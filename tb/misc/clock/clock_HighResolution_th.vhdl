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
use     PoC.physical.all;
use     PoC.vectors.all;
use     PoC.axi4lite.all;
use     PoC.uart.all;
use     PoC.clock.all;

library OSVVM;
context OSVVM.OsvvmContext;

library OSVVM_Axi4;
context OSVVM_Axi4.Axi4LiteContext;


entity clock_HighResolution_th is
end entity;


architecture TestHarness of clock_HighResolution_th is

	constant AXI_ADDR_WIDTH : integer := 32;
	constant AXI_DATA_WIDTH : integer := 32;
	constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH / 8;

	-- DUT
	constant SECOND_RESOLUTION : T_SECOND_RESOLUTION := MILLISECONDS;
	constant CLOCK_FREQ        : FREQ                := 1000 MHz;

	signal Load_nanoseconds    : std_logic             := '0';
	signal Load_datetime       : std_logic             := '0';
	signal Nanoseconds_to_load : unsigned(63 downto 0) := (others => '0');
	signal Datetime_to_load    : T_CLOCK_Datetime      := (others => (others => '0'));
	signal Ns_inc              : std_logic             := '0';
	signal Ns_dec              : std_logic             := '0';
	signal Nanoseconds         : unsigned(63 downto 0) := (others => '0');
	signal Nanoseconds_i       : unsigned(63 downto 0) := (others => '0');
	signal Datetime            : T_CLOCK_Datetime      := (others => (others => '0'));
	signal Datetime_i          : T_CLOCK_Datetime      := (others => (others => '0'));

	-- Clock, reset generation
	signal Clock : std_logic := '1';
	signal Reset : std_logic := '1';

	constant tperiod_Clk : time := to_time(CLOCK_FREQ);
	constant tpd         : time := 0 ns;

	signal AXI_m2s : T_AXI4Lite_BUS_M2S(
		AWAddr(AXI_ADDR_WIDTH - 1 downto 0),
		WData(AXI_DATA_WIDTH - 1 downto 0),
		WStrb(AXI_STRB_WIDTH-1 downto 0),
		ARAddr(AXI_ADDR_WIDTH - 1 downto 0)
	);
	signal AXI_s2m : T_AXI4Lite_BUS_S2M(
		RData(AXI_DATA_WIDTH - 1 downto 0)
	);

	-- Transaction interfaces
	signal AXI_Manager : AddressBusRecType(
		Address      (AXI_ADDR_WIDTH - 1 downto 0),
		DataToModel  (AXI_DATA_WIDTH - 1 downto 0),
		DataFromModel(AXI_DATA_WIDTH - 1 downto 0)
	);

	-- AXI Manager physical Interface
	signal AxiBus : Axi4LiteRecType(
		WriteAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0)),
		WriteData   (Data(AXI_DATA_WIDTH - 1 downto 0), Strb(AXI_STRB_WIDTH - 1 downto 0)),
		ReadAddress (Addr(AXI_ADDR_WIDTH - 1 downto 0)),
		ReadData    (Data(AXI_DATA_WIDTH - 1 downto 0))
	);
	
	component clock_HighResolution_tc
		generic (
			CLOCK_FREQ : FREQ
		);
		port (
			Clock       : in std_logic;
			Reset       : in std_logic;
			AXI_Manager : inout AddressBusRecType;

			Load_nanoseconds    : out std_logic;
			Load_datetime       : out std_logic;
			Nanoseconds_to_load : out unsigned(63 downto 0);
			Datetime_to_load    : out T_CLOCK_Datetime;
			
			Nanoseconds : in unsigned(63 downto 0);
			Datetime    : in T_CLOCK_Datetime
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
			AxiBus      => AxiBus
		);
		
	dut: entity PoC.clock_HighResolution
		generic map (
			SECOND_RESOLUTION => SECOND_RESOLUTION,
			CLOCK_FREQUENCY   => 1000 MHz
		)
		port map (
			Clock           => Clock,
			Reset           => Reset,

			Load_nanoseconds    => Load_nanoseconds,
			Load_datetime       => Load_datetime,
			Nanoseconds_to_load => Nanoseconds_to_load,
			Datetime_to_load    => Datetime_to_load,
			Ns_inc              => Ns_inc,
			Ns_dec              => Ns_dec,

			Nanoseconds         => Nanoseconds_i,
			Datetime            => Datetime_i
		);

	Nanoseconds <= Nanoseconds_i when rising_edge(Clock);
	Datetime	<= Datetime_i    when rising_edge(Clock);

	TestCtrl: component clock_HighResolution_tc
		generic map (
			CLOCK_FREQ     => CLOCK_FREQ
		)
		port map (
			Clock          => Clock,
			Reset          => Reset,
			AXI_Manager    => AXI_Manager,
			
			Load_nanoseconds    => Load_nanoseconds,
			Load_datetime       => Load_datetime,
			Nanoseconds_to_load => Nanoseconds_to_load,
			Datetime_to_load    => Datetime_to_load,

			Nanoseconds => Nanoseconds,
			Datetime    => Datetime
		);

end architecture;
