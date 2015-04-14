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
-- Entity: is61lv_ctrl_wb
-- Author(s): Martin Zabel
-- 
-- Wishbone Wrapper for Memory controller is61lv_ctrl.
--
-- Configuration:
-- WA_BITS : number of bits addressing the word
-- BA_BITS : number of bits addressing the byte inside a word; can be set to
--           zero if not needed
-- D_BITS  : data bits of full word
-- CE_CNT  : count of chip enables (see is61lv_ctrl)
-- SDIN_REG: generate register for sram_data on input (see is61lv_ctrl)
--
-- The range of address lines and number of 'sel' lines is derived from the
-- above configuration, according to Wishbone RULE 3.95 and following.
--
-- Synchronous reset is used.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-12-19 14:23:19 $
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

library poc;
use poc.is61lv.all;

entity is61lv_ctrl_wb is
  
  generic (
    WA_BITS  : positive;
    BA_BITS  : positive;
    D_BITS   : positive;
    CE_CNT   : positive;
    SDIN_REG : boolean);

  port (
    clk : in std_logic;
    rst : in std_logic;
    
    -- Wishbone Interface
    wb_cyc_i : in  std_logic;
    wb_stb_i : in  std_logic;
    wb_sel_i : in  std_logic_vector((2**BA_BITS)-1 downto 0);
    wb_we_i  : in  std_logic;
    wb_adr_i : in  std_logic_vector((WA_BITS+BA_BITS)-1 downto BA_BITS);
    wb_dat_i : in  std_logic_vector(D_BITS-1 downto 0);
    wb_ack_o : out std_logic;
    wb_dat_o : out std_logic_vector(D_BITS-1 downto 0);

    sram_ce_n : out   std_logic_vector(CE_CNT-1 downto 0);
    sram_be_n : out   std_logic_vector((2**BA_BITS)-1 downto 0);
    sram_oe_n : out   std_logic;
    sram_we_n : out   std_logic;
    sram_addr : out   unsigned(WA_BITS-1 downto 0);
    sram_data : inout std_logic_vector(D_BITS-1 downto 0)
  );

end is61lv_ctrl_wb;

architecture rtl of is61lv_ctrl_wb is
  signal mem_rdy   : std_logic;
  signal mem_rstb  : std_logic;
  signal mem_req   : std_logic;
  signal mem_write : std_logic;
  signal mem_addr  : unsigned(WA_BITS-1 downto 0);
  
begin  -- rtl
  mctrl: is61lv_ctrl
    generic map (
      A_BITS   => WA_BITS,
      D_BITS   => D_BITS,
      CE_CNT   => CE_CNT,
      BE_CNT   => 2**BA_BITS,
      SDIN_REG => SDIN_REG)
    port map (
      clk       => clk,
      rst       => rst,
      req       => mem_req,
      write     => mem_write,
      be        => wb_sel_i,
      addr      => mem_addr,
      wdata     => wb_dat_i,
      rdy       => mem_rdy,
      rstb      => mem_rstb,
      rdata     => wb_dat_o,
      sram_ce_n => sram_ce_n,
      sram_be_n => sram_be_n,
      sram_oe_n => sram_oe_n,
      sram_we_n => sram_we_n,
      sram_addr => sram_addr,
      sram_data => sram_data);

  -- Some tools do not like conversion inside component instantiation.
  mem_addr <= unsigned(wb_adr_i);
  
  wbctrl: block
    type FSM_TYPE is (IDLE, READING, ACKING);
    signal fsm_cs : FSM_TYPE;
    signal fsm_ns : FSM_TYPE;

  begin  -- block wbctrl
    process (fsm_cs, wb_cyc_i, wb_stb_i, wb_we_i, mem_rdy, mem_rstb)
    begin  -- process
      fsm_ns     <= fsm_cs;
      wb_ack_o   <= '0';
      mem_req    <= '0';
      mem_write  <= '-';

      case fsm_cs is
        when IDLE =>
          if (wb_cyc_i and wb_stb_i) = '1' then
            -- Immediately pass command.
            mem_req   <= '1';
            mem_write <= wb_we_i;

            if mem_rdy = '1' then
              if wb_we_i = '1' then
                -- Switch to ACKING, to prevent combinatorial paths between
                -- module inputs and outputs
                fsm_ns <= ACKING;
              else
                fsm_ns <= READING;
              end if;
            end if;
          end if;

        when READING =>
          -- Precondition: command has been accepted by memory controller.
          -- Immediately pass read data.
          -- Terminate Wishbone bus cycle now.
          if mem_rstb = '1' then
            wb_ack_o   <= '1';
            fsm_ns     <= IDLE;
          end if;
          
        when ACKING =>
          -- Wishbone bus cycle is terminated now.
          wb_ack_o <= '1';
          fsm_ns <= IDLE;
      end case;
    end process;
    
    process (clk)
    begin  -- process
      if rising_edge(clk) then
        if rst = '1' then
          fsm_cs   <= IDLE;
        else
          fsm_cs   <= fsm_ns;
        end if;
      end if;
    end process;
  end block wbctrl;
end rtl;
