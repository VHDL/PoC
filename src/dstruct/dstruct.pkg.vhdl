-- =============================================================================
-- Authors:     Jens Voss
--
-- Package:     dstruct
--
-- Description
-- -----------
--   Package for component declarations, types and functions within the
--   namespace PoC.dstruct.
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

package dstruct is

	component dstruct_Stack is
		generic (
			DATA_BITS    : positive;              -- Data Width
			MIN_DEPTH : positive              -- Minimum Stack Depth
		);
		port (
			-- INPUTS
			Clock : in  std_logic;
			Reset : in  std_logic;

			-- Write Ports
			Put     : in  std_logic;  -- 0 -> top, 1 -> push
			DataIn  : in  std_logic_vector(DATA_BITS-1 downto 0);  -- Data Input
			Full    : out std_logic;

			-- Read Ports
			Got     : in  std_logic;
			DataOut : out std_logic_vector(DATA_BITS-1 downto 0);
			Valid   : out std_logic
		);
	end component dstruct_Stack;

	component dstruct_DoubleEndedQueue is
		generic (
			DATA_BITS    : positive;              -- Data Width
			MIN_DEPTH : positive              -- Minimum Deque Depth
		);
		port (
			-- Shared Ports
			Clock : in  std_logic;
			Reset : in  std_logic;

			-- Port A
			PortA_Put   : in  std_logic;
			PortA_DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);  -- DataA Input
			PortA_Full  : out std_logic;
			PortA_Got   : in  std_logic;
			PortA_DataOut  : out std_logic_vector(DATA_BITS-1 downto 0);  -- DataA Output
			PortA_Valid : out std_logic;

			-- Port B
			PortB_Put   : in  std_logic;
			PortB_DataIn   : in  std_logic_vector(DATA_BITS-1 downto 0);  -- DataB Input
			PortB_Full  : out std_logic;
			PortB_Got   : in  std_logic;
			PortB_DataOut  : out std_logic_vector(DATA_BITS-1 downto 0);
			PortB_Valid : out std_logic
		);
	end component dstruct_DoubleEndedQueue;

end package;
