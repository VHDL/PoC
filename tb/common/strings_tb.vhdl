-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Testbench:				Tests global constants, functions and settings
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		TODO
-- 
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
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

entity strings_tb is
end strings_tb;

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.simulation.all;


architecture tb of strings_tb is
	constant raw_format_slv_dec_result0		: STRING		:= raw_format_slv_dec(STD_LOGIC_VECTOR'(x"12"));
	constant raw_format_slv_dec_result1		: STRING		:= raw_format_slv_dec(x"3456");
	constant raw_format_slv_dec_result2		: STRING		:= raw_format_slv_dec(x"12345678");
	constant raw_format_slv_dec_result3		: STRING		:= raw_format_slv_dec(x"A1B2C3D4E5F607A8");
	
begin
	process
	begin
		tbAssert((raw_format_slv_dec_result0 = "18"),										"raw_format_slv_dec(0x12)="	& raw_format_slv_dec_result0 &	"    Expected='18'");
		tbAssert((raw_format_slv_dec_result1 = "13398"),								"raw_format_slv_dec(0x3456)="	& raw_format_slv_dec_result1 &	"    Expected='13398'");
		tbAssert((raw_format_slv_dec_result2 = "305419896"),						"raw_format_slv_dec(0x12345678)="	& raw_format_slv_dec_result2 &	"    Expected='305419896'");
		tbAssert((raw_format_slv_dec_result3 = "11651590505119483816"),	"raw_format_slv_dec(0xA1b2c3d4e5f607a8)="	& raw_format_slv_dec_result3 &	"    Expected='11651590505119483816'");
		
		tbAssert((str_length("") = 0),																	"str_length('')=" & INTEGER'image(str_length("")) & "  Expected=0");
		tbAssert((str_length((1 to 3 => C_POC_NUL)) = 0),								"str_length('\0\0\0')=" & INTEGER'image(str_length((1 to 3 => C_POC_NUL))) & "  Expected=0");
		tbAssert((str_length("Hello") = 5),															"str_length('Hello')=" & INTEGER'image(str_length("Hello")) & "  Expected=5");
		tbAssert((str_length("Hello" & (1 to 3 => C_POC_NUL)) = 5),			"str_length('Hello\0\0\0')=" & INTEGER'image(str_length("Hello" & (1 to 3 => C_POC_NUL))) & "  Expected=5");
		
		tbAssert((str_match("", "") = TRUE),																		"str_match('', '')=" & BOOLEAN'image(str_match("", "")) & "  Expected=TRUE");
		tbAssert((str_match("", (1 to 3 => C_POC_NUL)) = TRUE),									"str_match('', '\0\0\0')=" & BOOLEAN'image(str_match("", (1 to 3 => C_POC_NUL))) & "  Expected=TRUE");
		tbAssert((str_match("Hello", "hello") = FALSE),													"str_match('Hello', 'hello')=" & BOOLEAN'image(str_match("Hello", "hello")) & "  Expected=FALSE");
		tbAssert((str_match("Hello", "Hello") = TRUE),													"str_match('Hello', 'Hello')=" & BOOLEAN'image(str_match("Hello", "Hello")) & "  Expected=TRUE");
		tbAssert((str_match("Hello World", "Hello") = FALSE),										"str_match('Hello World', 'Hello')=" & BOOLEAN'image(str_match("Hello World", "Hello")) & "  Expected=FALSE");
		tbAssert((str_match("Hello", "Hello World") = FALSE),										"str_match('Hello', 'Hello World')=" & BOOLEAN'image(str_match("Hello", "Hello World")) & "  Expected=FALSE");
		tbAssert((str_match("Hello", "Hello" & (1 to 3 => C_POC_NUL)) = TRUE),	"str_match('Hello', 'Hello\0\0\0')=" & BOOLEAN'image(str_match("Hello", "Hello" & (1 to 3 => C_POC_NUL))) & "  Expected=TRUE");
		
		tbAssert((str_imatch("", "") = TRUE),																		"str_imatch('', '')=" & BOOLEAN'image(str_imatch("", "")) & "  Expected=TRUE");
		tbAssert((str_imatch("", (1 to 3 => C_POC_NUL)) = TRUE),								"str_imatch('', '\0\0\0')=" & BOOLEAN'image(str_imatch("", (1 to 3 => C_POC_NUL))) & "  Expected=TRUE");
		tbAssert((str_imatch("Hello", "hello") = TRUE),													"str_imatch('Hello', 'hello')=" & BOOLEAN'image(str_imatch("Hello", "hello")) & "  Expected=TRUE");
		tbAssert((str_imatch("Hello", "Hello") = TRUE),													"str_imatch('Hello', 'Hello')=" & BOOLEAN'image(str_imatch("Hello", "Hello")) & "  Expected=TRUE");
		tbAssert((str_imatch("Hello World", "Hello") = FALSE),									"str_imatch('Hello World', 'Hello')=" & BOOLEAN'image(str_imatch("Hello World", "Hello")) & "  Expected=FALSE");
		tbAssert((str_imatch("Hello", "Hello World") = FALSE),									"str_imatch('Hello', 'Hello World')=" & BOOLEAN'image(str_imatch("Hello", "Hello World")) & "  Expected=FALSE");
		tbAssert((str_imatch("Hello", "Hello" & (1 to 3 => C_POC_NUL)) = TRUE),	"str_imatch('Hello', 'Hello\0\0\0')=" & BOOLEAN'image(str_imatch("Hello", "Hello" & (1 to 3 => C_POC_NUL))) & "  Expected=TRUE");
		
		
		-- simulation completed
		
		-- Report overall simulation result
		tbPrintResult;
		wait;
	end process;
end;
