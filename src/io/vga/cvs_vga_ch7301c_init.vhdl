--
-- Copyright (c) 2013
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
-- Entity: vga_ch7301c_init
-- Author(s): Martin Zabel
-- 
-- Generates IIC initialization sequence to setup a CH7301C DVI transmitter.
-- The IIC master itself is not part of this entity.
-- See also ../README.
--
-- CLK_FREQ is the *pixel* clock frequency in Hz.
-- CVT must be equal to configuration of module "vga_timing".
-- DEV_ADDR is the IIC device address of the DVI transmitter.
-- RGB_BYPASS enables the analog part of the DVI connector.
--
-- 'clk' / 'rst' must be equal to the clock/reset of the IIC master!
-- 'status' shows initialization status:
--    "00"  = in progress
--    "01"  = successfull
--    "10"  = failed
-- 'error' holds error code, see implementation.
--
-- All others signals constitute the IIC interface is derived from
-- entity "i2c_master_byte_ctrl" from OpenCores.
--
-- The following DVI transmitter registers are initialized:
--
-- Register      Value       Description
-- -----------------------------------
-- 0x49 PM       0xC0        Enable DVI, RGB bypass off
--            or 0xD0        Enable DVI, RGB bypass on
-- 0x33 TPCP     0x08 if clk_freq <= 65 MHz else 0x06
-- 0x34 TPD      0x16 if clk_freq <= 65 MHz else 0x26
-- 0x36 TPF      0x60 if clk_freq <= 65 MHz else 0xA0
-- 0x1F IDF      0x80        when using SMT (VS0, HS0)
--            or 0x90        when using CVT (VS1, HS0)
-- 0x21 DC       0x09        Enable DAC if RGB bypass is on
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2013-07-02 15:12:14 $
--

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;

library poc;
use poc.vga.all;
use poc.ddrio.all;

entity vga_ch7301c_init is
  generic (
    CLK_FREQ   : positive;
    CVT        : boolean;
    DEV_ADDR   : std_logic_vector(6 downto 0);
    RGB_BYPASS : boolean);
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    status  : out std_logic_vector(1 downto 0);
    error   : out std_logic_vector(3 downto 0);
    
    start   : out std_logic;
    stop    : out std_logic;
    read    : out std_logic;
    write   : out std_logic;
    ack_in  : out std_logic;
    din     : out std_logic_vector(7 downto 0);
    cmd_ack : in  std_logic;
    ack_out : in  std_logic;
    dout    : in  std_logic_vector(7 downto 0));
end vga_ch7301c_init;

architecture rtl of vga_ch7301c_init is
    type FSM_TYPE is (RESETTING, FINISHED, FAIL,
                      DID1, DID2, DID3, DID4,
                      PM1, PM2, PM3,
                      TPCP1, TPCP2, TPCP3,
                      TPD1, TPD2, TPD3,
                      TPF1, TPF2, TPF3,
                      IDF1, IDF2, IDF3,
                      DAC1, DAC2, DAC3,
                      TSTP1, TSTP2, TSTP3);
    signal fsm_cs : FSM_TYPE;
    signal fsm_ns : FSM_TYPE;
    
    signal set_err : std_logic;
begin  -- rtl
    process (fsm_cs, cmd_ack, ack_out)
    begin  -- process
      fsm_ns  <= fsm_cs;
      set_err <= '0';
      status  <= "00";
      
      start  <= '0';
      stop   <= '0';
      read   <= '0';
      write  <= '0';
      ack_in <= '-';
      din    <= (others => '-');

      --
      -- See Chrontel AN-41 for adress / data protocol.
      --
      case fsm_cs is
        when RESETTING =>
          fsm_ns <= DID1;

        when DID1 =>
          -- Read device ID from CH7301C => "00010111"
          start <= '1';
          write <= '1';                 -- output device address
          din   <= DEV_ADDR & '0';      -- write to device
          if cmd_ack = '1' then
            fsm_ns <= DID2;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when DID2 =>
          write <= '1';                 -- output register address
          din   <= x"CB";               -- DID register, MSB set
          if cmd_ack = '1' then
            fsm_ns <= DID3;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when DID3 =>
          start <= '1';                 -- continue, but other direction
          write <= '1';
          din   <= DEV_ADDR & '1';      -- read from device
          if cmd_ack = '1' then
            fsm_ns <= DID4;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

          
        when DID4 =>
          read   <= '1';
          ack_in <= '1';                -- NACK: last byte
          stop   <= '1';
          if cmd_ack = '1' then
            fsm_ns  <= PM1;
          end if;

        when PM1 =>
          start <= '1';
          write <= '1';                 -- output device address
          din   <= DEV_ADDR & '0';      -- write to device
          if cmd_ack = '1' then
            fsm_ns <= PM2;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when PM2 =>
          write <= '1';                 -- output register address
          din   <= x"C9";               -- PM register, MSB set
          if cmd_ack = '1' then
            fsm_ns <= PM3;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when PM3 =>
          write <= '1';
          if RGB_BYPASS then
            din   <= "11010000";          -- DVI on, RGB bypass
          else
            din   <= "11000000";          -- DVI on, RGB off
          end if;
          stop  <= '1';
          if cmd_ack = '1' then
            fsm_ns <= TPCP1;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPCP1 =>
          start <= '1';
          write <= '1';                 -- output device address
          din   <= DEV_ADDR & '0';      -- write to device
          if cmd_ack = '1' then
            fsm_ns <= TPCP2;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPCP2 =>
          write <= '1';                 -- output register address
          din   <= x"B3";               -- TPCP register, MSB set
          if cmd_ack = '1' then
            fsm_ns <= TPCP3;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPCP3 =>
          write <= '1';
          if CLK_FREQ <= 65000000 then
            din   <= "00001000";          -- Default for f <= 65 MHz
          else
            din   <= "00000110";          -- Default for f >  65 MHz
          end if;
          stop  <= '1';
          if cmd_ack = '1' then
            fsm_ns <= TPD1;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPD1 =>
          start <= '1';
          write <= '1';                 -- output device address
          din   <= DEV_ADDR & '0';      -- write to device
          if cmd_ack = '1' then
            fsm_ns <= TPD2;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPD2 =>
          write <= '1';                 -- output register address
          din   <= x"B4";               -- TPD register, MSB set
          if cmd_ack = '1' then
            fsm_ns <= TPD3;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPD3 =>
          write <= '1';
          if CLK_FREQ <= 65000000 then
            din   <= "00010110";          -- Default for f <= 65 MHz
          else
            din   <= "00100110";          -- Default for f >  65 MHz
          end if;
          stop  <= '1';
          if cmd_ack = '1' then
            fsm_ns <= TPF1;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPF1 =>
          start <= '1';
          write <= '1';                 -- output device address
          din   <= DEV_ADDR & '0';      -- write to device
          if cmd_ack = '1' then
            fsm_ns <= TPF2;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPF2 =>
          write <= '1';                 -- output register address
          din   <= x"B6";               -- TPF register, MSB set
          if cmd_ack = '1' then
            fsm_ns <= TPF3;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TPF3 =>
          write <= '1';
          if CLK_FREQ <= 65000000 then
            din   <= "01100000";          -- Default for f <= 65 MHz
          else
            din   <= "10100000";          -- Default for f >  65 MHz
          end if;
          stop  <= '1';
          if cmd_ack = '1' then
            fsm_ns <= IDF1;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when IDF1 =>
          start <= '1';
          write <= '1';                 -- output device address
          din   <= DEV_ADDR & '0';      -- write to device
          if cmd_ack = '1' then
            fsm_ns <= IDF2;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when IDF2 =>
          write <= '1';                 -- output register address
          din   <= x"9F";               -- IDF register, MSB set
          if cmd_ack = '1' then
            fsm_ns <= IDF3;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when IDF3 =>
          write <= '1';
          if CVT then
            din   <= "10010000";          -- V1, H0, IDF0
          else
            din   <= "10000000";          -- V0, H0, IDF0
          end if;
          stop  <= '1';
          if cmd_ack = '1' then
            fsm_ns <= DAC1;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when DAC1 =>
          start <= '1';
          write <= '1';                 -- output device address
          din   <= DEV_ADDR & '0';      -- write to device
          if cmd_ack = '1' then
            fsm_ns <= DAC2;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when DAC2 =>
          write <= '1';                 -- output register address
          din   <= x"A1";               -- DAC register, MSB set
          if cmd_ack = '1' then
            fsm_ns <= DAC3;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when DAC3 =>
          write <= '1';
          din   <= "00001001";          -- DVI on, RGB bypass (RGB)
          stop  <= '1';
          if cmd_ack = '1' then
            --fsm_ns <= TSTP1;            -- chip-internal TPG
            fsm_ns <= FINISHED;         -- own test-pattern
            
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

          -- The followning activates an internal test pattern.
          -- Skip states if own test-pattern should be displayed.
          -- See above in state DAC3.
        when TSTP1 =>
          start <= '1';
          write <= '1';                 -- output device address
          din   <= DEV_ADDR & '0';      -- write to device
          if cmd_ack = '1' then
            fsm_ns <= TSTP2;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TSTP2 =>
          write <= '1';                 -- output register address
          din   <= x"C8";               -- TSTP register, MSB set
          if cmd_ack = '1' then
            fsm_ns <= TSTP3;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

        when TSTP3 =>
          write <= '1';
          din   <= "00011001";          -- Color bars
          stop  <= '1';
          if cmd_ack = '1' then
            fsm_ns <= FINISHED;
            if ack_out = '1' then       -- no ACK from slave
              fsm_ns  <= FAIL;
              set_err <= '1';
            end if;
          end if;

          
        when FINISHED =>
          status <= "01";
          
        when FAIL     =>
          status <= "10";
                         
      end case;
    end process;

    process (clk)
    begin  -- process
      if rising_edge(clk) then
        if rst = '1' then
          fsm_cs <= RESETTING;
          error  <= (others => '0');
        else
          fsm_cs <= fsm_ns;

          if set_err = '1' then
            case fsm_cs is
              when DID1   => error <= x"0";
              when DID2   => error <= x"1";
              when DID3   => error <= x"2";
              when PM1    => error <= x"3";
              when PM2    => error <= x"4";
              when PM3    => error <= x"5";
              when TSTP1  => error <= x"6";
              when TSTP2  => error <= x"7";
              when TSTP3  => error <= x"8";
              when others => error <= x"F";
            end case;
          end if;
        end if;
      end if;
    end process;
end rtl;
