-- =============================================================================
-- Authors:    Patrick Lehmann
--             Stefan Unrein
--
-- Entity:     Generic arbiter
--
-- Description:
-- -------------------------------------
-- This module implements a generic arbiter. It currently supports the
-- following arbitration strategies:
--
-- * Round Robin (RR)
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
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

entity bus_Arbiter is
	generic (
		STRATEGY   : string   := "RR"; -- RR, LOT
		PORTS      : positive := 1;
		WEIGHTS    : integer_vector := (0 => 1);
		OUTPUT_REG : boolean  := FALSE
	);
	port (
		Clock : in  std_logic;
		Reset : in  std_logic;

		Arbitrate     : in  std_logic;
		RequestVector : in  std_logic_vector(PORTS - 1 downto 0);

		Arbitrated  : out std_logic;
		GrantVector : out std_logic_vector(PORTS - 1 downto 0);
		GrantIndex  : out unsigned(log2ceilnz(PORTS) - 1 downto 0)
	);
end entity;
architecture rtl of bus_Arbiter is
	attribute KEEP         : boolean;
	attribute FSM_ENCODING : string;

begin
	-- XXX: How does arith_FirstOne relate to an arbiter and to RR or Priority arbitration?
	gen_Strategy : if STRATEGY = "RR" generate -- Round Robin Arbiter
		signal RequestLeft : unsigned(PORTS - 1 downto 0);
		signal SelectLeft  : unsigned(PORTS - 1 downto 0);
		signal SelectRight : unsigned(PORTS - 1 downto 0);

		signal ChannelPointer_d   : std_logic_vector(PORTS - 1 downto 0) := to_slv(1, PORTS);
		signal ChannelPointer_nxt : std_logic_vector(PORTS - 1 downto 0);

	begin

		RequestLeft        <= (not ((unsigned(ChannelPointer_d) - 1) or unsigned(ChannelPointer_d))) and unsigned(RequestVector);
		SelectLeft         <= (unsigned(not RequestLeft) + 1) and RequestLeft; -- Is the next index above the current pointer
		SelectRight        <= (unsigned(not RequestVector) + 1) and unsigned(RequestVector); -- Is the first index that is requested from 0 (including self)
		ChannelPointer_nxt <= std_logic_vector(ite((RequestLeft = (RequestLeft'range => '0')), SelectRight, SelectLeft));

		genREG : if OUTPUT_REG generate
			signal ChannelPointer_bin_d : unsigned(log2ceilnz(PORTS) - 1 downto 0) := (others => '0');
		begin
			process (Clock)
			begin
				if rising_edge(Clock) then
					Arbitrated   <= '0';

					if (Reset = '1') then
						ChannelPointer_d     <= to_slv(1, PORTS);
						ChannelPointer_bin_d <= (others => '0');

					elsif (Arbitrate = '1') then
						Arbitrated   <= '1';
						ChannelPointer_d      <= ChannelPointer_nxt;
						ChannelPointer_bin_d  <= onehot2bin(ChannelPointer_nxt);
					end if;
				end if;
			end process;

			GrantVector <= ChannelPointer_d;
			GrantIndex  <= ChannelPointer_bin_d;

		else generate
			process (Clock)
			begin
				if rising_edge(Clock) then
					if (Reset = '1') then
						ChannelPointer_d     <= to_slv(1, PORTS);

					elsif (Arbitrate = '1') then
						ChannelPointer_d      <= ChannelPointer_nxt;
					end if;
				end if;
			end process;

			Arbitrated  <= Arbitrated;
			GrantVector <= ChannelPointer_nxt;
			GrantIndex  <= onehot2bin(ChannelPointer_nxt);

		end generate;

	-- elsif STRATEGY = "LOT" generate -- Lottery Arbiter
	-- elsif STRATEGY = "WRR" generate -- Weighted Round Robin Arbiter

	else generate
		assert false report "PoC.bus_Arbiter:: Strategy '" & STRATEGY & "' not implemented!" severity failure;
	end generate;

end architecture;
