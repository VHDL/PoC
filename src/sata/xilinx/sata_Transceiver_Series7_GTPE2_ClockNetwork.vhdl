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
use			PoC.components.all;
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

		GTP_Clock_2X							: out	std_logic;
		GTP_Clock_4X							: out	std_logic
	);
end entity;


architecture rtl of sata_Transceiver_Series7_GTPE2_ClockNetwork is
	attribute KEEP											: boolean;

		-- delay CMB resets until the slowed syncBlock has noticed that LockedState is low
		--	control clock:				200 MHz
		--	slowest output clock:	10 Mhz
		--	worst case delay:			(Control_Clock freq / slowest clock in MHz) * register stages		+ safety
		--		=> 44								(200 MHz						/ 10 MHz)								* 2 register stages	+ 4
	constant CMB_DELAY_CYCLES						: positive		:= integer(real(CLOCK_IN_FREQ / 10 MHz) * 2.0 + 4.0);

	signal ClkNet_Reset									: std_logic;

	signal MMCM_Reset										: std_logic;
	signal MMCM_Reset_clr								: std_logic;
	signal MMCM_ResetState							: std_logic		:= '0';
	signal MMCM_Reset_delayed						: std_logic_vector(CMB_DELAY_CYCLES - 1 downto 0) := (others => '0');
	signal MMCM_Locked_async						: std_logic;
	signal MMCM_Locked									: std_logic;
	signal MMCM_Locked_d								: std_logic		:= '0';
	signal MMCM_Locked_re								: std_logic;
	signal MMCM_LockedState							: std_logic		:= '0';

	signal Locked												: std_logic;
	signal Reset												: std_logic;

	signal Control_Clock								: std_logic;
	signal Control_Clock_BUFR						: std_logic;

	signal MMCM_Clock_200MHz						: std_logic;
	signal MMCM_Clock_300MHz						: std_logic;
	signal MMCM_Clock_150MHz						: std_logic;

	signal MMCM_Clock_200MHz_BUFG				: std_logic;
	signal MMCM_Clock_300MHz_BUFG				: std_logic;
	signal MMCM_Clock_150MHz_BUFG				: std_logic;

	attribute KEEP of MMCM_Clock_200MHz_BUFG		: signal is DEBUG;
	attribute KEEP of MMCM_Clock_300MHz_BUFG		: signal is DEBUG;
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

	-- detect rising edge on CMB locked signals
	MMCM_Locked_d						<= MMCM_Locked	when rising_edge(Control_Clock);
	MMCM_Locked_re					<= not MMCM_Locked_d	and MMCM_Locked;

	--												RS-FF					Q										RST										SET														CLK
	-- hold reset until external reset goes low and CMB noticed reset
	MMCM_ResetState					<= ffrs(q => MMCM_ResetState,	 rst => MMCM_Reset_clr,	set => ClkNet_Reset)	 when rising_edge(Control_Clock);
	-- deassert *_LockedState, if CMBs are going to be reseted; assert it if *_Locked is high again
	MMCM_LockedState				<= ffrs(q => MMCM_LockedState, rst => ClkNet_Reset,		set => MMCM_Locked_re) when rising_edge(Control_Clock);

	-- delay CMB resets until the slowed syncBlock has noticed that LockedState is low
	MMCM_Reset_delayed			<= shreg_left(MMCM_Reset_delayed, MMCM_ResetState)	when rising_edge(Control_Clock);
	MMCM_Reset							<= MMCM_Reset_delayed(MMCM_Reset_delayed'high);

	Locked									<= MMCM_LockedState;
	ClockNetwork_ResetDone	<= Locked;

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

	-- 200 MHz BUFG
	BUFG_MMCM_Clock_200MHz : BUFG
		port map (
			I		=> MMCM_Clock_200MHz,
			O		=> MMCM_Clock_200MHz_BUFG
		);

	-- 300 MHz BUFG
	BUFG_MMCM_Clock_300MHz : BUFG
		port map (
			I		=> MMCM_Clock_300MHz,
			O		=> MMCM_Clock_300MHz_BUFG
		);

	-- 150 MHz BUFG
	BUFG_MMCM_Clock_100MHz : BUFG
		port map (
			I		=> MMCM_Clock_150MHz,
			O		=> MMCM_Clock_150MHz_BUFG
		);

	-- ==================================================================
	-- Mixed-Mode Clock Manager (MMCM)
	-- ==================================================================
	System_MMCM : MMCME2_ADV
		generic map (
			STARTUP_WAIT						=> false,
			BANDWIDTH								=> "LOW",																			-- LOW = Jitter Filter
			COMPENSATION						=> "BUF_IN",	--"ZHOLD",

			CLKIN1_PERIOD						=> to_real(to_time(CLOCK_IN_FREQ), 1 ns),
			CLKIN2_PERIOD						=> to_real(to_time(CLOCK_IN_FREQ), 1 ns),		-- Not used
			REF_JITTER1							=> 0.00048,
			REF_JITTER2							=> 0.00048,																		-- Not used

			CLKFBOUT_MULT_F					=> 4.5,
			CLKFBOUT_PHASE					=> 0.0,
			CLKFBOUT_USE_FINE_PS		=> false,

			DIVCLK_DIVIDE						=> 1,

			CLKOUT0_DIVIDE_F				=> 4.5,
			CLKOUT0_PHASE						=> 0.0,
			CLKOUT0_DUTY_CYCLE			=> 0.500,
			CLKOUT0_USE_FINE_PS			=> false,

			CLKOUT1_DIVIDE					=> 3,
			CLKOUT1_PHASE						=> 0.0,
			CLKOUT1_DUTY_CYCLE			=> 0.500,
			CLKOUT1_USE_FINE_PS			=> false,

			CLKOUT2_DIVIDE					=> 6,
			CLKOUT2_PHASE						=> 0.0,
			CLKOUT2_DUTY_CYCLE			=> 0.500,
			CLKOUT2_USE_FINE_PS			=> false,

			CLKOUT3_DIVIDE					=> 4,
			CLKOUT3_PHASE						=> 0.0,
			CLKOUT3_DUTY_CYCLE			=> 0.500,
			CLKOUT3_USE_FINE_PS			=> false,

			CLKOUT4_CASCADE					=> false,
			CLKOUT4_DIVIDE					=> 100,
			CLKOUT4_PHASE						=> 0.0,
			CLKOUT4_DUTY_CYCLE			=> 0.500,
			CLKOUT4_USE_FINE_PS			=> false
		)
		port map (
			RST									=> MMCM_Reset,

			CLKIN1							=> ClockIn_150MHz,
			CLKIN2							=> ClockIn_150MHz,
			CLKINSEL						=> '1',
			CLKINSTOPPED				=> open,

			CLKFBOUT						=> open,
			CLKFBOUTB						=> open,
			CLKFBIN							=> MMCM_Clock_200MHz_BUFG,
			CLKFBSTOPPED				=> open,

			CLKOUT0							=> MMCM_Clock_200MHz,
			CLKOUT0B						=> open,
			CLKOUT1							=> MMCM_Clock_300MHz,
			CLKOUT1B						=> open,
			CLKOUT2							=> MMCM_Clock_150MHz,
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
	--Clock_200MHz					<= MMCM_Clock_200MHz_BUFG;
	GTP_Clock_2X					<= MMCM_Clock_300MHz_BUFG;
	GTP_Clock_4X					<= MMCM_Clock_150MHz_BUFG;

	-- synchronize internal Locked signal to ouput clock domains
--	syncLocked200MHz : entity PoC.sync_Bits_Xilinx
--		port map (
--			Clock					=> MMCM_Clock_200MHz_BUFG,		-- Clock to be synchronized to
--			Input(0)			=> Locked,										-- Data to be synchronized
--			Output(0)			=> Clock_Stable_200MHz				-- synchronised data
--		);

--	syncLocked300MHz : entity PoC.sync_Bits_Xilinx
--		port map (
--			Clock					=> MMCM_Clock_300MHz_BUFG,		-- Clock to be synchronized to
--			Input(0)			=> Locked,										-- Data to be synchronized
--			Output(0)			=> Clock_Stable_300MHz				-- synchronised data
--		);

--	syncLocked150MHz : entity PoC.sync_Bits_Xilinx
--		port map (
--			Clock					=> MMCM_Clock_150MHz_BUFG,		-- Clock to be synchronized to
--			Input(0)			=> Locked,										-- Data to be synchronized
--			Output(0)			=> Clock_Stable_150MHz				-- synchronised data
--		);


	-- ==================================================================
	-- ClockMultiplexers
	-- ==================================================================
	-- SATAGeneration_d1		<= SATAGeneration			when rising_edge(ClockIn_150MHz);
	-- SATAGeneration_d2		<= SATAGeneration_d1	when rising_edge(ClockIn_150MHz);
	-- MuxControl					<= to_sl(SATAGeneration_d2 = SATA_GENERATION_2);

	-- MUX_Clock_1X : BUFGMUX
		-- port map (
			-- S		=> MuxControl,
			-- I0	=> DCM_Clock_150MHz,
			-- I1	=> DCM_Clock_300MHz,
			-- O		=> GTP_Clock_1X_i
		-- );

	-- MUX_Clock_4X : BUFGMUX
		-- port map (
			-- S		=> MuxControl,
			-- I0	=> DCM_Clock_37_5MHz,
			-- I1	=> DCM_Clock_75MHz,
			-- O		=> GTP_Clock_4X_i
		-- );
end architecture;
