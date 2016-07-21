-------------------------------------------------------------------------------
-- Title      : Testbench for design "ocram_esdp_test"
-- Project    :
-------------------------------------------------------------------------------
-- File       : ocram_esdp_test_tb.vhdl
-- Author     : Martin Zabel  <zabel@ite161.inf.tu-dresden.de>
-- Company    :
-- Created    : 2015-02-17
-- Last update: 2015-02-18
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2015
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2015-02-17  1.0      zabel	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.utils.all;

-------------------------------------------------------------------------------

entity fifo_ic_got_test_tb is

end entity fifo_ic_got_test_tb;

-------------------------------------------------------------------------------

architecture sim of fifo_ic_got_test_tb is

  -- component generics
  constant D_BITS	  : positive := 16;
  constant MIN_DEPTH	  : positive := 256;
  constant DATA_REG	  : boolean  := false;
  constant OUTPUT_REG	  : boolean  := false;
  constant ESTATE_WR_BITS : natural  := 0;
  constant FSTATE_RD_BITS : natural  := 0;

  -- component ports
  signal clk_wr	   : std_logic := '1';
  signal rst_wr	   : std_logic;
  signal put	   : std_logic;
  signal din	   : std_logic_vector(D_BITS-1 downto 0);
  signal full	   : std_logic;
  signal estate_wr : std_logic_vector(imax(ESTATE_WR_BITS-1, 0) downto 0);
  signal clk_rd	   : std_logic := '1';
  signal rst_rd	   : std_logic;
  signal got	   : std_logic;
  signal valid	   : std_logic;
  signal dout	   : std_logic_vector(D_BITS-1 downto 0);
  signal fstate_rd : std_logic_vector(imax(FSTATE_RD_BITS-1, 0) downto 0);

begin  -- architecture sim

  -- component instantiation
  NA: entity work.fifo_ic_got_test
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

  -- clock generation
  clk_wr <= not clk_wr after 60 ns;
  clk_rd <= not clk_rd after 10 ns;

  WriteGen_Proc: process
  begin
    -- Apply reset at both ports at the same time!
    rst_wr <= '1';
    wait for 100 ns;

    wait until rising_edge(clk_wr);
    put    <= '0';
    rst_wr <= '0';

    -- Put in some data.
    for i in 0 to 15 loop
      wait until rising_edge(clk_wr);
      din <= x"D" & std_logic_vector(to_unsigned(i, D_BITS-4));
      put <= '1';
    end loop;  -- i

    wait until rising_edge(clk_wr);
    put <= '0';

    wait;
  end process WriteGen_Proc;

  -- Apply "got" as soon as possible.
  got <= valid;

  ReadGen_Proc: process is
  begin
    -- Apply reset at both ports at the same time!
    rst_rd <= '1';
    wait for 100 ns;

    wait until rising_edge(clk_rd);
    rst_rd <= '0';

    -- Read out data.
    for i in 0 to 15 loop
      wait until rising_edge(clk_rd) and valid = '1';
      assert dout = (x"D" & std_logic_vector(to_unsigned(i, D_BITS-4)))
	report "Read wrong data from FIFO!" severity error;
    end loop;  -- i

    wait;
  end process ReadGen_Proc;

end architecture sim;

-------------------------------------------------------------------------------

configuration fifo_ic_got_test_tb_sim_cfg of fifo_ic_got_test_tb is
  for sim
  end for;
end fifo_ic_got_test_tb_sim_cfg;

-------------------------------------------------------------------------------
