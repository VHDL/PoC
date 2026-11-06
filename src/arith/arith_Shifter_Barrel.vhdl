-- =============================================================================
-- Authors:          Patrick Lehmann
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany,
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

use     work.utils.all;


-- Universal barrel shifter.
--
-- This barrel shifter supports:
--
-- * shifting and rotating
-- * right and left operations
-- * arithmetic and logic mode (only valid for right shift operations)
--
-- This is equivalent to the CPU instructions: SLL, SLA, SRL, SRA, RL, RR
--
-- The shifter is combinational. It consists of one stage per bit of ``ShiftAmount``; stage ``i`` shifts or rotates by
-- ``2**i`` positions if ``ShiftAmount(i)`` is set. Shifts fill vacated positions with ``'0'``, except an arithmetic
-- right shift, which replicates the sign bit ``Input(BITS - 1)``.
entity arith_Shifter_Barrel is
	generic (
		BITS        : positive    := 32  -- Width of ``Input`` and ``Output``.
	);
	port (
		Input           : in  std_logic_vector(BITS - 1 downto 0);              -- Operand.
		ShiftAmount     : in  std_logic_vector(log2ceilnz(BITS) - 1 downto 0);  -- Distance to shift or rotate.
		ShiftRotate     : in  std_logic;                                        -- ``'0'``: shift; ``'1'``: rotate.
		LeftRight       : in  std_logic;                                        -- ``'0'``: left; ``'1'``: right.
		ArithmeticLogic : in  std_logic;                                        -- ``'0'``: arithmetic; ``'1'``: logic.
		Output          : out std_logic_vector(BITS - 1 downto 0)               -- Shifted or rotated ``Input``.
	);
end entity;


architecture rtl of arith_Shifter_Barrel is
	constant STAGES    : positive    := log2ceilnz(BITS);

	subtype  T_INTERMEDIATE_RESULT is std_logic_vector(BITS - 1 downto 0);
	type    T_INTERMEDIATE_VECTOR is array (natural range <>) of T_INTERMEDIATE_RESULT;  -- FIXME: T_SLVV

	signal IntermediateResults  : T_INTERMEDIATE_VECTOR(STAGES downto 0);

begin
	IntermediateResults(0)  <= Input;
	Output                  <= IntermediateResults(STAGES);

	genStage : for i in 0 to STAGES - 1 generate
		process(IntermediateResults(i), ShiftRotate, LeftRight, ArithmeticLogic, ShiftAmount)
		begin
			if (ShiftAmount(i) = '0') then
				IntermediateResults(i + 1) <= IntermediateResults(i);                                                                                            -- NOP
			else
				if (ShiftRotate = '0') then
					if (LeftRight = '0') then
						IntermediateResults(i + 1) <= IntermediateResults(i)((BITS - 2**i - 1) downto 0) & ((2**i - 1) downto 0 => '0');                            -- SLA, SLL
					else
						if (ArithmeticLogic = '0') then
							IntermediateResults(i + 1) <= ((2**i - 1) downto 0 => IntermediateResults(i)(BITS - 1)) & IntermediateResults(i)(BITS - 1 downto 2**i);    -- SRA
						else
							IntermediateResults(i + 1) <= ((2**i - 1) downto 0 => '0') & IntermediateResults(i)(BITS - 1 downto 2**i);                                -- SRL
						end if;
					end if;
				else
					if (LeftRight = '0') then
						IntermediateResults(i + 1) <= IntermediateResults(i)((BITS - 2**i - 1) downto 0) & IntermediateResults(i)(BITS - 1 downto (BITS - 2**i));    -- RL
					else
						IntermediateResults(i + 1) <= IntermediateResults(i)((2**i - 1) downto 0) & IntermediateResults(i)(BITS - 1 downto 2**i);            -- RR
					end if;
				end if;
			end if;
		end process;
	end generate;
end architecture;
