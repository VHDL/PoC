-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Entity:					Cache with PoC's "mem" interface.
--
-- Description:
-- -------------------------------------
-- This unit provides a cache (:doc:`PoC.cache.par2 <cache_par2>`) together
-- with a cache controller which reads / writes cache lines from / to memory.
-- It has two PoC's "mem" interfaces:
--
-- * one for the "CPU" side  (ports with prefix ``cpu_``), and
-- * one for the memory side (ports with prefix ``mem_``).
--
-- Thus, this unit can be placed into an already available memory path between
-- the CPU and the memory (controller).
--
-- Configuration
-- *************
--
-- +--------------------+----------------------------------------------------+
-- | Parameter          | Description                                        |
-- +====================+====================================================+
-- | REPLACEMENT_POLICY | Replacement policy of embedded cache. For supported|
-- |                    | values see PoC.cache_replacement_policy.           |
-- +--------------------+----------------------------------------------------+
-- | CACHE_LINES        | Number of cache lines.                             |
-- +--------------------+----------------------------------------------------+
-- | ASSOCIATIVITY      | Associativity of embedded cache.                   |
-- +--------------------+----------------------------------------------------+
-- | ADDR_BITS          | Number of bits of full memory address, including   |
-- |                    | byte address bits.                                 |
-- +--------------------+----------------------------------------------------+
-- | DATA_BITS          | Size of a cache line in bits. Equals also the size |
-- |                    | of the read and write data ports of the CPU and    |
-- |                    | memory side. DATA_BITS must be divisible by 8.     |
-- +--------------------+----------------------------------------------------+
--
--
-- Operation
-- *********
--
-- All inputs are synchronous to the rising-edge of the clock ``clk``.
-- A synchronous reset must be applied even on a FPGA.
--
-- The write policy is: write-through, no-write-allocate.
--
-- .. TODO::
--    * Allow partial update of cache line (byte write enable).
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_mem is
	generic (
		REPLACEMENT_POLICY : string		:= "LRU";
		CACHE_LINES				 : positive := 32;
		ASSOCIATIVITY			 : positive := 32;
		ADDR_BITS	      	 : positive := 8;
		DATA_BITS					 : positive := 8
	);
	port (
    clk : in std_logic; -- clock
    rst : in std_logic; -- reset

    -- "CPU" side
    cpu_req   : in  std_logic;
    cpu_write : in  std_logic;
    cpu_addr  : in  unsigned(ADDR_BITS-1 downto 0);
    cpu_wdata : in  std_logic_vector(DATA_BITS-1 downto 0);
    cpu_rdy   : out std_logic;
    cpu_rstb  : out std_logic;
    cpu_rdata : out std_logic_vector(DATA_BITS-1 downto 0);

		-- Memory side
		mem_req		: out std_logic;
		mem_write : out std_logic;
		mem_addr	: out unsigned(ADDR_BITS-1 downto 0);
		mem_wdata : out std_logic_vector(DATA_BITS-1 downto 0);
		mem_rdy		: in	std_logic;
		mem_rstb	: in	std_logic;
		mem_rdata : in	std_logic_vector(DATA_BITS-1 downto 0)
    );
end entity;

architecture rtl of cache_mem is
	-- Interface to Cache instance.
	signal cache_Request		: std_logic;
	signal cache_ReadWrite	: std_logic;
	signal cache_Invalidate : std_logic;
	signal cache_Replace		: std_logic;
	signal cache_Address		: std_logic_vector(ADDR_BITS-1 downto 0);
	signal cache_LineIn			: std_logic_vector(DATA_BITS-1 downto 0);
	signal cache_LineOut		: std_logic_vector(DATA_BITS-1 downto 0);
	signal cache_Hit				: std_logic;
	signal cache_Miss				: std_logic;

	-- Address and data path
	signal cpu_write_r : std_logic;
	signal cpu_addr_r  : unsigned(cpu_addr'range);
	signal cpu_wdata_r : std_logic_vector(cpu_wdata'range);

  -- FSM and other state registers
  type T_FSM is (READY, ACCESS_MEM, READING_MEM, UNKNOWN);
  signal fsm_cs : T_FSM -- current state
		-- synthesis translate_off
		:= UNKNOWN
		-- synthesis translate_on
		;
  signal fsm_ns : T_FSM;-- next state

	signal cpu_rstb_r		: std_logic;
	signal cpu_rstb_nxt : std_logic;

begin  -- architecture rtl

  cache_inst: entity work.cache_par2
    generic map (
			REPLACEMENT_POLICY => REPLACEMENT_POLICY,
			CACHE_LINES        => CACHE_LINES,
			ASSOCIATIVITY      => ASSOCIATIVITY,
			ADDR_BITS          => ADDR_BITS,
			DATA_BITS          => DATA_BITS,
			HIT_MISS_REG       => false)
    port map (
			Clock        => clk,
			Reset        => rst,
			Request      => cache_Request,
			ReadWrite    => cache_ReadWrite,
			Invalidate   => cache_Invalidate,
			Replace      => cache_Replace,
			Address      => cache_Address,
			CacheLineIn  => cache_LineIn,
			CacheLineOut => cache_LineOut,
			CacheHit     => cache_Hit,
			CacheMiss    => cache_Miss,
			OldAddress   => open);

  -- Address and Data path
  -- ===========================================================================
  cache_Address <= std_logic_vector(cpu_addr) when fsm_cs = READY else
									 std_logic_vector(cpu_addr_r);
  cache_LineIn  <= cpu_wdata when fsm_cs = READY else mem_rdata;

  cpu_rdata <= mem_rdata when fsm_cs = READING_MEM else
							 cache_LineOut; -- when READY or ACCESS_MEM
  cpu_rstb  <= cpu_rstb_r or  -- after read from cache
							 mem_rstb;      -- when reading from memory

	mem_write <= cpu_write_r;
	mem_addr  <= cpu_addr_r;
	mem_wdata <= cpu_wdata_r;

	process(clk)
	begin
		-- save request when FSM is ready
		if rising_edge(clk) then
			if fsm_cs = READY then
				cpu_write_r <= cpu_write;
				cpu_addr_r  <= cpu_addr;
				cpu_wdata_r <= cpu_wdata;
			end if;
		end if;
	end process;

	-- FSM
	-- ===========================================================================
	process(fsm_cs, cpu_req, cpu_write, cache_Hit, cache_Miss, cpu_write_r,
					mem_rdy, mem_rstb)
	begin
		-- Update state registers
		fsm_ns			 <= fsm_cs;
		cpu_rstb_nxt <= '0';

		-- Control signals for cache access
		cache_Request		 <= '0';
		cache_ReadWrite	 <= '-';
		cache_Invalidate <= '-';
		cache_Replace		 <= '0';

		-- Control / status signals for CPU and MEM side
		cpu_rdy <= '0';
		mem_req <= '0';

		case fsm_cs is
			when READY =>
				-- Ready for a new cache access.
				-- -----------------------------
				cpu_rdy <= '1';

				cache_Request		 <= to_x01(cpu_req);
				cache_ReadWrite	 <= to_x01(cpu_write); -- doesn't care if no request
				cache_Invalidate <= '0';

				cpu_rstb_nxt <= cache_Hit and not cpu_write; -- read successful

				case ((cache_Hit and cpu_write) or cache_Miss) is
					when '1' =>	-- write successfull but write-through, or cache miss
						fsm_ns <= ACCESS_MEM;
					when '0' => -- read successfull
						null;
					when others => -- invalid input
						fsm_ns <= UNKNOWN;
				end case;


			when ACCESS_MEM =>
				-- Access memory.
				-- --------------
				mem_req <= '1';
				case to_x01(mem_rdy) is
					when '1' => -- access granted
						case to_x01(cpu_write_r) is
							when '1'    => fsm_ns <= READY; -- write
							when '0'    => fsm_ns <= READING_MEM; -- read
							when others => fsm_ns <= UNKNOWN; -- invalid input
						end case;

					when '0' =>	null; -- still waiting
					when others => fsm_ns <= UNKNOWN; -- invalid input
				end case;


      when READING_MEM =>
        -- Wait for incoming read data and write it to cache.
				-- --------------------------------------------------
				cache_Replace   <= to_x01(mem_rstb);
				cache_ReadWrite <= '1';

				case to_x01(mem_rstb) is
					when '1' => -- read data available
						-- read data is directly passed to CPU in datapath above
						fsm_ns <= READY;
					when '0' => null;-- still waiting
					when others => fsm_ns <= UNKNOWN; -- invalid input
				end case;


			when UNKNOWN =>
				-- Catches invalid state transitions.
				-- ----------------------------------
				fsm_ns			 <= UNKNOWN;
				cpu_rstb_nxt <= 'X';

				cache_Request		 <= 'X';
				cache_ReadWrite	 <= 'X';
				cache_Invalidate <= 'X';
				cache_Replace		 <= 'X';
		end case;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			case to_x01(rst) is
				when '1' =>
					fsm_cs		 <= READY;
					cpu_rstb_r <= '0';
				when '0' =>
					fsm_cs		 <= fsm_ns;
					cpu_rstb_r <= cpu_rstb_nxt;
				when others =>
					fsm_cs		 <= UNKNOWN;
					cpu_rstb_r <= 'X';
			end case;
		end if;
	end process;

end architecture rtl;
