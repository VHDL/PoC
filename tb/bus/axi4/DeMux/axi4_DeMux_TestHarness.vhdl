-- =============================================================================
-- Authors:
--  Iqbal Asif (PLC2 Design GmbH)
--  Patrick Lehmann (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
use     PoC.vectors.all;
use     PoC.AXI4_Full.all;
use     PoC.axi4_OSVVM.all;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_axi4;
context osvvm_axi4.AXI4Context;

entity axi4_DeMux_TestHarness is
	generic(
		NUM_TRANSACTIONS : natural := 0
	);
end axi4_DeMux_TestHarness;

architecture Harness of axi4_DeMux_TestHarness is
	constant DEMUX_CHANNELS : positive := 5;

	constant AXI_ADDR_WIDTH : integer := 32;
	constant AXI_DATA_WIDTH : integer := 32;
	constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH/8;
	constant AXI_ID_WIDTH   : integer := 4;

	constant tperiod_Clk : time := 10 ns;
	constant tpd         : time := 2 ns;

	constant BASE_ADDRESS      : T_SLUV(0 to DEMUX_CHANNELS -1)    := (0 =>                      32x"10000", 1 => 32x"20000", 2 => 32x"30000", 3 => 32x"40000", 4 => 32x"50000");
	constant BASE_ADDRESS_MASK : T_SLUV(0 to DEMUX_CHANNELS -1)    := (0 to DEMUX_CHANNELS -1 => 32x"0FFFF");
	constant PIPELINE_OUT      : natural_vector(BASE_ADDRESS'range) := (others => 0);

	signal Clock : std_logic := '0';
	signal Reset : std_logic := '1';

	-- Testbench Transaction Interface
	subtype ManagerRec is AddressBusRecType(
		Address((AXI_ADDR_WIDTH) - 1 downto 0),
		DataToModel((AXI_DATA_WIDTH) - 1 downto 0),
		DataFromModel((AXI_DATA_WIDTH) - 1 downto 0)
	);

	signal AxiManagerTransRec : ManagerRec;

	signal SubordinateRec : AddressBusRecArrayType(DEMUX_CHANNELS - 1 downto 0)(
		Address(AXI_ADDR_WIDTH - 1 downto 0),
		DataToModel(AXI_DATA_WIDTH - 1 downto 0),
		DataFromModel(AXI_DATA_WIDTH - 1 downto 0)
	);

	-- AXI Master Functional Interface
	signal AxiBus : AXI4RecType(
		WriteAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0), ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0)),
		WriteData(Data(AXI_DATA_WIDTH - 1 downto 0), Strb(AXI_STRB_WIDTH - 1 downto 0), ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0)),
		ReadAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0), ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0)),
		ReadData(Data(AXI_DATA_WIDTH - 1 downto 0), ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0)),
		WriteResponse(ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0))
	);

	signal Out_M2S : T_AXI4_Bus_M2S_VECTOR(DEMUX_CHANNELS - 1 downto 0)(
		AWAddr(AXI_ADDR_WIDTH - 1 downto 0), WData(AXI_DATA_WIDTH - 1 downto 0),
		WStrb((AXI_DATA_WIDTH /8) - 1 downto 0), ARAddr(AXI_ADDR_WIDTH - 1 downto 0),
		AWID(AXI_ID_WIDTH -1 downto 0), ARID(AXI_ID_WIDTH -1 downto 0), AWUser(0 downto 0),
		WUser(0 downto 0), ARUser(0 downto 0)
		);
	signal Out_S2M : T_AXI4_Bus_S2M_VECTOR(DEMUX_CHANNELS - 1 downto 0)(
		RData(AXI_DATA_WIDTH - 1 downto 0), BID(AXI_ID_WIDTH -1 downto 0), BUser(0 downto 0), RID(AXI_ID_WIDTH -1 downto 0), RUser(0 downto 0)
		);

	signal In_M2S : Out_M2S'element;
	signal In_S2M : Out_S2M'element;

	component axi4_DeMux_TestController is
		port (
			-- Global Signal Interface
			Clock : in  std_logic;
			Reset : in  std_logic;
			-- Transaction Interfaces
			ManagerRec     : inout AddressBusRecType;
			SubordinateRec : inout AddressBusRecArrayType
		);
	end component;

begin

	-- create Clock for TB and 100 Mhz
	Osvvm.ClockResetPkg.CreateClock (
		Clk    => Clock,
		Period => Tperiod_Clk
	);

	-- create nReset
	Osvvm.ClockResetPkg.CreateReset (
		Reset       => Reset,
		ResetActive => '1',
		Clk         => Clock,
		Period      => 7 * tperiod_Clk,
		tpd         => tpd
	);

	------------------------------------------------
	-- osvvm axi4 manager interface
	------------------------------------------------
	AXI4_Config : entity OSVVM_AXI4.AXI4Manager
	generic map(
		tperiod_Clk     => 5 ns,
		tpd_Clk_AWValid => 0 ns,
		tpd_Clk_AWProt  => 0 ns,
		tpd_Clk_AWAddr  => 0 ns,
		tpd_Clk_WValid  => 0 ns,
		tpd_Clk_WData   => 0 ns,
		tpd_Clk_WStrb   => 0 ns,
		tpd_Clk_BReady  => 0 ns,
		tpd_Clk_ARValid => 0 ns,
		tpd_Clk_ARProt  => 0 ns,
		tpd_Clk_ARAddr  => 0 ns,
		tpd_Clk_RReady  => 0 ns
	)
	port map
	(
		Clk    => Clock,
		nReset => not Reset,

		TransRec => AxiManagerTransRec, -- Testbench Transaction Interface
		AxiBus   => AxiBus              -- AXI Master Functional Interface
	);

	to_PoC_AXI4_Bus_Master(In_M2S, In_S2M, AxiBus);

	---------------------------------------------------------
	-- osvvm axi4 subordinate interface
	---------------------------------------------------------
	genSubordinate : for i in 0 to DEMUX_CHANNELS - 1 generate
		signal AxiBus : AXI4RecType(
			WriteAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0), ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0)),
			WriteData(Data(AXI_DATA_WIDTH - 1 downto 0), Strb(AXI_STRB_WIDTH - 1 downto 0), ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0)),
			ReadAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0), ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0)),
			ReadData(Data(AXI_DATA_WIDTH - 1 downto 0), ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0)),
			WriteResponse(ID(AXI_ID_WIDTH -1 downto 0), User(0 downto 0))
		);
	begin
		Subordinate : entity OSVVM_AXI4.AXI4Subordinate
		generic map(
			tperiod_Clk   => 5 ns,
			DEFAULT_DELAY => 0 ns
		)
		port map
		(
			Clk    => Clock,
			nReset => not Reset,

			AxiBus   => AxiBus,
			TransRec => SubordinateRec(i)
		);

		to_PoC_AXI4_Bus_Slave(Out_M2S(i), Out_S2M(i), AxiBus);
	end generate;

	TestCtrl : axi4_DeMux_TestController
	port map
	(
		Clock    => Clock,
		Reset => Reset,

		ManagerRec     => AxiManagerTransRec,
		SubordinateRec => SubordinateRec
	);


	DUT : entity PoC.axi4_DeMux
	generic map(
		BASE_ADDRESS      => BASE_ADDRESS,
		BASE_ADDRESS_MASK => BASE_ADDRESS_MASK,
		-- PIPELINE_OUT      => PIPELINE_OUT
		NUM_OUTSTANDING_READS  => NUM_TRANSACTIONS,
		NUM_OUTSTANDING_WRITES => NUM_TRANSACTIONS
	)
	port map
	(
		-- AXI4 slave interface
		Clock => Clock,
		Reset => Reset,

		In_M2S => In_M2S,
		In_S2M => In_S2M,

		Out_M2S => Out_M2S,
		Out_S2M => Out_S2M
	);

end architecture;
