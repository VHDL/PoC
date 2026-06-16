-- =============================================================================
-- Authors:          Thomas B. Preusser
--
-- Entity:          Multi-cycle Non-Performing Restoring Divider
--
-- Description:
-- -------------------------------------
-- Implementation of a Non-Performing restoring divider with a configurable radix.
-- The multi-cycle division is controlled by 'start' / 'rdy'. A new division is
-- started by asserting 'start'. The result Q = A/D is available when 'rdy'
-- returns to '1'. A division by zero is identified by output Z. The Q and R
-- outputs are undefined in this case.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universität Dresden - Germany,
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

entity arith_Divider is
	generic (
		DIVIDEND_BITS      : positive;          -- Dividend Width
		DIVISOR_BITS       : positive;          -- Divisor Width
		RADIX_EXPONENT     : positive := 1;     -- Power of Compute Radix (2**RAPOW)
		PIPELINED          : boolean  := false  -- Computation Pipeline
	);
	port (
		-- Global Reset/Clock
		Clock : in  std_logic;
		Reset : in  std_logic;

		-- Ready / Start
		Start : in  std_logic;
		Ready : out std_logic;

		-- Arguments / Result (2's complement)
		Dividend       : in  std_logic_vector(DIVIDEND_BITS-1 downto 0);
		Divisor        : in  std_logic_vector(DIVISOR_BITS-1 downto 0);
		Quotient       : out std_logic_vector(DIVIDEND_BITS-1 downto 0);
		Remainder      : out std_logic_vector(DIVISOR_BITS-1 downto 0);
		DivisionByZero : out std_logic
	);
end entity arith_Divider;


library IEEE;
use     IEEE.numeric_std.all;

use     work.utils.all;

-------------------------------------------------------------------------------
-- This divider is an implementation by an iterative digit recurrence.
--
-- The basic approach is radix 2 (RAPOW=1). A higher radix power may be
-- specified so as to unroll the corresponding number of elementary radix-2
-- steps into one clock cycle. This cuts the computational latency accordingly.
-- However, the amount of combinational logic does increase and the critical
-- path will eventually be affected.
--
-- A PIPELINED instantiation unrolls all necessary iteration steps in space
-- so that every stage uses its own set of registers. The pipeline can accept a
-- new pair of inputs in every clock cycle.
--
-- Internally, the divider uses two state registers:
--   - DR - the divisor, which remains constant throughout one operation, and
--   - AR holding the actual computation state, which is iteratively tranformed
--     from the initial dividend to the quotient.
-- The active computation is performed on the left end of AR, which represents
-- the relevant prefix of the current residue to be tested against the divisor.
-- The remaining residue is shifted step-by-step into this region. The freed
-- space on the right is immediately re-used for the generated quotient digits.
--
-- The layout transformation of AR (either over time or in space) is as follows:
--
--    |<- D_BITS+RAPOW ->|<- (Digits of A) - 1 ->|
--                    |<-        A_BITS        ->|
--
--    | 00   ...   00 |             A            |
--
--     \-------v-------/
--           P-D ?
--            / \______________________________
--            |                                \
--            v                                 v
--
--    |       P'      |        << A <<        | Q|
--
--
--    |       R       |             Q            |
--
architecture rtl of arith_Divider is

	-- Constants
	constant STEPS       : positive := (DIVIDEND_BITS+RADIX_EXPONENT-1)/RADIX_EXPONENT;   -- Number of Iteration Steps
	constant DEPTH       : natural  := ite(PIPELINED, STEPS, 0);        -- Physical Depth
	constant TRUNK_BITS  : natural  := (STEPS-1)*RADIX_EXPONENT;
	constant ACTIVE_BITS : positive := DIVISOR_BITS + RADIX_EXPONENT;

	-- Private Types
	subtype t_residue is unsigned(ACTIVE_BITS+TRUNK_BITS-1 downto 0);
	subtype t_divisor is unsigned(DIVISOR_BITS-1 downto 0);
	type residue_vector is array(natural range<>) of t_residue;
	type divisor_vector is array(natural range<>) of t_divisor;

	function div_step(av : t_residue; dv : t_divisor) return t_residue is
		variable res : t_residue;
		variable win : unsigned(DIVISOR_BITS-1 downto 0);
		variable dif : unsigned(DIVISOR_BITS downto 0);
	begin
		win := av(av'left downto TRUNK_BITS + RADIX_EXPONENT);
		for i in RADIX_EXPONENT-1 downto 0 loop
			dif := (win & av(TRUNK_BITS+i)) - dv;
			if dif(dif'left) = '0' then
				win := dif(DIVISOR_BITS-1 downto 0);
			else
				win := win(DIVISOR_BITS-2 downto 0) & av(TRUNK_BITS+i);
			end if;
			res(i) := not dif(dif'left);
		end loop;
		res(res'left downto RADIX_EXPONENT) := win & av(TRUNK_BITS-1 downto 0);
		return res;
	end function div_step;

	-- Data Registers
	signal AR : residue_vector(0 to DEPTH) := (others => (others => '-'));
	signal DR : divisor_vector(0 to DEPTH) := (others => (others => '-'));
	signal ZR : std_logic := '-';  -- Zero Detection only in last pipeline stage

	signal exec : std_logic;

begin

	-----------------------------------------------------------------------------
	-- Control
	genPipeN : if not PIPELINED generate
		constant EXEC_BITS : positive                     := log2ceil(STEPS)+1;
		constant EXEC_IDLE : signed(EXEC_BITS-1 downto 0) := '0' & (1 to EXEC_BITS-1 => '-');

		signal CntExec     : signed(EXEC_BITS-1 downto 0) := EXEC_IDLE;
	begin
		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					CntExec <= EXEC_IDLE;
				elsif Start = '1' then
					CntExec <= to_signed(-STEPS, CntExec'length);
				elsif CntExec(CntExec'left) = '1' then
					CntExec <= CntExec + 1;
				end if;
			end if;
		end process;
		exec  <= CntExec(CntExec'left);
		Ready <= not exec;
	end generate genPipeN;

	genPipeY : if PIPELINED generate
		signal Vld : std_logic_vector(0 to STEPS) := (others => '0');
	begin
		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					Vld <= (others => '0');
				else
					Vld <= Start & Vld(0 to STEPS-1);
				end if;
			end if;
		end process;
		Ready <= Vld(STEPS);
	end generate genPipeY;

	-----------------------------------------------------------------------------
	-- Registers
	process(Clock)
		variable an : t_residue;
		variable dn : t_divisor;
	begin
		if rising_edge(Clock) then
			-- Reset
			if Reset = '1' then
				AR <= (others => (others => '-'));
				DR <= (others => (others => '-'));
				ZR <= '-';

			-- Operation Initialization
			else

				an := t_residue'((t_residue'left downto DIVIDEND_BITS => '0') & unsigned(Dividend));
				dn := t_divisor'(unsigned(Divisor));
				for i in 0 to imax(0, DEPTH-1) loop
					AR(i) <= an;
					DR(i) <= dn;
					an := div_step(AR(i), DR(i));
					dn := DR(i);
				end loop;

				if PIPELINED or (Start = '0' and exec = '1') then
					AR(DEPTH) <= an;
					DR(DEPTH) <= dn;
					if Is_X(std_logic_vector(dn)) then
						ZR <= 'X';
					elsif dn = 0 then
						ZR <= '1';
					else
						ZR <= '0';
					end if;
				end if;

			end if;
		end if;
	end process;

	Quotient       <= std_logic_vector(AR(DEPTH)(DIVIDEND_BITS-1 downto 0));
	Remainder      <= std_logic_vector(AR(DEPTH)(STEPS * RADIX_EXPONENT + DIVISOR_BITS-1 downto STEPS * RADIX_EXPONENT));
	DivisionByZero <= ZR;
end architecture;
