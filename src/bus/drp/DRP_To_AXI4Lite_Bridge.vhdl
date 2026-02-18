-- =============================================================================
-- Authors:
--   Stefan Unrein
--
-- Entity:
--
-- Description:
-- -------------------------------------
-- An adapter from AXI4-Lite to DRP (dynamic reconfiguration port).
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
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils.all;
use work.axi4lite.all;
use work.drp.all;

entity DRP_To_AXI4Lite_Bridge is
	generic (
		DRP_COUNT     : positive := 1;
		DRP_ADDR_BITS : positive := 10 --Register Address, NO Word-Address; 10 bit for US+, 9 bit for US
	);
	port (
		Clock         : in std_logic;
		Reset         : in std_logic;
		-- IN Port
		AXI4Lite_M2S  : in  T_AXI4Lite_Bus_M2S;
		AXI4Lite_S2M  : out T_AXI4Lite_Bus_S2M;
		-- OUT Port
		DRP_M2S       : out T_DRP_Bus_M2S_VECTOR(0 to DRP_COUNT - 1);
		DRP_S2M       : in  T_DRP_Bus_S2M_VECTOR(0 to DRP_COUNT - 1)
	);
end entity;
architecture rtl of DRP_To_AXI4Lite_Bridge is
	constant DRP_DATA_BITS   : positive := 16;
	constant C_COUNT_BITS    : natural  := log2ceil(DRP_COUNT);
	constant C_AXI_ADDR_BITS : natural  := C_COUNT_BITS + DRP_ADDR_BITS;

	signal DRP_Enable      : std_logic_vector(0 to DRP_COUNT - 1);
	signal DRP_WriteEnable : std_logic_vector(0 to DRP_COUNT - 1);

	signal DRP_Address     : unsigned(DRP_ADDR_BITS - 1 downto 0);
	signal DRP_Address_d   : unsigned(DRP_ADDR_BITS - 1 downto 0)         := (others => '0');
	signal DRP_Address_En  : std_logic;

	signal DRP_DataIn      : std_logic_vector(DRP_DATA_BITS - 1 downto 0);
	signal DRP_DataIn_d    : std_logic_vector(DRP_DATA_BITS - 1 downto 0) := (others => '0');
	signal DRP_DataIn_En   : std_logic;

	signal DRP_DataOut_i   : std_logic_vector(DRP_DATA_BITS - 1 downto 0);
	signal DRP_DataOut_d   : std_logic_vector(DRP_DATA_BITS - 1 downto 0) := (others => '0');

	signal DRP_port_i      : unsigned(C_COUNT_BITS - 1 downto 0);
	signal DRP_port_d      : unsigned(C_COUNT_BITS - 1 downto 0)          := (others => '0');

	type T_State is (idle, read, read_wait, read_error, write, write_wait, write_error);
	signal State     : T_State := idle;
	signal State_nxt : T_State;
begin
	assert AXI4Lite_M2S.WData'length = 32 report "PoC.DRP_To_AXI4Lite_Bridge:: Bridge can only support 32bit data width for AXI4L!" severity failure;
	assert AXI4Lite_M2S.AWAddr'length >= C_AXI_ADDR_BITS +2  report "PoC.DRP_To_AXI4Lite_Bridge:: Not enough address bits in AXI4L!" severity failure;

	process (all)
	begin
		for i in 0 to DRP_COUNT - 1 loop
			DRP_M2S(i).Address     <= DRP_Address;
			DRP_M2S(i).DataIn      <= DRP_DataIn;
			DRP_M2S(i).Enable      <= DRP_Enable(i);
			DRP_M2S(i).WriteEnable <= DRP_WriteEnable(i);
		end loop;
	end process;

	process (Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				State <= Idle;
			else
				State <= State_nxt;
			end if;
		end if;
	end process;

	process (all)
		variable DRP_port : unsigned(C_COUNT_BITS - 1 downto 0) := (others => '0');
	begin
		State_nxt              <= State;
		DRP_Enable             <= (others => '0');
		DRP_WriteEnable        <= (others => '0');

		DRP_DataIn_En          <= '0';
		DRP_DataIn             <= DRP_DataIn_d;
		DRP_Address_En         <= '0';
		DRP_Address            <= DRP_Address_d;
		DRP_port               := (others => '0');
		DRP_port_i             <= DRP_port_d;
		DRP_DataOut_i          <= DRP_DataOut_d;

		AXI4Lite_S2M.AWReady <= '0';
		AXI4Lite_S2M.WReady  <= '0';
		AXI4Lite_S2M.BValid  <= '0';
		AXI4Lite_S2M.BResp   <= C_AXI4_RESPONSE_OKAY;
		AXI4Lite_S2M.RResp   <= C_AXI4_RESPONSE_OKAY;

		AXI4Lite_S2M.ARReady <= '0';
		AXI4Lite_S2M.RValid  <= '0';
		AXI4Lite_S2M.RData   <= (others => '0');

		case State is
			when Idle =>
				if (AXI4Lite_M2S.AWValid and AXI4Lite_M2S.WValid) = '1' then

					DRP_DataIn_En  <= '1';
					DRP_DataIn     <= AXI4Lite_M2S.WData(DRP_DATA_BITS -1 downto 0);
					DRP_Address_En <= '1';
					DRP_Address    <= unsigned(AXI4Lite_M2S.AWAddr(DRP_ADDR_BITS + 1 downto 2));
					DRP_port       := unsigned(AXI4Lite_M2S.AWAddr(C_AXI_ADDR_BITS + 1 downto DRP_ADDR_BITS + 2));
					DRP_port_i     <= DRP_port;
					AXI4Lite_S2M.AWReady <= '1';
					AXI4Lite_S2M.WReady  <= '1';

					if DRP_port < DRP_COUNT then
						DRP_Enable(to_integer(DRP_port))      <= '1';
						DRP_WriteEnable(to_integer(DRP_port)) <= '1';
						if DRP_S2M(to_integer(DRP_port)).Ready = '1' then
							State_nxt <= write_wait;
						else
							State_nxt <= write;
						end if;
					else
						State_nxt <= write_error;
					end if;
				elsif AXI4Lite_M2S.ARValid = '1' then
					DRP_Address_En <= '1';
					DRP_Address    <= unsigned(AXI4Lite_M2S.ARAddr(DRP_ADDR_BITS + 1 downto 2));
					DRP_port       := unsigned(AXI4Lite_M2S.ARAddr(C_AXI_ADDR_BITS + 1 downto DRP_ADDR_BITS + 2));
					DRP_port_i     <= DRP_port;
					AXI4Lite_S2M.ARReady <= '1';

					if DRP_port < DRP_COUNT then
						DRP_Enable(to_integer(DRP_port)) <= '1';
						if DRP_S2M(to_integer(DRP_port)).Ready = '1' then
							State_nxt          <= read_wait;
							AXI4Lite_S2M.RData <= resize(DRP_S2M(to_integer(DRP_port)).DataOut, AXI4Lite_S2M.RData'length);
							DRP_DataOut_i      <= DRP_S2M(to_integer(DRP_port)).DataOut;
						else
							State_nxt <= read;
						end if;
					else
						State_nxt <= read_error;
					end if;

				end if;

			when read =>
				if DRP_S2M(to_integer(DRP_port_d)).Ready = '1' then
					AXI4Lite_S2M.RValid <= '1';
					AXI4Lite_S2M.RData  <= resize(DRP_S2M(to_integer(DRP_port_d)).DataOut, AXI4Lite_S2M.RData'length);
					DRP_DataOut_i       <= DRP_S2M(to_integer(DRP_port_d)).DataOut;
					if AXI4Lite_M2S.RReady = '1' then
						State_nxt <= idle;
					else
						State_nxt <= read_wait;
					end if;
				end if;

			when read_wait =>
				AXI4Lite_S2M.RValid <= '1';
				AXI4Lite_S2M.RData  <= resize(DRP_DataOut_d, AXI4Lite_S2M.RData'length);
				if AXI4Lite_M2S.RReady = '1' then
					State_nxt <= idle;
				end if;

			when read_error =>
				AXI4Lite_S2M.RValid <= '1';
				AXI4Lite_S2M.RResp  <= C_AXI4_RESPONSE_DECODE_ERROR;
				AXI4Lite_S2M.RData  <= (others => '0');
				if AXI4Lite_M2S.RReady = '1' then
					State_nxt <= idle;
				end if;

			when write =>
				if DRP_S2M(to_integer(DRP_port_d)).Ready = '1' then
					AXI4Lite_S2M.BValid <= '1';
					if AXI4Lite_M2S.BReady = '1' then
						State_nxt <= idle;
					else
						State_nxt <= write_wait;
					end if;
				end if;
			when write_wait =>
				AXI4Lite_S2M.BValid <= '1';
				if AXI4Lite_M2S.BReady = '1' then
					State_nxt <= idle;
				end if;
			when write_error =>
				AXI4Lite_S2M.BValid <= '1';
				AXI4Lite_S2M.BResp  <= C_AXI4_RESPONSE_DECODE_ERROR;
				if AXI4Lite_M2S.BReady = '1' then
					State_nxt <= idle;
				end if;
		end case;
	end process;

	DRP_DataOut_d <= DRP_DataOut_i when rising_edge(Clock);
	DRP_DataIn_d  <= DRP_DataIn    when rising_edge(Clock) and DRP_DataIn_En = '1';
	DRP_Address_d <= DRP_Address   when rising_edge(Clock) and DRP_Address_En = '1';
	DRP_port_d    <= DRP_port_i    when rising_edge(Clock);

end architecture;
