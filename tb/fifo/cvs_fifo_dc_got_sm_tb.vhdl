--
-- Copyright (c) 2008
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
-- Entity: fifo_dc_got_sm_tb
-- Author(s): Martin Zabel
-- 
-- Testbench for fifo_dc_got_sm.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-11-04 20:41:13 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.fifo.all;

entity fifo_dc_got_sm_tb is
end fifo_dc_got_sm_tb;

architecture behavioral of fifo_dc_got_sm_tb is

  -- component generics
  -- must match configuration used for synthesis if simulating netlists
  constant D_BITS    : positive := 8;
  constant MIN_DEPTH : positive := 15;

  component fifo_dc_got_sm
-- uncomment generics if simulating netlists
    generic (
      D_BITS    : positive;
      MIN_DEPTH : positive);
    port (
      clk_wr : in  std_logic;
      rst_wr : in  std_logic;
      put    : in  std_logic;
      din    : in  std_logic_vector(D_BITS-1 downto 0);
      full   : out std_logic;
      clk_rd : in  std_logic;
      rst_rd : in  std_logic;
      got    : in  std_logic;
      valid  : out std_logic;
      dout   : out std_logic_vector(D_BITS-1 downto 0));
  end component;

  -- component ports
  signal clk_wr : std_logic := '0';
  signal rst_wr : std_logic;
  signal put    : std_logic;
  signal din    : std_logic_vector(D_BITS-1 downto 0);
  signal full   : std_logic;
  signal clk_rd : std_logic := '0';
  signal rst_rd : std_logic;
  signal got    : std_logic;
  signal valid  : std_logic;
  signal dout   : std_logic_vector(D_BITS-1 downto 0);

begin  -- behavioral

  -- component instantiation
  UUT: fifo_dc_got_sm
-- uncomment generics if simulating netlists
    generic map (
      D_BITS    => D_BITS,
      MIN_DEPTH => MIN_DEPTH)
    port map (
      clk_wr => clk_wr,
      rst_wr => rst_wr,
      put    => put,
      din    => din,
      full   => full,
      clk_rd => clk_rd,
      rst_rd => rst_rd,
      got    => got,
      valid  => valid,
      dout   => dout);

  -- clock generation
  clk_rd <= not clk_rd after 15 ns;
  clk_wr <= transport clk_rd after 7.5 ns;  -- phase shifted

  -- waveform generation
  Write_Proc : process
  begin
    -- circuit initialization
    rst_wr <= '1';
    put    <= '0';
    din    <= (others => '-');
    wait for 100 ns;
    wait until falling_edge(clk_wr);
    rst_wr <= '0';
    
    -- insert signal assignments here
    wait until falling_edge(clk_wr) and full = '0';
    put <= '1';
    din <= x"01";
    wait until falling_edge(clk_wr);
    put <= '0';
    wait until falling_edge(clk_wr);
    
    put <= '1';
    din <= x"10";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"11";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"12";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"13";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"14";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"15";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"16";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"17";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"18";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"19";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"1a";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"1b";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"1c";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"1d";
    wait until falling_edge(clk_wr);
    put <= '1';
    din <= x"1e";
    wait until falling_edge(clk_wr);
    -- fifo is full now, "put" will be ignored
    put <= '1';
    din <= x"1f";
    wait until falling_edge(clk_wr);
    put <= '0';
    wait until falling_edge(clk_wr);

    -- wait for FIFO to be cleared
    wait for 2000 ns;
    wait until falling_edge(clk_wr);
    
    -- continues write
    for i in 0 to 10000 loop
      while full /= '0' loop           -- catch also 'X', ...
        put <= '0';
        wait until falling_edge(clk_wr);
      end loop;
      din <= std_logic_vector(to_unsigned(i mod 256, D_BITS));
      put <= '1';
      wait until falling_edge(clk_wr);
    end loop;  -- i
    put <= '0';
    wait until falling_edge(clk_wr);
    
    wait;
  end process Write_Proc;

  -- waveform generation
  Read_Proc : process
  begin
    -- circuit initialization
    rst_rd <= '1';
    got    <= '0';
    wait for 100 ns;
    wait until falling_edge(clk_rd);
    rst_rd <= '0';
      
    -- insert signal assignments here
    wait until falling_edge(clk_rd) and valid = '1';
    got <= '1';
    wait until falling_edge(clk_rd);
    got <= '0';
    wait until falling_edge(clk_rd);

    -- wait for FIFO to be filled
    wait for 1000 ns;
    wait until falling_edge(clk_rd);
    
    for i in 0 to 15 loop
      -- last "got" will be ignored
      got <= '1';
      wait until falling_edge(clk_rd);
    end loop;  -- i
    got <= '0';
    wait until falling_edge(clk_rd);

    -- continues read
    for i in 0 to 10000 loop
      while valid /= '1' loop           -- catch also 'X', ...
        got <= '0';
        wait until falling_edge(clk_rd);
      end loop;
      assert dout = std_logic_vector(to_unsigned(i mod 256, D_BITS))
        report "Wrong read value"
        severity error;
      got <= '1';
      wait until falling_edge(clk_rd);
    end loop;  -- i
    got <= '0';
    wait until falling_edge(clk_rd);
    
    wait;
  end process Read_Proc;

end behavioral;
