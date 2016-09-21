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
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
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
--	changes via DRP require a full GTPE2 reset

--	used configuration words
--	address		bits		|	GTPE2 generic name					GEN_1			GEN_2		Note GEN_1			Note GEN_2
-- =============================================================================

-- To be updated.

--	0x05			[3]			|	PLL_TXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x05			[4]			|	PLL_TXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x09			[15]		|	PLL_RXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x0A			[0]			|	PLL_RXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x45			[15]		|	PLL_TXDIVSEL_OUT_0 [0]				 1				 0		divide by 2			divide by 1
--	0x46			[0]			|	PLL_TXDIVSEL_OUT_0 [1]				 0				 0		divide by 2			divide by 1
--	0x46			[3..2]	|	PLL_RXDIVSEL_OUT_0 [1:0]			01				00		divide by 2			divide by 1


entity sata_Transceiver_Series7_GTPE2_Configurator is
	generic (
		DEBUG											: boolean							:= FALSE;										--
		DRPCLOCK_FREQ							: FREQ								:= 0 MHz;										--
		INITIAL_SATA_GENERATION		: T_SATA_GENERATION		:= C_SATA_GENERATION_MAX		-- intial SATA Generation
	);
	port (
		DRP_Clock								: in	std_logic;
		DRP_Reset								: in	std_logic;

		SATA_Clock							: in	std_logic;

		Reconfig								: in	std_logic;											-- @SATA_Clock
		ConfigSelect						: in	std_logic_vector(2 downto 0);		-- @SATA_Clock
		ReconfigComplete				: out	std_logic;											-- @SATA_Clock

		GTP_DRP_Enable					: out	std_logic;							-- @DRP_Clock
		GTP_DRP_Address					: out	T_XIL_DRP_ADDRESS;			-- @DRP_Clock
		GTP_DRP_ReadWrite				: out	std_logic;							-- @DRP_Clock
		GTP_DRP_DataIn					: in	T_XIL_DRP_DATA;					-- @DRP_Clock
		GTP_DRP_DataOut					: out	T_XIL_DRP_DATA;					-- @DRP_Clock
		GTP_DRP_Ack							: in	std_logic								-- @DRP_Clock
	);
end entity;


architecture rtl of sata_Transceiver_Series7_GTPE2_Configurator is
	attribute KEEP								: boolean;
	attribute FSM_ENCODING				: string;

	function ins(value: std_logic_vector; Length : natural) return std_logic_vector is
		variable Result		: std_logic_vector(Length - 1 downto 0)		:= (others => '0');
	begin
		Result(value'range)	:= value;
		return Result;
	end function;

	-- 1. descibe all used generics
	type GTP_GENERICS is record
		RX_CDR_CFG				: std_logic_vector(83 downto 0);		-- RX CDR Configuration; see Xilinx AR# 53364 - CDR settings for SSC (spread spectrum clocking)
	end record;
	type GTP_GENERICS_VECTOR is array(natural range <>) of GTP_GENERICS;

	-- 2. assign each generic for each speed configuration
	--		index -> speed configuration
	constant GTP_CONFIGS			: GTP_GENERICS_VECTOR := (
		-- SATA Generation 1: set RX_CDR_CFG for 1.5 GHz line rate
		0 => (RX_CDR_CFG	=> x"0000047FE106024481010"),
		-- SATA Generation 2: set RX_CDR_CFG for 3.0 GHz line rate
		1 => (RX_CDR_CFG	=> x"0000047FE206024481010"),
		-- SATA Generation 3: set RX_CDR_CFG for 6.0 GHz line rate
		2 => (RX_CDR_CFG	=> x"0000087FE206024441010")
	);

	-- RX_DATA_WIDTH
	type RXDW_CONFIGS_VECTOR is array(0 to 1) of std_logic_vector(2 downto 0);
	constant RXDW_CONFIGS	: RXDW_CONFIGS_VECTOR := (
		0 => "100", -- 32 bit
		1 => "101"  -- 40 bit
	);

	-- 3. convert generics into ConfigROM entries for each config set and each speed configuration
	constant XILDRP_CONFIG_ROM								: T_XIL_DRP_CONFIG_ROM := (
		-- Set 0, SATA Generation 1
		0 => (Configs =>																				--															SET		generic			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>									GTP_CONFIGS(0).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>									GTP_CONFIGS(0).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>									GTP_CONFIGS(0).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>									GTP_CONFIGS(0).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"FFFF", Data => 								GTP_CONFIGS(0).RX_CDR_CFG(79 downto 64)),		-- 0x0AC,	[15..0]			xxxx xxxx xxxx xxxx
							 5 => (Address => x"00AD", Mask => x"0007", Data => x"000" & '0'	& GTP_CONFIGS(0).RX_CDR_CFG(82 downto 80)),		-- 0x0AD,	[2..0]			____ ____ ____ _xxx
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 5),
		-- Set 1, SATA Generation 2
		1 => (Configs =>																				--															SET		generic			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>									GTP_CONFIGS(1).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>									GTP_CONFIGS(1).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>									GTP_CONFIGS(1).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>									GTP_CONFIGS(1).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"FFFF", Data => 				 				GTP_CONFIGS(1).RX_CDR_CFG(79 downto 64)),		-- 0x0AC,	[15..0]			xxxx xxxx xxxx xxxx
							 5 => (Address => x"00AD", Mask => x"0007", Data => x"000" & '0'	& GTP_CONFIGS(1).RX_CDR_CFG(82 downto 80)),		-- 0x0AD,	[2..0]			____ ____ ____ _xxx
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 5),
		-- Set 2, SATA Generation 3
		2 => (Configs =>																				--															SET		generic			slice						DRP-Addr		Bits				Mask
							(0 => (Address => x"00A8", Mask => x"FFFF", Data =>									GTP_CONFIGS(2).RX_CDR_CFG(15 downto 0)),		-- 0x0A8,	[15..0]			xxxx xxxx xxxx xxxx
							 1 => (Address => x"00A9", Mask => x"FFFF", Data =>									GTP_CONFIGS(2).RX_CDR_CFG(31 downto 16)),		-- 0x0A9,	[15..0]			xxxx xxxx xxxx xxxx
							 2 => (Address => x"00AA", Mask => x"FFFF", Data =>									GTP_CONFIGS(2).RX_CDR_CFG(47 downto 32)),		-- 0x0AA,	[15..0]			xxxx xxxx xxxx xxxx
							 3 => (Address => x"00AB", Mask => x"FFFF", Data =>									GTP_CONFIGS(2).RX_CDR_CFG(63 downto 48)),		-- 0x0AB,	[15..0]			xxxx xxxx xxxx xxxx
							 4 => (Address => x"00AC", Mask => x"FFFF", Data => 								GTP_CONFIGS(2).RX_CDR_CFG(79 downto 64)),		-- 0x0AC,	[15..0]			xxxx xxxx xxxx xxxx
							 5 => (Address => x"00AD", Mask => x"0007", Data => x"000" & '0'	& GTP_CONFIGS(2).RX_CDR_CFG(82 downto 80)),		-- 0x0AD,	[2..0]			____ ____ ____ _xxx
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 5),
		-- Set 3, Set datapath to 32 bit for PMAReset
		3 => (Configs =>																				--															SET		generic											DRP-Addr		Bits				Mask
							(0 => (Address => x"0011", Mask => x"3800", Data =>	"00" & 				RXDW_CONFIGS(0) 					& "00000000000"),		-- 0x011,	[13..11]		__xx x___ ____ ____
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 0),
		-- Set 4, Set datapath to 40 bit for PMAReset
		4 => (Configs =>																				--															SET		generic											DRP-Addr		Bits				Mask
							(0 => (Address => x"0011", Mask => x"3800", Data =>	"00" & 				RXDW_CONFIGS(1) 					& "00000000000"),		-- 0x011,	[13..11]		__xx x___ ____ ____
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 0)
	);

	constant XILDRP_CONFIGSELECT_BITS	: positive			:= log2ceilnz(XILDRP_CONFIG_ROM'length);

	-- @DRP Clock
	signal Reconfig_DRP								: std_logic;
	signal ConfigSelect_DRP						: std_logic_vector(XILDRP_CONFIGSELECT_BITS - 1 downto 0);
	signal ReconfigDone_DRP						: std_logic;

	signal float : std_logic;

begin
	-- synchronize Reconfig, ConfigSelect from SATA_Clock to DRP_Clock
	sync1 : entity PoC.sync_Vector
		generic map (
			MASTER_BITS => 1,
			SLAVE_BITS	=> 3)
		port map (
			Clock1						 => SATA_Clock,
			Clock2						 => DRP_Clock,
			Input(0)					 => Reconfig,
			Input(3 downto 1)	 => ConfigSelect,
			Output(0)					 => float,
			Output(3 downto 1) => ConfigSelect_DRP,
			Changed 					 => Reconfig_DRP
		);

	-- synchronize ReconfigComplete from DRP_Clock to SATA_Clock
	sync2 : entity PoC.sync_Strobe
		port map (
			Clock1			=> DRP_Clock,
			Clock2			=> SATA_Clock,
			Input(0)		=> ReconfigDone_DRP,
			Output(0)		=> ReconfigComplete
		);

	XilDRP : entity PoC.xil_Reconfigurator
		generic map (
			DEBUG						=> DEBUG,
			CLOCK_FREQ			=> DRPCLOCK_FREQ,
			CONFIG_ROM			=> XILDRP_CONFIG_ROM
		)
		port map (
			Clock						=> DRP_Clock,
			Reset						=> DRP_Reset,

			Reconfig				=> Reconfig_DRP,
			ReconfigDone		=> ReconfigDone_DRP,
			ConfigSelect		=> ConfigSelect_DRP,

			DRP_en					=> GTP_DRP_Enable,
			DRP_Address			=> GTP_DRP_Address,
			DRP_we					=> GTP_DRP_ReadWrite,
			DRP_DataIn			=> GTP_DRP_DataIn,
			DRP_DataOut			=> GTP_DRP_DataOut,
			DRP_Ack					=> GTP_DRP_Ack
		);

end architecture;
