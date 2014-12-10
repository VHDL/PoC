-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Package:     IO-related functions.
--
-- Authors:			Patrick Lehmann
--							Thomas B. Preusser
--
-- Description:
--   Exploring the options for providing a more convenient API than std.textio.
--   Not yet recommended for adoption as it depends on the VHDL generation and
--   still is under discussion.
--
--	 Open problems:
--     - verify that std.textio.write(text, string) is, indeed, specified and
--              that it does *not* print a trailing \newline
--          -> would help to elimate line buffering in shared variables
--     - move C_LINEBREAK to my_config to keep platform dependency out?
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany,
--  					 				 Chair for VLSI-Design, Diagnostics and Architecture
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

library	PoC;
use			PoC.utils.all;
use			PoC.my_project.MY_OPERATING_SYSTEM;


package txtio is
	-----------------------------------------------------------------------------
	-- Constant declarations
	constant C_LINEBREAK : STRING := ite(str_equal(MY_OPERATING_SYSTEM, "WINDOWS"), (CR & LF), (1 => LF));

	procedure stdout_write    (str : STRING);
	procedure stdout_writeline(str : STRING := "");
	procedure stderr_write    (str : STRING);
	procedure stderr_writeline(str : STRING := "");

end package txtio;

package body txtio is

	shared variable stdout_line : line;
	shared variable stderr_line : line;

	procedure stdout_write(str : STRING) is
	begin
		write(stdout_line, str);
	end procedure;
	
	procedure stdout_writeline(str : STRING := "") is
	begin
		write(stdout_line, str);
		writeline(stdout_line);
	end procedure;
	
	procedure stderr_write(str : STRING) is
	begin
		write(stderr_line, str);
	end procedure;
	
	procedure stderr_writeline(str : STRING := "") is
	begin
		write(stderr_line, str);
		writeline(stderr_line);
	end procedure;
	
end package body; 

