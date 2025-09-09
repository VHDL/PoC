-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:  Thomas B. Preusser
--           Martin Zabel
--           Patrick Lehmann
--
-- Package:  VHDL package for component declarations, types and functions
--           associated to the PoC.arith namespace
--
-- Description:
-- -------------------------------------
--    For detailed documentation see below.
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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


package arith is
	function arith_prbs_lfsr (value : std_logic_vector) return std_logic_vector;

	component arith_firstone is
		generic (
			N : positive                                      -- Length of Token Chain
		);
		port (
			tin  : in  std_logic := '1';                        -- Enable:    Fed Token
			rqst : in  std_logic_vector(N-1 downto 0);            -- Request:    Token Requests
			grnt : out std_logic_vector(N-1 downto 0);            -- Grant:      Token Output
			tout : out std_logic;                                 -- Inactive:  Unused Token
			bin  : out std_logic_vector(log2ceil(N)-1 downto 0)  -- Binary Grant Index
		);
	end component;

	component arith_counter_bcd is
		generic (
			DIGITS  : positive
		);
		port (
			clk : in  std_logic;
			rst : in  std_logic;
			inc : in  std_logic;
			val : out T_BCD_VECTOR(DIGITS-1 downto 0));
	end component;

	component arith_counter_gray is
		generic (
			BITS  : positive;                -- Bit width of the counter
			INIT  : natural          := 0    -- Initial/reset counter value
		);
		port (
			clk    : in  std_logic;
			rst    : in  std_logic;                          -- Reset to INIT value
			inc    : in  std_logic;                          -- Increment
			dec    : in  std_logic    := '0';                  -- Decrement
			val    : out std_logic_vector(BITS-1 downto 0);  -- Value output
			cry    : out std_logic                            -- Carry output
		);
	end component;

	-- This function computes the latency of the sequential divider, both for the
	-- pipelined and the regular sequential implementation. The returned value
	-- specifies the number of cycles it takes after asserting start for the
	-- result to become ready.
	function arith_div_latency(a_bits, rapow : positive) return positive;

	component arith_div
		generic (
			A_BITS             : positive;          -- Dividend Width
			D_BITS             : positive;          -- Divisor Width
			RAPOW              : positive := 1;     -- Power of Compute Radix (2**RAPOW)
			PIPELINED          : boolean  := false  -- Computation Pipeline
		);
		port (
			-- Global Reset/Clock
			clk : in std_logic;
			rst : in std_logic;

			-- Ready / Start
			start : in  std_logic;
			ready : out std_logic;

			-- Arguments / Result (2's complement)
			A : in  std_logic_vector(A_BITS-1 downto 0);  -- Dividend
			D : in  std_logic_vector(D_BITS-1 downto 0);  -- Divisor
			Q : out std_logic_vector(A_BITS-1 downto 0);  -- Quotient
			R : out std_logic_vector(D_BITS-1 downto 0);  -- Remainder
			Z : out std_logic  -- Division by Zero
		);
	end component;

	component arith_prng
		generic (
			BITS    : positive;
			SEED    : std_logic_vector := "0"
		);
		port (
			Clock    : in  std_logic;
			Reset    : in  std_logic; -- reset value to seed

			InitialValue : in std_logic_vector := SEED; -- Is loaded when Reset = '1'
			Got          : in std_logic; -- the current value has been got, and a new value should be calculated
			Value        : out std_logic_vector(BITS - 1 downto 0) -- the pseudo-random number
		);
	end component;

	component arith_trng is
		generic (
			BITS : positive   -- Width: Number of Oscillators
		);
		port (
			clk : in  std_logic;                         -- Clock
			rnd : out std_logic_vector(BITS-1 downto 0)  -- Random Oscillator Samples
		);
	end component;

	-- component arith_muls_wide
	-- 	generic (
	-- 		NA    : integer range 2 to 18;
	-- 		NB    : integer range 19 to 36;
	-- 		SPLIT  : positive
	-- 	);
	-- 	port (
	-- 		a      : in  signed(NA-1 downto 0);
	-- 		b      : in  signed(NB-1 downto 0);
	-- 		p      : out signed(NA+NB-1 downto 0)
	-- 	);
	-- end component;

	component arith_sqrt
		generic (
			N    : positive
		);
		port (
			rst      : in  std_logic;
			clk      : in  std_logic;
			arg      : in  std_logic_vector(N-1 downto 0);
			start    : in  std_logic;
			sqrt    : out std_logic_vector((N-1)/2 downto 0);
			rdy      : out std_logic
		);
	end component;

	type tArch     is (AAM, CAI, CCA, PAI);
	type tBlocking is (DFLT, FIX, ASC, DESC);
	type tSkipping is (PLAIN, CCC, PPN_KS, PPN_BK);

	component arith_addw is
		generic (
			N            : positive;            -- Operand Width
			K            : positive;            -- Block Count

			ARCH        : tArch      := AAM;    -- Architecture
			BLOCKING    : tBlocking  := DFLT;  -- Blocking Scheme
			SKIPPING    : tSkipping  := CCC;    -- Carry Skip Scheme
			P_INCLUSIVE  : boolean    := false  -- Use Inclusive Propagate, i.e. c^1
		);
		port (
			a, b  : in std_logic_vector(N-1 downto 0);
			cin    : in std_logic;

			s      : out std_logic_vector(N-1 downto 0);
			cout  : out std_logic
		);
	end component;

	component arith_same is
		generic (
			N    : positive                            -- Input width
		);
		port (
			g    : in  std_logic    := '1';              -- Guard Input (!g => !y)
			x    : in  std_logic_vector(N-1 downto 0);  -- Input Vector
			y    : out std_logic                        -- All-same Output
		);
	end component;

	component arith_carrychain_inc_xilinx is
		generic (
			BITS      : positive
		);
		port (
			X    : in  std_logic_vector(BITS - 1 downto 0);
			CIn  : in  std_logic                              := '1';
			Y    : out std_logic_vector(BITS - 1 downto 0)
		);
	end component;

	component arith_prefix_and_xilinx is
		generic (
			N : positive
		);
		port (
			x : in  std_logic_vector(N-1 downto 0);
			y : out std_logic_vector(N-1 downto 0)
		);
	end component;

	component arith_prefix_or_xilinx is
		generic (
			N : positive
		);
		port (
			x : in  std_logic_vector(N-1 downto 0);
			y : out std_logic_vector(N-1 downto 0)
		);
	end component;

	component arith_inc_ovcy_xilinx is
		generic (
			N    : positive                             -- Bit Width
		);
		port (
			p    : in  std_logic_vector(N-1 downto 0);  -- Argument
			g    : in  std_logic;                      -- Increment Guard
			v    : out std_logic                        -- Overflow Output
		);
	end component;
end package;

package body arith is
	function arith_div_latency(a_bits, rapow : positive) return positive is
	begin
		return (a_bits+rapow-1)/rapow;
	end;

	function arith_prbs_lfsr (value : std_logic_vector) return std_logic_vector is
		subtype T_TAPPOSITION     is T_NATVEC(0 to 4);
		type T_TAPPOSITION_VECTOR is array (natural range <>) of T_TAPPOSITION;

		-- Tap positions are taken from Xilinx Application Note 052 (XAPP052)
		constant C_TAPPOSITION_LIST : T_TAPPOSITION_VECTOR(3 to 168) := (
			3   => (0 => 2,                       others => 0),
			4   => (0 => 3,                       others => 0),
			5   => (0 => 3,                       others => 0),
			6   => (0 => 5,                       others => 0),
			7   => (0 => 6,                       others => 0),
			8   => (0 => 6, 1 => 5, 2 => 4,       others => 0),
			9   => (0 => 5,                       others => 0),
			10  => (0 => 7,                       others => 0),
			11  => (0 => 9,                       others => 0),
			12  => (0 => 6, 1 => 4, 2 => 1,       others => 0),
			13  => (0 => 4, 1 => 3, 2 => 1,       others => 0),
			14  => (0 => 5, 1 => 3, 2 => 1,       others => 0),
			15  => (0 => 14,                      others => 0),
			16  => (0 => 15, 1 => 13, 2 => 4,     others => 0),
			17  => (0 => 14,                      others => 0),
			18  => (0 => 11,                      others => 0),
			19  => (0 => 6, 1 => 2, 2 => 1,       others => 0),
			20  => (0 => 17,                      others => 0),
			21  => (0 => 19,                      others => 0),
			22  => (0 => 21,                      others => 0),
			23  => (0 => 18,                      others => 0),
			24  => (0 => 23, 1 => 22, 2 => 17,    others => 0),
			25  => (0 => 22,                      others => 0),
			26  => (0 => 6, 1 => 2, 2 => 1,       others => 0),
			27  => (0 => 5, 1 => 2, 2 => 1,       others => 0),
			28  => (0 => 25,                      others => 0),
			29  => (0 => 27,                      others => 0),
			30  => (0 => 6, 1 => 4, 2 => 1,       others => 0),
			31  => (0 => 28,                      others => 0),
			32  => (0 => 22, 1 => 2, 2 => 1,      others => 0),
			33  => (0 => 2,                       others => 0),
			34  => (0 => 27, 1 => 2, 2 => 1,      others => 0),
			35  => (0 => 33,                      others => 0),
			36  => (0 => 25,                      others => 0),
			37  => (0 => 5, 1 => 4, 2 => 3, 3 => 2, 4 => 1),
			38  => (0 => 6, 1 => 5, 2 => 1,       others => 0),
			39  => (0 => 35,                      others => 0),
			40  => (0 => 38, 1 => 21, 2 => 19,    others => 0),
			41  => (0 => 38,                      others => 0),
			42  => (0 => 41, 1 => 20, 2 => 19,    others => 0),
			43  => (0 => 42, 1 => 38, 2 => 37,    others => 0),
			44  => (0 => 43, 1 => 18, 2 => 17,    others => 0),
			45  => (0 => 44, 1 => 42, 2 => 41,    others => 0),
			46  => (0 => 45, 1 => 26, 2 => 25,    others => 0),
			47  => (0 => 42,                      others => 0),
			48  => (0 => 47, 1 => 21, 2 => 20,    others => 0),
			49  => (0 => 4,                       others => 0),
			50  => (0 => 49, 1 => 24, 2 => 23,    others => 0),
			51  => (0 => 50, 1 => 36, 2 => 35,    others => 0),
			52  => (0 => 49,                      others => 0),
			53  => (0 => 52, 1 => 38, 2 => 37,    others => 0),
			54  => (0 => 53, 1 => 18, 2 => 17,    others => 0),
			55  => (0 => 31,                      others => 0),
			56  => (0 => 55, 1 => 35, 2 => 34,    others => 0),
			57  => (0 => 5,                       others => 0),
			58  => (0 => 39,                      others => 0),
			59  => (0 => 58, 1 => 38, 2 => 37,    others => 0),
			60  => (0 => 59,                      others => 0),
			61  => (0 => 60, 1 => 46, 2 => 45,    others => 0),
			62  => (0 => 61, 1 => 6, 2 => 5,      others => 0),
			63  => (0 => 62,                      others => 0),
			64  => (0 => 63, 1 => 61, 2 => 60,    others => 0),
			65  => (0 => 47,                      others => 0),
			66  => (0 => 65, 1 => 57, 2 => 56,    others => 0),
			67  => (0 => 66, 1 => 58, 2 => 57,    others => 0),
			68  => (0 => 59,                      others => 0),
			69  => (0 => 67, 1 => 42, 2 => 40,    others => 0),
			70  => (0 => 69, 1 => 55, 2 => 54,    others => 0),
			71  => (0 => 65,                      others => 0),
			72  => (0 => 66, 1 => 25, 2 => 19,    others => 0),
			73  => (0 => 48,                      others => 0),
			74  => (0 => 73, 1 => 59, 2 => 58,    others => 0),
			75  => (0 => 74, 1 => 65, 2 => 64,    others => 0),
			76  => (0 => 75, 1 => 41, 2 => 40,    others => 0),
			77  => (0 => 76, 1 => 47, 2 => 46,    others => 0),
			78  => (0 => 77, 1 => 59, 2 => 58,    others => 0),
			79  => (0 => 7,                       others => 0),
			80  => (0 => 79, 1 => 43, 2 => 42,    others => 0),
			81  => (0 => 77,                      others => 0),
			82  => (0 => 79, 1 => 47, 2 => 44,    others => 0),
			83  => (0 => 82, 1 => 38, 2 => 37,    others => 0),
			84  => (0 => 71,                      others => 0),
			85  => (0 => 84, 1 => 58, 2 => 57,    others => 0),
			86  => (0 => 85, 1 => 74, 2 => 73,    others => 0),
			87  => (0 => 74,                      others => 0),
			88  => (0 => 87, 1 => 17, 2 => 16,    others => 0),
			89  => (0 => 51,                      others => 0),
			90  => (0 => 89, 1 => 72, 2 => 71,    others => 0),
			91  => (0 => 90, 1 => 8, 2 => 7,      others => 0),
			92  => (0 => 91, 1 => 80, 2 => 79,    others => 0),
			93  => (0 => 91,                      others => 0),
			94  => (0 => 73,                      others => 0),
			95  => (0 => 84,                      others => 0),
			96  => (0 => 94, 1 => 49, 2 => 47,    others => 0),
			97  => (0 => 91,                      others => 0),
			98  => (0 => 87,                      others => 0),
			99  => (0 => 97, 1 => 54, 2 => 52,    others => 0),
			100 => (0 => 63,                      others => 0),
			101 => (0 => 100, 1 => 95, 2 => 94,   others => 0),
			102 => (0 => 101, 1 => 36, 2 => 35,   others => 0),
			103 => (0 => 94,                      others => 0),
			104 => (0 => 103, 1 => 94, 2 => 93,   others => 0),
			105 => (0 => 89,                      others => 0),
			106 => (0 => 91,                      others => 0),
			107 => (0 => 105, 1 => 44, 2 => 42,   others => 0),
			108 => (0 => 77,                      others => 0),
			109 => (0 => 108, 1 => 103, 2 => 102, others => 0),
			110 => (0 => 109, 1 => 98, 2 => 97,   others => 0),
			111 => (0 => 101,                     others => 0),
			112 => (0 => 110, 1 => 69, 2 => 67,   others => 0),
			113 => (0 => 104,                     others => 0),
			114 => (0 => 113, 1 => 33, 2 => 32,   others => 0),
			115 => (0 => 114, 1 => 101, 2 => 100, others => 0),
			116 => (0 => 115, 1 => 46, 2 => 45,   others => 0),
			117 => (0 => 115, 1 => 99, 2 => 97,   others => 0),
			118 => (0 => 85,                      others => 0),
			119 => (0 => 111,                     others => 0),
			120 => (0 => 113, 1 => 9, 2 => 2,     others => 0),
			121 => (0 => 103,                     others => 0),
			122 => (0 => 121, 1 => 63, 2 => 62,   others => 0),
			123 => (0 => 121,                     others => 0),
			124 => (0 => 87,                      others => 0),
			125 => (0 => 124, 1 => 18, 2 => 17,   others => 0),
			126 => (0 => 125, 1 => 90, 2 => 89,   others => 0),
			127 => (0 => 126,                     others => 0),
			128 => (0 => 126, 1 => 101, 2 => 99,  others => 0),
			129 => (0 => 124,                     others => 0),
			130 => (0 => 127,                     others => 0),
			131 => (0 => 130, 1 => 84, 2 => 83,   others => 0),
			132 => (0 => 103,                     others => 0),
			133 => (0 => 132, 1 => 82, 2 => 81,   others => 0),
			134 => (0 => 77,                      others => 0),
			135 => (0 => 124,                     others => 0),
			136 => (0 => 135, 1 => 11, 2 => 10,   others => 0),
			137 => (0 => 116,                     others => 0),
			138 => (0 => 137, 1 => 131, 2 => 130, others => 0),
			139 => (0 => 136, 1 => 134, 2 => 131, others => 0),
			140 => (0 => 111,                     others => 0),
			141 => (0 => 140, 1 => 110, 2 => 109, others => 0),
			142 => (0 => 121,                     others => 0),
			143 => (0 => 142, 1 => 123, 2 => 122, others => 0),
			144 => (0 => 143, 1 => 75, 2 => 74,   others => 0),
			145 => (0 => 93,                      others => 0),
			146 => (0 => 145, 1 => 87, 2 => 86,   others => 0),
			147 => (0 => 146, 1 => 110, 2 => 109, others => 0),
			148 => (0 => 121,                     others => 0),
			149 => (0 => 148, 1 => 40, 2 => 39,   others => 0),
			150 => (0 => 97,                      others => 0),
			151 => (0 => 148,                     others => 0),
			152 => (0 => 151, 1 => 87, 2 => 86,   others => 0),
			153 => (0 => 152,                     others => 0),
			154 => (0 => 152, 1 => 27, 2 => 25,   others => 0),
			155 => (0 => 154, 1 => 124, 2 => 123, others => 0),
			156 => (0 => 155, 1 => 41, 2 => 40,   others => 0),
			157 => (0 => 156, 1 => 131, 2 => 130, others => 0),
			158 => (0 => 157, 1 => 132, 2 => 131, others => 0),
			159 => (0 => 128,                     others => 0),
			160 => (0 => 159, 1 => 142, 2 => 141, others => 0),
			161 => (0 => 143,                     others => 0),
			162 => (0 => 161, 1 => 75, 2 => 74,   others => 0),
			163 => (0 => 162, 1 => 104, 2 => 103, others => 0),
			164 => (0 => 163, 1 => 151, 2 => 150, others => 0),
			165 => (0 => 164, 1 => 135, 2 => 134, others => 0),
			166 => (0 => 165, 1 => 128, 2 => 127, others => 0),
			167 => (0 => 161,                     others => 0),
			168 => (0 => 166, 1 => 153, 2 => 151, others => 0)
		);

		constant BITS           : natural       := value'length;
		constant C_TAPPOSITIONS : T_TAPPOSITION := C_TAPPOSITION_LIST(BITS);

		variable temp : std_logic;
	begin
		assert ((3 <= BITS) and (BITS <= 168)) report "Width not yet supported." severity failure;

		temp := value(BITS - 1);

		for i in 0 to 4 loop
			if C_TAPPOSITIONS(i) > 0 then
				temp := temp xnor value(C_TAPPOSITIONS(i) - 1); -- the "- 1" is necessary, because the Tappositions only work for vectors which begin at index 1
			end if;
		end loop;

		return value(BITS - 2 downto 0) & temp;
	end;
end package body arith;
