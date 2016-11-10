--
-- Copyright (c) 2007
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair of VLSI-Design, Diagnostics and Architecture
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--
-- Implements the communication over the programming JTAG link
-- using the USER2 command.
--
--   Spartan-3: 000010 (USER1), 000011 (USER2)
--   Send: '0'.data.crc(."--")
--   Recv: '0'.data.crc(.'0'.ack)
--
--   impact -batch:
--   > bsdebug -scanir 000011
--   > bsdebug -scandr <data_bit_flipped>
--
-- Entity: jtag
-- Author(s): Thomas B. Preusser
--
-- JTAG UART for Spartan-Devices
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2010-01-05 12:22:16 $
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library poc;
use poc.functions.all;

library UNISIM;
use UNISIM.VComponents.all;


entity jtag is
  generic(
    DAT_LEN : positive;          -- Data Bits
    CRC_GEN : std_logic_vector;  -- CRC Polynom: "1" - none
    ACK_BIT : boolean            -- Optional ACK/NAK Bit
  );
  port(
    clk  : in  std_logic;
    rst  : in  std_logic;

    -- Output from JTAG
    wr_ful : in  std_logic;
    wr_dat : out std_logic_vector(DAT_LEN-1 downto 0);
    wr_put : out std_logic;

    -- Input to JTAG
    rd_dat : in  std_logic_vector(DAT_LEN-1 downto 0);
    rd_got : out std_logic
  );
end jtag;

architecture jtag_impl of jtag is

  constant CRC_LEN : natural := length(CRC_GEN)-1;

  component crc
    generic (
      GEN : std_logic_vector
    );
    port (
      clk : in std_logic;                 -- Clock

      rst  : in std_logic;                -- Reset
      load : in std_logic;                -- Parallel Preload of Remainder
      init : in std_logic_vector(max(length(GEN)-2, 0) downto 0);  -- Initial Remainder

      en  : in std_logic;                 -- Enable
      din : in std_logic;                 -- Serial Data Input

      rmd  : out std_logic_vector(max(length(GEN)-2, 0) downto 0);  -- Remainder
      zero : out std_logic                                          -- Remainder is Zero
    );
  end component;

  type tPhase is (PhData, PhFCS);
  signal Phase : tPhase;

  signal Capture : std_logic;
  signal Shift   : std_logic;
  signal LoadFCS : std_logic;
  signal Finish  : std_logic;

  signal jt_tdi : std_logic;
  signal jt_tdo : std_logic;
  signal jt_ack : std_logic;

begin

  -- BSCAN with wrapping State Machine
  blkJTAG: block

    signal jt_strobe  : std_logic;      -- Strobed Clock
    signal jt_sel     : std_logic;
    signal jt_capture : std_logic;      -- Strobed to avoid reloading of output
    signal jt_shift   : std_logic;

  begin

    blkBSCAN: block

      signal bs_clk   : std_logic;
      signal jt_clk   : std_logic;
      signal jt_clk_d : std_logic;

      signal bs_capture : std_logic;
      signal jt_cap     : std_logic;
      signal jt_cap_d   : std_logic;

      signal bs_sel     : std_logic;
      signal bs_shift   : std_logic;
      signal bs_tdi     : std_logic;

    begin
      BSCAN : BSCAN_SPARTAN3
        port map (
          CAPTURE => bs_capture,          -- CAPTURE output from TAP controller
          DRCK1   => open,        -- Data register output for USER1 functions
          DRCK2   => bs_clk,      -- Data register output for USER2 functions
          RESET   => open,                -- Reset output from TAP controller
          SEL1    => open,                -- USER1 active output
          SEL2    => bs_sel,              -- USER2 active output
          SHIFT   => bs_shift,            -- SHIFT output from TAP controller
          TDI     => bs_tdi,              -- TDI output from TAP controller
          UPDATE  => open,                -- UPDATE output from TAP controller
          TDO1    => '0',                 -- Data input for USER1 function
          TDO2    => jt_tdo               -- Data input for USER2 function
        );

      -- Synchronize Inputs
      process(clk)
      begin
        if clk'event and clk = '1' then
          jt_clk_d  <= jt_clk;
          jt_clk    <= bs_clk;
          jt_cap_d  <= jt_cap;
          jt_cap    <= bs_capture;

          jt_sel     <= bs_sel;
          jt_shift   <= bs_shift;
          jt_tdi     <= bs_tdi;
        end if;
      end process;
      jt_strobe  <= jt_clk and not jt_clk_d;
      jt_capture <= jt_cap and not jt_cap_d;

    end block blkBSCAN;

    blkSM: block
      type   tState is (Idling, ShiftData, ShiftSkew, ShiftFCS);
      signal State     : tState := Idling;
      signal NextState : tState;

      signal SetLoadFCS : std_logic;
      signal StartFCS   : std_logic;
      signal SetFinish  : std_logic;

      -- Counting down to -1
      signal ShiftCount : signed(log2ceil(max(DAT_LEN, CRC_LEN)-1) downto 0);
      signal CntZZ      : std_logic;

    begin

      -- State Register
      process(clk)
      begin
        if clk'event and clk = '1' then
          if rst = '1' then
            State  <= Idling;
          else
            State  <= NextState;
          end if;
        end if;
      end process;

      -- Shift Counter
      process(clk)
      begin
        if clk'event and clk = '1' then
          if Capture = '1' then
            ShiftCount <= to_signed(DAT_LEN-2, ShiftCount'length);
          elsif StartFCS = '1' then
            ShiftCount <= to_signed(CRC_LEN-2, ShiftCount'length);
          elsif Shift = '1' then
            ShiftCount <= ShiftCount - 1;
          end if;

          Finish  <= SetFinish;
          LoadFCS <= SetLoadFCS;
        end if;
      end process;

      CntZZ <= ShiftCount(ShiftCount'left);

      -- State Machine
      process(State, jt_sel, jt_capture, jt_shift, jt_strobe, CntZZ)
      begin
        -- Defaults
        NextState <= State;
        Phase     <= PhFCS;

        Capture   <= '0';
        Shift     <= '0';

        SetLoadFCS <= '0';
        StartFCS   <= '0';
        SetFinish  <= '0';

        if jt_sel = '1' then

          if jt_capture = '1' then

            Capture   <= '1';
            NextState <= ShiftData;

          elsif jt_shift = '1' and jt_strobe = '1' then

            Shift <= '1';
            case State is
              when Idling =>
                null;

              when ShiftData =>
                Phase <= PhData;

                if CntZZ = '1' then
                  SetLoadFCS <= '1';

                  if CRC_LEN > 0 then
                    NextState <= ShiftSkew;
		  else
		    NextState <= ShiftFCS;
		  end if;
                end if;

              when ShiftSkew =>
                Phase     <= PhData;
                StartFCS  <= '1';
                NextState <= ShiftFCS;

              when ShiftFCS =>
		if CRC_LEN = 0 then
		  Phase <= PhData;
		end if;

                if CRC_LEN = 0 or CntZZ = '1' then
                  SetFinish <= '1';

                  -- We do not need to generate any more controls
                  -- even for an ACK_BIT.
                  NextState <= Idling;
                end if;

            end case;
          end if;
        end if;

      end process;
    end block blkSM;

  end block blkJTAG;

  -- Data Input
  blkInput: block

    -- Data Register
    signal RegDatIn : std_logic_vector(DAT_LEN-1 downto 0);
    signal crc_ok   : std_logic;

  begin

    -- Data Register
    process(clk)
    begin
      if clk'event and clk = '1' then

        -- Actual Data Register
        if Shift = '1' and Phase = PhData then
          RegDatIn <= RegDatIn(RegDatIn'left-1 downto 0) & jt_tdi;
        end if;

      end if;
    end process;

    -- CRC: always active
    crc_in: crc
      generic map (
        GEN => CRC_GEN
      )
      port map (
        clk  => clk,
        rst  => Capture,
        load => '0',
        init => (1 to max(CRC_LEN, 1) => '-'),
        en   => Shift,
        din  => jt_tdi,
        rmd  => open,
        zero => crc_ok
      );

    jt_ack <= Finish and crc_ok and not wr_ful;
    wr_put <= jt_ack;
    wr_dat <= RegDatIn;

  end block blkInput;

  -- Data Output
  blkOutput: block
    signal RegDatOut : std_logic_vector(DAT_LEN-1         downto 0);
    signal rmd       : std_logic_vector(max(CRC_LEN-1, 0) downto 0);
  begin

    -- Data Output Register
    process(clk)
    begin
      if clk'event and clk = '1' then

        -- Manipulate Data Register
        if Capture = '1' then
          RegDatOut <= rd_dat;
        elsif LoadFCS = '1' then
          RegDatOut(RegDatOut'left downto RegDatOut'left-rmd'length+1) <= rmd;
        elsif ACK_BIT and Finish = '1' then
          RegDatOut(RegDatOut'left) <= jt_ack;
        elsif Shift = '1' then
          RegDatOut <= RegDatOut(RegDatOut'left-1 downto 0) & '0';
        end if;

      end if;
    end process;
    rd_got <= Capture;

    -- CRC
    crc_out: crc
      generic map (
        GEN => CRC_GEN
      )
      port map (
        clk  => clk,
        rst  => '0',
        load => Capture,
        init => rd_dat(DAT_LEN-1 downto DAT_LEN-rmd'length),
        en   => Shift,
        din  => RegDatOut(RegDatOut'left-rmd'length),
        rmd  => rmd,
        zero => open
      );

    jt_tdo <= RegDatOut(RegDatOut'left);

  end block blkOutput;

end jtag_impl;
