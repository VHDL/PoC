-- =============================================================================
-- Authors:
--  Iqbal Asif (PLC2 Design GmbH)
--  Patrick Lehmann (PLC2 Design GmbH)
--  Stefan Unrein (PLC2 Design GmbH)
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
use     IEEE.std_logic_1164.ALL;
use     IEEE.numeric_std.ALL;

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.axi4lite.all;
use     PoC.axi4lite_OSVVM.all;

library osvvm;
context osvvm.OsvvmContext ;

library OSVVM_AXI4;
context OSVVM_AXI4.Axi4LiteContext ;

entity axi4lite_Demux_TestHarness is
end axi4lite_Demux_TestHarness;

architecture sim of axi4lite_Demux_TestHarness is
	constant DEMUX_CHANNELS : positive := 2;

	constant AXI_ADDR_WIDTH : integer := 32;
	constant AXI_DATA_WIDTH : integer := 64;
	constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH/8 ;

	constant tperiod_Clk : time := 10 ns ;
	constant tpd         : time := 2 ns ;

	constant BASE_ADDRESS      : T_SLUV(0 to 1) := (0 => 32x"0000", 1 => 32x"4000");
	constant BASE_ADDRESS_MASK : T_SLUV(0 to 1) := (0 to 1 => 32x"03FFF");
	constant PIPELINE_OUT      : natural_vector(BASE_ADDRESS'range) := (others => 0);

	signal Clk    : std_logic := '0';
	signal nReset : std_logic := '1';

	-- Testbench Transaction Interface
	subtype ManagerRec is AddressBusTransactionRecType(
		Address((AXI_ADDR_WIDTH)-1 downto 0),
		DataToModel((AXI_DATA_WIDTH)-1 downto 0),
		DataFromModel((AXI_DATA_WIDTH)-1 downto 0)
		) ;

	signal  AxiManagerTransRec : ManagerRec  ;

	signal SubordinateRec : AddressBusRecArrayType(0 to DEMUX_CHANNELS -1)(
				Address(AXI_ADDR_WIDTH-1 downto 0),
				DataToModel(AXI_DATA_WIDTH-1 downto 0),
				DataFromModel(AXI_DATA_WIDTH-1 downto 0)
				);

	-- AXI Master Functional Interface
	signal In_AxiBus : Axi4LiteRecType(
		WriteAddress( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
		WriteData   ( Data (AXI_DATA_WIDTH-1 downto 0),   Strb(AXI_STRB_WIDTH-1 downto 0) ),
		ReadAddress ( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
		ReadData    ( Data (AXI_DATA_WIDTH-1 downto 0) )
	);

	signal Out_AXI4Lite_M2S : T_AXI4Lite_Bus_M2S_VECTOR(0 to DEMUX_CHANNELS -1)(
			AWAddr(AXI_ADDR_WIDTH -1 downto 0), WData(AXI_DATA_WIDTH -1 downto 0),
			WStrb((AXI_DATA_WIDTH /8) -1 downto 0), ARAddr(AXI_ADDR_WIDTH -1 downto 0));
	signal Out_AXI4Lite_S2M : T_AXI4Lite_Bus_S2M_VECTOR(0 to DEMUX_CHANNELS -1)(RData(AXI_DATA_WIDTH -1 downto 0));

	signal In_AXI4Lite_M2S : Out_AXI4Lite_M2S'element;
	signal In_AXI4Lite_S2M : Out_AXI4Lite_S2M'element;

	component axi4lite_Demux_TestController is
		port (
			-- Global Signal Interface
			Clk    : in  std_logic ;
			nReset : in  std_logic ;
			-- Transaction Interfaces
			ManagerRec     : inout AddressBusRecType;
			SubordinateRec : inout AddressBusRecArrayType
		) ;
	end component;

begin

	-- create Clock for TB and 100 Mhz
	Osvvm.ClockResetPkg.CreateClock (
		Clk    => Clk,
		Period => Tperiod_Clk
	)  ;

	-- create nReset
	Osvvm.ClockResetPkg.CreateReset (
		Reset       => nReset,
		ResetActive => '0',
		Clk         => Clk,
		Period      => 7 * tperiod_Clk,
		tpd         => tpd
	) ;

	------------------------------------------------
	-- osvvm axi4 manager interface
	------------------------------------------------
	AXI4_Config : entity OSVVM_AXI4.axi4liteManager
	generic map (
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
	port map (
		Clk      => Clk,
		nReset   => nReset,

		TransRec => AxiManagerTransRec, -- Testbench Transaction Interface
		AxiBus   => In_AxiBus           -- AXI Master Functional Interface
	);
	to_PoC_AXI4Lite_Bus_Master(In_AXI4Lite_M2S, In_AXI4Lite_S2M, In_AxiBus);


	---------------------------------------------------------
	-- osvvm axi4 subordinate interface
	---------------------------------------------------------
	genSubordinate: for i in 0 to DEMUX_CHANNELS - 1 generate

		signal Out_AxiBus : Axi4LiteRecType(
			WriteAddress( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
			WriteData   ( Data (AXI_DATA_WIDTH-1 downto 0),   Strb(AXI_STRB_WIDTH-1 downto 0) ),
			ReadAddress ( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
			ReadData    ( Data (AXI_DATA_WIDTH-1 downto 0) )
			);
	begin
		Subordinate : entity OSVVM_AXI4.Axi4LiteSubordinate
		generic map (
			tperiod_Clk   => 5 ns,
			DEFAULT_DELAY => 0 ns
		)
		port map (
			Clk    => Clk,
			nReset => nReset,

			AxiBus   => Out_AxiBus,
			TransRec => SubordinateRec(i)
		) ;
		to_PoC_AXI4Lite_Bus_Slave(Out_AXI4Lite_M2S(i), Out_AXI4Lite_S2M(i), Out_AxiBus);
	end generate;

	TestCtrl : axi4lite_Demux_TestController
		port map(
			Clk    => Clk,
			nReset => nReset,

			ManagerRec     => AxiManagerTransRec,
			SubordinateRec => SubordinateRec
		);

	---------------------------------------------------------
	-- axi4 demux interface
	---------------------------------------------------------
	axi4lite_Demux_Int_DUT : entity PoC.axi4lite_DeMux
	generic map (
		BASE_ADDRESS      => BASE_ADDRESS,
		BASE_ADDRESS_MASK => BASE_ADDRESS_MASK,
		PIPELINE_OUT      => PIPELINE_OUT
	)
	port map (
		-- AXI4lite slave interface
		Clock => Clk,
		Reset => not nReset,

		In_M2S => In_AXI4Lite_M2S,
		In_S2M => In_AXI4Lite_S2M,

		Out_M2S => Out_AXI4Lite_M2S,
		Out_S2M => Out_AXI4Lite_S2M
	);

end architecture;
