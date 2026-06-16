-- =============================================================================
-- Authors:     Stefan Unrein
--
-- Entity:      Out of Order Buffer
--
-- When data (DataIn) is put in (Put = '1'), an index (IndexOut) is returned.
-- If later, this index is given to this component (IndexIn and Got = '1') the
-- Data of the corresponding index is returned.
-- IndexOut is hold and stable until data is Put into the buffer.
--
-- License:
-- =============================================================================
-- Copyright 2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
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
use     work.ocram.all;


entity dstruct_OutOfOrderBuffer is
	generic (
		DATA_BITS : positive;
		NUM_INDEX : positive
	);
	port (
		-- INPUTS
		Clock : in  std_logic;
		Reset : in  std_logic;

		-- Put Port
		Put      : in  std_logic;
		DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);
		Full     : out std_logic;
		IndexOut : out unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);

		-- Get Port
		Got      : in  std_logic;
		IndexIn  : in  unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);
		DataOut  : out std_logic_vector(DATA_BITS-1 downto 0);
		Valid    : out std_logic
	);
end entity;

architecture rtl of dstruct_OutOfOrderBuffer is
	subtype T_Data is std_logic_vector(DATA_BITS-1 downto 0);
	type    T_Data_Vector is array (natural range <>) of T_Data;    -- FIXME: T_SLVV

	signal IndexValid  : std_logic_vector(0 to NUM_INDEX -1) := (others => '0');
	signal DataBuffer  : T_Data_Vector(0 to NUM_INDEX -1)    := (others => (others => '0'));

	signal NextIndex    : unsigned(log2ceilnz(NUM_INDEX) -1 downto 0) := (others => '0');
	signal NextIndex_i  : unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);
	signal full_i    : std_logic := '0';
	signal full_next : std_logic;

	function get_next_Index(Used : std_logic_vector(0 to NUM_INDEX -1); NextIndex : unsigned(log2ceilnz(NUM_INDEX) -1 downto 0)) return unsigned is
	begin
		for i in 0 to NUM_INDEX -1 loop
			if Used(i) = '0' and i /= to_integer(NextIndex) then
				return to_unsigned(i, log2ceilnz(NUM_INDEX));
			end if;
		end loop;
		return to_unsigned(0, log2ceilnz(NUM_INDEX));
	end function;

begin
	IndexOut    <= NextIndex;
	Full        <= full_i;

	full_next   <= '1' when (not (unsigned(IndexValid) or reverse(unsigned(bin2onehot(NextIndex, NUM_INDEX))))) = 0 else '0'; --will the buffer be full with the next put?

	NextIndex_i <= get_next_Index(IndexValid, NextIndex);

	process(all)
	begin
		DataOut <= (others => '1');
		Valid   <= '0';
		if IndexIn < NUM_INDEX then -- range check for index
			DataOut     <= DataBuffer(to_integer(IndexIn));
			Valid       <= IndexValid(to_integer(IndexIn));
		end if;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				IndexValid <= (others => '0');
				NextIndex  <= (others => '0');
				full_i     <= '0';
			else
				if full_i = '0' and Put = '1' then
					IndexValid(to_integer(NextIndex))  <= '1';
					DataBuffer(to_integer(NextIndex))  <= DataIn;
					NextIndex  <= NextIndex_i;
					full_i     <= full_next;
				end if;

				if IndexIn < NUM_INDEX then -- range check for index
					if Got = '1' and IndexValid(to_integer(IndexIn)) = '1' then
						IndexValid(to_integer(IndexIn))  <= '0';
						full_i    <= '0';
						if full_next = '1' then
							NextIndex <= IndexIn;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

end architecture;
