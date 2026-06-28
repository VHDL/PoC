-- =============================================================================
-- Authors:         Martin Zabel
--                  Patrick Lehmann
--
-- Entity:          True dual-port memory with write-first behavior.
--
-- Description:
-- -------------------------------------
-- Inferring / instantiating true dual-port memory, with:
--
-- * single clock, clock enable,
-- * 2 read/write ports.
--
-- Command truth table:
--
-- == === === =====================================================
-- ce we1 we2 Command
-- == === === =====================================================
-- 0   X   X  No operation
-- 1   0   0  Read only from memory
-- 1   0   1  Read from memory on port 1, write to memory on port 2
-- 1   1   0  Write to memory on port 1, read from memory on port 2
-- 1   1   1  Write to memory on both ports
-- == === === =====================================================
--
-- Both reads and writes are synchronous to the clock.
--
-- The generalized behavior across Altera and Xilinx FPGAs since
-- Stratix/Cyclone and Spartan-3/Virtex-5, respectively, is as follows:
--
-- Same-Port Read-During-Write
--   When writing data through port 1, the read output of the same port
--   (``q1``) will output the new data (``d1``, in the following clock cycle)
--   which is aka. "write-first behavior".
--
--   Same applies to port 2.
--
-- Mixed-Port Read-During-Write
--   When reading at the write address, the read value will be the new data,
--   aka. "write-first behavior". Of course, the read is still synchronous,
--   i.e, the latency is still one clock cyle.
--
-- If a write is issued on both ports to the same address, then the output of
-- this unit and the content of the addressed memory cell are undefined.
--
-- For simulation, always our dedicated simulation model :ref:`IP:ocram_TrueDualPort_sim`
-- is used.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2008-2016 Technische Universitaet Dresden - Germany
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

use     work.config.all;
use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;
use     work.mem.all;
use     work.ocram.all;


entity ocram_TrueDualPort_WriteFirst is
	generic (
		ADDRESS_BITS : positive;                              -- number of address bits
		DATA_BITS    : positive;                              -- number of data bits
		FILENAME     : string    := ""                        -- file-name for RAM initialization
	);
	port (
		Clock             : in  std_logic;                                 -- clock
		ClockEnable       : in  std_logic;                                 -- clock-enable
		PortA_WriteEnable : in  std_logic;                                 -- write-enable for 1st port
		PortB_WriteEnable : in  std_logic;                                 -- write-enable for 2nd port
		PortA_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);         -- address for 1st port
		PortB_Address     : in  unsigned(ADDRESS_BITS-1 downto 0);         -- address for 2nd port
		PortA_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);    -- write-data for 1st port
		PortB_DataIn      : in  std_logic_vector(DATA_BITS-1 downto 0);    -- write-data for 2nd port
		PortA_DataOut     : out std_logic_vector(DATA_BITS-1 downto 0);    -- read-data from 1st port
		PortB_DataOut     : out std_logic_vector(DATA_BITS-1 downto 0)     -- read-data from 2nd port
	);
end entity;


architecture rtl of ocram_TrueDualPort_WriteFirst is
	-- Two read/write ports are only supported in true-dual port block memories
	-- on FPGAs. But not all synthesis tools, do infer the required bypass logic
	-- as already shown for :ref:`IP:ocram_SimpleDualPort_wf`.
	-- Thus, bypass logic has to be explicitly described to get the intended
	-- write-first behavior.

	signal wd1_r  : std_logic_vector(PortA_DataIn'range); -- write data from port 1
	signal wd2_r  : std_logic_vector(PortB_DataIn'range); -- write data from port 2
	signal fwd1_r : std_logic;                  -- forward write data from port 1 to port 2
	signal fwd2_r : std_logic;                  -- forward write data from port 2 to port 1
	signal ram_q1 : std_logic_vector(PortA_DataOut'range); -- RAM output, port 1
	signal ram_q2 : std_logic_vector(PortB_DataOut'range); -- RAM output, port 2



begin
	process(Clock)
		variable addr_eq : X01;
	begin
		if rising_edge(Clock) then
			case to_x01(ClockEnable) is
				when '1' =>
					wd1_r   <= to_x01(PortA_DataIn);
					wd2_r   <= to_x01(PortB_DataIn);
					addr_eq := addressIsEqual(PortA_Address, PortB_Address);
					fwd1_r  <= addr_eq and PortA_WriteEnable;
					fwd2_r  <= addr_eq and PortB_WriteEnable;

				when '0' =>    -- keep previous state
					null;

				when others => -- X propagation in simulation
					wd1_r  <= (others => 'X');
					fwd1_r <= 'X';
					fwd2_r <= 'X';
			end case;

			if SIMULATION then
				assert (fwd1_r and fwd2_r) /= '1' report "ERROR: both ports write to the same address." severity error;
			end if;
		end if;
	end process;

	ram_tdp: entity work.ocram_TrueDualPort
		generic map (
			ADDRESS_BITS   => ADDRESS_BITS,
			DATA_BITS   => DATA_BITS,
			FILENAME => FILENAME)
		port map (
			PortA_Clock => Clock,
			PortB_Clock => Clock,
			PortA_ClockEnable  => ClockEnable,
			PortB_ClockEnable  => ClockEnable,
			PortA_WriteEnable  => PortA_WriteEnable,
			PortB_WriteEnable  => PortB_WriteEnable,
			PortA_Address   => PortA_Address,
			PortB_Address   => PortB_Address,
			PortA_DataIn   => PortA_DataIn,
			PortB_DataIn   => PortB_DataIn,
			PortA_DataOut   => ram_q1,
			PortB_DataOut   => ram_q2);

	with fwd1_r select PortB_DataOut <=
		wd1_r            when '1',
		ram_q2           when '0',
		(others => 'X') when others; -- X propagation in simulation

	with fwd2_r select PortA_DataOut <=
		wd2_r            when '1',
		ram_q1           when '0',
		(others => 'X') when others; -- X propagation in simulation

end architecture;
