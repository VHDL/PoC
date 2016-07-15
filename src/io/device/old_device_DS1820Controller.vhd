-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Patrick Lehmann
--
-- Module:					1-Wire Temperature sensor: DS1820
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


entity device_DS1820Controller is
	port (
		Clock								: in	STD_LOGIC;
		Reset								: in	STD_LOGIC;
		
		OW_Data							: inout STD_LOGIC;
		
		DS1820_Temperature	: out	STD_LOGIC_VECTOR(8 downto 0);
		DS1820_Valid				: out	STD_LOGIC;
		DS1820_Error				: out	STD_LOGIC
	);
end entity;


architecture rtl of device_DS1820Controller is


	type T_STATE is (ST_READY, ST_ERROR, ST_FINISHED,		-- generische FSM-Zustände
									 ST_BUS_RESET, ST_BUS_RESET_WAIT,		-- OWBus Reset
									 ST_SKIP_ROM, ST_SKIP_ROM_WAIT,			-- Sende SkipROM
									 ST_CONV_T, ST_CONV_T_WAIT,					-- Sende ConvertTemperature
									 ST_WAIT,														-- Warten auf neue Temperatur
									 ST_READ_SP, ST_READ_SP_WAIT,				-- Sende ReadScratchPad
									 ST_READ, ST_READ_WAIT,							-- Empfange Daten (72 Bit)
									 ST_STORE_TEMP, ST_CRC);						-- Temperatur sichern / CRC Prüfsumme berechnen
	
	signal State : T_STATE := ST_READY;
	signal NextState : T_STATE := ST_READY;
	
	signal TempState : T_STATE := ST_READY;
	signal NextTempState : T_STATE := ST_READY;
	
	-- Input-Signale
	signal OWC_Reset : STD_LOGIC;
	signal OWC_Strobe : STD_LOGIC;
	signal OWC_Write : STD_LOGIC;
	signal OWC_Data_In : STD_LOGIC_VECTOR(7 downto 0);
			
	-- Output-Signale
	signal OWC_Data_Out : STD_LOGIC_VECTOR(7 downto 0);
	signal OWC_Error : STD_LOGIC;
	signal OWC_Ready : STD_LOGIC;
	
	-- Wait-Counter
	signal WaitCounter : unsigned(25 downto 0);
	signal WaitCounter_Enable : STD_LOGIC;
	signal WaitCounter_Ctrl : STD_LOGIC;
	signal WaitCounter_Reset : STD_LOGIC;
	
	-- ScratchPad-Counter
	signal ScratchPadCounter : unsigned(3 downto 0);
	signal ScratchPadCounter_Enable : STD_LOGIC;
	signal ScratchPadCounter_Ctrl : STD_LOGIC;
	signal ScratchPadCounter_Reset : STD_LOGIC;
	
	-- ScratchPad
	signal ScratchPad : STD_LOGIC_VECTOR(71 downto 0);
	signal ScratchPad_BitShift : STD_LOGIC;
	signal ScratchPad_ByteShift : STD_LOGIC;
	
	-- Temperatur Puffer
	signal TemperatureBuffer : STD_LOGIC_VECTOR(8 downto 0);
	signal TemperatureBuffer_Load : STD_LOGIC;
	
	-- CRC Prüfsumme
	signal CRC_Reset : STD_LOGIC;
	signal CRC_Enable : STD_LOGIC;
	signal CRC_In : STD_LOGIC;
	signal CRC_Out : STD_LOGIC_VECTOR(7 downto 0);
	
	-- CRCBit-Counter
	signal CRCBitCounter : unsigned(6 downto 0);
	signal CRCBitCounter_Enable : STD_LOGIC;
	signal CRCBitCounter_Ctrl : STD_LOGIC;
	signal CRCBitCounter_Reset : STD_LOGIC;
	
begin
	-- Statemaschine
	process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				State <= ST_READY;
				TempState <= ST_READY;			
			else
				State <= NextState;
				TempState <= NextTempState;			
			end if;
		end if;
	end process;
	
	process(State, TempState, OWC_Ready, OWC_Error, WaitCounter_Ctrl, ScratchPadCounter_Ctrl, CRCBitCounter, CRCBitCounter_Ctrl, ScratchPad, CRC_Out)
	begin
		NextState <= State;
		NextTempState <= TempState;
		
		OWC_Reset <= '0';
		OWC_Strobe <= '0';
		OWC_Write <= '0';
		OWC_Data_In <= "00000000";
		
		WaitCounter_Enable <= '0';
		ScratchPadCounter_Enable <= '0';
		ScratchPad_BitShift <= '0';
		ScratchPad_ByteShift <= '0';
		
		TemperatureBuffer_Load <= '0';
		CRC_Reset <= '0';
		CRC_Enable <= '0';
		CRCBitCounter_Enable <= '0';
		
		DS1820_Valid <= '0';
		DS1820_Error <= '0';
		
		case State is
			-- Start-/Warte-Zustand
			-- """"""""""""""""""""""""""""""""
			when ST_READY =>
				NextState <= ST_BUS_RESET;
				NextTempState <= ST_CONV_T;
				
			-- Fehlerzustand (gefangen)
			-- """"""""""""""""""""""""""""""""
			when ST_ERROR =>
				DS1820_Error <= '1';
				
			when ST_FINISHED =>
				NextState <= ST_READY;
				
				DS1820_Valid <= '1';

			-- einen Takt pausiren
			-- """"""""""""""""""""""""""""""""
			when ST_BUS_RESET =>
				OWC_Reset <= '1';
				
				NextState <= ST_BUS_RESET_WAIT;
			
			when ST_BUS_RESET_WAIT =>
				if OWC_Error = '1' then
					NextState <= ST_ERROR;
				elsif OWC_Ready = '1' then
					NextState <= ST_SKIP_ROM;
				end if;
			
			when ST_SKIP_ROM =>
				OWC_Strobe <= '1';
				OWC_Write <= '1';
				OWC_Data_In <= "11001100";						-- 0xCCh
			
				NextState <= ST_SKIP_ROM_WAIT;
			
			when ST_SKIP_ROM_WAIT =>
				if OWC_Error = '1' then
					NextState <= ST_ERROR;
				elsif OWC_Ready = '1' then
					NextState <= TempState;
				end if;
		
			when ST_CONV_T =>
				OWC_Strobe <= '1';
				OWC_Write <= '1';
				OWC_Data_In <= "01000100";						-- 0x44h
				
				NextState <= ST_CONV_T_WAIT;
				
			when ST_CONV_T_WAIT =>
				if OWC_Error = '1' then
					NextState <= ST_ERROR;
				elsif OWC_Ready = '1' then
					NextState <= ST_WAIT;
				end if;
				
			when ST_WAIT =>
				WaitCounter_Enable <= '1';
				
				if OWC_Error = '1' then
					NextState <= ST_ERROR;
				elsif WaitCounter_Ctrl = '1' then
					NextState <= ST_BUS_RESET;
					NextTempState <= ST_READ_SP;
				end if;
			
			when ST_READ_SP =>
				OWC_Strobe <= '1';
				OWC_Write <= '1';
				OWC_Data_In <= "10111110";						-- 0xBEh
			
				NextState <= ST_READ_SP_WAIT;
			
			when ST_READ_SP_WAIT =>
				if OWC_Error = '1' then
					NextState <= ST_ERROR;
				elsif OWC_Ready = '1' then
					NextState <= ST_READ;
				end if;
			
			when ST_READ =>
				OWC_Strobe <= '1';
				OWC_Write <= '0';
				
				ScratchPadCounter_Enable <= '1';
				
				NextState <= ST_READ_WAIT;
				
				if OWC_Error = '1' then
					NextState <= ST_ERROR;
				end if;
			
			when ST_READ_WAIT =>
				if OWC_Error = '1' then
					NextState <= ST_ERROR;
				else
					if OWC_Ready = '1' then
						ScratchPad_ByteShift <= '1';
						
						if ScratchPadCounter_Ctrl = '0' then
							NextState <= ST_READ;
						else
							NextState <= ST_STORE_TEMP;
						end if;
					end if;
				end if;
			
			when ST_STORE_TEMP =>
				TemperatureBuffer_Load <= '1';
			
				NextState <= ST_CRC;
			
			when ST_CRC =>
				CRCBitCounter_Enable <= '1';
				
				if CRCBitCounter <= 55 OR CRCbitCounter >= 64 then
					CRC_Enable <= '1';
				end if;
			
				ScratchPad_BitShift <= '1';
			
				if CRCBitCounter_Ctrl = '1' then
					if CRC_Out = (7 downto 0 => '0') then
						NextState <= ST_FINISHED;
					else
						NextState <= ST_READY;
					end if;
				end if;
			
			-- """"""""""""""""""""""""""""""""
			when others =>
				null;
	
		end case;
  end process;
	
	
	
	-- Wait-Steuerung
	-- """"""""""""""""
	WaitCounter_Reset <= Reset;
	process(Clock)
  begin
    if rising_edge(Clock) then
			if Reset = '1'  then
				WaitCounter <= (others => '0');
			elsif WaitCounter_Enable = '1' then
				if WaitCounter_Ctrl = '1' then
					WaitCounter <= (others => '0');
				else  
					WaitCounter <= WaitCounter + 1;
				end if;
			end if;
    end if;
  end process;
	
	WaitCounter_Ctrl <= '1' when (WaitCounter = 1000	* 50000 OR WaitCounter_Reset = '1') else '0';  -- 1000 ms
	
	-- ScratchPad-Steuerung
	-- """"""""""""""""
	ScratchPadCounter_Reset <= Reset;
	process(Clock)
  begin
    if rising_edge(Clock) then
			if Reset = '1'  then
				ScratchPadCounter <= (others => '0');
			elsif ScratchPadCounter_Enable = '1' then
				if ScratchPadCounter_Ctrl = '1' then
					ScratchPadCounter <= (others => '0');
				else  
					ScratchPadCounter <= ScratchPadCounter + 1;
				end if;
			end if;
    end if;
  END PROCESS;

	ScratchPadCounter_Ctrl <= '1' when (ScratchPadCounter = 8 OR ScratchPadCounter_Reset = '1') else '0';
	
	-- ScratchPad PSR - ParallelShiftRegister
	process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				ScratchPad <= (others => '0');
			else
				if ScratchPad_ByteShift = '1' then
					ScratchPad <= OWC_Data_Out & ScratchPad(71 downto 8);
				end if;
				
				if ScratchPad_BitShift = '1' then
					ScratchPad <= ScratchPad(70 downto 0) & ScratchPad(71);
				end if;
			end if;
		end if;
	END PROCESS;
	
	OWC : entity PoC.ow_Controller
		port map (
			Clock => Clock,
			Reset => Reset,
			OW_Data => OW_Data,
		
			OWReset => OWC_Reset,
			OWStrobe => OWC_Strobe,
			OWWrite => OWC_Write,
			OWData_In => OWC_Data_In,
			
			OWData_Out => OWC_Data_Out,
			OWError => OWC_Error,
			OWReady => OWC_Ready
		);
	
	-- TemperaturBuffer (PLR)
	process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				TemperatureBuffer <= (others => '0');
			elsif TemperatureBuffer_Load = '1' then
				TemperatureBuffer <= ScratchPad(8 downto 0);
			end if;
		end if;
	end process;
	
	-- CRCBit-Steuerung
	-- """"""""""""""""
	CRCBitCounter_Reset <= Reset;
	
	process(Clock)
  begin
    if rising_edge(Clock) then
			if Reset = '1'  then
				CRCBitCounter <= to_unsigned(127,7);
			elsif CRCBitCounter_Enable = '1' then
				if CRCBitCounter_Ctrl = '1' then
					CRCBitCounter <= to_unsigned(0,7);
				else  
					CRCBitCounter <= CRCBitCounter + 1;
				end if;
			end if;
    end if;
  end process;

	CRCBitCounter_Ctrl <= '1' when (CRCBitCounter = 71 OR CRCBitCounter_Reset = '1') else '0';
	
	-- CRC Prüfsummengenerator
	CRC_In <= ScratchPad(71);
	
	CRC : entity PoC.ow_CRCGenerator
		PORT MAP (
			Clock				=> Clock,
			Reset				=> CRC_Reset,
			CE					=> CRC_Enable,
			Signal_In		=> CRC_In,
			CRC_Out			=> CRC_Out
		);
	
	DS1820_Temperature <= TemperatureBuffer;
end architecture;
