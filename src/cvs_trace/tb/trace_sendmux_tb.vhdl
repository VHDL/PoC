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
-- Entity: trace_sendmux_tb
-- Author(s): Martin Zabel
-- 
-- Check trace_sendmux
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2010-04-24 17:49:33 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trace_sendmux_tb is
end trace_sendmux_tb;

-------------------------------------------------------------------------------

architecture behavioral of trace_sendmux_tb is

  component trace_sendmux
    generic (
      MIN_DATA_PACKET_SIZE : integer range 2 to 128);
    port (
      clk             : in  std_logic;
      rst             : in  std_logic;
      data_fifo_clear : in  std_logic;
      data_fifo_put   : in  std_logic;
      data_fifo_din   : in  std_logic_vector(7 downto 0);
      data_fifo_full  : out std_logic;
      data_fifo_empty : out std_logic;
      ctrl_valid      : in  std_logic;
      ctrl_data       : in  std_logic_vector(7 downto 0);
      ctrl_last       : in  std_logic;
      ctrl_got        : out std_logic;
      eth_valid       : out std_logic;
      eth_last        : out std_logic;
      eth_dout        : out std_logic_vector(7 downto 0);
      eth_got         : in  std_logic;
      eth_finish      : in  std_logic;
      header          : out std_logic);
  end component;

  -- component generics
  constant MIN_DATA_PACKET_SIZE : integer := 3;

  -- component ports
  signal clk             : std_logic := '0';
  signal rst             : std_logic;
  signal data_fifo_clear : std_logic;
  signal data_fifo_put   : std_logic;
  signal data_fifo_din   : std_logic_vector(7 downto 0);
  signal data_fifo_full  : std_logic;
  signal data_fifo_empty : std_logic;
  signal ctrl_valid      : std_logic;
  signal ctrl_data       : std_logic_vector(7 downto 0);
  signal ctrl_last       : std_logic;
  signal ctrl_got        : std_logic;
  signal eth_valid       : std_logic;
  signal eth_last        : std_logic;
  signal eth_dout        : std_logic_vector(7 downto 0);
  signal eth_got         : std_logic;
  signal eth_finish      : std_logic;
  signal header          : std_logic;

begin  -- behavioral

  -- component instantiation
  DUT: trace_sendmux
    generic map (
      MIN_DATA_PACKET_SIZE => MIN_DATA_PACKET_SIZE)
    port map (
      clk             => clk,
      rst             => rst,
      data_fifo_clear => data_fifo_clear,
      data_fifo_put   => data_fifo_put,
      data_fifo_din   => data_fifo_din,
      data_fifo_full  => data_fifo_full,
      data_fifo_empty => data_fifo_empty,
      ctrl_valid      => ctrl_valid,
      ctrl_data       => ctrl_data,
      ctrl_last       => ctrl_last,
      ctrl_got        => ctrl_got,
      eth_valid       => eth_valid,
      eth_last        => eth_last,
      eth_dout        => eth_dout,
      eth_got         => eth_got,
      eth_finish      => eth_finish,
      header          => header);

  -- clock generation
  clk <= not clk after 5 ns;

  eth_got <= eth_valid;
  
  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    rst           <= '1';
    data_fifo_put <= '0';
    data_fifo_clear <= '0';
    ctrl_valid    <= '0';
    ctrl_last     <= '0';
    eth_finish    <= '0';
    wait until rising_edge(clk);
    rst <= '0';

    ---------------------------------------------------------------------------
    -- Do nothing
    ---------------------------------------------------------------------------
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Add enough data
    ---------------------------------------------------------------------------
    data_fifo_put <= '1';
    data_fifo_din <= x"01";
    wait until rising_edge(clk);
    data_fifo_din <= x"02";
    wait until rising_edge(clk);
    data_fifo_din <= x"03";
    wait until rising_edge(clk);
    data_fifo_din <= x"04";
    wait until rising_edge(clk);
    data_fifo_din <= x"05";
    wait until rising_edge(clk);
    data_fifo_din <= x"06";
    wait until rising_edge(clk);
    data_fifo_din <= x"07";
    wait until rising_edge(clk);
    data_fifo_put <= '0';

    ---------------------------------------------------------------------------
    -- Do nothing
    ---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- Send a control packet
    ---------------------------------------------------------------------------
    ctrl_valid <= '1';
    ctrl_data  <= x"81";
    wait until ctrl_got = '1';
    wait until rising_edge(clk);
    ctrl_data  <= x"82";
    wait until rising_edge(clk);
    ctrl_data  <= x"83";
    wait until rising_edge(clk);
    ctrl_data  <= x"84";
    ctrl_last  <= '1';
    wait until rising_edge(clk);
    ctrl_valid <= '0';
    ctrl_last  <= '0';

    ---------------------------------------------------------------------------
    -- Add data but not enough
    ---------------------------------------------------------------------------
    data_fifo_put <= '1';
    data_fifo_din <= x"11";
    wait until rising_edge(clk);
    data_fifo_din <= x"12";
    wait until rising_edge(clk);
    data_fifo_put <= '0';

    ---------------------------------------------------------------------------
    -- Send a control packet instead
    ---------------------------------------------------------------------------
    ctrl_valid <= '1';
    ctrl_data  <= x"91";
    wait until ctrl_got = '1';
    wait until rising_edge(clk);
    ctrl_data  <= x"92";
    wait until rising_edge(clk);
    ctrl_data  <= x"93";
    wait until rising_edge(clk);
    ctrl_data  <= x"94";
    ctrl_last  <= '1';
    wait until rising_edge(clk);
    ctrl_valid <= '0';
    ctrl_last  <= '0';

    ---------------------------------------------------------------------------
    -- Add more data
    ---------------------------------------------------------------------------
    data_fifo_put <= '1';
    data_fifo_din <= x"13";
    wait until rising_edge(clk);
    data_fifo_din <= x"14";
    wait until rising_edge(clk);
    -- FIFO is full now, wait one cycle
    data_fifo_put <= '0';
    wait until rising_edge(clk);
    data_fifo_put <= '1';
    data_fifo_din <= x"15";
    wait until rising_edge(clk);
    data_fifo_put <= '0';

    ---------------------------------------------------------------------------
    -- Do nothing
    ---------------------------------------------------------------------------
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    
    ---------------------------------------------------------------------------
    -- Add more data
    ---------------------------------------------------------------------------
    data_fifo_put <= '1';
    data_fifo_din <= x"16";
    wait until rising_edge(clk);
    data_fifo_din <= x"17";
    wait until rising_edge(clk);
    data_fifo_din <= x"20";
    wait until rising_edge(clk);
    data_fifo_din <= x"21";
    -- maximum packet size reached
    eth_finish    <= '1';
    wait until rising_edge(clk);
    eth_finish    <= '0';
    data_fifo_din <= x"22";
    wait until rising_edge(clk);
    data_fifo_din <= x"23";
    wait until rising_edge(clk);
    -- FIFO is full now, wait one cycle
    data_fifo_put <= '0';
    wait until rising_edge(clk);
    data_fifo_put <= '1';
    data_fifo_din <= x"24";
    wait until rising_edge(clk);
    data_fifo_din <= x"25";
    wait until rising_edge(clk);
    data_fifo_din <= x"26";
    wait until rising_edge(clk);
    data_fifo_din <= x"27";
    wait until rising_edge(clk);
    data_fifo_put <= '0';

    ---------------------------------------------------------------------------
    -- Do nothing
    ---------------------------------------------------------------------------
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    
    ---------------------------------------------------------------------------
    -- Empty data fifo
    ---------------------------------------------------------------------------
    data_fifo_clear <= '1';
    wait until rising_edge(clk);
    
    wait;
  end process WaveGen_Proc;

  

end behavioral;
