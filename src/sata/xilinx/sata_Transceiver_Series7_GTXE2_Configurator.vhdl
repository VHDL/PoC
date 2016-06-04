-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		For detailed documentation see below.
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany,
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
--USE			PoC.vectors.ALL;
USE			PoC.physical.ALL;
USE			PoC.sata.ALL;
USE			PoC.xil.ALL;


-- ==================================================================
-- Notice
-- ==================================================================
--	modifies FPGA configuration bits via Dynamic Reconfiguration Port (DRP)
--	changes via DRP require a full GTX_DUAL reset

--	used configuration words
--	address		bits		|	GTX_DUAL generic name				GEN_1			GEN_2		Note GEN_1			Note GEN_2
-- ============================================================================================================================================================
--	0x05			[3]			|	PLL_TXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x05			[4]			|	PLL_TXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x09			[15]		|	PLL_RXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x0A			[0]			|	PLL_RXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x45			[15]		|	PLL_TXDIVSEL_OUT_0 [0]				 1				 0		divide by 2			divide by 1
--	0x46			[0]			|	PLL_TXDIVSEL_OUT_0 [1]				 0				 0		divide by 2			divide by 1
--	0x46			[3..2]	|	PLL_RXDIVSEL_OUT_0 [1:0]			01				00		divide by 2			divide by 1


ENTITY sata_Transceiver_Series7_GTXE2_Configurator IS
	GENERIC (
		DEBUG											: BOOLEAN							:= FALSE;										--
		DRPCLOCK_FREQ							: FREQ								:= 0 MHz;										--
		INITIAL_SATA_GENERATION		: T_SATA_GENERATION		:= C_SATA_GENERATION_MAX		-- intial SATA Generation
	);
	PORT (
		DRP_Clock								: IN	STD_LOGIC;
		DRP_Reset								: IN	STD_LOGIC;

		SATA_Clock							: IN	STD_LOGIC;

		Reconfig								: IN	STD_LOGIC;							-- @SATA_Clock
		SATAGeneration					: IN	T_SATA_GENERATION;			-- @SATA_Clock
		ReconfigComplete				: OUT	STD_LOGIC;							-- @SATA_Clock
		ConfigReloaded					: OUT	STD_LOGIC;							-- @SATA_Clock

		GTX_DRP_Enable					: OUT	STD_LOGIC;							-- @DRP_Clock
		GTX_DRP_Address					: OUT	T_XIL_DRP_ADDRESS;			-- @DRP_Clock
		GTX_DRP_ReadWrite				: OUT	STD_LOGIC;							-- @DRP_Clock
		GTX_DRP_DataIn					: IN	T_XIL_DRP_DATA;					-- @DRP_Clock
		GTX_DRP_DataOut					: OUT	T_XIL_DRP_DATA;					-- @DRP_Clock
		GTX_DRP_Ack							: IN	STD_LOGIC;							-- @DRP_Clock

		GTX_ReloadConfig				: OUT	STD_LOGIC;							-- @DRP_Clock
		GTX_ReloadConfigDone		: IN	STD_LOGIC								-- @DRP_Clock
	);
END;


ARCHITECTURE rtl OF sata_Transceiver_Series7_GTXE2_Configurator IS
	ATTRIBUTE KEEP								: BOOLEAN;
	ATTRIBUTE FSM_ENCODING				: STRING;

	FUNCTION ins(value: STD_LOGIC_VECTOR; Length : NATURAL) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result		: STD_LOGIC_VECTOR(Length - 1 DOWNTO 0)		:= (OTHERS => '0');
	BEGIN
		Result(value'range)	:= value;
		RETURN Result;
	END FUNCTION;

	-- 1. descibe all used GENERICs
	TYPE GTX_GENERICS IS RECORD
		RX_CDR_CFG				: STD_LOGIC_VECTOR(71 DOWNTO 0);		-- RX CDR Configuration; see Xilinx AR# 53364 - CDR settings for SSC (spread spectrum clocking)
	END RECORD;
	TYPE GTX_GENERICS_VECTOR IS ARRAY(NATURAL RANGE <>) OF GTX_GENERICS;

	-- 2. assign each GENERIC for each speed configuration
	--		index -> speed configuration
	CONSTANT GTX_CONFIGS			: GTX_GENERICS_VECTOR := (
		-- SATA Generation 1: set RX_CDR_CFG for 1.5 GHz line rate
		0 => (RX_CDR_CFG	=> x"0380008BFF40100008"),
		-- SATA Generation 2: set RX_CDR_CFG for 3.0 GHz line rate
		1 => (RX_CDR_CFG	=> x"0388008BFF40200008"),
		-- SATA Generation 3: set RX_CDR_CFG for 6.0 GHz line rate
		2 => (RX_CDR_CFG	=> x"0380008BFF10200010")
	);

	-- 3. convert GENERICs into ConfigROM enties for each config set and each speed configuration
	CONSTANT XILDRP_CONFIG_ROM								: T_XIL_DRP_CONFIG_ROM := (
		-- Set 0, SATA Generation 1
		0 => (Configs =>																				--											SET		GENERIC			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>					GTX_CONFIGS(0).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>					GTX_CONFIGS(0).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>					GTX_CONFIGS(0).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>					GTX_CONFIGS(0).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"00FF", Data => x"00" & GTX_CONFIGS(0).RX_CDR_CFG(71 downto 64)),		-- 0x0AC,	[7..0]			____ ____ xxxx xxxx
							 OTHERS => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 4),
		-- Set 0, SATA Generation 2
		1 => (Configs =>																				--											SET		GENERIC			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>					GTX_CONFIGS(1).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>					GTX_CONFIGS(1).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>					GTX_CONFIGS(1).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>					GTX_CONFIGS(1).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"00FF", Data => x"00" & GTX_CONFIGS(1).RX_CDR_CFG(71 downto 64)),		-- 0x0AC,	[7..0]			____ ____ xxxx xxxx
							 OTHERS => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 4),
		-- Set 0, SATA Generation 3
		2 => (Configs =>																				--											SET		GENERIC			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>					GTX_CONFIGS(2).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>					GTX_CONFIGS(2).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>					GTX_CONFIGS(2).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>					GTX_CONFIGS(2).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"00FF", Data => x"00" & GTX_CONFIGS(2).RX_CDR_CFG(71 downto 64)),		-- 0x0AC,	[7..0]			____ ____ xxxx xxxx
							 OTHERS => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 4)
	);

	CONSTANT XILDRP_CONFIGSELECT_BITS	: POSITIVE			:= log2ceilnz(XILDRP_CONFIG_ROM'length);

	TYPE T_STATE IS (
		ST_IDLE,
		ST_RECONFIG,	ST_RECONFIG_WAIT,
		ST_RELOAD,		ST_RELOAD_WAIT
	);

	-- GTXE2_Configuration - Statemachine
	SIGNAL State											: T_STATE											:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State	: SIGNAL IS getFSMEncoding_gray(DEBUG);

	SIGNAL Reconfig_DRP								: STD_LOGIC;
	SIGNAL ReconfigComplete_i					: STD_LOGIC;
	SIGNAL ConfigReloaded_i						: STD_LOGIC;
	SIGNAL SATAGeneration_DRP					: T_SATA_GENERATION		:= INITIAL_SATA_GENERATION;

	SIGNAL doReconfig									: STD_LOGIC;

	SIGNAL ReloadConfig_i							: STD_LOGIC;

	SIGNAL XilDRP_Reconfig						: STD_LOGIC;
	SIGNAL XilDRP_ReconfigDone				: STD_LOGIC;
	SIGNAL XilDRP_ConfigSelect				: STD_LOGIC_VECTOR(XILDRP_CONFIGSELECT_BITS - 1 DOWNTO 0);

BEGIN
	-- synchronize Reconfig, SATAGeneration from SATA_Clock to DRP_Clock
	sync1 : ENTITY PoC.sync_Strobe
		PORT MAP (
			Clock1			=> SATA_Clock,
			Clock2			=> DRP_Clock,
			Input(0)		=> Reconfig,
			Output(0)		=> Reconfig_DRP
		);

	-- sample SATAGeneration in new clock domain if Reconfig occurs (SATAGeneration was stable for several cycles)
	PROCESS(DRP_Clock)
	BEGIN
		IF rising_edge(DRP_Clock) THEN
			IF (Reconfig_DRP = '1') THEN
				SATAGeneration_DRP	<= SATAGeneration;
			END IF;
		END IF;
	END PROCESS;

	doReconfig				<= Reconfig_DRP;

	-- synchronize ReconfigComplete, ConfigReloaded, Locked from DRP_Clock to SATA_Clock
	sync2 : ENTITY PoC.sync_Strobe
		GENERIC MAP (
			BITS				=> 2
		)
		PORT MAP (
			Clock1			=> DRP_Clock,
			Clock2			=> SATA_Clock,
			Input(0)		=> ReconfigComplete_i,
			Input(1)		=> ConfigReloaded_i,
			Output(0)		=> ReconfigComplete,
			Output(1)		=> ConfigReloaded
		);

	PROCESS(DRP_Clock)
	BEGIN
		IF rising_edge(DRP_Clock) THEN
			IF (DRP_Reset = '1') THEN
				State				<= ST_IDLE;
			ELSE
				State				<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, doReconfig, XilDRP_ReconfigDone, GTX_ReloadConfigDone, SATAGeneration_DRP)
	BEGIN
		NextState								<= State;

		-- default assignments
		-- ==============================================================
		ReconfigComplete_i			<= '0';
		ConfigReloaded_i				<= '0';
		ReloadConfig_i					<= '0';

		-- internal modules
		XilDRP_Reconfig					<= '0';
		XilDRP_ConfigSelect			<= to_slv(0, XILDRP_CONFIGSELECT_BITS);

		CASE State IS
			WHEN ST_IDLE =>
				IF (doReconfig = '1') THEN
					NextState					<= ST_RECONFIG;		-- do reconfig
				END IF;

			-- activate XilinxReconfigurator
			-- ------------------------------------------------------------------
			WHEN ST_RECONFIG =>
				XilDRP_Reconfig				<= '1';

				case SATAGeneration_DRP is
					when SATA_GENERATION_1 =>		XilDRP_ConfigSelect <= to_slv(0, XILDRP_CONFIGSELECT_BITS);
					when SATA_GENERATION_2 =>		XilDRP_ConfigSelect <= to_slv(1, XILDRP_CONFIGSELECT_BITS);
					when SATA_GENERATION_3 =>		XilDRP_ConfigSelect <= to_slv(2, XILDRP_CONFIGSELECT_BITS);
					when others =>							XilDRP_ConfigSelect <= to_slv(0, XILDRP_CONFIGSELECT_BITS);
				end case;

				NextState							<= ST_RECONFIG_WAIT;

			WHEN ST_RECONFIG_WAIT =>
				case SATAGeneration_DRP is
					when SATA_GENERATION_1 =>		XilDRP_ConfigSelect <= to_slv(0, XILDRP_CONFIGSELECT_BITS);
					when SATA_GENERATION_2 =>		XilDRP_ConfigSelect <= to_slv(1, XILDRP_CONFIGSELECT_BITS);
					when SATA_GENERATION_3 =>		XilDRP_ConfigSelect <= to_slv(2, XILDRP_CONFIGSELECT_BITS);
					when others =>							XilDRP_ConfigSelect <= to_slv(0, XILDRP_CONFIGSELECT_BITS);
				end case;

				IF (XilDRP_ReconfigDone = '1') THEN
					ReconfigComplete_i	<= '1';
					NextState						<= ST_RELOAD;
				END IF;

			-- reload GTX_DUAL configuration
			-- ------------------------------------------------------------------
			-- assign ReloadConfig until ReloadConfigDone goes to '0'
			WHEN ST_RELOAD =>
				ReloadConfig_i				<= '1';
				NextState							<= ST_RELOAD_WAIT;

			-- wait for ReloadConfigDone
			WHEN ST_RELOAD_WAIT =>
				IF (GTX_ReloadConfigDone = '1') THEN
					ConfigReloaded_i		<= '1';
					NextState						<= ST_IDLE;
				END IF;

		END CASE;
	END PROCESS;

	XilDRP : ENTITY PoC.xil_Reconfigurator
		GENERIC MAP (
			DEBUG						=> DEBUG,
			CLOCK_FREQ			=> DRPCLOCK_FREQ,
			CONFIG_ROM			=> XILDRP_CONFIG_ROM
		)
		PORT MAP (
			Clock						=> DRP_Clock,
			Reset						=> DRP_Reset,

			Reconfig				=> XilDRP_Reconfig,
			ReconfigDone		=> XilDRP_ReconfigDone,
			ConfigSelect		=> XilDRP_ConfigSelect,

			DRP_en					=> GTX_DRP_Enable,
			DRP_Address			=> GTX_DRP_Address,
			DRP_we					=> GTX_DRP_ReadWrite,
			DRP_DataIn			=> GTX_DRP_DataIn,
			DRP_DataOut			=> GTX_DRP_DataOut,
			DRP_Ack					=> GTX_DRP_Ack
		);

	-- GTX_ReloadConfig**** interface
	GTX_ReloadConfig	<= ReloadConfig_i;

END;
