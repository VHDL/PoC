-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- =============================================================================
-- Package:					sata
--
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Description:
-- ------------------------------------
-- FSM for module "sata_PhysicalLayer".
-- Commmand-Status-Error interface is described in that module.
--
-- The Clock might be only unstable in the states ST_RESET and
-- ST_*_RECONFIG_WAIT. This is accomplished by:
--
-- a) During Power-up or a ClockNetwork_Reset this unit is hold in the
--    reset state ST_RESET due to Trans_ResetDone = '0'. The OOB Controller is
--    reseted too.
--
-- b) During reconfiguration, this FSM waits in one of the ST_*_RECONFIG_WAIT
--    states. Asserting Trans_RP_ConfigReloaded is only permitted
-- 	  after the clock is stable again.
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
USE			PoC.debug.ALL;
USE			PoC.components.ALL;
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;


entity sata_PhysicalLayerFSM is
	generic (
		DEBUG											: BOOLEAN							:= FALSE;												ALLOW_SPEED_NEGOTIATION		: BOOLEAN							:= TRUE;
		-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN							:= FALSE;												-- enables the assignment of signals to the debugport
		INITIAL_SATA_GENERATION		: T_SATA_GENERATION		:= C_SATA_GENERATION_MAX;
		GENERATION_CHANGE_COUNT		: INTEGER							:= 32;
		ATTEMPTS_PER_GENERATION		: INTEGER							:= 8
	);
	PORT (
		Clock											: in	STD_LOGIC;
		ClockEnable 							: in  STD_LOGIC;
		Reset											: in	STD_LOGIC;

		Command										: in	T_SATA_PHY_COMMAND;
		Status										: out	T_SATA_PHY_STATUS;
		Error											: out	T_SATA_PHY_ERROR;
		SATAGenerationMin					: in	T_SATA_GENERATION;									--
		SATAGenerationMax					: in	T_SATA_GENERATION;									--

		DebugPortOut							: out	T_SATADBG_PHYSICAL_PFSM_OUT;

		OOBC_Timeout							: in	STD_LOGIC;
		OOBC_DeviceOrHostDetected	: in  STD_LOGIC;
		OOBC_LinkOK 							: in  STD_LOGIC;
		OOBC_LinkDead 						: in  STD_LOGIC;
		OOBC_Reset								: out	STD_LOGIC;

		-- Transceiver interface
		Trans_ResetDone						: in	STD_LOGIC;
		Trans_Status							: in	T_SATA_TRANSCEIVER_STATUS;

		Trans_RP_Reconfig					: out	STD_LOGIC;
		Trans_RP_SATAGeneration		: out	T_SATA_GENERATION;									--
		Trans_RP_ConfigReloaded		: in	STD_LOGIC
	);
END;


ARCHITECTURE rtl OF sata_PhysicalLayerFSM is
	ATTRIBUTE FSM_ENCODING	: STRING;

	TYPE T_SGEN_SGEN	IS ARRAY (T_SATA_GENERATION) OF T_SATA_GENERATION;
	TYPE T_SGEN2_SGEN	IS ARRAY (T_SATA_GENERATION) OF T_SGEN_SGEN;
	TYPE T_SGEN3_SGEN	IS ARRAY (T_SATA_GENERATION) OF T_SGEN2_SGEN;

	FUNCTION StartGen RETURN T_SGEN2_SGEN IS
		CONSTANT ERROR_VALUE	: T_SATA_GENERATION	:= ite(SIMULATION, SATA_GENERATION_ERROR, SATA_GENERATION_1);
		VARIABLE SG						: T_SGEN2_SGEN			:= (OTHERS => (OTHERS => ERROR_VALUE));
	BEGIN
		-- minimal			/	maximal gen.		==>	cmp value
		-- ========================================================================
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_3;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_1)				:= SATA_GENERATION_1;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_2)				:= SATA_GENERATION_2;
		SG(SATA_GENERATION_AUTO)(SATA_GENERATION_3)				:= SATA_GENERATION_3;

		SG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		SG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		SG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)				:= SATA_GENERATION_3;
		SG(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		SG(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		SG(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		RETURN SG;
	END;

	FUNCTION NextGen RETURN T_SGEN3_SGEN IS
		CONSTANT ERROR_VALUE	: T_SATA_GENERATION	:= ite(SIMULATION, SATA_GENERATION_ERROR, SATA_GENERATION_1);
		VARIABLE NG						: T_SGEN3_SGEN			:= (OTHERS => (OTHERS => (OTHERS => ERROR_VALUE)));
	BEGIN
		-- current 		/ minimal			/	maximal gen.		==>	next gen.
		-- ========================================================================
		-- current generation is SATA_GENERATION_1
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_3;

		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_1)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		-- current generation is SATA_GENERATION_2
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_1;

		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_1;

		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_2)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		-- current generation is SATA_GENERATION_3
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_AUTO)		:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_1)			:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_2)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_AUTO)(SATA_GENERATION_3)			:= SATA_GENERATION_2;

		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_1)(SATA_GENERATION_3)					:= SATA_GENERATION_2;

		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_2)(SATA_GENERATION_3)					:= SATA_GENERATION_2;

		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_AUTO)			:= SATA_GENERATION_3;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_1)					:= SATA_GENERATION_1;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_2)					:= SATA_GENERATION_2;
		NG(SATA_GENERATION_3)(SATA_GENERATION_3)(SATA_GENERATION_3)					:= SATA_GENERATION_3;

		RETURN NG;
	END;

	CONSTANT ROM_StartGeneration							: T_SGEN2_SGEN	:= StartGen;
	CONSTANT ROM_NextGeneration 							: T_SGEN3_SGEN	:= NextGen;

	CONSTANT GENERATION_CHANGE_COUNTER_BITS		: POSITIVE			:= log2ceilnz(GENERATION_CHANGE_COUNT + 1);
	CONSTANT TRY_PER_GENERATION_COUNTER_BITS	: POSITIVE			:= log2ceilnz(ATTEMPTS_PER_GENERATION);

	TYPE T_STATE IS (
		ST_RESET,
		ST_INIT_CONNECTION,
		ST_NODEV_RECONFIG, ST_NODEV_RECONFIG_WAIT, ST_NODEVICE,
		ST_REINIT_CONNECTION,
		ST_NOCOMMUNICATION, ST_NOCOM_TIMEOUT, ST_NOCOM_RECONFIG, ST_NOCOM_RECONFIG_WAIT,
		ST_COMMUNICATING,
		ST_ERROR
	);

	-- Statemachine
	SIGNAL State												: T_STATE												:= ST_RESET;
	SIGNAL NextState										: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State		: SIGNAL IS getFSMEncoding_gray(DEBUG);

	SIGNAL Status_i											: T_SATA_PHY_STATUS;
	SIGNAL Error_r											: T_SATA_PHY_ERROR;
	SIGNAL Error_nxt										: T_SATA_PHY_ERROR;
	SIGNAL Error_en											: STD_LOGIC;

	signal OOBC_Reset_i 								: STD_LOGIC;
	signal Trans_RP_Reconfig_i					: STD_LOGIC;

	-- Speed Negotiation specific
	SIGNAL SATAGeneration_rst						: STD_LOGIC;
	SIGNAL SATAGeneration_Change				: STD_LOGIC;
	SIGNAL SATAGeneration_Changed				: STD_LOGIC;
	SIGNAL SATAGeneration_cur						: T_SATA_GENERATION							:= INITIAL_SATA_GENERATION;
	SIGNAL SATAGeneration_nxt						: T_SATA_GENERATION;

	-- Rec

	SIGNAL GenerationChange_Counter_rst	: STD_LOGIC;
	SIGNAL GenerationChange_Counter_en	: STD_LOGIC;
	SIGNAL GenerationChange_Counter_us	: UNSIGNED(GENERATION_CHANGE_COUNTER_BITS DOWNTO 0) := (OTHERS => '0');
	SIGNAL GenerationChange_Counter_ov	: STD_LOGIC;

	SIGNAL TryPerGeneration_Counter_rst	: STD_LOGIC;
	SIGNAL TryPerGeneration_Counter_en	: STD_LOGIC;
	SIGNAL TryPerGeneration_Counter_us	: UNSIGNED(TRY_PER_GENERATION_COUNTER_BITS DOWNTO 0) := (OTHERS => '0');
	SIGNAL TryPerGeneration_Counter_ov	: STD_LOGIC;

BEGIN

	-- ===========================================================================
	-- Calculation of SATA generation.
	-- ===========================================================================
	PROCESS(SATAGeneration_rst, SATAGeneration_cur, SATAGeneration_Change, SATAGenerationMin, SATAGenerationMax)
		VARIABLE SATAGeneration_nxt_v : T_SATA_GENERATION;
	BEGIN
		if (SATAGeneration_rst = '1') then
			SATAGeneration_nxt_v	:= ROM_StartGeneration(SATAGenerationMin)(SATAGenerationMax);
		elsif (SATAGeneration_Change = '1') then
			SATAGeneration_nxt_v	:= ROM_NextGeneration(SATAGeneration_cur)(SATAGenerationMin)(SATAGenerationMax);
		else
			SATAGeneration_nxt_v	:= SATAGeneration_cur;
		end if;

		-- test if generation is going to be changed
		SATAGeneration_Changed	<= to_sl(SATAGeneration_cur /= SATAGeneration_nxt_v);

		-- assign new generation to *_nxt signal
		SATAGeneration_nxt			<= SATAGeneration_nxt_v;
	END PROCESS;

	-- export current SATA generation to other layers
	Trans_RP_SATAGeneration <= SATAGeneration_cur;


	-- ===========================================================================
	-- Statemachine
	-- ===========================================================================
	process(Clock)
	begin
		if rising_edge(Clock) then
			if Trans_ResetDone = '0' then
				State <= ST_RESET;
			elsif ClockEnable = '1' then
				if Reset = '1' then
					State <= ST_RESET;
				else
					State <= NextState;
				end if;
			end if;

			if Error_en = '1' then --only true if also clock is enabled
				Error_r <= Error_nxt;
			end if;
		end if;
	end process;

	genSpeedNego: if (ALLOW_SPEED_NEGOTIATION = TRUE) generate
		process(Clock)
		begin
			if rising_edge(Clock) then
				if (ClockEnable = '1') then
					-- Only update if clock is enabled because the current value must mimic
					-- the FPGA transceiver configuration which is not automatically reseted.
					SATAGeneration_cur	<= SATAGeneration_nxt;
				end if;
			end if;
		end process;
	end generate;
	genNoSpeedNego: if (ALLOW_SPEED_NEGOTIATION = FALSE) generate
		SATAGeneration_cur <= INITIAL_SATA_GENERATION;
	end generate;

	process(State, Command,
					OOBC_Timeout, OOBC_DeviceOrHostDetected, OOBC_LinkOK, OOBC_LinkDead,
					Trans_Status, Trans_RP_ConfigReloaded,
					SATAGeneration_Changed,
					TryPerGeneration_Counter_ov, GenerationChange_Counter_ov)
	begin
		NextState														<= State;

		Status_i														<= SATA_PHY_STATUS_ERROR;
		Error_nxt 													<= SATA_PHY_ERROR_NONE;
		Error_en 														<= '0';

		SATAGeneration_rst									<= '0';
		SATAGeneration_Change								<= '0';
		OOBC_Reset_i 												<= '0';
		Trans_RP_Reconfig_i									<= '0';

		TryPerGeneration_Counter_rst				<= '0';
		TryPerGeneration_Counter_en					<= '0';
		GenerationChange_Counter_rst				<= '0';
		GenerationChange_Counter_en					<= '0';

		-- Implementation notes:
		--
		-- Assert OOBC_Reset_i during reconfiguration or to start a new try.
		-- Directly after deassertion of OOBC_Reset_i, the OOBC tries to establish
		-- a communication.
		case State is
			when ST_RESET =>
				-- Trans_ResetDone = '0' will hold the FSM in this state.
				-- Hold sub-components also in reset, until the transceiver
				-- interface is ready and the clock the first time stable.
				Status_i 			<= SATA_PHY_STATUS_RESET;
				OOBC_Reset_i 	<= '1';
				Error_en 			<= '1'; -- reset error
				Error_nxt 		<= SATA_PHY_ERROR_NONE;

				if Trans_Status = SATA_TRANSCEIVER_STATUS_READY then
					-- Automatically init connection after transceiver is ready.
					NextState 	<= ST_INIT_CONNECTION;
				end if;


			when ST_INIT_CONNECTION =>
				-- Start here to initiate a new connection with speed negotiation.
				Status_i 											<= SATA_PHY_STATUS_NODEVICE;
				OOBC_Reset_i									<= '1';
				SATAGeneration_rst						<= '1';
				TryPerGeneration_Counter_rst	<= '1';
				GenerationChange_Counter_rst	<= '1';

				if (SATAGeneration_Changed = '1') then
					if ALLOW_SPEED_NEGOTIATION then
						NextState									<= ST_NODEV_RECONFIG;
					else
						NextState 								<= ST_ERROR;
						Error_en 									<= '1';
						Error_nxt 								<= SATA_PHY_ERROR_NEGOTIATION;
					end if;
				else
					NextState										<= ST_NODEVICE;
				end if;


			when ST_NODEV_RECONFIG =>
				-- Reconfiguration during NODEVICE condition.
				Status_i 								<= SATA_PHY_STATUS_NODEVICE;
				OOBC_Reset_i 						<= '1';
				Trans_RP_Reconfig_i			<= '1';
				NextState								<= ST_NODEV_RECONFIG_WAIT;


			WHEN ST_NODEV_RECONFIG_WAIT =>
				-- Reconfiguration during NODEVICE condition. Clock might be unstable
				-- when FSM is in this state. See description in header.
				Status_i								<= SATA_PHY_STATUS_NODEVICE;
				OOBC_Reset_i 						<= '1';

				if (Trans_RP_ConfigReloaded = '1') then
					NextState							<= ST_NODEVICE;
				end if;


			when ST_NODEVICE =>
				-- No device detected yet. When coming from above then OOBC_Reset_i
				-- is deasserted, so that OOBC tries to init a connection.
				Status_i								<= SATA_PHY_STATUS_NODEVICE;

				if OOBC_Timeout = '1' then
					OOBC_Reset_i 					<= '1'; -- start over
			  elsif OOBC_DeviceOrHostDetected = '1' then
					NextState 						<= ST_NOCOMMUNICATION;
				end if;


			when ST_REINIT_CONNECTION =>
				-- Start here to re-initiate the connection at the same speed.
				Status_i											<= SATA_PHY_STATUS_NOCOMMUNICATION;
				OOBC_Reset_i 									<= '1';
				TryPerGeneration_Counter_rst	<= '1';


			when ST_NOCOMMUNICATION =>
				-- Communication has not been established yet.
				-- When coming from another state, OOBC_Reset_i is
				-- deasserted now, so that OOBC tries to init a connection.
				Status_i		<= SATA_PHY_STATUS_NOCOMMUNICATION;

				if OOBC_LinkDead = '1' then
					NextState <= ST_ERROR;
					Error_en  <= '1';
					Error_nxt <= SATA_PHY_ERROR_LINK_DEAD;

				elsif OOBC_LinkOK = '1' then
					NextState <= ST_COMMUNICATING;

				elsif OOBC_Timeout = '1' then
					NextState <= ST_NOCOM_TIMEOUT;
				end if;


			when ST_NOCOM_TIMEOUT =>
				-- Timeout during establishing a communication.
				Status_i												<= SATA_PHY_STATUS_NOCOMMUNICATION;

				IF (TryPerGeneration_Counter_ov = '1') THEN
					IF (GenerationChange_Counter_ov = '1') THEN
						NextState										<= ST_ERROR;
						Error_en 										<= '1';
						Error_nxt 									<= SATA_PHY_ERROR_NEGOTIATION;
					ELSE																					-- generation change counter allows => generation change
						SATAGeneration_Change				<= '1';
						TryPerGeneration_Counter_rst	<= '1';
						GenerationChange_Counter_en	<= '1';

						IF (SATAGeneration_Changed = '1') THEN
							if ALLOW_SPEED_NEGOTIATION then
								NextState								<= ST_NOCOM_RECONFIG;
							else
								NextState 							<= ST_ERROR;
								Error_en 								<= '1';
								Error_nxt 							<= SATA_PHY_ERROR_NEGOTIATION;
							end if;
						ELSE
							NextState									<= ST_NOCOMMUNICATION;
							OOBC_Reset_i 							<= '1';
						END IF;
					END IF;
				ELSE																						-- tries per generation counter allows an other try at current generation
					TryPerGeneration_Counter_en		<= '1';
					NextState											<= ST_NOCOMMUNICATION;
					OOBC_Reset_i 									<= '1';
				END IF;


			when ST_NOCOM_RECONFIG =>
				-- Reconfiguration during NOCOMMUNICTION condition.
				Status_i								<= SATA_PHY_STATUS_NOCOMMUNICATION;
				OOBC_Reset_i 						<= '1';
				Trans_RP_Reconfig_i			<= '1';
				NextState								<= ST_NOCOM_RECONFIG_WAIT;


			when ST_NOCOM_RECONFIG_WAIT =>
				-- Reconfiguration during NOCOMMUNICTION condition. Clock might be
				-- unstable when FSM is in this state. See description in header.
				Status_i								<= SATA_PHY_STATUS_NOCOMMUNICATION;
				OOBC_Reset_i 						<= '1';

				IF (Trans_RP_ConfigReloaded = '1') THEN
					NextState							<= ST_NOCOMMUNICATION;
				END IF;


			when ST_COMMUNICATING =>
				-- Communication established.
				Status_i				<= SATA_PHY_STATUS_COMMUNICATING;

				case Command is
					when SATA_PHY_CMD_INIT_CONNECTION =>
						NextState 	<= ST_INIT_CONNECTION;

					when SATA_PHY_CMD_REINIT_CONNECTION =>
						NextState 	<= ST_REINIT_CONNECTION;

					when SATA_PHY_CMD_NONE =>
						if OOBC_LinkDead = '1' then
							NextState <= ST_ERROR;
							Error_en  <= '1';
							Error_nxt <= SATA_PHY_ERROR_LINK_DEAD;
						end if;
				end case;


			when ST_ERROR =>
				-- Fatal error occured. Error code is loaded by prevoius state.
				Status_i				<= SATA_PHY_STATUS_ERROR;

				case Command is
					when SATA_PHY_CMD_INIT_CONNECTION =>
						Error_en 	<= '1';
						Error_nxt <= SATA_PHY_ERROR_NONE;
						NextState <= ST_INIT_CONNECTION;

					when SATA_PHY_CMD_REINIT_CONNECTION =>
						Error_en 	<= '1';
						Error_nxt <= SATA_PHY_ERROR_NONE;
						NextState <= ST_REINIT_CONNECTION;

					when SATA_PHY_CMD_NONE =>
						null;
				end case;
		end case;
	end process;

	Status						<= Status_i;
	Error							<= Error_r;
	OOBC_Reset				<= OOBC_Reset_i;
	Trans_RP_Reconfig	<= Trans_RP_Reconfig_i;

	-- ================================================================
	-- try counters
	-- ================================================================
	TryPerGeneration_Counter_us	<= upcounter_next(cnt => TryPerGeneration_Counter_us, rst => TryPerGeneration_Counter_rst, en => TryPerGeneration_Counter_en) WHEN rising_edge(Clock);		-- count attempts per generation
	GenerationChange_Counter_us	<= upcounter_next(cnt => GenerationChange_Counter_us, rst => GenerationChange_Counter_rst, en => GenerationChange_Counter_en) WHEN rising_edge(Clock);		-- count generation changes

	TryPerGeneration_Counter_ov	<= upcounter_equal(TryPerGeneration_Counter_us, ATTEMPTS_PER_GENERATION - 1);
	GenerationChange_Counter_ov	<= upcounter_equal(GenerationChange_Counter_us, GENERATION_CHANGE_COUNT);


	-- debug port
	-- ===========================================================================
	genSim : if (SIMULATION = TRUE) generate
		signal sim_SATAGeneration	: UNSIGNED(2 downto 0);
	begin
		sim_SATAGeneration	<= to_unsigned(SATAGeneration_cur, 3) + 1;
	end generate;

	genDebug : IF (ENABLE_DEBUGPORT = TRUE) GENERATE
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
				0 => dbg_ExportEncoding("Physical Layer - FSM",			dbg_generateStateEncodings,		PROJECT_DIR & "ChipScope/TokenFiles/FSM_PhysicalLayer.tok"),
				1 => dbg_ExportEncoding("Physical Layer - Command Enum",	dbg_generateCommandEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Phy_Command.tok"),
				2 => dbg_ExportEncoding("Physical Layer - Status Enum",		dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Phy_Status.tok"),
				3 => dbg_ExportEncoding("Physical Layer - Error Enum",		dbg_generateErrorEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Phy_Error.tok")
			);
		begin
		end generate;

		DebugPortOut.FSM										<= dbg_EncodeState(State);
		DebugPortOut.Command								<= Command;
		DebugPortOut.Status									<= Status_i;
		DebugPortOut.Error									<= Error_r;
		DebugPortOut.SATAGeneration					<= SATAGeneration_cur;
		DebugPortOut.SATAGeneration_Reset		<= SATAGeneration_rst;
		DebugPortOut.SATAGeneration_Change	<= SATAGeneration_Change;
		DebugPortOut.SATAGeneration_Changed	<= SATAGeneration_Changed;
		DebugPortOut.OOBC_Reset							<= OOBC_Reset_i;
		DebugPortOut.Trans_Reconfig					<= Trans_RP_Reconfig_i;
		DebugPortOut.Trans_ConfigReloaded		<= Trans_RP_ConfigReloaded;
		DebugPortOut.GenerationChanges			<= resize(std_logic_vector(GenerationChange_Counter_us), DebugPortOut.GenerationChanges'length);
		DebugPortOut.TrysPerGeneration			<= resize(std_logic_vector(TryPerGeneration_Counter_us), DebugPortOut.TrysPerGeneration'length);
	END GENERATE;
END;
