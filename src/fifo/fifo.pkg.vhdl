-- =============================================================================
-- Authors:          Thomas B. Preusser
--                  Steffen Koehler
--                  Martin Zabel
--                  Patrick Lehmann
--
-- Package:          VHDL package for component declarations, types and functions
--                  associated to the PoC.fifo namespace
--
-- Description:
-- -------------------------------------
--    For detailed documentation see below.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany,
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

use     work.utils.all;


package fifo is

	-- Minimal FIFO with single clock to decouple enable domains.
	component fifo_Stage
		generic (
			DATA_BITS       : positive;
			STAGES       : natural := 1;
			LIGHT_WEIGHT : boolean := FALSE
		);
		port (
			-- Control
			Clock : in  std_logic;                 -- Clock
			Reset : in  std_logic;                 -- Synchronous Reset

			-- Input
			Put : in  std_logic;                            -- Put Value
			DataIn  : in  std_logic_vector(DATA_BITS - 1 downto 0);  -- Data Input
			Full : out std_logic;                            -- Full

			-- Output
			Valid : out std_logic;                            -- Data Available
			DataOut  : out std_logic_vector(DATA_BITS - 1 downto 0);  -- Data Output
			Got : in  std_logic                             -- Data Consumed
		);
	end component;

	-- Simple FIFO backed by a shift register.
	component fifo_Shift
		generic (
			DATA_BITS    : positive;               -- Data Width
			MIN_DEPTH : positive                -- Minimum FIFO Size in Words
		);
		port (
			-- Global Control
			Clock : in  std_logic;
			Reset : in  std_logic;

			-- Writing Interface
			Put : in  std_logic;                            -- Write Request
			DataIn : in  std_logic_vector(DATA_BITS - 1 downto 0);  -- Input Data
			Full : out std_logic;                            -- Capacity Exhausted

			-- Reading Interface
			Got  : in  std_logic;                            -- Read Done Strobe
			DataOut : out std_logic_vector(DATA_BITS - 1 downto 0);  -- Output Data
			Valid  : out std_logic                             -- Data Valid
		);
	end component;

	-- Full-fledged FIFO with single clock domain using on-chip RAM.
	component fifo_cc_got
		generic (
			DATA_BITS         : positive;          -- Data Width
			MIN_DEPTH      : positive;          -- Minimum FIFO Depth
			DATA_REG       : boolean := false;  -- Store Data Content in Registers
			STATE_REG      : boolean := false;  -- Registered Full/Empty Indicators
			OUTPUT_REG     : boolean := false;  -- Registered FIFO Output
			EMPTY_STATE_BITS : natural := 0;      -- Empty State Bits
			FILL_STATE_BITS : natural := 0       -- Full State Bits
		);
		port (
			-- Global Reset and Clock
			Reset, Clock : in  std_logic;

			-- Writing Interface
			Put       : in  std_logic;                            -- Write Request
			DataIn       : in  std_logic_vector(DATA_BITS - 1 downto 0);  -- Input Data
			Full      : out std_logic;
			EmptyState : out std_logic_vector(imax(0, EMPTY_STATE_BITS - 1) downto 0);

			-- Reading Interface
			Got       : in  std_logic;                            -- Read Completed
			DataOut      : out std_logic_vector(DATA_BITS - 1 downto 0);  -- Output Data
			Valid     : out std_logic;
			FillState : out std_logic_vector(imax(0, FILL_STATE_BITS - 1) downto 0)
		);
	end component;

	component fifo_ic_got
		generic (
			DATA_BITS         : positive;          -- Data Width
			MIN_DEPTH      : positive;          -- Minimum FIFO Depth
			DATA_REG       : boolean := false;  -- Store Data Content in Registers
			OUTPUT_REG     : boolean := false;  -- Registered FIFO Output
			EMPTY_STATE_BITS : natural := 0;      -- Empty State Bits
			FILL_STATE_BITS : natural := 0       -- Full State Bits
		);
		port (
			-- Write Interface
			clk_wr    : in  std_logic;
			rst_wr    : in  std_logic;
			put       : in  std_logic;
			din       : in  std_logic_vector(DATA_BITS - 1 downto 0);
			full      : out std_logic;
			estate_wr : out std_logic_vector(imax(EMPTY_STATE_BITS - 1, 0) downto 0);

			-- Read Interface
			clk_rd    : in  std_logic;
			rst_rd    : in  std_logic;
			got       : in  std_logic;
			valid     : out std_logic;
			dout      : out std_logic_vector(DATA_BITS - 1 downto 0);
			fstate_rd : out std_logic_vector(imax(FILL_STATE_BITS - 1, 0) downto 0)
		);
	end component;

	component fifo_cc_got_tempput
		generic (
			DATA_BITS         : positive;          -- Data Width
			MIN_DEPTH      : positive;          -- Minimum FIFO Depth
			DATA_REG       : boolean := false;  -- Store Data Content in Registers
			STATE_REG      : boolean := false;  -- Registered Full/Empty Indicators
			OUTPUT_REG     : boolean := false;  -- Registered FIFO Output
			EMPTY_STATE_BITS : natural := 0;      -- Empty State Bits
			FILL_STATE_BITS : natural := 0       -- Full State Bits
			);
		port (
			-- Global Reset and Clock
			Reset, Clock : in  std_logic;

			-- Writing Interface
			Put       : in  std_logic;                            -- Write Request
			DataIn       : in  std_logic_vector(DATA_BITS - 1 downto 0);  -- Input Data
			Full      : out std_logic;
			EmptyState : out std_logic_vector(imax(0, EMPTY_STATE_BITS - 1) downto 0);

			Commit    : in  std_logic;
			Rollback  : in  std_logic;

			-- Reading Interface
			Got       : in  std_logic;                            -- Read Completed
			DataOut      : out std_logic_vector(DATA_BITS - 1 downto 0);  -- Output Data
			Valid     : out std_logic;
			FillState : out std_logic_vector(imax(0, FILL_STATE_BITS - 1) downto 0)
			);
	end component;

	component fifo_cc_got_tempgot is
		generic (
			DATA_BITS         : positive;          -- Data Width
			MIN_DEPTH      : positive;          -- Minimum FIFO Depth
			DATA_REG       : boolean := false;  -- Store Data Content in Registers
			STATE_REG      : boolean := false;  -- Registered Full/Empty Indicators
			OUTPUT_REG     : boolean := false;  -- Registered FIFO Output
			EMPTY_STATE_BITS : natural := 0;      -- Empty State Bits
			FILL_STATE_BITS : natural := 0       -- Full State Bits
		);
		port (
			-- Global Reset and Clock
			Reset, Clock : in  std_logic;

			-- Writing Interface
			Put       : in  std_logic;                            -- Write Request
			DataIn       : in  std_logic_vector(DATA_BITS - 1 downto 0);  -- Input Data
			Full      : out std_logic;
			EmptyState : out std_logic_vector(imax(0, EMPTY_STATE_BITS - 1) downto 0);

			-- Reading Interface
			Got       : in  std_logic;                            -- Read Completed
			DataOut      : out std_logic_vector(DATA_BITS - 1 downto 0);  -- Output Data
			Valid     : out std_logic;
			FillState : out std_logic_vector(imax(0, FILL_STATE_BITS - 1) downto 0);

			Commit    : in  std_logic;
			Rollback  : in  std_logic
		);
	end component;

	component fifo_ic_assembly is
		generic (
			D_BITS : positive;                  -- Data Width
			A_BITS : positive;                  -- Address Bits
			G_BITS : positive                    -- Generation Guard Bits
		);
		port (
			-- Write Interface
			clk_wr : in  std_logic;
			rst_wr : in  std_logic;

			-- Only write addresses in the range [base, base+2**(A_BITS-G_BITS)) are
			-- acceptable. This is equivalent to the test
			--   tmp(A_BITS-1 downto A_BITS-G_BITS) = 0 where tmp = addr - base.
			-- Writes performed outside the allowable range will assert the failure
			-- indicator, which will stick until the next reset.
			-- No write is to be performed before base turns zero (0) for the first
			-- time.
			base   : out std_logic_vector(A_BITS-1 downto 0);
			failed : out std_logic;

			addr : in  std_logic_vector(A_BITS-1 downto 0);
			din  : in  std_logic_vector(D_BITS-1 downto 0);
			put  : in  std_logic;

			-- Read Interface
			clk_rd : in  std_logic;
			rst_rd : in  std_logic;

			dout : out std_logic_vector(D_BITS-1 downto 0);
			vld  : out std_logic;
			got  : in  std_logic
		);
	end component;

end package;
