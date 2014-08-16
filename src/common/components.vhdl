-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;


PACKAGE components IS
	-- FlipFlop functions
	FUNCTION ffdre(q : STD_LOGIC; d : STD_LOGIC; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC;												-- D-FlipFlop with reset and enable
	FUNCTION ffdre(q : STD_LOGIC_VECTOR; d : STD_LOGIC_VECTOR; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC_VECTOR;	-- D-FlipFlop with reset and enable
	FUNCTION ffdse(q : STD_LOGIC; d : STD_LOGIC; set : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC;												-- D-FlipFlop with set and enable
	FUNCTION fftre(q : STD_LOGIC; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC;																			-- T-FlipFlop with reset and enable
	FUNCTION ffrs(q : STD_LOGIC; rst : STD_LOGIC; set : STD_LOGIC) RETURN STD_LOGIC;																			-- RS-FlipFlop with dominant rst
	FUNCTION ffsr(q : STD_LOGIC; rst : STD_LOGIC; set : STD_LOGIC) RETURN STD_LOGIC;																			-- RS-FlipFlop with dominant set

END;


PACKAGE BODY components IS
	-- D-FlipFlop with reset and enable
	FUNCTION ffdre(q : STD_LOGIC; d : STD_LOGIC; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		RETURN ((d AND en) OR (q AND NOT en)) AND NOT rst;
	END FUNCTION;
	
	FUNCTION ffdre(q : STD_LOGIC_VECTOR; d : STD_LOGIC_VECTOR; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN ((d AND (q'range => en)) OR (q AND NOT (q'range => en))) AND NOT (q'range => rst);
	END FUNCTION;
	
	-- D-FlipFlop with set and enable
	FUNCTION ffdse(q : STD_LOGIC; d : STD_LOGIC; set : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		RETURN ((d AND en) OR (q AND NOT en)) OR set;
	END FUNCTION;
	
	-- T-FlipFlop with reset and enable
	FUNCTION fftre(q : STD_LOGIC; rst : STD_LOGIC; en : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		RETURN ((NOT q AND en) OR (q AND NOT en)) AND NOT rst;
	END FUNCTION;
	
	-- RS-FlipFlop with dominant rst
	FUNCTION ffrs(q : STD_LOGIC; rst : STD_LOGIC; set : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		RETURN (q OR set) AND NOT rst;
	END FUNCTION;
	
	-- RS-FlipFlop with dominant set
	FUNCTION ffsr(q : STD_LOGIC; rst : STD_LOGIC; set : STD_LOGIC) RETURN STD_LOGIC IS
	BEGIN
		RETURN (q AND NOT rst) OR set;
	END FUNCTION;
END PACKAGE BODY;