-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Patrick Lehmann
--
-- Module:					1-Wire Controller
-- 
-- Description:
-- ------------------------------------
--	TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library PoC;
use			PoC.physical.all;


entity owController is
  port (
		Clock					: in STD_LOGIC;
		Reset					: in STD_LOGIC;
		
		OWReset				: in STD_LOGIC;
		OWStrobe			: in STD_LOGIC;
		OWWrite				: in STD_LOGIC;
		OWData_In			: in STD_LOGIC_VECTOR(7 downto 0);
		
		OWData_Out		: out STD_LOGIC_VECTOR(7 downto 0);
		OWError				: out STD_LOGIC;
		OWReady				: out STD_LOGIC;
		
		-- OneWire physical interface
		SerialData_i	: in	STD_LOGIC;
		SerialData_o	: out	STD_LOGIC;
		SerialData_t	: out	STD_LOGIC
	);
end entity;

-- TODO: check design for parasitary mode support

architecture rtl of OneWireController is

	type T_STATE is (
		ST_READY, ST_ERROR, ST_FINISHED,
		ST_BUS_RESET, ST_BUS_RESET_WAIT,
		ST_WRITE, ST_WRITE_WAIT, ST_READ, ST_READ_WAIT
	);
	
	signal State			: T_STATE := ST_READY;
	signal NextState	: T_STATE;
	
	-- Input-Signale
	signal OWBusC_Reset				: STD_LOGIC;
	signal OWBusC_Strobe			: STD_LOGIC;
	signal OWBusC_Write				: STD_LOGIC;
			
	-- Output-Signale
	signal OWBusC_Data_Out		: STD_LOGIC;
	signal OWBusC_Error				: STD_LOGIC;
	signal OWBusC_Ready				: STD_LOGIC;
	
	-- Puffer
	signal WriteBuffer				: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	signal WriteBuffer_Shift	: STD_LOGIC;
	signal ReadBuffer					: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	signal ReadBuffer_Shift		:  STD_LOGIC;
	
	-- Bit-Counter
	signal BitCounter					: UNSIGNED(3 downto 0) := to_unsigned(15,4);
	signal BitCounter_Enable	: STD_LOGIC;
	signal BitCounter_Ctrl		: STD_LOGIC;
	signal BitCounter_Reset		: STD_LOGIC;
	
begin
	-- Daten zum Schreiben puffern - LSR
	process(Clock, Reset, OWStrobe, OWData_In, WriteBuffer_Shift, WriteBuffer)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				WriteBuffer <= (others => '0');
			elsif OWStrobe = '1' then
				WriteBuffer <= OWData_In;
			elsif WriteBuffer_Shift = '1' then
				WriteBuffer <= '0' & WriteBuffer(7 downto 1);
			end if;
		end if;
	end process;
	
	-- Daten lesen und in LSR speichern
	process(Clock, Reset, ReadBuffer_Shift, OWBusC_Data_Out, ReadBuffer)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				ReadBuffer <= (others => '0');
			elsif ReadBuffer_Shift = '1' then
				ReadBuffer <= OWBusC_Data_Out & ReadBuffer(7 downto 1);
			end if;
		end if;
	end process;

	-- Statemaschine
	process(Clock, NextState)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				State <= ST_READY;
			else
				State <= NextState;
			end if;
		end if;
	end process;
	
	process(State, OWReset, OWStrobe, OWWrite, OWBusC_Ready, OWBusC_Error, 
	        WriteBuffer, BitCounter_Ctrl)
	begin
		NextState <= State;
		
		WriteBuffer_Shift <= '0';
		ReadBuffer_Shift <= '0';
		
		BitCounter_Enable <= '0';
		
		OWBusC_Reset <= '0';
		OWBusC_Strobe <= '0';
		OWBusC_Write <= '0';
	
		OWReady <= '0';
		OWError <= '0';
		
		case State is
			-- Start-/Warte-Zustand
			-- """"""""""""""""""""""""""""""""
			when ST_READY =>
				if OWReset = '1' then
					NextState <= ST_BUS_RESET;

					OWBusC_Reset <= '1';
				else
					if OWStrobe = '1' then
						if OWWrite = '0' then		-- Lesen
							NextState <= ST_READ;
						else										-- Schreiben
							NextState <= ST_WRITE;
						end if;
					end if;
				end if;
			
			-- Fehlerzustand (gefangen)
			-- """"""""""""""""""""""""""""""""
			when ST_ERROR =>
				OWError <= '1';
				
			when ST_FINISHED =>
				NextState <= ST_READY;
			
				OWReady <= '1';

			-- Bus Reset
			-- """"""""""""""""""""""""""""""
			when ST_BUS_RESET =>
				if OWBusC_Error = '1' then
					NextState <= ST_ERROR;
				else
					if OWBusC_Ready = '1' then
						NextState <= ST_READY;
						
						OWReady <= '1';
					end if;
				end if;
				
			-- lesen
			-- """"""""""""""""""""""""""""""
			when ST_READ =>
				OWBusC_Strobe <= '1';
				OWBusC_Write <= '0';
			
				BitCounter_Enable <= '1';
			
				NextState <= ST_READ_WAIT;
				
				if OWBusC_Error = '1' then
					NextState <= ST_ERROR;
				end if;
			
			when ST_READ_WAIT =>
				if OWBusC_Error = '1' then
					NextState <= ST_ERROR;
				else
					if OWBusC_Ready = '1' then
						ReadBuffer_Shift <= '1';
						
						if BitCounter_Ctrl = '0' then
							NextState <= ST_READ;
						else
							NextState <= ST_FINISHED;
						end if;
					end if;
				end if;
				
			-- schreiben
			-- """"""""""""""""""""""""""""""
			when ST_WRITE =>
				OWBusC_Strobe <= '1';
				OWBusC_Write <= '1';
				
				BitCounter_Enable <= '1';
			
				NextState <= ST_WRITE_WAIT;
				
				if OWBusC_Error = '1' then
					NextState <= ST_ERROR;
				end if;
			
			when ST_WRITE_WAIT =>
				if OWBusC_Error = '1' then
					NextState <= ST_ERROR;
				else
					if OWBusC_Ready = '1' then
						WriteBuffer_Shift <= '1';
						
						if BitCounter_Ctrl = '0' then
							NextState <= ST_WRITE;
						else
							NextState <= ST_FINISHED;
						end if;
					end if;
				end if;
						
			-- """"""""""""""""""""""""""""""""
			when others =>
				null;
	
		end case;
  end process;
	
	-- Bit-Steuerung
	-- """"""""""""""""
	BitCounter_Reset <= Reset;
	
	process(Clock)
  begin
    if rising_edge(Clock) then
			if Reset = '1'  then
				BitCounter <= to_unsigned(15,4);
			else
			  if BitCounter_Enable = '1' then
					if BitCounter_Ctrl = '1' then
						BitCounter <= to_unsigned(0,4);
					else  
						BitCounter <= BitCounter + 1;
					end if;
				end if;
			end if;
    end if;
  end process;

	BitCounter_Ctrl <= '1' when (BitCounter = 7 OR BitCounter_Reset = '1') else '0';
	
	OWBusC : entity PoC.ow_BusController
		port map (
			Clock							=> Clock,
			Reset							=> Reset,
			
			OWReset						=> OWBusC_Reset,
			OWStrobe					=> OWBusC_Strobe,
			OWWrite						=> OWBusC_Write,
			OWData_In					=> WriteBuffer(0),
			OWData_Out				=> OWBusC_Data_Out,
			OWError						=> OWBusC_Error,
			OWReady						=> OWBusC_Ready,
			
			SerialData_i			=> SerialData_i,
			SerialData_o			=> SerialData_o,
			SerialData_t			=> SerialData_t
		);
	
	-- Datenausgabe
	OWData_Out <= ReadBuffer;
end architecture;
