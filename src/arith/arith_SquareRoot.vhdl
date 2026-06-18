-- =============================================================================
-- Authors:          Thomas B. Preußer
--
-- Entity:          Iterative Square Root Extractor.
--
-- Description:
-- -------------------------------------
-- Iterative Square Root Extractor.
--
-- Its computation requires (N+1)/2 steps for an argument bit width of N.
--
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universität Dresden - Germany,
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


entity arith_SquareRoot is
	generic (
		BITS : positive -- := 8                   -- Bit Width of Argument
	);
	port (
		-- Global Control
		Reset : in  std_logic;                 -- Reset (synchronous)
		Clock : in  std_logic;                 -- Clock

		-- Inputs
		Operand   : in  std_logic_vector(BITS-1 downto 0);  -- Radicand
		Start : in  std_logic;                       -- Start Strobe

		-- Outputs
		Result : out std_logic_vector((BITS-1)/2 downto 0);  -- Result
		Ready   : out std_logic                              -- Ready / Done
	);
end entity arith_SquareRoot;


architecture rtl of arith_SquareRoot is

	-- Number of Iteration Steps = Number of Result Digits
	constant STEPS : positive := (BITS+1)/2;

	-- Intern Registers
	signal Rmd : unsigned(BITS+STEPS-1 downto 0);      -- Remainder / Result
	signal Vld : unsigned(STEPS-1 downto 0);        -- Result Flags
	signal Res : unsigned(STEPS-1 downto 0);        -- Extracted Result

	-- Tentative Difference
	signal diff : unsigned(STEPS+1 downto 0);

begin  -- rtl

	-- Registers
	process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then

				-- Only clear Ready, everything else: '-'
				Rmd <= (others => '-');
				Vld <= (others => '-');
				Vld(Vld'left) <= '0';

			else

				if Start = '1' then

					-- Initilize Computation
					Rmd <= (Rmd'left downto BITS => '0') & unsigned(Operand);
					Vld <= (others => '1');

				elsif Vld(Vld'left) = '1' then

					-- Computation Step

					-- New Residue
					Rmd(BITS-1 downto 0) <= Rmd(BITS-3 downto 0) & '-' & not diff(diff'left);  -- just shift lower bits
					if diff(diff'left) = '1' then
						-- Sub failed: just shift upper Part
						Rmd(Rmd'left downto BITS) <= Rmd(Rmd'left-2 downto BITS-2);
					else
						-- Sub succeeded: replace by shifted Difference
						Rmd(Rmd'left downto BITS) <= diff(diff'left-2 downto 0);
					end if;

					-- Validate Result Digit
					Vld <= Vld(Vld'left-1 downto 0) & '0';

				end if;

			end if;
		end if;
	end process;

	-- Extract Result
	genRes: for i in Res'range generate
		Res(i) <= Rmd(2*i) and not Vld(i);
	end generate;

	-- Tentative Subtraction: 4*rmd - (4*res+1)
	diff <= Rmd(Rmd'left downto BITS-2) + ('1' & not Res(STEPS-2 downto 0) & "11");

	-- Ouputs
	Result <= std_logic_vector(Res);
	Ready  <= not Vld(Vld'left);

end architecture;
