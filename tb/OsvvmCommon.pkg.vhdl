-- =============================================================================
-- Brief
-- Package to set the OSVVM result directory
--
-- Author(s)
--   Jonas Schreiner
-- 
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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

package OsvvmTestCommonPkg is
	-- FIXME: check if this is still needed. The constant was used by OSVVM in tranings, but is not relevant for normal testbenches.
	constant OSVVM_RESULTS_DIR : string := "";
end OsvvmTestCommonPkg;
