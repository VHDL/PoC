-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Package:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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



-- Summary:
-- ============
--  This function package parses *.VCD files and drives simulation stimulies.
--
-- Description:
-- ============
--	"VCD_ReadHeader" reads the file header.
--	"VCD_ReadLine" reads a line from *.vcd file.
--	"VCD_Read_StdLogic" parses a vcd one bit value to std_logic.
--	"VCD_Read_StdLogicVector" parses a vcd N bit value to std_logic_vector with N bits.
--
--	See ../tb/Test_vcd_example_tb.vhd for example code.
--
-- Dependancies:
-- =============
--	- IEEE.STD_LOGIC_1164.ALL
--	- IEEE.STD_LOGIC_TEXTIO.ALL
--	- IEEE.NUMERIC_STD.ALL
--	- STD.TEXTIO.ALL
--	- PoC.functions.ALL
--
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2012-06-08 16:51:07 $
--


library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.STD_LOGIC_TEXTIO.all;
use			IEEE.NUMERIC_STD.all;
use			STD.TEXTIO.all;

library PoC;
use			PoC.utils.all;

package sim_value_change_dump is
	subtype T_VCDLINE		is		string(1 to 80);

	function to_nat(str : string) return integer;
	function resize(str : string; size : positive) return string;

	procedure VCD_ReadHeader(file VCDFile : TEXT; VCDLine : inout T_VCDLINE);
	procedure VCD_ReadLine(file VCDFile : TEXT; VCDLine : out string);

	procedure VCD_Read_StdLogic(VCDLine : string; signal sl : out std_logic; WaveName : string);
	procedure VCD_Read_StdLogicVector(VCDLine : string; signal slv : out std_logic_vector; WaveName : string; def : std_logic := '0');

end sim_value_change_dump;

package body sim_value_change_dump is
	function to_digit(chr : character) return integer is
	begin
		case (chr) is
			when '0' =>			return 0;
			when '1' =>			return 1;
			when '2' =>			return 2;
			when '3' =>			return 3;
			when '4' =>			return 4;
			when '5' =>			return 5;
			when '6' =>			return 6;
			when '7' =>			return 7;
			when '8' =>			return 8;
			when '9' =>			return 9;
			when others =>	return -1;
		end case;
	end;

	function to_nat(str : string) return integer is
		variable Result			: natural		:= 0;
		variable Digit			: integer;
	begin
		if (to_digit(str(str'low)) /= -1) then
			for i in str'range loop
				Digit	:= to_digit(str(I));
				if Digit /= -1 then
					Result	:= Result * 10 + Digit;
				else
					exit;
				end if;
			end loop;

			return Result;
		else
			return -1;
		end if;
	end;

	function to_sl(Value : boolean) return std_logic is
	begin
		if Value then
			return '1';
		else
			return '0';
		end if;
	end;

	function to_sl(Value : character) return std_logic is
	begin
		case Value is
			when 'U' =>			return 'U';
			when 'X' =>			return 'X';
			when '0' =>			return '0';
			when '1' =>			return '1';
			when 'Z' =>			return 'Z';
			when 'W' =>			return 'W';
			when 'L' =>			return 'L';
			when 'H' =>			return 'H';
			when '-' =>			return '-';
			when others =>	return 'X';
		end case;
	end;

	function is_sl(char : character) return boolean is
	begin
		case char is
			when 'U' =>			return TRUE;
			when 'X' =>			return TRUE;
			when '0' =>			return TRUE;
			when '1' =>			return TRUE;
			when 'Z' =>			return TRUE;
			when 'W' =>			return TRUE;
			when 'L' =>			return TRUE;
			when 'H' =>			return TRUE;
			when '-' =>			return TRUE;
			when others =>	return FALSE;
		end case;
	end;

	function str_length(str : string) return natural is
		variable l	: natural		:= 0;
	begin
		for i in str'range loop
			if str(I) = NUL then
				return l;
			else
				l := l + 1;
			end if;
		end loop;

		return str'length;
	end;

	function str_equal(str1 : string; str2 : string) return boolean is
		variable L				: positive	:= imin(str_length(str1), str_length(str2));
	begin
		for i in 0 to L - 1 loop
			if (str1(str1'low + I) /= str2(str2'low + I)) then
				return FALSE;
			end if;
		end loop;

		return TRUE;
	end;

	function resize(str : string; size : positive) return string is
		constant MaxLength	: positive							:= imin(size, str'length);
		variable Result			: string(1 to size)			:= (others => nul);
	begin
		Result(1 to MaxLength) := str(1 to MaxLength);
		return Result;
	end;

	procedure VCD_ReadHeader(file VCDFile : TEXT; VCDLine : inout T_VCDLINE) is
	begin
		while not endfile(VCDFile) loop
			VCD_ReadLine(VCDFile, VCDLine);

			if (VCDLine(1) = '#') then
				assert (FALSE) report "Header passed" severity NOTE;
				exit;
			end if;
		end loop;
	end;

	procedure VCD_ReadLine(file VCDFile : TEXT; VCDLine : out string) is
		variable l					: LINE;
		variable c					: character;
		variable is_string	: boolean;
	begin
		readline(VCDFile, l);

		-- clear VCDLine
		for I in VCDLine'range loop
			VCDLine(I)		:= NUL;
		end loop;

		-- TODO: use imin of ranges, not 'range
		for i in VCDLine'range loop
			read(l, c, is_string);
			if not is_string then
				exit;
			end if;

			VCDLine(I)	:= c;
		end loop;
	end;

	procedure VCD_Read_StdLogic(VCDLine : string; signal sl : out std_logic; WaveName : string) is
	begin
		if (str_equal(VCDLine(2 to VCDLine'high), WaveName)) then
			sl	<= to_sl(VCDLine(1));
		end if;
	end;

	procedure VCD_Read_StdLogicVector(VCDLine : string; signal slv : out std_logic_vector; WaveName : string; def : std_logic := '0') is
		variable Result	: std_logic_vector(slv'range)			:= (others => def);
		variable k			: natural													:= 0;
	begin
		for i in VCDLine'range loop
			if not is_sl(VCDLine(I)) then
				k				:= I;
				exit;
			else
				Result := Result(Result'high - 1 downto Result'low) & to_sl(VCDLine(I));
			end if;
		end loop;

		if (str_equal(VCDLine(k + 1 to VCDLine'high), WaveName)) then
			slv				<= Result;
		end if;
	end;
end package body;
