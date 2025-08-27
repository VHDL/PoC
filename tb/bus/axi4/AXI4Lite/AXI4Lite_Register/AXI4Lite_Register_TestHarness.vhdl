-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:
--                  Iqbal Asif (PLC2 Design GmbH)
--                  Patrick Lehmann (PLC2 Design GmbH)
--                  Adrian Weiland (PLC2 Design GmbH)
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
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;

library PoC;
use     PoC.vectors.all;
use     PoC.axi4lite.all;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library OSVVM_AXI4;
context OSVVM_AXI4.Axi4LiteContext;

use     work.AXI4Lite_Register_pkg.all;


entity AXI4Lite_Register_TestHarness is
end    AXI4Lite_Register_TestHarness;

architecture sim of AXI4Lite_Register_TestHarness is

	constant tperiod_Clk : time     := 10 ns;

	signal Clock          : std_logic;
	signal Reset          : std_logic;
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
			Clock : in    std_logic;
			Reset : out   std_logic;

			Irq   : in    std_logic;

			ReadPort  : in   T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0);
			WritePort : out  T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0):= (others => (others => '0'));

			-- Transaction Interfaces
			AxiMasterTransRec         : inout Axi4LiteMasterTransactionRecType
			);
	end component;

	function gen_Config return T_AXI4_Register_Vector is
		variable config : T_AXI4_Register_Vector(0 to 16);
		variable addr   : natural := 0;
		variable pos    : natural := 0;
	begin
		config(pos) := to_AXI4_Register(Name => "Reg1", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => ConstantValue, Init_Value => 32x"12");
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "Reg2", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => ReadOnly);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "Reg3", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => ReadWrite,     Init_Value => 32x"FF");
		pos := pos + 1; addr := addr + 4;
		addr := addr + 4;  -- reserved
		config(pos) := to_AXI4_Register(Name => "Reg4_L", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => ReadWrite,   Init_Value => 32x"2");
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "Reg4_H", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => ReadWrite,   Init_Value => 32x"A");
		pos := pos + 1; addr := addr + 4;
		addr := addr + 4;  -- reserved
		addr := addr + 4;  -- reserved
		config(pos) := to_AXI4_Register(Name => "IRQ_L_lhcor", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchHighBit_ClearOnRead,  IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_H_lhcor", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchHighBit_ClearOnRead,  IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_L_llcor", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchLowBit_ClearOnRead,   IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_H_llcor", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchLowBit_ClearOnRead,   IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_L_lhcow", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchHighBit_ClearOnWrite, IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_H_lhcow", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchHighBit_ClearOnWrite, IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_L_llcow", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchLowBit_ClearOnWrite,  IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_H_llcow", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchLowBit_ClearOnWrite,  IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_L_lvcor", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchValue_ClearOnRead,    IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_H_lvcor", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchValue_ClearOnRead,    IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_L_lvcow", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchValue_ClearOnWrite,   IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;
		config(pos) := to_AXI4_Register(Name => "IRQ_H_lvcow", Address => to_unsigned(addr, REG_ADDRESS_BITS), RegisterMode => LatchValue_ClearOnWrite,   IsInterruptRegister => true);
		pos := pos + 1; addr := addr + 4;

		return config(0 to pos - 1);
	end function;

	constant CONFIG : T_AXI4_Register_Vector := gen_Config;

	signal Reg_ReadPort    : T_SLVV(0 to (CONFIG'length - 1))(AXI_DATA_WIDTH -1 downto 0);
	signal Reg_WritePort   : T_SLVV(0 to (CONFIG'length - 1))(AXI_DATA_WIDTH -1 downto 0) := (others => (others => '0'));

	signal Reg_ReadPort_hit     : std_logic_vector(0 to CONFIG'Length - 1);
	signal Reg_WritePort_hit    : std_logic_vector(0 to CONFIG'Length - 1);
	signal Reg_WritePort_strobe : std_logic_vector(0 to CONFIG'Length - 1) := get_strobeVector(CONFIG);

begin

	-- create Clock for TB and 100 Mhz
	Osvvm.ClockResetPkg.CreateClock (
		Clk        => Clock,
		Period     => Tperiod_Clk
	);

	Master_Config : entity OSVVM_AXI4.Axi4LiteManager
	generic map (
		tperiod_Clk     => tperiod_Clk,
		DEFAULT_DELAY   => 0 ns
	)
	port map (
		Clk         => Clock,
		nReset      => not Reset,

		TransRec    => AxiMasterTransRec, -- Testbench Transaction Interface
		AxiBus      => AxiLiteBus -- AXI Master Functional Interface
	);

	DUT : entity PoC.AXI4Lite_Register
	generic map (
		CONFIG                             => CONFIG,
		-- VERBOSE                            => False,
		INTERRUPT_IS_STROBE                => TRUE,
		INTERRUPT_ENABLE_REGISTER_ADDRESS  => 32x"864",
		INTERRUPT_MATCH_REGISTER_ADDRESS   => 32x"868"
	)
	port map (
		Clock          => Clock,
		Reset          => Reset,

		AXI4Lite_m2s.AWValid   => AxiLiteBus.WriteAddress.Valid,
		AXI4Lite_m2s.AWAddr    => AxiLiteBus.WriteAddress.Addr,
		AXI4Lite_m2s.AWCache   => (others => '0'),
		AXI4Lite_m2s.AWProt    => AxiLiteBus.WriteAddress.Prot,
		AXI4Lite_m2s.WValid    => AxiLiteBus.WriteData.Valid,
		AXI4Lite_m2s.WData     => AxiLiteBus.WriteData.Data,
		AXI4Lite_m2s.WStrb     => AxiLiteBus.WriteData.Strb,
		AXI4Lite_m2s.BReady    => AxiLiteBus.WriteResponse.Ready,
		AXI4Lite_m2s.ARValid   => AxiLiteBus.ReadAddress.Valid,
		AXI4Lite_m2s.ARAddr    => AxiLiteBus.ReadAddress.Addr,
		AXI4Lite_m2s.ARCache   => (others => '0'),
		AXI4Lite_m2s.ARProt    => AxiLiteBus.ReadAddress.Prot,
		AXI4Lite_m2s.RReady    => AxiLiteBus.ReadData.Ready,

		AXI4Lite_s2m.WReady    => AxiLiteBus.WriteData.Ready,
		AXI4Lite_s2m.BValid    => AxiLiteBus.WriteResponse.Valid,
		AXI4Lite_s2m.BResp     => AxiLiteBus.WriteResponse.Resp,
		AXI4Lite_s2m.ARReady   => AxiLiteBus.ReadAddress.Ready,
		AXI4Lite_s2m.AWReady   => AxiLiteBus.WriteAddress.Ready,
		AXI4Lite_s2m.RValid    => AxiLiteBus.ReadData.Valid,
		AXI4Lite_s2m.RData     => AxiLiteBus.ReadData.Data,
		AXI4Lite_s2m.RResp     => AxiLiteBus.ReadData.Resp,

		AXI4Lite_IRQ           => Main_Interrupt,

		RegisterFile_ReadPort         => Reg_ReadPort,
		RegisterFile_ReadPort_hit     => Reg_ReadPort_hit,
		RegisterFile_WritePort        => Reg_WritePort,
		RegisterFile_WritePort_hit    => Reg_WritePort_hit,
		RegisterFile_WritePort_strobe => Reg_WritePort_strobe
	);

	TestCtrl : AXI4Lite_Register_TestController
	generic map (
		CONFIG => CONFIG
	)
	port map(
		Clock     => Clock,
		Reset     => Reset,

		Irq       => Main_Interrupt,

		ReadPort  => Reg_ReadPort,
		WritePort => Reg_WritePort,

		AxiMasterTransRec => AxiMasterTransRec
	);

end architecture;
