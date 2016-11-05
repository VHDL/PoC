-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:         Martin Zabel
--
-- Testbench:       Testbench for cache_mem.
--
-- Description:
-- ------------------------------------
-- Test cache_mem using two memories. One connected behind the cache, and one
-- directly attached to the stimuli generator. The checker compares the
-- result of read requests to the cache with the result from the direct
-- attached memory.
--
-- Stimuli / Checker  ---+--- Cache ---- 1st memory
--                       |
--                       +--- 2nd memory
--
-- License:
-- ============================================================================
-- Copyright 2016-2016 Technische Universitaet Dresden - Germany,
--										 Chair for VLSI-Design, Diagnostics and Architecture
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
use ieee.numeric_std.all;

library poc;
use poc.physical.all;
-- simulation only packages
use poc.sim_types.all;
use poc.simulation.all;
use poc.waveform.all;

entity cache_mem_tb is
end entity cache_mem_tb;

architecture sim of cache_mem_tb is
	constant CLOCK_FREQ : FREQ := 100 MHz;

	-- Cache / Memory configuration
  constant REPLACEMENT_POLICY : string   := "LRU";
  constant CACHE_LINES        : positive := 32;
  constant ASSOCIATIVITY      : positive := 4;
  constant ADDR_BITS          : positive := 6;
  constant BYTE_ADDR_BITS     : natural  := 0;
  constant DATA_BITS          : positive := 8;

	-- Global signals
  signal clk : std_logic := '1';
  signal rst : std_logic;

	-- Bus between Stimuli / Checker and Cache
	-- Request signals are shared with 2nd Memory, issue request only if Cache is
	-- ready. The 2nd memory is always ready after reset.
  signal cache_req   : std_logic;
  signal cache_write : std_logic;
  signal cache_addr  : unsigned(ADDR_BITS-1 downto BYTE_ADDR_BITS);
  signal cache_wdata : std_logic_vector(DATA_BITS-1 downto 0);
  signal cache_rdy   : std_logic;
  signal cache_rstb  : std_logic;
  signal cache_rdata : std_logic_vector(DATA_BITS-1 downto 0);

	-- Bus between Cache and 1st Memory
  signal mem1_req   : std_logic;
  signal mem1_write : std_logic;
  signal mem1_addr  : unsigned(ADDR_BITS-1 downto BYTE_ADDR_BITS);
  signal mem1_wdata : std_logic_vector(DATA_BITS-1 downto 0);
  signal mem1_rdy   : std_logic;
  signal mem1_rstb  : std_logic;
  signal mem1_rdata : std_logic_vector(DATA_BITS-1 downto 0);

	-- Bus between Stimuli / Checker and 2nd Memory
	-- Request signals are shared with CPU side of Cache.
  signal mem2_rdy   : std_logic;
  signal mem2_rstb  : std_logic;
  signal mem2_rdata : std_logic_vector(DATA_BITS-1 downto 0);

	-- Write-Data Generator
	signal wdata_got : std_logic;
	signal wdata_val : std_logic_vector(DATA_BITS-1 downto 0);

	-- Control signals between Stimuli and Checker
	signal finished : boolean := false;

begin
	-- initialize global simulation status
	simInitialize;
	-- generate global testbench clock
	simGenerateClock(clk, CLOCK_FREQ);

	-- The Cache
	cache_inst: entity poc.cache_mem
    generic map (
      REPLACEMENT_POLICY => REPLACEMENT_POLICY,
      CACHE_LINES        => CACHE_LINES,
      ASSOCIATIVITY      => ASSOCIATIVITY,
      ADDR_BITS          => ADDR_BITS,
      BYTE_ADDR_BITS     => BYTE_ADDR_BITS,
      DATA_BITS          => DATA_BITS)
    port map (
      clk       => clk,
      rst       => rst,
      cpu_req   => cache_req,
      cpu_write => cache_write,
      cpu_addr  => cache_addr,
      cpu_wdata => cache_wdata,
      cpu_rdy   => cache_rdy,
      cpu_rstb  => cache_rstb,
      cpu_rdata => cache_rdata,
      mem_req   => mem1_req,
      mem_write => mem1_write,
      mem_addr  => mem1_addr,
      mem_wdata => mem1_wdata,
      mem_rdy   => mem1_rdy,
      mem_rstb  => mem1_rstb,
      mem_rdata => mem1_rdata);

	-- The 1st Memory
	memory1: entity work.mem_model
		generic map (
			A_BITS	=> ADDR_BITS-BYTE_ADDR_BITS,
			D_BITS	=> DATA_BITS)
		port map (
			clk       => clk,
			rst       => rst,
			mem_req   => mem1_req,
			mem_write => mem1_write,
			mem_addr  => mem1_addr,
			mem_wdata => mem1_wdata,
			mem_rdy   => mem1_rdy,
			mem_rstb  => mem1_rstb,
			mem_rdata => mem1_rdata);

	-- The 2nd Memory
	memory2: entity work.mem_model
		generic map (
			A_BITS	=> ADDR_BITS-BYTE_ADDR_BITS,
			D_BITS	=> DATA_BITS)
		port map (
			clk       => clk,
			rst       => rst,
			mem_req   => cache_req,
			mem_write => cache_write,
			mem_addr  => cache_addr,
			mem_wdata => cache_wdata,
			mem_rdy   => mem2_rdy,
			mem_rstb  => mem2_rstb,
			mem_rdata => mem2_rdata);

	-- The Write-Data Generator
	wdata_prng: entity poc.arith_prng
    generic map (BITS => DATA_BITS)
    port map (
      clk => clk,
      rst => rst,
      got => wdata_got,
      val => wdata_val);

	-- The Stimuli Generator
  Stimuli: process
 		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Stimuli");

		-- Wait until cache and 2nd memory are ready.
		procedure wait_cache_rdy is
		begin
			wait for 1 ps; --let ready outputs settle
			while cache_rdy /= '1' or mem2_rdy /= '1' loop
				cache_req   <= '0';
				cache_write <= '-';
				cache_addr  <= (others => '-');
				cache_wdata <= (others => '-');
				wait until rising_edge(clk);
				wait for 1 ps; --let ready outputs settle
			end loop;
		end procedure;

		-- Wait until cache is ready and then write random data at given address.
		procedure write_cache (addr : in natural) is
		begin
			wait_cache_rdy;
			cache_req   <= '1';
			cache_write <= '1';
			cache_addr  <= to_unsigned(addr, ADDR_BITS-BYTE_ADDR_BITS);
			cache_wdata <= wdata_val;
			wdata_got   <= '1';
			wait until rising_edge(clk);
		end procedure;

		-- Wait until cache is ready and then read at given address.
		procedure read_cache (addr : in natural) is
		begin
			wait_cache_rdy;
			cache_req   <= '1';
			cache_write <= '0';
			cache_addr  <= to_unsigned(addr, ADDR_BITS-BYTE_ADDR_BITS);
			cache_wdata <= (others => '-');
			wait until rising_edge(clk);
		end procedure;

  begin
		-- Reset is mandatory
    rst <= '1';
    wait until rising_edge(clk);
    rst <= '0';

		-- Fill memory with valid data and read it back
		-- --------------------------------------------
		-- Due to the No-Write-Allocate policy no cache hit occurs.
		for addr in 0 to 2**ADDR_BITS-1 loop
			write_cache(addr);
		end loop;  -- addr
		for addr in 0 to 2**ADDR_BITS-1 loop
			read_cache(addr);
		end loop;  -- addr

		-- Read back again
		-- ---------------
		-- Cache hit occurs only if memory size equals cache size.
		for addr in 0 to 2**ADDR_BITS-1 loop
			read_cache(addr);
		end loop;  -- addr

		-- Finished
		-- --------
		cache_req <= '0';
		cache_write <= '-';
		cache_addr  <= (others => '-');
		cache_wdata <= (others => '-');
		finished <= true;
		simDeactivateProcess(simProcessID);
    wait;
  end process Stimuli;

	-- The Checker
	Checker: process
 		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("Checker");
		variable saved_rdata  : std_logic_vector(DATA_BITS-1 downto 0);
	begin
		-- wait until reset completes
		wait until rising_edge(clk) and rst = '0';

		-- wait until all stimuli have been applied
		while not finished loop
			wait until rising_edge(clk);
			simAssertion(not is_x(cache_rstb) and not is_x(mem2_rstb), "Meta-value on rstb.");
			if mem2_rstb = '1' then
				saved_rdata := mem2_rdata;
				-- If cache does not return data in same clock cycle (i.e. cache miss),
				-- then wait for cache_rstb.
				while cache_rstb = '0' loop
					wait until rising_edge(clk);
					-- No new data from 2nd memory must arrive here.
					simAssertion(mem2_rstb = '0', "Invalid reply from 2nd memory.");
				end loop;

				simAssertion(cache_rdata = saved_rdata, "Read data differs.");
			end if;
		end loop;

		simDeactivateProcess(simProcessID);
		simFinalize;
		wait;
	end process Checker;

end architecture sim;
