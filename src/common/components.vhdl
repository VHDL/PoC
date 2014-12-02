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

library PoC;
use			PoC.utils.all;


PACKAGE components IS
	-- FlipFlop functions
	FUNCTION ffdre(q : STD_LOGIC; d : STD_LOGIC; rst : STD_LOGIC := '0'; en : STD_LOGIC := '1') RETURN STD_LOGIC;												-- D-FlipFlop with reset and enable
	FUNCTION ffdre(q : STD_LOGIC_VECTOR; d : STD_LOGIC_VECTOR; rst : STD_LOGIC := '0'; en : STD_LOGIC := '1') RETURN STD_LOGIC_VECTOR;	-- D-FlipFlop with reset and enable
	FUNCTION ffdse(q : STD_LOGIC; d : STD_LOGIC; set : STD_LOGIC := '0'; en : STD_LOGIC) RETURN STD_LOGIC;												-- D-FlipFlop with set and enable
	FUNCTION fftre(q : STD_LOGIC; rst : STD_LOGIC := '0'; en : STD_LOGIC := '1') RETURN STD_LOGIC;																			-- T-FlipFlop with reset and enable
	FUNCTION ffrs(q : STD_LOGIC; rst : STD_LOGIC := '0'; set : STD_LOGIC := '0') RETURN STD_LOGIC;																			-- RS-FlipFlop with dominant rst
	FUNCTION ffsr(q : STD_LOGIC; rst : STD_LOGIC := '0'; set : STD_LOGIC := '0') RETURN STD_LOGIC;																			-- RS-FlipFlop with dominant set

	-- adder
	function inc(value : STD_LOGIC_VECTOR; increment : NATURAL := 1) return STD_LOGIC_VECTOR;
	function inc(value : UNSIGNED; increment : NATURAL := 1) return UNSIGNED;

	-- counter
	function counter_inc(cnt : UNSIGNED; rst : STD_LOGIC; en : STD_LOGIC; init : NATURAL := 0) return UNSIGNED;
	function counter_eq(cnt : UNSIGNED; value : NATURAL) return STD_LOGIC;

	-- shift/rotate registers
	function sr_left(q : STD_LOGIC_VECTOR; i : STD_LOGIC) return STD_LOGIC_VECTOR;
	function sr_right(q : STD_LOGIC_VECTOR; i : STD_LOGIC) return STD_LOGIC_VECTOR;
	function rr_left(q : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR;
	function rr_right(q : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR;

	-- multiplexing
	function mux(sel : STD_LOGIC; sl0		: STD_LOGIC;				sl1		: STD_LOGIC)				return STD_LOGIC;
	function mux(sel : STD_LOGIC; slv0	: STD_LOGIC_VECTOR;	slv1	: STD_LOGIC_VECTOR)	return STD_LOGIC_VECTOR;
	function mux(sel : STD_LOGIC; us0		: UNSIGNED;					us1		: UNSIGNED)					return UNSIGNED;
END;


PACKAGE BODY components IS
	-- d-flipflop with reset and enable
	function ffdre(q : STD_LOGIC; d : STD_LOGIC; rst : STD_LOGIC := '0'; en : STD_LOGIC := '1') return STD_LOGIC is
	begin
		return ((d and en) or (q and not en)) and not rst;
	end function;
	
	function ffdre(q : STD_LOGIC_VECTOR; d : STD_LOGIC_VECTOR; rst : STD_LOGIC := '0'; en : STD_LOGIC := '1') return STD_LOGIC_VECTOR is
	begin
		return ((d and (q'range => en)) or (q and not (q'range => en))) and not (q'range => rst);
	end function;
	
	-- d-flipflop with set and enable
	function ffdse(q : STD_LOGIC; d : STD_LOGIC; set : STD_LOGIC := '0'; en : STD_LOGIC := '1') return STD_LOGIC is
	begin
		return ((d and en) or (q and not en)) or set;
	end function;
	
	-- t-flipflop with reset and enable
	function fftre(q : STD_LOGIC; rst : STD_LOGIC := '0'; en : STD_LOGIC := '1') return STD_LOGIC is
	begin
		return ((not q and en) or (q and not en)) and not rst;
	end function;
	
	-- rs-flipflop with dominant rst
	function ffrs(q : STD_LOGIC; rst : STD_LOGIC := '0'; set : STD_LOGIC := '0') return STD_LOGIC is
	begin
		return (q or set) and not rst;
	end function;
	
	-- rs-flipflop with dominant set
	function ffsr(q : STD_LOGIC; rst : STD_LOGIC := '0'; set : STD_LOGIC := '0') return STD_LOGIC is
	begin
		return (q and not rst) or set;
	end function;
	
	-- adder
	function inc(value : STD_LOGIC_VECTOR; increment : NATURAL := 1) return STD_LOGIC_VECTOR is
	begin
		return std_logic_vector(inc(unsigned(value), increment));
	end function;
	
	function inc(value : UNSIGNED; increment : NATURAL := 1) return UNSIGNED is
	begin
		return value + increment;
	end function;
	
	-- counter
	function counter_inc(cnt : UNSIGNED; rst : STD_LOGIC; en : STD_LOGIC; init : NATURAL := 0) return UNSIGNED is
	begin
		if (rst = '1') then
			return to_unsigned(init, cnt'length);
		elsif (en = '1') then
			return cnt + 1;
		else
			return cnt;
		end if;
--		return mux(rst, mux(en, cnt, cnt + 1), to_unsigned(init, cnt'length));
	end function;
	
	function counter_eq(cnt : UNSIGNED; value : NATURAL) return STD_LOGIC is
	begin
		return to_sl(cnt = to_unsigned(value, cnt'length));
	end function;
	
	-- shift/rotate registers
	function sr_left(q : STD_LOGIC_VECTOR; i : std_logic) return STD_LOGIC_VECTOR is
	begin
		return q(q'left - 1 downto q'right) & i;
	end function;
	
	function sr_right(q : STD_LOGIC_VECTOR; i : std_logic) return STD_LOGIC_VECTOR is
	begin
		return i & q(q'left downto q'right - 1);
	end function;
	
	function rr_left(q : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
	begin
		return q(q'left - 1 downto q'right) & q(q'left);
	end function;
	
	function rr_right(q : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
	begin
		return q(q'right) & q(q'left downto q'right - 1);
	end function;
	
	-- multiplexing
	function mux(sel : STD_LOGIC; sl0 : STD_LOGIC; sl1 : STD_LOGIC) return STD_LOGIC is
	begin
		return (sl0 and not sel) or (sl1 and sel);
	end function;
	
	function mux(sel : STD_LOGIC; slv0 : STD_LOGIC_VECTOR; slv1 : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
	begin
		return (slv0 and not (slv0'range => sel)) or (slv1 and (slv0'range => sel));
	end function;

	function mux(sel : STD_LOGIC; us0 : UNSIGNED; us1 : UNSIGNED) return UNSIGNED is
	begin
		return (us0 and not (us0'range => sel)) or (us1 and (us0'range => sel));
	end function;
END PACKAGE BODY;