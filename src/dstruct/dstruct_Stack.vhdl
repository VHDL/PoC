-- =============================================================================
-- Authors:     Jens Voss
--
-- Entity:      Stack (LIFO)
--
-- Description:
-- -------------------------------------
-- Implements a stack, a LIFO storage abstraction.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--              http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;


entity dstruct_Stack is
	generic (
		DATA_BITS : positive;               -- Data Width
		MIN_DEPTH : positive                -- Minimum Stack Depth
	);
	port (
		-- INPUTS
		Clock   : in  std_logic;
		Reset   : in  std_logic;

		-- Write Ports
		Put     : in  std_logic;  -- 0 -> top, 1 -> push
		DataIn  : in  std_logic_vector(DATA_BITS-1 downto 0);  -- Data Input
		Full    : out std_logic;

		-- Read Ports
		Got     : in  std_logic;
		DataOut : out std_logic_vector(DATA_BITS-1 downto 0);
		Valid   : out std_logic
	);
end entity;


library IEEE;
use     IEEE.numeric_std.all;

use     work.config.all;
use     work.utils.all;
use     work.ocram.all;

architecture rtl of dstruct_Stack is

		-- Constants
		constant ADDRESS_BITS : natural := log2ceil(MIN_DEPTH);

		-- Signals
		signal stackpointer : unsigned(ADDRESS_BITS-1 downto 0) := (others => '0');
		signal we : std_logic := '0';
		signal adr : unsigned(ADDRESS_BITS-1 downto 0) := (others => '0');
		signal s_adr : unsigned(ADDRESS_BITS-1 downto 0) := (others => '0');
		signal s_dout : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
		signal s_valid : std_logic := '0';
		signal s_din : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');

		-- ctrl signal for stackpointer operations
		type ctrl_t is (PUSH, POP, NOOP);
		signal ctrl : ctrl_t;

		type state is (SEMPTY, NOTFULL, WAITING, SFULL);
		signal current_state, next_state : state; -- current and next state

begin

	-- Backing Memory
	ram : entity work.ocram_SinglePort
		generic map(
			ADDRESS_BITS => ADDRESS_BITS,
			DATA_BITS => DATA_BITS,
			FILENAME => ""
		)
		port map(
			Clock => Clock,
			ClockEnable  => '1',
			WriteEnable  => we,
			Address  => adr,
			DataIn  => s_din,
			DataOut  => s_dout
		);

	process(Clock)
	begin
		if rising_edge(Clock) then
			if(Reset = '1') then
				current_state <= SEMPTY;
			else
				current_state <= next_state;
			end if;
		end if;
	end process;

	process(current_state, Put, stackpointer, Got)
	begin
		ctrl <= NOOP;
		we <= '0';
		s_adr <= (others =>'0');
		Valid <= '1';
		Full <= '0';
		case( current_state ) is
			when SEMPTY =>
				Valid <= '0';
				next_state <= SEMPTY;
				if(Put = '1') then
					-- push to empty stack!
					next_state <= NOTFULL;
					ctrl <= PUSH;
					we <= '1';
				else
					-- enable is 0 -> do nothing
					ctrl <= NOOP;
				end if;
			when NOTFULL=>
				next_state <= NOTFULL;
				s_adr <= stackpointer - 1;
				if(Got = '1' and Put = '0') then
					ctrl <= POP;
					s_adr <= stackpointer - 2;
					if stackpointer = 1 then
						-- last value popped from stack -> empty
						next_state <= SEMPTY;
					end if;
				elsif (Got = '0' and Put = '1') then
					-- push to Stack
					ctrl <= PUSH;
					s_adr <= stackpointer;
					we <= '1';
					if stackpointer = (MIN_DEPTH - 1) then
							next_state <= SFULL;
					end if;
				elsif (Got = '1' and Put = '1') then
					-- overwrite ToS
					we <= '1';
					ctrl <= NOOP;
				else
					-- do nothing
					ctrl <= NOOP;
				end if;
			when SFULL=>
				next_state <= SFULL;
				Full <= '1';
				s_adr <= stackpointer-1;
				if(Got = '1') then
					-- pop from Stack
					ctrl <= POP;
					next_state <= NOTFULL;
					s_adr <= stackpointer-2;
				else
					-- got is 0 -> do nothing
					ctrl <= NOOP;
				end if;
			when others =>
				ctrl <= NOOP;
				next_state <= SEMPTY;
		end case;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			case ctrl is
				when NOOP => stackpointer <= stackpointer;
				when PUSH => stackpointer <= stackpointer + 1;
				when POP =>  stackpointer <= stackpointer - 1;
			end case;
		end if;
	end process;

	s_din <= DataIn;
	DataOut <= s_dout;

	-- map local signals to ports
	adr <= s_adr;
end architecture;
