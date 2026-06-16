-- =============================================================================
-- Authors:           Thomas B. Preusser
--                  Martin Zabel
--                  Steffen Koehler
--
-- Entity:           Gray-Code counter.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;


entity arith_Counter_Gray is
	generic (
		BITS : positive;                              -- Bit width of the counter
		INIT : natural         := 0                    -- Initial/reset counter value
	);
	port (
		Clock     : in  std_logic;
		Reset     : in  std_logic;                          -- Reset to INIT value
		Increment : in  std_logic;                          -- Increment
		Decrement : in  std_logic    := '0';                  -- Decrement
		Value     : out std_logic_vector(BITS-1 downto 0);  -- Value output
		CarryOut  : out std_logic                            -- Carry output
	);
end entity;


architecture rtl of arith_Counter_Gray is

	-- purpose: gray constant encoder
	function gray_encode (val : natural; len : positive) return unsigned is
		variable bin : unsigned(len-1 downto 0) := to_unsigned(val, len);
	begin
		if len = 1 then
			return bin;
		end if;
		return bin xor '0' & bin(len-1 downto 1);
	end gray_encode;

	-- purpose: parity generation
	function parity (val : unsigned) return std_logic is
		variable res : std_logic := '0';
	begin  -- parity
		for i in val'range loop
			res := res xor val(i);
		end loop;
		return res;
	end parity;

	-- Counter Register
	constant INIT_GRAY  : unsigned(BITS-1 downto 0) := gray_encode(INIT, BITS);
	signal gray_cnt_r   : unsigned(BITS-1 downto 0) := INIT_GRAY;
	signal gray_cnt_nxt : unsigned(BITS-1 downto 0);

	signal en : std_logic;                -- enable: inc xor dec

begin

	-----------------------------------------------------------------------------
	-- Actual Counter Register
	en <= Increment xor Decrement;
	process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				gray_cnt_r <= INIT_GRAY;
			elsif en = '1' then
				gray_cnt_r <= gray_cnt_nxt;
			end if;
		end if;
	end process;
	Value <= std_logic_vector(gray_cnt_r);

	-----------------------------------------------------------------------------
	-- Computation of Increment/Decrement


	-- Trivial one-bit Counter
	g1: if BITS = 1 generate
		gray_cnt_nxt <= not gray_cnt_r;
		CarryOut          <= gray_cnt_r(0) xor Decrement;
	end generate g1;

	-- Multi-Bit Counter
	g2: if BITS > 1 generate

		constant INIT_PAR : std_logic := parity(INIT_GRAY);
		-- search for first one in gray_cnt_r(MSB-1 downto LSB)
		-- first_one_n(i) = '1' denotes position i

		-- parity of gray_cnt_r
		signal par_r   : std_logic := INIT_PAR;
		signal par_nxt : std_logic;

	begin

		-- Parity Register
		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					par_r <= INIT_PAR;
				elsif en = '1' then
					par_r <= par_nxt;
				end if;
			end if;
		end process;

		-- Computation of next Value
		process(gray_cnt_r, par_r, Decrement)
			variable  x : unsigned(BITS-1 downto 0);
			variable  s : unsigned(BITS-1 downto 0);
		begin

			-- Prefer inc over dec to keep combinational path short in standard use.
			x         := gray_cnt_r(BITS-2 downto 0) & (par_r xnor Decrement);
			x(x'left) := not gray_cnt_r(BITS-1);  -- catch final carry to invert last bit
			s         := not x + 1;               -- locate first intermediate '1'

			gray_cnt_nxt <= s(BITS-1) & (gray_cnt_r(BITS-2 downto 0) xor
																	 (s(BITS-2 downto 0) and x(BITS-2 downto 0)));
			par_nxt      <= s(0) xor Decrement;
		end process;

		CarryOut <=  (gray_cnt_r(BITS-1) xor Decrement) and (gray_cnt_nxt(BITS-1) xnor Decrement);
	end generate g2;

end architecture;
