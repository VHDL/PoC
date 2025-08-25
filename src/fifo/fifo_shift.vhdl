-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Stefan Unrein
--
-- Entity:          FIFO, common clock, pipelined interface
--
-- Description:
-- -------------------------------------
-- This FIFO implementation is based on an internal shift register. This is
-- especially useful for smaller FIFO sizes, which can be implemented in LUT
-- storage on some devices (e.g. Xilinx' SRLs). Only a single read pointer is
-- maintained, which determines the number of valid entries within the
-- underlying shift register.
--
-- The specified depth (``MIN_DEPTH``) is rounded up to the next suitable value.
--
-- License:
-- =============================================================================
-- Copyright 2015-2025 The PoC-Library Authors
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;


entity fifo_shift is
	generic (
		D_BITS    : positive;               -- Data Width
		MIN_DEPTH : positive                -- Minimum FIFO Size in Words
	);
	port (
		-- Global Control
		clk  : in  std_logic;
		rst  : in  std_logic;
		fill : out std_logic_vector(log2ceilnz(MIN_DEPTH) downto 0); -- Fill'left = Empty, Fill'left = no vld
		                                                             -- If vld='1' then fill(fill'left -1 downto 0) +1 is the number of Words saved

		-- Writing Interface
		put  : in  std_logic;                            -- Write Request
		din  : in  std_logic_vector(D_BITS-1 downto 0);  -- Input Data
		ful  : out std_logic;                            -- Capacity Exhausted

		-- Reading Interface
		got  : in  std_logic;                            -- Read Done Strobe
		dout : out std_logic_vector(D_BITS-1 downto 0);  -- Output Data
		vld  : out std_logic                             -- Data Valid
	);
end entity fifo_shift;

architecture rtl of fifo_shift is
	constant A_BITS : positive := log2ceilnz(MIN_DEPTH);
	constant DEPTH  : positive := 2**A_BITS;

	-- Data Register
	type tData is array(natural range<>) of std_logic_vector(D_BITS-1 downto 0);
	signal Dat : tData(0 to DEPTH-1);
	signal Ptr   : unsigned(A_BITS downto 0) := (others => '1');

	signal ful_i : std_logic;
	signal vld_i : std_logic;

begin

	-- Data anf Pointer Registers
	process(clk)
	begin
		if rising_edge(clk) then
			if (put and not ful_i) = '1' then
				Dat <= din & Dat(0 to DEPTH-2);
			end if;
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				Ptr <= (others => '1');
			else
				if (put and not ful_i) /= (got and vld_i) then
					if (put and not ful_i) = '1' then
						Ptr <= Ptr + 1;
					else
						Ptr <= Ptr - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- Outputs
	dout   <= Dat(to_integer(Ptr(Ptr'left-1 downto 0)));
	vld_i  <= not Ptr(Ptr'left);
	ful_i  <= vld_i when (Ptr(Ptr'left-1 downto 0) and to_unsigned(DEPTH-1, Ptr'length-1)) = DEPTH-1 else '0';
	vld    <= vld_i;
	ful    <= ful_i;
	fill   <= std_logic_vector(Ptr);

end rtl;
