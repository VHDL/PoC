-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Patrick Lehmann
-- 
-- Testbench:				For PoC.io.iic.IICController
--
-- Description:
-- ------------------------------------
--	TODO
-- 
-- License:
-- ============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.iic.all;
-- simulation only packages
use			PoC.sim_types.all;
use			PoC.simulation.all;
use			PoC.waveform.all;


entity iic_Controller_tb is
end entity;


architecture tb of iic_Controller_tb is
	constant CLOCK_FREQ					: FREQ			:= 100 MHz;
	
	constant ADDRESS_BITS				: POSITIVE	:= 7;
	constant DATA_BITS					: POSITIVE	:= 8;
	
	signal Clock								: STD_LOGIC;
	signal Reset								: STD_LOGIC;

	signal Master_Request				: STD_LOGIC;
	signal Master_Grant					: STD_LOGIC;
	signal Master_Command				: T_IO_IIC_COMMAND;
	signal Master_Status				: T_IO_IIC_STATUS;
	signal Master_Error					: T_IO_IIC_ERROR;
	
	signal Master_Address				: STD_LOGIC_VECTOR(ADDRESS_BITS - 1 downto 0);
  
	signal Master_WP_Valid			: STD_LOGIC;
	signal Master_WP_Data				: STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
	signal Master_WP_Last				: STD_LOGIC;
	signal Master_WP_Ack				: STD_LOGIC;
	signal Master_RP_Valid			: STD_LOGIC;
	signal Master_RP_Data				: STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
	signal Master_RP_Last				: STD_LOGIC;
	signal Master_RP_Ack				: STD_LOGIC;
	
	-- tristate interface: STD_LOGIC;
	signal SerialClock_i				: STD_LOGIC;
	signal SerialClock_o				: STD_LOGIC;
	signal SerialClock_t				: STD_LOGIC;
	signal SerialData_i					: STD_LOGIC;
	signal SerialData_o					: STD_LOGIC;
	signal SerialData_t					: STD_LOGIC;
	
begin
	simGenerateClock(Clock, CLOCK_FREQ);
	simGenerateWaveform(Reset, simGenerateWaveform_Reset(Pause => 50 ns));
	
	UUT : entity PoC.iic_Controller
		generic map (
			DEBUG													=> FALSE,
			CLOCK_FREQ										=> CLOCK_FREQ,
			IIC_BUSMODE										=> IO_IIC_BUSMODE_STANDARDMODE,
			IIC_ADDRESS										=> (7 downto 1 => '0') & '-',
			ADDRESS_BITS									=> ADDRESS_BITS,
			DATA_BITS											=> DATA_BITS,
			ALLOW_MEALY_TRANSITION				=> TRUE
		)
		port map (
			Clock													=> Clock,
			Reset													=> Reset,
			
			-- IICController master interface
			Master_Request								=> Master_Request,
			Master_Grant									=> Master_Grant,
			Master_Command								=> Master_Command,
			Master_Status									=> Master_Status,
			Master_Error									=> Master_Error,
			
			Master_Address								=> Master_Address,
			
			Master_WP_Valid								=> Master_WP_Valid,
			Master_WP_Data								=> Master_WP_Data,
			Master_WP_Last								=> Master_WP_Last,
			Master_WP_Ack									=> Master_WP_Ack,
			Master_RP_Valid								=> Master_RP_Valid,
			Master_RP_Data								=> Master_RP_Data,
			Master_RP_Last								=> Master_RP_Last,
			Master_RP_Ack									=> Master_RP_Ack,
			
			-- tristate interface
			SerialClock_i									=> SerialClock_i,
			SerialClock_o									=> SerialClock_o,
			SerialClock_t									=> SerialClock_t,
			SerialData_i									=> SerialData_i,
			SerialData_o									=> SerialData_o,
			SerialData_t									=> SerialData_t
		);

	procChecker : process
		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Checker");
	begin
		
		wait for 10 us;
		
		-- This process is finished
		simDeactivateProcess(simProcessID);
		wait;  -- forever
	end process;
	
end architecture;
