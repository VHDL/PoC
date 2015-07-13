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
-- Entity: vga_testcard3_data
-- Author(s): Peter Reichel, Martin Zabel
-- 
-- Generates testcard data for 3-Bit color output. For a complete testcard
-- design see vga_testcard3.
--
-- The sizes of x- and y-coordinate can be configured with XPOS_BITS and
-- YPOS_BITS.
--
-- The clock frequency must be specified by CLK_FREQ in Hz.
--
-- pixel_data(2) = red
-- pixel_data(1) = green
-- pixel_data(0) = blue
--
-- PHY control signals must be pipelined according to calculation of the
-- pixel data. Thus, these are fed through this unit.
-- See also ../README.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-02-16 09:35:15 $
--

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;
use poc.vga.all;

entity vga_testcard3_data is
  generic (
    CLK_FREQ  : positive; -- := 25000000;
    XPOS_BITS : positive; -- := 10;
    YPOS_BITS : positive);-- := 10);
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    xpos        : in  unsigned (XPOS_BITS-1 downto 0);
    ypos        : in  unsigned (YPOS_BITS-1 downto 0);
    phy_ctrl_in : in  VGA_PHY_CTRL_TYPE;
    phy_ctrl_out: out VGA_PHY_CTRL_TYPE;
    pixel_data  : out std_logic_vector (2 downto 0));
end vga_testcard3_data;

architecture rtl of vga_testcard3_data is
  signal one_sec_pulse  : std_logic;
  signal five_sec_pulse : std_logic;
  
  type tPixSel is ( CTRL_PIXSEL_RED,
                    CTRL_PIXSEL_GREEN,
                    CTRL_PIXSEL_BLUE,
                    CTRL_PIXSEL_HORI_LINES,
                    CTRL_PIXSEL_VERT_LINES,
                    CTRL_PIXSEL_CROSS_LINES,
                    CTRL_PIXSEL_TESTCARD,
                    CTRL_PIXSEL_HOLD
                  );
  signal ctrl_pixsel : tPixSel;
  signal reg_pixel_data : std_logic_vector(2 downto 0);
  signal nxt_pixel_data : std_logic_vector(2 downto 0);
  
  signal pixel_hori_lines  : std_logic_vector(2 downto 0);
  signal pixel_vert_lines  : std_logic_vector(2 downto 0);
  signal pixel_cross_lines : std_logic_vector(2 downto 0);
  signal pixel_testcard    : std_logic_vector(2 downto 0);
  
  type tState is ( S_BEGIN, S_RED, S_GREEN, S_BLUE, S_HORILINES, S_VERTLINES, S_CROSS, S_TESTCARD );
  signal fsm_cs : tState;
  signal fsm_ns : tState;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        fsm_cs <= S_BEGIN;
      else
        fsm_cs <= fsm_ns;
      end if;
    end if;
  end process;
  
  process(fsm_cs, one_sec_pulse, five_sec_pulse)
  begin
    fsm_ns      <= fsm_cs;
    ctrl_pixsel <= CTRL_PIXSEL_HOLD;
    
    case fsm_cs is
      when S_BEGIN =>
        if five_sec_pulse = '1' then
          fsm_ns <= S_RED;
        end if;
        
      when S_RED =>
        ctrl_pixsel <= CTRL_PIXSEL_RED;
        if one_sec_pulse = '1' then
          fsm_ns <= S_GREEN;
        end if;
        
      when S_GREEN =>
        ctrl_pixsel <= CTRL_PIXSEL_GREEN;
        if one_sec_pulse = '1' then
          fsm_ns <= S_BLUE;
        end if;
        
      when S_BLUE =>
        ctrl_pixsel <= CTRL_PIXSEL_BLUE;
        if one_sec_pulse = '1' then
          fsm_ns <= S_HORILINES;
        end if;
        
      when S_HORILINES =>
        ctrl_pixsel <= CTRL_PIXSEL_HORI_LINES;
        if one_sec_pulse = '1' then
          fsm_ns <= S_VERTLINES;
        end if;
        
      when S_VERTLINES =>
        ctrl_pixsel <= CTRL_PIXSEL_VERT_LINES;
        if one_sec_pulse = '1' then
          fsm_ns <= S_CROSS;
        end if;

      when S_CROSS =>
        ctrl_pixsel <= CTRL_PIXSEL_CROSS_LINES;
        if one_sec_pulse = '1' then
          fsm_ns <= S_TESTCARD;
        end if;
        
      when S_TESTCARD =>
        -- end state
        ctrl_pixsel <= CTRL_PIXSEL_TESTCARD;
    end case;
  end process;

  -- horizontal-lines
  process(ypos)
  begin
    pixel_hori_lines <= "000";
    
    if ypos(3 downto 0) = 0 then
      pixel_hori_lines <= "111";
    end if;
  end process;

  -- vertical-lines
  process(xpos)
  begin
    pixel_vert_lines <= "000";
    
    if xpos(3 downto 0) = 0 then
      pixel_vert_lines <= "111";
    end if;
  end process;

  -- cross
  process(xpos, ypos)
  begin
    pixel_cross_lines <= "000";
    
    if xpos(3 downto 0) = 0 or ypos(3 downto 0) = 0 then
      pixel_cross_lines <= "111";
    end if;
  end process;

  -- testcard
  process(xpos, ypos)
  begin
    pixel_testcard <= "000";

    -- cross
    if xpos(3 downto 0) = 0 or ypos(3 downto 0) = 0 then
      pixel_testcard <= "111";
    end if;

    -- colors
    if ypos > 100 and ypos < 200 then
      if xpos >= 80 and xpos < 140 then
        pixel_testcard <= "111";
      elsif xpos >= 140 and xpos < 200 then
        pixel_testcard <= "110";
      elsif xpos >= 200 and xpos < 260 then
        pixel_testcard <= "011";
      elsif xpos >= 260 and xpos < 320 then
        pixel_testcard <= "010";
      elsif xpos >= 320 and xpos < 380 then
        pixel_testcard <= "101";
      elsif xpos >= 380 and xpos < 440 then
        pixel_testcard <= "100";
      elsif xpos >= 440 and xpos < 500 then
        pixel_testcard <= "001";
      elsif xpos >= 500 and xpos < 560 then
        pixel_testcard <= "000";
      end if;
    end if;
  end process;

  -- Select pixel data
  with ctrl_pixsel select nxt_pixel_data <=
    "100"                                           when CTRL_PIXSEL_RED,
    "010"                                           when CTRL_PIXSEL_GREEN,
    "001"                                           when CTRL_PIXSEL_BLUE,
    pixel_hori_lines                                when CTRL_PIXSEL_HORI_LINES,
    pixel_vert_lines                                when CTRL_PIXSEL_VERT_LINES,
    pixel_cross_lines                               when CTRL_PIXSEL_CROSS_LINES,
    pixel_testcard                                  when CTRL_PIXSEL_TESTCARD,
    reg_pixel_data                                  when others;

  process(clk)
  begin
    if rising_edge(clk) then
      -- Reset state don't care.
      reg_pixel_data <= nxt_pixel_data;
      phy_ctrl_out   <= phy_ctrl_in;
    end if;
  end process;
  pixel_data <= reg_pixel_data;
  
  -----------------------------------------------
  -- 5- and 1-sec counter
  cnt_blk : block
    signal reg_5cnt  : unsigned(2 downto 0);
    signal ctrl_clr5 : std_logic;
    signal reg_1cnt  : unsigned(log2ceil(CLK_FREQ+1)-1 downto 0);
    signal ctrl_clr1 : std_logic;
  begin
    process(clk)
    begin
      if rising_edge(clk) then
        if (rst or ctrl_clr1) = '1' then
          reg_1cnt <= (others => '0');
        else
          reg_1cnt <= reg_1cnt + 1;
        end if;
      end if;
    end process;
    ctrl_clr1 <= '1' when reg_1cnt = CLK_FREQ else '0';
    
    process(clk)
    begin
      if rising_edge(clk) then
        if (rst or ctrl_clr5) = '1' then
          reg_5cnt <= (others => '0');
        elsif one_sec_pulse = '1' then
          reg_5cnt <= reg_5cnt + 1;
        end if;
      end if;
    end process;
    ctrl_clr5 <= '1' when reg_5cnt = 5 else '0';
    
    
    one_sec_pulse  <= ctrl_clr1;
    five_sec_pulse <= ctrl_clr5;
  end block;

end rtl;

