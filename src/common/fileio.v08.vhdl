-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Patrick Lehmann
--
-- Package:     		File I/O-related Functions.
--
-- Description:
-- ------------------------------------
--	TODO
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
use			PoC.utils.all;
use			PoC.strings.all;
use			PoC.ProtectedTypes.all;


package FileIO is
	file GlobalLogFile		: TEXT;

	subtype T_LOGFILE_OPEN_KIND is FILE_OPEN_KIND range WRITE_MODE to APPEND_MODE;
	
	-- Constant declarations
	constant C_LINEBREAK : STRING;

	-- ===========================================================================
	type T_LOGFILE is protected
		procedure OpenLogFile(Status : out FILE_OPEN_STATUS; FileName : STRING; OpenKind : T_LOGFILE_OPEN_KIND := WRITE_MODE);
		procedure CloseLogFile;
		
		procedure Print(str : STRING);
		procedure PrintLine(str : STRING := "");
		procedure Flush;
		-- procedure WriteLine(LineBuffer : inout LINE);
	end protected;

	-- ===========================================================================
	type T_FILE is protected
		procedure OpenFile(Status : out FILE_OPEN_STATUS; FileName : STRING; OpenKind : FILE_OPEN_KIND := WRITE_MODE);
		procedure CloseFile;
		
		procedure Print(str : STRING);
		procedure PrintLine(str : STRING := "");
		procedure Flush;
		-- procedure WriteLine(LineBuffer : inout LINE);
	end protected;
	
	type T_STDOUT is protected
		procedure Print(str : STRING);
		procedure PrintLine(str : STRING := "");
		procedure Flush;
	end protected;
end package;


package body FileIO is
	-- ===========================================================================
	constant C_LINEBREAK : STRING := ite(str_equal(MY_OPERATING_SYSTEM, "WINDOWS"), (CR & LF), (1 => LF));
	
	shared variable LogFile_IsOpen			: P_BOOLEAN;
	-- shared variable LogFile_IsMirrored	: P_BOOLEAN;
	
	-- ===========================================================================
	type T_LOGFILE is protected body
		variable LineBuffer	: LINE;
		
		procedure OpenLogFile(Status : out FILE_OPEN_STATUS; FileName : STRING; OpenKind : T_LOGFILE_OPEN_KIND := WRITE_MODE) is
		begin
			file_open(Status, GlobalLogFile, FileName, OpenKind);
			LogFile_IsOpen.Set(Status = OPEN_OK);
		end procedure;
		
		procedure CloseLogFile is
		begin
			if (LogFile_IsOpen.Get = TRUE) then
				file_close(GlobalLogFile);
				LogFile_IsOpen.Clear;
			end if;
		end procedure;

		procedure WriteLine(LineBuffer : inout LINE) is
		begin
			if (LogFile_IsOpen.Get = FALSE) then
				writeline(OUTPUT, LineBuffer);
			-- elsif (LogFile_IsMirrored.Get = TRUE) then
				-- tee(GlobalLogFile, LineBuffer);
			else
				writeline(GlobalLogFile, LineBuffer);
			end if ; 
		end procedure; 
		
		procedure Print(str : STRING) is
		begin
			write(LineBuffer, str);
		end procedure;
		
		procedure PrintLine(str : STRING := "") is
		begin
			write(LineBuffer, str);
			WriteLine(LineBuffer);
		end procedure;
		
		procedure Flush is
		begin
			WriteLine(LineBuffer);
		end procedure;
	end protected body;
	
	type T_FILE is protected body
		file			LocalFile		: TEXT;
		variable	LineBuffer	: LINE;
		variable	IsOpen			: BOOLEAN;
		
		procedure OpenFile(Status : out FILE_OPEN_STATUS; FileName : STRING; OpenKind : FILE_OPEN_KIND := WRITE_MODE) is
		begin
			file_open(Status, LocalFile, FileName, OpenKind);
			IsOpen	:= (Status = OPEN_OK);
		end procedure;
		
		procedure CloseFile is
		begin
			if (IsOpen = TRUE) then
				file_close(LocalFile);
				IsOpen	:= FALSE;
			end if;
		end procedure;
		
		procedure WriteLine(LineBuffer : inout LINE) is
		begin
			if (IsOpen = FALSE) then
				report "File is not open." severity ERROR;
			else
				writeline(LocalFile, LineBuffer);
			end if ; 
		end procedure; 

		procedure Print(str : STRING) is
		begin
			write(LineBuffer, str);
		end procedure;
		
		procedure PrintLine(str : STRING := "") is
		begin
			write(LineBuffer, str);
			WriteLine(LineBuffer);
		end procedure;
		
		procedure Flush is
		begin
			WriteLine(LineBuffer);
		end procedure;
	end protected body;
	
	type T_STDOUT is protected body
		variable LineBuffer	: LINE;

		procedure Print(str : STRING) is
		begin
			write(LineBuffer, str);
		end procedure;
		
		procedure PrintLine(str : STRING := "") is
		begin
			write(LineBuffer, str);
			writeline(OUTPUT, LineBuffer);
		end procedure;
		
		procedure Flush is
		begin
			writeline(OUTPUT, LineBuffer);
		end procedure;
	end protected body;
end package body;
