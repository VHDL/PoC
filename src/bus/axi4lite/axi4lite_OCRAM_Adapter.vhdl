-- =============================================================================
-- Authors:         Iqbal Asif
--                  Patrick Lehmann
--                  Srikanth Boppudi
--                  Stefan Unrein
--
-- Entity: axi4lite_OCRAM_Adapter
--
-- Description:
-- This module bridges the AXI4-Lite bus to a simplified synchronous RAM interface.
-- Includes a PREFFERED_READ_ACCESS generic to resolve simultaneous Read/Write
-- requests by prioritizing the read channel when set to TRUE.
-- Resource Utilization (64-bit Data | 13-bit AXI Addr | 10-bit RAM Addr| with '0' pipeline stages):
--   +-------------------+-------+
--   | Resource Type     | Count |
--   +-------------------+-------+
--   | CLB LUTs          |  19   |
--   | CLB Registers     |   3   |
--   +-------------------+-------+
-- -------------------------------------
-- An adapter from AXI4-Lite to OCRAM.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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

use     work.utils.all;
use     work.axi4lite.all;

entity axi4lite_OCRAM_Adapter is
	generic (
		OCRAM_ADDRESS_BITS    : positive;
		OCRAM_DATA_BITS       : positive;
		PREFFERED_READ_ACCESS : boolean := TRUE;
		INPUT_STAGES          : natural := 0;
		ADD_READ_DELAY        : boolean := FALSE  -- delay read if data is available on the bus after two clock cycles
	);
	port (
		Clock : in  std_logic;
		Reset : in  std_logic;

		AXI4Lite_m2s : in  T_AXI4Lite_Bus_m2s;
		AXI4Lite_s2m : out T_AXI4Lite_Bus_s2m;

		OCRAM_Address     : out unsigned(OCRAM_ADDRESS_BITS - 1 downto 0) := (others => '0');
		OCRAM_WriteEnable : out std_logic;
		OCRAM_ByteEnable  : out std_logic_vector((OCRAM_DATA_BITS / 8) - 1 downto 0);
		OCRAM_DataIn      : in  std_logic_vector(OCRAM_DATA_BITS - 1 downto 0);
		OCRAM_DataOut     : out std_logic_vector(OCRAM_DATA_BITS - 1 downto 0)
	);
end entity;

architecture rtl of axi4lite_OCRAM_Adapter is
	constant ADDRESS_BITS : positive := AXI4Lite_m2s.AWAddr'length;
	constant DATA_BITS    : positive := AXI4Lite_m2s.WData'length;
	constant ADDR_LSB     : positive := log2ceil(DATA_BITS) - 3;

	-- AXI4LITE signals
	signal nextAddress  : OCRAM_Address'subtype;
	signal axi_awready   : std_logic;
	signal axi_wready    : std_logic;
	signal axi_bresp     : std_logic_vector(1 downto 0);
	signal axi_bvalid    : std_logic;
	signal axi_arready   : std_logic;
	signal axi_rresp     : std_logic_vector(1 downto 0) := "00";
	signal axi_rvalid    : std_logic                    := '0';
	signal AXI4L_m2s_int : AXI4Lite_m2s'subtype;
	signal AXI4L_s2m_int : AXI4Lite_s2m'subtype;

	type t_state is (
		st_idle,
		st_await_write_address,
		st_await_write_data,
		st_write_address_data,
		st_read_data_ack,
		st_write_response_wait,
		st_read_response_wait,
		st_read_response_wait_delay,
		st_error
	);

	signal currentState : t_state := st_idle;
	signal nextState    : t_state;

begin
	assert (ADDRESS_BITS - ADDR_LSB) >= OCRAM_ADDRESS_BITS report "PoC.axi4lite_OCRAM_Adapter:: Not enough address bits in AXI4L bus for " & integer'image(OCRAM_ADDRESS_BITS) & " OCRAM-address-bits!" severity failure;
	assert DATA_BITS >= OCRAM_DATA_BITS                    report "PoC.axi4lite_OCRAM_Adapter:: Not enough data bits in AXI4L bus for " & integer'image(OCRAM_DATA_BITS) & " OCRAM-data-bits!" severity failure;

	pipeline_in : if INPUT_STAGES > 0 generate
		pipeline : entity work.axi4lite_FIFO
			generic map(
				TRANSACTIONS => INPUT_STAGES
			)
			port map
			(
				Clock => Clock,
				Reset => Reset,
				-- IN Port
				In_m2s => AXI4Lite_m2s,
				In_s2m => AXI4Lite_s2m,
				-- OUT Port
				Out_m2s => AXI4L_m2s_int,
				Out_s2m => AXI4L_s2m_int
			);
	else generate
		AXI4L_m2s_int <= AXI4Lite_m2s;
		AXI4Lite_s2m  <= AXI4L_s2m_int;
	end generate;

	AXI4L_s2m_int.AWReady <= axi_awready;
	AXI4L_s2m_int.WReady  <= axi_wready;
	AXI4L_s2m_int.BResp   <= axi_bresp;
	AXI4L_s2m_int.BValid  <= axi_bvalid;
	AXI4L_s2m_int.ARReady <= axi_arready;
	AXI4L_s2m_int.RData   <= resize(OCRAM_DataIn, DATA_BITS);
	AXI4L_s2m_int.RResp   <= axi_rresp;
	AXI4L_s2m_int.RValid  <= axi_rvalid;

	OCRAM_DataOut    <= resize(AXI4L_m2s_int.WData, OCRAM_DATA_BITS);
	OCRAM_ByteEnable <= AXI4L_m2s_int.WStrb(OCRAM_ByteEnable'range);

	process (Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				currentState <= st_idle;
			else
				currentState <= nextState;
			end if;
		end if;
	end process;

	OCRAM_Address <= nextAddress when rising_edge(Clock);

	process (all)
		variable valid : std_logic_vector(2 downto 0);
	begin
		nextState         <= currentState;
		nextAddress       <= OCRAM_Address;
		OCRAM_WriteEnable <= '0';
		axi_awready       <= '0';
		axi_wready        <= '0';
		axi_arready       <= '0';
		axi_rvalid        <= '0';
		axi_bvalid        <= '0';
		axi_bresp         <= C_AXI4_RESPONSE_OKAY;
		axi_rresp         <= C_AXI4_RESPONSE_OKAY;

		valid := AXI4L_m2s_int.WValid & AXI4L_m2s_int.AWValid & AXI4L_m2s_int.ARValid;

		case currentState is
			when st_idle =>

				case valid is
					when "000" =>

					when "001" => -- only read address
						nextAddress  <= unsigned(AXI4L_m2s_int.ARAddr(OCRAM_ADDRESS_BITS + ADDR_LSB -1 downto ADDR_LSB));
						nextState    <= st_read_data_ack;

					when "010" => -- only write address
						nextAddress <= unsigned(AXI4L_m2s_int.AWAddr(OCRAM_ADDRESS_BITS + ADDR_LSB -1 downto ADDR_LSB));
						nextState   <= st_await_write_data;

					when "011" | "101" | "111" => -- read and write address at the same time
						if (PREFFERED_READ_ACCESS = TRUE) then
							nextAddress <= unsigned(AXI4L_m2s_int.ARAddr(OCRAM_ADDRESS_BITS + ADDR_LSB -1 downto ADDR_LSB));
							nextState <= st_read_data_ack;

						elsif (valid = "011") then -- read and write address at the same time
							nextAddress <= unsigned(AXI4L_m2s_int.AWAddr(OCRAM_ADDRESS_BITS + ADDR_LSB -1 downto ADDR_LSB));
							nextState   <= st_await_write_data;

						elsif (valid = "101") then-- read address and write data at the same time
							nextState <= st_await_write_address;

						elsif (valid = "111") then
							nextAddress <= unsigned(AXI4L_m2s_int.AWAddr(OCRAM_ADDRESS_BITS + ADDR_LSB -1 downto ADDR_LSB));
							nextState   <= st_write_address_data;
						end if;

					when "100" => -- only write data
						nextState <= st_await_write_address;

					when "110" => -- write & address data
						nextAddress <= unsigned(AXI4L_m2s_int.AWAddr(OCRAM_ADDRESS_BITS + ADDR_LSB -1 downto ADDR_LSB));
						nextState   <= st_write_address_data;

					when others =>
						nextState   <= st_error;

				end case;

			when st_await_write_address =>
				if (AXI4L_m2s_int.AWValid = '1') then
					nextAddress <= unsigned(AXI4L_m2s_int.AWAddr(OCRAM_ADDRESS_BITS + ADDR_LSB -1 downto ADDR_LSB));
					nextState   <= st_write_address_data;
				end if;

			when st_await_write_data =>
				if (AXI4L_m2s_int.WValid = '1') then
					axi_awready <= '1';
					axi_wready  <= '1';
					axi_bvalid  <= '1';
					OCRAM_WriteEnable <= '1';

					if (AXI4L_m2s_int.BReady = '1') then
						nextState <= st_idle;
					else
						nextState <= st_write_response_wait;
					end if;
				end if;

			when st_write_address_data =>
				axi_awready <= '1';
				axi_wready  <= '1';
				axi_bvalid  <= '1';
				OCRAM_WriteEnable <= '1';

				if (AXI4L_m2s_int.BReady = '1') then
					nextState <= st_idle;
				else
					nextState <= st_write_response_wait;
				end if;

			when st_read_data_ack =>

				if not ADD_READ_DELAY then
					axi_arready <= '1';
					nextState   <= st_read_response_wait;
				else
					nextState   <= st_read_response_wait_delay;
				end if;

			when st_read_response_wait_delay =>
				axi_arready <= '1';
				nextState   <= st_read_response_wait;

			when st_write_response_wait =>
				axi_bvalid <= '1';

				if (AXI4L_m2s_int.BReady = '1') then
					nextState <= st_idle;
				end if;

			when st_read_response_wait =>
				axi_rvalid <= '1';

				if (AXI4L_m2s_int.RReady = '1') then
					nextState   <= st_idle;
				end if;

			when st_error => nextState <= st_idle;
		end case;

	end process;

end architecture;
