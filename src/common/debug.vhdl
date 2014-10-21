-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Package:					Global configuration settings.
--
-- Authors:					Thomas B. Preusser
--									Martin Zabel
--									Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		This file evaluates the settings declared in the project specific package my_config.
--		See also template file my_config.vhdl.template.
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany,
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
-- ============================================================================

use			STD.TextIO.all;

library	PoC;
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.vectors.all;


package debug is
	constant C_DBG_STRING_LENGTH			: POSITIVE	:= 64;

	type T_DBG_ENCODING is record
		Name			: STRING(1 to C_DBG_STRING_LENGTH);
		Binary		: T_SLV_32;
	end record;

	type T_DBG_ENCODING_REPLACEMENT is record
		Pattern			: STRING(1 to C_DBG_STRING_LENGTH);
		Replacement	: STRING(1 to C_DBG_STRING_LENGTH);
	end record;
	
	type T_DBG_ENCODING_VECTOR				is array (natural range <>) of T_DBG_ENCODING;
	type T_DBG_ENCODING_REPLACEMENTS	is array (natural range <>) of T_DBG_ENCODING_REPLACEMENT;
	
	CONSTANT C_DBG_DEFAULT_ENCODING_REPLACEMENTS	: T_DBG_ENCODING_REPLACEMENTS		:= (
		(Pattern => resize("st_", C_DBG_STRING_LENGTH),				Replacement => resize("", C_DBG_STRING_LENGTH)),
		(Pattern => resize("device", C_DBG_STRING_LENGTH),		Replacement => resize("dev", C_DBG_STRING_LENGTH))
	);

	function dbg_ExportEncoding(Name : STRING; encodings : T_DBG_ENCODING_VECTOR; tokenFileName : STRING; Replacements: T_DBG_ENCODING_REPLACEMENTS := C_DBG_DEFAULT_ENCODING_REPLACEMENTS) return BOOLEAN;

end package;


package body debug is
	function dbg_ExportEncoding(Name : STRING; encodings : T_DBG_ENCODING_VECTOR; tokenFileName : STRING; Replacements: T_DBG_ENCODING_REPLACEMENTS := C_DBG_DEFAULT_ENCODING_REPLACEMENTS) return BOOLEAN is
		file		 tokenFile						: TEXT open WRITE_MODE is	to_OSPath(tokenFileName);		-- declare ouput file
    variable tokenLine						: LINE;																			-- 
		
		variable nameLength						: NATURAL		:= 0;
		variable hexLength						: NATURAL		:= 0;
		variable nameBuffer						: STRING(1 to 128);
		variable lineBuffer						: STRING(1 to 128);
		variable hexBuffer						: STRING(1 to (encodings(0).Binary'length / 4));
	begin
		report "Exporting encoding of '" & Name & "' to '" & tokenFileName & "'..." severity note;
		
		-- write file header
		write(tokenLine, "# Encoding file for '" & Name & "'");	writeline(tokenFile, tokenLine);
		write(tokenLine, "#");																	writeline(tokenFile, tokenLine);
		write(tokenLine, "# ChipScope Token File Version");			writeline(tokenFile, tokenLine);
		write(tokenLine, "@FILE_VERSION=1.0.0");								writeline(tokenFile, tokenLine);
		write(tokenLine, "#");																	writeline(tokenFile, tokenLine);
		write(tokenLine, "# Default token value");							writeline(tokenFile, tokenLine);
		write(tokenLine, "@DEFAULT_TOKEN=");										writeline(tokenFile, tokenLine);
		write(tokenLine, "#");																	writeline(tokenFile, tokenLine);
		
		-- write per device entires
		for i in encodings'range loop
			nameBuffer					:= resize(encodings(i).Name, nameBuffer'length);
			for j in Replacements'range loop
				nameBuffer				:= resize(str_replace(nameBuffer, str_trim(Replacements(j).Pattern), str_trim(Replacements(j).Replacement)), nameBuffer'length);
			end loop;
		
			nameLength									:= str_length(nameBuffer);
			lineBuffer(1 to nameLength)	:= nameBuffer(1 to nameLength);
			lineBuffer(nameLength + 1)	:= '=';
			
			hexBuffer										:= resize(str_ltrim(raw_format_slv_hex(encodings(i).Binary), '0'), hexBuffer'length);
			hexLength										:= str_length(hexBuffer);
			if (hexLength > 0) then
				lineBuffer(nameLength + 2 to nameLength + hexLength + 1)	:= hexBuffer(1 to hexLength);
				lineBuffer(nameLength + hexLength + 2)										:= NUL;
			else
				lineBuffer(nameLength + 2)	:= '0';
				lineBuffer(nameLength + 3)	:= NUL;
			end if;
			
			write(tokenLine, str_trim(lineBuffer));
			writeline(tokenFile, tokenLine);
		end loop;
		
		file_close(tokenFile);
		return true;
	end function;
end package body;