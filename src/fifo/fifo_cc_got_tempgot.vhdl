-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Steffen Koehler
--                  Martin Zabel
--                  Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:          FIFO, common clock (cc), pipelined interface, reads only become effective after explicit commit
--
-- Description:
-- -------------------------------------
-- The specified depth (``MIN_DEPTH``) is rounded up to the next suitable value.
--
-- As uncommitted reads occupy FIFO space that is not yet available for
-- writing, an instance of this FIFO can, indeed, report ``full`` and ``not vld``
-- at the same time. While a ``commit`` would eventually make space available for
-- writing (``not ful``), a ``rollback`` would re-iterate data for reading
-- (``vld``).
--
-- ``commit`` and ``rollback`` are inclusive and apply to all reads (``got``) since
-- the previous ``commit`` or ``rollback`` up to and including a potentially
-- simultaneous read.
--
-- The FIFO state upon a simultaneous assertion of ``commit`` and ``rollback`` is
-- *undefined*!
--
-- ``*STATE_*_BITS`` defines the granularity of the fill state indicator
-- ``*state_*``. ``fstate_rd`` is associated with the read clock domain and outputs
-- the guaranteed number of words available in the FIFO. ``estate_wr`` is
-- associated with the write clock domain and outputs the number of words that
-- is guaranteed to be accepted by the FIFO without a capacity overflow. Note
-- that both these indicators cannot replace the ``full`` or ``valid`` outputs as
-- they may be implemented as giving pessimistic bounds that are minimally off
-- the true fill state.
--
-- If a fill state is not of interest, set ``*STATE_*_BITS = 0``.
--
-- ``fstate_rd`` and ``estate_wr`` are combinatorial outputs and include an address
-- comparator (subtractor) in their path.
--
-- **Examples:**
--
-- * FSTATE_RD_BITS = 1:
--
--   * fstate_rd == 0 => 0/2 full
--   * fstate_rd == 1 => 1/2 full (half full)
--
-- * FSTATE_RD_BITS = 2:
--
--   * fstate_rd == 0 => 0/4 full
--   * fstate_rd == 1 => 1/4 full
--   * fstate_rd == 2 => 2/4 full
--   * fstate_rd == 3 => 3/4 full
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany,
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

use     work.config.all;
use     work.mem.all;
use     work.utils.all;
use     work.ocram.ocram_SimpleDualPort;

entity fifo_cc_got_tempgot is
	generic (
		RAM_TYPE         : T_RAM_TYPE := RAM_TYPE_OPTIMIZED;--RAM_TYPE_AUTO;
		DATA_BITS        : positive;         -- Data Width
		MIN_DEPTH        : positive;         -- Minimum FIFO Depth
		DATA_REG         : boolean := false; -- Store Data Content in Registers
		STATE_REG        : boolean := false; -- Registered Full/Empty Indicators
		OUTPUT_REG       : boolean := false; -- Registered FIFO Output
		EMPTY_STATE_BITS : natural := 0;     -- Empty State Bits
		FILL_STATE_BITS  : natural := 0      -- Full State Bits
	);
	port (
		-- Global Reset and Clock
		Clock      : in  std_logic;
		Reset      : in  std_logic;

		-- Writing Interface
		Put        : in  std_logic;                             -- Write Request
		DataIn     : in  std_logic_vector(DATA_BITS - 1 downto 0); -- Input Data
		Full       : out std_logic;
		EmptyState : out std_logic_vector(imax(0, EMPTY_STATE_BITS - 1) downto 0);

		-- Reading Interface
		Got        : in  std_logic;                              -- Read Completed
		DataOut    : out std_logic_vector(DATA_BITS - 1 downto 0); -- Output Data
		Valid      : out std_logic;
		FillState  : out std_logic_vector(imax(0, FILL_STATE_BITS - 1) downto 0);

		Commit     : in  std_logic;
		Rollback   : in  std_logic
	);
end entity;

architecture rtl of fifo_cc_got_tempgot is

	-- Address Width
	constant ADDRESS_BITS : natural := log2ceil(MIN_DEPTH);

	-- Force Carry-Chain Use for Pointer Increments on Xilinx Architectures
	constant FORCE_XILCY : boolean := (not SIMULATION) and (VENDOR = VENDOR_XILINX) and STATE_REG and (ADDRESS_BITS > 4);

	-----------------------------------------------------------------------------
	-- Memory Pointers

	-- Actual Input and Output Pointers
	signal IP0 : unsigned(ADDRESS_BITS - 1 downto 0) := (others => '0');
	signal OP0 : unsigned(ADDRESS_BITS - 1 downto 0) := (others => '0');

	-- Incremented Input and Output Pointers
	signal IP1 : unsigned(ADDRESS_BITS - 1 downto 0);
	signal OP1 : unsigned(ADDRESS_BITS - 1 downto 0);

	-- Committed Read Pointer (Commit Marker)
	signal OPm : unsigned(ADDRESS_BITS - 1 downto 0) := (others => '0');

	-----------------------------------------------------------------------------
	-- Backing Memory Connectivity

	-- Write Port
	signal wa : unsigned(ADDRESS_BITS - 1 downto 0);
	signal we : std_logic;

	-- Read Port
	signal ra : unsigned(ADDRESS_BITS - 1 downto 0);
	signal re : std_logic;

	-- Internal full and empty indicators
	signal fulli : std_logic;
	signal empti : std_logic;

begin

	-----------------------------------------------------------------------------
	-- Pointer Logic
	blkPointer : block
		signal IP0_slv : std_logic_vector(IP0'range);
		signal IP1_slv : std_logic_vector(IP0'range);
		signal OP0_slv : std_logic_vector(IP0'range);
		signal OP1_slv : std_logic_vector(IP0'range);
	begin
		IP0_slv <= std_logic_vector(IP0);
		OP0_slv <= std_logic_vector(OP0);

		incIP : entity work.arith_CarryChain_inc
			generic map(
				BITS => ADDRESS_BITS
			)
			port map
			(
				X => IP0_slv,
				Y => IP1_slv
			);

		incOP : entity work.arith_CarryChain_inc
			generic map(
				BITS => ADDRESS_BITS
			)
			port map
			(
				X => OP0_slv,
				Y => OP1_slv
			);

		IP1 <= unsigned(IP1_slv);
		OP1 <= unsigned(OP1_slv);
	end block;

	process (Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				IP0 <= (others => '0');
				OP0 <= (others => '0');
				OPm <= (others => '0');
			else
				-- Update Input Pointer upon Write
				if we = '1' then
					IP0 <= IP1;
				end if;

				-- Update Output Pointer upon Read or Rollback
				if Rollback = '1' then
					OP0 <= OPm;
				elsif re = '1' then
					OP0 <= OP1;
				end if;

				-- Update Commit Marker
				if Commit = '1' then
					if re = '1' then
						OPm <= OP1;
					else
						OPm <= OP0;
					end if;
				end if;

			end if;
		end if;
	end process;
	wa <= IP0;
	ra <= OP0;

	-- Fill State Computation (soft indicators)
	process (fulli, IP0, OP0, OPm)
		variable d : std_logic_vector(ADDRESS_BITS - 1 downto 0);
	begin

		-- Available Space
		if EMPTY_STATE_BITS > 0 then
			-- Compute Pointer Difference
			if fulli = '1' then
				d := (others => '1'); -- true number minus one when full
			else
				d := std_logic_vector(IP0 - OPm); -- true number of valid entries
			end if;
			EmptyState <= not d(d'left downto d'left - EMPTY_STATE_BITS + 1);
		else
			EmptyState <= (others => 'X');
		end if;

		-- Available Content
		if FILL_STATE_BITS > 0 then
			-- Compute Pointer Difference
			if fulli = '1' then
				d := (others => '1'); -- true number minus one when full
			else
				d := std_logic_vector(IP0 - OP0); -- true number of valid entries
			end if;
			FillState <= d(d'left downto d'left - FILL_STATE_BITS + 1);
		else
			FillState <= (others => 'X');
		end if;

	end process;

	-----------------------------------------------------------------------------
	-- Computation of full and empty indications.
	--
	-- The STATE_REG generic is ignored as two different comparators are
	-- needed to compare IP with OPm (full) and IP with OP (empty) anyways.
	-- So the register implementation is always used.
	blkState : block
		signal Ful : std_logic := '0';
		signal Pnd : std_logic := '0';
		signal Avl : std_logic := '0';
	begin
		process (Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					Ful <= '0';
					Pnd <= '0';
					Avl <= '0';
				else

					-- Pending Indicator for uncommitted Data
					if Commit = '1' or Rollback = '1' then
						Pnd <= '0';
					elsif re = '1' then
						Pnd <= '1';
					end if;

					-- Update Full Indicator
					if Commit = '1' and (re = '1' or Pnd = '1') then
						Ful <= '0';
					elsif we = '1' and IP1 = OPm then
						Ful <= '1';
					end if;

					-- Update Empty Indicator
					if we = '1' or (Rollback = '1' and Pnd = '1') then
						Avl <= '1';
					elsif re = '1' and we = '0' and OP1 = IP0 then
						Avl <= '0';
					end if;

				end if;
			end if;
		end process;
		fulli <= Ful;
		empti <= not Avl;
	end block;

	-----------------------------------------------------------------------------
	-- Memory Access

	-- Write Interface => Input
	Full <= fulli;
	we   <= Put and not fulli;

	-- Backing Memory and Read Interface => Output
	genLarge : if not DATA_REG generate
		signal do : std_logic_vector(DATA_BITS - 1 downto 0);
	begin

		-- Backing Memory
		ram : entity work.ocram_SimpleDualPort_Optimized
			generic map(
				RAM_TYPE => RAM_TYPE,
				ADDRESS_BITS   => ADDRESS_BITS,
				DATA_BITS   => DATA_BITS
			)
			port map
			(
				Write_Clock => Clock,
				Read_Clock => Clock,
				Write_ClockEnable  => '1',

				Write_Address => wa,
				Write_WriteEnable => we,
				Write_DataIn  => DataIn,

				Read_Address  => ra,
				Read_ClockEnable => re,
				Read_DataOut   => do
			);

		-- Read Interface => Output
		genOutputCmb : if not OUTPUT_REG generate
			signal Vld : std_logic := '0'; -- valid output of RAM module
		begin
			process (Clock)
			begin
				if rising_edge(Clock) then
					if Reset = '1' then
						Vld <= '0';
					else
						Vld <= (Vld and not Got) or not empti;
					end if;
				end if;
			end process;
			re    <= (not Vld or Got) and not empti;
			DataOut  <= do;
			Valid <= Vld;
		end generate genOutputCmb;

		genOutputReg : if OUTPUT_REG generate
			-- Extra Buffer Register for Output Data
			signal Buf : std_logic_vector(DATA_BITS - 1 downto 0) := (others => '-');
			signal Vld : std_logic_vector(0 to 1)              := (others => '0');
			-- Vld(0)   -- valid output of RAM module
			-- Vld(1)   -- valid word in Buf
		begin
			process (Clock)
			begin
				if rising_edge(Clock) then
					if Reset = '1' then
						Buf <= (others => '-');
						Vld <= (others => '0');
					else
						Vld(0) <= (Vld(0) and Vld(1) and not Got) or not empti;
						Vld(1) <= (Vld(1) and not Got) or Vld(0);
						if Vld(1) = '0' or Got = '1' then
							Buf <= do;
						end if;
					end if;
				end if;
			end process;
			re    <= (not Vld(0) or not Vld(1) or Got) and not empti;
			DataOut  <= Buf;
			Valid <= Vld(1);
		end generate genOutputReg;

	end generate genLarge;

	genSmall : if DATA_REG generate

		-- Memory modelled as Array
		type regfile_t is array(0 to 2 ** ADDRESS_BITS - 1) of std_logic_vector(DATA_BITS - 1 downto 0);
		signal regfile                 : regfile_t;
		attribute ram_style            : string; -- XST specific
		attribute ram_style of regfile : signal is "distributed";

		-- Altera Quartus II: Allow automatic RAM type selection.
		-- For small RAMs, registers are used on Cyclone devices and the M512 type
		-- is used on Stratix devices. Pass-through logic is automatically added
		-- if required. (Warning can be ignored.)

	begin

		-- Memory State
		process (Clock)
		begin
			if rising_edge(Clock) then
				--synthesis translate_off
				if SIMULATION and (Reset = '1') then
					regfile <= (others => (others => '-'));
				else
					--synthesis translate_on
					if we = '1' then
						regfile(to_integer(wa)) <= DataIn;
					end if;
					--synthesis translate_off
				end if;
				--synthesis translate_on
			end if;
		end process;

		-- Memory Output
		re   <= Got and not empti;
		DataOut <= (others => 'X') when Is_X(std_logic_vector(ra)) else
			regfile(to_integer(ra));
		Valid <= not empti;

	end generate genSmall;

end architecture;
