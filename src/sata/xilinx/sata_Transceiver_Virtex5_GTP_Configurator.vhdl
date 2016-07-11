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
--	changes via DRP require a full GTP_DUAL reset

--	used configuration words
--	address		bits		|	GTP_DUAL generic name				GEN_1			GEN_2		Note GEN_1			Note GEN_2
-- ===============================================================================================
--	0x05			[3]			|	PLL_TXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x05			[4]			|	PLL_TXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x09			[15]		|	PLL_RXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x0A			[0]			|	PLL_RXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x45			[15]		|	PLL_TXDIVSEL_OUT_0 [0]				 1				 0		divide by 2			divide by 1
--	0x46			[0]			|	PLL_TXDIVSEL_OUT_0 [1]				 0				 0		divide by 2			divide by 1
--	0x46			[3..2]	|	PLL_RXDIVSEL_OUT_0 [1:0]			01				00		divide by 2			divide by 1


entity sata_Transceiver_Virtex5_GTP_Configurator is
	generic (
		DEBUG											: boolean											:= FALSE;																--
		DRPCLOCK_FREQ							: FREQ												:= 100 MHz;															--
		PORTS											: positive										:= 1;																		-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 1 => C_SATA_GENERATION_MAX)		-- initial SATA Generation
	);
	port (
		DRP_Clock								: in	std_logic;
		DRP_Reset								: in	std_logic;

		SATA_Clock							: in	std_logic_vector(PORTS - 1 downto 0);

		Reconfig								: in	std_logic_vector(PORTS - 1 downto 0);							-- @SATA_Clock
		SATAGeneration					: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);			-- @SATA_Clock
		ReconfigComplete				: out	std_logic_vector(PORTS - 1 downto 0);							-- @SATA_Clock
		ConfigReloaded					: out	std_logic_vector(PORTS - 1 downto 0);							-- @SATA_Clock
		Lock										: in	std_logic_vector(PORTS - 1 downto 0);							-- @SATA_Clock
		Locked									: out	std_logic_vector(PORTS - 1 downto 0);							-- @SATA_Clock

		NoDevice								: in	std_logic_vector(PORTS - 1 downto 0);							-- @DRP_Clock

		GTP_DRP_en							: out	std_logic;																				-- @DRP_Clock
		GTP_DRP_Address					: out	T_XIL_DRP_ADDRESS;																-- @DRP_Clock
		GTP_DRP_we							: out	std_logic;																				-- @DRP_Clock
		GTP_DRP_DataIn					: in	T_XIL_DRP_DATA;																		-- @DRP_Clock
		GTP_DRP_DataOut					: out	T_XIL_DRP_DATA;																		-- @DRP_Clock
		GTP_DRP_Ack							: in	std_logic;																				-- @DRP_Clock

		GTP_ReloadConfig				: out	std_logic;																				-- @DRP_Clock
		GTP_ReloadConfigDone		: in	std_logic																					-- @DRP_Clock
	);
end;

architecture rtl of sata_Transceiver_Virtex5_GTP_Configurator is
	attribute KEEP								: boolean;
	attribute FSM_ENCODING				: string;

	function vec(value : std_logic) return std_logic_vector is
		variable Result : std_logic_vector(0 downto 0) := (others => value);
	begin
		return Result;
	end function;

	function mv(value : std_logic_vector; move : integer) return std_logic_vector is
		variable Result : std_logic_vector(value'left + move downto value'right + move) := value;
	begin
		return Result;
	end function;

	function ins(value: std_logic_vector; Length : natural) return std_logic_vector is
		variable Result		: std_logic_vector(Length - 1 downto 0)		:= (others => '0');
	begin
		Result(value'range)	:= value;
		return Result;
	end function;

	function slv(value : unsigned) return std_logic_vector is
	begin
		return std_logic_vector(value);
	end function;

	-- 1. descibe all used generics
	type GTP_GENERICS is record
		PLL_TXDIVSEL_OUT_0		: unsigned(1 downto 0);			-- Port 0: PLL TX ClockDivider
		PLL_RXDIVSEL_OUT_0		: unsigned(1 downto 0);			-- Port 0: PLL RX ClockDivider
		PLL_TXDIVSEL_OUT_1		: unsigned(1 downto 0);			-- Port 1: PLL TX ClockDivider
		PLL_RXDIVSEL_OUT_1		: unsigned(1 downto 0);			-- Port 1: PLL RX ClockDivider
	end record;
	type GTP_GENERICS_VECTOR is array(natural range <>) of GTP_GENERICS;

	-- 2. assign each generic for each speed configuration
	-- *DIVSEL_OUT_*:		0 -> divide by 1,		1 -> divide by 2
	--
	-- index -> speed configuration
	constant GTP_CONFIGS									: GTP_GENERICS_VECTOR := (
		-- SATA Generation 1: set dividers to "01" for divide by 2
		0 => (PLL_TXDIVSEL_OUT_0 => to_unsigned(1, 2),
					PLL_RXDIVSEL_OUT_0 => to_unsigned(1, 2),
					PLL_TXDIVSEL_OUT_1 => to_unsigned(1, 2),
					PLL_RXDIVSEL_OUT_1 => to_unsigned(1, 2)),
		-- SATA Generation 2 set dividers to "00" for divide by 1
		1 => (PLL_TXDIVSEL_OUT_0 => to_unsigned(0, 2),
					PLL_RXDIVSEL_OUT_0 => to_unsigned(0, 2),
					PLL_TXDIVSEL_OUT_1 => to_unsigned(0, 2),
					PLL_RXDIVSEL_OUT_1 => to_unsigned(0, 2))
		);

	-- 3. convert generics into ConfigROM enties for each config set and each speed configuration
	constant XILDRP_CONFIG_ROM								: T_XIL_DRP_CONFIG_ROM := (
		-- Port 0, SATA Generation 1
		0 => (Configs =>																				--		insert, move, convert			generic							position, length
							(0 => (Address => x"0045", Mask => x"8000", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_TXDIVSEL_OUT_0(0)), 15), 16)),				-- 0x45,	[15]				x___ ____ ____ ____
							 1 => (Address => x"0046", Mask => x"0001", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_TXDIVSEL_OUT_0(1)),	 0), 16)),				-- 0x46,	[0]					____ ____ ____ ___x
							 2 => (Address => x"0046", Mask => x"000C", Data => ins(mv(slv(GTP_CONFIGS(0).PLL_RXDIVSEL_OUT_0),		 2), 16)),				-- 0x46,	[3..2]			____ ____ ____ xx__
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 2),
		-- Port 0, SATA Generation 2
		1 => (Configs =>																				--		insert, move, convert			generic							position, length
							(0 => (Address => x"0045", Mask => x"8000", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_TXDIVSEL_OUT_0(0)), 15), 16)),				-- 0x45,	[15]				x___ ____ ____ ____
							 1 => (Address => x"0046", Mask => x"0001", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_TXDIVSEL_OUT_0(1)),	 0), 16)),				-- 0x46,	[0]					____ ____ ____ ___x
							 2 => (Address => x"0046", Mask => x"000C", Data => ins(mv(slv(GTP_CONFIGS(1).PLL_RXDIVSEL_OUT_0),		 2), 16)),				-- 0x46,	[3..2]			____ ____ ____ xx__
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 2),
		-- Port 1, SATA Generation 1
		2 => (Configs =>																				--		insert, move, convert			generic							position, length
							(0 => (Address => x"0005", Mask => x"0008", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_TXDIVSEL_OUT_1(1)),	 3), 16)),				-- 0x05,	[3]					____ ____ ____ x___
							 1 => (Address => x"0005", Mask => x"0010", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_TXDIVSEL_OUT_1(0)),	 4), 16)),				-- 0x05,	[4]					____ ____ ___x ____
							 2 => (Address => x"0009", Mask => x"8000", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_RXDIVSEL_OUT_1(1)), 15), 16)),				-- 0x09,	[15]				x___ ____ ____ ____
							 3 => (Address => x"000A", Mask => x"0001", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_RXDIVSEL_OUT_1(0)),	 0), 16)),				-- 0x0A,	[0]					____ ____ ____ ___x
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 3),
		-- Port 1, SATA Generation 2
		3 => (Configs =>																				--		insert, move, convert			generic							position, length
							(0 => (Address => x"0005", Mask => x"0008", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_TXDIVSEL_OUT_1(1)),	 3), 16)),				-- 0x05,	[3]					____ ____ ____ x___
							 1 => (Address => x"0005", Mask => x"0010", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_TXDIVSEL_OUT_1(0)),	 4), 16)),				-- 0x05,	[4]					____ ____ ___x ____
							 2 => (Address => x"0009", Mask => x"8000", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_RXDIVSEL_OUT_1(1)), 15), 16)),				-- 0x09,	[15]				x___ ____ ____ ____
							 3 => (Address => x"000A", Mask => x"0001", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_RXDIVSEL_OUT_1(0)),	 0), 16)),				-- 0x0A,	[0]					____ ____ ____ ___x
							 others => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 3)
		);

	constant XILDRP_CONFIGSELECT_BITS	: positive										:= log2ceilnz(XILDRP_CONFIG_ROM'length);

	type T_STATE is (
		ST_IDLE,
		ST_LOCKED,
		ST_LOCKED_RECONFIG,

		ST_RECONFIG_PORT0,	ST_RECONFIG_PORT0_WAIT,
		ST_RECONFIG_PORT1,	ST_RECONFIG_PORT1_WAIT,
		ST_RELOAD,					ST_RELOAD_WAIT
	);

	-- GTP_DualConfiguration - Statemachine
	signal State											: T_STATE											:= ST_IDLE;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING	of State	: signal is getFSMEncoding_gray(DEBUG);

	signal Reconfig_DRP								: std_logic_vector(PORTS - 1 downto 0);
	signal ReconfigComplete_i					: std_logic;
	signal ConfigReloaded_i						: std_logic;
	signal SATAGeneration_DRP					: T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0)	:= INITIAL_SATA_GENERATIONS;

	signal Lock_DRP										: std_logic_vector(PORTS - 1 downto 0);
	signal Locked_i										: std_logic;

	signal doReconfig									: std_logic;
	signal doLock											: std_logic;

	signal ReloadConfig_i							: std_logic;

	signal XilDRP_Reconfig						: std_logic;
	signal XilDRP_ReconfigDone				: std_logic;
	signal XilDRP_ConfigSelect				: std_logic_vector(XILDRP_CONFIGSELECT_BITS - 1 downto 0);

begin
	assert (PORTS <= 2)	report "to many ports per transceiver"	severity FAILURE;

	-- cross clock domain bit synchronisation
	genSyncSATA_DRP : for i in 0 to PORTS - 1 generate
		signal Lock_i								: std_logic;
		signal SATAGeneration_SATA	: T_SATA_GENERATION			:= INITIAL_SATA_GENERATIONS(I);
	begin
		-- synchronize Reconfig(I), Lock(I), SATAGeneration(I) from SATA_Clock to DRP_Clock
		sync1 : entity PoC.sync_Flag
			port map (
				Clock				=> DRP_Clock,
				Input(0)		=> Lock(I),
				Output(0)		=> Lock_i
			);

		sync2 : entity PoC.sync_Strobe
			port map (
				Clock1			=> SATA_Clock(I),
				Clock2			=> DRP_Clock,
				Input(0)		=> Reconfig(I),
				Output(0)		=> Reconfig_DRP(I)
			);

		-- only connected ports can request locks
		Lock_DRP(I)					<= Lock_i	and (not NoDevice(I));

		-- register SATAGeneration in old clock domain
		SATAGeneration_SATA	<= SATAGeneration(I) when rising_edge(SATA_Clock(I));

		-- sample SATAGeneration in new clock domain if Reconfig occurs (SATAGeneration was stable for several cycles)
		process(DRP_Clock)
		begin
			if rising_edge(DRP_Clock) then
				if (Reconfig_DRP(I) = '1') then
					SATAGeneration_DRP(I)	<= SATAGeneration_SATA;
				end if;
			end if;
		end process;
	end generate;

	-- calculate shared control signals
	doReconfig				<= slv_or(Reconfig_DRP);
	doLock						<= slv_or(Lock_DRP);

	genSyncDRP_SATA : for i in 0 to PORTS - 1 generate
		-- synchronize Locked_i from DRP_Clock to SATA_Clock(I)
		sync1 : entity PoC.sync_Flag
			port map (
				Clock				=> DRP_Clock,
				Input(0)		=> Locked_i,
				Output(0)		=> Locked(I)
			);

		-- synchronize ReconfigComplete, ConfigReloaded, Locked from DRP_Clock to SATA_Clock
		sync2 : entity PoC.sync_Strobe
			generic map (
				BITS				=> 2
			)
			port map (
				Clock1			=> DRP_Clock,
				Clock2			=> SATA_Clock(I),
				Input(0)		=> ReconfigComplete_i,
				Input(1)		=> ConfigReloaded_i,
				Output(0)		=> ReconfigComplete(I),
				Output(1)		=> ConfigReloaded(I)
			);
	end generate;

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


	process(State, doReconfig, doLock, XilDRP_ReconfigDone, GTP_ReloadConfigDone, SATAGeneration_DRP)
	begin
		NextState				<= State;

		-- default assignments
		-- ==============================================================
		Locked_i								<= '0';
		ReconfigComplete_i			<= '0';
		ConfigReloaded_i				<= '0';

		-- GTP shared port
		ReloadConfig_i					<= '0';

		-- internal modules
		XilDRP_Reconfig					<= '0';
		XilDRP_ConfigSelect			<= to_slv(0, XILDRP_CONFIGSELECT_BITS);

		case State is
			when ST_IDLE =>
				if (doLock = '1') then
					if (doReconfig = '1') then
						NextState						<= ST_LOCKED_RECONFIG;	-- do reconfig, but lock is set
					else
						NextState						<= ST_LOCKED;						-- lock is set
					end if;
				else																						-- no lock is requested
					if (doReconfig = '1') then
						NextState						<= ST_RECONFIG_PORT0;		-- do reconfig
					end if;
				end if;

			when ST_LOCKED =>
				Locked_i								<= '1';									-- expose lock-state

				if (doReconfig = '1') then
					if (doLock = '1') then												-- do reconfig, but lock is set
						NextState						<= ST_LOCKED_RECONFIG;
					else
						NextState						<= ST_RECONFIG_PORT0;		-- do reconfig only for port 0
					end if;
				else	-- doReconfig
					if (doLock = '0') then
						NextState						<= ST_IDLE;
					else
						null;
					end if;
				end if;

			when ST_LOCKED_RECONFIG =>
				Locked_i								<= '1';									-- expose lock-state

				if (doLock = '0') then													-- no lock is set, start reconfig
					NextState							<= ST_RECONFIG_PORT0;		-- do reconfig only for port 0
				end if;

-- activate XilinxReconfigurator
-- ------------------------------------------------------------------
			when ST_RECONFIG_PORT0 =>
				XilDRP_Reconfig				<= '1';
				XilDRP_ConfigSelect		<= ite((SATAGeneration_DRP(0) = SATA_GENERATION_1), to_slv(0, XILDRP_CONFIGSELECT_BITS), to_slv(1, XILDRP_CONFIGSELECT_BITS));

				NextState							<= ST_RECONFIG_PORT0_WAIT;

			when ST_RECONFIG_PORT0_WAIT =>
				XilDRP_ConfigSelect		<= ite((SATAGeneration_DRP(0) = SATA_GENERATION_1), to_slv(0, XILDRP_CONFIGSELECT_BITS), to_slv(1, XILDRP_CONFIGSELECT_BITS));

				if (XilDRP_ReconfigDone = '1') then
					if (PORTS = 2) then
						NextState						<= ST_RECONFIG_PORT1;
					else
						ReconfigComplete_i	<= '1';
						NextState						<= ST_RELOAD;
					end if;
				end if;

			when ST_RECONFIG_PORT1 =>
				XilDRP_Reconfig				<= '1';
				XilDRP_ConfigSelect		<= ite((SATAGeneration_DRP(imin(1, PORTS - 1)) = SATA_GENERATION_1), to_slv(2, XILDRP_CONFIGSELECT_BITS), to_slv(3, XILDRP_CONFIGSELECT_BITS));

				NextState							<= ST_RECONFIG_PORT1_WAIT;

			when ST_RECONFIG_PORT1_WAIT =>
				XilDRP_ConfigSelect		<= ite((SATAGeneration_DRP(imin(1, PORTS - 1)) = SATA_GENERATION_1), to_slv(2, XILDRP_CONFIGSELECT_BITS), to_slv(3, XILDRP_CONFIGSELECT_BITS));

				if (XilDRP_ReconfigDone = '1') then
					ReconfigComplete_i	<= '1';
					NextState						<= ST_RELOAD;
				end if;
-- reload GTP_DUAL configuration
-- ------------------------------------------------------------------
			-- assign ReloadConfig until ReloadConfigDone goes to '0'
			when ST_RELOAD =>
				ReloadConfig_i				<= '1';

				if (GTP_ReloadConfigDone = '0') then
					NextState						<= ST_RELOAD_WAIT;
				end if;

			-- wait for ReloadConfigDone
			when ST_RELOAD_WAIT =>
				if (GTP_ReloadConfigDone = '1') then
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

			DRP_en					=> GTP_DRP_en,
			DRP_Address			=> GTP_DRP_Address,
			DRP_we					=> GTP_DRP_we,
			DRP_DataIn			=> GTP_DRP_DataIn,
			DRP_DataOut			=> GTP_DRP_DataOut,
			DRP_Ack					=> GTP_DRP_Ack
		);

	-- GTP_ReloadConfig**** interface
	GTP_ReloadConfig	<= ReloadConfig_i;

end;
