-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Package:					TODO
--
-- Description:
-- ------------------------------------
--		TODO
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

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_PhysicalLayer is
	generic (
		DEBUG														: BOOLEAN													:= FALSE;
		ENABLE_DEBUGPORT								: BOOLEAN													:= FALSE;
		CLOCK_FREQ											: FREQ														:= 150.0 MHz;
		CONTROLLER_TYPE									: T_SATA_DEVICE_TYPE							:= SATA_DEVICE_TYPE_HOST;
		ALLOW_SPEED_NEGOTIATION					: BOOLEAN													:= TRUE;
		INITIAL_SATA_GENERATION					: T_SATA_GENERATION								:= C_SATA_GENERATION_MAX;
		ALLOW_AUTO_RECONNECT						: BOOLEAN													:= TRUE;
		ALLOW_STANDARD_VIOLATION				: BOOLEAN													:= FALSE;
		OOB_TIMEOUT											: TIME														:= TIME'low;
		GENERATION_CHANGE_COUNT					: INTEGER													:= 8;
		ATTEMPTS_PER_GENERATION					: INTEGER													:= 4
	);
	port (
		Clock														: in	STD_LOGIC;
		ClockEnable											: in	STD_LOGIC;
		Reset														: in	STD_LOGIC;										-- general logic reset without some counter resets while Clock is unstable
																																				--   => preserve SATAGeneration between connection-cycles
		SATAGenerationMin								: in	T_SATA_GENERATION;						-- 
		SATAGenerationMax								: in	T_SATA_GENERATION;						-- 

		-- PhysicalLayer interface
		Command													: in	T_SATA_PHY_COMMAND;
		Status													: out	T_SATA_PHY_STATUS;
		Error														: out	T_SATA_PHY_ERROR;

		DebugPortOut										: out	T_SATADBG_PHYSICAL_OUT;

		Link_RX_Data										: out	T_SLV_32;
		Link_RX_CharIsK									: out	T_SLV_4;
		
		Link_TX_Data										: in	T_SLV_32;
		Link_TX_CharIsK									: in	T_SLV_4;

		-- TransceiverLayer interface
		Trans_ResetDone									: in	STD_LOGIC;
		
		Trans_Command										: out	T_SATA_TRANSCEIVER_COMMAND;
		Trans_Status										: in	T_SATA_TRANSCEIVER_STATUS;
		Trans_Error											: in	T_SATA_TRANSCEIVER_ERROR;

		Trans_RP_Reconfig								: out	STD_LOGIC;
		Trans_RP_SATAGeneration					: out	T_SATA_GENERATION;
		Trans_RP_ReconfigComplete				: in	STD_LOGIC;
		Trans_RP_ConfigReloaded					: in	STD_LOGIC;
		Trans_RP_Lock										: out	STD_LOGIC;
		Trans_RP_Locked									: in	STD_LOGIC;

		Trans_OOB_TX_Command						: out	T_SATA_OOB;
		Trans_OOB_TX_Complete						: in	STD_LOGIC;
		Trans_OOB_RX_Received						: in	T_SATA_OOB;
		Trans_OOB_HandshakeComplete			: out	STD_LOGIC;		

		Trans_TX_Data										: out	T_SLV_32;
		Trans_TX_CharIsK								: out T_SLV_4;

		Trans_RX_Data										: in	T_SLV_32;
		Trans_RX_CharIsK								: in	T_SLV_4;
		Trans_RX_Valid									: in	STD_LOGIC
	);
END;


architecture rtl of sata_PhysicalLayer is
	attribute KEEP						: BOOLEAN;
	attribute FSM_ENCODING		: STRING;
	
	type T_STATE is (
		ST_RESET,
		ST_LINK_UP,
		ST_CHANGE_SPEED,
		ST_LINK_OK,
		ST_LINK_BROKEN,
		ST_ERROR
	);
	
	signal State											: T_STATE													:= ST_RESET;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING of State		: signal is getFSMEncoding_gray(DEBUG);

	signal Reset_i 										: STD_LOGIC;
	signal Status_i										: T_SATA_PHY_STATUS;

	signal FSM_SC_Reset								: STD_LOGIC;
	signal FSM_SC_Command							: T_SATA_PHY_SPEED_COMMAND;
	
	signal SC_Status									: T_SATA_PHY_SPEED_STATUS;	
	signal SC_OOBC_Reset							: STD_LOGIC;
	signal SC_OOBC_Retry							: STD_LOGIC;
	signal SC_SATAGeneration					: T_SATA_GENERATION;
		
	signal OOBC_Reset									: STD_LOGIC;
	signal OOBC_LinkOK								: STD_LOGIC;
	signal OOBC_LinkDead							: STD_LOGIC;
	signal OOBC_Timeout								: STD_LOGIC;
	signal OOBC_Timeout_d							: STD_LOGIC;
	signal OOBC_Timeout_re						: STD_LOGIC;
	signal OOBC_ReceivedReset					: STD_LOGIC;

	signal ResetGeneration						: STD_LOGIC;
	signal ResetTrysPerGeneration_i		: STD_LOGIC;
	signal Trans_RP_Reconfig_i				: STD_LOGIC;

	signal OOBC_TX_Primitive					: T_SATA_PRIMITIVE;
	signal RX_Primitive								: T_SATA_PRIMITIVE;
	signal Trans_TX_Data_i						: T_SLV_32;
	signal Trans_TX_CharIsK_i					: T_SLV_4;
	
	signal OOBC_DebugPortOut					: T_SATADBG_PHYSICAL_OOBCONTROL_OUT;
	signal SC_DebugPortOut						: T_SATADBG_PHYSICAL_SPEEDCONTROL_OUT;
	
	signal Error_rst									: STD_LOGIC;
	signal Error_en										: STD_LOGIC;
	signal Error_nxt									: T_SATA_PHY_ERROR;
	
begin

	assert FALSE report "Physical Layer"																															severity NOTE;
	assert FALSE report "  ControllerType:         " & T_SATA_DEVICE_TYPE'image(CONTROLLER_TYPE)			severity NOTE;
	assert FALSE report "  AllowSpeedNegotiation:  " & to_string(ALLOW_SPEED_NEGOTIATION)							severity NOTE;
	assert FALSE report "  AllowAutoReconnect:     " & to_string(ALLOW_AUTO_RECONNECT)								severity NOTE;
	assert FALSE report "  AllowStandardViolation: " & to_string(ALLOW_STANDARD_VIOLATION)						severity NOTE;
	assert FALSE report "  Init. SATA Generation:  Gen" & INTEGER'image(INITIAL_SATA_GENERATION + 1)	severity NOTE;

	-- ================================================================
	-- physical layer control
	-- ================================================================

	-- Reset this unit until initial reset of lower layer has been completed.
	-- Allow synchronous 'Reset' only when ClockEnable = '1'.
	Reset_i <= (not Trans_ResetDone) or (Reset and ClockEnable);
	
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset_i = '1') then
				State 	<= ST_RESET;
			else
				State		<= NextState;
			end if;
			
			if (Error_rst = '1') then
				Error			<= SATA_PHY_ERROR_NONE;
			elsif (Error_en = '1') then
				Error			<= Error_nxt;
			end if;
		end if;
	end process;
	
	process(State, Command, SC_Status, SC_OOBC_Reset,
					Trans_RP_Reconfig_i, Trans_RP_ConfigReloaded,
					OOBC_LinkOK, OOBC_LinkDead, OOBC_ReceivedReset)
	begin
		NextState								<= State;
		
		Status_i								<= SATA_PHY_STATUS_ERROR;
		Error_rst								<= '0';
		Error_en								<= '0';
		Error_nxt								<= SATA_PHY_ERROR_NONE;
		
		Trans_Command						<= SATA_TRANSCEIVER_CMD_NONE;
		
		FSM_SC_Reset						<= '0';
		FSM_SC_Command					<= SATA_PHY_SPEED_CMD_NONE;

		OOBC_Reset 							<= SC_OOBC_Reset;
		
		------------------------------------------------------------------
		-- Implementation notes:
		--
		-- OOBControl must be reseted when a SpeedControl command is issued.
		------------------------------------------------------------------
		case State is
			when ST_RESET =>
				-- Trans_ResetDone = '0' will hold the FSM in this state.
				-- Hold sub-components also in reset, until the transceiver
				-- interface is ready and the clock the first time stable.
				Error_rst 					<= '1';
				FSM_SC_Reset 				<= '1';
				OOBC_Reset 					<= '1'; -- override
				Status_i						<= SATA_PHY_STATUS_RESET;
				NextState						<= ST_LINK_UP;
	
			when ST_LINK_UP =>
				Status_i						<= SATA_PHY_STATUS_LINK_UP;
			
				if (Trans_RP_Reconfig_i = '1') then
					-- Must be highest priority to reach safe state during
					-- reconfiguration (where clock can be unstable).
					NextState					<= ST_CHANGE_SPEED;
				elsif (Command = SATA_PHY_CMD_INIT_CONNECTION) then
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_RESET;
					NextState					<= ST_LINK_UP;
				elsif (Command = SATA_PHY_CMD_REINIT_CONNECTION) then
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_NEWLINK_UP;
					NextState					<= ST_LINK_UP;
				elsif (OOBC_LinkOK = '1') then
					NextState					<= ST_LINK_OK;
				elsif (SC_Status = SATA_PHY_SPEED_STATUS_NEGOTIATION_ERROR) then
					Error_nxt					<= SATA_PHY_ERROR_NEGOTIATION_ERROR;
					Error_en					<= '1';
					NextState					<= ST_ERROR;
				end if;
				
			when ST_LINK_OK =>
				Status_i						<= SATA_PHY_STATUS_LINK_OK;
			
				IF (Command = SATA_PHY_CMD_INIT_CONNECTION) then
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_RESET;
					NextState					<= ST_LINK_UP;
				elsif (Command = SATA_PHY_CMD_REINIT_CONNECTION) then
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_NEWLINK_UP;
					NextState					<= ST_LINK_UP;
				elsif (OOBC_LinkOK = '0') then
					NextState					<= ST_LINK_BROKEN;
				elsif (OOBC_LinkDead = '1') then
					Error_nxt					<= SATA_PHY_ERROR_LINK_DEAD;
					Error_en					<= '1';
					NextState					<= ST_ERROR;
				elsif (OOBC_ReceivedReset = '1') then
					NextState					<= ST_LINK_UP;
				end if;
			
			when ST_LINK_BROKEN =>
				Status_i						<= SATA_PHY_STATUS_LINK_BROKEN;
			
				if (Command = SATA_PHY_CMD_INIT_CONNECTION) then
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_RESET;
					NextState					<= ST_LINK_UP;
				elsif (Command = SATA_PHY_CMD_REINIT_CONNECTION) then
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_NEWLINK_UP;
					NextState					<= ST_LINK_UP;
				elsif (OOBC_LinkOK = '1') then
					NextState					<= ST_LINK_OK;
				elsif (OOBC_LinkDead = '1') then
					Error_nxt					<= SATA_PHY_ERROR_LINK_DEAD;
					Error_en					<= '1';
					NextState					<= ST_ERROR;
				elsif (OOBC_ReceivedReset = '1') then
					NextState					<= ST_LINK_UP;
				end if;
				
			when ST_CHANGE_SPEED =>
				-- Clock can be unstable in this state.
				-- Trans_RP_ReconfigReloaded must not be asserted before clock is
				-- stable again.
				Status_i						<= SATA_PHY_STATUS_CHANGE_SPEED;

				if (Trans_RP_ConfigReloaded = '1') then
					NextState					<= ST_LINK_UP;
				end if;
			
			when ST_ERROR =>
				Status_i						<= SATA_PHY_STATUS_ERROR;
				
				if (Command = SATA_PHY_CMD_INIT_CONNECTION) then
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_RESET;
					NextState					<= ST_LINK_UP;
				elsif (Command = SATA_PHY_CMD_REINIT_CONNECTION) then
					FSM_SC_Command		<= SATA_PHY_SPEED_CMD_NEWLINK_UP;
					NextState					<= ST_LINK_UP;
				elsif (OOBC_ReceivedReset = '1') then
					Error_rst					<= '1';
					NextState					<= ST_LINK_UP;
				end if;
				
		end case;
	end process;
	
	Status	<= Status_i;

	-- OOB (out of band) signaling
	-- ===========================================================================
	genHost : if (CONTROLLER_TYPE = SATA_DEVICE_TYPE_HOST) generate
		OOBC : entity PoC.sata_Physical_OOBControl_Host
			generic map (
				DEBUG											=> DEBUG,
				ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
				CLOCK_FREQ								=> CLOCK_FREQ,
				ALLOW_STANDARD_VIOLATION	=> ALLOW_STANDARD_VIOLATION,
				OOB_TIMEOUT								=> OOB_TIMEOUT
			)
			port map (
				Clock											=> Clock,
				Reset											=> OOBC_Reset,
				
				DebugPortOut							=> OOBC_DebugPortOut,

				Retry											=> SC_OOBC_Retry,
				SATAGeneration						=> SC_SATAGeneration,
				Timeout										=> OOBC_Timeout,
				LinkOK										=> OOBC_LinkOK,
				LinkDead									=> OOBC_LinkDead,
				ReceivedReset							=> OOBC_ReceivedReset,
				
				Trans_Status							=> Trans_Status,
				Trans_Error								=> Trans_Error,
				
				OOB_TX_Command						=> Trans_OOB_TX_Command,
				OOB_TX_Complete						=> Trans_OOB_TX_Complete,
				OOB_RX_Received						=> Trans_OOB_RX_Received,
				OOB_HandshakeComplete			=> Trans_OOB_HandshakeComplete,
				
				TX_Primitive							=> OOBC_TX_Primitive,
				RX_Primitive							=> RX_Primitive,
				RX_Valid									=> Trans_RX_Valid
			);
	end generate;
	genDev : if (CONTROLLER_TYPE = SATA_DEVICE_TYPE_DEVICE) generate
		OOBC : entity PoC.sata_Physical_OOBControl_Device
			generic map (
				DEBUG											=> DEBUG,
				ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
				CLOCK_FREQ								=> CLOCK_FREQ,
				ALLOW_STANDARD_VIOLATION	=> ALLOW_STANDARD_VIOLATION,
				OOB_TIMEOUT								=> OOB_TIMEOUT
			)
			port map (
				Clock											=> Clock,
				Reset											=> OOBC_Reset,
				
				DebugPortOut							=> OOBC_DebugPortOut,

				Retry											=> SC_OOBC_Retry,
				SATAGeneration						=> SC_SATAGeneration,
				Timeout										=> OOBC_Timeout,
				LinkOK										=> OOBC_LinkOK,
				LinkDead									=> OOBC_LinkDead,
				ReceivedReset							=> OOBC_ReceivedReset,
				
				OOB_TX_Command						=> Trans_OOB_TX_Command,
				OOB_TX_Complete						=> Trans_OOB_TX_Complete,
				OOB_RX_Received						=> Trans_OOB_RX_Received,
				OOB_HandshakeComplete			=> Trans_OOB_HandshakeComplete,
				
				TX_Primitive							=> OOBC_TX_Primitive,
				RX_Primitive							=> RX_Primitive,
				RX_Valid									=> Trans_RX_Valid
			);
	end generate;
	

	-- SpeedControl
	-- ===========================================================================
	genSC : if (ALLOW_SPEED_NEGOTIATION = TRUE) generate
		SC : entity PoC.sata_Physical_SpeedControl
			generic map (
				DEBUG											=> DEBUG,
				ENABLE_DEBUGPORT					=> ENABLE_DEBUGPORT,
				INITIAL_SATA_GENERATION		=> INITIAL_SATA_GENERATION,
				GENERATION_CHANGE_COUNT		=> GENERATION_CHANGE_COUNT,
				ATTEMPTS_PER_GENERATION		=> ATTEMPTS_PER_GENERATION
			)
			port map (
				Clock											=> Clock,
				Reset											=> FSM_SC_Reset,

				Command										=> FSM_SC_Command,
				Status										=> SC_Status,

				DebugPortOut							=> SC_DebugPortOut,

				SATAGenerationMin					=> SATAGenerationMin,								-- 
				SATAGenerationMax					=> SATAGenerationMax,								-- 

				-- OOBControl interface
				OOBC_Timeout							=> OOBC_Timeout,
				OOBC_Reset 								=> SC_OOBC_Reset,
				OOBC_Retry								=> SC_OOBC_Retry,

				-- reconfiguration interface
				Trans_RP_Reconfig					=> Trans_RP_Reconfig_i,
				Trans_RP_SATAGeneration		=> SC_SATAGeneration,								-- 
				Trans_RP_ReconfigComplete	=> Trans_RP_ReconfigComplete,
				Trans_RP_ConfigReloaded		=> Trans_RP_ConfigReloaded,
				Trans_RP_Lock							=> Trans_RP_Lock,
				Trans_RP_Locked						=> Trans_RP_Locked
			);
	end generate;
	--
	-- no SpeedControl
	-- ===========================================================================
	genNoSC : if (ALLOW_SPEED_NEGOTIATION = FALSE) generate
		signal TryCounter_rst			: STD_LOGIC;
		signal TryCounter_en			: STD_LOGIC;
		signal TryCounter_s				: SIGNED(log2ceilnz(ATTEMPTS_PER_GENERATION) downto 0)			:= (others => '0');
		signal TryCounter_uf			: STD_LOGIC;
		
		signal OOB_Timeout_d			: STD_LOGIC					:= '0';
		signal OOB_Timeout_re			: STD_LOGIC;

		-- Issue first SC_Retry after respective SC_Command
		signal SC_StartOver 			: STD_LOGIC 				:= '0';
		
	begin
		SC_SATAGeneration			<= INITIAL_SATA_GENERATION;
		
		Trans_RP_Reconfig_i		<= '0';
		Trans_RP_Lock					<= NOT TryCounter_uf;
	
		OOBC_Timeout_d				<= OOBC_Timeout when rising_edge(Clock);
		OOBC_Timeout_re				<= not OOBC_Timeout_d and OOBC_Timeout;
		
		SC_OOBC_Reset 				<= to_sl((FSM_SC_Command = SATA_PHY_SPEED_CMD_RESET) or (FSM_SC_COMMAND = SATA_PHY_SPEED_CMD_NEWLINK_UP));
		SC_OOBC_Retry					<= (OOBC_Timeout_re and not TryCounter_uf) or SC_StartOver;
		SC_Status							<= SATA_PHY_SPEED_STATUS_NEGOTIATION_ERROR when (TryCounter_uf = '1') else SATA_PHY_SPEED_STATUS_WAITING;

		TryCounter_rst				<= SC_StartOver;
		TryCounter_en					<= OOBC_Timeout_re;
	
		process(Clock)
		begin
			if rising_edge(Clock) then
				-- C_OOBC_Reset is low, when PhysicalLayer is reset.
				SC_StartOver 		<= SC_OOBC_Reset;
				
				if (TryCounter_rst = '1') then
					TryCounter_s		<= to_signed(ATTEMPTS_PER_GENERATION, TryCounter_s'length);
				else
					if (TryCounter_en = '1') then
						TryCounter_s	<= TryCounter_s - 1;
					end if;
				end if;
			end if;
		end process;
	
		TryCounter_uf <= TryCounter_s(TryCounter_s'high);
	
	end generate;

	Trans_RP_Reconfig					<= Trans_RP_Reconfig_i;
	Trans_RP_SATAGeneration		<= SC_SATAGeneration;

	-- physical layer PrimitiveMux
	process(OOBC_TX_Primitive, Link_TX_Data, Link_TX_CharIsK)
	begin
		case OOBC_TX_Primitive is
			when SATA_PRIMITIVE_ALIGN =>																			-- ALIGN				D27.3 D10.2 D10.2 K28.5
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_ALIGN);			-- x"7B4A4ABC";
				Trans_TX_CharIsK_i	<= "0001";
				
			when SATA_PRIMITIVE_DIAL_TONE =>																	-- Dial Tone		D10.2 D10.2 D10.2 D10.2
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_DIAL_TONE);	-- x"4A4A4A4A";
				Trans_TX_CharIsK_i	<= "0000";

			when SATA_PRIMITIVE_NONE =>																				-- passthrought data and k-symbols from linklayer
				Trans_TX_Data_i			<= Link_TX_Data;
				Trans_TX_CharIsK_i	<= Link_TX_CharIsK;

			when others =>
				Trans_TX_Data_i			<= to_sata_word(SATA_PRIMITIVE_DIAL_TONE);
				Trans_TX_CharIsK_i	<= "0000";
				
				assert FALSE report "Illegal PRIMTIVE" severity FAILURE;
				
		end case;
	end process;
	
	Trans_TX_Data			<= Trans_TX_Data_i;
	Trans_TX_CharIsK	<= Trans_TX_CharIsK_i;
	
	-- physical layer PrimtiveDetector
	RX_Primitive			<= to_sata_primitive(Trans_RX_Data, Trans_RX_CharIsK);
	
	-- passthrought RX data
	Link_RX_Data			<= Trans_RX_Data;
	Link_RX_CharIsK		<= Trans_RX_CharIsK;
	
		
	-- debug port
	-- ===========================================================================
	genDebugPort : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeState(st : T_STATE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_STATE'pos(st), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
		end function;
	begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_generateStateEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_STATE loop
					STD.TextIO.write(l, str_replace(T_STATE'image(i), "st_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			function dbg_generateCommandEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_PHY_COMMAND loop
					STD.TextIO.write(l, str_replace(T_SATA_PHY_COMMAND'image(i), "sata_phy_cmd", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_generateStatusEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_PHY_STATUS loop
					STD.TextIO.write(l, str_replace(T_SATA_PHY_STATUS'image(i), "sata_phy_status_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_generateErrorEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_PHY_ERROR loop
					STD.TextIO.write(l, str_replace(T_SATA_PHY_ERROR'image(i), "sata_phy_error_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
		
			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Physical Layer - Layer FSM",			dbg_generateStateEncodings,		PROJECT_DIR & "ChipScope/TokenFiles/FSM_PhysicalLayer.tok"),
				1 => dbg_ExportEncoding("Physical Layer - Command Enum",	dbg_generateCommandEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Phy_Command.tok"),
				2 => dbg_ExportEncoding("Physical Layer - Status Enum",		dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Phy_Status.tok"),
				3 => dbg_ExportEncoding("Physical Layer - Error Enum",		dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Phy_Error.tok")
			);
		begin
		end generate;
		
		DebugPortOut.FSM						<= dbg_EncodeState(State);
		DebugPortOut.PHY_Status			<= Status_i;
	
		DebugPortOut.TX_Data				<= Trans_TX_Data_i;
		DebugPortOut.TX_CharIsK			<= Trans_TX_CharIsK_i;
		DebugPortOut.RX_Data				<= Trans_RX_Data;
		DebugPortOut.RX_CharIsK			<= Trans_RX_CharIsK;
		DebugPortOut.RX_Valid				<= Trans_RX_Valid;
	
		DebugPortOut.OOBControl			<= OOBC_DebugPortOut;
		DebugPortOut.SpeedControl		<= SC_DebugPortOut;
	end generate;
end;
