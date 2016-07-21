--
-- Copyright (c) 2010
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: trace_fifo_ic
-- Author(s): Stefan Alex, Martin Zabel
--
-- Complete re-write by Martin Zabel
--
-- Wrapper for fifo_ic_got.vhdl checking fill-state.
--
-- TODO: 'thres' also useful for read clock domain?
--
-- Revision:    $Revision: 1.8 $
-- Last change: $Date: 2013-05-27 16:04:01 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.fifo.all;
use poc.functions.all;

entity trace_fifo_ic is
  generic (
    D_BITS     : positive;
    MIN_DEPTH  : positive;
    THRESHOLD  : positive;
    OUTPUT_REG : boolean
  );
  port (
    -- Write Interface
    clk_wr    : in  std_logic;
    rst_wr    : in  std_logic;
    put       : in  std_logic;
    din       : in  std_logic_vector(D_BITS-1 downto 0);
    full      : out std_logic;
    thres     : out std_logic;

    -- Read Interface
    clk_rd    : in  std_logic;
    rst_rd    : in  std_logic;
    got       : in  std_logic;
    valid     : out std_logic;
    dout      : out std_logic_vector(D_BITS-1 downto 0)
  );
end trace_fifo_ic;

architecture rtl of trace_fifo_ic is
  -- Minimum address size, regardless of FIFO implementation
  constant A_BITS : natural := log2ceil(MIN_DEPTH);

  -- Calculate fill-state in parts of 2**ESTATE_WR_BITS.
  -- Default: part of sixteen
  constant ESTATE_WR_BITS : positive := imin(4, A_BITS);
  constant ESTATE_THRES   : natural  := THRESHOLD*(2**ESTATE_WR_BITS)/MIN_DEPTH;
  signal   estate_wr      : std_logic_vector(ESTATE_WR_BITS-1 downto 0);
begin

  assert (2**log2ceil(MIN_DEPTH+1)) = MIN_DEPTH+1
    report "FIFO_DEPTH ist not optimal. Should be 2**n-1. Otherwise memory is wasted."
    severity warning;

  assert ESTATE_THRES < 2**(ESTATE_WR_BITS-1)
    report "Safe Distance (FIFO_SDS) is too large. Maximum allowed is 1/2 of fifo size."
    severity failure;

  fifo0: fifo_ic_got
    generic map (
      DATA_REG       => MIN_DEPTH<=64,
      D_BITS         => D_BITS,
      MIN_DEPTH      => MIN_DEPTH,
      ESTATE_WR_BITS => ESTATE_WR_BITS,
      FSTATE_RD_BITS => 0)
    port map (
      clk_wr    => clk_wr,
      rst_wr    => rst_wr,
      put       => put,
      din       => din,
      full      => full,
      estate_wr => estate_wr,
      clk_rd    => clk_rd,
      rst_rd    => rst_rd,
      got       => got,
      valid     => valid,
      dout      => dout,
      fstate_rd => open);

  -- Register fstate_wr to shorten critical path.
  process (clk_wr)
  begin  -- process
    if rising_edge(clk_wr) then
      if rst_wr = '1' then
        thres <= '0';
      else
        if unsigned(estate_wr) <= ESTATE_THRES then
          thres <= '1';
        else
          thres <= '0';
        end if;
      end if;
    end if;
  end process;

end rtl;
