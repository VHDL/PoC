-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein
--                  Max Kraft-Kugler
--                  Patrick Lehmann
--                  Iqbal Asif
--
-- Package:         mem_GitVersionRegister
--
-- Description:
-- -------------------------------------
-- This package defines the Functions, Strings and Records necessary for
-- the AXI4Lite_GitVersionRegister module.
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
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

use     STD.TextIO.all;

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.config.all;
use     work.vectors.all;
use     work.strings.all;
use     work.axi4lite.all;


package mem_GitVersionRegister is
	-------Define AXI Register structure-------------
	constant Version_of_VersionReg : std_logic_vector(7 downto 0) := x"02";

	constant Address_Width     : natural := 32;
	constant Data_Width        : natural := 32;

	type T_Version_Register_Common is record
		BuildDate_Day          : std_logic_vector(7 downto 0);
		BuildDate_Month        : std_logic_vector(7 downto 0);
		BuildDate_Year         : std_logic_vector(15 downto 0);

		NumberModule           : std_logic_vector(23 downto 0);
		VersionOfVersionReg    : std_logic_vector(7 downto 0);

		ToolVersion_Year       : std_logic_vector(15 downto 0);
		ToolVersion_Release    : std_logic_vector(7 downto 0);
		ToolVersion_SubRelease : std_logic_vector(7 downto 0);

		ProjektName            : std_logic_vector(159 downto 0);
	end record;

	type T_Version_Register_Top is record
		Version_Major          : std_logic_vector(7 downto 0);
		Version_Minor          : std_logic_vector(7 downto 0);
		Version_Release        : std_logic_vector(7 downto 0);
		Version_CommitsToTag   : std_logic_vector(5 downto 0);
		Version_DirtyUntracked : std_logic;
		Version_DirtyModified  : std_logic;

		GitHash                : std_logic_vector(159 downto 0);

		GitDate_Day            : std_logic_vector(7 downto 0);
		GitDate_Month          : std_logic_vector(7 downto 0);
		GitDate_Year           : std_logic_vector(15 downto 0);

		GitTime_Hour           : std_logic_vector(7 downto 0);
		GitTime_Min            : std_logic_vector(7 downto 0);
		GitTime_Sec            : std_logic_vector(7 downto 0);
		GitTime_Zone           : std_logic_vector(7 downto 0);

		BranchName_Tag         : std_logic_vector(511 downto 0);

		GitURL                 : std_logic_vector(1023 downto 0);
	end record;

	type T_Version_Register_UID is record
		UID                    : std_logic_vector(127 downto 0);
		User_eFuse             : std_logic_vector(31 downto 0);
		User_ID                : std_logic_vector(95 downto 0);
	end record;

	type T_Version_Register is record
		Common : T_Version_Register_Common;
		Top    : T_Version_Register_Top;
		UID    : T_Version_Register_UID;
	end record;

	constant C_VERSION_REGISTER_UID_INIT : T_Version_Register_UID := (
		UID        => (others => '0'),
		User_eFuse => (others => '0'),
		User_ID    => (others => '0')
	);

	constant C_Num_reg_UID_vec : T_NATVEC := (
		0 => C_VERSION_REGISTER_UID_INIT.UID'length / 32,
		1 => C_VERSION_REGISTER_UID_INIT.User_eFuse'length / 32,
		2 => C_VERSION_REGISTER_UID_INIT.User_ID'length / 32
	);

	constant C_Num_Reg_Common : natural := 8;
	constant C_Num_Reg_Top    : natural := 56;
	constant C_Num_Reg_UID    : natural := isum(C_Num_reg_UID_vec);


	constant C_Num_Version_Header     : natural := C_Num_Reg_Common + C_Num_Reg_Top;
	constant C_Num_Version_Register   : natural := C_Num_Version_Header + C_Num_Reg_UID;

	function to_SLVV_32_Common       (data : T_Version_Register_Common)        return T_SLVV_32;
	function to_SLVV_32_Top          (data : T_Version_Register_Top)           return T_SLVV_32;
	function to_Version_Register     (reg_vec : T_SLVV)                        return T_Version_Register;
	function get_Dummy_Descriptor(len : natural) return T_AXI4_Register_Vector;

	function get_Version_Descriptor return T_AXI4_Register_Vector;

	impure function read_Version_from_mem(FileName : string) return T_SLVV_32;
	impure function to_Version_Register  (FileName : string) return T_Version_Register;
end package;


package body mem_GitVersionRegister is

	function get_Version_Descriptor return T_AXI4_Register_Vector is
		variable temp : T_AXI4_Register_Vector(0 to C_Num_Version_Register -1);
		variable pos  : natural := 0;
		variable addr : natural := 0;
	begin
		temp(pos) := to_AXI4_Register(Name => "Common.BuildDate",                         Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
		addr := addr +4; pos := pos +1;
		temp(pos) := to_AXI4_Register(Name => "Common.NumberModule_VersionOfVersionReg",  Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
		addr := addr +4; pos := pos +1;
		temp(pos) := to_AXI4_Register(Name => "Common.ToolVersion",                       Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
		addr := addr +4; pos := pos +1;
		for i in 0 to 4 loop
			temp(pos) := to_AXI4_Register(Name => "Common.ProjektName(" & integer'image(i) & ")", Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
			addr := addr +4; pos := pos +1;
		end loop;


		temp(pos) := to_AXI4_Register(Name => "Top.Version", Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
		addr := addr +4; pos := pos +1;
		for i in 0 to 4 loop
			temp(pos) := to_AXI4_Register(Name => "Top.GitHash(" & integer'image(i) & ")" ,   Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
			addr := addr +4; pos := pos +1;
		end loop;
		temp(pos) := to_AXI4_Register(Name => "Top.GitDate", Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
		addr := addr +4; pos := pos +1;
		temp(pos) := to_AXI4_Register(Name => "Top.GitTime", Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
		addr := addr +4; pos := pos +1;
		for i in 0 to 15 loop
			temp(pos) := to_AXI4_Register(Name => "Top.BranchName_Tag(" & integer'image(i) & ")" ,   Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
			addr := addr +4; pos := pos +1;
		end loop;
		for i in 0 to 31 loop
			temp(pos) := to_AXI4_Register(Name => "Top.GitURL(" & integer'image(i) & ")" ,   Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
			addr := addr +4; pos := pos +1;
		end loop;

		for i in 0 to C_Num_reg_UID_vec(0) -1 loop
			temp(pos) := to_AXI4_Register(Name => "UID.UID(" & integer'image(i) & ")" ,   Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
			addr := addr +4; pos := pos +1;
		end loop;
		temp(pos) := to_AXI4_Register(Name => "UID.User_eFuse" ,   Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
		addr := addr +4; pos := pos +1;
		for i in 0 to C_Num_reg_UID_vec(2) -1 loop
			temp(pos) := to_AXI4_Register(Name => "UID.User_ID(" & integer'image(i) & ")" ,   Address => to_unsigned(addr, 32), RegisterMode => ReadOnly_NotRegistered);
			addr := addr +4; pos := pos +1;
		end loop;

		return temp(0 to pos -1);
	end function;

	function to_Version_Register (reg_vec : T_SLVV) return T_Version_Register is
		variable temp : T_Version_Register;
	begin
		temp.Common.BuildDate_Day          := reg_vec(0)(31 downto 24);
		temp.Common.BuildDate_Month        := reg_vec(0)(23 downto 16);
		temp.Common.BuildDate_Year         := reg_vec(0)(15 downto  0);
		temp.Common.NumberModule           := reg_vec(1)(31 downto  8);
		temp.Common.VersionOfVersionReg    := reg_vec(1)( 7 downto  0);
		temp.Common.ToolVersion_Year       := reg_vec(2)(31 downto 16);
		temp.Common.ToolVersion_Release    := reg_vec(2)(15 downto  8);
		temp.Common.ToolVersion_SubRelease := reg_vec(2)( 7 downto  0);
		for i in 0 to 4 loop
			temp.Common.ProjektName(32 * i +31 downto 32 * i) := reg_vec(i + 3);
		end loop;

		temp.Top.Version_Major          := reg_vec(8)(31 downto 24);
		temp.Top.Version_Minor          := reg_vec(8)(23 downto 16);
		temp.Top.Version_Release        := reg_vec(8)(15 downto  8);
		temp.Top.Version_CommitsToTag   := reg_vec(8)( 7 downto  2);
		temp.Top.Version_DirtyUntracked := reg_vec(8)(1);
		temp.Top.Version_DirtyModified  := reg_vec(8)(0);
		for i in 0 to 4 loop
			temp.Top.GitHash(32 * i +31 downto 32 * i) := reg_vec(i + 9);
		end loop;
		temp.Top.GitDate_Day            := reg_vec(14)(31 downto 24);
		temp.Top.GitDate_Month          := reg_vec(14)(23 downto 16);
		temp.Top.GitDate_Year           := reg_vec(14)(15 downto  0);
		temp.Top.GitTime_Hour           := reg_vec(15)(31 downto 24);
		temp.Top.GitTime_Min            := reg_vec(15)(23 downto 16);
		temp.Top.GitTime_Sec            := reg_vec(15)(15 downto  8);
		temp.Top.GitTime_Zone           := reg_vec(15)( 7 downto  0);
		for i in 0 to 15 loop
			temp.Top.BranchName_Tag(32 * i +31 downto 32 * i) := reg_vec(i + 16);
		end loop;
		for i in 0 to 31 loop
			temp.Top.GitURL(32 * i +31 downto 32 * i)         := reg_vec(i + 32);
		end loop;

		for i in 0 to 3 loop
			temp.UID.UID(32 * i +31 downto 32 * i)     := reg_vec(i + 64);
		end loop;
		temp.UID.User_eFuse                            := reg_vec(68);
		for i in 0 to 2 loop
			temp.UID.User_ID(32 * i +31 downto 32 * i) := reg_vec(i + 69);
		end loop;

		return temp;
	end function;


	function get_Dummy_Descriptor(len : natural) return T_AXI4_Register_Vector is
		variable descriptor : T_AXI4_Register_Vector(0 to len -1);
	begin
		for i in descriptor'range loop
			descriptor(i) := to_AXI4_Register(
				Name         => "Dummy(" & integer'image(i) & ")",
				Address      => to_unsigned(i *4,Address_Width),
				RegisterMode => ReadOnly_NotRegistered);
		end loop;
		return descriptor;
	end function;


	function to_SLVV_32_Common(data : T_Version_Register_Common) return T_SLVV_32 is
		variable temp : T_SLVV_32(0 to 7) := (others => (others => '0'));
		variable name : T_SLVV_32(4 downto 0) := to_slvv_32(data.ProjektName);
	begin
		temp(0) := data.BuildDate_Day & data.BuildDate_Month & data.BuildDate_Year;
		temp(1) := data.NumberModule & data.VersionOfVersionReg;
		temp(2) := data.ToolVersion_Year & data.ToolVersion_Release & data.ToolVersion_SubRelease;
		for i in name'reverse_range loop
			temp(i +3) := name(i);
		end loop;

		return temp;
	end function;

	function to_SLVV_32_Top(data : T_Version_Register_Top) return T_SLVV_32 is
		variable temp : T_SLVV_32(0 to 55)     := (others => (others => '0'));

		variable hash : T_SLVV_32(4 downto 0)  := to_slvv_32(data.GitHash);
		variable name : T_SLVV_32(15 downto 0) := to_slvv_32(data.BranchName_Tag);
		variable url  : T_SLVV_32(31 downto 0) := to_slvv_32(data.GitURL);

		variable idx  : natural := 0;
	begin
		temp(0) := data.Version_Major & data.Version_Minor & data.Version_Release & data.Version_CommitsToTag & data.Version_DirtyUntracked & data.Version_DirtyModified;
		idx := idx +1;

		for i in hash'reverse_range loop
			temp(i +1) := hash(i);
			idx := idx +1;
		end loop;

		temp(idx) := data.GitDate_Day & data.GitDate_Month & data.GitDate_Year;
		idx := idx +1;
		temp(idx) := data.GitTime_Hour & data.GitTime_Min & data.GitTime_Sec & data.GitTime_Zone;
		idx := idx +1;

		for i in name'reverse_range loop
			temp(idx) := name(i);
			idx := idx +1;
		end loop;

		for i in url'reverse_range loop
			temp(idx) := url(i);
			idx := idx +1;
		end loop;

		return temp;
	end function;

	impure function read_Version_from_mem(FileName : string) return T_SLVV_32 is
		constant Verbose                 : boolean  := POC_VERBOSE;
		constant MemoryLines             : positive := C_Num_Version_Header;
		variable HW_BUILD_VERSION_COMMON : T_Version_Register_Common;
		variable HW_BUILD_VERSION_TOP    : T_Version_Register_Top;

		file     FileHandle   : TEXT open READ_MODE is FileName;
		variable CurrentLine  : LINE;
		variable TempWord     : string(1 to 3);
		variable Good         : boolean;
		variable Len          : natural;

		constant Init         : string(1 to 128) := (others => NUL);
		variable result_s     : string(1 to 128) := Init;
		variable result_h     : std_logic_vector(159 downto 0);

		variable temp_signed : signed(7 downto 0);
		variable temp : T_SLVV_32(0 to MemoryLines -1)     := (others => (others => '0'));

	begin

		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_COMMON.BuildDate_Day            := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_COMMON.BuildDate_Month          := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_COMMON.BuildDate_Year           := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 16));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_COMMON.NumberModule             := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 24));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_COMMON.VersionOfVersionReg      := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_COMMON.ToolVersion_Year         := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 16));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_COMMON.ToolVersion_Release      := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_COMMON.ToolVersion_SubRelease   := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));

		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report result_s(1 to Len) severity note;
		HW_BUILD_VERSION_COMMON.ProjektName              := to_slv(to_RawString(resize(result_s(1 to Len), 20, NUL)));


		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.Version_Major               := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.Version_Minor               := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.Version_Release             := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.Version_CommitsToTag        := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 6));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		result_h(0 downto 0) := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 1)); -- result_h is unused until here
		HW_BUILD_VERSION_TOP.Version_DirtyUntracked := result_h(0);
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		result_h(0 downto 0) := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 1)); -- result_h is unused until here
		HW_BUILD_VERSION_TOP.Version_DirtyModified  := result_h(0);

		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		hread(CurrentLine, result_h(Len * 4 -1 downto 0), Good);
		assert not Verbose report "get_slv_h: " & integer'image(Len) severity NOTE;
		HW_BUILD_VERSION_TOP.GitHash                     := result_h(Len * 4 -1 downto 0);

		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.GitDate_Day                 := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.GitDate_Month               := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.GitDate_Year                := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 16));

		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.GitTime_Hour                := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.GitTime_Min                 := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));
		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report "get_slv_d(): " & result_s(1 to Len) severity Note;
		HW_BUILD_VERSION_TOP.GitTime_Sec                 := std_logic_vector(to_unsigned(to_natural_dec(result_s(1 to Len)), 8));

		readline(FileHandle, CurrentLine);
		read(CurrentLine, TempWord, Good);
		assert not Verbose report result_s(1 to Len) severity note;
		if not Good then
			report "Error while reading memory file '" & FileName & "'." severity FAILURE;
			return temp;
		end if;
		if TempWord(1) = '-' then
			temp_signed := to_signed(-1* to_natural_dec(TempWord(2 to TempWord'high)),8);
		else
			temp_signed := to_signed(to_natural_dec(TempWord(2 to TempWord'high)),8);
		end if;
		HW_BUILD_VERSION_TOP.GitTime_Zone                := std_logic_vector(temp_signed);

		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report result_s(1 to Len) severity note;
		HW_BUILD_VERSION_TOP.BranchName_Tag              := to_slv(to_RawString(resize(result_s(1 to Len), 64, NUL)));

		readline(FileHandle, CurrentLine);
		Len := CurrentLine'length;
		read(CurrentLine, result_s(1 to Len), Good);
		assert not Verbose report result_s(1 to Len) severity note;
		HW_BUILD_VERSION_TOP.GitURL                      := to_slv(to_RawString(resize(result_s(1 to Len), 128, NUL)));

		temp(0 to C_Num_Reg_Common - 1)                                  := to_SLVV_32_Common(HW_BUILD_VERSION_COMMON);
		temp(C_Num_Reg_Common to C_Num_Version_Header - 1) := to_SLVV_32_Top(HW_BUILD_VERSION_TOP);

		return temp;
	end function;
	
	impure function to_Version_Register  (FileName : string) return T_Version_Register is
		variable VersionData : T_SLVV_32(0 to C_Num_Version_Register - 1);
	
	begin
		VersionData(0 to C_Num_Version_Header - 1) := read_Version_from_mem(FileName);
		VersionData(C_Num_Version_Header to C_Num_Version_Register - 1) := (others => (others => '0'));
		return to_Version_Register(VersionData);
	end function;
	
end package body;
