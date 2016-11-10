-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Patrick Lehmann
--
-- Testbench:				For PoC.io.iic.Controller
--
-- Description:
-- ------------------------------------
--	TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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

	constant ADDRESS_BITS				: positive	:= 7;
	constant DATA_BITS					: positive	:= 8;

	signal Clock								: std_logic;
	signal Reset								: std_logic;

	signal Master_Request				: std_logic;
	signal Master_Grant					: std_logic;
	signal Master_Command				: T_IO_IIC_COMMAND;
	signal Master_Status				: T_IO_IIC_STATUS;
	signal Master_Error					: T_IO_IIC_ERROR;

	signal Master_Address				: std_logic_vector(ADDRESS_BITS - 1 downto 0);

	signal Master_WP_Valid			: std_logic;
	signal Master_WP_Data				: std_logic_vector(DATA_BITS - 1 downto 0);
	signal Master_WP_Last				: std_logic;
	signal Master_WP_Ack				: std_logic;
	signal Master_RP_Valid			: std_logic;
	signal Master_RP_Data				: std_logic_vector(DATA_BITS - 1 downto 0);
	signal Master_RP_Last				: std_logic;
	signal Master_RP_Ack				: std_logic;

	-- tristate interface: STD_LOGIC;
	signal Master_SerialClock_i	: std_logic;
	signal Master_SerialClock_o	: std_logic;
	signal Master_SerialClock_t	: std_logic;
	signal Master_SerialData_i	: std_logic;
	signal Master_SerialData_o	: std_logic;
	signal Master_SerialData_t	: std_logic;

	signal Slave1_SerialClock_i	: std_logic;
	signal Slave1_SerialClock_o	: std_logic;
	signal Slave1_SerialClock_t	: std_logic;
	signal Slave1_SerialData_i	: std_logic;
	signal Slave1_SerialData_o	: std_logic;
	signal Slave1_SerialData_t	: std_logic;

begin
	-- initialize global simulation status
	-- simInitialize;
	simInitialize(MaxSimulationRuntime => 200 us);
	-- generate global testbench clock and reset
	simGenerateClock(Clock, CLOCK_FREQ);
	simGenerateWaveform(Reset, simGenerateWaveform_Reset(Pause => 50 ns));

	UUT : entity PoC.iic_Controller
		generic map (
			DEBUG													=> FALSE,
			CLOCK_FREQ										=> CLOCK_FREQ,
			IIC_BUSMODE										=> IO_IIC_BUSMODE_FASTMODEPLUS,	--IO_IIC_BUSMODE_STANDARDMODE,
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
			SerialClock_i									=> Master_SerialClock_i,
			SerialClock_o									=> Master_SerialClock_o,
			SerialClock_t									=> Master_SerialClock_t,
			SerialData_i									=> Master_SerialData_i,
			SerialData_o									=> Master_SerialData_o,
			SerialData_t									=> Master_SerialData_t
		);

	blkSerialClock : block
		signal SerialClock_Wire	: std_logic;
		signal Master_Wire			: std_logic		:= 'Z';
		signal Slave1_Wire			: std_logic		:= 'Z';
	begin
		-- pullup resistor
		SerialClock_Wire			<= 'H';

		Master_Wire						<= 'L', '0' after 20 ns		when (Master_SerialClock_t = '0') else 'Z' after 100 ns;
		Slave1_Wire						<= 'L', '0' after 30 ns		when (Slave1_SerialClock_t = '0') else 'Z' after 200 ns;
		SerialClock_Wire			<= Master_Wire;
		SerialClock_Wire			<= Slave1_Wire;

		-- readers
		Master_SerialClock_i	<= to_X01(SerialClock_Wire) after 40 ns;
		Slave1_SerialClock_i	<= to_X01(SerialClock_Wire) after 50 ns;
	end block;

	blkSerialData : block
		signal SerialData_Wire	: std_logic;
		signal Master_Wire			: std_logic		:= 'Z';
		signal Slave1_Wire			: std_logic		:= 'Z';
	begin
		-- pullup resistor
		SerialData_Wire				<= 'H';

		-- drivers
		Master_Wire						<= 'L', '0' after 20 ns		when (Master_SerialData_t = '0') else 'Z' after 100 ns;
		Slave1_Wire						<= 'L', '0' after 30 ns		when (Slave1_SerialData_t = '0') else 'Z' after 200 ns;
		SerialData_Wire				<= Master_Wire;
		SerialData_Wire				<= Slave1_Wire;

		-- readers
		Master_SerialData_i		<= to_X01(SerialData_Wire) after 40 ns;
		Slave1_SerialData_i		<= to_X01(SerialData_Wire) after 50 ns;
	end block;

	procMaster : process
		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Master Port");
	begin
		Master_Request		<= '0';
		Master_Command		<= IO_IIC_CMD_NONE;
		Master_Address		<= (others => '0');
		Master_WP_Valid		<= '0';
		Master_WP_Data		<= (others => '0');
		Master_WP_Last		<= '0';
		Master_RP_Ack			<= '0';
		wait until rising_edge(Clock);

		-- Execute Quick Command Write
		Master_Request		<= '1';
		wait until (Master_Grant	= '1') and rising_edge(Clock);
		simAssertion((Master_Status = IO_IIC_STATUS_IDLE), "Master is not idle.");
		simAssertion((Master_Error = IO_IIC_ERROR_NONE), "Master claims an error");

		Master_Command		<= IO_IIC_CMD_QUICKCOMMAND_WRITE;
		Master_Address		<= "0101011";
		wait until rising_edge(Clock);
		Master_Command		<= IO_IIC_CMD_NONE;
		Master_Address		<= (others => '0');
		simAssertion((Master_Status	= IO_IIC_STATUS_EXECUTING), "Master should execute the command");

		wait until (Master_Status	/= IO_IIC_STATUS_EXECUTING) and rising_edge(Clock);
		simAssertion((Master_Status	= IO_IIC_STATUS_EXECUTE_OK), "Master should execute the command");
		Master_Request		<= '0';
		wait until rising_edge(Clock);

		-- Execute Quick Command Read
		Master_Request		<= '1';
		wait until (Master_Grant	= '1') and rising_edge(Clock);
		simAssertion((Master_Status = IO_IIC_STATUS_IDLE), "Master is not idle.");
		simAssertion((Master_Error = IO_IIC_ERROR_NONE), "Master claims an error");

		Master_Command		<= IO_IIC_CMD_QUICKCOMMAND_READ;
		Master_Address		<= "0101011";
		wait until rising_edge(Clock);
		Master_Command		<= IO_IIC_CMD_NONE;
		Master_Address		<= (others => '0');
		simAssertion((Master_Status	= IO_IIC_STATUS_EXECUTING), "Master should execute the command");

		wait until (Master_Status	/= IO_IIC_STATUS_EXECUTING) and rising_edge(Clock);
		simAssertion((Master_Status	= IO_IIC_STATUS_EXECUTE_OK), "Master should execute the command");
		Master_Request		<= '0';
		wait until rising_edge(Clock);

		-- Send Bytes
		Master_Request		<= '1';
		wait until (Master_Grant	= '1') and rising_edge(Clock);
		simAssertion((Master_Status = IO_IIC_STATUS_IDLE), "Master is not idle.");
		simAssertion((Master_Error = IO_IIC_ERROR_NONE), "Master claims an error");

		Master_Command		<= IO_IIC_CMD_SEND_BYTES;
		Master_Address		<= "0100011";
		Master_WP_Data		<= x"DE";
		wait until rising_edge(Clock);
		Master_Command		<= IO_IIC_CMD_NONE;
		Master_Address		<= (others => '0');
		simAssertion((Master_Status	= IO_IIC_STATUS_SENDING), "Master should execute the command");

		-- Master_WP_Valid		<= '1';
		Master_WP_Data		<= x"AD";
		wait until (Master_WP_Ack = '1') and rising_edge(Clock);
		-- Master_WP_Valid		<= '1';
		Master_WP_Data		<= x"BE";
		wait until (Master_WP_Ack = '1') and rising_edge(Clock);
		-- Master_WP_Valid		<= '1';
		Master_WP_Data		<= x"EF";
		Master_WP_Last		<= '1';
		wait until (Master_WP_Ack = '1') and rising_edge(Clock);
		-- Master_WP_Valid		<= '0';
		Master_WP_Data		<= x"00";
		Master_WP_Last		<= '0';


		-- wait until (Master_Status	/= IO_IIC_STATUS_SENDING) and rising_edge(Clock);
		-- simAssertion((Master_Status	= IO_IIC_STATUS_EXECUTE_OK), "Master should execute the command");
		-- Master_Request		<= '0';
		-- wait until rising_edge(Clock);

		wait for 100 us;

		-- This process is finished
		simDeactivateProcess(simProcessID);
		wait;  -- forever
	end process;

	procAck : process
		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Acknolegements");
	begin
		Slave1_SerialClock_o		<= '0';
		Slave1_SerialClock_t		<= '1';
		Slave1_SerialData_o			<= '0';
		Slave1_SerialData_t			<= '1';

		-- ack impulse -> Quick Command Write
		for i in 1 to 9 loop
			wait until falling_edge(Slave1_SerialClock_i);
		end loop;

		wait for 100 ns;
		Slave1_SerialData_t			<= '0';
		wait until rising_edge(Slave1_SerialClock_i);
		wait for 50 ns;
		Slave1_SerialData_t			<= '1';
		wait until rising_edge(Slave1_SerialClock_i);

		-- ack impulse -> Quick Command Read
		for i in 1 to 9 loop
			wait until falling_edge(Slave1_SerialClock_i);
		end loop;

		wait for 100 ns;
		Slave1_SerialData_t			<= '0';
		wait until rising_edge(Slave1_SerialClock_i);
		wait for 50 ns;
		Slave1_SerialData_t			<= '1';
		wait until rising_edge(Slave1_SerialClock_i);

		-- ack impulse -> Send Bytes
		-- Address ACK
		for i in 1 to 9 loop
			wait until falling_edge(Slave1_SerialClock_i);
		end loop;

		wait for 100 ns;
		Slave1_SerialData_t			<= '0';
		wait until rising_edge(Slave1_SerialClock_i);
		wait for 50 ns;
		Slave1_SerialData_t			<= '1';

		-- Data 0 ACK
		for i in 1 to 9 loop
			wait until falling_edge(Slave1_SerialClock_i);
		end loop;

		wait for 100 ns;
		Slave1_SerialData_t			<= '0';
		wait until rising_edge(Slave1_SerialClock_i);
		wait for 50 ns;
		Slave1_SerialData_t			<= '1';

		-- Data 1 ACK
		for i in 1 to 9 loop
			wait until falling_edge(Slave1_SerialClock_i);
		end loop;

		wait for 100 ns;
		Slave1_SerialData_t			<= '0';
		wait until rising_edge(Slave1_SerialClock_i);
		wait for 50 ns;
		Slave1_SerialData_t			<= '1';

		-- Data 2 ACK
		for i in 1 to 9 loop
			wait until falling_edge(Slave1_SerialClock_i);
		end loop;

		wait for 100 ns;
		Slave1_SerialData_t			<= '0';
		wait until rising_edge(Slave1_SerialClock_i);
		wait for 50 ns;
		Slave1_SerialData_t			<= '1';

		-- Data 3 ACK
		for i in 1 to 9 loop
			wait until falling_edge(Slave1_SerialClock_i);
		end loop;

		wait for 100 ns;
		Slave1_SerialData_t			<= '0';
		wait until rising_edge(Slave1_SerialClock_i);
		wait for 50 ns;
		Slave1_SerialData_t			<= '1';
		wait until rising_edge(Slave1_SerialClock_i);


		-- disable this slave
		Slave1_SerialClock_t		<= '1';
		Slave1_SerialData_t			<= '1';

		-- This process is finished
		simDeactivateProcess(simProcessID);
		wait;  -- forever
	end process;
end architecture;
