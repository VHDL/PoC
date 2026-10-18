-- ============================================================================
-- Authors:     Jens Voss
--
-- Entity:      Tb_dstruct_Stack
--
-- Description:
-- ------------
--   Testbench for dstruct_Stack. Converted to OSVVM style.
--
-- License:
-- ============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
-- ============================================================================

entity Tb_dstruct_Stack is
end entity;


library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.dstruct.all;

library osvvm;
context osvvm.OsvvmContext;

architecture tb of Tb_dstruct_Stack is

	constant MIN_DEPTH  : positive := 8;
	constant D_BITS     : positive := 16;
	constant CLK_PERIOD : time     := 20 ns;

	signal clk   : std_logic;
	signal rst   : std_logic;
	signal din   : std_logic_vector(D_BITS-1 downto 0);
	signal put   : std_logic;
	signal got   : std_logic;
	signal dout  : std_logic_vector(D_BITS-1 downto 0);
	signal full  : std_logic;
	signal valid : std_logic;

	signal TestDone : integer_barrier := 1;

begin

	Osvvm.ClockResetPkg.CreateClock(Clk => clk, Period => CLK_PERIOD);

	DUT : entity PoC.dstruct_Stack
		generic map (
			DATA_BITS => D_BITS,
			MIN_DEPTH => MIN_DEPTH
		)
		port map (
			Clock   => clk,
			Reset   => rst,
			Put     => put,
			DataIn  => din,
			Full    => full,
			Got     => got,
			DataOut => dout,
			Valid   => valid
		);

	process
		procedure checkTOS(constant EXPECT : in integer) is
		begin
			AffirmIf(to_integer(unsigned(dout)) = EXPECT,
				"Wrong top of stack: " & integer'image(to_integer(unsigned(dout))) &
				" instead of " & integer'image(EXPECT));
		end procedure checkTOS;

		variable high : integer;
	begin

		-- Reset Sequence
		rst <= '1';
		wait until rising_edge(clk);
		rst <= '0';
		put <= '0';
		got <= '0';
		wait until falling_edge(clk);
		AffirmIf(valid = '0', "valid != 0!");
		AffirmIf(full = '0', "full != 0!");

		-- Fill stack with data
		put <= '1';
		din <= (others => '0');
		while full = '0' loop
			wait until falling_edge(clk);
			AffirmIf(valid = '1', "valid != 1!");
			din <= std_logic_vector(unsigned(din)+1);
		end loop;
		high := to_integer(unsigned(din));

		-- One more, which should not be accepted
		din <= (others => 'X');
		wait until falling_edge(clk);
		put <= '0';
		AffirmIf(valid = '1', "valid != 1!");
		AffirmIf(full = '1', "full != 1!");

		-- Idle
		wait until falling_edge(clk);
		checkTOS(high);

		-- Pop two (2) elements
		got <= '1';

		wait until falling_edge(clk);
		high := high - 1;
		AffirmIf(full = '0', "full != 0");
		AffirmIf(valid = '1', "valid != 1");
		checkTOS(high);

		wait until falling_edge(clk);
		high := high - 1;
		AffirmIf(full = '0', "full != 0");
		AffirmIf(valid = '1', "valid != 1");
		checkTOS(high);

		got <= '0';

		-- Push two (2) zeroes
		din <= (others => '0');
		put <= '1';
		wait until falling_edge(clk);
		AffirmIf(full = '0', "full != 0");
		AffirmIf(valid = '1', "valid != 1");
		wait until falling_edge(clk);
		AffirmIf(full = '1', "full != 1");
		AffirmIf(valid = '1', "valid != 1");

		-- One more, which should not be accepted
		din <= (others => 'X');
		wait until falling_edge(clk);
		put <= '0';

		-- Pop two (2) zeroes
		got <= '1';

		AffirmIf(valid = '1', "valid != 1!");
		AffirmIf(full = '1', "full != 1!");
		checkTOS(0);
		wait until falling_edge(clk);

		AffirmIf(valid = '1', "valid != 1");
		AffirmIf(full = '0', "full != 0");
		checkTOS(0);
		wait until falling_edge(clk);

		-- Drain whole stack
		while valid = '1' loop
			AffirmIf(full = '0', "full != 0");
			checkTOS(high);
			wait until falling_edge(clk);
			high := high - 1;
		end loop;
		AffirmIf(high = -1, "Failed to drain stack.");
		got <= '0';

		WaitForBarrier(TestDone);
		wait;
	end process;

	ControlProc : process
	begin
		SetTestName("Tb_dstruct_Stack");
		SetLogEnable(PASSED, FALSE);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		Log("NOTE: This is a mechanically converted old-style testbench and needs a proper OSVVM port.", INFO);
		wait until rst = '0';
		ClearAlerts;
		WaitForBarrier(TestDone, 100 ms);
		AlertIf(now >= 100 ms, "Test timed out");
		AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");
		EndOfTestReports;
		std.env.stop;
	end process;

end architecture tb;
