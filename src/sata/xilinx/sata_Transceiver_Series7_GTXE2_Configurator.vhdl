-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					TODO
--
-- Description:
-- -------------------------------------
--		For detailed documentation see below.
--
-- License:
-- =============================================================================
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
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
--use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.sata.all;
use			PoC.xil.all;


-- ==================================================================
-- Notice
-- ==================================================================
--	modifies FPGA configuration bits via Dynamic Reconfiguration Port (DRP)
--	changes via DRP require a full GTX_DUAL reset

--	used configuration words
--	address		bits		|	GTX_DUAL generic name				GEN_1			GEN_2		Note GEN_1			Note GEN_2
-- =============================================================================
--	0x05			[3]			|	PLL_TXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x05			[4]			|	PLL_TXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x09			[15]		|	PLL_RXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x0A			[0]			|	PLL_RXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x45			[15]		|	PLL_TXDIVSEL_OUT_0 [0]				 1				 0		divide by 2			divide by 1
--	0x46			[0]			|	PLL_TXDIVSEL_OUT_0 [1]				 0				 0		divide by 2			divide by 1
--	0x46			[3..2]	|	PLL_RXDIVSEL_OUT_0 [1:0]			01				00		divide by 2			divide by 1


entity sata_Transceiver_Series7_GTXE2_Configurator is
	generic (
		DEBUG											: boolean							:= FALSE;										--
		DRPCLOCK_FREQ							: FREQ								:= 0 MHz;										--
		INITIAL_SATA_GENERATION		: T_SATA_GENERATION		:= C_SATA_GENERATION_MAX		-- intial SATA Generation
	);
	port (
		DRP_Clock								: in	std_logic;
		DRP_Reset								: in	std_logic;

		SATA_Clock							: in	std_logic;

		Reconfig								: in	std_logic;							-- @SATA_Clock
		SATAGeneration					: in	T_SATA_GENERATION;			-- @SATA_Clock
		ReconfigComplete				: out	std_logic;							-- @SATA_Clock
		ConfigReloaded					: out	std_logic;							-- @SATA_Clock

		GTX_DRP_Enable					: out	std_logic;							-- @DRP_Clock
		GTX_DRP_Address					: out	T_XIL_DRP_ADDRESS;			-- @DRP_Clock
		GTX_DRP_ReadWrite				: out	std_logic;							-- @DRP_Clock
		GTX_DRP_DataIn					: in	T_XIL_DRP_DATA;					-- @DRP_Clock
		GTX_DRP_DataOut					: out	T_XIL_DRP_DATA;					-- @DRP_Clock
		GTX_DRP_Ack							: in	std_logic;							-- @DRP_Clock

		GTX_ReloadConfig				: out	std_logic;							-- @DRP_Clock
		GTX_ReloadConfigDone		: in	std_logic								-- @DRP_Clock
	);
end;


architecture rtl of sata_Transceiver_Series7_GTXE2_Configurator is
	attribute KEEP								: boolean;
	attribute FSM_ENCODING				: string;

	function ins(value: std_logic_vector; Length : natural) return std_logic_vector is
		variable Result		: std_logic_vector(Length - 1 downto 0)		:= (others => '0');
	begin
		Result(value'range)	:= value;
		return Result;
	end function;

	-- 1. descibe all used generics
	type GTX_GENERICS is record
		RX_CDR_CFG				: std_logic_vector(71 downto 0);		-- RX CDR Configuration; see Xilinx AR# 53364 - CDR settings for SSC (spread spectrum clocking)
	end record;
	type GTX_GENERICS_VECTOR is array(natural range <>) of GTX_GENERICS;

	-- 2. assign each generic for each speed configuration
	--		index -> speed configuration
	constant GTX_CONFIGS			: GTX_GENERICS_VECTOR := (
		-- SATA Generation 1: set RX_CDR_CFG for 1.5 GHz line rate
		0 => (RX_CDR_CFG	=> x"0380008BFF40100008"),
		-- SATA Generation 2: set RX_CDR_CFG for 3.0 GHz line rate
		1 => (RX_CDR_CFG	=> x"0388008BFF40200008"),
		-- SATA Generation 3: set RX_CDR_CFG for 6.0 GHz line rate
		2 => (RX_CDR_CFG	=> x"0380008BFF10200010")
	);

	-- 3. convert generics into ConfigROM enties for each config set and each speed configuration
	constant XILDRP_CONFIG_ROM								: T_XIL_DRP_CONFIG_ROM := (
		-- Set 0, SATA Generation 1
		0 => (Configs =>																				--											SET		generic			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>					GTX_CONFIGS(0).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>					GTX_CONFIGS(0).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>					GTX_CONFIGS(0).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>					GTX_CONFIGS(0).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"00FF", Data => x"00" & GTX_CONFIGS(0).RX_CDR_CFG(71 downto 64)),		-- 0x0AC,	[7..0]			____ ____ xxxx xxxx
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 4),
		-- Set 0, SATA Generation 2
		1 => (Configs =>																				--											SET		generic			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>					GTX_CONFIGS(1).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>					GTX_CONFIGS(1).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>					GTX_CONFIGS(1).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>					GTX_CONFIGS(1).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"00FF", Data => x"00" & GTX_CONFIGS(1).RX_CDR_CFG(71 downto 64)),		-- 0x0AC,	[7..0]			____ ____ xxxx xxxx
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 4),
		-- Set 0, SATA Generation 3
		2 => (Configs =>																				--											SET		generic			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>					GTX_CONFIGS(2).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>					GTX_CONFIGS(2).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>					GTX_CONFIGS(2).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>					GTX_CONFIGS(2).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"00FF", Data => x"00" & GTX_CONFIGS(2).RX_CDR_CFG(71 downto 64)),		-- 0x0AC,	[7..0]			____ ____ xxxx xxxx
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 4)
	);

	constant XILDRP_CONFIGSELECT_BITS	: positive			:= log2ceilnz(XILDRP_CONFIG_ROM'length);

	type T_STATE is (
		ST_IDLE,
		ST_RECONFIG,	ST_RECONFIG_WAIT,
		ST_RELOAD,		ST_RELOAD_WAIT
	);

	-- GTXE2_Configuration - Statemachine
	signal State											: T_STATE											:= ST_IDLE;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING	of State	: signal is getFSMEncoding_gray(DEBUG);

	signal Reconfig_DRP								: std_logic;
	signal ReconfigComplete_i					: std_logic;
	signal ConfigReloaded_i						: std_logic;
	signal SATAGeneration_DRP					: T_SATA_GENERATION		:= INITIAL_SATA_GENERATION;

	signal doReconfig									: std_logic;

	signal ReloadConfig_i							: std_logic;

	signal XilDRP_Reconfig						: std_logic;
	signal XilDRP_ReconfigDone				: std_logic;
	signal XilDRP_ConfigSelect				: std_logic_vector(XILDRP_CONFIGSELECT_BITS - 1 downto 0);

begin
	-- synchronize Reconfig, SATAGeneration from SATA_Clock to DRP_Clock
	sync1 : entity PoC.sync_Strobe
		port map (
			Clock1			=> SATA_Clock,
			Clock2			=> DRP_Clock,
			Input(0)		=> Reconfig,
			Output(0)		=> Reconfig_DRP
		);

	-- sample SATAGeneration in new clock domain if Reconfig occurs (SATAGeneration was stable for several cycles)
	process(DRP_Clock)
	begin
		if rising_edge(DRP_Clock) then
			if (Reconfig_DRP = '1') then
				SATAGeneration_DRP	<= SATAGeneration;
			end if;
		end if;
	end process;

	doReconfig				<= Reconfig_DRP;

	-- synchronize ReconfigComplete, ConfigReloaded, Locked from DRP_Clock to SATA_Clock
	sync2 : entity PoC.sync_Strobe
		generic map (
			BITS				=> 2
		)
		port map (
			Clock1			=> DRP_Clock,
			Clock2			=> SATA_Clock,
			Input(0)		=> ReconfigComplete_i,
			Input(1)		=> ConfigReloaded_i,
			Output(0)		=> ReconfigComplete,
			Output(1)		=> ConfigReloaded
		);

	process(DRP_Clock)
	begin
		if rising_edge(DRP_Clock) then
			if (DRP_Reset = '1') then
				State				<= ST_IDLE;
			else
				State				<= NextState;
			end if;
		end if;
	end process;

	process(State, doReconfig, XilDRP_ReconfigDone, GTX_ReloadConfigDone, SATAGeneration_DRP)
	begin
		NextState								<= State;

		-- default assignments
		-- ==============================================================
		ReconfigComplete_i			<= '0';
		ConfigReloaded_i				<= '0';
		ReloadConfig_i					<= '0';

		-- internal modules
		XilDRP_Reconfig					<= '0';
		XilDRP_ConfigSelect			<= to_slv(0, XILDRP_CONFIGSELECT_BITS);

		case State is
			when ST_IDLE =>
				if (doReconfig = '1') then
					NextState					<= ST_RECONFIG;		-- do reconfig
				end if;

			-- activate XilinxReconfigurator
			-- ------------------------------------------------------------------
			when ST_RECONFIG =>
				XilDRP_Reconfig				<= '1';

				case SATAGeneration_DRP is
					when SATA_GENERATION_1 =>		XilDRP_ConfigSelect <= to_slv(0, XILDRP_CONFIGSELECT_BITS);
					when SATA_GENERATION_2 =>		XilDRP_ConfigSelect <= to_slv(1, XILDRP_CONFIGSELECT_BITS);
					when SATA_GENERATION_3 =>		XilDRP_ConfigSelect <= to_slv(2, XILDRP_CONFIGSELECT_BITS);
					when others =>							XilDRP_ConfigSelect <= to_slv(0, XILDRP_CONFIGSELECT_BITS);
				end case;

				NextState							<= ST_RECONFIG_WAIT;

			when ST_RECONFIG_WAIT =>
				case SATAGeneration_DRP is
					when SATA_GENERATION_1 =>		XilDRP_ConfigSelect <= to_slv(0, XILDRP_CONFIGSELECT_BITS);
					when SATA_GENERATION_2 =>		XilDRP_ConfigSelect <= to_slv(1, XILDRP_CONFIGSELECT_BITS);
					when SATA_GENERATION_3 =>		XilDRP_ConfigSelect <= to_slv(2, XILDRP_CONFIGSELECT_BITS);
					when others =>							XilDRP_ConfigSelect <= to_slv(0, XILDRP_CONFIGSELECT_BITS);
				end case;

				if (XilDRP_ReconfigDone = '1') then
					ReconfigComplete_i	<= '1';
					NextState						<= ST_RELOAD;
				end if;

			-- reload GTX_DUAL configuration
			-- ------------------------------------------------------------------
			-- assign ReloadConfig until ReloadConfigDone goes to '0'
			when ST_RELOAD =>
				ReloadConfig_i				<= '1';
				NextState							<= ST_RELOAD_WAIT;

			-- wait for ReloadConfigDone
			when ST_RELOAD_WAIT =>
				if (GTX_ReloadConfigDone = '1') then
					ConfigReloaded_i		<= '1';
					NextState						<= ST_IDLE;
				end if;

		end case;
	end process;

	XilDRP : entity PoC.xil_Reconfigurator
		generic map (
			DEBUG						=> DEBUG,
			CLOCK_FREQ			=> DRPCLOCK_FREQ,
			CONFIG_ROM			=> XILDRP_CONFIG_ROM
		)
		port map (
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

end;
