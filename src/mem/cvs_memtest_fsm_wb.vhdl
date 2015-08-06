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
-- Entity: memtest_fsm_wb
-- Author(s): Martin Zabel
-- 
-- Wishbone Wrapper for Generic Memory Controller Test FSM (memtest_fsm).
--
-- This is a Wishbone master. memtest_fsm is already instantiated in this
-- module.
--
-- TODO: Handle wb_rty_i separately.
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

entity memtest_fsm_wb is
  
  generic (
    A_BITS : positive := 18;
    D_BITS : positive := 32);

  port (
    clk : in std_logic;
    rst : in std_logic;
    
    -- Wishbone interface
    wb_ack_i : in std_logic;
    wb_err_i : in std_logic;
    wb_rty_i : in std_logic;
    wb_dat_i : in std_logic_vector(D_BITS-1 downto 0);
    wb_cyc_o : out  std_logic;
    wb_stb_o : out  std_logic;
    wb_we_o  : out  std_logic;
    wb_adr_o : out  std_logic_vector(A_BITS-1 downto 0);
    wb_dat_o : out  std_logic_vector(D_BITS-1 downto 0);

    -- Misc
    status : out std_logic_vector(2 downto 0)
  );

end memtest_fsm_wb;

architecture rtl of memtest_fsm_wb is
  component memtest_fsm
    generic (
      A_BITS : positive;
      D_BITS : positive);
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      mem_rdy   : in  std_logic;
      mem_rstb  : in  std_logic;
      mem_rdata : in  std_logic_vector(D_BITS-1 downto 0);
      mem_req   : out std_logic;
      mem_write : out std_logic;
      mem_addr  : out unsigned(A_BITS-1 downto 0);
      mem_wdata : out std_logic_vector(D_BITS-1 downto 0);
      status    : out std_logic_vector(2 downto 0));
  end component;

  -- FSM state
  type FSM_TYPE is (IDLE, READWRITING);
  signal fsm_cs : FSM_TYPE;
  signal fsm_ns : FSM_TYPE;

  -- Control signals
  signal rdy : std_logic;
  
  signal rstb_r   : std_logic;
  signal rstb_nxt : std_logic;
  
  -- Wishbone control and data signals
  signal wb_cyco_r   : std_logic;
  signal wb_cyco_nxt : std_logic;

  signal wb_weo_r   : std_logic;
  signal wb_weo_nxt : std_logic;

  signal wb_adro_r   : std_logic_vector(A_BITS-1 downto 0);
  signal wb_adro_nxt : std_logic_vector(A_BITS-1 downto 0);
  signal wb_adro_ce  : std_logic;

  signal wb_dato_r   : std_logic_vector(D_BITS-1 downto 0);
  signal wb_dato_nxt : std_logic_vector(D_BITS-1 downto 0);
  signal wb_dato_ce  : std_logic;

  signal wb_dati_r   : std_logic_vector(D_BITS-1 downto 0);
  signal wb_dati_nxt : std_logic_vector(D_BITS-1 downto 0);
  signal wb_dati_ce  : std_logic;

  signal writing_r   : std_logic;
  signal writing_nxt : std_logic;

  -- memtest_fsm outputs
  signal mem_req   : std_logic;
  signal mem_write : std_logic;
  signal mem_addr  : unsigned(A_BITS-1 downto 0);
  signal mem_wdata : std_logic_vector(D_BITS-1 downto 0);

begin  -- rtl

  -----------------------------------------------------------------------------
  -- Components
  -----------------------------------------------------------------------------
  fsm: memtest_fsm
    generic map (
      A_BITS => A_BITS,
      D_BITS => D_BITS)
    port map (
      clk       => clk,
      rst       => rst,
      mem_rdy   => rdy,
      mem_rstb  => rstb_r,
      mem_rdata => wb_dati_r,
      mem_req   => mem_req,
      mem_write => mem_write,
      mem_addr  => mem_addr,
      mem_wdata => mem_wdata,
      status    => status);
  

  -----------------------------------------------------------------------------
  -- Datapath not depending on FSM
  -----------------------------------------------------------------------------
  wb_adro_nxt <= std_logic_vector(mem_addr);
  wb_dato_nxt <= mem_wdata;

  wb_dati_nxt <= wb_dat_i;

  -----------------------------------------------------------------------------
  -- FSM
  -----------------------------------------------------------------------------
  process (fsm_cs, mem_req, mem_write, writing_r, 
           wb_ack_i, wb_err_i, wb_rty_i)
  begin  -- process
    fsm_ns      <= fsm_cs;
    writing_nxt <= writing_r;           -- keep!
    rstb_nxt    <= '0';
    
    wb_cyco_nxt <= '0';
    wb_weo_nxt  <= '0';
    wb_adro_ce  <= '0';
    wb_dato_ce  <= '0';
    wb_dati_ce  <= '0';

    case fsm_cs is
      when IDLE =>
        if mem_req = '1' then
          wb_adro_ce  <= '1';
          wb_cyco_nxt <= '1';
          wb_dato_ce  <= mem_write;
          wb_weo_nxt  <= mem_write;
          writing_nxt <= mem_write;
          fsm_ns      <= READWRITING;
        end if;

      when READWRITING =>
        -- unconditionally sample data and status
        wb_dati_ce <= not writing_r;

        -- hold
        wb_weo_nxt  <= writing_r;
        
        if (wb_ack_i or wb_err_i or wb_rty_i) = '1' then
          -- bus cycle terminated, data/status sampled due to above statements
          fsm_ns     <= IDLE;

        else
          -- wait for ack/err/rty
          wb_cyco_nxt <= '1';
        end if;

        if (wb_ack_i = '1') and (writing_r = '0') then
            -- issue read strobe
          rstb_nxt <= '1';
        end if;
    end case;
  end process;

  -----------------------------------------------------------------------------
  -- Registers
  -----------------------------------------------------------------------------
  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        fsm_cs <= IDLE;
        rstb_r <= '0';
      else
        fsm_cs <= fsm_ns;
        rstb_r <= rstb_nxt;
      end if;
      
      writing_r <= writing_nxt;
      
      if rst = '1' then
        wb_cyco_r <= '0';
      else
        wb_cyco_r <= wb_cyco_nxt;
      end if;

      wb_weo_r  <= wb_weo_nxt;

      if wb_adro_ce = '1' then
        wb_adro_r <= wb_adro_nxt;
      end if;

      if wb_dato_ce = '1' then
        wb_dato_r <= wb_dato_nxt;
      end if;

      if wb_dati_ce = '1' then
        wb_dati_r <= wb_dati_nxt;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  rdy <= '1' when fsm_cs = IDLE else '0';

  wb_cyc_o <= wb_cyco_r;
  wb_stb_o <= wb_cyco_r;                -- only one access per bus-cycle
  wb_we_o  <= wb_weo_r;
  wb_adr_o <= wb_adro_r;
  wb_dat_o <= wb_dato_r;

end rtl;
