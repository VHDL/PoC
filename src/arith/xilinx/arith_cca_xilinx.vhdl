-- =============================================================================
-- Author:      Thomas B. Preusser
-- ================================================================================
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
-- ===================================================================================

library IEEE;
use     IEEE.std_logic_1164.all;

-- Carry-compact adder (CCA) for Xilinx Virtex-5 architectures and newer.
--
-- A carry-compact adder (CCA) utilizes the fast carry chain of contemporary FPGA devices to implement a fast and even
-- compacted binary word addition. For wide operands, it accounts for the delay encountered even on this fast signal
-- path and uses the associated time to perform a significantly shorter but effective LUT-based parallel computation
-- that reduces the length of the internal ripple-carry adder (RCA) without affecting the critical path length.
--
-- The compaction performed by the CCA is performed hierarchically on potentially multiple levels. The number of levels
-- may be restricted by the optional generic ``X``. A linear compaction on a single level may be of special interest as
-- it typically does not increase the LUT demand in comparison to a standard RCA implementation. The generic ``L`` is
-- architecture-dependent and estimates the delay of a LUT stage in terms of carry-chain hops. It is a tuning
-- parameter. Values around 20 are a good starting point. If ``BITS`` is too small for a compaction, a standard RCA is
-- used and a note is reported.
--
-- The adder is combinational: ``s`` is ``a + b + c`` modulo ``2**BITS``; there is no carry output.
--
-- For a detailed description see:
--
--   Preusser, T.B.; Zabel, M.; Spallek, R.G.:
--   `"Accelerating Computations on FPGA Carry Chains by Operand Compaction"
--   <http://dx.doi.org/10.1109/ARITH.2011.22>`__,
--   20th IEEE Symposium on Computer Arithmetic (ARITH), 2011.
--
-- This implementation instantiates ``LUT6_2`` primitives for the compaction and expansion logic.
entity arith_cca is
	generic(
		BITS : positive;     -- Width of the operands and of the sum in bits.
		L    : natural;      -- Carry-chain length equivalent to the delay of one LUT stage.
		X    : natural := 0  -- Maximum compaction depth; ``0``: unlimited.
	);
	port(
		a : in  std_logic_vector(BITS-1 downto 0);  -- First operand.
		b : in  std_logic_vector(BITS-1 downto 0);  -- Second operand.
		c : in  std_logic := '0';                   -- Carry input.
		s : out std_logic_vector(BITS-1 downto 0)   -- Sum ``a + b + c``, truncated to ``BITS`` bits.
	);
end entity;


library IEEE;
use     IEEE.numeric_std.all;

architecture rtl of arith_cca is

	type tLevel is record
		base : natural;
		core : integer;
		done : natural;
	end record tLevel;
	type tLevels is array(natural range<>) of tLevel;

	function compact return tLevels is
		variable res : tLevels(0 to 31);
		variable base : integer := 0;
		variable core : integer := (BITS - L) / 2;
		variable done : integer := BITS - 2*core;
	begin
		for i in res'range loop
			res(i) := (base, core, done);
			if core <= 0 then
				for j in 0 to i loop
					report integer'image(j)&": ("&integer'image(res(j).base)&", "&integer'image(res(j).core)&", "&integer'image(res(j).done)&")" severity note;
				end loop;
				return  res(0 to i);
			end if;
			base := base + 2*core;
			done := done + (core-2*(core/2)+L);
			core := core/2 - L;
			if i+1 = X and core > 0 then
				done := done + 2*core;
				core := 0;
			end if;
		end loop;
	end function compact;

	constant LEVELS : tLevels := compact;
	constant CCA    : boolean := LEVELS'length > 1;

begin
	genRCA: if not CCA generate
		assert false
			report "Using standard RCA for small "&integer'image(BITS)&"-bit adder."
			severity note;
		s <= std_logic_vector(unsigned(a)+unsigned(b)+(0 to 0 => c));
	end generate;

	genCCA: if CCA generate
		constant WI : positive := LEVELS(LEVELS'high).base;
		constant WC : positive := LEVELS(LEVELS'high).done + LEVELS'high*L + 2*LEVELS(LEVELS'high).core;

		signal ai, bi, si : std_logic_vector(WI-1 downto 0);
		signal ac, bc, sc : unsigned(WC-1 downto 0);
	begin

		-- Feed operands into compaction tree except for a prefix of L bits
		-- to hide expansion delay of lower-order bits
		blkFeed: block is
			constant DONE : natural := LEVELS(0).done;
		begin
			-- alias most-significant prefix of ports and compacted operation
			genPre: if DONE > 0 generate
				ac(WC-1 downto WC-DONE) <= unsigned(a(BITS-1 downto BITS-DONE));
				bc(WC-1 downto WC-DONE) <= unsigned(b(BITS-1 downto BITS-DONE));
				s(BITS-1 downto BITS-DONE) <= std_logic_vector(sc(WC-1 downto WC-DONE));
			end generate genPre;

			-- copy compaction region
			ai(BITS-DONE-1 downto 0) <= a(BITS-DONE-1 downto 0);
			bi(BITS-DONE-1 downto 0) <= b(BITS-DONE-1 downto 0);
			s(BITS-DONE-1 downto 0) <= si(BITS-DONE-1 downto 0);
		end block blkFeed;

		-- Build the compaction tree
		genCompact: for i in 1 to LEVELS'high generate
			constant PAIRS : positive := LEVELS(i-1).core;

			constant BASE : natural := LEVELS(i).base;
			constant CORE : integer := LEVELS(i).core;
			constant DONE : natural := LEVELS(i).done;

			component LUT6_2 is
				generic(
					INIT : bit_vector := X"0000000000000000"
				);
				port(
					O5 : out std_ulogic;
					O6 : out std_ulogic;
					I0 : in  std_ulogic;
					I1 : in  std_ulogic;
					I2 : in  std_ulogic;
					I3 : in  std_ulogic;
					I4 : in  std_ulogic;
					I5 : in  std_ulogic
				);
			end component LUT6_2;

		begin
			genPairs: for j in 0 to PAIRS-1 generate
				signal b1, b0, a1, a0 : std_logic;
				signal ss             : std_logic;
			begin
				-- Compaction ------

				-- Simplify Names
				b1 <= bi(BASE-2*(PAIRS-j)+1);
				b0 <= bi(BASE-2*(PAIRS-j)+0);
				a1 <= ai(BASE-2*(PAIRS-j)+1);
				a0 <= ai(BASE-2*(PAIRS-j)+0);

				genLast: if CORE <= 0 or j < L or L+2*CORE <= j generate
					signal aa, bb : std_logic;
				begin
					aa <= (b1 and a1) or (b1 and a0) or (a1 and a0);
					bb <= (b1 and a1) or (b1 and b0) or (a1 and b0);

					genSuf: if CORE <= 0 or j < L generate
						ac((i-1)*L+j) <= aa;
						bc((i-1)*L+j) <= bb;
						ss <= sc((i-1)*L+j);
					end generate genSuf;
					genPre: if CORE > 0 and L+2*CORE <= j generate
						ac(j-L-2*CORE+(WC-DONE)) <= aa;
						bc(j-L-2*CORE+(WC-DONE)) <= bb;
						ss <= sc(j-L-2*CORE+(WC-DONE));
					end generate genPre;
				end generate genLast;

				genCore: if CORE > 0 and L <= j and j < L+2*CORE generate
					ss <= si(BASE-L+j);

					compact: LUT6_2
						generic map(
							INIT => X"FCC0FCC0FAA0FAA0"
						)
						port map(
							O6 => bi(BASE-L+j),
							O5 => ai(BASE-L+j),
							I5 => '1',
							I4 => '-',
							I3 => b1,
							I2 => a1,
							I1 => b0,
							I0 => a0
						);
				end generate genCore;

				-- Expansion ------
				expand: LUT6_2
					generic map(
						INIT => X"E77E81189FF96006"
					)
					port map(
						O6 => si(BASE-2*(PAIRS-j)+1),
						O5 => si(BASE-2*(PAIRS-j)+0),
						I5 => '1',
						I4 => ss,
						I3 => b1,
						I2 => a1,
						I1 => b0,
						I0 => a0
					);

			end generate genPairs;
		end generate genCompact;
		sc <= ac + bc + (0 to 0 => c);
	end generate genCCA;

end architecture;
