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
-- Entity: ocram_wb
-- Author(s): Martin Zabel
-- 
-- Wishbone Slave wrapper for ocram RAM modules.
--
-- This slave supports Wishbone Registered Feedback bus cycles (aka. burst
-- transfers / advanced synchronous cycle termination). The mode "Incrementing
-- burst cycle" (CTI = 010) with "Linear burst" (BTE = 00) is supported.
-- 
-- If your master does support Wishbone Classis bus cycles only, then connect
-- wb_cti_i = "000" and wb_bte_i = "00".
--
-- Connect the ocram of your choice to the ram_* port signals. (Every RAM with
-- single cyle read latency is supported.)
--
-- Configuration:
-- --------------
-- PIPE_STAGES = 1: The RAM output is directly connected to the bus. Thus, the
--   read access latency (one cycle) is short. But, the RAM's read timing delay
--   must be respected.
--
-- PIPE_STAGES = 2: The RAM output is registered again. Thus, the read access
--   latency is two cycles. 
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-01-22 13:45:46 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ocram_wb is
  
  generic (
    A_BITS      : positive;-- := 10;
    D_BITS      : positive;-- := 32;
    PIPE_STAGES : integer range 1 to 2);-- := 1);

  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    wb_cyc_i : in  std_logic;
    wb_stb_i : in  std_logic;
    wb_cti_i : in  std_logic_vector(2 downto 0);
    wb_bte_i : in  std_logic_vector(1 downto 0);
    wb_we_i  : in  std_logic;
    wb_adr_i : in  std_logic_vector(A_BITS-1 downto 0);
    wb_dat_i : in  std_logic_vector(D_BITS-1 downto 0);
    wb_ack_o : out std_logic;
    wb_dat_o : out std_logic_vector(D_BITS-1 downto 0);
    ram_ce   : out std_logic;
    ram_we   : out std_logic;
    ram_a    : out unsigned(A_BITS-1 downto 0);
    ram_d    : out std_logic_vector(D_BITS-1 downto 0);
    ram_q    : in  std_logic_vector(D_BITS-1 downto 0));

end ocram_wb;

architecture rtl of ocram_wb is

  -- FSM state
  type FSM_TYPE is (IDLE, ACKING);
  signal fsm_cs : FSM_TYPE;
  signal fsm_ns : FSM_TYPE;

  -- Address selection
  type ADDR_SEL_TYPE is (ADDR_SEL_BUS, ADDR_SEL_INC);
  signal addr_sel : ADDR_SEL_TYPE;

  -- The address register
  signal addr_r   : unsigned(A_BITS-1 downto 0);
  signal addr_nxt : unsigned(A_BITS-1 downto 0);
  signal addr_ce  : std_logic;
  
begin  -- rtl

  assert PIPE_STAGES = 1
    report "PIPE_STAGES = 2 not yet supported"
    severity failure;

  -----------------------------------------------------------------------------
  -- FSM (including control outputs)
  -----------------------------------------------------------------------------

  process (fsm_cs, wb_cyc_i, wb_stb_i, wb_cti_i, wb_bte_i, wb_we_i)
  begin  -- process
    fsm_ns   <= fsm_cs;
    ram_ce   <= '0';
    ram_we   <= '0';
    addr_sel <= ADDR_SEL_BUS;
    addr_ce  <= '0';
    wb_ack_o <= '0';
    
    case fsm_cs is
      when IDLE =>
        if (wb_cyc_i and wb_stb_i) = '1' then
          addr_ce <= '1';
          
          if wb_we_i = '0' then
            -- Read from RAM
            ram_ce <= '1';
          end if;

          -- Write during ACK, see below.

          fsm_ns <= ACKING;
        end if;
        
      when ACKING => 
        wb_ack_o <= '1';

        if wb_we_i = '0' then
          -- Read: Check for supported burst transfer
          addr_sel <= ADDR_SEL_INC;

          if wb_stb_i = '1' then
            -- Control signals are valid, otherwise master inserts a wait-state
            -- Read ahead even if data (and address) is not needed.
            -- Do not read, if wb_stb_i = '0'!
            ram_ce  <= '1';
            addr_ce <= '1';           -- increment address!
            
            if not ((wb_cti_i = "010") and (wb_bte_i = "00")) then
              -- Unsupported mode or end-of-burst.
              fsm_ns <= IDLE;
            end if;
          end if;

        else
          -- Write: Do write and check for burst transfer
          -- Use address from bus! Update of address-reg not required.
          ram_we <= '1';
          
          if wb_stb_i = '1' then
            -- Control / data signals are valid, otherwise master inserts
            -- a wait-state.
            -- Master ready => really write (again).
            ram_ce  <= '1';

            if not ((wb_cti_i = "010") and (wb_bte_i = "00")) then
              -- Unsupported mode or end-of-burst.
              fsm_ns <= IDLE;
            end if;
          end if;
        end if;
        
    end case;
  end process;
  
  -----------------------------------------------------------------------------
  -- Datapath (including data outputs)
  -----------------------------------------------------------------------------

  with addr_sel select
    addr_nxt <=
    unsigned(wb_adr_i) when ADDR_SEL_BUS,
    addr_r + 1         when ADDR_SEL_INC;

  ram_a <= addr_nxt;
  ram_d <= wb_dat_i;
  
  p1: if PIPE_STAGES = 1 generate
    wb_dat_o <= ram_q;
  end generate p1;
  
  -----------------------------------------------------------------------------
  -- Register
  -----------------------------------------------------------------------------

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        fsm_cs <= IDLE;
      else
        fsm_cs <= fsm_ns;
      end if;

      if addr_ce = '1' then
        addr_r <= addr_nxt;
      end if;
    end if;
  end process;

end rtl;
