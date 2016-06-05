-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
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

library UNISIM;
use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.utils.all;
use			PoC.physical.all;
use			PoC.io.all;
use			PoC.sata.all;


entity sata_Transceiver_Virtex5_GTP_ClockNetwork is
	generic (
		DEBUG											: BOOLEAN												:= TRUE;
		CLOCK_IN_FREQ							: FREQ													:= 150 MHz;																-- 150 MHz
		PORTS											: POSITIVE											:= 1;																			-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR			:= (0 to 1 => C_SATA_GENERATION_MAX)			-- intial SATA Generation
	);
	port (
		ClockIn_150MHz						: in	STD_LOGIC;

		ClockNetwork_Reset				: in	STD_LOGIC;
		ClockNetwork_ResetDone		:	OUT	STD_LOGIC;

		SATAGeneration						: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);

		GTP_Clock_1X							: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		GTP_Clock_4X							: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0)
	);
end;


architecture rtl of sata_Transceiver_Virtex5_GTP_ClockNetwork is
	attribute KEEP											: BOOLEAN;

	signal ClkNet_Reset									: STD_LOGIC;
	signal ClkNet_Reset_i								: STD_LOGIC;
	signal ClkNet_Reset_r1							: STD_LOGIC		:= '0';
	signal ClkNet_Reset_r2							: STD_LOGIC		:= '0';
	signal ClkNet_Reset_r3							: STD_LOGIC		:= '0';

	signal DCM_Reset										: STD_LOGIC;
--	signal DCM_Locked										: STD_LOGIC;
--	signal DCM_Locked_d1								: STD_LOGIC		:= '0';
--	signal DCM_Locked_d2								: STD_LOGIC		:= '0';
	signal DCM_Locked_i									: STD_LOGIC;

	signal DCM_Clock_37_5MHz						: STD_LOGIC;
	signal DCM_Clock_75MHz							: STD_LOGIC;
	signal DCM_Clock_150MHz							: STD_LOGIC;
	signal DCM_Clock_300MHz							: STD_LOGIC;

	signal GTP_Clock_1X_i								: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal GTP_Clock_4X_i								: STD_LOGIC_VECTOR(PORTS - 1 downto 0);

begin
	assert (PORTS <= 2)	report "to many ports per transceiver"	severity FAILURE;

	-- reset generation
	-- ======================================================================
	-- clock network resets
	ClkNet_Reset_i							<= ClockNetwork_Reset;																					-- @async:

	-- D-FF @ClockIn_150MHz with async reset
	process(ClockIn_150MHz)
	begin
		if rising_edge(ClockIn_150MHz) then
			if (ClkNet_Reset_i = '1') then
				ClkNet_Reset_r1		<= '1';
				ClkNet_Reset_r2		<= '1';
				ClkNet_Reset_r3		<= '1';
			else
				ClkNet_Reset_r1		<= ClkNet_Reset_i;
				ClkNet_Reset_r2		<= ClkNet_Reset_r1;
				ClkNet_Reset_r3		<= ClkNet_Reset_r2;
			end if;
		end if;
	end process;

	ClkNet_Reset								<= ClkNet_Reset_r3;																							-- @ClockIn_150MHz:
	DCM_Reset										<= ClkNet_Reset;																								-- @ClockIn_150MHz:

	-- calculate when all clocknetwork components are stable
--	DCM_Locked_d1						<= DCM_Locked_i		when rising_edge(ClockIn_150MHz);
--	DCM_Locked_d2						<= DCM_Locked_d1	when rising_edge(ClockIn_150MHz);
--	DCM_Locked							<= DCM_Locked_d2;

	ClockNetwork_ResetDone	<= DCM_Locked_i;

-- ==================================================================
-- ClockMultiplexers
-- ==================================================================
	gen1 : for i in 0 to PORTS - 1 generate
		signal SATAGeneration_d1				: T_SATA_GENERATION		:= INITIAL_SATA_GENERATIONS(INITIAL_SATA_GENERATIONS'low + I);
		signal SATAGeneration_d2				: T_SATA_GENERATION		:= INITIAL_SATA_GENERATIONS(INITIAL_SATA_GENERATIONS'low + I);
		signal MuxControl								: STD_LOGIC;

		attribute KEEP OF MuxControl		: signal IS DEBUG;
	begin
		SATAGeneration_d1		<= SATAGeneration(I) when rising_edge(ClockIn_150MHz);
		SATAGeneration_d2		<= SATAGeneration_d1 when rising_edge(ClockIn_150MHz);
		MuxControl						<= to_sl(SATAGeneration_d2 = SATA_GENERATION_2);

		MUX_Clock_1X : BUFGMUX
			port map (
				S		=> MuxControl,
				I0	=> DCM_Clock_150MHz,
				I1	=> DCM_Clock_300MHz,
				O		=> GTP_Clock_1X_i(I)
			);

		MUX_Clock_4X : BUFGMUX
			port map (
				S		=> MuxControl,
				I0	=> DCM_Clock_37_5MHz,
				I1	=> DCM_Clock_75MHz,
				O		=> GTP_Clock_4X_i(I)
			);
	end generate;
-- ==================================================================
-- DigitalClockManager (DCM)
-- ==================================================================
	GTP_DCM : DCM_BASE
		generic map (
			-- configure CLKIN input
			CLKIN_PERIOD						=> to_real(to_time(CLOCK_IN_FREQ), 1 ns),
			DLL_FREQUENCY_MODE			=> "HIGH",
			DUTY_CYCLE_CORRECTION		=> TRUE,
			FACTORY_JF							=> x"F0F0",
			-- configure CLKFB feedback
			CLK_FEEDBACK						=> "NONE",
			-- configure CLKDV output
			CLKDV_DIVIDE						=> 2.0,
			-- configure CLKFX output
			CLKFX_MULTIPLY					=> 2,
			CLKFX_DIVIDE						=> 8
		)
		port map (
			RST											=> DCM_Reset,

			CLKIN										=> ClockIn_150MHz,
			CLKFB										=> '0',

			CLKFX										=> DCM_Clock_37_5MHz,
			CLKFX180								=> open,
			CLKDV										=> DCM_Clock_75MHz,		-- open,
			CLK0										=> DCM_Clock_150MHz,
			CLK90										=> open,
			CLK180									=> open,
			CLK270									=> open,
			CLK2X										=> DCM_Clock_300MHz,
			CLK2X180								=> open,

			LOCKED									=> DCM_Locked_i
		);

	GTP_Clock_1X			<= GTP_Clock_1X_i;
	GTP_Clock_4X			<= GTP_Clock_4X_i;

	genCSP : if (DEBUG = TRUE) generate
		signal DBG_Clock_300MHz								: STD_LOGIC;

		attribute KEEP OF DBG_Clock_300MHz		: signal IS TRUE;
	begin
		BUFG_Clock_300MHz : BUFG
			port map (
				I		=> DCM_Clock_300MHz,
				O		=> DBG_Clock_300MHz
			);
	end generate;

end;
