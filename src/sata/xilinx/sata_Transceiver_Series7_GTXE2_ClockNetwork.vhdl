-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--                  Martin Zabel
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
use			PoC.components.all;
use			PoC.io.all;
use			PoC.sata.all;


entity sata_Transceiver_Series7_GTXE2_ClockNetwork is
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

		GTP_Clock_4X							: out	std_logic
	);
end entity;


architecture rtl of sata_Transceiver_Series7_GTXE2_ClockNetwork is
	attribute KEEP											: boolean;

	signal ClkNet_Reset									: std_logic;

	signal MMCM_Reset										: std_logic;
	signal MMCM_Reset_clr								: std_logic;
	signal MMCM_Locked_async						: std_logic;
	signal MMCM_Locked									: std_logic;

	signal Locked												: std_logic;
	signal Reset												: std_logic;

	signal Control_Clock								: std_logic;
	signal Control_Clock_BUFR						: std_logic;

	signal MMCM_Clock_Feedback          : std_logic;
	signal MMCM_Clock_150MHz						: std_logic;

	signal MMCM_Clock_Feedback_BUFG			: std_logic;
	signal MMCM_Clock_150MHz_BUFG				: std_logic;

	attribute KEEP of MMCM_Clock_150MHz_BUFG		: signal is DEBUG;

begin
	-- ==================================================================
	-- ResetControl
	-- ==================================================================
	-- synchronize external (async) ClockNetwork_Reset and internal (but async) MMCM_Locked signals to "Control_Clock" domain
	syncControlClock : entity PoC.sync_Bits_Xilinx
		generic map (
			BITS					=> 2										-- number of BITS to synchronize
		)
		port map (
			Clock					=> Control_Clock,				-- Clock to be synchronized to
			Input(0)			=> ClockNetwork_Reset,	-- Data to be synchronized
			Input(1)			=> MMCM_Locked_async,		--
			Output(0)			=> ClkNet_Reset,				-- synchronised data
			Output(1)			=> MMCM_Locked					--
			);

	-- clear reset signals, if external Reset is low and CMB (clock modifying block) noticed reset -> locked = low
	MMCM_Reset_clr					<= ClkNet_Reset nor MMCM_Locked;

	-- hold reset until external reset goes low and CMB noticed reset
	MMCM_Reset							<= ffrs(q => MMCM_Reset,	 rst => MMCM_Reset_clr,	set => ClkNet_Reset)	 when rising_edge(Control_Clock);

	ClockNetwork_ResetDone	<= MMCM_Locked_async;

	-- ==================================================================
	-- ClockBuffers
	-- ==================================================================
	-- Control_Clock
	BUFR_Control_Clock : BUFR
		generic map (
			SIM_DEVICE	=> "7SERIES"
		)
		port map (
			CE	=> '1',
			CLR	=> '0',
			I		=> ClockIn_150MHz,
			O		=> Control_Clock_BUFR
		);

	Control_Clock						<= Control_Clock_BUFR;

	-- Feedback BUFG
	BUFG_MMCM_Clock_Feedback : BUFG
		port map (
			I		=> MMCM_Clock_Feedback,
			O		=> MMCM_Clock_Feedback_BUFG
		);

	-- 150 MHz BUFG
	BUFG_MMCM_Clock_150MHz : BUFG
		port map (
			I		=> MMCM_Clock_150MHz,
			O		=> MMCM_Clock_150MHz_BUFG
		);

	-- ==================================================================
	-- Mixed-Mode Clock Manager (MMCM)
	-- ==================================================================
	SATA_MMCM : MMCME2_ADV
		generic map (
			STARTUP_WAIT						=> false,
			BANDWIDTH								=> "LOW",																			-- LOW = Jitter Filter
			COMPENSATION						=> "BUF_IN",	--"ZHOLD",

			CLKIN1_PERIOD						=> to_real(to_time(CLOCK_IN_FREQ), 1 ns),
			CLKIN2_PERIOD						=> to_real(to_time(CLOCK_IN_FREQ), 1 ns),		-- Not used
			REF_JITTER1							=> 0.00048,
			REF_JITTER2							=> 0.00048,																		-- Not used

			CLKFBOUT_MULT_F					=> 900.0 / to_real(CLOCK_IN_FREQ, 1 MHz),			-- target VCO frequency is 900 MHz
			CLKFBOUT_PHASE					=> 0.0,
			CLKFBOUT_USE_FINE_PS		=> false,

			DIVCLK_DIVIDE						=> 1,

			CLKOUT0_DIVIDE_F				=> 6.0,
			CLKOUT0_PHASE						=> 0.0,
			CLKOUT0_DUTY_CYCLE			=> 0.500,
			CLKOUT0_USE_FINE_PS			=> false
		)
		port map (
			RST									=> MMCM_Reset,

			CLKIN1							=> ClockIn_150MHz,
			CLKIN2							=> ClockIn_150MHz,
			CLKINSEL						=> '1',
			CLKINSTOPPED				=> open,

			CLKFBOUT						=> MMCM_Clock_Feedback,
			CLKFBOUTB						=> open,
			CLKFBIN							=> MMCM_Clock_Feedback_BUFG,
			CLKFBSTOPPED				=> open,

			CLKOUT0							=> MMCM_Clock_150MHz,
			CLKOUT0B						=> open,
			CLKOUT1							=> open,
			CLKOUT1B						=> open,
			CLKOUT2							=> open,
			CLKOUT2B						=> open,
			CLKOUT3							=> open,
			CLKOUT3B						=> open,
			CLKOUT4							=> open,
			CLKOUT5							=> open,
			CLKOUT6							=> open,

			-- Dynamic Reconfiguration Port
			DO									=>	open,
			DRDY								=>	open,
			DADDR								=>	"0000000",
			DCLK								=>	'0',
			DEN									=>	'0',
			DI									=>	x"0000",
			DWE									=>	'0',

			PWRDWN							=>	'0',
			LOCKED							=>	MMCM_Locked_async,

			PSCLK								=>	'0',
			PSEN								=>	'0',
			PSINCDEC						=>	'0',
			PSDONE							=>	open
		);

	--Control_Clock_150MHz	<= Control_Clock_BUFR;
	GTP_Clock_4X					<= MMCM_Clock_150MHz_BUFG;

	-- ==================================================================
	-- ClockMultiplexers
	-- ==================================================================
	-- SATAGeneration_d1		<= SATAGeneration			when rising_edge(ClockIn_150MHz);
	-- SATAGeneration_d2		<= SATAGeneration_d1	when rising_edge(ClockIn_150MHz);
	-- MuxControl					<= to_sl(SATAGeneration_d2 = SATA_GENERATION_3);

	-- MUX_Clock_4X : BUFGMUX
		-- port map (
			-- S		=> MuxControl,
			-- I0	=> MMCM_Clock_75MHz,
			-- I1	=> MMCM_Clock_150MHz,
			-- O		=> GTP_Clock_4X
		-- );
end architecture;
