-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Patrick Lehmann
--
-- Testbench:				For PoC.io.pio.fifo
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
use			PoC.io.all;
-- simulation only packages
use			PoC.sim_types.all;
use			PoC.simulation.all;
use			PoC.waveform.all;


entity pio_fifo_tb is
end entity;


architecture tb of pio_fifo_tb is
	constant CLOCK_1_FREQ				: FREQ						:= 100 MHz;
	constant CLOCK_2_FREQ				: FREQ						:= 100 MHz;

	constant DATARATE						: T_IO_DATARATE		:= IO_DATARATE_SDR;
	constant BITS								: positive				:= 8;

	signal Clock_1							: std_logic;
	signal Reset_1							: std_logic;

	signal put									: std_logic;
	signal DataIn								: std_logic_vector(BITS - 1 downto 0);
	signal Full									: std_logic;

	signal UUT1_Clock						: std_logic;
	signal UUT1_DataOut					: std_logic_vector(BITS downto 0);

	signal UUT2_DataOut					: std_logic_vector(0 downto 0);

	signal Wire_Clock						: std_logic;
	signal Wire_Data12					: std_logic_vector(UUT1_DataOut'range);
	signal Wire_Data21					: std_logic_vector(UUT2_DataOut'range);

	signal Clock_2							: std_logic;
	signal Reset_2							: std_logic;

	signal got									: std_logic;
	signal DataOut							: std_logic_vector(BITS - 1 downto 0);
	signal Valid								: std_logic;

begin
	simGenerateClock(Clock_1, Frequency => CLOCK_1_FREQ, Phase =>  0.0 deg, Wander => 0 permil);
	simGenerateClock(Clock_2, Frequency => CLOCK_2_FREQ, Phase => 90.0 deg, Wander => 10 permil);

	simGenerateWaveform(Reset_1, simGenerateWaveform_Reset(Pause => 10 ns));

	procGenerator : process
		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Generator");
	begin
		put				<= '0';
		DataIn		<= x"00";

		for i in 1 to 128 loop
			put			<= '1';
			DataIn	<= to_slv(i, DataIn'length);
			wait until rising_edge(Clock_1);
		end loop;

		put				<= '0';
		simWaitUntilRisingEdge(Clock_1, 10);

		-- This process is finished
		simDeactivateProcess(simProcessID);
		wait;  -- forever
	end process;

	UUT1 : entity PoC.pio_fifo_out
		generic map (
			DATARATE		=> IO_DATARATE_SDR,
			BITS				=> BITS
		)
		port map (
			Clock				=> Clock_1,
			Reset				=> Reset_2,

			put					=> put,
			DataIn			=> DataIn,
			Full				=> Full,

			Pad_Clock		=> UUT1_Clock,
			Pad_DataOut	=> UUT1_DataOut,
			Pad_DataIn	=> Wire_Data21
		);

	blkWire : block
		constant DELAYS12		: T_TIMEVEC		:= (UUT1_DataOut'range => 4 ns);
		constant DELAYS21		: T_TIMEVEC		:= (UUT2_DataOut'range => 5 ns);
	begin
		Wire_Clock	<= UUT1_Clock'delayed(4 ns);
		genWires12 : for i in UUT1_DataOut'range generate
			Wire_Data12(i)	<= UUT1_DataOut(i)'delayed(DELAYS12(i));
		end generate;
		genWires21 : for i in UUT2_DataOut'range generate
			Wire_Data21(i)	<= UUT2_DataOut(i)'delayed(DELAYS21(i));
		end generate;
	end block;

	UUT2 : entity PoC.pio_fifo_in
		generic map (
			DATARATE		=> DATARATE,
			BITS				=> BITS
		)
		port map (
			Clock				=> Clock_2,
			Reset				=> Reset_2,

			got					=> got,
			DataOut			=> DataOut,
			Valid				=> Valid,

			Pad_Clock		=> Wire_Clock,
			Pad_DataIn	=> Wire_Data12,
			Pad_DataOut	=> UUT2_DataOut
		);

	procChecker : process
		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Checker");
	begin
		got			<= '0';

		for i in 1 to 128 loop
			wait until (Valid = '1') and rising_edge(Clock_2);
			got		<= '1';
		end loop;

		got			<= '0';

		simWaitUntilRisingEdge(Clock_2, 10);

		-- This process is finished
		simDeactivateProcess(simProcessID);
		wait;  -- forever
	end process;

end architecture;
