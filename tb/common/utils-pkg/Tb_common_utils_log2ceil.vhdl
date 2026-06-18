-- =============================================================================
-- Authors:         Stefan Unrein
--                  Markus Leiter
--
-- Entity:          utils.log2ceil test bench
--
-- Description:
-- -------------------------------------
-- TBD
--
-- License:
-- =============================================================================
-- Copyright 2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library ieee;
use     ieee.std_logic_1164.all;

library PoC;
use     PoC.utils.all;

library osvvm;
context osvvm.OsvvmContext;

entity Tb_common_utils_log2ceil is
end entity;

architecture tb of Tb_common_utils_log2ceil is
	constant TestName : string := "Tb_common_utils_log2ceil";
begin

	------------------------------------------------------------
	-- ControlProc
	--   Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
	begin
		-- Initialization of test
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		Log("Test utils.log2ceil");
		Log("INTEGER_BITS = " & to_string(INTEGER_BITS));

		Log("2 ** 0");
		AffirmIfEqual(log2ceil(1), 0);
		AffirmIfEqual(log2ceil(2), 1);
		AffirmIfEqual(log2ceil(3), 2);

		for i in 16 to INTEGER_BITS -2 loop
			Log("2 ** " & to_string(i));
			AffirmIfEqual(log2ceil(2 ** i - 2), i);
			AffirmIfEqual(log2ceil(2 ** i - 1), i);
			AffirmIfEqual(log2ceil(2 ** i    ), i);
			AffirmIfEqual(log2ceil(2 ** i + 1), i +1);
		end loop;

		Log("2 ** " & to_string(INTEGER_BITS -1));
		AffirmIfEqual(log2ceil(integer'high -1), INTEGER_BITS -1);
		AffirmIfEqual(log2ceil(integer'high),     INTEGER_BITS -1);

		Log("Test utils.log2ceilnz");
		Log("INTEGER_BITS = " & to_string(INTEGER_BITS));

		Log("2 ** 0");
		AffirmIfEqual(log2ceilnz(1), 1);
		AffirmIfEqual(log2ceilnz(2), 1);
		AffirmIfEqual(log2ceilnz(3), 2);


		EndOfTestReports;
		std.env.finish;
		wait;
	end process;
end architecture;
