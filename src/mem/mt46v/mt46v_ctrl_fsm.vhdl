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
-- Entity: mt46v_ctrl_fsm
-- Author(s): Martin Zabel
-- 
-- Controller for Micron DDR-SDRAM "MT46V*".
--
-- This file contains the FSM as well as parts of the datapath.
-- The board specific physical layer is defined in another file
-- mt46v_ctrl_phy_*.vhdl
--
-- After user_cmd_valid is asserted high, the command (user_write) and address
-- (user_addr) must be hold until user_got_cmd is asserted.
--
-- The FSM automatically waits for user_wdata_valid on writes. The data should
-- be available soon. Otherwise the auto refresh might fail. The FSM only waits
-- for the first word to write. All successive words of a burst must be valid
-- in the following cycles. (A burst can't be stalled.) ATTENTION: During
-- writes, user_cmd_got is asserted only if user_wdata_valid is set.
--
-- The write data must directly connected to the physical layer.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-12-19 15:50:52 $
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
use poc.functions.all;

entity mt46v_ctrl_fsm is
  generic (
    A_BITS : positive := 25;            -- 32M
    D_BITS : positive := 16;            -- x16

    CLK_FREQ_MHZ : positive := 100;     -- 100 MHz

    CL : positive := 2;                 -- CAS Latency
    BL : positive := 2;                 -- Burst Length
    
    MR_CL : std_logic_vector(2 downto 0) := "010";  -- CL = 2
    MR_BL : std_logic_vector(2 downto 0) := "001";  -- BL = 2

    T_MRD : integer := 2;               -- 12 ns @ 100 MHz
    T_RAS : integer := 5;               -- 42 ns @ 100 MHz
    T_RCD : integer := 2;               -- 15 ns @ 100 MHz
    T_RFC : integer := 8;               -- 72 ns @ 100 MHz
    T_RP  : integer := 2;               -- 15 ns @ 100 MHz
    T_WR  : integer := 2;               -- 15 ns @ 100 MHz
    T_WTR : integer := 1);              -- 1 cycle
  port (
    clk : in std_logic;
    rst : in std_logic;

    user_cmd_valid   : in  std_logic;
    user_wdata_valid : in  std_logic;
    user_write       : in  std_logic;
    user_addr        : in  unsigned(A_BITS-1 downto 0);
    user_got_cmd     : out std_logic;
    user_got_wdata   : out std_logic;

    sd_cke_nxt : out std_logic;
    sd_cs_nxt  : out std_logic;
    sd_ras_nxt : out std_logic;
    sd_cas_nxt : out std_logic;
    sd_we_nxt  : out std_logic;
    sd_a_nxt   : out std_logic_vector(12 downto 0);
    sd_ba_nxt  : out std_logic_vector(1 downto 0);
    rden_nxt   : out std_logic;
    wren_nxt   : out std_logic);
    

end mt46v_ctrl_fsm;

architecture rtl of mt46v_ctrl_fsm is

  -- FSM
  type FSM_TYPE is (INIT1, INIT2, INIT3, INIT4, INIT5, INIT6, INIT7, INIT8,
                    INIT9, INIT10,
                    DO_ACTIVATE,
                    DO_READ1, DO_READ2,
                    DO_WRITE1, DO_WRITE2,
                    CHECKNXT,
                    DO_PRECHARGE, DO_AUTO_REFRESH);
  signal fsm_cs : FSM_TYPE;
  signal fsm_ns : FSM_TYPE;
  
  -- SDRAM Commands
  subtype  SD_CMD_TYPE is std_logic_vector(3 downto 0);
  constant SD_CMD_DESELECT        : SD_CMD_TYPE := "1---";
  constant SD_CMD_NOP             : SD_CMD_TYPE := "0111";
  constant SD_CMD_ACTIVE          : SD_CMD_TYPE := "0011";
  constant SD_CMD_READ            : SD_CMD_TYPE := "0101";
  constant SD_CMD_WRITE           : SD_CMD_TYPE := "0100";
  constant SD_CMD_BURST_TERMINATE : SD_CMD_TYPE := "0110";
  constant SD_CMD_PRECHARGE       : SD_CMD_TYPE := "0010";
  constant SD_CMD_AUTO_REFRESH    : SD_CMD_TYPE := "0001";
  constant SD_CMD_LOAD_MODE_REG   : SD_CMD_TYPE := "0000";
  signal   sd_cmd_nxt             : SD_CMD_TYPE;

  -- SDRAM address
  signal bank_addr     : std_logic_vector(1 downto 0);
  signal row_addr      : std_logic_vector(12 downto 0);
  signal col_addr1     : std_logic_vector(1 downto 0);
  signal col_addr0     : std_logic_vector(9 downto 0);
  signal precharge_all : std_logic;
  
  type SD_A_SEL_TYPE is (SD_A_SEL_EXT_MODE_REG,
                         SD_A_SEL_MODE_REG,
                         SD_A_SEL_ROW_ADDR,
                         SD_A_SEL_COL_ADDR);
  signal sd_a_sel : SD_A_SEL_TYPE;

  type SD_BA_SEL_TYPE is (SD_BA_SEL_EXT_MODE_REG,
                         SD_BA_SEL_MODE_REG,
                         SD_BA_SEL_ADDR);
  signal sd_ba_sel : SD_BA_SEL_TYPE;

  -- Value for Extended Mode Register:
  --   normal drive strength, enable DLL
  constant EXT_MODE_REG : std_logic_vector(12 downto 0) :=
    "0000000000000";
  
  -- Value for Mode Register
  --   reset DLL, CL, sequential burst, BL
  constant MODE_REG : std_logic_vector(12 downto 0) :=
    "000010" & MR_CL & "0" & MR_BL;

  --------
  -- Timer
  --------

  -- Timer for average periodic refresh interval
  --   Initialized to T_REFI = 7 us (instead of 7.8 us) to account for 
  --   read/writes in progress.
  --   Timer counts from T_REFI-2 downto -1 for easy detection of
  --   "timer done". MSB is sign bit.
  constant T_REFI            : integer := 7 * CLK_FREQ_MHZ;
  signal   timer_tREFI       : signed(log2ceil(T_REFI-2) downto 0);
  constant TIMER_TREFI_INIT  : signed(log2ceil(T_REFI-2) downto 0)
    := to_signed(T_REFI-2, timer_tREFI'length);
  signal   timer_tREFI_start : std_logic;
  signal   timer_tREFI_done  : std_logic;

  -- Timer for SDRAM commands. To wait for n clock cycles, the timer must be
  -- initiated to the value n-2. The minimum allowed initial value is -1. In
  -- this case the timer is done in the next clock cycles.
  signal timer_cmd       : signed(5 downto 0);
  signal timer_cmd_init  : signed(5 downto 0);
  signal timer_cmd_start : std_logic;
  signal timer_cmd_done  : std_logic;
  
  -- Timer for ACTIVE-to-PRECHARGE.
  --   Timer counts from T_RAS-2 downto -1 for easy detection of
  --   "timer done". MSB is sign bit.
  --   Substract 1, because timer is checked one cycle before DO_PRECHARGE.
  signal   timer_tRAS       : signed(log2ceil(T_RAS-2) downto 0);
  constant TIMER_TRAS_INIT  : signed(log2ceil(T_RAS-2) downto 0)
    := to_signed(T_RAS-1 -2, timer_tRAS'length);
  signal   timer_tRAS_start : std_logic;
  signal   timer_tRAS_done  : std_logic;
  
  --------
  -- Counter
  --------

  -- Misc down counter. Counter is "done", when value == -1.
  -- Thus, if counter is inited to n, then counter is done n+2 decrements
  -- later. 
  signal downcnt      : signed(5 downto 0);
  signal downcnt_init : signed(5 downto 0);
  signal downcnt_set  : std_logic;
  signal downcnt_dec  : std_logic;
  signal downcnt_done : std_logic;

  --------
  -- Last address
  --------
  signal last_bank_addr_r   : std_logic_vector(bank_addr'range);
  signal last_bank_addr_nxt : std_logic_vector(bank_addr'range);
  signal last_row_addr_r    : std_logic_vector(row_addr'range);
  signal last_row_addr_nxt  : std_logic_vector(row_addr'range);
  signal last_write_r       : std_logic;
  signal last_write_nxt     : std_logic;
  signal save_cmd_addr      : std_logic;
  signal same_bank_row      : std_logic;
  
begin  -- rtl

  -----------------------------------------------------------------------------
  -- Configuration check
  -----------------------------------------------------------------------------

  assert (D_BITS = 16) or (D_BITS = 8) or (D_BITS = 4)
    report "Data width not yet supported."
    severity failure;
  
  -----------------------------------------------------------------------------
  -- Datapath not depending on FSM
  -----------------------------------------------------------------------------

  gAddr16 : if D_BITS = 16 generate
    assert A_BITS = 25
      report "Address width not yet supported."
      severity failure;
    
    col_addr0 <= std_logic_vector(user_addr(9 downto 0));
    col_addr1 <= "00";
    row_addr  <= std_logic_vector(user_addr(22 downto 10));
    bank_addr <= std_logic_vector(user_addr(24 downto 23));
  end generate;

  gAddr8 : if D_BITS = 8 generate
    assert A_BITS = 26
      report "Address width not yet supported."
      severity failure;
    
    col_addr0 <= std_logic_vector(user_addr(9 downto 0));
    col_addr1 <= "0" & user_addr(10);
    row_addr  <= std_logic_vector(user_addr(23 downto 11));
    bank_addr <= std_logic_vector(user_addr(25 downto 24));
  end generate;

  gAddr4 : if D_BITS = 4 generate
    assert A_BITS = 27
      report "Address width not yet supported."
      severity failure;

    col_addr0 <= std_logic_vector(user_addr(9 downto 0));
    col_addr1 <= std_logic_vector(user_addr(11 downto 10));
    row_addr  <= std_logic_vector(user_addr(24 downto 12));
    bank_addr <= std_logic_vector(user_addr(26 downto 25));
  end generate;

  timer_tREFI_done <= timer_tREFI(timer_tREFI'left);
  timer_cmd_done   <= timer_cmd(timer_cmd'left);
  timer_tRAS_done  <= timer_tRAS(timer_tRAS'left);
  downcnt_done     <= downcnt(downcnt'left);

  same_bank_row <= '1' when (last_bank_addr_r & last_row_addr_r) =
                            (bank_addr & row_addr) else '0';

  last_bank_addr_nxt <= bank_addr;
  last_row_addr_nxt  <= row_addr;
  last_write_nxt     <= user_write;
  
  -----------------------------------------------------------------------------
  -- FSM
  -----------------------------------------------------------------------------
  process (fsm_cs,
           timer_tREFI_done, timer_cmd_done, timer_tRAS_done,
           downcnt_done,
           same_bank_row, last_write_r,
           user_cmd_valid, user_write, user_wdata_valid)
  begin  -- process
    fsm_ns        <= fsm_cs;
    sd_cke_nxt    <= '1';
    sd_cmd_nxt    <= SD_CMD_DESELECT;
    sd_a_sel      <= SD_A_SEL_COL_ADDR;
    sd_ba_sel     <= SD_BA_SEL_ADDR;
    precharge_all <= '0';
    rden_nxt      <= '0';
    wren_nxt      <= '0';
    
    timer_tREFI_start <= '0';
    timer_tRAS_start  <= '0';
    
    timer_cmd_init <= (others => '-');
    timer_cmd_start <= '0';
    
    downcnt_init <= (others => '-');
    downcnt_set  <= '0';
    downcnt_dec  <= '0';
    
    user_got_cmd   <= '0';
    user_got_wdata <= '0';

    save_cmd_addr <= '0';
    
    case fsm_cs is
      when INIT1 =>
        -- Wait for 200 us by waiting 31+2 times for tREFI (= 7 us).
        -- Hold sd_cke low.
        sd_cke_nxt        <= '0';
        downcnt_init      <= to_signed(31, downcnt_init'length);
        downcnt_set       <= '1';
        timer_tREFI_start <= '1';
        fsm_ns            <= INIT2;

      when INIT2 =>
        sd_cke_nxt <= '0';
        
        if timer_tREFI_done = '1' then
          if downcnt_done = '1' then
            fsm_ns <= INIT3;
          else
            timer_tREFI_start <= '1';
            downcnt_dec       <= '1';
          end if;
        end if;
          
      when INIT3 =>
        -- Bring up sd_cke with a NOP command.
        sd_cmd_nxt <= SD_CMD_NOP;
        fsm_ns     <= INIT4;

      when INIT4 =>
        -- Precharge all.
        sd_cmd_nxt      <= SD_CMD_PRECHARGE;
        sd_a_sel        <= SD_A_SEL_COL_ADDR;
        precharge_all   <= '1';
        timer_cmd_init  <= to_signed(T_RP-2, timer_cmd_init'length);
        timer_cmd_start <= '1';
        fsm_ns          <= INIT5;

      when INIT5 =>
        sd_a_sel       <= SD_A_SEL_EXT_MODE_REG;
        sd_ba_sel      <= SD_BA_SEL_EXT_MODE_REG;
        timer_cmd_init <= to_signed(T_MRD-2, timer_cmd_init'length);
        
        if timer_cmd_done = '1' then
          -- Load extended mode register
          sd_cmd_nxt      <= SD_CMD_LOAD_MODE_REG;
          timer_cmd_start <= '1';
          fsm_ns          <= INIT6;
        end if;
        
      when INIT6 =>
        sd_a_sel       <= SD_A_SEL_MODE_REG;
        sd_ba_sel      <= SD_BA_SEL_MODE_REG;
        timer_cmd_init <= to_signed(T_MRD-2, timer_cmd_init'length);
        
        if timer_cmd_done = '1' then
          -- Load mode register
          sd_cmd_nxt            <= SD_CMD_LOAD_MODE_REG;
          timer_cmd_start <= '1';

          -- Wait for 200 cycles, by waiting for T_REFI = 7 us.
          -- This is juzst for reuse.
          timer_tREFI_start <= '1';
          fsm_ns            <= INIT7;
        end if;

      when INIT7 =>
        sd_a_sel       <= SD_A_SEL_COL_ADDR;
        precharge_all  <= '1';
        timer_cmd_init <= to_signed(T_RP-2, timer_cmd_init'length);
        
        if timer_cmd_done = '1' then
          -- Precharge all.
          sd_cmd_nxt      <= SD_CMD_PRECHARGE;
          timer_cmd_start <= '1';
          fsm_ns          <= INIT8;
        end if;

      when INIT8 =>
        timer_cmd_init <= to_signed(T_RFC-2, timer_cmd_init'length);
        
        if timer_cmd_done = '1' then
          -- First auto refresh.
          sd_cmd_nxt      <= SD_CMD_AUTO_REFRESH;
          timer_cmd_start <= '1';
          fsm_ns          <= INIT9;
        end if;

      when INIT9 =>
        timer_cmd_init <= to_signed(T_RFC-2, timer_cmd_init'length);
        
        if timer_cmd_done = '1' then
          -- Second auto refresh.
          sd_cmd_nxt      <= SD_CMD_AUTO_REFRESH;
          timer_cmd_start <= '1';
          fsm_ns          <= INIT10;
        end if;

      when INIT10 =>
        timer_cmd_init <= to_signed(T_RFC-2, timer_cmd_init'length);
        
        if timer_tREFI_done = '1' then
          -- Now, we have waited for at least 200 cycles.
          -- Schedule another auto refresh and restart T_REFI timer.
          sd_cmd_nxt        <= SD_CMD_AUTO_REFRESH;
          timer_cmd_start   <= '1';
          timer_tREFI_start <= '1';
          fsm_ns            <= DO_ACTIVATE;
        end if;

      when DO_ACTIVATE =>
        -- For activate row.
        sd_a_sel  <= SD_A_SEL_ROW_ADDR;
        sd_ba_sel <= SD_BA_SEL_ADDR;
        
        -- wait for finish of last command, before executing new one
        if timer_cmd_done = '1' then
          if user_cmd_valid = '1' then
            -- Activate Row
            sd_cmd_nxt      <= SD_CMD_ACTIVE;
            timer_cmd_init  <= to_signed(T_RCD-2, timer_cmd_init'length);
            timer_cmd_start <= '1';
            timer_tRAS_start<= '1';
            
            if user_write = '1' then
              fsm_ns <= DO_WRITE1;
            else
              fsm_ns <= DO_READ1;
            end if;
            
          elsif timer_tREFI_done = '1' then
            -- Auto Refresh
            sd_cmd_nxt        <= SD_CMD_AUTO_REFRESH;
            timer_cmd_init    <= to_signed(T_RFC-2, timer_cmd_init'length);
            timer_cmd_start   <= '1';
            timer_tREFI_start <= '1';
            --fsm_ns <= DO_ACTIVATE;
          end if;
        end if;

      when DO_READ1 =>
        -- wait for CL cycles.
        -- Substract 1 because CHECKNXT is entered before
        -- DO_PRECHARGE.
        timer_cmd_init  <= to_signed(CL-1 -2,
                                     timer_cmd_init'length);

        -- Additional burst cycles: (BL/2)-1
        downcnt_init <= to_signed((BL/2)-1-2, downcnt_init'length);

        sd_a_sel  <= SD_A_SEL_COL_ADDR;
        sd_ba_sel <= SD_BA_SEL_ADDR;
        
        if timer_cmd_done = '1' then
          -- Read first
          sd_cmd_nxt      <= SD_CMD_READ;
          rden_nxt        <= '1';
          timer_cmd_start <= '1';
          downcnt_set     <= '1';
          user_got_cmd    <= '1';
          save_cmd_addr   <= '1';

          if BL = 2 then
            fsm_ns <= CHECKNXT;
          else
            fsm_ns <= DO_READ2;
          end if;
        end if;

      when DO_READ2 =>
        if BL > 2 then
          -- Read more
          downcnt_dec <= '1';
          rden_nxt    <= '1';
          
          if downcnt_done = '1' then
            fsm_ns <= CHECKNXT;
          end if;
        end if;

      when DO_WRITE1 =>
        -- wait for 1 + (BL/2) + T_WR cycles
        -- Substract 1 because CHECKNXT is entered before
        -- DO_PRECHARGE.
        timer_cmd_init  <= to_signed(1+(BL/2)+T_WR-1 -2,
                                     timer_cmd_init'length);

        -- Additional burst cycles: (BL/2)-1
        downcnt_init <= to_signed((BL/2)-1-2, downcnt_init'length);
        
        sd_a_sel  <= SD_A_SEL_COL_ADDR;
        sd_ba_sel <= SD_BA_SEL_ADDR;
        
        if (timer_cmd_done and user_wdata_valid) = '1' then
          -- Write first
          sd_cmd_nxt      <= SD_CMD_WRITE;
          wren_nxt        <= '1';
          timer_cmd_start <= '1';
          downcnt_set     <= '1';
          user_got_cmd    <= '1';
          user_got_wdata  <= '1';
          save_cmd_addr   <= '1';

          if BL = 2 then
            fsm_ns <= CHECKNXT;
          else
            fsm_ns <= DO_WRITE2;
          end if;
        end if;

      when DO_WRITE2 =>
        if BL > 2 then
          -- Write more
          downcnt_dec    <= '1';
          wren_nxt       <= '1';
          user_got_wdata <= '1';
          
          if downcnt_done = '1' then
            fsm_ns <= CHECKNXT;
          end if;
        end if;
        
      when CHECKNXT =>
        if last_write_r = '1' then
          -- last was write
          if user_write = '1' then
            -- write-to-write to same bank and row
            -- Set timer to zero.
            timer_cmd_init <= to_signed(-2, timer_cmd_init'length);
          else
            -- write-to-read to same bank and row
            -- We must wait for 1+(BL/2)+T_WTR cycles since start of write.
            -- We already waited for (BL/2) due to execution of burst.
            timer_cmd_init <= to_signed(1+T_WTR -2, timer_cmd_init'length);
          end if;
        else
          -- last was read
          if user_write = '1' then
            -- read-to-write to same bank and row
            -- We must wait for (BL/2)+CL cycles since start of read.
            -- We already waited for (BL/2) due to execution of burst.
            timer_cmd_init <= to_signed(CL -2, timer_cmd_init'length);
          else
            -- read-to-read to same bank and row
            -- Set timer to zero.
            timer_cmd_init <= to_signed(-2, timer_cmd_init'length);
          end if;
          
        end if;
        
        if timer_tREFI_done = '1' then
          -- A refresh is pending.
          -- Wait here until timer_tRAS is done.
          if timer_tRAS_done = '1' then
            fsm_ns <= DO_PRECHARGE;
          end if;
          
        elsif (user_cmd_valid and same_bank_row) = '1' then
          -- Access to same bank and row.
          -- Wait timer is initiated above.
          timer_cmd_start <= '1';
          if user_write = '1' then
            fsm_ns <= DO_WRITE1;
          else
            fsm_ns <= DO_READ1;
          end if;
          
        elsif timer_cmd_done = '1' then
          -- Execute a precharge now for minimum latency of next access to
          -- another bank/row.
          -- Wait here until timer_tRAS is done.
          if timer_tRAS_done = '1' then
            fsm_ns <= DO_PRECHARGE;
          end if;

        --else: check again
        end if;

      when DO_PRECHARGE =>
        timer_cmd_init  <= to_signed(T_RP-2, timer_cmd_init'length);
        
        if timer_cmd_done = '1' then
          -- Precharge
          -- NOTE: It is sufficient to precharge the bank in use.
          -- But, because the address isn't saved, the bank is unknown.
          -- Thus, precharge ALL.
          sd_cmd_nxt      <= SD_CMD_PRECHARGE;
          precharge_all   <= '1';
          timer_cmd_start <= '1';
          if timer_tREFI_done = '1' then
            fsm_ns <= DO_AUTO_REFRESH;
          else
            fsm_ns <= DO_ACTIVATE;
          end if;
        end if;

      when DO_AUTO_REFRESH =>
        timer_cmd_init  <= to_signed(T_RFC-2, timer_cmd_init'length);
        
        if timer_cmd_done = '1' then
          -- Auto refresh
          sd_cmd_nxt        <= SD_CMD_AUTO_REFRESH;
          timer_cmd_start   <= '1';
          timer_tREFI_start <= '1';
          fsm_ns            <= DO_ACTIVATE;
        end if;

    end case;
  end process;

  -----------------------------------------------------------------------------
  -- Datapath depending on FSM output
  --
  -- Command and address are registered again in the physical layer.
  -----------------------------------------------------------------------------

  sd_cs_nxt  <= sd_cmd_nxt(3);
  sd_ras_nxt <= sd_cmd_nxt(2);
  sd_cas_nxt <= sd_cmd_nxt(1);
  sd_we_nxt  <= sd_cmd_nxt(0);
  
  with sd_a_sel select
    sd_a_nxt <=
    EXT_MODE_REG when SD_A_SEL_EXT_MODE_REG,
    MODE_REG     when SD_A_SEL_MODE_REG,
    row_addr     when SD_A_SEL_ROW_ADDR,
    col_addr1 & precharge_all & col_addr0
                 when others;           -- SD_A_SEL_COL_ADDR

  with sd_ba_sel select
    sd_ba_nxt <=
    "01"      when SD_BA_SEL_EXT_MODE_REG,
    "00"      when SD_BA_SEL_MODE_REG,
    bank_addr when others;              -- SD_BA_SEL_ADDR
  
  -----------------------------------------------------------------------------
  -- Registers
  -----------------------------------------------------------------------------

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        fsm_cs <= INIT1;
      else
        fsm_cs <= fsm_ns;
      end if;

      if timer_tREFI_start = '1' then
        timer_tREFI <= TIMER_TREFI_INIT;
      elsif timer_tREFI_done = '0' then
        -- auto decrement
        timer_tREFI <= timer_tREFI - 1;
      end if;

      if timer_cmd_start = '1' then
        timer_cmd <= timer_cmd_init;
      elsif timer_cmd_done = '0' then
        -- auto decrement
        timer_cmd <= timer_cmd - 1;
      end if;

      if timer_tRAS_start = '1' then
        timer_tRAS <= TIMER_TRAS_INIT;
      elsif timer_tRAS_done = '0' then
        -- auto decrement
        timer_tRAS <= timer_tRAS - 1;
      end if;

      if downcnt_set = '1' then
        downcnt <= downcnt_init;
      elsif downcnt_dec = '1' then
        downcnt <= downcnt - 1;
      end if;

      if save_cmd_addr = '1' then
        last_write_r     <= last_write_nxt;
        last_bank_addr_r <= last_bank_addr_nxt;
        last_row_addr_r  <= last_row_addr_nxt;
      end if;
    end if;
  end process;
end rtl;
