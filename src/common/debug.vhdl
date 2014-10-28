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
	type line_vector is array(natural range<>) of line;

	type T_DBG_ENCODING_REPLACEMENT is record
		Pattern			: line;
		Replacement	: line;
	end record;
	type T_DBG_ENCODING_REPLACEMENTS is array(natural range <>) of T_DBG_ENCODING_REPLACEMENT;
	
--	shared variable C_DBG_DEFAULT_ENCODING_REPLACEMENTS : T_DBG_ENCODING_REPLACEMENTS := (
--		(Pattern => new string'("st_"),				Replacement => new string'("")),
--		(Pattern => new string'("device"),		Replacement => new string'("dev"))
--	);

	function dbg_ExportEncoding(Name : STRING; encodings : line_vector; tokenFileName : STRING) return BOOLEAN;--; Replacements: T_DBG_ENCODING_REPLACEMENTS := C_DBG_DEFAULT_ENCODING_REPLACEMENTS) return BOOLEAN;

end package;


package body debug is
	function dbg_ExportEncoding(Name : STRING; encodings : line_vector; tokenFileName : STRING) return BOOLEAN is	--; Replacements: T_DBG_ENCODING_REPLACEMENTS := C_DBG_DEFAULT_ENCODING_REPLACEMENTS) return BOOLEAN is
		file		 tokenFile						: TEXT open WRITE_MODE is	to_OSPath(tokenFileName);		-- declare ouput file
		variable l, t : line;
	begin
		report "Exporting encoding of '" & Name & "' to '" & tokenFileName & "'..." severity note;
		
		-- write file header
		write(l, "# Encoding file for '" & Name & "'");	writeline(tokenFile, l);
		write(l, "#");																	writeline(tokenFile, l);
		write(l, "# ChipScope Token File Version");			writeline(tokenFile, l);
		write(l, "@FILE_VERSION=1.0.0");								writeline(tokenFile, l);
		write(l, "#");																	writeline(tokenFile, l);
		write(l, "# Default token value");							writeline(tokenFile, l);
		write(l, "@DEFAULT_TOKEN=");										writeline(tokenFile, l);
		write(l, "#");																	writeline(tokenFile, l);
		
		-- write per device entires
		for i in encodings'range loop
			write(l, encodings(i).all);
--			for j in Replacements'range loop
--				t := l;
--				l := new string'(str_replace(t.all, Replacements(j).Pattern.all, Replacements(j).Replacement.all));
--				deallocate(t);
--			end loop;
			write(l, character'('='));
			write(l, raw_format_nat_hex(i));
			writeline(tokenFile, l);
		end loop;
		
		file_close(tokenFile);
		return true;
	end function;
end package body;

