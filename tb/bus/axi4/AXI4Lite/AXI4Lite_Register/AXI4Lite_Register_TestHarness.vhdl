-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:
--                  Iqbal Asif (PLC2 Design GmbH)
--                  Patrick Lehmann (PLC2 Design GmbH)
--
-- Entity:          AXI4Lite_Register_TestHarness
--
-- Description:
-- -------------------------------------
-- Testharness of OSVVM Testbench of entity AXI4Lite_Register
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library PoC;
use PoC.vectors.all;
use PoC.axi4lite.all;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library OSVVM_AXI4;
context OSVVM_AXI4.Axi4LiteContext;

entity AXI4Lite_Register_TestHarness is
end AXI4Lite_Register_TestHarness;

architecture sim of AXI4Lite_Register_TestHarness is

	constant tperiod_Clk : time     := 10 ns;
	constant tpd         : time     := 2 ns;
	constant Num_of_Reg  : positive := 8;

	constant AXI_ADDR_WIDTH : integer := 32;
	constant AXI_DATA_WIDTH : integer := 32;
	constant AXI_STRB_WIDTH : integer := AXI_DATA_WIDTH/8;

	function gen_Config return T_AXI4_Register_Vector is
		variable temp : T_AXI4_Register_Vector(0 to 255);
		variable addr : natural := 8;
		variable pos  : natural := 0;
	begin

		for i in 0 to Num_of_Reg - 1 loop
			temp(pos) := to_AXI4_Register(Name => "IRQ(" & integer'image(i) & ")", Address => to_unsigned(addr, 32), RegisterMode => LatchValue_ClearOnRead, IsInterruptRegister => true);
			addr      := addr + 4;
			pos       := pos + 1;
			temp(pos) := to_AXI4_Register(Name => "Read(" & integer'image(i) & ")", Address => to_unsigned(addr, 32), RegisterMode => ReadOnly, Init_Value => x"00000001");
			addr      := addr + 4;
			pos       := pos + 1;
			temp(pos) := to_AXI4_Register(Name => "ReadWrite(" & integer'image(i) & ")", Address => to_unsigned(addr, 32), RegisterMode => ReadWrite);
			addr      := addr + 4;
			pos       := pos + 1;
		end loop;
		return temp(0 to pos - 1);
	end function;

	constant Reg_Config : T_AXI4_Register_Vector := gen_Config;

	signal Reg_ReadPort  : T_SLVV(0 to (Reg_Config'length - 1))(AXI_DATA_WIDTH - 1 downto 0);
	signal Reg_WritePort : T_SLVV(0 to (Reg_Config'length - 1))(AXI_DATA_WIDTH - 1 downto 0) := (others => (others => '0'));

	signal Reg_ReadPort_hit     : std_logic_vector(0 to Reg_Config'Length - 1);
	signal Reg_WritePort_hit    : std_logic_vector(0 to Reg_Config'Length - 1);
	signal Reg_WritePort_strobe : std_logic_vector(0 to Reg_Config'Length - 1) := get_strobeVector(Reg_Config);

	signal Clk            : std_logic;
	signal nReset         : std_logic;
	signal Main_Interrupt : std_logic;

	-- Testbench Transaction Interface
	subtype MasterTransactionRecType is AddressBusTransactionRecType(
		Address((AXI_ADDR_WIDTH) - 1 downto 0),
		DataToModel((AXI_DATA_WIDTH) - 1 downto 0),
		DataFromModel((AXI_DATA_WIDTH) - 1 downto 0)
	);

	signal AxiMasterTransRec : MasterTransactionRecType;

	signal AxiLiteBus : Axi4LiteRecType(
		WriteAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0)),
		WriteData(Data(AXI_DATA_WIDTH - 1 downto 0),
		Strb(AXI_STRB_WIDTH - 1 downto 0)),
		ReadAddress(Addr(AXI_ADDR_WIDTH - 1 downto 0)),
		ReadData(Data(AXI_DATA_WIDTH - 1 downto 0))
	);

	component AXI4Lite_Register_TestController is
		generic (
			CONFIG : T_AXI4_Register_Vector
		);
		port (
			-- Global Signal Interface
			Clk    : in std_logic;
			nReset : in std_logic;

			Irq : in std_logic;

			ReadPort  : in T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0);
			WritePort : out T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0) := (others => (others => '0'));

			-- Transaction Interfaces
			AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType
		);
	end component;

begin

	-- create Clock for TB and 100 Mhz
	Osvvm.ClockResetPkg.CreateClock (
		Clk    => Clk,
		Period => Tperiod_Clk
	);

	-- create nReset
	Osvvm.ClockResetPkg.CreateReset (
		Reset       => nReset,
		ResetActive => '0',
		Clk         => Clk,
		Period      => 7 * tperiod_Clk,
		tpd         => 0 ns
	);

	Master_Config : entity OSVVM_AXI4.Axi4LiteManager
	generic map(
		tperiod_Clk     => tperiod_Clk,
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
		Clk    => Clk,
		nReset => nReset,

		TransRec => AxiMasterTransRec, -- Testbench Transaction Interface
		AxiBus   => AxiLiteBus         -- AXI Master Functional Interface
	);

	DUT : entity PoC.AXI4Lite_Register
	generic map(
		CONFIG                            => Reg_Config,
		INTERRUPT_IS_STROBE               => TRUE,
		INTERRUPT_ENABLE_REGISTER_ADDRESS => 32x"864",
		INTERRUPT_MATCH_REGISTER_ADDRESS  => 32x"868"
	)
	port map
	(
		S_AXI_ACLK    => Clk,
		S_AXI_ARESETN => nReset,

		AXI4Lite_m2s.AWValid => AxiLiteBus.WriteAddress.Valid,
		AXI4Lite_m2s.AWAddr  => AxiLiteBus.WriteAddress.Addr,
		AXI4Lite_m2s.AWCache => (others => '0'),
		AXI4Lite_m2s.AWProt  => AxiLiteBus.WriteAddress.Prot,
		AXI4Lite_m2s.WValid  => AxiLiteBus.WriteData.Valid,
		AXI4Lite_m2s.WData   => AxiLiteBus.WriteData.Data,
		AXI4Lite_m2s.WStrb   => AxiLiteBus.WriteData.Strb,
		AXI4Lite_m2s.BReady  => AxiLiteBus.WriteResponse.Ready,
		AXI4Lite_m2s.ARValid => AxiLiteBus.ReadAddress.Valid,
		AXI4Lite_m2s.ARAddr  => AxiLiteBus.ReadAddress.Addr,
		AXI4Lite_m2s.ARCache => (others => '0'),
		AXI4Lite_m2s.ARProt  => AxiLiteBus.ReadAddress.Prot,
		AXI4Lite_m2s.RReady  => AxiLiteBus.ReadData.Ready,

		AXI4Lite_s2m.WReady  => AxiLiteBus.WriteData.Ready,
		AXI4Lite_s2m.BValid  => AxiLiteBus.WriteResponse.Valid,
		AXI4Lite_s2m.BResp   => AxiLiteBus.WriteResponse.Resp,
		AXI4Lite_s2m.ARReady => AxiLiteBus.ReadAddress.Ready,
		AXI4Lite_s2m.AWReady => AxiLiteBus.WriteAddress.Ready,
		AXI4Lite_s2m.RValid  => AxiLiteBus.ReadData.Valid,
		AXI4Lite_s2m.RData   => AxiLiteBus.ReadData.Data,
		AXI4Lite_s2m.RResp   => AxiLiteBus.ReadData.Resp,

		AXI4Lite_IRQ => Main_Interrupt,

		RegisterFile_ReadPort         => Reg_ReadPort,
		RegisterFile_ReadPort_hit     => Reg_ReadPort_hit,
		RegisterFile_WritePort        => Reg_WritePort,
		RegisterFile_WritePort_hit    => Reg_WritePort_hit,
		RegisterFile_WritePort_strobe => Reg_WritePort_strobe
	);

	TestCtrl : AXI4Lite_Register_TestController
	generic map(
		CONFIG => Reg_Config
	)
	port map
	(
		Clk    => Clk,
		nReset => nReset,

		Irq => Main_Interrupt,

		ReadPort  => Reg_ReadPort,
		WritePort => Reg_WritePort,

		AxiMasterTransRec => AxiMasterTransRec
	);

end architecture;
