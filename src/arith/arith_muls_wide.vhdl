-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Martin Zabel
-- 
-- Entity:					Signed wide multiplication spanning multiple DSP or MULT blocks.
-- 
-- Description:
-- -------------------------------------
-- Signed wide multiplication spanning multiple DSP or MULT blocks.
-- Small partial products are calculated through LUTs.
-- For detailed documentation see below.
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universität Dresden - Germany,
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
-- =============================================================================

library ieee;
use			ieee.std_logic_1164.all;
use			ieee.numeric_std.all;


entity arith_muls_wide is
	generic (
		NA : integer range 2	to 18;-- 18;
		NB : integer range 19 to 36;-- 26;
		SPLIT : positive);					-- 17 or NB-18

	port (
		a : in	signed(NA-1 downto 0);
		b : in	signed(NB-1 downto 0);
		p : out signed(NA+NB-1 downto 0));

end entity arith_muls_wide;

-- Signed wide multiplication spanning multiple DSP or MULT blocks.
-- Small partial products are calculated through LUTs.
--
-- Currently supported operand widths are given by generic declaration.
--
-- The generic SPLIT specifies at which bit position of 'b' the multiplication
-- is split into upper and lower product. Typical values are:
-- SPLIT = 17:
--	 Lower product uses MULT block. Due to unsigned, only 17 bits are available.
--	 Upper product uses LUTs or another MULT block, depending on the remaining
--	 size. Final sum is calculated by LUTs in the former case, and inside the
--	 MULT block (if possible) in the latter case.
-- SPLIT = NB-18:
--	 Upper product uses MULT block. Now all 18 bits are available.
--	 Lower product uses LUTs or another MULT block, depending on the remaining
--	 size. Final sum is calculated inside the upper MULT block (if possible).
--
-- Note: if remaining part of 'b' exceeds 2/3 of 18 = 12 bit, then another MULT
-- block is used to save LUTs.
--
-- Example: NA=18,NB=26 on Virtex-4:
--	 SPLIT = 17 gives more logic but less delay.
--	 SPLIT = NB-18 = 8 gives less logic but more delay.
--
-- TODO: expand range of input widths

architecture rtl of arith_muls_wide is
	-- Factors must be of same type for multiplication.
	-- Thus, for the lower product, the lower part of b is "converted" to
	-- unsigned by prepending a '0'.
	signal bl : signed(SPLIT		downto 0);		 -- '0' & lower part of b
	signal bh : signed(NB-1		 downto SPLIT); -- higher part of b
	signal pl : signed(NA+SPLIT downto 0);		 -- lower product
	signal ph : signed(NA+NB-1	downto SPLIT); -- upper product

	-- purpose: Determine appropiate multiplier style
	function f_mult_style (
		constant SIZE : positive)
		return string is
	begin	-- _mult_style
		if SIZE < 12 then									 -- 2/3 of 18
			return "lut";
		end if;
		return "block";
	end f_mult_style;

	attribute mult_style : string;
	attribute mult_style of pl : signal is f_mult_style(bl'length);
	attribute mult_style of ph : signal is f_mult_style(bh'length);

begin	-- rtl

	-- "Convert" lower part of b to unsigned as noted above.
	bl <= '0' & b(bl'left-1 downto 0);
	bh <= b(b'left downto bl'left);

	-- Do not add pl to ph here, otherwise a MULT block is always used for ph
	-- even if LUTs are intended. For case SPLIT = NB-18, merging of MULT block
	-- and adder also works, if the adder has a separate statement (below).
	pl <= a * bl;
	ph <= a * bh;

	-- Sign extension is implicitly enforced by "signed" operands.
	p(ph'right-1 downto 0)		<= pl(ph'right-1 downto 0);
	p(p'left downto ph'right) <= ph + pl(pl'left downto ph'right);

	-- Summing up both products in the DSP block even for SPLIT=17 is also
	-- possible with the following statement:
	-- p <= pl + (ph & to_signed(0,ph'right));
	-- But, the delay for sum is very high. Maybe the granularity of the timing
	-- specification is not fine enough. It must also be considered, that pl must
	-- be routed again to the DSP block giving also a large delay.

end rtl;
