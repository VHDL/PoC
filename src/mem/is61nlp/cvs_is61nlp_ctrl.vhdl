--
-- Copyright (c) 2008
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair of VLSI-Design, Diagnostics and Architecture
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: is61nlp_ctrl
-- Author(s): Martin Zabel
--
-- Controller for IS61NLP ZBT Synchronous SRAM.
--
-- Configuration:
-- A_BITS   = number of address bits (word address)
-- D_BITS   = number of data bits (of the word)
-- CE_CNT   = count of chip enables
-- BW_CNT   = count of byte write enables
-- SDIN_REG = generate register for sram_data on input
--
-- While the register on input from the SRAM chip is optional, all outputs to
-- the SRAM are registered as normal. These output registers should be placed
-- in an IOB on an FPGA, so that the timing relationship is fulfilled.
--
-- On read, byte write enables are ignored.
--
-- On top-level, the SRAM clock must be assigned as shown by the memtest_ml505
-- example.
--
-- At the moment, only one memory chip is supported for each part of the
-- data-bus. Thus, sram_ce_n is set to all zero.
--
-- Component is always ready (aka. ZBT).
--
-- Tested with Virtex-5 ML505 Board @ 100 MHz.
--
-- Synchronous reset is used.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-12-19 14:56:47 $
--
-------------------------------------------------------------------------------
-- Naming Conventions:
-- (Based on: Keating and Bricaud: "Reuse Methodology Manual")
--
-- active low signals: "*_n"
-- clock signals: "clk", "clk_div#", "clk_#x"
-- reset signals: "rst", "rst_n"
-- generics: all UPPERCASE
-- user defined types: "*_TYPE"
-- state machine next state: "*_ns"
-- state machine current state: "*_cs"
-- output of a register: "*_r"
-- asynchronous signal: "*_a"
-- pipelined or register delay signals: "*_p#"
-- data before being registered into register with the same name: "*_nxt"
-- clock enable signals: "*_ce"
-- internal version of output port: "*_i"
-- tristate internal signal "*_z"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity is61nlp_ctrl is

  generic (
    A_BITS   : positive;
    D_BITS   : positive;
    CE_CNT   : positive;
    BW_CNT   : positive;
    SDIN_REG : boolean);

  port (
    rst   : in  std_logic;
    clk   : in  std_logic;
    req   : in  std_logic;
    write : in  std_logic;
    bw    : in  std_logic_vector(BW_CNT-1 downto 0);
    addr  : in  unsigned(A_BITS-1 downto 0);
    wdata : in  std_logic_vector(D_BITS-1 downto 0);
    rstb  : out std_logic;
    rdata : out std_logic_vector(D_BITS-1 downto 0);

    sram_ce_n : out   std_logic_vector(CE_CNT-1 downto 0);
    sram_mode : out   std_logic;
    sram_bw_n : out   std_logic_vector(BW_CNT-1 downto 0);
    sram_addr : out   unsigned(A_BITS-1 downto 0);
    sram_we_n : out   std_logic;
    sram_adv  : out   std_logic;
    sram_oe_n : out   std_logic;
    sram_data : inout std_logic_vector(D_BITS-1 downto 0));
end is61nlp_ctrl;

architecture rtl of is61nlp_ctrl is
  -- address register
  signal addr_p0  : unsigned(A_BITS-1 downto 0);
  signal addr_nxt : unsigned(A_BITS-1 downto 0);

  -- byte enable register
  signal bw_p0_n  : std_logic_vector(BW_CNT-1 downto 0);
  signal bw_nxt_n : std_logic_vector(BW_CNT-1 downto 0);

  -- write data register
  signal wdata_p0  : std_logic_vector(D_BITS-1 downto 0);
  signal wdata_p1  : std_logic_vector(D_BITS-1 downto 0);
  signal wdata_p2  : std_logic_vector(D_BITS-1 downto 0);
  signal wdata_nxt : std_logic_vector(D_BITS-1 downto 0);

  -- sample user address and data
  signal get_user : std_logic;

  -- signals whether a read operation is currently executed
  signal reading_p0  : std_logic;
  signal reading_p1  : std_logic;
  signal reading_p2  : std_logic;
  signal reading_nxt : std_logic;

  -- signals whether a write operation is currently executed
  signal writing_p0_n  : std_logic;
  signal writing_p1_n  : std_logic;
  signal writing_nxt_n : std_logic;

  -- Own output enable, low-active
  signal own_oe_r_n   : std_logic_vector(D_BITS-1 downto 0);
  signal own_oe_nxt_n : std_logic;

  -- SRAM write enable, low-active
  signal sram_we_r_n   : std_logic;
  signal sram_we_nxt_n : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Datapath / Control
  --
  -- Pipeline:
  --   Input  =>  Reg      =>  Reg         =>  Reg
  --  ----------------------------------------------------------------
  --   stb/       reading_p0   reading_p1      reading_p2
  --    write     writing_p0   writing_p1      own_oe_r_n
  --   wdata      wdata_p0     wdata_p1        wdata_p2
  --   addr       addr_p0
  --   bw         bw_p0
  -----------------------------------------------------------------------------

  bw_nxt_n  <= not bw;
  addr_nxt  <= addr;
  wdata_nxt <= wdata;

  get_user      <= req;
  reading_nxt   <= req and not write;
  writing_nxt_n <= req nand write;
  own_oe_nxt_n  <= writing_p1_n;
  sram_we_nxt_n <= writing_nxt_n;

  -----------------------------------------------------------------------------
  -- Registers
  -----------------------------------------------------------------------------

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        reading_p0   <= '0';
        reading_p1   <= '0';
        reading_p2   <= '0';
        writing_p0_n <= '1';
        writing_p1_n <= '1';
        own_oe_r_n   <= (others => '1');
        sram_we_r_n  <= '1';

      else
        reading_p0   <= reading_nxt;
        reading_p1   <= reading_p0;
        reading_p2   <= reading_p1;
        writing_p0_n <= writing_nxt_n;
        writing_p1_n <= writing_p0_n;
        own_oe_r_n   <= (others => own_oe_nxt_n);
        sram_we_r_n  <= sram_we_nxt_n;
      end if;

      if get_user = '1' then
        bw_p0_n  <= bw_nxt_n;
        addr_p0  <= addr_nxt;
        wdata_p0 <= wdata_nxt;
      end if;

      wdata_p1  <= wdata_p0;
      wdata_p2  <= wdata_p1;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  gNoSdinReg : if not SDIN_REG generate
    rdata <= sram_data;
    rstb  <= reading_p2;
  end generate gNoSdinReg;

  gSdinReg : if SDIN_REG generate
    process (clk)
    begin  -- process
      if rising_edge(clk) then
        if reading_p2 = '1' then
          rdata <= sram_data;
        end if;

        if rst = '1' then
          rstb <= '0';
        else
          rstb <= reading_p2;
        end if;
      end if;
    end process;
  end generate gSdinReg;

  sram_bw_n <= bw_p0_n;
  sram_addr <= addr_p0;

  l1: for i in 0 to D_BITS-1 generate
    -- each bit needs its own output enable
    sram_data(i) <= wdata_p2(i) when own_oe_r_n(i) = '0' else 'Z';
  end generate l1;

  sram_ce_n <= (others => '0');
  sram_mode <= '0';
  sram_adv  <= '0';
  sram_oe_n <= '0';                     -- masked inside SRAM
  sram_we_n <= sram_we_r_n;

end rtl;
