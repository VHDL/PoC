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
-- Package: lcd
-- Author(s): Thomas B. Preußer, Martin Zabel
-- 
-- LCD Controller with 4-Bit data bus
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2008-11-03 19:50:03 $
--

-------------------------------------------------------------------------------
-- stb:      strobe
-- addr = 0: select LCD command register
-- addr = 1: select LCD data register
-- din:      byte to write
-- rdy:      ready for next strobe
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------
-- Interface

entity lcd4 is
  port(
    -- Global Reset and Clock
    rst, clk	: in std_logic;

    -- Upper Layer Interface
    stb      : in  std_logic;
    addr     : in  std_logic;
    din      : in  std_logic_vector(7 downto 0);
    rdy      : out std_logic;
    
    -- LCD Connections
    lcd_e   : out   std_logic;                    -- Enable
    lcd_rs  : out   std_logic;                    -- Register Select
    lcd_rw  : out   std_logic;                    -- Read / Write
    lcd_dat_o : out std_logic_vector(3 downto 0); -- Data - Output
    lcd_dat_t : out std_logic;                    -- Data - Tristate, if t=0 then output data
    lcd_dat_i : in  std_logic_vector(3 downto 0)  -- Data - Input
  );
end entity lcd4;

-------------------------------------------------------------------------------
-- Implementation
-------------------------------------------------------------------------------
-- Smaller Implementation (Default)

architecture lcd4_impl2 of lcd4 is
-- Machine State---------------------------------------------------------------
type   tState is (Recover, BusyTest, BusyTest2, BusyTest3, BusyHold, Idle, put_l_settle, put_l_hold, put_h_settle, put_h_hold, put_h_wait, put_l_wait, put_h_post, put_l_post);
signal State	 : tState := Recover;
signal NextState : tState;

-- Command / Data Buffer ------------------------------------------------------
signal CD      : std_logic                    := '-';
signal HBuf    : std_logic_vector(3 downto 0) := (others => '-');
signal LBuf 	: std_logic_vector(3 downto 0) := (others => '-');
signal LoadCD  : std_logic;             -- Load CD
signal LoadBuf : std_logic;             -- Load Cmd/Data Word
signal busy_rd : std_logic;

-- Busy Cycle Counter----------------------------------------------------------
signal Count      : unsigned(11 downto 0) := (others => '0');
signal CountNext  : unsigned(11 downto 0);
signal BCountDone : std_logic;
signal ECountDone : std_logic;
signal EDownCountDone : std_logic;
signal PCountDone : std_logic;
signal WDownCountDone : std_logic;
signal CountInc   : std_logic;
signal CountClr   : std_logic;


-- Buffered Busy-Flag ---------------------------------------------------------
signal BF : std_logic := '-';

begin
  -- Main State Machine
  process(State, stb, ECountDone, BCountDone, PCountDone, EDownCountDone,WDownCountDone, PCountDone, BF, CD, LBuf, HBuf)
  begin
    NextState <= State;

    rdy <= '0';                         -- ready for output

    LoadCD  <= '0';                     -- load output register
    LoadBuf <= '0';

    CountInc <= '0';
    CountClr <= '0';

    lcd_e   <= '0';
    lcd_rs  <= '0';
    lcd_rw  <= '1';                  -- changed!!!
    lcd_dat_o <= (others => '-');
    lcd_dat_t <= '1';  -- output disabled
    
    busy_rd <= '0';

    case State is
      
      when Recover =>
        CountInc <= '1';
        if ECountDone = '1' then
          CountClr  <= '1';
          NextState <= BusyTest;
        end if;

      when BusyTest =>
        lcd_e    <= '1';
        CountInc <= '1';
        busy_rd <= '1';
        
        if ECountDone = '1' then
          CountClr <= '1';
          NextState <= BusyTest2;
        end if;

      when BusyTest2 =>
        CountInc <= '1';
        if EDownCountDone = '1' then
          CountClr <= '1';
          NextState <= BusyTest3;
        end if;
        
      when BusyTest3 =>
        lcd_e   <= '1';
        CountInc <= '1';
        if ECountDone = '1' then
          CountClr <= '1';
          if BF = '1' then
            NextState <= Recover;
          else
            NextState <= BusyHold;
          end if;
        end if;
        
      when BusyHold =>
        CountInc <= '1';
        if BCountDone = '1' then
          CountClr  <= '1';
          NextState <= Idle;
        end if;

      when Idle =>
        rdy <= '1';
        if stb = '1' then
          LoadCD    <= '1';
          LoadBuf   <= '1';
          NextState <= put_h_settle;
        end if;

      when put_h_settle =>
        lcd_rs	<= CD;
        lcd_rw	<= '0';
        lcd_dat_o <= HBuf;
        lcd_dat_t <= '0';
        
        CountInc <= '1';
        if PCountDone = '1' then
          CountClr <= '1';
          NextState <= put_h_hold;
        end if;
        
      when put_h_hold =>
        lcd_e	<= '1';
        lcd_rs	<= CD;
        lcd_rw	<= '0';
        lcd_dat_o <= HBuf;
        lcd_dat_t <= '0';

        CountInc <= '1';
        if ECountDone = '1' then
          CountClr  <= '1';
          NextState <= put_h_post;
        end if;
        
      when put_h_post =>
        lcd_rs <= CD;
        lcd_rw <= '0';
        lcd_dat_o <= HBuf;
        lcd_dat_t <= '0';
        
        NextState <= put_h_wait;
        
      when put_h_wait =>
        lcd_rs <= CD;
        lcd_rw <= '0';
        
        
        CountInc <= '1';
        if EDownCountDone = '1' then
          CountClr <= '1';
          NextState <= put_l_settle;
        end if;
        
      when put_l_settle =>
        lcd_rs	<= CD;
        lcd_rw	<= '0';
        lcd_dat_o <= LBuf;
        lcd_dat_t <= '0';
        
        CountInc <= '1';
        if PCountDone = '1' then
          CountClr <= '1';
          NextState <= put_l_hold;
        end if;
        
      when put_l_hold =>
        lcd_e	<= '1';
        lcd_rs	<= CD;
        lcd_rw	<= '0';
        lcd_dat_o <= LBuf;
        lcd_dat_t <= '0';

        CountInc <= '1';
        if ECountDone = '1' then
          CountClr  <= '1';
          NextState <= put_l_post;
        end if;
        
      when put_l_post =>
        lcd_rs <= CD;
        lcd_rw <= '0';
        lcd_dat_o <= LBuf;
        lcd_dat_t <= '0';
        
        NextState <= put_l_wait;

      when put_l_wait =>
        CountInc <= '1';
        if WDownCountDone = '1' then
          CountClr <= '1';
          NextState <= Recover;
        end if;
        
    end case;
  end process;

  process(rst, clk)
  begin
    if clk'event and clk = '1' then
      -- State Register
      if rst = '1' then
        State <= Recover;
      else
        State <= NextState;
      end if;

      -- Data Command Buffer
      if LoadCD = '1' then
        CD <= addr;
      end if;
      
      if LoadBuf = '1' then
        HBuf <= din(7 downto 4);
        LBuf <= din(3 downto 0);
      end if;
      
      -- Cycle Counter
      if (rst or CountClr) = '1' then
        Count <= (others => '0');
      elsif CountInc = '1' then
        Count <= CountNext;
      end if;
      
      -- Busy Flag
      if busy_rd = '1' then
        BF <= lcd_dat_i(3);
      end if;
    end if; 
  end process;

  -- Counter Combinatorics
  CountNext  <= Count + 1;
  ECountDone <= Count(4);
  EDownCountDone <= Count(5) and Count(4);
  BCountDone <= Count(6) and not CountNext(6);
  WDownCountDone <= Count(11);
  PCountDone <= Count(1);

end lcd4_impl2;
