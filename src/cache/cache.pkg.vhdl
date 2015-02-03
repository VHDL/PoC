-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Package:					Cache functions and types
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		For detailed documentation see below.
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;


package cache is
	-- cache-lookup Result
	TYPE T_CACHE_RESULT	IS (CACHE_RESULT_NONE, CACHE_RESULT_HIT, CACHE_RESULT_MISS);

	FUNCTION to_Cache_Result(CacheHit : STD_LOGIC; CacheMiss : STD_LOGIC) RETURN T_CACHE_RESULT;
	
end package cache;


package body cache is

	FUNCTION to_cache_Result(CacheHit : STD_LOGIC; CacheMiss : STD_LOGIC) RETURN T_CACHE_RESULT IS
	BEGIN
		IF (CacheMiss = '1') THEN
			RETURN CACHE_RESULT_MISS;
		ELSIF (CacheHit = '1') THEN
			RETURN CACHE_RESULT_HIT;
		END IF;
		RETURN CACHE_RESULT_NONE;
	END FUNCTION;

end cache;



