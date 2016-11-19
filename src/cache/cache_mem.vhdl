-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Martin Zabel
--
-- Entity:          Cache with :ref:`INT:PoC.Mem` interface on the "CPU" side
--
-- Description:
-- -------------------------------------
-- This unit provides a cache (:ref:`IP:cache_par2`) together
-- with a cache controller which reads / writes cache lines from / to memory.
-- It has two :ref:`INT:PoC.Mem` interfaces:
--
-- * one for the "CPU" side  (ports with prefix ``cpu_``), and
-- * one for the memory side (ports with prefix ``mem_``).
--
-- Thus, this unit can be placed into an already available memory path between
-- the CPU and the memory (controller). If you want to plugin a cache into a
-- CPU pipeline, see :ref:`IP:cache_cpu`.
--
--
-- Configuration
-- *************
--
-- +--------------------+-----------------------------------------------------+
-- | Parameter          | Description                                         |
-- +====================+=====================================================+
-- | REPLACEMENT_POLICY | Replacement policy of embedded cache. For supported |
-- |                    | values see PoC.cache_replacement_policy.            |
-- +--------------------+-----------------------------------------------------+
-- | CACHE_LINES        | Number of cache lines.                              |
-- +--------------------+-----------------------------------------------------+
-- | ASSOCIATIVITY      | Associativity of embedded cache.                    |
-- +--------------------+-----------------------------------------------------+
-- | CPU_ADDR_BITS      | Number of address bits on the CPU side. Each address|
-- |                    | identifies one memory word as seen from the CPU.    |
-- |                    | Calculated from other parameters as described below.|
-- +--------------------+-----------------------------------------------------+
-- | CPU_DATA_BITS      | Width of the data bus (in bits) on the CPU side.    |
-- |                    | CPU_DATA_BITS must be divisible by 8.               |
-- +--------------------+-----------------------------------------------------+
-- | MEM_ADDR_BITS      | Number of address bits on the memory side. Each     |
-- |                    | address identifies one word in the memory.          |
-- +--------------------+-----------------------------------------------------+
-- | MEM_DATA_BITS      | Width of a memory word and of a cache line in bits. |
-- |                    | MEM_DATA_BITS must be divisible by CPU_DATA_BITS.   |
-- +--------------------+-----------------------------------------------------+
--
-- If the CPU data-bus width is smaller than the memory data-bus width, then
-- the CPU needs additional address bits to identify one CPU data word inside a
-- memory word. Thus, the CPU address-bus width is calculated from::
--
--   CPU_ADDR_BITS=log2ceil(CPU_DATA_BITS/MEM_DATA_BITS)+MEM_ADDR_BITS
--
-- The write policy is: write-through, no-write-allocate.
--
--
-- Operation
-- *********
--
-- Memory accesses are always aligned to a word boundary. Each memory word
-- (and each cache line) consists of MEM_DATA_BITS bits.
-- For example if MEM_DATA_BITS=128:
--
-- * memory address 0 selects the bits   0..127 in memory,
-- * memory address 1 selects the bits 128..256 in memory, and so on.
--
-- Cache accesses are always aligned to a CPU word boundary. Each CPU word
-- consists of CPU_DATA_BITS bits. For example if CPU_DATA_BITS=32:
--
-- * CPU address 0 selects the bits   0.. 31 in memory word 0,
-- * CPU address 1 selects the bits  32.. 63 in memory word 0,
-- * CPU address 2 selects the bits  64.. 95 in memory word 0,
-- * CPU address 3 selects the bits  96..127 in memory word 0,
-- * CPU address 4 selects the bits   0.. 31 in memory word 1,
-- * CPU address 5 selects the bits  32.. 63 in memory word 1, and so on.
--
-- A synchronous reset must be applied even on a FPGA.
--
-- The interface is documented in detail :ref:`here <INT:PoC.Mem>`.
--
-- SeeAlso:
--   :ref:`IP:cache_cpu`
--
-- License:
-- =============================================================================
-- Copyright 2016-2016 Technische Universitaet Dresden - Germany
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.utils.all;

entity cache_mem is
	generic (
		REPLACEMENT_POLICY : string		:= "LRU";
		CACHE_LINES        : positive;
		ASSOCIATIVITY      : positive;
		CPU_DATA_BITS      : positive;
		MEM_ADDR_BITS      : positive;
		MEM_DATA_BITS      : positive
	);
	port (
    clk : in std_logic; -- clock
    rst : in std_logic; -- reset

    -- "CPU" side
    cpu_req   : in  std_logic;
    cpu_write : in  std_logic;
    cpu_addr  : in  unsigned(log2ceil(CPU_DATA_BITS/MEM_DATA_BITS)+MEM_ADDR_BITS-1 downto 0);
    cpu_wdata : in  std_logic_vector(CPU_DATA_BITS-1 downto 0);
    cpu_wmask : in  std_logic_vector(CPU_DATA_BITS/8-1 downto 0);
    cpu_rdy   : out std_logic;
    cpu_rstb  : out std_logic;
    cpu_rdata : out std_logic_vector(CPU_DATA_BITS-1 downto 0);

		-- Memory side
		mem_req		: out std_logic;
		mem_write : out std_logic;
		mem_addr	: out unsigned(MEM_ADDR_BITS-1 downto 0);
		mem_wdata : out std_logic_vector(MEM_DATA_BITS-1 downto 0);
		mem_wmask : out std_logic_vector(MEM_DATA_BITS/8-1 downto 0);
		mem_rdy		: in	std_logic;
		mem_rstb	: in	std_logic;
		mem_rdata : in	std_logic_vector(MEM_DATA_BITS-1 downto 0)
    );
end entity;

architecture rtl of cache_mem is
	-- signals to internal cache_cpu
	signal int_req   : std_logic;
	signal int_write : std_logic;
	signal int_addr  : unsigned(log2ceil(CPU_DATA_BITS/MEM_DATA_BITS)+MEM_ADDR_BITS-1 downto 0);
	signal int_wdata : std_logic_vector(CPU_DATA_BITS-1 downto 0);
	signal int_wmask : std_logic_vector(CPU_DATA_BITS/8-1 downto 0);
	signal int_got   : std_logic;
	signal int_rdata : std_logic_vector(CPU_DATA_BITS-1 downto 0);

begin

	cache_cpu_inst: entity work.cache_cpu
		generic map (
			REPLACEMENT_POLICY => REPLACEMENT_POLICY,
			CACHE_LINES        => CACHE_LINES,
			ASSOCIATIVITY      => ASSOCIATIVITY,
			CPU_DATA_BITS      => CPU_DATA_BITS,
			MEM_ADDR_BITS      => MEM_ADDR_BITS,
			MEM_DATA_BITS      => MEM_DATA_BITS)
		port map (
			clk       => clk,
			rst       => rst,
			cpu_req   => int_req,
			cpu_write => int_write,
			cpu_addr  => int_addr,
			cpu_wdata => int_wdata,
			cpu_wmask => int_wmask,
			cpu_got   => int_got,
			cpu_rdata => int_rdata,
			mem_req   => mem_req,
			mem_write => mem_write,
			mem_addr  => mem_addr,
			mem_wdata => mem_wdata,
			mem_wmask => mem_wmask,
			mem_rdy   => mem_rdy,
			mem_rstb  => mem_rstb,
			mem_rdata => mem_rdata);

	g1: block
    signal cpu_req_r   : std_logic;
    signal cpu_write_r : std_logic;
    signal cpu_addr_r  : unsigned(log2ceil(CPU_DATA_BITS/MEM_DATA_BITS)+MEM_ADDR_BITS-1 downto 0);
    signal cpu_wdata_r : std_logic_vector(CPU_DATA_BITS-1 downto 0);
    signal cpu_wmask_r : std_logic_vector(CPU_DATA_BITS/8-1 downto 0);
    signal cpu_rdy_r   : std_logic;
    signal cpu_rstb_r  : std_logic;
    signal cpu_rdata_r : std_logic_vector(CPU_DATA_BITS-1 downto 0);
	begin
		-- cpu_rdy should have a short clock-to-output delay, but int_got has a large
		-- propagation delay. Thus, do not depend cpu_rdy and int_got.
		-- This single entry FIFO stores a valid request if cpu_req_r = '1',
		-- otherwise it is empty.
		process(clk)
		begin
			if rising_edge(clk) then
				-- store new request only if FIFO is empty
				case to_x01(cpu_req_r) is
					when '1' => null; -- FIFO is full
					when '0' =>
						cpu_write_r <= cpu_write;
						cpu_addr_r  <= cpu_addr;
						cpu_wdata_r <= cpu_wdata;
						cpu_wmask_r <= cpu_wmask;

					when others => -- just for simulation
						cpu_write_r <= 'X';
						cpu_addr_r  <= (others => 'X');
						cpu_wdata_r <= (others => 'X');
						cpu_wmask_r <= (others => 'X');
				end case;

				-- FIFO state logic
				case to_x01(rst) is
					when '1' =>    cpu_req_r <= '0';
					when '0' =>	   cpu_req_r <=
													 (cpu_req_r and not int_got) or -- keep if not yet acknowledged
													 (not cpu_req_r and cpu_req);   -- or new request when empty
					when others => cpu_req_r <= 'X';
				end case;

				-- read data is valid one clock cycle after int_got is asserted
				cpu_rstb <= (not rst) and (not cpu_write_r) and int_got;
			end if;
		end process;

		cpu_rdy   <= not cpu_req_r; -- ready when empty
		cpu_rdata <= int_rdata; -- already delayed by one clock cycle

		int_req   <= cpu_req_r;
		int_write <= cpu_write_r;
		int_addr  <= cpu_addr_r;
		int_wdata <= cpu_wdata_r;
		int_wmask <= cpu_wmask_r;
	end block g1;

end architecture rtl;
