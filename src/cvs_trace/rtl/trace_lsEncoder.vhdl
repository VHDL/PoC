--
-- Copyright (c) 2010
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
-- Entity: trace_lsEncoder
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- LS-Encoder from TraceDo                          --
-- Modified:                                        --
-- - only one bit header                            --
-- - first event after mode-change is implicit the  --
--   bit                                            --
------------------------------------------------------
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-03-29 15:44:33 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trace_lsEncoder is
  generic (
    MESSAGE_BYTES : positive := 1
  );
  port (

    -- Globals --
    clk : in  std_logic; -- Clock
    rst : in  std_logic; -- Reset

    -- Inputs --
    ie : in std_logic;
    ev : in std_logic;

    -- Outputs --
    message : out std_logic_vector(MESSAGE_BYTES*8-1 downto 0);
    oe      : out std_logic
  );
end trace_lsEncoder;

architecture rtl of trace_lsEncoder is

  type tState is (ShortChartMessage, LongChartMessage);
  signal State     : tState := ShortChartMessage;
  signal NextState : tState;

  constant REG_BITS : positive := MESSAGE_BYTES*8-1;
  signal reg : std_logic_vector(REG_BITS-1 downto 0) := (REG_BITS-1 downto 1 => '0') & '1';

  signal reg_set_lcm : std_logic;
  signal reg_rst_set : std_logic;
  signal reg_shift   : std_logic;
  signal reg_inc     : std_logic;

  signal short_chart_switch : std_logic;
  signal short_chart_full   : std_logic;

  signal long_chart_finish : std_logic;
  signal long_chart_full   : std_logic;

  signal send : std_logic;

begin

  short_chart_full   <= reg(REG_BITS-1);

  short_chart_switch <= '1' when reg(REG_BITS-2 downto 0) = (REG_BITS-2 downto 0 => ev) else  '0';

  long_chart_full    <= '1' when reg(REG_BITS-2 downto 0) = (REG_BITS-2 downto 0 => '1') else '0';

  long_chart_finish  <= (reg(REG_BITS-1) xor ev) or long_chart_full;

  com_proc : process(ie, short_chart_switch, short_chart_full, long_chart_finish, long_chart_full, State)
  begin
    NextState   <= State;
    reg_set_lcm <= '0';
    reg_rst_set <= '0';
    reg_shift   <= '0';
    reg_inc     <= '0';
    send        <= '0';

    case State is

      when ShortChartMessage =>

        if ie = '1' then

          if short_chart_full = '1' then

            if short_chart_switch = '1' then -- go to long chart message
              reg_set_lcm <= '1';
              NextState   <= LongChartMessage;
            else -- no mode change possible, so send message and reset everything
              send        <= '1';
              reg_rst_set <= '1'; -- event will be added
            end if;

          else

            reg_shift <= '1';

          end if;

        end if;

      when LongChartMessage =>

        if ie = '1' then

          if long_chart_finish  = '1' then
            reg_rst_set <= '1';
            send        <= '1';
            NextState <= ShortChartMessage;
          else
            reg_inc <= '1';
          end if;

        end if;

    end case;
  end process com_proc;

  clk_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        State <= ShortChartMessage;
        reg   <= (REG_BITS-1 downto 1 => '0') & '1';
      else
        State <= NextState;

        if reg_rst_set = '1' then
          reg <= (REG_BITS-1 downto 2 => '0') & '1' & ev;
        elsif reg_set_lcm = '1' then
          reg <= ev & (REG_BITS-2 downto 0 => '0');
        elsif reg_shift = '1' then
          reg <= reg(REG_BITS-2 downto 0) & ev;
        elsif reg_inc = '1' then
          reg(REG_BITS-2 downto 0) <= std_logic_vector(unsigned(reg(REG_BITS-2 downto 0))+1);
        end if;

      end if;
    end if;
  end process clk_proc;

  -------------
  -- Outputs --
  -------------

  -- Header is finish-bit for short-path-message
  oe      <= send;
  message(REG_BITS-1 downto 0) <= reg;
  message(MESSAGE_BYTES*8-1)   <= '1' when State = LongChartMessage else
                                  '0';

end rtl;
