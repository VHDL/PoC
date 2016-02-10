-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Patrick Lehmann
--
-- Module:					1-Wire BusController
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


entity ow_BusController is
  port (
		Clock					: in	STD_LOGIC;
		Reset					: in	STD_LOGIC;
			
		OWReset				: in	STD_LOGIC;
		OWStrobe			: in	STD_LOGIC;
		OWWrite				: in	STD_LOGIC;
		OWData_In			: in	STD_LOGIC;
		
		OWData_Out		: out	STD_LOGIC;
		OWError				: out	STD_LOGIC;
		OWReady				: out	STD_LOGIC;
		
		-- OneWire physical interface
		SerialData_i	: in	STD_LOGIC;
		SerialData_o	: out	STD_LOGIC;
		SerialData_t	: out	STD_LOGIC
	);
end entity;

architecture rtl of ow_BusController is
	constant COUNTER_BW				: POSITIVE := 15;
	
	constant CLOCKSPEED_HZ		: POSITIVE := 50000000;
	constant TIME_FACTOR			: POSITIVE := CLOCKSPEED_HZ / 1000000;
	
  constant OW_T_SLOT_MIN		: POSITIVE :=  60;		-- Time Slot Min							 60 µs
	constant OW_T_SLOT_MAX		: POSITIVE := 120;		-- Time Slot Max							120 µs
	constant OW_T_REC					: POSITIVE :=   1;		-- Recovery Time								1 µs
	constant OW_T_RSTH				: POSITIVE := 480;		-- Reset Time High						480 µs
	constant OW_T_RSTL				: POSITIVE := 480;		-- Reset Time Low							480 µs
	constant OW_T_PDHIGH_MIN	: POSITIVE :=  15;		-- Presence Detect High Min		 15 µs
	constant OW_T_PDHIGH_MAX	: POSITIVE :=  60;		-- Presence Detect High Max		 60 µs
	constant OW_T_PDLOW_MIN		: POSITIVE :=  60;		-- Presence Detect Low Min		 60 µs
	constant OW_T_PDLOW_MAX		: POSITIVE := 240;		-- Presence Detect Low Max		240 µs
	constant OW_T_LOW0_MIN		: POSITIVE :=  60;		-- Write 0 Low Time Min				 60 µs
	constant OW_T_LOW0_MAX		: POSITIVE := 120;		-- Write 0 Low Time Max				120 µs
	constant OW_T_LOW1_MIN		: POSITIVE :=   1;		-- Write 1 Low Time Min					1 µs
	constant OW_T_LOW1_MAX		: POSITIVE :=  15;		-- Write 1 Low Time Max				 15 µs
	constant OW_T_RDV					: POSITIVE :=  15;		-- Read Data Valid						 15 µs
	constant OW_T_RPD					: POSITIVE :=		1;		-- Read PullDown								1 µs

	type T_STATE is (
		ST_READY, ST_ERROR,
		ST_RESET_LOW, ST_RESET_DETECT_HIGH, ST_RESET_DETECT_HIGH_MIN, ST_RESET_DETECT_HIGH_MAX, ST_RESET_DETECT_LOW_MIN, ST_RESET_DETECT_LOW_MAX,
		ST_RECOVERY, ST_SLOT_TIMEOUT,
		ST_READ_START, ST_READ_LOW, ST_READ_SAMPLE, ST_READ_END,
		ST_WRITE_0_START, ST_WRITE_0_LOW,
		ST_WRITE_1_START, ST_WRITE_1_LOW
	);
	
	signal State												: T_STATE																			:= ST_READY;
	signal NextState										: T_STATE;
	signal TempState										: T_STATE																			:= ST_READY;
	signal NextTempState								: T_STATE;
	
	signal SlotCounter 									: UNSIGNED(COUNTER_BW - 1 downto 0) 					:= (others => '0');
	signal SlotCounter_Maximum					: UNSIGNED(COUNTER_BW - 1 downto 0) 					:= (others => '0');
	signal NextSlotCounter_Maximum			: UNSIGNED(COUNTER_BW - 1 downto 0) 					:= (others => '0');
	signal SlotCounter_Ctrl							: STD_LOGIC;
	signal SlotCounter_Reset						: STD_LOGIC;
	signal SlotCounter_Enable						: STD_LOGIC;
						
	signal TimingCounter 								: UNSIGNED(COUNTER_BW - 1 downto 0) 					:= (others => '0');
	signal TimingCounter_Maximum				: UNSIGNED(COUNTER_BW - 1 downto 0) 					:= (others => '0');
	signal NextTimingCounter_Maximum		: UNSIGNED(COUNTER_BW - 1 downto 0) 					:= (others => '0');
	signal TimingCounter_Ctrl						: STD_LOGIC;
	signal TimingCounter_Reset					: STD_LOGIC;
	signal TimingCounter_Enable					: STD_LOGIC;
	
	signal TriStateControl							: STD_LOGIC;
	
	signal OW_Data_r										: STD_LOGIC;
	signal OWData_Out_r   							: STD_LOGIC;
	signal OWData_Out_nxt 							: STD_LOGIC;
	
begin
	process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				State <= ST_READY;
				TempState <= ST_READY;
				
				SlotCounter_Maximum <= (others => '0');
				TimingCounter_Maximum <= (others => '0');
			else
				State <= NextState;
				TempState <= NextTempState;
				
				SlotCounter_Maximum <= NextSlotCounter_Maximum;
				TimingCounter_Maximum <= NextTimingCounter_Maximum;
			end if;
		end if;
	end process;

	process(State, OWWrite, OWStrobe, OWReset, OWData_In, OW_Data_r, TimingCounter_Ctrl, SlotCounter_Ctrl, 
				  TempState, OWData_Out_r, TimingCounter_Maximum, SlotCounter_Maximum)
	begin
		NextState <= State;
		NextTempState <= TempState;
		
		NextTimingCounter_Maximum <= TimingCounter_Maximum;
		NextSlotCounter_Maximum <= SlotCounter_Maximum;
		
		SlotCounter_Enable <= '0';
		SlotCounter_Reset <= '0';
		
		TimingCounter_Enable <= '0';
		TimingCounter_Reset <= '0';
		
		OWReady <= '0';
		OWError <= '0';
		OWData_Out_nxt <= OWData_Out_r;
		
		TriStateControl <= '1';
		
		case State is
			-- Start-/Warte-Zustand
			-- """"""""""""""""""""""""""""""""
			when ST_READY =>
				if OWReset = '1' then
					NextState <= ST_RESET_LOW;
					
					OWData_Out_nxt <= '0';
					
					SlotCounter_Reset <= '1';
					TimingCounter_Reset <= '1';
					
					NextTimingCounter_Maximum <= to_unsigned(OW_T_RSTL * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);														-- 480 µs auf "0"
				else
					if OWStrobe = '1' then
						-- Recovery-Timing für alle weiteren Slotarten setzen
						NextTimingCounter_Maximum <= to_unsigned(OW_T_REC * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);		-- 1µs
					
						if OWWrite = '0' then		-- Lesen
							NextState <= ST_READ_START;
						else										-- Schreiben
							if OWData_In = '0' then
								NextState <= ST_Write_0_START;
							else
								NextState <= ST_Write_1_START;
							end if;
						end if;
					end if;
				end if;
			
			-- Fehlerzustand (gefangen)
			-- """"""""""""""""""""""""""""""""
			when ST_ERROR =>
				OWError <= '1';
			
			-- Reset senden / Presence erkennen
			-- """"""""""""""""""""""""""""""""
			when ST_RESET_LOW =>
				TriStateControl <= '0';
			
				TimingCounter_Enable <= '1';
				
				if TimingCounter_Ctrl = '1' then
					NextState <= ST_RESET_DETECT_HIGH;
					
					NextSlotCounter_Maximum <= to_unsigned(OW_T_RSTH * TIME_FACTOR - 1, SlotCounter_Maximum'length);														-- 480 µs auf "0"
				end if;
			
			when ST_RESET_DETECT_HIGH =>
				SlotCounter_Enable <= '1';
			
				if OW_Data_r = '1' then
					NextState <= ST_RESET_DETECT_HIGH_MIN;
					
					NextTimingCounter_Maximum <= to_unsigned(OW_T_PDHIGH_MIN * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);
				else
					if SlotCounter_Ctrl = '1' then		-- SlotCounter abgelaufen
						NextState <= ST_ERROR;
					end if;
				end if;
				
			when ST_RESET_DETECT_HIGH_MIN =>
				SlotCounter_Enable <= '1';
			
				TimingCounter_Enable <= '1';
				
				if OW_Data_r = '0' then
					NextState <= ST_ERROR;
					
					TimingCounter_Reset <= '1';
				else
					if TimingCounter_Ctrl = '1' then		-- TimingCounter abgelaufen
						NextState <= ST_RESET_DETECT_HIGH_MAX;
						
						NextTimingCounter_Maximum <= to_unsigned((OW_T_PDHIGH_MAX - OW_T_PDHIGH_MIN) * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);	-- 45µs maximal auf "0" warten
					else
						if SlotCounter_Ctrl = '1' then		-- SlotCounter abgelaufen
							NextState <= ST_ERROR;
						end if;
					end if;
				end if;
			
			when ST_RESET_DETECT_HIGH_MAX =>
				SlotCounter_Enable <= '1';
			
				TimingCounter_Enable <= '1';
				
				if OW_Data_r = '0' then
					NextState <= ST_RESET_DETECT_LOW_MIN;
					
					TimingCounter_Reset <= '1';
					NextTimingCounter_Maximum <= to_unsigned(OW_T_PDLOW_MIN * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);		-- 60µs muss "0" anliegen
				else
					if TimingCounter_Ctrl = '1' OR SlotCounter_Ctrl = '1' then		-- TimingCounter oder SlotCounter abgelaufen
						NextState <= ST_ERROR;
					end if;
				end if;
			
			when ST_RESET_DETECT_LOW_MIN =>
				SlotCounter_Enable <= '1';
			
				TimingCounter_Enable <= '1';
				
				if OW_Data_r = '1' then
					NextState <= ST_ERROR;
					
					TimingCounter_Reset <= '1';
				else
					if TimingCounter_Ctrl = '1' then		-- TimingCounter abgelaufen
						NextState <= ST_RESET_DETECT_LOW_MAX;
						
						NextTimingCounter_Maximum <= to_unsigned((OW_T_PDLOW_MAX - OW_T_PDLOW_MIN) * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);		-- 180µs maximal auf "1" warten
					else
						if SlotCounter_Ctrl = '1' then		-- SlotCounter abgelaufen
							NextState <= ST_ERROR;
						end if;
					end if;
				end if;
			
			when ST_RESET_DETECT_LOW_MAX =>
				SlotCounter_Enable <= '1';
			
				TimingCounter_Enable <= '1';
				
				if OW_Data_r = '1' then
					NextState <= ST_SLOT_TIMEOUT;
					
					TimingCounter_Reset <= '1';
				else
					if TimingCounter_Ctrl = '1' OR SlotCounter_Ctrl = '1' then		-- TimingCounter oder SlotCounter abgelaufen
						NextState <= ST_ERROR;
					end if;
				end if;
			
			-- Recovery
			-- """"""""""""""""""""""""""""""""
			when ST_RECOVERY =>
				TimingCounter_Enable <= '1';
				
				if TimingCounter_Ctrl = '1' then
					NextState <= TempState;
					
					-- Timings setzen
					if TempState = ST_READ_LOW then
						NextTimingCounter_Maximum <= to_unsigned(OW_T_RPD * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);		-- 1µs
					elsif TempState =	ST_WRITE_0_LOW then
						NextTimingCounter_Maximum <= to_unsigned(OW_T_LOW0_MIN * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);		-- 60µs
					elsif TempState = ST_WRITE_1_LOW then
						NextTimingCounter_Maximum <= to_unsigned(OW_T_LOW1_MIN * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);		-- 1µs
					end if;
									
					NextSlotCounter_Maximum <= to_unsigned(OW_T_SLOT_MIN * TIME_FACTOR - 1, SlotCounter_Maximum'length);
				end if;
			
			-- Slot Timeout
			-- """"""""""""""""""""""""""""""""
			when ST_SLOT_TIMEOUT =>
				SlotCounter_Enable <= '1';
								
				if SlotCounter_Ctrl = '1' then
					NextState <= ST_READY;
					
					OWReady <= '1';
				end if;
			
			-- Lesen
			-- """"""""""""""""""""""""""""""""
			when ST_READ_START =>
				NextState <= ST_RECOVERY;
				NextTempState <= ST_READ_LOW;
				
			when ST_READ_LOW =>
				TriStateControl <= '0';
			
				SlotCounter_Enable <= '1';
			
				TimingCounter_Enable <= '1';
				
				if TimingCounter_Ctrl = '1' then
					NextState <= ST_READ_SAMPLE;
					
					NextTimingCounter_Maximum <= to_unsigned(OW_T_RDV * TIME_FACTOR - 1, NextTimingCounter_Maximum'length);		-- 15µs
				end if;
			
			when sT_READ_SAMPLE =>
				SlotCounter_Enable <= '1';
			
				TimingCounter_Enable <= '1';
				
				if TimingCounter_Ctrl = '1' then
					-- Daten verarbeiten
					if OW_Data_r = '0' then
						OWData_Out_nxt <= '0';
					else
						OWData_Out_nxt <= '1';
					end if;
				
					if SlotCounter_Ctrl = '1' then
						NextState <= ST_READY;
						
						OWReady <= '1';
					else
						NextState <= ST_SLOT_TIMEOUT;
					end if;
				else
					if SlotCounter_Ctrl = '1' then
						NextState <= ST_ERROR;
					end if;
				end if;
			
			-- "0" schreiben
			-- """"""""""""""""""""""""""""""""
			when ST_WRITE_0_START =>
				NextState <= ST_RECOVERY;
				NextTempState <= ST_WRITE_0_LOW;
				
			when ST_WRITE_0_LOW =>
				TriStateControl <= '0';
			
				SlotCounter_Enable <= '1';
			
				TimingCounter_Enable <= '1';
				
				if TimingCounter_Ctrl = '1' then
					if SlotCounter_Ctrl = '1' then
						NextState <= ST_READY;
						
						OWReady <= '1';
					else
						NextState <= ST_SLOT_TIMEOUT;
					end if;
				else
					if SlotCounter_Ctrl = '1' then
						NextState <= ST_ERROR;
					end if;
				end if;
			
			-- "1" schreiben
			-- """"""""""""""""""""""""""""""
			when ST_WRITE_1_START =>
				NextState <= ST_RECOVERY;
				NextTempState <= ST_WRITE_1_LOW;
				
			when ST_WRITE_1_LOW =>
				TriStateControl <= '0';
			
				SlotCounter_Enable <= '1';
			
				TimingCounter_Enable <= '1';
				
				if TimingCounter_Ctrl = '1' then
					if SlotCounter_Ctrl = '1' then
						NextState <= ST_READY;
						
						OWReady <= '1';
					else
						NextState <= ST_SLOT_TIMEOUT;
					end if;
				else
					if SlotCounter_Ctrl = '1' then
						NextState <= ST_ERROR;
					end if;
				end if;
			
			-- """"""""""""""""""""""""""""""""
			when others =>
				null;
	
		end case;
  end process;

	-- Daten lesen/schreiben
	-- """""""""""""""""""""
	SerialData_o		<= '0';
	SerialData_t		<= TriStateControl;

	-- Daten einsynchronisieren
	-- """"""""""""""""""""""""
	process(Clock)
	begin
		if rising_edge(Clock) then
			OW_Data_r <= SerialData_i;
		end if;
	end process;

	-- Daten puffern
	-- """"""""""""""""""""""""
	process(Clock)
	begin
		if rising_edge(Clock) then
			OWData_Out_r <= OWData_Out_nxt;
		end if;
	end process;
  OWData_Out <= OWData_Out_r;
	
	-- Slot-Steuerung
	-- """"""""""""""""
	process(Clock)
  begin
    if rising_edge(Clock) then
			if Reset = '1'  then
				SlotCounter <= (others => '0');
			else
			  if SlotCounter_Enable = '1' then
					if SlotCounter_Ctrl = '1' then
						SlotCounter <= (others => '0');
					else  
						SlotCounter <= SlotCounter + 1;
					end if;
				end if;
			end if;
    end if;
  end process;

	SlotCounter_Ctrl <= '1' when (SlotCounter = SlotCounter_Maximum OR SlotCounter_Reset = '1') else '0';

  -- Timing-Steuerung
	-- """"""""""""""""
	process(Clock)
  begin
    if rising_edge(Clock) then
			if Reset = '1'  then
				TimingCounter <= (others => '0');
			else
			  if TimingCounter_Enable = '1' then
					if TimingCounter_Ctrl = '1' then
						TimingCounter <= (others => '0');
					else  
						TimingCounter <= TimingCounter + 1;
					end if;
				end if;
			end if;
    end if;
  end process;

	TimingCounter_Ctrl <= '1' when (TimingCounter = TimingCounter_Maximum OR TimingCounter_Reset = '1') else '0';
end architecture;
