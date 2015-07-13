-------------------------------------------------------------------------------
-- Title      : Testbench for design "trace_value_2fifo"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : trace_value_2fifo_tb.vhdl
-- Author     : Martin Zabel  <zabel@ite161.inf.tu-dresden.de>
-- Company    : 
-- Created    : 2013-10-23
-- Last update: 2013-10-23
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2013-10-23  1.0      zabel	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

-------------------------------------------------------------------------------

entity trace_value_2fifo_tb is

end trace_value_2fifo_tb;

-------------------------------------------------------------------------------

architecture sim of trace_value_2fifo_tb is

  component trace_value_2fifo
    generic (
      BLOCK_BITS : positive;
      IN_BLOCKS  : positive;
      OUT_BLOCKS : positive);
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      in_value_got   : out std_logic;
      in_value       : in  std_logic_vector(IN_BLOCKS*BLOCK_BITS-1 downto 0);
      in_value_fill  : in  unsigned(log2ceilnz(IN_BLOCKS)-1 downto 0);
      in_value_valid : in  std_logic;
      fifo_dat       : out std_logic_vector(OUT_BLOCKS*BLOCK_BITS-1 downto 0);
      fifo_put       : out std_logic;
      fifo_full      : in  std_logic;
      fifo_ptr       : out unsigned(log2ceil(OUT_BLOCKS)-1 downto 0));
  end component;

  -- component generics
  constant BLOCK_BITS : positive := 1;
  constant IN_BLOCKS  : positive := 11;
  constant OUT_BLOCKS : positive := 8;

  -- component ports
  signal clk            : std_logic := '1';
  signal rst            : std_logic;
  signal in_value_got   : std_logic;
  signal in_value       : std_logic_vector(IN_BLOCKS*BLOCK_BITS-1 downto 0);
  signal in_value_fill  : unsigned(log2ceilnz(IN_BLOCKS)-1 downto 0);
  signal in_value_valid : std_logic;
  signal fifo_dat       : std_logic_vector(OUT_BLOCKS*BLOCK_BITS-1 downto 0);
  signal fifo_put       : std_logic;
  signal fifo_full      : std_logic;
  signal fifo_ptr       : unsigned(log2ceil(OUT_BLOCKS)-1 downto 0);

begin  -- sim

  -- component instantiation
  UUT: trace_value_2fifo
    generic map (
      BLOCK_BITS => BLOCK_BITS,
      IN_BLOCKS  => IN_BLOCKS,
      OUT_BLOCKS => OUT_BLOCKS)
    port map (
      clk            => clk,
      rst            => rst,
      in_value_got   => in_value_got,
      in_value       => in_value,
      in_value_fill  => in_value_fill,
      in_value_valid => in_value_valid,
      fifo_dat       => fifo_dat,
      fifo_put       => fifo_put,
      fifo_full      => fifo_full,
      fifo_ptr       => fifo_ptr);

  -- clock generation
  clk <= not clk after 10 ns;

  -- waveform generation
  WaveGen_Proc : process
  begin
    -- insert signal assignments here
    rst            <= '1';
    fifo_full      <= '0';
    in_value_valid <= '0';
    in_value_fill  <= "1010";
    
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    wait until rising_edge(clk);
    wait until rising_edge(clk);

    in_value <= "10000000110";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "11111111111";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000000";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "11111111111";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000000";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "11111111111";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000000";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000000";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000001";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000001";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000001";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000001";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000000";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000000";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000000";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value <= "00000000000";
    in_value_valid <= '1';
    wait until rising_edge(clk) and in_value_got = '1';

    in_value_valid <= '0';

    wait;
  end process WaveGen_Proc;

  

end sim;

-------------------------------------------------------------------------------

configuration trace_value_2fifo_tb_sim_cfg of trace_value_2fifo_tb is
  for sim
  end for;
end trace_value_2fifo_tb_sim_cfg;

-------------------------------------------------------------------------------
