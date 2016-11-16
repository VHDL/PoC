-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ===========================================================================
-- Testbench:				Binary-serial to parallel BCD converter for integers and
--                  fractions.
--
-- Authors:					Thomas B. Preusser
--
-- Description:
-- ------------
--		Automated testbench for PoC.arith_bcdcollect
--
-- License:
-- ===========================================================================
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
-- =============================================================================

entity arith_bcdcollect_tb is
end;


use std.textio.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

library PoC;
use PoC.utils.all;
use PoC.simulation.all;

architecture tb of arith_bcdcollect_tb is
	component arith_bcdcollect is
		generic (
			BITS     : natural := 0;     -- Maximum Number of Input Bits
																	 --  Zero (0): unspecified
                                   --   -> practical limit by bcd'length
			FRACTION : boolean := false  -- Binary Fractional Input
		);
		port (
			-- Clock
			clk : in std_logic;

			-- Functional Interface
			rst : in  std_logic;-- Reset Value to Zero (0)
			bin : in  std_logic;-- Sequential Binary Input, last digit at binary point:
                          -- Integer Input: MSB first, Fractional Input: LSB first
			ena : in  std_logic;-- Input Enable
			bcd : out t_bcd_vector -- Parallel BCD Output, most-significant digit left
		);
	end component;

	type tDone is array(boolean) of boolean;
	signal done : tDone := (false, false);

begin

	blkInteger: block is
		constant BITS : natural := 30;
		constant TESTS : T_INTVEC := (8723495, 234124, 40134845);

		signal clk : std_logic;
		signal rst : std_logic;
		signal bin : std_logic;
		signal ena : std_logic;
		signal bcd : t_bcd_vector(7 downto 0);
	begin

		dut: arith_bcdcollect
			generic map (
				BITS     => BITS,
				FRACTION => false
			)
			port map (
				clk => clk,
				rst => rst,
				bin => bin,
				ena => ena,
				bcd => bcd
			);

		process
			procedure cycle is
			begin
				clk <= '0';
				wait for 5 ns;
				clk <= '1';
				wait for 5 ns;
			end;

			variable t : integer;
			variable x : unsigned(BITS-1 downto 0);

		begin
			for i in TESTS'range loop
				-- Reset Collector
				rst <= '1';
				cycle;

				-- Feed Binary Input
				rst <= '0';
				ena <= '1';
				t := TESTS(i);
				x := to_unsigned(t, x'length);
				for j in x'range loop
					bin <= x(j);
					cycle;
				end loop;

				-- Check Result
				for j in bcd'reverse_range loop
					tbAssert(to_integer(unsigned(bcd(j))) = (t mod 10), "Integer BCD: Wrong output.");
					t := t / 10;
				end loop;

			end loop;

			done(false) <= true;
			wait;
		end process;

	end block;

	blkFraction: block is
		constant BITS : natural := 15;
		constant TESTS : T_REALVEC := (0.5789, 0.2542, 0.7209);

		signal clk : std_logic;
		signal rst : std_logic;
		signal bin : std_logic;
		signal ena : std_logic;
		signal bcd : t_bcd_vector(1 to 4);
	begin
		dut: arith_bcdcollect
			generic map (
				BITS     => BITS,
				FRACTION => true
			)
			port map (
				clk => clk,
				rst => rst,
				bin => bin,
				ena => ena,
				bcd => bcd
			);

		process
			procedure cycle is
			begin
				clk <= '0';
				wait for 5 ns;
				clk <= '1';
				wait for 5 ns;
			end;

      variable tr, ti : real;
			variable x : std_logic_vector(1 to BITS);
      variable ok     : boolean;
      variable l      : line;

		begin
			for i in TESTS'range loop
				-- Reset Collector
				rst <= '1';
				cycle;

				-- Feed Binary Input
				rst <= '0';
				ena <= '1';
				tr := TESTS(i);
				for j in x'range loop
					tr := 2.0*tr;
					ti := floor(tr);
					tr := tr - ti;
					x(j) := to_sl(ti > 0.5);
				end loop;
				for j in x'reverse_range loop
					bin <= x(j);
					cycle;
				end loop;

				-- Check Result
				tr := TESTS(i);
				ok := true;
				for j in bcd'range loop
					tr := 10.0*tr;
					ti := floor(tr);
					tr := tr - ti;
					if unsigned(bcd(j)) /= to_unsigned(integer(ti), 4) then
						ok := false;
					end if;
				end loop;
				if not ok then
					write(l, '.');
					for j in bcd'range loop
						write(l, to_integer(unsigned(bcd(j))));
					end loop;
					write(l, string'(" for "));
					write(l, TESTS(i));
					tbAssert(ok, l.all);
					deallocate(l);
				end if;
			end loop;

			done(true) <= true;
			wait;
		end process;

		process(done)
		begin
			if done = (true, true) then
				tbPrintResult;
			end if;
		end process;

	end block;

end;
