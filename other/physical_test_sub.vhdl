-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
--
-- Module:					Sub-module for physical_test.
--
--
-- Description:
-- ------------------------------------
-- Synthesis reports a multiple driver error/critical warning when the test
-- below fails.
--
-- The values to check are defined via generics to allow debugging within Vivado
-- because Vivado does not support the `report` statement during synthesis.
-- Instead, it prints the assigned values in the synthesis report.
-- But, ISE does not print them in the synthesis report by default, thus a
-- `report` statement is required.
-- Quartus, reports them both ways.
--
-- License:
-- ============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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

library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.physical.all;
use poc.utils.all;

entity physical_test_sub is

  generic (
    CLOCK_FREQ   	: freq;
    DELAY_TIME   	: time;
    CLOCK_PERIOD 	: time;
    STEPS				 	: integer;
    EXPECT_STEPS 	: integer);

	port (
		clk : in	std_logic;
		d		: in	std_logic;
		q		: out std_logic);

end entity physical_test_sub;

architecture rtl of physical_test_sub is
	function f return boolean is
	begin
		report "CLOCK_FREQ   = " & FREQ'image(CLOCK_FREQ  ) severity note;
		report "DELAY_TIME   = " & time'image(DELAY_TIME  ) severity note;
		report "CLOCK_PERIOD = " & time'image(CLOCK_PERIOD) severity note;
		report "STEPS        = " & integer'image(STEPS       ) severity note;
		report "EXPECT_STEPS = " & integer'image(EXPECT_STEPS) severity note;
	return true;
	end f;

	constant C : boolean := f;

	-- prevent of generating to much flip-flops
	signal reg : std_logic_vector(imin(1000, STEPS)-1 downto 0);

begin  -- architecture rtl

	reg <= reg(reg'left-1 downto 0) & d when rising_edge(clk);

	-- This should be the only one assignment of output q.
	q	<= reg(reg'left);

	gError: if STEPS /= EXPECT_STEPS generate
		-- Several variants have been tried, but Vivado issues only a critical
		-- warning instead of an error.
		q <= d;
	end generate;
end architecture rtl;
