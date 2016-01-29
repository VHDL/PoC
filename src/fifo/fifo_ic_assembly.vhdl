-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ===========================================================================
-- Module:					address-based FIFO stream assembly, independent clocks (ic)
--
-- Authors:					Thomas B. Preusser
--
-- Description:
-- ------------
--	This module assembles a FIFO stream from data blocks that may arrive
--  slightly out of order. The arriving data is ordered according to their
--  address. The streamed output starts with the data word written to
--  address zero (0) and may proceed all the way to just before the first yet
--  missing data. The association of data with addesses is used on the input
--  side for the sole purpose of reconstructing the correct order of the data.
--  It is assumed to wrap so as to allow an infinite input sequence. Adresses
--  are not actively exposed to the purely stream-based FIFO output.
--
--  The implemented functionality enables the reconstruction of streams that
--  are tunneled across address-based transports that are allowed to reorder
--  the transmission of data blocks. This applies to many DMA implementations.
--
-- License:
-- ===========================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair for VLSI-Design, Diagnostics and Architecture
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
-- ===========================================================================

library	IEEE;
use			IEEE.std_logic_1164.all;

entity fifo_ic_assembly is
  generic (
    D_BITS : positive;  								-- Data Width
    A_BITS : positive;  								-- Address Bits
    G_BITS : positive  									-- Generation Guard Bits
  );
  port (
    -- Write Interface
    clk_wr : in std_logic;
    rst_wr : in std_logic;

    addr : in  std_logic_vector(A_BITS-1 downto 0);
    ful  : out std_logic;
    din  : in  std_logic_vector(D_BITS-1 downto 0);
    put  : in  std_logic;

		---------------------------------------------------------------------------
		-- TODO: Capacity Reporting!
		---------------------------------------------------------------------------

    -- Read Interface
    clk_rd : in std_logic;
    rst_rd : in std_logic;

    dout : out std_logic_vector(D_BITS-1 downto 0);
    vld  : out std_logic;
    got  : in  std_logic
  );
end fifo_ic_got;


library IEEE;
use			IEEE.numeric_std.all;

library	PoC;
use			PoC.ocram.all;

architecture rtl of fifo_ic_assembly is

	-----------------------------------------------------------------------------
	-- Memory Dimensioning
	--  The leading guard bits from the provided address serve to distinguish
	--  the data generations. A generation is the amount of data that fills the
	--  internal assembly memory exactly once. Due to their purpose, the guard
	--  bits tag the data rather than being used for internal addressing.
	constant AN : positive := A_BITS - G_BITS;
	constant DN : positive := G_BITS + D_BITS;

	-- Memory Connectivity
	signal wa : unsigned(AN-1 downto 0);
	signal we : std_logic;
	signal di : std_logic_vector(DN-1 downto 0);

	signal ra : unsigned(AN-1 downto 0);
	signal do : std_logic_vector(DN-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Write clock domain
	blkWrite: block is
		signal InitCnt : unsigned(AN downto 0) := (others => '0');
	begin
		process(clk_wr)
		begin
			if rising_edge(clk_wr) then
				if rst_wr = '1' then
					InitCnt <= (others => '0');
				elsif InitCnt(InitCnt'left) = '0' then
					InitCnt <= InitCnt + 1;
				end if;
			end if;
		end process;
		wa <= InitCnt(AN-1 downto 0) when InitCnt(InitCnt'left) = '0' else
					unsigned(addr(AN-1 downto 0));
		di <= (1 to G_BITS => '1') & (1 to D_BITS => '-') when InitCnt(InitCnt'left) = '0' else
					addr(A_BITS-1 downto AN) & din;
		we <= put or not InitCnt(InitCnt'left);

		-- Module Outputs
		ful <= not InitCnt(InitCnt'left);
	end block blkWrite;

  blkRead : block is

		-- Output Pointer for Reading
    signal OP : unsigned(A_BITS-1 downto 0)         := (others => '0');
		-- Expected Generation to check for continuity
    signal EG : std_logic_vector(G_BITS-1 downto 0) := (others => '1');
		-- Internal check result
		signal vldi : std_logic;

  begin
    process(clk_rd)
    begin
      if rising_edge(clk_rd) then
        if rst_rd = '1' then
          OP <= (others => '0');
          EG <= (others => '1');
        elsif vldi = '1' and got = '1' then
          OP <= OP + 1;
          EG <= std_logic_vector(OP(A_BITS-1 downto AN));
        end if;
      end if;
    end process;
    ra   <= OP(AN-1 downto 0);
    vldi <= '1' when do(DN-1 downto D_BITS) = EG else '0';

		-- Module Outputs
		dout <= do;
    vld  <= vldi;

  end block blkRead;

	-- Backing internal assembly memory
	ram : ocram_sdp
		generic map (
			A_BITS => AN,
			D_BITS => DN
		)
		port map (
			wclk   => clk_wr,
			rclk   => clk_rd,

			wa     => wa,
			wce    => '1',
			we     => we,
			d      => di,

			ra     => ra,
			rce    => '1',
			q      => do
		);

end rtl;
