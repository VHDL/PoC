-- =============================================================================
-- Authors:          Thomas B. Preusser
--
-- Entity:          TODO
--
-- Description:
-- -------------------------------------
-- Computes from an input word, a word of the same size that has, at most,
-- one bit set. The output contains a set bit at the position of the rightmost
-- set bit of the input if and only if such a set bit exists in the input.
--
-- A typical use case for this computation would be an arbitration over
-- requests with a fixed and strictly ordered priority. The terminology of
-- the interface assumes this use case and provides some useful extras:
--
-- * Set tin <= '0' (no input token) to disallow grants altogether.
-- * Read tout (unused token) to see whether or any grant was issued.
-- * Read bin to obtain the binary index of the rightmost detected one bit.
--   The index starts at zero (0) in the rightmost bit position.
--
-- This implementation uses carry chains for wider implementations.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universität Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--              http://www.apache.org/licenses/LICENSE-2.0
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

use     work.config.all;
use     work.utils.all;

entity arith_FirstOne is
	generic (
		BITS : positive                                -- Length of Token Chain
	);
	port (
		TokenIn  : in  std_logic := '1';                -- Enable:   Fed Token
		Request  : in  std_logic_vector(BITS-1 downto 0);  -- Request:  Token Requests
		Grant    : out std_logic_vector(BITS-1 downto 0);  -- Grant:    Token Output
		TokenOut : out std_logic;                       -- Inactive: Unused Token
		Index    : out std_logic_vector(log2ceil(BITS)-1 downto 0)  -- Binary Grant Index
	);
end entity;

architecture rtl of arith_FirstOne is
begin
	-- Generic Carry Chain through Addition
	genGeneric: if VENDOR /= VENDOR_XILINX or BITS < 6 generate
		process(Request, TokenIn)
			variable onehot : std_logic_vector(Grant'range);
			variable binary : unsigned(Index'range);
			variable adder : unsigned(BITS downto 0);
		begin
			adder  := ("0" & unsigned(not Request)) + (1 to 1 => TokenIn);
			onehot := std_logic_vector(adder(BITS-1 downto 0)) and Request;
			binary := (others => '0');
			for i in onehot'range loop
				if onehot(i) = '1' then
					binary := binary or to_unsigned(i, binary'length);
				end if;
			end loop;
			TokenOut <= adder(BITS);
			Grant <= onehot;
			Index  <= std_logic_vector(binary);
		end process;
	end generate genGeneric;

	-- Optimized Xilinx Carry Chain by MUXCY Instantiation
	genXilinx: if VENDOR = VENDOR_XILINX and BITS >= 6 generate
		component MUXCY
			port (
				S  : in  std_logic;
				DI : in  std_logic;
				CI : in  std_logic;
				O  : out std_logic
			);
		end component;

		signal p : std_logic_vector(BITS-1 downto 0);  -- Propagates
		signal q : std_logic_vector(BITS   downto 0);  -- Carries = Intermediate Tokens
	begin

		-- Propagate if no local Request
		p <= not Request;

		-- Token Input
		q(0) <= to_X01(TokenIn);

		-- Token Forwarding Chain
		genChain: for i in 0 to BITS-1 generate
			signal pp, cc : std_logic;
			signal qq     : std_logic_vector(1 downto 0);
		begin

			-- q(i+1) <= q(i) and p(i)

			-- First MUXCY only with switching LUT
			genFirst: if i = 0 generate
				pp <= q(0) and p(0);
				cc <= '1';
			end generate;

			-- Others using Carry Input
			genChain: if i > 0 generate
				pp <= p(i);
				cc <= q(i);
			end generate genChain;

			MUXCY_inst : MUXCY
				port map (
					O  => q(i+1),
					CI => cc,
					DI => '0',
					S  => pp
				);

			-- Compute Grant
			qq <= q(i+1 downto i);
			with qq select Grant(i) <=
				'0' when "00" | "11",
				'1' when "01",
				'X' when others;

		end generate;

		-- Token Output
		TokenOut <= q(BITS);

		-- Recode to Binary
		process(q)
			variable b : std_logic;
		begin
			for i in 0 to log2ceil(BITS)-1 loop
				b := '0';
				for j in 0 to (BITS+(2**i)-1)/(2**(i+1))-1 loop
					b := b or (q((2**i) + j*(2**(i+1))) and not q(imin(BITS, (2**(i+1)) + j*(2**(i+1)))));
				end loop;
				Index(i) <= b;
			end loop;
		end process;

	end generate genXilinx;

end architecture;
