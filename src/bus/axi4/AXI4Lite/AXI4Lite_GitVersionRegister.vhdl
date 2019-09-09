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

use     work.my_project.MY_PROJECT_DIR;
use     work.utils.all;
use     work.vectors.all;
use     work.strings.all;
use     work.axi4lite.all;

use     work.GitVersionRegister.all;
--use     work.BuildVersion.all;


entity AXI4Lite_GitVersionRegister is
	Generic (
		VERSION_FILE_NAME : string
	);
	Port (
		Clock     : in  std_logic;
		Reset     : in  std_logic;
		
		S_AXI_m2s : in  T_AXI4Lite_BUS_M2S;
		S_AXI_s2m : out T_AXI4Lite_BUS_S2M
	);
end entity;


architecture rtl of AXI4Lite_GitVersionRegister is
	constant DATA_BITS            : natural          := 32;
	

	constant num_Version_register : natural          := get_num_Version_register;
  
  constant CONFIG      : T_AXI4_Register_Description_Vector       := get_Dummy_Descriptor(num_Version_register);
	constant VersionData : T_SLVV_32(0 to num_Version_register - 1) := read_Version_from_mem(MY_PROJECT_DIR & "/" & VERSION_FILE_NAME);
		
	function to_slvv(data : T_SLVV_32) return T_SLVV is
		variable temp : T_SLVV(VersionData'range)(DATA_BITS -1 downto 0) := (others => (others => '0'));
	begin
		for i in VersionData'range loop
			temp(i) := data(i);
		end loop;
		return temp;
	end function;

	signal   RegisterFile_ReadPort   : T_SLVV(0 to CONFIG'Length -1)(DATA_BITS - 1 downto 0);
  constant RegisterFile_WritePort  : T_SLVV(0 to CONFIG'Length -1)(DATA_BITS - 1 downto 0) := to_slvv(VersionData);
  
	signal AddressTrunc_m2s : T_AXI4LITE_BUS_M2S := Initialize_AXI4Lite_Bus_M2S(log2ceil(CONFIG'Length) + log2ceil(DATA_BITS), DATA_BITS);
	signal AddressTrunc_s2m : T_AXI4LITE_BUS_S2M := Initialize_AXI4Lite_Bus_S2M(log2ceil(CONFIG'Length) + log2ceil(DATA_BITS), DATA_BITS);
  
begin
	AXI4Lite_AdrTrunc : entity work.AXI4Lite_AddressTruncate
		port map (
			S_AXI_m2s               => S_AXI_m2s,
			S_AXI_s2m               => S_AXI_s2m,
			
			M_AXI_m2s               => AddressTrunc_m2s,
			M_AXI_s2m               => AddressTrunc_s2m
		);

  AXI4LiteReg : entity work.AXI4Lite_Register
		generic map(
			CONFIG                  => CONFIG
		)
		port map(
			S_AXI_ACLK              => Clock,
			S_AXI_ARESETN           => not Reset,
			
			S_AXI_m2s               => AddressTrunc_m2s,
			S_AXI_s2m               => AddressTrunc_s2m,
			
			RegisterFile_ReadPort   => RegisterFile_ReadPort,
			RegisterFile_WritePort  => RegisterFile_WritePort
		);
end architecture;
