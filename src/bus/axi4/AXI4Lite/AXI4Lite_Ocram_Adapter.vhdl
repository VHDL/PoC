-- =============================================================================
-- Authors:
--   Iqbal Asif
--   Patrick Lehmann
--
-- Entity:
--
-- Description:
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
--		http://www.apache.org/licenses/LICENSE-2.0
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


use work.utils.all;
use work.axi4lite.all;

entity AXI4Lite_Ocram_Adapter is
	generic (
		OCRAM_ADDRESS_BITS    : positive;
		OCRAM_DATA_BITS       : positive;
		PREFFERED_READ_ACCESS : boolean := TRUE
	);
	port (
		Clock    : in std_logic;
		Reset    : in std_logic;

		AXI4Lite_m2s : in  T_AXI4Lite_Bus_M2S;
		AXI4Lite_s2m : out T_AXI4Lite_Bus_S2M;

		Write_En : out std_logic;
		Address  : out unsigned(OCRAM_ADDRESS_BITS-1 downto 0);
		Data_In  : in  std_logic_vector(OCRAM_DATA_BITS-1 downto 0);
		Data_Out : out std_logic_vector(OCRAM_DATA_BITS-1 downto 0)
	);
end entity;

architecture rtl of AXI4Lite_Ocram_Adapter is
	constant ADDRESS_BITS     : positive := AXI4Lite_m2s.AWAddr'length;
	constant DATA_BITS        : positive := AXI4Lite_m2s.WData'length;
	constant DATA_BITS_intern : positive := 32;
	constant ADDR_LSB         : positive  := log2ceil(DATA_BITS_intern) - 3;

	-- AXI4LITE signals
	signal axi_awaddr : std_logic_vector(ADDRESS_BITS - ADDR_LSB - 1 downto 0) := (others => '0');
	signal axi_awready: std_logic := '0';
	signal axi_wready : std_logic := '0';
	signal axi_bresp  : std_logic_vector(1 downto 0) := "00";
	signal axi_bvalid : std_logic := '0';
	signal axi_araddr : std_logic_vector(ADDRESS_BITS - ADDR_LSB - 1 downto 0) := (others => '0');
	signal axi_arready: std_logic := '0';
	signal axi_rdata  : std_logic_vector(DATA_BITS - 1 downto 0) := (others => '0');
	signal axi_rresp  : std_logic_vector(1 downto 0)  := "00";
	signal axi_rvalid : std_logic := '0';

	type t_state is (
		st_idle,
		st_await_write_address,
		st_await_write_data,
		st_write_address_data,
		st_read_data_ack,
		st_write_response_wait,
		st_read_response_wait,
		st_error
	);

	signal currentstate : t_state := st_idle;
	signal nextstate    : t_state;

begin
	AXI4Lite_s2m.AWReady <= axi_awready;
	AXI4Lite_s2m.WReady  <= axi_wready;
	AXI4Lite_s2m.BResp   <= axi_bresp;
	AXI4Lite_s2m.BValid  <= axi_bvalid;
	AXI4Lite_s2m.ARReady <= axi_arready;
	AXI4Lite_s2m.RData   <= axi_rdata;
	AXI4Lite_s2m.RResp   <= axi_rresp;
	AXI4Lite_s2m.RValid  <= axi_rvalid;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				currentstate <= st_idle;
			else
				currentstate <= nextstate;
			end if;
		end if;
	end process;

	process(all)
	 variable valid : std_logic_vector(2 downto  0);
	begin
		nextstate   <= currentstate;
		Address     <= resize(unsigned(AXI4Lite_m2s.AWAddr), Address'length) ;
		Write_En    <= '0';
		axi_awready <= '0';
		axi_wready  <= '0';
		axi_arready <= '0';
		axi_rvalid  <= '0';
		axi_bvalid  <= '0';
		axi_bresp   <= C_AXI4_RESPONSE_OKAY;
		axi_rresp   <= C_AXI4_RESPONSE_OKAY;
    valid       := AXI4Lite_m2s.WValid & AXI4Lite_m2s.AWValid & AXI4Lite_m2s.ARValid;

		case currentstate is

			when st_idle =>

        case valid is

          when "001" => -- only read address
						Address     <= resize(unsigned(AXI4Lite_m2s.ARAddr), Address'length) ;
						nextstate   <= st_read_data_ack;

          when "010" => -- only write address
						nextstate <= st_await_write_data;

          when "011" | "101" | "111" => -- read and write address at the same time
            if (PREFFERED_READ_ACCESS = TRUE) then
              Address     <= resize(unsigned(AXI4Lite_m2s.ARAddr), Address'length) ;
              nextstate   <= st_read_data_ack;
            elsif (valid = "011" ) then
              nextstate <= st_await_write_data;
            elsif (valid = "101" ) then
              nextstate <= st_await_write_address;
            elsif (valid = "111" ) then
              nextstate <= st_write_address_data;
            end if;

          when "100" => -- only write data
						nextstate <= st_await_write_address;

          when "110" => -- write & address data
            nextstate <= st_write_address_data;

          when others =>

        end case;

      when st_await_write_address =>
        if (AXI4Lite_m2s.AWValid = '1') then
          axi_awready <= '1';
          axi_wready  <= '1';
          Write_En    <= '1';
          axi_bvalid  <= '1';
          if (AXI4Lite_m2s.BReady = '1') then
            nextstate <= st_idle;
          else
            nextstate <= st_write_response_wait;
          end if;
        end if;

      when st_await_write_data =>
				Address   <= resize(unsigned(AXI4Lite_m2s.AWAddr), Address'length) ;
        if (AXI4Lite_m2s.WValid = '1') then
          axi_awready <= '1';
          axi_wready  <= '1';
          Write_En    <= '1';
          axi_bvalid  <= '1';
          if (AXI4Lite_m2s.BReady = '1') then
            nextstate <= st_idle;
          else
            nextstate <= st_write_response_wait;
          end if;
        end if;

      when st_write_address_data =>
				Address   <= resize(unsigned(AXI4Lite_m2s.AWAddr), Address'length) ;
        axi_awready <= '1';
        axi_wready  <= '1';
        Write_En    <= '1';
        axi_bvalid  <= '1';
        if (AXI4Lite_m2s.BReady = '1') then
          nextstate <= st_idle;
        else
          nextstate <= st_write_response_wait;
        end if;

			when st_read_data_ack =>
        axi_rvalid <= '1';
				Address    <= resize(unsigned(AXI4Lite_m2s.ARAddr), Address'length) ;
        if (AXI4Lite_m2s.RReady = '1') then
          axi_arready <= '1';
          nextstate <= st_idle;
        else
          nextstate <= st_read_response_wait;
        end if;

			when st_write_response_wait =>
        axi_bvalid  <= '1';
        if (AXI4Lite_m2s.BReady = '1') then
          nextstate <= st_idle;
        end if;

			when st_read_response_wait =>
        axi_rvalid  <= '1';
        if (AXI4Lite_m2s.RReady = '1') then
          axi_arready <= '1';
          nextstate   <= st_idle;
        end if;

			when st_error => nextstate <= st_idle;

			when others => nextstate <= st_idle;

		end case;

	end process;

  Data_Out  <= resize(AXI4Lite_m2s.WData, Data_Out'length);
  axi_rdata <= resize(Data_In, axi_rdata'length);

end architecture;

