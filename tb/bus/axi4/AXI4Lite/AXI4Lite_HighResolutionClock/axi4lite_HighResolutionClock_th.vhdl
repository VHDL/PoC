-- =============================================================================
-- Authors:
--   Adrian Weiland
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.AXI4Lite_OSVVM.all;
use     PoC.utils.all;
use     PoC.physical.all;
use     PoC.vectors.all;
use     PoC.axi4lite.all;
use     PoC.uart.all;
use     PoC.math.all;
use     PoC.clock.all;

library OSVVM;
context OSVVM.OsvvmContext;

library OSVVM_Axi4;
context OSVVM_Axi4.Axi4LiteContext;

use     work.axi4lite_HighResolutionClock_tb_pkg.all;


entity axi4lite_HighResolutionClock_th is
end entity;


architecture TestHarness of axi4lite_HighResolutionClock_th is
	-- DUT
	constant CLOCK_FREQ        : FREQ          := 200 MHz;
	constant PERIOD            : T_TIME        := to_time(CLOCK_FREQ);
	constant PERIOD_FRACT      : t_fractional  := fract(PERIOD / 1.0e-9, 1000000, 1.0e-12);
	constant INCREMENT_FULL    : natural       := PERIOD_FRACT.whole;

	constant SECOND_RESOLUTION : T_SECOND_RESOLUTION := MICROSECONDS;

	signal Nanoseconds          : unsigned(63 downto 0) := (others => '0');
	signal Datetime             : T_CLOCK_Datetime      := (others => (others => '0'));

	signal Clock     : std_logic := '1';
	signal AXI_clock : std_logic := '1';
	signal Reset     : std_logic := '1';
	signal AXI_reset : std_logic := '1';

	signal AXI_m2s : T_AXI4Lite_BUS_M2S(
		AWAddr(AXI_ADDR_WIDTH - 1 downto 0),
		WData(AXI_DATA_WIDTH - 1 downto 0),
		WStrb(AXI_STRB_WIDTH-1 downto 0),
		ARAddr(AXI_ADDR_WIDTH - 1 downto 0)
	);
	signal AXI_s2m : T_AXI4Lite_BUS_S2M(
		RData(AXI_DATA_WIDTH - 1 downto 0)
	);

	-- Clock, reset generation
	constant tperiod_Clk : time := to_time(CLOCK_FREQ);
	constant tpd         : time := 0 ns;

	-- Transaction interfaces
	signal AXI_Manager : AddressBusRecType(
		Address      (AXI_ADDR_WIDTH - 1 downto 0),
		DataToModel  (AXI_DATA_WIDTH - 1 downto 0),
		DataFromModel(AXI_DATA_WIDTH - 1 downto 0)
	);

	-- AXI Manager physical Interface
	signal AxiLiteBus : Axi4LiteRecType(
		WriteAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0)),
		WriteData   (Data(AXI_DATA_WIDTH - 1 downto 0), Strb(AXI_STRB_WIDTH - 1 downto 0)),
		ReadAddress (Addr(AXI_ADDR_WIDTH - 1 downto 0)),
		ReadData    (Data(AXI_DATA_WIDTH - 1 downto 0))
	);
	
	component axi4Lite_HighResolutionClock_tc
		generic (
			CLOCK_FREQ     : FREQ;
			INCREMENT_FULL : natural
		);
		port (
			Reset       : in std_logic;
			AXI_Manager : inout AddressBusRecType
		);
	end component;

begin
	-- Create system clock
	clk: Osvvm.ClockResetPkg.CreateClock(
		Clk             => Clock,
		Period          => tperiod_Clk
	);

	-- Create system reset
	rst: Osvvm.ClockResetPkg.CreateReset (
		Reset           => Reset,
		ResetActive     => '1',
		Clk             => Clock,
		Period          => 7 * tperiod_Clk,
		tpd             => tpd
	);

	 -- AXI4Lite configuration manager
	manager: entity OSVVM_AXI4.Axi4LiteManager
		generic map (
			tperiod_Clk   => tperiod_Clk,
			DEFAULT_DELAY => tpd
		)
		port map (
			Clk         => Clock,
			nReset      => not Reset,

			-- Transaction interface from TestController
			TransRec    => AXI_Manager,

			-- AXI manager physical interface
			AxiBus      => AxiLiteBus
		);
	
	-- mapping between PoC and OSVVM AXI bus types
	to_PoC_AXI4Lite_Bus_Master(AXI_m2s, AXI_s2m, AxiLiteBus);

	-- todo: check frequency
	AXI_clock <= Clock;
	AXI_reset <= Reset;
	dut: entity PoC.axi4lite_HighResolutionClock
		generic map (
			CLOCK_FREQUENCY      => 200 MHz,
			USE_CDC              => True,
			REGISTER_NANOSECONDS => 4,  -- num pipelining stages
			SECOND_RESOLUTION    => SECOND_RESOLUTION
		)
		port map (
			Clock       => Clock,
			Reset       => Reset,

			AXI_clock   => AXI_clock,
			AXI_reset   => AXI_reset,

			AXI_m2s     => AXI_m2s,
			AXI_s2m     => AXI_s2m,

			Nanoseconds => Nanoseconds,
			Datetime    => Datetime
		);
	
	TestCtrl: component axi4lite_HighResolutionClock_tc
		generic map (
			CLOCK_FREQ     => CLOCK_FREQ,
			INCREMENT_FULL => INCREMENT_FULL
		)
		port map (
			Reset          => Reset,
			AXI_Manager    => AXI_Manager
		);
	
end architecture;
