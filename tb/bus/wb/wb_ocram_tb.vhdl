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
-- Entity: ocram_wb_tb
-- Author(s): Martin Zabel
-- 
-- Testbench for ocram_wb
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2009-01-22 13:44:25 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.ocram.all;

entity ocram_wb_tb is
end ocram_wb_tb;

architecture behavior of ocram_wb_tb is

  -- component generics
  constant A_BITS      : positive             := 8;
  constant D_BITS      : positive             := 16;
  constant PIPE_STAGES : integer range 1 to 2 := 1;

  -- component ports
  signal clk      : std_logic := '1';
  signal rst      : std_logic;
  signal wb_cyc_i : std_logic;
  signal wb_stb_i : std_logic;
  signal wb_cti_i : std_logic_vector(2 downto 0);
  signal wb_bte_i : std_logic_vector(1 downto 0);
  signal wb_we_i  : std_logic;
  signal wb_adr_i : std_logic_vector(A_BITS-1 downto 0);
  signal wb_dat_i : std_logic_vector(D_BITS-1 downto 0);
  signal wb_ack_o : std_logic;
  signal wb_dat_o : std_logic_vector(D_BITS-1 downto 0);
  signal ram_ce   : std_logic;
  signal ram_we   : std_logic;
  signal ram_a    : unsigned(A_BITS-1 downto 0);
  signal ram_d    : std_logic_vector(D_BITS-1 downto 0);
  signal ram_q    : std_logic_vector(D_BITS-1 downto 0);

begin  -- behavior

  UUT: entity PoC.ocram_wb
    generic map (
      A_BITS      => A_BITS,
      D_BITS      => D_BITS,
      PIPE_STAGES => PIPE_STAGES)
    port map (
      clk      => clk,
      rst      => rst,
      wb_cyc_i => wb_cyc_i,
      wb_stb_i => wb_stb_i,
      wb_cti_i => wb_cti_i,
      wb_bte_i => wb_bte_i,
      wb_we_i  => wb_we_i,
      wb_adr_i => wb_adr_i,
      wb_dat_i => wb_dat_i,
      wb_ack_o => wb_ack_o,
      wb_dat_o => wb_dat_o,
      ram_ce   => ram_ce,
      ram_we   => ram_we,
      ram_a    => ram_a,
      ram_d    => ram_d,
      ram_q    => ram_q);

  -- clock generation
  clk <= not clk after 5 ns;

  -- Waveform generation.
  --
  -- Notes:
  -- - Wait additional 1 ns after the rising clock edge to meet
  --   hold time as well as clock-output-time
  -- - Wait 1 ns after chaning inputs to meet propagation delays for
  --   checked outputs.
  process
  begin
    rst      <= '1';
    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    wait until rising_edge(clk); wait for 1 ns;
    rst      <= '0';
    
    ---------------------------------------------------------------------------
    -- Classic write
    ---------------------------------------------------------------------------
    wb_cyc_i <= '1';
    wb_stb_i <= '1';
    wb_cti_i <= "000";
    wb_bte_i <= "00";
    wb_we_i  <= '1';
    wb_adr_i <= x"01";
    wb_dat_i <= x"0101";
    wait for 1 ns;
    
    assert (wb_ack_o = '0') and (ram_ce = '0')
      report "Classic Write: Write too early." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    assert wb_ack_o = '1' report "Classic Write: ACK failed." severity error;
    assert (ram_ce = '1') and (ram_we = '1') and
           (ram_a = x"01") and (ram_d = x"0101")
      report "Classic Write: RAM write failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    
    ---------------------------------------------------------------------------
    -- Classic read
    ---------------------------------------------------------------------------
    wb_cyc_i <= '1';
    wb_stb_i <= '1';
    wb_cti_i <= "000";
    wb_bte_i <= "00";
    wb_we_i  <= '0';
    wb_adr_i <= x"02";
    wait for 1 ns;

    assert wb_ack_o = '0' report "Classic Read: ACK too early." severity error;
    assert (ram_ce = '1') and (ram_we = '0') and (ram_a = x"02")
      report "Classic Read: RAM read failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    assert (wb_ack_o = '1') and (wb_dat_o = x"0202")
      report "Classic Read: ACK failed or data invalid." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    
    ---------------------------------------------------------------------------
    -- Bus idle
    ---------------------------------------------------------------------------
    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    wait for 1 ns;
    
    assert (wb_ack_o = '0') and (ram_ce = '0')
      report "Bus not idle." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    
    assert (wb_ack_o = '0') and (ram_ce = '0')
      report "Bus not idle." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    
    ---------------------------------------------------------------------------
    -- Burst write
    ---------------------------------------------------------------------------
    wb_cyc_i <= '1';
    wb_stb_i <= '1';
    wb_cti_i <= "010";
    wb_bte_i <= "00";
    wb_we_i  <= '1';
    wb_adr_i <= x"10";
    wb_dat_i <= x"1010";
    wait for 1 ns;
    
    assert (wb_ack_o = '0') and (ram_ce = '0')
      report "Burst Write: Write too early." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    assert wb_ack_o = '1' report "Burst Write: ACK failed." severity error;
    assert (ram_ce = '1') and (ram_we = '1') and
           (ram_a = x"10") and (ram_d = x"1010")
      report "Burst Write: RAM write failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    
    wb_adr_i <= x"11";
    wb_dat_i <= x"1111";
    wb_stb_i <= '1';
    wait for 1 ns;

    assert wb_ack_o = '1' report "Burst Write: ACK failed." severity error;
    assert (ram_ce = '1') and (ram_we = '1') and
           (ram_a = x"11") and (ram_d = x"1111")
      report "Burst Write: RAM write failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    wb_adr_i <= (others => 'X');
    wb_dat_i <= (others => 'X');
    wb_stb_i <= '0';                    -- Wait-State Master
    wait for 1 ns;

    assert wb_ack_o = '1' report "Burst Write: ACK failed." severity error;
    assert (ram_ce = '0') 
      report "Burst Write: Invalid RAM write." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    wb_adr_i <= x"12";
    wb_dat_i <= x"1212";
    wb_stb_i <= '1';
    wait for 1 ns;

    assert wb_ack_o = '1' report "Burst Write: ACK failed." severity error;
    assert (ram_ce = '1') and (ram_we = '1') and
           (ram_a = x"12") and (ram_d = x"1212")
      report "Burst Write: RAM write failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    
    wb_adr_i <= (others => 'X');
    wb_dat_i <= (others => 'X');
    wb_cti_i <= "111";                  -- End-of-Burst
    wb_stb_i <= '0';                    -- but wait-state
    wait for 1 ns;

    assert wb_ack_o = '1' report "Burst Write: ACK failed." severity error;
    assert (ram_ce = '0')
      report "Burst Write: Invalid RAM access." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    wb_adr_i <= x"13";
    wb_dat_i <= x"1313";
    wb_cti_i <= "111";                  -- End-of-Burst
    wb_stb_i <= '1';
    wait for 1 ns;

    assert wb_ack_o = '1' report "Burst Write: ACK failed." severity error;
    assert (ram_ce = '1') and (ram_we = '1') and
           (ram_a = x"13") and (ram_d = x"1313")
      report "Burst Write: RAM write failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    wait for 1 ns;
    
    assert (wb_ack_o = '0') and (ram_ce = '0')
      report "Burst Write: Bus not idle." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    wb_cyc_i <= '0';
    wb_stb_i <= '0';

    ---------------------------------------------------------------------------
    -- Burst Read
    ---------------------------------------------------------------------------
    wb_cyc_i <= '1';
    wb_stb_i <= '1';
    wb_cti_i <= "010";
    wb_bte_i <= "00";
    wb_we_i  <= '0';
    wb_adr_i <= x"20";
    wait for 1 ns;
    
    assert wb_ack_o = '0' report "Burst Read: ACK too early." severity error;
    assert (ram_ce = '1') and (ram_we = '0') and (ram_a = x"20")
      report "Burst Read: RAM read0 failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    assert (wb_ack_o = '1') and (wb_dat_o = x"2020")
      report "Burst Read: ACK failed or data invalid." severity error;
    assert (ram_ce = '1') and (ram_we = '0') and (ram_a = x"21")
      report "Burst Read: RAM read1 failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    
    wb_adr_i <= x"21";
    wb_stb_i <= '1';
    wait for 1 ns;

    assert (wb_ack_o = '1') and (wb_dat_o = x"2121")
      report "Burst Read: ACK failed or data invalid." severity error;
    assert (ram_ce = '1') and (ram_we = '0') and (ram_a = x"22")
      report "Burst Read: RAM read2 failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    wb_adr_i <= (others => 'X');
    wb_stb_i <= '0';                    -- Wait-State Master
    wait for 1 ns;

    assert (wb_ack_o = '1')
      report "Burst Read: ACK failed." severity error;
    -- Either no read or read at same address
    assert (ram_ce = '0') or ((ram_we = '0') and (ram_a = x"22"))
      report "Burst Read: RAM read2b failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    wb_adr_i <= x"22";
    wb_stb_i <= '1';
    wait for 1 ns;

    assert (wb_ack_o = '1') and (wb_dat_o = x"2222")
      report "Burst Read: ACK failed or data invalid." severity error;
    assert (ram_ce = '1') and (ram_we = '0') and (ram_a = x"23")
      report "Burst Read: RAM read3 failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    wb_adr_i <= (others => 'X');
    wb_cti_i <= "111";                  -- End-of-Burst
    wb_stb_i <= '0';                    -- but wait-state
    wait for 1 ns;

    assert (wb_ack_o = '1')
      report "Burst Read: ACK failed." severity error;
    -- Either no read or read at same address
    assert (ram_ce = '0') or ((ram_we = '0') and (ram_a = x"23"))
      report "Burst Read: RAM read3b failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    wb_adr_i <= x"23";
    wb_cti_i <= "111";                  -- End-of-Burst
    wb_stb_i <= '1';
    wait for 1 ns;

    assert (wb_ack_o = '1') and (wb_dat_o = x"2323")
      report "Burst Read: ACK failed or data invalid." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    
    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    wait for 1 ns;
    
    assert (wb_ack_o = '0') and (ram_ce = '0')
      report "Burst Write: Bus not idle." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    wb_cyc_i <= '0';
    wb_stb_i <= '0';

    ---------------------------------------------------------------------------
    -- Single-word burst write
    ---------------------------------------------------------------------------
    wb_cyc_i <= '1';
    wb_stb_i <= '1';
    wb_cti_i <= "111";
    wb_bte_i <= "00";
    wb_we_i  <= '1';
    wb_adr_i <= x"31";
    wb_dat_i <= x"3131";
    wait for 1 ns;
    
    assert (wb_ack_o = '0') and (ram_ce = '0')
      report "Single Write: Write too early." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    assert wb_ack_o = '1' report "Single Write: ACK failed." severity error;
    assert (ram_ce = '1') and (ram_we = '1') and
           (ram_a = x"31") and (ram_d = x"3131")
      report "Single Write: RAM write failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    
    ---------------------------------------------------------------------------
    -- Single-word burst read
    ---------------------------------------------------------------------------
    wb_cyc_i <= '1';
    wb_stb_i <= '1';
    wb_cti_i <= "111";
    wb_bte_i <= "00";
    wb_we_i  <= '0';
    wb_adr_i <= x"32";
    wait for 1 ns;

    assert wb_ack_o = '0' report "Single Read: ACK too early." severity error;
    assert (ram_ce = '1') and (ram_we = '0') and (ram_a = x"32")
      report "Single Read: RAM read failed." severity error;
    wait until rising_edge(clk); wait for 1 ns;

    assert (wb_ack_o = '1') and (wb_dat_o = x"3232")
      report "Single Read: ACK failed or data invalid." severity error;
    wait until rising_edge(clk); wait for 1 ns;
    wb_cyc_i <= '0';
    wb_stb_i <= '0';
    
    ---------------------------------------------------------------------------
    -- End
    ---------------------------------------------------------------------------
    wait;
  end process;

  -----------------------------------------------------------------------------
  -- RAM
  -----------------------------------------------------------------------------
  RAM: process (clk)
  begin  -- process RAM
    if rising_edge(clk) then
      if ram_ce = '1' then
        ram_q <= std_logic_vector(ram_a & ram_a);
      end if;
    end if;
  end process RAM;
end behavior;
