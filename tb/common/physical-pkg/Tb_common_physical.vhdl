-- =============================================================================
-- Authors:          Patrick Lehmann
--
-- Testbench:        Tests physical type arithmetic (FREQ, time)
--
-- Description:
-- ------------------------------------
--    Converted to OSVVM style.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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

library PoC;
use     PoC.physical.all;

library osvvm;
context osvvm.OsvvmContext;


entity Tb_common_physical is
end entity;


architecture tb of Tb_common_physical is
	constant TestName : string := "Tb_common_physical";
begin

	ControlProc : process
		variable t : time;
		variable f : FREQ;
	begin
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		Log("NOTE: This is a mechanically converted old-style testbench and needs a proper OSVVM port.", INFO);

		t := 20 ns;
		AffirmIf(integer(10.0 * to_real(t, 1 ns))  = 200, "Failed stripping of time unit.");
		f := 1.0 / t;
		AffirmIf(integer(10.0 * to_real(f, 1 MHz)) = 500, "Failed stripping of FREQ unit.");

		AffirmIf(integer(10.0 * t*f) = 10, "Failed cycle computation t*f.");
		AffirmIf(integer(10.0 * f*t) = 10, "Failed cycle computation f*t.");

		EndOfTestReports;
		std.env.stop;
		wait;
	end process;
end architecture;
