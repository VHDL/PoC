-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Martin Zabel
--
-- Entity:					Controller for IS61LV Asynchronous SRAM.
--
-- Description:
-- -------------------------------------
-- Controller for IS61LV Asynchronous SRAM.
--
-- Tested with SRAM: IS61LV25616AL
--
-- This component provides the :doc:`PoC.Mem </References/Interfaces/Memory>`
-- interface for the user application.
--
--
-- Configuration
-- *************
--
-- +------------+-------------------------------------------+
-- | Parameter  | Description                               |
-- +============+===========================================+
-- | A_BITS     | Number of address bits (word address).    |
-- +------------+-------------------------------------------+
-- | D_BITS     | Number of data bits (of the word).        |
-- +------------+-------------------------------------------+
-- | SDIN_REG   | Generate register for sram_data on input. |
-- +------------+-------------------------------------------+
--
-- .. NOTE::
--    While the register on input from the SRAM chip is optional, all outputs
--    to the SRAM are registered as normal. These output registers should be
--    placed in an IOB on an FPGA, so that the timing relationship is
--    fulfilled.
--
--
-- Operation
-- *********
--
-- Regarding the user application interface, more details can be found
-- :doc:`here </References/Interfaces/Memory>`.
--
-- The system top-level must connect GND ('0') to the SRAM chip enable ``ce_n``.
--
-- When using an IS61LV25616: the SRAM byte enables ``lb_n`` and ``ub_n`` must be
-- connected to ``sram_be_n(0)`` and ``sram_be_n(1)``, respectively.
--
-- The system top-level must instantiate the appropriate tri-state driver for
-- ``sram_data``.
--
-- Synchronous reset is used.
--
-- License:
-- =============================================================================
-- Copyright 2008-2016 Technische Universitaet Dresden - Germany,
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

-------------------------------------------------------------------------------
-- Naming Conventions:
-- (Based on: Keating and Bricaud: "Reuse Methodology Manual")
--
-- active low signals: "*_n"
-- clock signals: "clk", "clk_div#", "clk_#x"
-- reset signals: "rst", "rst_n"
-- generics: all UPPERCASE
-- user defined types: "*_TYPE"
-- state machine next state: "*_ns"
-- state machine current state: "*_cs"
-- output of a register: "*_r"
-- asynchronous signal: "*_a"
-- pipelined or register delay signals: "*_p#"
-- data before being registered into register with the same name: "*_nxt"
-- clock enable signals: "*_ce"
-- internal version of output port: "*_i"
-- tristate internal signal "*_z"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.io.all;

entity sram_is61lv_ctrl is

	generic (
		A_BITS   : positive;
		D_BITS   : positive;
		SDIN_REG : boolean := true);

	port (
		-- PoC.Mem interface
		clk   : in  std_logic;
		rst   : in  std_logic;
		req   : in  std_logic;
		write : in  std_logic;
		addr  : in  unsigned(A_BITS-1 downto 0);
		wdata : in  std_logic_vector(D_BITS-1 downto 0);
		wmask : in  std_logic_vector(D_BITS/8 -1 downto 0) := (others => '0');
		rdy   : out std_logic;
		rstb  : out std_logic;
		rdata : out std_logic_vector(D_BITS-1 downto 0);

		-- SRAM connection
		sram_be_n : out   std_logic_vector(D_BITS/8 -1 downto 0);
		sram_oe_n : out   std_logic;
		sram_we_n : out   std_logic;
		sram_addr : out   unsigned(A_BITS-1 downto 0);
		sram_data : inout T_IO_TRISTATE_VECTOR(D_BITS-1 downto 0));
end sram_is61lv_ctrl;

architecture rtl of sram_is61lv_ctrl is
	attribute KEEP : boolean;

	-- WAR = Write After Read
	-- Don't merge with SRAM output registers.
	type FSM_TYPE is (RUNNING, WAR, WRITING);
	signal fsm_cs : FSM_TYPE;
	signal fsm_ns : FSM_TYPE;

	attribute KEEP of fsm_cs : signal is true;

	-- ready register
	signal rdy_r   : std_logic;
	signal rdy_nxt : std_logic;

	-- address register
	signal addr_r   : unsigned(A_BITS-1 downto 0);
	signal addr_nxt : unsigned(A_BITS-1 downto 0);

	-- byte enable register
	signal be_r_n   : std_logic_vector(D_BITS/8 -1 downto 0);
	signal be_nxt_n : std_logic_vector(D_BITS/8 -1 downto 0);

	-- write data register
	signal wdata_r   : std_logic_vector(D_BITS-1 downto 0);
	signal wdata_nxt : std_logic_vector(D_BITS-1 downto 0);

	-- sample user address and data
	signal get_user : std_logic;

	-- signals whether a read operation is currently executed
	signal reading_r   : std_logic;
	signal reading_nxt : std_logic;

	-- SRAM write enable, low-active
	-- Don't merge with FSM state register.
	signal sram_we_r_n   : std_logic;
	signal sram_we_nxt_n : std_logic;

	attribute KEEP of sram_we_r_n : signal is true;

	-- SRAM output enable, low-active
	-- Don't merge with reading_r.
	signal sram_oe_r_n   : std_logic;
	signal sram_oe_nxt_n : std_logic;

	attribute KEEP of sram_oe_r_n : signal is true;

	-- Own output enable, low-active
	-- Each bit needs its own output enable register!
	signal own_oe_r_n   : std_logic_vector(D_BITS-1 downto 0);
	signal own_oe_nxt_n : std_logic;

	attribute KEEP of own_oe_r_n : signal is true;

begin

	-------------------------------------------------------------------------
	-- Datapath not depending on FSM
	-------------------------------------------------------------------------
	be_nxt_n  <= wmask when write = '1' else
							 (others => '0'); -- all bytes must be enabled when reading
	addr_nxt  <= addr;
	wdata_nxt <= wdata;

	-------------------------------------------------------------------------
	-- FSM
	-------------------------------------------------------------------------
	process (fsm_cs, req, write, reading_r)
	begin  -- process
		fsm_ns        <= fsm_cs;
		get_user      <= '0';
		own_oe_nxt_n  <= '1';
		sram_oe_nxt_n <= '1';
		sram_we_nxt_n <= '1';
		reading_nxt   <= '0';

		-- BE CAREFUL!
		-- Set to '1' whenever fsm_ns <= RUNNING;
		rdy_nxt <= '-';

		case fsm_cs is
			when RUNNING =>
				-- due to fsm_ns <= fsm_cs by default
				rdy_nxt <= '1';

				if req = '1' then
					get_user <= '1';

					if write = '1' then
						if reading_r = '1' then
							-- wait for one cycle to change data-bus direction
							rdy_nxt <= '0';
							fsm_ns  <= WAR;
						else
							-- write to SRAM
							own_oe_nxt_n  <= '0';
							sram_we_nxt_n <= '0';
							fsm_ns        <= WRITING;
							rdy_nxt       <= '0';
						end if;

					else                          -- write = '0'
						-- read from SRAM
						sram_oe_nxt_n <= '0';
						reading_nxt   <= '1';
					end if;
				end if;

			when WAR =>
				-- write to SRAM after data-bus direction changed
				own_oe_nxt_n  <= '0';
				sram_we_nxt_n <= '0';
				fsm_ns        <= WRITING;
				rdy_nxt       <= '0';

			when WRITING =>
				-- hold data but de-assert write-enable of SRAM to issue write
				own_oe_nxt_n  <= '0';
				sram_we_nxt_n <= '1';
				fsm_ns        <= RUNNING;
				rdy_nxt       <= '1';

		end case;
	end process;

	-------------------------------------------------------------------------
	-- Registers
	-------------------------------------------------------------------------
	process (clk)
	begin  -- process
		if rising_edge(clk) then
			if rst = '1' then
				fsm_cs      <= RUNNING;
				rdy_r       <= '1';
				reading_r   <= '0';
				own_oe_r_n  <= (others => '1');
				sram_oe_r_n <= '1';
				sram_we_r_n <= '1';
			else
				fsm_cs      <= fsm_ns;
				rdy_r       <= rdy_nxt;
				reading_r   <= reading_nxt;
				own_oe_r_n  <= (others => own_oe_nxt_n);
				sram_oe_r_n <= sram_oe_nxt_n;
				sram_we_r_n <= sram_we_nxt_n;
			end if;

			if get_user = '1' then
				be_r_n  <= be_nxt_n;
				addr_r  <= addr_nxt;
				wdata_r <= wdata_nxt;
			end if;
		end if;
	end process;

	-------------------------------------------------------------------------
	-- Outputs
	-------------------------------------------------------------------------
	rdy <= rdy_r;

	gNoSdinReg: if SDIN_REG = false generate
		-- direct output, register elsewhere
		l1: for i in 0 to D_BITS-1 generate
			rdata(i) <= sram_data(i).i;
		end generate l1;

		rstb  <= reading_r;
	end generate gNoSdinReg;

	gSdinReg: if SDIN_REG = true generate
		process (clk)
		begin  -- process
			if rising_edge(clk) then
				if reading_r = '1' then             -- don't collect garbage
					for i in 0 to D_BITS-1 loop
						rdata(i) <= sram_data(i).i;
					end loop;  -- i
				end if;

				if rst = '1' then
					rstb <= '0';
				else
					rstb <= reading_r;
				end if;
			end if;
		end process;
	end generate gSdinReg;

	sram_be_n <= be_r_n;
	sram_addr <= addr_r;

	l1: for i in 0 to D_BITS-1 generate
		sram_data(i).o <= wdata_r(i);
		sram_data(i).t <= own_oe_r_n(i); -- driven when '0', otherwise high-z
		sram_data(i).i <= 'Z';           -- drive all record members
	end generate l1;

	sram_oe_n <= sram_oe_r_n;
	sram_we_n <= sram_we_r_n;

end rtl;
