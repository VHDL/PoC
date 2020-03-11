-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2017-2019 PLC2 Design GmbH - Freiburg, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

use			work.utils.all;
use			work.vectors.all;
use			work.physical.all;

entity stream_Statistics is
	generic (
		Count_Bits				: positive									:= 16;
		Clock_Frequency   : FREQ                      := 300 MHz;
		BE_Bits           : positive									:= 8;
		Tik_Time          : T_Time                    := 1.0e-3
	);
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;
		-- IN Ports
		In_Valid					: in	std_logic;
		In_BE   					: in	std_logic_vector(BE_Bits -1 downto 0);
		In_SOF						: in	std_logic;
		In_EOF						: in	std_logic;
		In_Ack						: in	std_logic;
		
		Overflow          : out std_logic;
		Tik               : out std_logic;
		Total_Bytes       : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Total_SoF         : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Total_EoF         : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Total_Pause       : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Total_Transfer    : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Total_W8Ack       : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Tik_Bytes         : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Tik_SoF           : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Tik_EoF           : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Tik_Pause         : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Tik_Transfer      : out unsigned(Count_Bits -1 downto 0) := (others => '0');
		Tik_W8Ack         : out unsigned(Count_Bits -1 downto 0) := (others => '0')
	);
end entity;


architecture rtl of stream_Statistics is
	constant Tik_Cycles : natural := TimingToCycles(Tik_Time, Clock_Frequency);
	
	signal Tik_i            : std_logic;
	signal Tik_count        : unsigned(log2ceilnz(Tik_Cycles +1) downto 0) := (others => '0');
	signal Total_Bytes_i    : unsigned(Count_Bits downto 0) := (others => '0');
	signal Total_SoF_i      : unsigned(Count_Bits downto 0) := (others => '0');
	signal Total_EoF_i      : unsigned(Count_Bits downto 0) := (others => '0');
	signal Total_Pause_i    : unsigned(Count_Bits downto 0) := (others => '0');
	signal Total_Transfer_i : unsigned(Count_Bits downto 0) := (others => '0');
	signal Total_W8Ack_i    : unsigned(Count_Bits downto 0) := (others => '0');
	signal Tik_Bytes_i      : unsigned(Count_Bits downto 0) := (others => '0');
	signal Tik_SoF_i        : unsigned(Count_Bits downto 0) := (others => '0');
	signal Tik_EoF_i        : unsigned(Count_Bits downto 0) := (others => '0');
	signal Tik_Pause_i      : unsigned(Count_Bits downto 0) := (others => '0');
	signal Tik_Transfer_i   : unsigned(Count_Bits downto 0) := (others => '0');
	signal Tik_W8Ack_i      : unsigned(Count_Bits downto 0) := (others => '0');
begin
	Tik      <= Tik_i when rising_edge(Clock);
	Overflow <= Total_Bytes_i(Count_Bits) or Total_SoF_i(Count_Bits) or  Total_EoF_i(Count_Bits) or  Total_Pause_i(Count_Bits)
	            or Total_Transfer_i(Count_Bits) or  Total_W8Ack_i(Count_Bits);
	
	count_proc : process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset or Tik_i) = '1' then
				Tik_count <= (others => '0');
			else
				Tik_count <= Tik_count +1;
			end if;
		end if;
	end process;
	Tik_i <= '1' when Tik_count = (Tik_Cycles -1) else '0';
	
	tik_proc : process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset or Tik_i) = '1' then
				Tik_Bytes_i    <= (others => '0');
				Tik_SoF_i      <= (others => '0');
				Tik_EoF_i      <= (others => '0');
				Tik_Pause_i    <= (others => '0');
				Tik_Transfer_i <= (others => '0');
				Tik_W8Ack_i    <= (others => '0');
				
				Tik_Bytes      <= Tik_Bytes_i(Tik_Bytes'range);
				Tik_SoF        <= Tik_SoF_i(Tik_SoF'range);
				Tik_EoF        <= Tik_EoF_i(Tik_EoF'range) ;
				Tik_Pause      <= Tik_Pause_i(Tik_Pause'range);
				Tik_Transfer   <= Tik_Transfer_i(Tik_Transfer'range);
				Tik_W8Ack      <= Tik_W8Ack_i(Tik_W8Ack'range);
				
			elsif (In_Valid and In_Ack) = '1' then
				Tik_Transfer_i <= Tik_Transfer_i +1;
				Tik_Bytes_i    <= to_unsigned(In_BE'high +1,Count_Bits +1) + Tik_Bytes_i;
				if In_SOF = '1' then
					Tik_SoF_i   <= Tik_SoF_i +1;
				end if;
				if In_EOF = '1' then
					Tik_Bytes_i <= to_unsigned(mssb_idx(In_BE) +1,Count_Bits +1) + Tik_Bytes_i;
					Tik_EoF_i   <= Tik_EoF_i +1;
				end if;
			else
				if In_Ack = '0' and In_Valid = '1' then
					Tik_W8Ack_i <= Tik_W8Ack_i +1;
				end if;
				Tik_Pause_i <= Tik_Pause_i +1;
			end if;
		end if;
	end process;
	
	total_proc : process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				Total_Bytes_i    <= (others => '0');
				Total_SoF_i      <= (others => '0');
				Total_EoF_i      <= (others => '0');
				Total_Pause_i    <= (others => '0');
				Total_Transfer_i <= (others => '0');
				Total_W8Ack_i    <= (others => '0');
			elsif (In_Valid and In_Ack) = '1' then
				Total_Transfer_i <= Total_Transfer_i +1;
				Total_Bytes_i    <= to_unsigned(In_BE'high +1,Count_Bits +1) + Total_Bytes_i;
				if In_SOF = '1' then
					Total_SoF_i   <= Total_SoF_i +1;
				end if;
				if In_EOF = '1' then
					Total_Bytes_i <= to_unsigned(mssb_idx(In_BE) +1,Count_Bits +1) + Total_Bytes_i;
					Total_EoF_i   <= Total_EoF_i +1;
				end if;
			else
				if In_Ack = '0' and In_Valid = '1' then
					Total_W8Ack_i <= Total_W8Ack_i +1;
				end if;
				Total_Pause_i <= Total_Pause_i +1;
			end if;
		end if;
	end process;

	Total_Bytes    <= Total_Bytes_i(Total_Bytes'range) when rising_edge(Clock);
	Total_EoF      <= Total_EoF_i(Total_EoF'range) when rising_edge(Clock);
	Total_SoF      <= Total_SoF_i(Total_SoF'range) when rising_edge(Clock);
	Total_Pause    <= Total_Pause_i(Total_Pause'range) when rising_edge(Clock);
	Total_Transfer <= Total_Transfer_i(Total_Transfer'range) when rising_edge(Clock);
	Total_W8Ack    <= Total_W8Ack_i(Total_W8Ack'range) when rising_edge(Clock);
end architecture;
