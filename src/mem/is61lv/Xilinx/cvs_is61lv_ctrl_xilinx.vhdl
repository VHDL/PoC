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
-- Entity: is61lv_ctrl_xilinx
-- Author(s): Martin Zabel
--
-- Controller for IS61LV Asynchronous SRAM.
--
-- See common description on is61lv_ctrl.
--
-- Special implementation using Xilinx components.
--
-- Tested with Spartan-3 Starter Kit Board @ 50 MHz.
--
-- Synchronous reset is used.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-04-30 11:29:10 $
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

-- Especially required for simulation.
library unisim;
use unisim.vcomponents.all;

entity is61lv_ctrl_xilinx is

  generic (
    A_BITS   : positive;
    D_BITS   : positive;
    CE_CNT   : positive;
    BE_CNT   : positive;
    SDIN_REG : boolean);

  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    req   : in  std_logic;
    write : in  std_logic;
    be    : in  std_logic_vector(BE_CNT-1 downto 0);
    addr  : in  unsigned(A_BITS-1 downto 0);
    wdata : in  std_logic_vector(D_BITS-1 downto 0);
    rdy   : out std_logic;
    rstb  : out std_logic;
    rdata : out std_logic_vector(D_BITS-1 downto 0);

    sram_ce_n : out   std_logic_vector(CE_CNT-1 downto 0);
    sram_be_n : out   std_logic_vector(BE_CNT-1 downto 0);
    sram_oe_n : out   std_logic;
    sram_we_n : out   std_logic;
    sram_addr : out   unsigned(A_BITS-1 downto 0);
    sram_data : inout std_logic_vector(D_BITS-1 downto 0));
end is61lv_ctrl_xilinx;

architecture rtl of is61lv_ctrl_xilinx is
  -- WAR = Write After Read
  type FSM_TYPE is (RUNNING, WAR);
  signal fsm_cs : FSM_TYPE;
  signal fsm_ns : FSM_TYPE;

  -- ready register
  signal rdy_r   : std_logic;
  signal rdy_nxt : std_logic;

  -- address register
  signal addr_r   : unsigned(A_BITS-1 downto 0);
  signal addr_nxt : unsigned(A_BITS-1 downto 0);

  -- byte enable register
  signal be_r_n   : std_logic_vector(BE_CNT-1 downto 0);
  signal be_nxt_n : std_logic_vector(BE_CNT-1 downto 0);

  -- write data register
  signal wdata_r   : std_logic_vector(D_BITS-1 downto 0);
  signal wdata_nxt : std_logic_vector(D_BITS-1 downto 0);

  -- sample user address and data
  signal get_user : std_logic;

  -- signals whether a read operation is currently executed
  signal reading_r   : std_logic;
  signal reading_nxt : std_logic;

  -- SRAM write enable, low-active
  signal sram_we_r_n   : std_logic;
  signal sram_we_nxt_n : std_logic;

  -- SRAM output enable, low-active
  signal sram_oe_r_n   : std_logic;
  signal sram_oe_nxt_n : std_logic;

  -- Own output enable, low-active
  signal own_oe_r_n   : std_logic_vector(D_BITS-1 downto 0);
  signal own_oe_nxt_n : std_logic;

  -- Required for ModelSim
  signal clk_n : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Datapath not depending on FSM
  -----------------------------------------------------------------------------

  be_nxt_n  <= not be;
  addr_nxt  <= addr;
  wdata_nxt <= wdata;

  -----------------------------------------------------------------------------
  -- FSM
  -----------------------------------------------------------------------------

  process (fsm_cs, req, write, reading_r)
  begin  -- process
    fsm_ns        <= fsm_cs;
    get_user      <= '0';
    own_oe_nxt_n  <= '1';
    sram_oe_nxt_n <= '1';
    sram_we_nxt_n <= '1';
    reading_nxt   <= '0';

    -- BE CAREFUL!
    -- Set to '1' whenever fsm_ns <= RUNNING;
    rdy_nxt <= '-';

    case fsm_cs is
      when RUNNING =>
        -- due to fsm_ns <= fsm_cs by default
        rdy_nxt <= '1';

        if req = '1' then
          get_user <= '1';

          if write = '1' then
            if reading_r = '1' then
              -- wait for one cycle to change data-bus direction
              rdy_nxt <= '0';
              fsm_ns  <= WAR;
            else
              -- write to SRAM
              own_oe_nxt_n  <= '0';
              sram_we_nxt_n <= '0';
            end if;

          else                          -- write = '0'
            -- read from SRAM
            sram_oe_nxt_n <= '0';
            reading_nxt   <= '1';
          end if;
        end if;

      when WAR =>
        -- write to SRAM after data-bus direction changed
        own_oe_nxt_n  <= '0';
        sram_we_nxt_n <= '0';
        fsm_ns        <= RUNNING;
        rdy_nxt       <= '1';
    end case;
  end process;

  -----------------------------------------------------------------------------
  -- Registers
  -----------------------------------------------------------------------------

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        fsm_cs      <= RUNNING;
        rdy_r       <= '1';
        reading_r   <= '0';
        own_oe_r_n  <= (others => '1');
        sram_oe_r_n <= '1';

      else
        fsm_cs      <= fsm_ns;
        rdy_r       <= rdy_nxt;
        reading_r   <= reading_nxt;
        own_oe_r_n  <= (others => own_oe_nxt_n);
        sram_oe_r_n <= sram_oe_nxt_n;
      end if;

      if get_user = '1' then
        be_r_n  <= be_nxt_n;
        addr_r  <= addr_nxt;
        wdata_r <= wdata_nxt;
      end if;
    end if;
  end process;

  -- Required for ModelSim
  clk_n <= not clk;

  -- Output sram_we_nxt_n only in the first half of the clock period. Data gets
  -- written with the rising edge of sram_we_r_n which is outputted with the
  -- falling edge of the clock.
  sram_we_reg : OFDDRRSE
    port map (
      S  => rst,
      R  => '0',
      C0 => clk,
      C1 => clk_n,
      CE => '1',
      D0 => sram_we_nxt_n,
      D1 => '1',
      Q  => sram_we_r_n);

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------

  rdy <= rdy_r;

  gNoSdinReg: if not SDIN_REG generate
    -- direct output, register elsewhere
    rdata <= sram_data;
    rstb  <= reading_r;
  end generate gNoSdinReg;

  gSdinReg: if SDIN_REG generate
    process (clk)
    begin  -- process
      if rising_edge(clk) then
        if reading_r = '1' then             -- don't collect garbage
          rdata <= sram_data;
        end if;

        if rst = '1' then
          rstb <= '0';
        else
          rstb <= reading_r;
        end if;
      end if;
    end process;
  end generate gSdinReg;

  sram_be_n <= be_r_n;
  sram_addr <= addr_r;

  l1: for i in 0 to D_BITS-1 generate
    -- each bit needs its own output enable
    sram_data(i) <= wdata_r(i) when own_oe_r_n(i) = '0' else 'Z';
  end generate l1;

  sram_ce_n <= (others => '0');
  sram_oe_n <= sram_oe_r_n;
  sram_we_n <= sram_we_r_n;
end rtl;
