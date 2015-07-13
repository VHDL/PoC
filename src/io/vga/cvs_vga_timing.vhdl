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
-- Entity: vga_timing
-- Author(s): Peter Reichel, Martin Zabel
-- 
-- Generates timing for several VGA/VESA video modes.
--
-- Configuration:
-- --------------
--
-- MODE = 0: VGA mode with  640x480  pixels, 60 Hz, frequency(clk) ~  25   MHz
-- MODE = 1: HD  720p with 1280x720  pixels, 60 Hz, frequency(clk) =  74,5 MHz
-- MODE = 2: HD 1080p with 1920x1080 pixels, 60 Hz, frequency(clk) = 138,5 MHz
--
-- MODE = 2 uses reduced blanking => only suitable for LCDs.
--
-- For MODE = 0, CVT can be configured:
-- - CVT = false: Use Safe Mode Timing (SMT).
--   The legacy fall-back mode supported by CRTs as well as LCDs.
--   HSync: low-active. VSync: low-active.
--   frequency(clk) = 25.175 MHz. (25 MHz works => 31 kHz / 59 Hz)
-- - CVT = true: The "new" Coordinated Video Timing (since 2003).
--   The CVT supports some new features, such as reduced blanking (for LCDs) or
--   aspect ratio encoding. See the web for more details.
--   Standard CRT-based timing (CVT-GTF) has been implemented for best
--   compatibility:
--   HSync: low-active. VSync: high-active.
--   frequency(clk) = 23.75 MHz. (25 MHz works => 31 kHz / 62 Hz)
--
-- Usage:
-- ------
--
-- The frequency of 'clk' must be equal to the pixel clock frequency of the
-- selected video mode, see also above.
--
-- When using analog output, the VGA color signals must be blanked, during
-- horizontal and vertical beam return. This could be achieved by
-- combinatorial "anding" the color value with "beam_on" (part of "phy_ctrl")
-- inside the PHY. 
--
-- When using digital output (DVI), then "beam_on" is equal to "DE"
-- (Data Enable) of the DVI transmitter.
--
-- xvalid and yvalid show if xpos respectivly ypos are in a valid range.
-- beam_on is '1' iff both xvalid and yvalid = '1'.
--
-- xpos and ypos also show the pixel location during blanking.
-- This might be useful in some applications. But be careful, that the ranges
-- differ between SMT and CVT.
--
-- Revision:    $Revision: 1.8 $
-- Last change: $Date: 2013-07-06 16:49:20 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.vga.all;

entity vga_timing is
   generic (
      MODE : natural := 0;
      CVT : boolean := false);
   port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      phy_ctrl   : out VGA_PHY_CTRL_TYPE;
      xvalid     : out std_logic;
      yvalid     : out std_logic;
      line_end   : out std_logic;
      screen_end : out std_logic;
      xpos       : out unsigned(11 downto 0);
      ypos       : out unsigned(10 downto 0));
end vga_timing;

architecture rtl of vga_timing is
  -- Timing and polarity parameters.
  type PARAMS_TYPE is
  record
    haddr    : positive;                -- displayed horizontal pixels
    htotal_e : positive;                -- end   of htotal (inclusive)
    hsync_b  : positive;                -- begin of hsync
    hsync_e  : positive;                -- end   of hsync  (inclusive)
    vaddr    : positive;                -- displayed vertical pixels
    vtotal_e : positive;                -- end   of vtotal (inclusive)
    vsync_b  : positive;                -- begin of vsync
    vsync_e  : positive;                -- end   of vsync  (inclusive)
    hs_pol   : std_logic;               -- hsync polarity
    vs_pol   : std_logic;               -- vsync_polarity
  end record;

  -- Calculate Timing parameters.
  function calc_params return PARAMS_TYPE is
    variable res : PARAMS_TYPE;
  begin
    if MODE = 0 then                    -- VGA 640x480
      res.haddr    := 640;
      res.vaddr    := 480;
      res.htotal_e := 800-1;
      res.hsync_b  := res.haddr+16;     -- + h_front_porch
      res.hs_pol   := '0';
      
      if CVT then
        res.vtotal_e := 500-1;
        res.hsync_e  := res.hsync_b+64-1;
        res.vsync_b  := res.vaddr+3;    -- + v_front_porch
        res.vsync_e  := res.vsync_b+4-1;
        res.vs_pol   := '1';
      else
        res.vtotal_e := 525-1;
        res.hsync_e  := res.hsync_b+96-1;
        res.vsync_b  := res.vaddr+10;   -- + v_front_porch
        res.vsync_e  := res.vsync_b+2-1;
        res.vs_pol   := '0';
      end if;
      
    elsif MODE = 1 then                   -- HD 720p 1280x720
      res.haddr    := 1280;
      res.htotal_e := 1664-1;             -- hor_total -1
      res.hsync_b  := res.haddr+64;       -- + h_front_porch
      res.hsync_e  := res.hsync_b+128-1;  -- + hor_sync -1
      res.vaddr    := 720;
      res.vtotal_e := 748-1;              -- ver_total -1
      res.vsync_b  := res.vaddr+3;        -- + v_front_porch
      res.vsync_e  := res.vsync_b+5-1;    -- + ver_sync -1
      res.hs_pol   := '0';                -- negative
      res.vs_pol   := '1';                -- positive
      
    elsif MODE = 2 then                   -- HD 1080p 1920x1080
      res.haddr    := 1920;
      res.htotal_e := 2080-1;             -- hor_total -1
      res.hsync_b  := res.haddr+48;       -- + h_front_porch
      res.hsync_e  := res.hsync_b+32-1;   -- + hor_sync -1
      res.vaddr    := 1080;
      res.vtotal_e := 1111-1;              -- ver_total -1
      res.vsync_b  := res.vaddr+3;        -- + v_front_porch
      res.vsync_e  := res.vsync_b+5-1;    -- + ver_sync -1
      res.hs_pol   := '1';                -- positive
      res.vs_pol   := '0';                -- negative
      
    else
      assert false report "MODE " & integer'image(MODE) & " is not supported!"
        severity failure;
    end if;
    
    return res;
  end function;

   constant params : PARAMS_TYPE := calc_params;
   
   signal xcount : unsigned(11 downto 0);
   signal ycount : unsigned(10 downto 0);
  
   signal ctrl_rst_x : std_logic;
   signal ctrl_inc_x : std_logic;
   signal ctrl_rst_y : std_logic;
   signal ctrl_inc_y : std_logic;
   signal xvalid_nxt : std_logic;
   signal yvalid_nxt : std_logic;
   
begin
   -- counter register
   process(clk, rst)
   begin
      if rising_edge(clk) then
         if (rst or ctrl_rst_x) = '1' then
            xcount <= to_unsigned(0,xcount'length);
         elsif ctrl_inc_x = '1' then
            xcount <= xcount + 1;
         end if;
         
         if (rst or ctrl_rst_y) = '1' then
            ycount <= to_unsigned(0,ycount'length);
         elsif ctrl_inc_y = '1' then
            ycount <= ycount + 1;
         end if;
      end if;
   end process;

   -- calculate internal control signals
   process(xcount, ycount)
   begin
      ctrl_rst_x     <= '0';
      ctrl_inc_x     <= '0';
      ctrl_rst_y     <= '0';
      ctrl_inc_y     <= '0';
      yvalid_nxt     <= '0';
      xvalid_nxt     <= '0';
      
      -- end of current line
      if xcount = params.htotal_e then
         ctrl_inc_y <= '1';
         ctrl_rst_x <= '1';
      else
         ctrl_inc_x <= '1';
      end if;
      
      -- end of current screen
      if xcount = params.htotal_e and ycount = params.vtotal_e then
         ctrl_rst_y <= '1';
      end if;
         
      -- yvalid
      if (ycount >= 0 and ycount < params.vaddr) then
         yvalid_nxt <= '1';
      end if;
         
      -- xvalid
      if (xcount >= 0 and xcount < params.haddr) then
         xvalid_nxt <= '1';
      end if;
   end process;
   
   -- calculate control signals for registered outputs
   process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            -- keep low during reset
            yvalid           <= '0';
            xvalid           <= '0';
            phy_ctrl.beam_on <= '0';
         else
            yvalid           <= yvalid_nxt;
            xvalid           <= xvalid_nxt;
            phy_ctrl.beam_on <= xvalid_nxt and yvalid_nxt;
         end if;
         
         line_end       <= ctrl_rst_x;
         screen_end     <= ctrl_rst_y;
         xpos           <= xcount;
         ypos           <= ycount;
         
         -- hsync
         if xcount >= params.hsync_b and xcount <= params.hsync_e then
            phy_ctrl.hsync <= params.hs_pol;
         else
            phy_ctrl.hsync <= not params.hs_pol;
         end if;
         
         -- vsync
         if ycount >= params.vsync_b and ycount <= params.vsync_e then
            phy_ctrl.vsync <= params.vs_pol;
         else
            phy_ctrl.vsync <= not params.vs_pol;
         end if;
      end if;
   end process;
end rtl;
