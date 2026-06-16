-- =============================================================================
-- Authors:
--
--
-- License:
-- =============================================================================
-- Copyright 2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
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
use     PoC.utils.all;
-- use     PoC.strings.all;
use     PoC.physical.all;
use     PoC.axi4_Full.all;
use     PoC.axi4_OSVVM.all;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_axi4;
context osvvm_axi4.Axi4Context;

entity AXI4_Mux_TestHarness is
	generic(
		NUM_TRANSACTIONS : natural := 0
	);
end entity;

architecture Harness of AXI4_Mux_TestHarness is
	constant IS_SIM : boolean := true;

	constant CLOCK_FREQ : FREQ := 100 MHz;

	constant AXI_ADDR_WIDTH : natural := 32;
	constant AXI_DATA_WIDTH : natural := 32;
	constant AXI_STRB_WIDTH : natural := AXI_DATA_WIDTH / 8;

	constant NUMBER_PORTS : positive := 5;

	component TestControl is
		generic (
			AXI_ADDR_WIDTH : natural;
			AXI_DATA_WIDTH : natural
		);
		port (
			Clock         : in  std_logic;
			Reset         : in  std_logic;

			AXI4_Manager_Transaction     : inout AddressBusRecArrayType;
			AXI4_Subordinate_Transaction : inout AddressBusRecType
		);
	end component;

	package AXI4_Package_Sized_In is
		new PoC.AXI4Full_Sized
		generic map(
			ADDRESS_BITS => AXI_ADDR_WIDTH,
			DATA_BITS    => AXI_DATA_WIDTH,
			USER_BITS    => 1,
			ID_BITS      => 3
		);
	package AXI4_Package_Sized_Out is
		new PoC.AXI4Full_Sized
		generic map(
			ADDRESS_BITS => AXI_ADDR_WIDTH,
			DATA_BITS    => AXI_DATA_WIDTH,
			USER_BITS    => 1,
			ID_BITS      => 4
		);

	signal AXI4_Manager_Transaction : AddressBusRecArrayType(0 to NUMBER_PORTS - 1)(
		Address(AXI_ADDR_WIDTH - 1 downto 0),
		DataToModel(AXI_DATA_WIDTH - 1 downto 0),
		DataFromModel(AXI_DATA_WIDTH - 1 downto 0)
		);
	signal AXI4_Subordinate_Transaction : AddressBusRecType (
		Address(30 - 1 downto 0),
		DataToModel(AXI_DATA_WIDTH - 1 downto 0),
		DataFromModel(AXI_DATA_WIDTH - 1 downto 0)
		);

	signal Clock : std_logic := '1';
	signal Reset : std_logic := '1';

	signal In_M2S   : AXI4_Package_Sized_In.Sized_M2S_VECTOR(0 to NUMBER_PORTS - 1);
	signal In_S2M   : AXI4_Package_Sized_In.Sized_S2M_VECTOR(0 to NUMBER_PORTS - 1);
	signal Out_M2S  : AXI4_Package_Sized_Out.Sized_M2S;
	signal Out_S2M  : AXI4_Package_Sized_Out.Sized_S2M;
begin

	Reset_Clock_blk : block
	begin
		Osvvm.ClockResetPkg.CreateClock (
			Clk    => Clock,
			Period => to_time(CLOCK_FREQ)
		);

		Osvvm.ClockResetPkg.CreateReset (
			Reset       => Reset,
			ResetActive => '1',
			Clk         => Clock,
			Period      => 200 ns,
			tpd         => 1 ns
		);
	end block;

	Manager_gen : for i in 0 to NUMBER_PORTS - 1 generate
		signal AxiBus : Axi4RecType(
			WriteAddress(
				Addr(AXI_ADDR_WIDTH - 1 downto 0),
				ID(2 downto 0),
				User(0 downto 0)
			),
			WriteData (
				Data(AXI_DATA_WIDTH - 1 downto 0),
				Strb(AXI_STRB_WIDTH - 1 downto 0),
				User(0 downto 0),
				ID(2 downto 0)
			),
			WriteResponse(
				ID(2 downto 0),
				User(0 downto 0)
			),
			ReadAddress (
				Addr(AXI_ADDR_WIDTH - 1 downto 0),
				ID(2 downto 0),
				User(0 downto 0)
			),
			ReadData (
				Data(AXI_DATA_WIDTH - 1 downto 0),
				ID(2 downto 0),
				User(0 downto 0)
			)
			);
	begin
		Manager : Axi4Manager
		generic map(
			MODEL_ID_NAME => "Manager_" & to_string(i),
			tperiod_Clk   => to_time(CLOCK_FREQ),
			DEFAULT_DELAY => 1 ns
		)
		port map
		(
			-- Globals
			Clk    => Clock,
			nReset => not Reset,

			-- AXI Manager Functional Interface
			AxiBus => AxiBus,

			-- Testbench Transaction Interface
			TransRec => AXI4_Manager_Transaction(i)
		);

		to_PoC_AXI4_Bus_Master(In_M2S(i), In_S2M(i), AxiBus);

	end generate;

	TestControl_inst : TestControl
	generic map(
		AXI_ADDR_WIDTH => AXI_ADDR_WIDTH,
		AXI_DATA_WIDTH => AXI_DATA_WIDTH
	)
	port map
	(
		Clock         => Clock,
		Reset         => Reset,

		AXI4_Manager_Transaction      => AXI4_Manager_Transaction,
		AXI4_Subordinate_Transaction  => AXI4_Subordinate_Transaction
	);

	Subordinate_blk : block

		signal AxiBus : Axi4RecType(
			WriteAddress(
				Addr(AXI_ADDR_WIDTH - 1 downto 0),
				ID(3 downto 0),
				User(0 downto 0)
			),
			WriteData (
				Data(AXI_DATA_WIDTH - 1 downto 0),
				Strb(AXI_STRB_WIDTH - 1 downto 0),
				User(0 downto 0),
				ID(3 downto 0)
			),
			WriteResponse(
				ID(3 downto 0),
				User(0 downto 0)
			),
			ReadAddress (
				Addr(AXI_ADDR_WIDTH - 1 downto 0),
				ID(3 downto 0),
				User(0 downto 0)
			),
			ReadData (
				Data(AXI_DATA_WIDTH - 1 downto 0),
				ID(3 downto 0),
				User(0 downto 0)
			)
		);
	begin
		Subordinate : Axi4Subordinate
		generic map(
			tperiod_Clk   => to_time(CLOCK_FREQ),
			DEFAULT_DELAY => 1 ns
		)
		port map
		(
			-- Globals
			Clk      => Clock,
			nReset   => not Reset,
			AxiBus   => AxiBus,
			TransRec => AXI4_Subordinate_Transaction
		);

		to_PoC_AXI4_Bus_Slave(Out_M2S, Out_S2M, AxiBus);
	end block;


	DUT : entity PoC.axi4_Mux
	generic map(
		PIPELINE_IN => (In_M2S'range => 0),
		PIPELINE_OUT => 0,
		NUM_OUTSTANDING_READS  => NUM_TRANSACTIONS,
		NUM_OUTSTANDING_WRITES => NUM_TRANSACTIONS
	)
	port map
	(
		Clock   => Clock,
		Reset   => Reset,
		In_M2S  => In_M2S,
		In_S2M  => In_S2M,
		Out_M2S => Out_M2S,
		Out_S2M => Out_S2M
	);



end architecture;
