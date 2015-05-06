-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Package:					TODO
--
-- Description:
-- ------------------------------------
-- Executes the COMRESET / COMINIT procedure.
--
-- The Clock might be only unstable in two states: ST_HOST_RESET and
-- ST_HOST_TIMEOUT. This is accomplished by:
--
-- a) During Power-up or a ClockNetwork_Reset this unit must be hold in the
--    reset state ST_HOST_RESET. Asserting Retry is only permitted after the
--    clock is stable.
--
-- b) Before reconfiguration on behalf of the SpeedController, this unit must
-- 	  enter on one the states listed above. Asserting Retry is only permitted
-- 	  after the clock is stable again (after reconfiguration).
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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

use			STD.TextIO.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.components.all;
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_Physical_OOBControl_Host is
	generic (
		DEBUG											: BOOLEAN														:= FALSE;												-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN														:= FALSE;												-- enables the assignment of signals to the debugport
		CLOCK_FREQ								: FREQ															:= 150.0 MHz;										-- 
		ALLOW_STANDARD_VIOLATION	: BOOLEAN														:= FALSE;
		OOB_TIMEOUT								: TIME															:= TIME'low
	);
	port (
		Clock											: in	STD_LOGIC;
		Reset											: in	STD_LOGIC;
		-- debug ports
		DebugPortOut							: out	T_SATADBG_PHYSICAL_OOBCONTROL_OUT;

		Retry											: in	STD_LOGIC;
		Timeout										: out	STD_LOGIC;
		SATAGeneration						: in	T_SATA_GENERATION;
		LinkOK										: out	STD_LOGIC;
		LinkDead									: out	STD_LOGIC;
		ReceivedReset							: out	STD_LOGIC;
		
		Trans_Status							: in	T_SATA_TRANSCEIVER_STATUS;
		Trans_Error								: in	T_SATA_TRANSCEIVER_ERROR;
		
		OOB_TX_Command						: out	T_SATA_OOB;
		OOB_TX_Complete						: in	STD_LOGIC;
		OOB_RX_Received						: in	T_SATA_OOB;
		OOB_HandshakeComplete			:	OUT	STD_LOGIC; 	-- MUST BE driven by register
		
		TX_Primitive							: out	T_SATA_PRIMITIVE;
		RX_Primitive							: in	T_SATA_PRIMITIVE;
		RX_Valid									: in	STD_LOGIC
	);
end;


architecture rtl of sata_Physical_OOBControl_Host is
	attribute KEEP												: BOOLEAN;
	attribute FSM_ENCODING								: STRING;

	constant CLOCK_GEN1_FREQ							: FREQ				:= CLOCK_FREQ / 4.0;			-- SATAClock frequency in MHz for SATA generation 1
	constant CLOCK_GEN2_FREQ							: FREQ				:= CLOCK_FREQ / 2.0;			-- SATAClock frequency in MHz for SATA generation 2
	constant CLOCK_GEN3_FREQ							: FREQ				:= CLOCK_FREQ / 1.0;			-- SATAClock frequency in MHz for SATA generation 3

	constant DEFAULT_OOB_TIMEOUT					: TIME				:= 880.0 us;
	constant CONSECUTIVE_ALIGN_MIN				: POSITIVE		:= 63;
	
	constant OOB_TIMEOUT_I								: TIME				:= ite((OOB_TIMEOUT = TIME'low), DEFAULT_OOB_TIMEOUT, OOB_TIMEOUT);
	constant COMRESET_TIMEOUT							: TIME				:= 450.0 ns;
	constant COMWAKE_TIMEOUT							: TIME				:= 250.0 ns;

	constant TTID1_OOB_TIMEOUT_GEN1				: NATURAL			:= 0;
	constant TTID1_OOB_TIMEOUT_GEN2				: NATURAL			:= 1;
	constant TTID1_OOB_TIMEOUT_GEN3				: NATURAL			:= 2;
	constant TTID2_COMRESET_TIMEOUT_GEN1	: NATURAL			:= 0;
	constant TTID2_COMRESET_TIMEOUT_GEN2	: NATURAL			:= 1;
	constant TTID2_COMRESET_TIMEOUT_GEN3	: NATURAL			:= 2;
	constant TTID2_COMWAKE_TIMEOUT_GEN1		: NATURAL			:= 3;
	constant TTID2_COMWAKE_TIMEOUT_GEN2		: NATURAL			:= 4;
	constant TTID2_COMWAKE_TIMEOUT_GEN3		: NATURAL			:= 5;

	constant TC1_TIMING_TABLE					: T_NATVEC				:= (--		 880 us
		TTID1_OOB_TIMEOUT_GEN1 => TimingToCycles(OOB_TIMEOUT_I,	CLOCK_GEN1_FREQ),							-- slot 0
		TTID1_OOB_TIMEOUT_GEN2 => TimingToCycles(OOB_TIMEOUT_I,	CLOCK_GEN2_FREQ),							-- slot 1
		TTID1_OOB_TIMEOUT_GEN3 => TimingToCycles(OOB_TIMEOUT_I,	CLOCK_GEN3_FREQ)							-- slot 2
	);
	
	constant TC2_TIMING_TABLE					: T_NATVEC				:= (
		TTID2_COMRESET_TIMEOUT_GEN1	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN1_FREQ),		-- slot 0
		TTID2_COMRESET_TIMEOUT_GEN2	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN2_FREQ),		-- slot 1
		TTID2_COMRESET_TIMEOUT_GEN3	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN3_FREQ),		-- slot 2
		TTID2_COMWAKE_TIMEOUT_GEN1	=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN1_FREQ),		-- slot 3
		TTID2_COMWAKE_TIMEOUT_GEN2	=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN2_FREQ),		-- slot 4
		TTID2_COMWAKE_TIMEOUT_GEN3	=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN3_FREQ)		-- slot 5
	);

	type T_STATE is (
		ST_HOST_RESET,
		ST_HOST_SEND_COMRESET,
		ST_HOST_SEND_COMRESET_WAIT,
		ST_HOST_WAIT_DEV_COMINIT,
		ST_HOST_WAIT_AFTER_DEV_COMINIT,
		ST_HOST_SEND_COMWAKE,
		ST_HOST_SEND_COMWAKE_WAIT,
		ST_HOST_WAIT_DEV_COMWAKE,
		ST_HOST_WAIT_AFTER_COMWAKE,
		ST_HOST_WAIT_DEV_NORMAL_MODE,
		ST_HOST_OOB_HANDSHAKE_COMPLETE,
		ST_HOST_SEND_D10_2,
		ST_HOST_SEND_ALIGN,
		ST_HOST_TIMEOUT,
		ST_HOST_LINK_OK,
		ST_HOST_LINK_BROKEN,
		ST_HOST_LINK_DEAD
	);

	-- OOB-Statemachine
	signal State											: T_STATE													:= ST_HOST_RESET;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING of State		: signal is getFSMEncoding_gray(DEBUG);

	signal LinkOK_i										: STD_LOGIC;
	signal LinkDead_i									: STD_LOGIC;
	signal Timeout_i									: STD_LOGIC;
	signal ReceivedReset_i						: STD_LOGIC;

	signal OOB_TX_Command_i						: T_SATA_OOB;
	signal OOB_HandshakeComplete_i		: STD_LOGIC; 	-- MUST BE driven by register

	signal AlignCounter_rst						: STD_LOGIC;
	signal AlignCounter_en						: STD_LOGIC;
	signal AlignCounter_us						: UNSIGNED(log2ceilnz(CONSECUTIVE_ALIGN_MIN) - 1 downto 0)						:= (others => '0');

	-- Timing-Counter
	-- ===========================================================================
	-- general timeouts
	signal TC1_en										: STD_LOGIC;
	signal TC1_Load									: STD_LOGIC;
	signal TC1_Slot									: NATURAL;
	signal TC1_Timeout							: STD_LOGIC;
	
	-- OOB state specific timeouts
	signal TC2_en										: STD_LOGIC;
	signal TC2_Load									: STD_LOGIC;
	signal TC2_Slot									: NATURAL;
	signal TC2_Timeout							: STD_LOGIC;	
	
begin
	assert ((SATAGeneration = SATA_GENERATION_1) or
					(SATAGeneration = SATA_GENERATION_2) or
					(SATAGeneration = SATA_GENERATION_3))
		report "Member of T_SATA_GENERATION not supported"
		severity FAILURE;

	-- OOBControl Statemachine
	-- ======================================================================================================================================
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State			<= ST_HOST_RESET;
			else
				State			<= NextState;
			end if;
		end if;
	end process;


	process(State, SATAGeneration, Retry, OOB_TX_Complete, OOB_RX_Received, RX_Valid, RX_Primitive, AlignCounter_us, TC1_Timeout, TC2_Timeout, Trans_Status, Trans_Error.RX)
	begin
		NextState									<= State;
		
		TX_Primitive							<= SATA_PRIMITIVE_ALIGN;			-- TODO: check if it's better to send ALIGN or DIAL_TONE
	
		AlignCounter_rst					<= '0';
		AlignCounter_en						<= '0';
	
		-- general timeout
		TC1_en										<= '0';
		TC1_Load									<= '0';
		TC1_Slot									<= 0;
		
		-- OOB state specific timeouts
		TC2_en										<= '0';
		TC2_Load									<= '0';
		TC2_Slot									<= 0;
	
		LinkOK_i									<= '0';
		LinkDead_i								<= '0';
		Timeout_i									<= '0';
		ReceivedReset_i						<= '0';
		
		OOB_TX_Command_i					<= SATA_OOB_NONE;
		OOB_HandshakeComplete_i		<= '0'; 	-- MUST BE driven by register

		DebugPortOut.AlignDetected	<= '0';

			case State is
				when ST_HOST_RESET =>
					-- Clock might be unstable when FSM is in this state. See description
					-- in header.
					if (Retry = '1') then
						NextState							<= ST_HOST_SEND_COMRESET;
					end if;
			
				when ST_HOST_SEND_COMRESET =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					OOB_TX_Command_i				<= SATA_OOB_COMRESET;
					TC1_en									<= '1';
						
					TC1_Load								<= '1';
					TC1_Slot								<= ite((SATAGeneration = SATA_GENERATION_1), TTID1_OOB_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID1_OOB_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID1_OOB_TIMEOUT_GEN3,
																																							 TTID1_OOB_TIMEOUT_GEN3)));
					NextState								<= ST_HOST_SEND_COMRESET_WAIT;
			
				when ST_HOST_SEND_COMRESET_WAIT =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif (OOB_TX_Complete = '1') then
						NextState							<= ST_HOST_WAIT_DEV_COMINIT;
					elsif ((ALLOW_STANDARD_VIOLATION = TRUE) and (OOB_RX_Received = SATA_OOB_COMRESET)) then					-- allow premature OOB response
						NextState							<= ST_HOST_WAIT_AFTER_DEV_COMINIT;
					end if;
					
				when ST_HOST_WAIT_DEV_COMINIT =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif (OOB_RX_Received = SATA_OOB_COMRESET) then																										-- device cominit detected
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMRESET_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMRESET_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMRESET_TIMEOUT_GEN3,
																																							 TTID2_COMRESET_TIMEOUT_GEN3)));
						
						NextState							<= ST_HOST_WAIT_AFTER_DEV_COMINIT;
					end if;
		
				when ST_HOST_WAIT_AFTER_DEV_COMINIT =>
					TC2_en									<= '1';
					TC1_en									<= '1';

					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif (OOB_RX_Received = SATA_OOB_COMRESET) then
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMRESET_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMRESET_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMRESET_TIMEOUT_GEN3,
																																							 TTID2_COMRESET_TIMEOUT_GEN3)));
					elsif (TC2_Timeout = '1') then
						NextState							<= ST_HOST_SEND_COMWAKE;
					end if;

				when ST_HOST_SEND_COMWAKE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					OOB_TX_Command_i				<= SATA_OOB_COMWAKE;
					TC1_en									<= '1';
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					else
						NextState							<= ST_HOST_SEND_COMWAKE_WAIT;
					end if;
					
				when ST_HOST_SEND_COMWAKE_WAIT =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif (OOB_TX_Complete = '1') then
						NextState							<= ST_HOST_WAIT_DEV_COMWAKE;
					elsif ((ALLOW_STANDARD_VIOLATION = TRUE) and (OOB_RX_Received = SATA_OOB_COMWAKE)) then						-- allow premature OOB response
						NextState							<= ST_HOST_WAIT_AFTER_COMWAKE;
					end if;
				
				when ST_HOST_WAIT_DEV_COMWAKE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;	--SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif (OOB_RX_Received = SATA_OOB_COMWAKE) then																											-- device comwake detected
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMWAKE_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMWAKE_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMWAKE_TIMEOUT_GEN3,
																																							 TTID2_COMWAKE_TIMEOUT_GEN3)));
					
						NextState							<= ST_HOST_WAIT_AFTER_COMWAKE;
					elsif ((ALLOW_STANDARD_VIOLATION = TRUE) and (OOB_RX_Received = SATA_OOB_COMRESET)) then					-- device COMINIT detected, but COMWAKE expected
						NextState							<= ST_HOST_SEND_COMWAKE;
					end if;
				
				when ST_HOST_WAIT_AFTER_COMWAKE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;
					TC1_en									<= '1';
					TC2_en									<= '1';

					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif (OOB_RX_Received = SATA_OOB_COMWAKE) then
						TC2_Load							<= '1';
						TC2_Slot							<= ite((SATAGeneration = SATA_GENERATION_1), TTID2_COMWAKE_TIMEOUT_GEN1,
																		 ite((SATAGeneration = SATA_GENERATION_2), TTID2_COMWAKE_TIMEOUT_GEN2,
																		 ite((SATAGeneration = SATA_GENERATION_3), TTID2_COMWAKE_TIMEOUT_GEN3,
																																							 TTID2_COMWAKE_TIMEOUT_GEN3)));
					elsif (TC2_Timeout = '1') then
						NextState							<= ST_HOST_WAIT_DEV_NORMAL_MODE;
					end if;
				
				when ST_HOST_WAIT_DEV_NORMAL_MODE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;
					TC1_en									<= '1';
				
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif (OOB_RX_Received = SATA_OOB_NONE) then
						NextState							<= ST_HOST_OOB_HANDSHAKE_COMPLETE;
					end if;
				
				when ST_HOST_OOB_HANDSHAKE_COMPLETE =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;
					OOB_HandshakeComplete_i	<= '1'; 	-- MUST BE driven by register
					TC1_en									<= '1';
						
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					else
						NextState								<= ST_HOST_SEND_D10_2;
					end if;
					
				when ST_HOST_SEND_D10_2 =>
					TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;
					AlignCounter_rst				<= '1';
					TC1_en									<= '1';
					
					-- TODO
					-- 		wait for 53,3 ns (64 UIs ~= 2 Gen1-DWords) before accepting ALIGN (<= crosstalking)
					--		source: ATA8-AST page 75, transition HP8:HP9, => note text
					
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif ((ALLOW_STANDARD_VIOLATION = FALSE) and (OOB_RX_Received /= SATA_OOB_NONE)) then				-- disallow OOB signals after "OOB_HandshakeComplete"
						NextState							<= ST_HOST_LINK_DEAD;
					elsif ((RX_Primitive = SATA_PRIMITIVE_ALIGN) and (RX_Valid = '1')) then										-- ALIGN detected
						AlignCounter_rst			<= '0';
						AlignCounter_en				<= '1';
					
						DebugPortOut.AlignDetected	<= '1';
						
						if (AlignCounter_us = CONSECUTIVE_ALIGN_MIN - 1) then
							nextstate						<= st_host_send_align;
						end if;
					end if;
				
				when ST_HOST_SEND_ALIGN =>
					TX_Primitive						<= SATA_PRIMITIVE_ALIGN;
					TC1_en									<= '1';
				
					if (TC1_Timeout = '1') then
						NextState 						<= ST_HOST_TIMEOUT;
					elsif (OOB_RX_Received /= SATA_OOB_NONE) then
						NextState							<= ST_HOST_LINK_DEAD;
					elsif ((Trans_Status = SATA_TRANSCEIVER_STATUS_ERROR) and (Trans_Error.RX /= SATA_TRANSCEIVER_RX_ERROR_NONE)) then
						NextState							<= ST_HOST_LINK_BROKEN;
					elsif (RX_Primitive = SATA_PRIMITIVE_SYNC) then																				-- SYNC detected
						NextState							<= ST_HOST_LINK_OK;
					end if;
					
				when ST_HOST_LINK_OK =>
					LinkOK_i								<= '1';
					TX_Primitive						<= SATA_PRIMITIVE_NONE;
					
					if (OOB_RX_Received /= SATA_OOB_NONE) then
						NextState							<= ST_HOST_LINK_DEAD;
					elsif ((Trans_Status = SATA_TRANSCEIVER_STATUS_ERROR) and (Trans_Error.RX /= SATA_TRANSCEIVER_RX_ERROR_NONE)) then
						NextState							<= ST_HOST_LINK_BROKEN;
					end if;
				
				when ST_HOST_LINK_BROKEN =>
					TX_Primitive						<= SATA_PRIMITIVE_ALIGN;
					
					if (RX_Valid = '1') then
						NextState							<= ST_HOST_LINK_OK;
					end if;
					
					if (Retry = '1') then
						NextState							<= ST_HOST_SEND_COMRESET;
					end if;
				
				when ST_HOST_LINK_DEAD =>
					LinkDead_i							<= '1';
					
					if (Retry = '1') then
						nextstate							<= st_host_send_comreset;
					end if;
				
				when ST_HOST_TIMEOUT =>
					-- Clock might be unstable when FSM is in this state. See description
					-- in header.
					Timeout_i								<= '1';
				
					if (Retry = '1') then
						NextState							<= ST_HOST_SEND_COMRESET;
					end if;
				
			end case;
	end process;
	
	LinkOK									<= LinkOK_i;
	LinkDead								<= LinkDead_i;
	Timeout									<= Timeout_i;
	ReceivedReset						<= ReceivedReset_i;

	OOB_TX_Command					<= OOB_TX_Command_i;
	OOB_HandshakeComplete		<= OOB_HandshakeComplete_i; 	-- MUST BE driven by register
	
	AlignCounter_us <= counter_inc(cnt => AlignCounter_us, rst => AlignCounter_rst, en => AlignCounter_en) when rising_edge(Clock);
	
	-- overall timeout counter
	TC1 : entity PoC.io_TimingCounter
		generic map (							-- timing table
			TIMING_TABLE				=> TC1_TIMING_TABLE
		)
		port map (
			Clock								=> Clock,
			Enable							=> TC1_en,
			Load								=> TC1_load,
			Slot								=> TC1_Slot,
			Timeout							=> TC1_Timeout
		);
	
	-- timeout counter for *_WAIT_AFTER_* states
	TC2 : entity PoC.io_TimingCounter
		generic map (							-- timing table
			TIMING_TABLE				=> TC2_TIMING_TABLE
		)
		port map (
			Clock								=> Clock,
			Enable							=> TC2_en,
			Load								=> TC2_load,
			Slot								=> TC2_Slot,
			Timeout							=> TC2_Timeout
		);
	
	-- debug port
	-- ===========================================================================
	genDebugPort : IF (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeState(st : T_STATE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_STATE'pos(st), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
		end function;
	begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_GenerateEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_STATE loop
					STD.TextIO.write(l, str_replace(T_STATE'image(i), "st_host_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			constant dummy : boolean := dbg_ExportEncoding("OOBControl (Host)", dbg_GenerateEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/FSM_OOBControl_Host.tok");
		begin
		end generate;
		
		DebugPortOut.FSM												<= dbg_EncodeState(State);
		DebugPortOut.Retry											<= Retry;
		DebugPortOut.Timeout										<= Timeout_i;
		DebugPortOut.LinkOK											<= LinkOK_i;
		DebugPortOut.LinkDead										<= LinkDead_i;
		DebugPortOut.ReceivedReset							<= ReceivedReset_i;
		
		DebugPortOut.OOB_TX_Command							<= OOB_TX_Command_i;
		DebugPortOut.OOB_TX_Complete						<= OOB_TX_Complete;
		DebugPortOut.OOB_RX_Received						<= OOB_RX_Received;
		DebugPortOut.OOB_HandshakeComplete			<= OOB_HandshakeComplete_i;		
	end generate;
end;
