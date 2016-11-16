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
-- directly attached to the CPU. The CPU compares the result of read requests
-- issued to the cache with the result from the direct attached memory.
--
-- CPU  ---+--- Cache (UUT) ---- 1st memory
--         |
--         +--- 2nd memory
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
use ieee.math_real.all;

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
  constant ADDR_BITS          : positive := 7;
  constant BYTE_ADDR_BITS     : natural  := 1;
  constant DATA_BITS          : positive := 16;
	constant WORD_ADDR_BITS     : positive := ADDR_BITS-BYTE_ADDR_BITS;
	constant MEMORY_WORDS       : positive := 2**WORD_ADDR_BITS;

	-- NOTE:
	-- Cache accesses are always aligned to a word boundary. A memory word and a
	-- cache line consist of DATA_BITS bits. For example if DATA_BITS=16:
	--
	-- * word address 0 selects the bits  0..15 in memory,
	-- * word address 1 selects the bits 16..31 in memory, and so on.

	-- Global signals
  signal clk : std_logic := '1';
  signal rst : std_logic;

	-- Request from CPU
  signal cpu_req   : std_logic;
  signal cpu_write : std_logic;
  signal cpu_addr  : unsigned(ADDR_BITS-1 downto BYTE_ADDR_BITS);
  signal cpu_wdata : std_logic_vector(DATA_BITS-1 downto 0);

	-- Bus between CPU and Cache
	-- write / addr / wdata are directly connected to the CPU
  signal cache_req   : std_logic;
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

	-- Bus between CPU and 2nd Memory
	-- write / addr / wdata are directly connected to the CPU
  signal mem2_req   : std_logic;
  signal mem2_rdy   : std_logic;
  signal mem2_rstb  : std_logic;
  signal mem2_rdata : std_logic_vector(DATA_BITS-1 downto 0);

	-- Write-Data Generator
	signal wdata_got : std_logic;
	signal wdata_val : std_logic_vector(DATA_BITS-1 downto 0);

	-- Control signals between Request Generator and Checker of CPU
	signal finished : boolean := false;

begin
	-- initialize global simulation status
	simInitialize;
	-- generate global testbench clock
	simGenerateClock(clk, CLOCK_FREQ);

	-- The Cache
	UUT: entity poc.cache_mem
    generic map (
      REPLACEMENT_POLICY => REPLACEMENT_POLICY,
      CACHE_LINES        => CACHE_LINES,
      ASSOCIATIVITY      => ASSOCIATIVITY,
      ADDR_BITS          => WORD_ADDR_BITS,
      DATA_BITS          => DATA_BITS)
    port map (
      clk       => clk,
      rst       => rst,
      cpu_req   => cache_req,
      cpu_write => cpu_write,
      cpu_addr  => cpu_addr,
      cpu_wdata => cpu_wdata,
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

	-- request only if also 2nd memory is ready
	cache_req <= cpu_req and mem2_rdy;

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
			mem_req   => mem2_req,
			mem_write => cpu_write,
			mem_addr  => cpu_addr,
			mem_wdata => cpu_wdata,
			mem_rdy   => mem2_rdy,
			mem_rstb  => mem2_rstb,
			mem_rdata => mem2_rdata);

	-- request only if also cache is ready
	mem2_req <= cpu_req and cache_rdy;

	-- The Write-Data Generator of the CPU
	wdata_prng: entity poc.arith_prng
    generic map (BITS => DATA_BITS)
    port map (
      clk => clk,
      rst => rst,
      got => wdata_got,
      val => wdata_val);

	-- The Request Generator of the CPU
  CPU_RequestGen: process
 		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("CPU RequestGen");

		-- no operation
		procedure nop is
		begin
			cpu_req   <= '0';
			cpu_write <= '-';
			cpu_addr  <= (others => '-');
			cpu_wdata <= (others => '-');
			wdata_got <= '0';
			wait until rising_edge(clk);
		end procedure;

		-- Write random data at given word address.
		-- Waits until cache and 2nd memory are ready.
		procedure write(addr : in natural) is
		begin
			-- apply request (will be ignored if not ready)
			cpu_req   <= '1';
			cpu_write <= '1';
			cpu_addr  <= to_unsigned(addr, WORD_ADDR_BITS);
			cpu_wdata <= wdata_val;
			wdata_got <= '1';
			while true loop
				wait until rising_edge(clk);
				exit when (cache_rdy and mem2_rdy) = '1';
			end loop;
		end procedure;

		-- Read at given word address.
		-- Waits until cache and 2nd memory are ready.
		procedure read(addr : in natural) is
		begin
			-- apply request (will be ignored if not ready)
			cpu_req   <= '1';
			cpu_write <= '0';
			cpu_addr  <= to_unsigned(addr, WORD_ADDR_BITS);
			cpu_wdata <= (others => '-');
			wdata_got <= '0';
			while true loop
				wait until rising_edge(clk);
				exit when (cache_rdy and mem2_rdy) = '1';
			end loop;
		end procedure;

		-- Seeds for random request generation
		variable seed1 : positive := 1;
		variable seed2 : positive := 1;

		variable temp_r : real;

  begin
		-- Reset is mandatory
    rst <= '1';
    wait until rising_edge(clk);
    rst <= '0';

		-- Check No Operation
		-- --------------------------------------------
		for i in 0 to 3 loop nop; end loop;

		-- Fill memory with valid data and read it back
		-- --------------------------------------------
		-- Due to the No-Write-Allocate policy no cache hit occurs.
		for addr in 0 to MEMORY_WORDS-1 loop
			write(addr);
		end loop;  -- addr
		for addr in 0 to MEMORY_WORDS-1 loop
			read(addr);
		end loop;  -- addr
		for i in 0 to 3 loop nop; end loop;

		-- Linear access, read/write/read at every address
		-- -----------------------------------------------
		for addr in 0 to MEMORY_WORDS-1 loop
			read(addr);  -- cache hit only if cache size equals memory size.
			write(addr); -- cache hit, write-through
			read(addr);  -- cache hit
			nop;
		end loop;  -- chunk
		for i in 0 to 3 loop nop; end loop;

		-- Linear access in chunks of cache size, read/write/read every chunk
		-- ------------------------------------------------------------------
		for chunk in 0 to (MEMORY_WORDS / CACHE_LINES)-1 loop
			for addr in chunk*CACHE_LINES to (chunk+1)*CACHE_LINES-1 loop
				read(addr);  -- cache hit only if cache size equals memory size.
			end loop; -- addr
			for addr in chunk*CACHE_LINES to (chunk+1)*CACHE_LINES-1 loop
				write(addr); -- cache hit, write-through
			end loop; -- addr
			for addr in chunk*CACHE_LINES to (chunk+1)*CACHE_LINES-1 loop
				read(addr);  -- cache hit
			end loop; -- addr
			nop;
		end loop;  -- chunk
		for i in 0 to 3 loop nop; end loop;

		-- Random access
		-- -------------
		for i in 1 to 1000 loop
			uniform(seed1, seed2, temp_r);
			if temp_r < 0.5 then
				uniform(seed1, seed2, temp_r);
				read(natural(floor(temp_r * real(MEMORY_WORDS))));
			else
				uniform(seed1, seed2, temp_r);
				write(natural(floor(temp_r * real(MEMORY_WORDS))));
			end if;
		end loop;

		-- Finished
		-- --------
		nop;
		finished  <= true;
		simDeactivateProcess(simProcessID);
    wait;
  end process CPU_RequestGen;

	-- The Checker of the CPU
	CPU_Checker: process
 		constant simProcessID	: T_SIM_PROCESS_ID := simRegisterProcess("CPU Checker");
		variable saved_rdata  : std_logic_vector(DATA_BITS-1 downto 0);
	begin
		-- wait until reset completes
		wait until rising_edge(clk) and rst = '0';

		-- wait until all requests have been applied
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
					simAssertion(not is_x(cache_rstb) and mem2_rstb = '0',
											 "Meta-value on rstb or invalid reply from 2nd memory.");
				end loop;

				simAssertion(cache_rdata = saved_rdata, "Read data differs.");
			end if;
		end loop;

		simDeactivateProcess(simProcessID);
		simFinalize;
		wait;
	end process CPU_Checker;

end architecture sim;
