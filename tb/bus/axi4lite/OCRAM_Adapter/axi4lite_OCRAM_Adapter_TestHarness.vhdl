-- =============================================================================
-- Authors:
--   Iqbal Asif (PLC2 Design GmbH)
--   Patrick Lehmann (PLC2 Design GmbH)
--   Adrian Weiland (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

-- TODO: Create testcase with r/w outside defined address space and check for according error (see https://gitlab.plc2.de/GitHub/PLC2/PoC/-/work_items/59)
library IEEE;
use     IEEE.std_logic_1164.ALL;
use     IEEE.numeric_std.ALL;

library PoC;
use     PoC.my_project.all;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.axi4lite.all;
use     PoC.axi4lite_OSVVM.all;

library osvvm;
context osvvm.OsvvmContext ;

library OSVVM_AXI4;
context OSVVM_AXI4.Axi4LiteContext ;

entity axi4lite_OCRAM_Adapter_TestHarness is
	generic (
		constant USE_INIT_FILE : boolean  := False;
		constant AXI_DATA_BITS : positive := 32
	);
end entity;

architecture sim of axi4lite_OCRAM_Adapter_TestHarness is

	constant AXI_ADDR_WIDTH        : integer := 32 ;
	constant AXI_DATA_WIDTH        : integer := AXI_DATA_BITS ;
	constant AXI_STRB_WIDTH        : integer := AXI_DATA_WIDTH/8 ;
	constant OCRAM_ADDRESS_BITS    : positive := 8;
	constant OCRAM_DATA_BITS       : positive := 32;
	constant PREFFERED_READ_ACCESS : boolean := TRUE;

	constant tperiod_Clock     : time := 10 ns ;
	constant tperiod_Clock_SPI : time := 100 ns ;
	constant tpd               : time := 2 ns ;

	signal Clock     : std_logic := '1';
	signal Reset     : std_logic := '1';

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
		WriteData   ( Data (AXI_DATA_WIDTH-1 downto 0), Strb(AXI_STRB_WIDTH-1 downto 0) ),
		ReadAddress ( Addr(AXI_ADDR_WIDTH-1 downto 0) ),
		ReadData    ( Data (AXI_DATA_WIDTH-1 downto 0) )
	) ;

	signal AXI_m2s : T_AXI4Lite_BUS_M2S(
		AWAddr(AXI_ADDR_WIDTH - 1 downto 0),
		WData(AXI_DATA_WIDTH - 1 downto 0),
		WStrb(AXI_STRB_WIDTH-1 downto 0),
		ARAddr(AXI_ADDR_WIDTH - 1 downto 0)
	);
	signal AXI_s2m : T_AXI4Lite_BUS_S2M(
		RData(AXI_DATA_WIDTH - 1 downto 0)
	);

	component axi4lite_OCRAM_Adapter_TestController is
		generic (
			constant OCRAM_ADDRESS_BITS : positive := 8;
			constant OCRAM_DATA_BITS    : positive := 32
		);
		port (
			-- Global Signal Interface
			Clock      : in  std_logic ;
			Reset      : in  std_logic ;

			MasterRec : inout AddressBusRecType
		);
	end component;

begin

	assert AXI_DATA_BITS = 32 or AXI_DATA_BITS = 64 report "Invalid number of AXI_DATA_BITS (" & to_string(AXI_DATA_BITS) & "), expected: 32 or 64" severity failure;

	-- create Clock for TB and 100 Mhz
	Osvvm.ClockResetPkg.CreateClock (
		Clk    => Clock,
		Period => Tperiod_Clock
	)  ;

	-- create nReset
	Osvvm.ClockResetPkg.CreateReset (
		Reset       => Reset,
		ResetActive => '1',
		Clk         => Clock,
		Period      => 7 * tperiod_Clock,
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
			Clk      => Clock,
			nReset   => not Reset,

			TransRec => AxiMasterTransRec, -- Testbench Transaction Interface
			AxiBus   => AxiBus         -- AXI Master Functional Interface
		) ;
	to_PoC_AXI4Lite_Bus_Master(AXI_m2s, AXI_s2m, AxiBus);

	---------------------------------------------------------------------------
	-- axi4_slave_rb_interface
	---------------------------------------------------------------------------
	axi4lite_OCRAM_Adapter : entity PoC.axi4lite_OCRAM_Adapter
	generic map (
		OCRAM_ADDRESS_BITS    => OCRAM_ADDRESS_BITS,
		OCRAM_DATA_BITS       => OCRAM_DATA_BITS,
		PREFFERED_READ_ACCESS => PREFFERED_READ_ACCESS
	)
		port map (
			-- AXI4lite slave interface
			Clock                => Clock,
			Reset                => Reset,

			AXI4Lite_m2s         =>  AXI_m2s,
			AXI4Lite_s2m         =>  AXI_s2m,

			OCRAM_Address        => address,
			OCRAM_WriteEnable    => write_en,
			OCRAM_ByteEnable     => open,
			OCRAM_DataIn         => data_in,
			OCRAM_DataOut        => data_out
		) ;

	OCRAM : entity PoC.ocram_TrueDualPort
		generic map (
			ADDRESS_BITS   => OCRAM_ADDRESS_BITS,
			DATA_BITS   => OCRAM_DATA_BITS,
			FILENAME => ite(USE_INIT_FILE, MY_PROJECT_DIR & "/tb/bus/axi4lite/OCRAM_Adapter/axi4lite_OCRAM_Adapter.hex", "")
		)
		port map (
			PortA_Clock => Clock,
			PortB_Clock => Clock,
			PortA_ClockEnable  => '1',
			PortB_ClockEnable  => '1',
			PortA_WriteEnable  => write_en,
			PortB_WriteEnable  => '0',
			PortA_Address   => address,
			PortB_Address   => PortB_address,
			PortA_DataIn   => data_out,
			PortB_DataIn   => (others => '0'),
			PortA_DataOut   => data_in,
			PortB_DataOut   => PortB_data
		);

	TestCtrl : axi4lite_OCRAM_Adapter_TestController
		generic map (
			OCRAM_ADDRESS_BITS => OCRAM_ADDRESS_BITS,
			OCRAM_DATA_BITS    => OCRAM_DATA_BITS
		)
		port map(
			Clock    => Clock,
			Reset    => Reset,

			MasterRec => AxiMasterTransRec
		);

end architecture;
