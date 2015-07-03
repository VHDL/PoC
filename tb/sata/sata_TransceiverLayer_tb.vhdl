-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Testbench:				Pseudo-Random Number Generator (PRNG).
-- 
-- Authors:					Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		Automated testbench for 'PoC.io_Debounce'.
--		TODO
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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
use			PoC.simulation.all;
use			PoC.io.all;
use			PoC.sata.all;
use			PoC.satadbg.all;
use			PoC.sata_TransceiverTypes.all;


entity sata_TransceiverLayer_tb is
end;


architecture test of sata_TransceiverLayer_tb is 
	-- simulation signals
	-- ===========================================================================
	signal SimStop								: STD_LOGIC 		:= '0';

	-- 
	-- ===========================================================================
	constant SATA_REFCLOCK_FREQ		: FREQ					:= 150 MHz;
	
	signal SATA_RefClock					: STD_LOGIC			:= '1';

	
	-- unit Under Test (UUT) configuration
	-- ===========================================================================
	

	-- unit under test signals
	-- ===========================================================================
	signal DebugPortIn					: T_SATADBG_TRANSCEIVER_IN;
 
	signal PowerDown						: STD_LOGIC;
	signal TX_Data							: T_SLV_32;
	signal TX_CharISK						: T_SLV_4;
 
	signal SATA_Common_In				: T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
	signal SATA_Private_In			: T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS;
	signal SATA_Private_Out			: T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS;
	
begin
	-- common clock generation
	SATA_RefClock <= SATA_RefClock xnor SimStop after (to_time(SATA_REFCLOCK_FREQ) / 2.0);
	
	SATA_Common_In.RefClockIn_150_MHz	<= SATA_RefClock;
	
	DebugPortIn.ForceOOBCommand				<= SATA_OOB_NONE;
	DebugPortIn.ForceTXElectricalIDLE	<= '0';
	
	PowerDown		<= '0';
	
	TX_Data			<= to_sata_word(SATA_PRIMITIVE_ALIGN);
	TX_CharIsK	<= "0001";	
	
	SATA_Private_In.RX_n			<= SATA_Private_Out.TX_n;
	SATA_Private_In.RX_p			<= SATA_Private_Out.TX_p;
	
	process
	begin
		wait for 10 us;

		-- shut down simulation

		
		-- final assertion
		--tbAssert((EventCounter = 4), "Events counted=" & INTEGER'image(EventCounter) &	" Expected=4");
		
		-- Report overall simulation result
		tbPrintResult;
		SimStop	<= '1';
		wait;
	end process;

	
	uut : ENTITY PoC.sata_Transceiver_Series7_GTXE2
		GENERIC MAP (
			DEBUG												=> TRUE,
			ENABLE_DEBUGPORT						=> TRUE,
			CLOCK_IN_FREQ_MHZ						=> 150.0,
			PORTS												=> 1,													-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS		=> (0 => SATA_GENERATION_2)		-- intial SATA Generation
		)
		PORT MAP (
			ClockNetwork_Reset(0)				=> '0',
			ClockNetwork_ResetDone			=> OPEN,
	
			PowerDown(0)								=> PowerDown,
			Reset(0)										=> '0',
			ResetDone										=> OPEN,

			SATA_Clock									=> OPEN,

			Command(0)									=> SATA_TRANSCEIVER_CMD_NONE,
			Status											=> OPEN,
			RX_Error										=> OPEN,
			TX_Error										=> OPEN,
	
			DebugPortIn(0)							=> DebugPortIn,
			DebugPortOut								=> OPEN,

			TX_Data(0)									=> TX_Data,
			TX_CharIsK(0)								=> TX_CharIsK,
	
			RX_Data											=> OPEN,
			RX_CharIsK									=> OPEN,
			RX_IsAligned								=> OPEN,
			
			RP_Reconfig(0)							=> '0',
			RP_SATAGeneration(0)				=> SATA_GENERATION_2,
			RP_ReconfigComplete					=> OPEN,
			RP_ConfigReloaded						=> OPEN,
			RP_Lock(0)									=> '0',
			RP_Locked										=> OPEN,
			
			OOB_TX_Command(0)						=> SATA_OOB_NONE,
			OOB_TX_Complete							=> OPEN,
			OOB_RX_received							=> OPEN,
			OOB_HandshakeComplete(0)		=> '0',

			-- vendor specific signals
			VSS_Common_In								=> SATA_Common_In,
			VSS_Private_In(0)						=> SATA_Private_In,
			VSS_Private_Out(0)					=> SATA_Private_Out
		);
END;
