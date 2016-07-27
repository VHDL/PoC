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

library UNISIM;
use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.utils.all;
use			PoC.physical.all;
use			PoC.io.all;
use			PoC.sata.all;


entity sata_Transceiver_Series7_GTPE2_ClockNetwork is
	generic (
		DEBUG											: boolean								:= TRUE;
		CLOCK_IN_FREQ							: FREQ									:= 150 MHz;										-- 150 MHz
		INITIAL_SATA_GENERATION		: T_SATA_GENERATION			:= C_SATA_GENERATION_MAX			-- intial SATA Generation
	);
	port (
		ClockIn_150MHz						: in	std_logic;

		ClockNetwork_Reset				: in	std_logic;
		ClockNetwork_ResetDone		:	out	std_logic;

		SATAGeneration						: in	T_SATA_GENERATION;

		GTP_Clock_1X							: out	std_logic;
		GTP_Clock_4X							: out	std_logic
	);
end entity;


architecture rtl of sata_Transceiver_Series7_GTPE2_ClockNetwork is
	attribute KEEP											: boolean;

	signal ClkNet_Reset									: std_logic;
	signal ClkNet_Reset_i								: std_logic;
	signal ClkNet_Reset_r1							: std_logic		:= '0';
	signal ClkNet_Reset_r2							: std_logic		:= '0';
	signal ClkNet_Reset_r3							: std_logic		:= '0';

	signal DCM_Reset										: std_logic;
--	signal DCM_Locked										: STD_LOGIC;
--	signal DCM_Locked_d1								: STD_LOGIC		:= '0';
--	signal DCM_Locked_d2								: STD_LOGIC		:= '0';
	signal DCM_Locked_i									: std_logic;

	signal DCM_Clock_37_5MHz						: std_logic;
	signal DCM_Clock_75MHz							: std_logic;
	signal DCM_Clock_150MHz							: std_logic;
	signal DCM_Clock_300MHz							: std_logic;

	signal SATAGeneration_d1				: T_SATA_GENERATION		:= INITIAL_SATA_GENERATION;
	signal SATAGeneration_d2				: T_SATA_GENERATION		:= INITIAL_SATA_GENERATION;
	signal MuxControl								: std_logic;
	attribute KEEP of MuxControl		: signal is DEBUG;

	signal GTP_Clock_1X_i								: std_logic;
	signal GTP_Clock_4X_i								: std_logic;

begin
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
	SATAGeneration_d1		<= SATAGeneration			when rising_edge(ClockIn_150MHz);
	SATAGeneration_d2		<= SATAGeneration_d1	when rising_edge(ClockIn_150MHz);
	MuxControl					<= to_sl(SATAGeneration_d2 = SATA_GENERATION_2);

	MUX_Clock_1X : BUFGMUX
		port map (
			S		=> MuxControl,
			I0	=> DCM_Clock_150MHz,
			I1	=> DCM_Clock_300MHz,
			O		=> GTP_Clock_1X_i
		);

	MUX_Clock_4X : BUFGMUX
		port map (
			S		=> MuxControl,
			I0	=> DCM_Clock_37_5MHz,
			I1	=> DCM_Clock_75MHz,
			O		=> GTP_Clock_4X_i
		);

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
		signal DBG_Clock_300MHz								: std_logic;

		attribute KEEP of DBG_Clock_300MHz		: signal is TRUE;
	begin
		BUFG_Clock_300MHz : BUFG
			port map (
				I		=> DCM_Clock_300MHz,
				O		=> DBG_Clock_300MHz
			);
	end generate;

end architecture;
