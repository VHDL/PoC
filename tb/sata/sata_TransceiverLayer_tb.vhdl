-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Testbench:				SATA Transceiver Layer
--
-- Description:
-- ------------------------------------
--		Automated testbench for 'PoC.sata.TransceiverLayer'.
--		TODO
--
-- License:
-- =============================================================================
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
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.io.all;
use			PoC.sata.all;
use			PoC.satadbg.all;
use			PoC.sata_TransceiverTypes.all;
-- simulation only packages
use			PoC.sim_types.all;
use			PoC.simulation.all;
use			PoC.waveform.all;


entity sata_TransceiverLayer_tb is
end entity;


architecture tb of sata_TransceiverLayer_tb is
	constant SATA_REFCLOCK_FREQ			: FREQ					:= 150 MHz;
	constant CLOCK_FREQ							: FREQ					:= 100 MHz;

	-- ===========================================================================
	signal SATA_RefClock						: STD_LOGIC;

	-- unit Under Test (UUT) configuration
	-- ===========================================================================


	-- unit under test signals
	-- ===========================================================================
	signal DebugPortIn					: T_SATADBG_TRANSCEIVER_IN;

	signal PowerDown						: STD_LOGIC;
	signal TX_Data							: T_SLV_32;
	signal TX_CharIsK						: T_SLV_4;

	signal SATA_Common_In				: T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
	signal SATA_Private_In			: T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS;
	signal SATA_Private_Out			: T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS;

begin
	-- initialize global simulation status
	simInitialize(MaxSimulationRuntime => 11 us);
	-- generate global testbench clock and reset
	simGenerateClock(SATA_RefClock, SATA_REFCLOCK_FREQ);

	SATA_Common_In.RefClockIn_150_MHz	<= SATA_RefClock;

	DebugPortIn.ForceOOBCommand				<= SATA_OOB_NONE;
	DebugPortIn.ForceTXElectricalIDLE	<= '0';

	PowerDown		<= '0';

	TX_Data			<= to_sata_word(SATA_PRIMITIVE_ALIGN);
	TX_CharIsK	<= "0001";

	SATA_Private_In.RX_n			<= SATA_Private_Out.TX_n;
	SATA_Private_In.RX_p			<= SATA_Private_Out.TX_p;

	procGenerator : process
		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Generator");
	begin
		wait for 10 us;
		-- shut down simulation

		-- final assertion
		--simAssertion((EventCounter = 4), "Events counted=" & INTEGER'image(EventCounter) &	" Expected=4");

		-- This process is finished
		simDeactivateProcess(simProcessID);
		wait;  -- forever
	end process;


	UUT : entity PoC.sata_Transceiver_Series7_GTXE2
		generic map (
			DEBUG												=> TRUE,
			ENABLE_DEBUGPORT						=> TRUE,
			REFCLOCK_FREQ								=> SATA_REFCLOCK_FREQ,
			PORTS												=> 1,													-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS		=> (0 => SATA_GENERATION_2)		-- intial SATA Generation
		)
		port map (
			ClockNetwork_Reset(0)				=> '0',
			ClockNetwork_ResetDone			=> open,

			PowerDown(0)								=> PowerDown,
			Reset(0)										=> '0',
			ResetDone										=> open,

			SATA_Clock									=> open,

			Command(0)									=> SATA_TRANSCEIVER_CMD_NONE,
			Status											=> open,
			Error												=> open,

			DebugPortIn(0)							=> DebugPortIn,
			DebugPortOut								=> open,

			RP_Reconfig(0)							=> '0',
			RP_SATAGeneration(0)				=> SATA_GENERATION_2,
			RP_ReconfigComplete					=> open,
			RP_ConfigReloaded						=> open,
			RP_Lock(0)									=> '0',
			RP_Locked										=> open,

			OOB_TX_Command(0)						=> SATA_OOB_NONE,
			OOB_TX_Complete							=> open,
			OOB_RX_Received							=> open,
			OOB_HandshakeComplete(0)		=> '0',
			OOB_AlignDetected(0)				=> '0',

			TX_Data(0)									=> TX_Data,
			TX_CharIsK(0)								=> TX_CharIsK,

			RX_Data											=> open,
			RX_CharIsK									=> open,
			RX_Valid										=> open,

			-- vendor specific signals
			VSS_Common_In								=> SATA_Common_In,
			VSS_Private_In(0)						=> SATA_Private_In,
			VSS_Private_Out(0)					=> SATA_Private_Out
		);
end architecture;
