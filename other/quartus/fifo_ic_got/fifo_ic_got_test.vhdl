library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.utils.all;

entity fifo_ic_got_test is

  generic (
    D_BITS	   : positive := 16;
    MIN_DEPTH	   : positive := 256;
    DATA_REG	   : boolean := false;
    OUTPUT_REG	   : boolean := false;
    ESTATE_WR_BITS : natural := 0;
    FSTATE_RD_BITS : natural := 0);

  port (
    clk_wr    : in  std_logic;
    rst_wr    : in  std_logic;
    put	      : in  std_logic;
    din	      : in  std_logic_vector(D_BITS-1 downto 0);
    full      : out std_logic;
    estate_wr : out std_logic_vector(imax(ESTATE_WR_BITS-1, 0) downto 0);
    clk_rd    : in  std_logic;
    rst_rd    : in  std_logic;
    got	      : in  std_logic;
    valid     : out std_logic;
    dout      : out std_logic_vector(D_BITS-1 downto 0);
    fstate_rd : out std_logic_vector(imax(FSTATE_RD_BITS-1, 0) downto 0));

end entity fifo_ic_got_test;

architecture rtl of fifo_ic_got_test is

begin  -- architecture rtl

  fifo0: entity poc.fifo_ic_got
    generic map (
      D_BITS	     => D_BITS,
      MIN_DEPTH	     => MIN_DEPTH,
      DATA_REG	     => DATA_REG,
      OUTPUT_REG     => OUTPUT_REG,
      ESTATE_WR_BITS => ESTATE_WR_BITS,
      FSTATE_RD_BITS => FSTATE_RD_BITS)
    port map (
      clk_wr	=> clk_wr,
      rst_wr	=> rst_wr,
      put	=> put,
      din	=> din,
      full	=> full,
      estate_wr => estate_wr,
      clk_rd	=> clk_rd,
      rst_rd	=> rst_rd,
      got	=> got,
      valid	=> valid,
      dout	=> dout,
      fstate_rd => fstate_rd);

end architecture rtl;

