-- =============================================================================
-- Authors:          Paul Genssler
--
-- Entity:          Simple ICAP wrapper with a fifo interface and a few status signals
--
-- Description:
-- -------------------------------------
-- This module was designed to connect the Xilinx "Internal Configuration Access Port" (ICAP)
-- to a PCIe endpoint on a Dini board. Tested on:
--
-- tbd
--
-- License:
-- =============================================================================
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

library UNISIM;
use     UNISIM.vcomponents.all;

use     work.utils.all;

entity reconfig_ICAP_Wrapper is
	generic (
		INPUT_FIFO_DEPTH  : positive := 256;
		OUTPUT_FIFO_DEPTH : positive := 256
	);
	port (
		Clock            : in  std_logic;
		Reset            : in  std_logic;
		ICAP_Clock       : in  std_logic;    -- clock signal for ICAP, max 100 MHz (double check with manual)

		ICAP_Busy        : out std_logic;    -- the ICAP is processing the data
		ICAP_Readback    : out std_logic;    -- high during a readback
		ICAP_Partial_res : out std_logic;    -- high during reconfiguration

		-- data in
		Write_Put        : in  std_logic;
		Write_Data       : in  std_logic_vector(31 downto 0);
		Write_Full       : out std_logic;
		Write_Done       : in  std_logic;    -- high pulse/edge after all data was written

		-- data out
		Read_Valid       : out std_logic;
		Read_Data        : out std_logic_vector(31 downto 0);
		Read_Got         : in  std_logic
	);
end entity;

architecture Behavioral of reconfig_ICAP_Wrapper is
	signal reset_icap        : std_logic;

	signal write_done_d        : std_logic;
	signal write_done_edge      : std_logic;
	signal write_done_icapclk    : std_logic;

	signal in_data_valid      : std_logic;
	constant STATE_BITS       : positive := 2;
	constant state_almost_full    : std_logic_vector(STATE_BITS -1 downto 0) := (0 => '0', others => '1');
	signal in_data_fill_state    : std_logic_vector(STATE_BITS -1 downto 0);
	signal in_data_rden        : std_logic;
	signal in_data_start      : std_logic;    -- high after enough data was written into the pci->icap fifo
														-- or write done (status register)
	signal icap_rden        : std_logic;    -- icap wants some yummy data
	signal in_data          : std_logic_vector(31 downto 0);

	signal out_data_full      : std_logic;
	signal out_data_put        : std_logic;
	signal out_data          : std_logic_vector(31 downto 0);

	signal icap_data_config      : std_logic_vector(31 downto 0);
	signal icap_data_readback    : std_logic_vector(31 downto 0);
	signal icap_csb          : std_logic;
	signal icap_rw          : std_logic;

	signal icap_data_config_r    : std_logic_vector(31 downto 0);
	signal icap_data_readback_r    : std_logic_vector(31 downto 0);
	signal icap_csb_r        : std_logic;
	signal icap_rw_r        : std_logic;

	signal fsm_status        : std_logic_vector(31 downto 0);
	signal fsm_status_clk      : std_logic_vector(31 downto 0);
	signal fsm_ready        : std_logic;
	signal fsm_ready_d        : std_logic;
begin
	write_done_d <= Write_Done when rising_edge(Clock);
	write_done_edge <= to_sl(Write_Done = '1' and write_done_d = '0');

	ICAP_Busy      <= not fsm_status_clk(3);
	ICAP_Readback    <= fsm_status_clk(1);
	ICAP_Partial_res  <= fsm_status_clk(0);

	fsm_ready <= fsm_status(3);
	fsm_ready_d <= fsm_ready when rising_edge(ICAP_Clock);

	-- buffer some data before starting the icap, icap needs to be sync'ed before it can be paused
	in_data_buffer_p : process (ICAP_Clock) begin
		if rising_edge(ICAP_Clock) then
			if (reset_icap = '1') then
				in_data_start <= '0';
			else
				if fsm_ready = '1' and fsm_ready_d = '0' then  -- reset after icap is done
					in_data_start <= '0';
				elsif in_data_fill_state = state_almost_full or write_done_icapclk = '1' then  -- set when fifo almost full or write already done
					in_data_start <= '1';
				end if;
			end if;
		end if;
	end process in_data_buffer_p;

	in_data_rden <= icap_rden and in_data_start and in_data_valid;

	-- sync the written pci data into the user clk
	-- writer: pci
	-- reader: core
	fifo_in: entity work.fifo_ic_got
		generic map(
			DATA_BITS        => 32,
			MIN_DEPTH        => INPUT_FIFO_DEPTH,
			OUTPUT_REG       => false,
			FILL_STATE_BITS  => STATE_BITS
		)
		port map(
			Write_Clock      => Clock,
			Write_Reset      => Reset,
			Write_Put        => Write_Put,
			Write_DataIn     => Write_Data,
			Write_Full       => Write_Full,
			Write_EmptyState => open,

			Read_Clock       => ICAP_Clock,
			Read_Reset       => reset_icap,
			Read_Valid       => in_data_valid,
			Read_DataOut     => in_data,
			Read_Got         => in_data_rden,
			Read_FillState   => in_data_fill_state
		);

	-- sync data from this core to the pci bus
	-- writer: core
	-- reader: pci
	fifo_out: entity work.fifo_ic_got
		generic map(
			DATA_BITS        => 32,
			MIN_DEPTH        => OUTPUT_FIFO_DEPTH,
			OUTPUT_REG       => false
		)
		port map(
			Write_Clock      => ICAP_Clock,
			Write_Reset      => reset_icap,
			Write_Put        => out_data_put,
			Write_DataIn     => out_data,
			Write_Full       => out_data_full,
			Write_EmptyState => open,

			Read_Clock       => Clock,
			Read_Reset       => Reset,
			Read_Valid       => Read_Valid,
			Read_DataOut     => Read_Data,
			Read_Got         => Read_Got,
			Read_FillState   => open
		);

	FSM: entity work.reconfig_ICAP_FSM
		port map(
			Clock => ICAP_Clock,
			Reset => reset_icap,
			icap_in => icap_data_config_r,
			icap_out => icap_data_readback_r,
			icap_csb => icap_csb_r,
			icap_rw => icap_rw_r,
			in_data => in_data,
			in_data_valid => in_data_rden,    -- TODO start one clock cycle later
			in_data_rden => icap_rden,
			out_data => out_data,
			out_data_valid => out_data_put,
			out_data_full => out_data_full,
			status => fsm_status
		);

	-- icap
	icap_reg_p : process (ICAP_Clock) begin
		if rising_edge(ICAP_Clock) then
			icap_data_readback_r <= icap_data_readback;
			icap_csb <= icap_csb_r;
			icap_rw <= icap_rw_r;
			icap_data_config <= icap_data_config_r;
		end if;
	end process icap_reg_p;

	ICAP: entity work.xil_ICAP
		port map (
			Clock      => ICAP_Clock,
			Disable    => icap_csb,
			Busy    => open,
			DataIn    => icap_data_config,
			DataOut  => icap_data_readback,
			ReadWrite    => icap_rw
		);

	strobe_sync: entity work.sync_Strobe
		port map (
			clock1 => Clock,
			clock2 => ICAP_Clock,
			input(0) => write_done_edge,
			output(0) => write_done_icapclk,
			busy => open
		);

	reset_sync: entity work.sync_Bits
		port map (
			clock => ICAP_Clock,
			input(0) => Reset,
			output(0) => reset_icap
		);

	fsm_status_sync: entity work.sync_vector
		generic map (
			master_bits => 32
		) port map (
			clock1 => ICAP_Clock,
			clock2 => Clock,
			input => fsm_status,
			output => fsm_status_clk,
			busy => open,
			changed => open
		);
end architecture;
