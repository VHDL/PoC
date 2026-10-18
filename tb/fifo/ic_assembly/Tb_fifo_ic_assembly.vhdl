-- =============================================================================
-- Authors:          Thomas B. Preusser
--                   Stefan Unrein
--
-- Entity:           Tb_fifo_ic_assembly
--
-- Description:
-- -------------------------------------
-- Testbench for fifo_ic_assembly (independent-clock stream assembly FIFO).
-- Writes 3*16*16 = 768 items out-of-order and verifies they are assembled
-- and read back in-order.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
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

library PoC;
use     PoC.utils.all;

library osvvm;
context osvvm.OsvvmContext;

entity Tb_fifo_ic_assembly is
end entity;

architecture tb of Tb_fifo_ic_assembly is
	constant TestName     : string   := "Tb_fifo_ic_assembly";
	constant CLOCK_PERIOD : time     := 10 ns;
	constant TIMEOUT      : time     := 10 ms;

	constant D_BITS : positive := 8;
	constant A_BITS : positive := 8;
	constant G_BITS : positive := 2;

	constant TOTAL_ITEMS : positive := 3 * 16 * 16;   -- 768

	constant SEQ : integer_vector := (1, 0, 2, 3, 5, 4, 7, 6, 8, 10, 9, 12, 11, 13, 15, 14);

	signal Clock  : std_logic;
	signal Reset  : std_logic;

	signal base   : std_logic_vector(A_BITS - 1 downto 0);
	signal failed : std_logic;
	signal addr   : std_logic_vector(A_BITS - 1 downto 0);
	signal din    : std_logic_vector(D_BITS - 1 downto 0);
	signal put    : std_logic;

	signal dout   : std_logic_vector(D_BITS - 1 downto 0);
	signal vld    : std_logic;
	signal got    : std_logic;

	signal TestDone : integer_barrier := 1;

begin

	------------------------------------------------------------
	-- ControlProc
	------------------------------------------------------------
	ControlProc : process
	begin
		SetTestName(TestName);
		SetLogEnable(PASSED, FALSE);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		Log("NOTE: This is a mechanically converted old-style testbench and needs a proper OSVVM port.", INFO);

		WaitForBarrier(TestDone, TIMEOUT);
		AlertIf(now >= TIMEOUT,     "Test timed out");
		AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

		EndOfTestReports;
		std.env.stop;
	end process;

	Osvvm.ClockResetPkg.CreateClock(Clk => Clock, Period => CLOCK_PERIOD);

	Reset <= '0';   -- fifo_ic_assembly uses separate clk_wr/rst_wr/clk_rd/rst_rd

	DUT : entity PoC.fifo_ic_assembly
		generic map (
			D_BITS => D_BITS,
			A_BITS => A_BITS,
			G_BITS => G_BITS
		)
		port map (
			clk_wr => Clock,
			rst_wr => Reset,
			base   => base,
			failed => failed,
			addr   => addr,
			din    => din,
			put    => put,
			clk_rd => Clock,
			rst_rd => Reset,
			dout   => dout,
			vld    => vld,
			got    => got
		);

	------------------------------------------------------------
	-- Writer: writes items out-of-order per SEQ permutation
	------------------------------------------------------------
	procWriter : process
		variable t : integer;
	begin
		put <= '0';
		wait until base = (base'range => '0');

		for k in 0 to 2 loop
			for i in SEQ'range loop
				for j in 0 to 15 loop
					t := 16 * SEQ(i) + j;
					-- Wait until the assembly window covers address t
					while ((t - to_integer(unsigned(base))) mod 2**A_BITS) / (2**(A_BITS - G_BITS)) /= 0 loop
						wait on base;
					end loop;
					put  <= '1';
					addr <= std_logic_vector(to_unsigned(t, addr'length));
					din  <= not std_logic_vector(to_unsigned(t, din'length));
					wait until rising_edge(Clock);
					put <= '0';
				end loop;

				for j in 0 to i / 2 loop
					wait until rising_edge(Clock);
				end loop;
			end loop;
		end loop;

		wait;
	end process;

	------------------------------------------------------------
	-- Reader / checker: reads TOTAL_ITEMS items in order
	------------------------------------------------------------
	procReader : process
		variable i   : integer := 0;
		variable del : integer := 0;
	begin
		for i in 0 to TOTAL_ITEMS - 1 loop
			got <= '1';
			wait until rising_edge(Clock) and vld = '1';
			AffirmIf(unsigned(not dout) = i mod 2**dout'length,
				"Unexpected output @ item " & integer'image(i) &
				": got "      & integer'image(to_integer(unsigned(dout))) &
				" expected "  & integer'image(2**dout'length - 1 - (i mod 2**dout'length)));
			got <= '0';
			for j in 0 to i / dout'length loop
				wait until rising_edge(Clock);
			end loop;
		end loop;

		WaitForBarrier(TestDone);
		wait;
	end process;

end architecture;
