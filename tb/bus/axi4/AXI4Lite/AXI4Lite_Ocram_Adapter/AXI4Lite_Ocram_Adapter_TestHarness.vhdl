-- =============================================================================
-- Authors:
--   Iqbal Asif (PLC2 Design GmbH)
--   Patrick Lehmann (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;

library PoC;
use     PoC.utils.all;
use     PoC.axi4.all;
use     PoC.vectors.all;

library osvvm;
context osvvm.OsvvmContext ;

library OSVVM_AXI4;
--context OSVVM_AXI4.Axi4Context ;
context OSVVM_AXI4.Axi4LiteContext ;

entity AXI4Lite_Ocram_Adapter_TestHarness is
end AXI4Lite_Ocram_Adapter_TestHarness;

architecture sim of AXI4Lite_Ocram_Adapter_TestHarness is

	constant AXI_ADDR_WIDTH : integer := 32 ;
	constant AXI_DATA_WIDTH : integer := 32 ;
	constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH/8 ;
	constant OCRAM_ADDRESS_BITS    : positive := 8;
	constant OCRAM_DATA_BITS       : positive := 32;
	constant PREFFERED_READ_ACCESS : boolean := TRUE;

	constant tperiod_Clk     : time := 10 ns ;
	constant tperiod_Clk_SPI : time := 100 ns ;
	constant tpd             : time := 2 ns ;

	signal Clk     : std_logic := '1';
	signal Reset   : std_logic := '1';

	signal write_en : std_logic;
	signal address  : unsigned(OCRAM_ADDRESS_BITS-1 downto 0);
	signal data_in  : std_logic_vector(OCRAM_DATA_BITS-1 downto 0) := (others => '0');
	signal data_out : std_logic_vector(OCRAM_DATA_BITS-1 downto 0);

	signal PortB_address : unsigned(OCRAM_ADDRESS_BITS-1 downto 0);
	signal PortB_data    : std_logic_vector(OCRAM_DATA_BITS-1 downto 0) := (others => '0');

	-- Testbench Transaction Interface
	subtype MasterTransactionRecType is AddressBusTransactionRecType(
		Address((AXI_ADDR_WIDTH)-1 downto 0),
		DataToModel((AXI_DATA_WIDTH)-1 downto 0),
		DataFromModel((AXI_DATA_WIDTH)-1 downto 0)
	) ;

	signal  AxiMasterTransRec :   MasterTransactionRecType  ;

--  AXI Master Functional Interface
  signal   AxiBus : Axi4LiteRecType(
    WriteAddress( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
    WriteData   ( Data (AXI_DATA_WIDTH-1 downto 0),   Strb(AXI_STRB_WIDTH-1 downto 0) ),
    ReadAddress ( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
    ReadData    ( Data (AXI_DATA_WIDTH-1 downto 0) )
  ) ;

	component AXI4Lite_Ocram_Adapter_TestController is
		port (
			-- Global Signal Interface
			Clk        : in std_logic ;
			nReset     : in std_logic ;

			MasterRec : inout AddressBusRecType
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
		Reset       => Reset,
		ResetActive => '1',
		Clk         => Clk,
		Period      => 7 * tperiod_Clk,
		tpd         => tpd
	) ;

	AXI4_Config : entity OSVVM_AXI4.Axi4LiteManager
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
			nReset   => not Reset,

			TransRec => AxiMasterTransRec, -- Testbench Transaction Interface
			AxiBus   => AxiBus         -- AXI Master Functional Interface
		) ;

	---------------------------------------------------------------------------
	-- axi4_slave_rb_interface
	---------------------------------------------------------------------------
	AXI4Lite_Ocram_Adaptar : entity PoC.AXI4Lite_Ocram_Adapter
	generic map (
		OCRAM_ADDRESS_BITS    => OCRAM_ADDRESS_BITS,
		OCRAM_DATA_BITS       => OCRAM_DATA_BITS,
		PREFFERED_READ_ACCESS => PREFFERED_READ_ACCESS
	)
		port map (
			-- AXI4lite slave interface
			Clock                => Clk,
			Reset                => Reset,

			AXI4Lite_m2s.AWValid =>	AxiBus.WriteAddress.Valid,
			AXI4Lite_m2s.AWAddr  =>	AxiBus.WriteAddress.Addr,
			AXI4Lite_m2s.AWCache =>	(others => '0'),
			AXI4Lite_m2s.AWProt  =>	AxiBus.WriteAddress.Prot,
			AXI4Lite_m2s.WValid  =>	AxiBus.WriteData.Valid,
			AXI4Lite_m2s.WData   =>	AxiBus.WriteData.Data,
			AXI4Lite_m2s.WStrb   =>	AxiBus.WriteData.Strb,
			AXI4Lite_m2s.BReady  =>	AxiBus.WriteResponse.Ready,
			AXI4Lite_m2s.ARValid =>	AxiBus.ReadAddress.Valid,
			AXI4Lite_m2s.ARAddr  =>	AxiBus.ReadAddress.Addr,
			AXI4Lite_m2s.ARCache =>	(others => '0'),
			AXI4Lite_m2s.ARProt  =>	AxiBus.ReadAddress.Prot,
			AXI4Lite_m2s.RReady  =>	AxiBus.ReadData.Ready,

			AXI4Lite_s2m.WReady  =>	AxiBus.WriteData.Ready,
			AXI4Lite_s2m.BValid  =>	AxiBus.WriteResponse.Valid,
			AXI4Lite_s2m.BResp   =>	AxiBus.WriteResponse.Resp,
			AXI4Lite_s2m.ARReady =>	AxiBus.ReadAddress.Ready,
			AXI4Lite_s2m.AWReady =>	AxiBus.WriteAddress.Ready,
			AXI4Lite_s2m.RValid  =>	AxiBus.ReadData.Valid,
			AXI4Lite_s2m.RData   =>	AxiBus.ReadData.Data,
			AXI4Lite_s2m.RResp   =>	AxiBus.ReadData.Resp,

			Write_En             => write_en,
			Address              => address,
			Data_In              => data_in,
			Data_Out             => data_out
		) ;

	ocram : entity PoC.ocram_tdp
    generic map (
      A_BITS   => OCRAM_ADDRESS_BITS,
      D_BITS   => OCRAM_DATA_BITS
    )
    port map (
      clk1 => Clk,
      clk2 => Clk,
      ce1  => '1',
      ce2  => '1',
      we1  => write_en,
      we2  => '0',
      a1   => address,
      a2   => PortB_address,
      d1   => data_out,
      d2   => (others => '0'),
      q1   => data_in,
      q2   => PortB_data
    ) ;

	TestCtrl : AXI4Lite_Ocram_Adapter_TestController
		port map(
			Clk    => Clk,
			nReset => not Reset,

			MasterRec => AxiMasterTransRec
		);

end architecture;
