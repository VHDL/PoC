-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Martin Zabel
--                  Patrick Lehmann
--                  Stefan Unrein
--
-- Package:         VHDL package for component declarations, types and functions
--                  of the PoC.mem namespace
--
-- Description:
-- -------------------------------------
-- This package holds all component declarations, types and functions of the
-- :ref:`PoC.mem <NS:mem>` namespace.
--
-- It provides the following enumerations:
--
-- * ``T_MEM_FILEFORMAT`` specifies whether a file is in Intel Hex, Lattice
--   Mem, or Xilinx Mem format.
--
-- * ``T_MEM_CONTENT`` specifies whether data in text file is in binary, decimal
--   or hexadecimal format.
--
-- It provides the following functions:
--
-- * ``mem_FileExtension`` returns the file extension of a given filename.
-- * ``mem_ReadMemoryFile`` reads initial memory content from a given file.
--
-- License:
-- =============================================================================
-- Copryright 2017-2025 The PoC-Library Authors
-- Copyright 2008-2015 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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
use     IEEE.std_logic_textio.all;
use     IEEE.numeric_std.all;

use     work.config.all;
use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;


package mem is
	type T_MEM_FILEFORMAT is (
		MEM_FILEFORMAT_INTEL_HEX,
		MEM_FILEFORMAT_LATTICE_MEM,
		MEM_FILEFORMAT_XILINX_MEM
	);

	type T_MEM_CONTENT is (
		MEM_CONTENT_BINARY,
		MEM_CONTENT_DECIMAL,
		MEM_CONTENT_HEX
	);

	type T_RAM_TYPE is (
		RAM_TYPE_AUTO,
		RAM_TYPE_OPTIMIZED,
		RAM_TYPE_LUT_RAM,
		RAM_TYPE_BLOCK_RAM,
		RAM_TYPE_ULTRA_RAM
	);

	function mem_FileExtension(Filename : string) return string;

	impure function mem_ReadMemoryFile(
		FileName : string;
		MemoryLines : positive;
		BitsPerMemoryLine : positive;
		FORMAT : T_MEM_FILEFORMAT;
		CONTENT : T_MEM_CONTENT := MEM_CONTENT_HEX
	) return T_SLM;

	function get_ram_style_string(ram_style : T_RAM_TYPE) return string;
	function get_ramstyle_string(ram_style : T_RAM_TYPE)  return string;
	function get_ram_type(a : positive; d : positive) return T_INTVEC;

	function get_BRAM_half_width(a : positive) return integer;
	function get_BRAM_full_width(a : positive) return integer;
end package;


package body mem is
	function mem_FileExtension(FileName : string) return string is
	begin
		for i in FileName'high downto FileName'low loop
			if (FileName(i) = '.') then
				return str_toLower(FileName(i + 1 to FileName'high));
			end if;
		end loop;
		return "";
	end function;

	procedure ReadHex(L : inout LINE; Value : out std_logic_vector; Good : out boolean) is
		variable ok          : boolean;
		variable Char        : character;
		variable Digit      : T_DIGIT_HEX;
		constant DigitCount  : positive      := div_ceil(Value'length, 4);
		variable slv        : std_logic_vector((DigitCount * 4) - 1 downto 0);
		variable Swapped    : std_logic_vector((DigitCount * 4) - 1 downto 0);
	begin
		Good    := TRUE;
		for i in 0 to DigitCount - 1 loop
			read(L, Char, ok);
			if not ok then
				Swapped  := swap(slv, 4);
				Value    := Swapped(Value'length - 1 downto 0);
				return;
			end if;
			Digit := to_digit_hex(Char);
			if Digit = -1 then
				Good := FALSE;
				return;
			end if;
			slv(i * 4 + 3 downto i * 4)  := to_slv(Digit, 4);
		end loop;
		Swapped  := swap(slv, 4);
		Value    := Swapped(Value'length - 1 downto 0);
	end procedure;

	-- Reads a memory file and returns a 2D std_logic matrix
	impure function mem_ReadMemoryFile(
		FileName : string;
		MemoryLines : positive;
		BitsPerMemoryLine : positive;
		FORMAT : T_MEM_FILEFORMAT;
		CONTENT : T_MEM_CONTENT := MEM_CONTENT_HEX
	) return T_SLM is
		file FileHandle        : TEXT open READ_MODE is FileName;
		variable CurrentLine  : LINE;
		variable Good          : boolean;
		variable TempWord      : std_logic_vector((div_ceil(BitsPerMemoryLine, 4) * 4) - 1 downto 0);
		variable Result        : T_SLM(MemoryLines - 1 downto 0, BitsPerMemoryLine - 1 downto 0);
	begin
		Result := (others => (others => ite(SIMULATION, 'U', '0')));

		if FORMAT = MEM_FILEFORMAT_XILINX_MEM then
			-- discard the first line of a mem file
			readline(FileHandle, CurrentLine);
		end if;

		for i in 0 to MemoryLines - 1 loop
			exit when endfile(FileHandle);

			readline(FileHandle, CurrentLine);
--      report CurrentLine.all severity NOTE;
--      ReadHex(CurrentLine, TempWord, Good);
			-- WORKAROUND: for Xilinx Vivado (tested with 2018.3)
			--  Version:  All versions
			--  Issue:    User defined procedures using access types like line are not supported (synthesizable).
			--  Solution:  Use hread, which only supports n*4 bits.
			hread(CurrentLine, TempWord, Good);
			if not Good then
				report "Error while reading memory file '" & FileName & "'." severity FAILURE;
				return Result;
			end if;
			for j in 0 to BitsPerMemoryLine - 1 loop
				Result(i, j) := TempWord(j);
			end loop;
		end loop;
		return  Result;
	end function;

	function get_ramstyle_string(ram_style : T_RAM_TYPE) return string is
	begin
		if VENDOR = VENDOR_ALTERA then
			assert ram_style = RAM_TYPE_AUTO report "RAM_TYPE '" & T_RAM_TYPE'image(ram_style) & "' not supported for Altera Devices!" severity warning;
			return "no_rw_check";
		else
			return "default";
		end if;
	end function;

	function get_ram_style_string(ram_style : T_RAM_TYPE)  return string is
	begin
		if VENDOR = VENDOR_XILINX then
			case ram_style is
				when RAM_TYPE_AUTO      => return "default";
				when RAM_TYPE_OPTIMIZED => return "default";
				when RAM_TYPE_LUT_RAM   => return "distributed";
				when RAM_TYPE_BLOCK_RAM => return "block";
				when RAM_TYPE_ULTRA_RAM => return "ultra";
			end case;
		else
			return "";
		end if;
	end function;

	function get_ram_type(a : positive; d : positive) return T_INTVEC is
		constant URAM : natural := 0;
		constant BRAM : natural := 1;
--    constant LRAM : natural := 2;

		variable reminder  : natural := d;

		variable result : T_INTVEC(0 to 1) := (others => 0);
	begin
		--==================================================================
		--***********depth smaler than 512, everithing in LUT_RAM***********
		if a <= 8 then
--      LRAM := d;
			return result;

		--==================================================================
		--512 => 36 bit BRAM/2
		elsif a = 9 then
			result(BRAM)     := reminder / 36;
			reminder := reminder - (result(BRAM) * 36);
			if reminder > 28 then
				result(BRAM) := result(BRAM) +1;
--      else
--        LRAM := (d - reminder);
			end if;

		--==================================================================
		--***********1k => 18bit BRAM/2***********
		elsif a = 10 then
			result(BRAM)     := reminder / 18;
			reminder := reminder - (result(BRAM) * 18);
			if reminder > 14 then
				result(BRAM) := result(BRAM) +1;
--      else
--        LRAM := (d - reminder);
			end if;

		--==================================================================
		--***********2k => 9bit BRAM/2***********
		elsif a = 11 then
			result(BRAM)     := reminder / 9;
			reminder := reminder - (result(BRAM) * 9);
			if reminder > 6 then
				result(BRAM) := result(BRAM) +1;
--      else
--        LRAM := (d - reminder);
			end if;

		--==================================================================
		--***********4k => URAM***********
		elsif a = 12 then
			result(URAM)     := reminder / 72;
			reminder := reminder - (result(URAM) * 72);
			if reminder > 57 then
				result(URAM) := result(URAM) +1;
			else
			--==================================================================
			--***********remaining in BRAM***********
				result(BRAM)     := reminder / 4;
				reminder := reminder - (result(BRAM) * 4);
				if reminder > 2 then
					result(BRAM) := result(BRAM) +1;
--        else
--          LRAM := (d - reminder);
				end if;
			end if;

		--==================================================================
		--***********8k => Cascaded 2x URAM***********
		elsif a = 13 then
			result(URAM)     := reminder / 72;
			reminder := reminder - (result(URAM) * 72);
			if reminder > 57 then
				result(URAM) := result(URAM) +1;
			else
			--==================================================================
			--***********remaining in BRAM***********
				result(BRAM)     := reminder / 2;
				reminder := reminder - (result(BRAM) * 2);
				if reminder > 0 then
					result(BRAM) := result(BRAM) +1;
				end if;
			end if;

		--==================================================================
		--***********16k => Cascaded 4x URAM***********
		elsif a = 14 then
			result(URAM)     := reminder / 72;
			reminder := reminder - (result(URAM) * 72);
			if reminder > 57 then
				result(URAM) := result(URAM) +1;
			else
			--==================================================================
			--***********remaining in BRAM***********
				result(BRAM)     := reminder;
			end if;

		--==================================================================
		--***********For everithing else => use default/auto***********
		else
			result := (others => -1);
		end if;

		return result;
	end function;

	function get_BRAM_half_width(a : positive) return integer is
	begin
		if a = 9 then
			return 36;
		elsif a = 10 then
			return 18;
		elsif a = 11 then
			return 9;
		elsif a = 12 then
			return 4;
		elsif a = 13 then
			return 2;
		elsif a = 14 then
			return 1;
		else
			return -1;
		end if;
	end function;

	function get_BRAM_full_width(a : positive) return integer is
	begin
		if a = 9 then
			return 72;
		elsif a = 10 then
			return 36;
		elsif a = 11 then
			return 18;
		elsif a = 12 then
			return 9;
		elsif a = 13 then
			return 4;
		elsif a = 14 then
			return 2;
		elsif a = 15 then
			return 1;
		else
			return -1;
		end if;
	end function;

end package body;
