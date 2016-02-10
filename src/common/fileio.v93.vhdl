-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Patrick Lehmann
--									Thomas B. Preusser
--
-- Package:     		File I/O-related Functions.
--
-- Description:
-- ------------------------------------
--   Exploring the options for providing a more convenient API than std.textio.
--   Not yet recommended for adoption as it depends on the VHDL generation and
--   still is under discussion.
--
--	 Open problems:
--     - verify that std.textio.write(text, string) is, indeed, specified and
--              that it does *not* print a trailing \newline
--          -> would help to eliminate line buffering in shared variables
--     - move C_LINEBREAK to my_config to keep platform dependency out?
--
-- License:
-- ============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
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

use			STD.TextIO.all;

library	PoC;
use			PoC.my_project.all;
use			PoC.strings.all;
use			PoC.utils.all;


package FileIO is
	file GlobalLogFile		: TEXT;

	subtype T_LOGFILE_OPEN_KIND is FILE_OPEN_KIND range WRITE_MODE to APPEND_MODE;
	
	procedure OpenLogFile(Status : out FILE_OPEN_STATUS; FileName : STRING; OpenKind : T_LOGFILE_OPEN_KIND := WRITE_MODE);
	procedure CloseLogFile;
	
	-- Constant declarations
	constant C_LINEBREAK : STRING;

	-- ===========================================================================
	procedure stdout_Print    (str : STRING);
	procedure stdout_PrintLine(str : STRING := "");
	procedure stdout_Flush;

end package;


package body FileIO is
	-- ===========================================================================
	constant C_LINEBREAK : STRING := ite(str_equal(MY_OPERATING_SYSTEM, "WINDOWS"), (CR & LF), (1 => LF));
	
	-- ===========================================================================
	shared variable LogFile_IsOpen	: BOOLEAN		:= FALSE;
	
	procedure OpenLogFile(Status : out FILE_OPEN_STATUS; FileName : STRING; OpenKind : T_LOGFILE_OPEN_KIND := WRITE_MODE) is
		variable OpenStatus		: FILE_OPEN_STATUS;
	begin
		file_open(OpenStatus, GlobalLogFile, FileName, OpenKind);
		LogFile_IsOpen	:= (OpenStatus = OPEN_OK);
		Status					:= OpenStatus;
	end procedure; 
	
	procedure CloseLogFile is
		begin
			if (LogFile_IsOpen = TRUE) then
				file_close(GlobalLogFile);
				LogFile_IsOpen	:= FALSE;
			end if;
		end procedure;

	shared variable stdout_LineBuffer : line;

	procedure stdout_Print(str : STRING) is
	begin
		write(stdout_LineBuffer, str);
	end procedure;
	
	procedure stdout_PrintLine(str : STRING := "") is
	begin
		write(stdout_LineBuffer, str);
		writeline(output, stdout_LineBuffer);
	end procedure;
	
	procedure stdout_Flush is
	begin
		writeline(output, stdout_LineBuffer);
	end procedure;
	
end package body;
