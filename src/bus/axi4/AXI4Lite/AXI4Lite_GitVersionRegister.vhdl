-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	A generic AXI4-Lite version register for Git.
--
-- Description:
-- -------------------------------------
-- This version register can be auto filled with constants from Git. Software
-- can read from what revision a firmware (bitstream, PL code) was build.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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

use     work.utils.all;
use     work.vectors.all;
use     work.strings.all;
use     work.axi4lite.all;

use     work.GitVersionRegister.all;
use     work.BuildVersion.all;


entity AXI4Lite_GitVersionRegister is
	Port (
		S_AXI_ACLK    : in  std_logic;
		S_AXI_ARESETN : in  std_logic;
		
		S_AXI_m2s     : in  T_AXI4Lite_BUS_M2S;
		S_AXI_s2m     : out T_AXI4Lite_BUS_S2M
	);
end entity;


architecture rtl of AXI4Lite_GitVersionRegister is
	constant DATA_BITS            : natural          := 32;
	
	constant num_Version_register : natural          := get_num_Version_register;
  
  constant CONFIG      : T_AXI4_Register_Description_Vector(0 to num_Version_register -1) := get_Dummy_Descriptor(num_Version_register);
	
	constant VersionData : T_SLVV_32(0 to num_Version_register -1) := (
			0                 to Reg_Length_Common -1                  => to_SLVV_32_Common(C_HW_BUILD_VERSION_COMMON),
			Reg_Length_Common to Reg_Length_Common + Reg_Length_Top -1 => to_SLVV_32_Top(C_HW_BUILD_VERSION_TOP)
		);
		
	function to_slvv(data : T_SLVV_32) return T_SLVV is
		variable temp : T_SLVV(VersionData'range)(DATA_BITS -1 downto 0) := (others => (others => '0'));
	begin
		for i in VersionData'range loop
			temp(i) := data(i);
		end loop;
		return temp;
	end function;

  constant RegisterFile_WritePort  : T_SLVV(0 to CONFIG'Length -1)(DATA_BITS -1 downto 0) := to_slvv(VersionData);
  
begin
  AXI4LiteReg : entity work.AXI4Lite_Register
	generic map(
	 	CONFIG        => CONFIG
	)
	port map(
		S_AXI_ACLK              => S_AXI_ACLK,
		S_AXI_ARESETN           => S_AXI_ARESETN,
		
		S_AXI_m2s               => S_AXI_m2s,
		S_AXI_s2m               => S_AXI_s2m,
		
		RegisterFile_ReadPort   => open,
		RegisterFile_WritePort  => RegisterFile_WritePort
	);
end architecture;
