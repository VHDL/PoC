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
-- Entity: trace_value_sel
-- Author(s): Stefan Alex
-- 
------------------------------------------------------
-- Select tracer-values, add time-information       --
--                                                  --
-- in_value_fill/tracer_data_fill                   --
-- is number of valid bits minus 1                  --
------------------------------------------------------
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2010-04-30 14:19:37 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_functions.all;
use poc.trace_types.all;
use poc.trace_internals.all;

entity trace_value_sel is
  generic (
    CYCLE_ACCURATE   : boolean;
    TRACER_CNT       : positive;
    TRACER_DATA_BITS : tNat_array;
    TIME_CMP_LEVELS  : positive;
    TIME_BITS        : positive
    );
  port (

    clk_sys : in std_logic;
    rst_sys : in std_logic;

    valid_in : in std_logic;

    -- tracer-interface
    tracer_data      : in  std_logic_vector(sum(TRACER_DATA_BITS)-1 downto 0);
    tracer_data_fill : in  std_logic_vector(sum(log2ceilnz(TRACER_DATA_BITS))-1 downto 0);
    tracer_data_last : in  std_logic_vector(TRACER_CNT-1 downto 0);
    tracer_data_got  : out std_logic_vector(TRACER_CNT-1 downto 0);

    current_tracer        : in  unsigned(log2ceilnz(TRACER_CNT)-1 downto 0);
    first_tracer_in_level : in  std_logic;
    last_tracer_in_level  : in  std_logic;
    done_tracer           : out std_logic;

    -- global-time-interface

    current_level : in  unsigned(log2ceilnz(TIME_CMP_LEVELS)-1 downto 0);
    current_time  : in  std_logic_vector(TIME_BITS-1 downto 0);
    no_data       : in  std_logic;
    done_level    : out std_logic;

    -- value-2fifo-interface
    next_value       : out std_logic_vector(max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0)-1 downto 0);
    next_value_fill  : out unsigned(log2ceil(max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0))-1 downto 0);
    next_value_got   : in  std_logic;
    next_value_valid : out std_logic
    );
end trace_value_sel;

architecture Behavioral of trace_value_sel is

  constant TRACER_DATA_FILL_BITS      : tNat_array := log2ceilnz(TRACER_DATA_BITS);
  constant MAX_TRACER_DATA_FILL_BITS  : positive   := max(TRACER_DATA_FILL_BITS);
  constant MAX_TRACER_DATA_VALUE_BITS : positive   := max(TRACER_DATA_BITS);
  constant TIME_VALUE_BITS            : natural    := ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0);
  constant VALUE_BITS                 : positive   := TIME_VALUE_BITS + MAX_TRACER_DATA_VALUE_BITS;
  constant FILL_BITS                  : positive   := log2ceil(MAX_TRACER_DATA_VALUE_BITS+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0));

  signal tracer_data_last_sel  : std_logic;
  signal tracer_data_sel       : std_logic_vector(max(TRACER_DATA_BITS)-1 downto 0);
  signal tracer_data_fill_sel  : std_logic_vector(max(TRACER_DATA_FILL_BITS)-1 downto 0);

  signal done_tracer_i : std_logic;

  -- signal registered output
  signal next_value_r       : std_logic_vector(max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0)-1 downto 0);
  signal next_value_i       : std_logic_vector(max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0)-1 downto 0);
  signal next_value_fill_i  : unsigned(log2ceil(max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0))-1 downto 0);
  signal next_value_fill_r  : unsigned(log2ceil(max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0))-1 downto 0);
  signal next_value_valid_i : std_logic;
  signal next_value_valid_r : std_logic; 
  signal next_value_got_i   : std_logic;

begin

  assert TRACER_CNT = countValuesGreaterThan(TRACER_DATA_BITS, 0)
    severity error;

  assert TIME_CMP_LEVELS * TIME_BITS = 8
    report "ERROR: Time-Bits * Time-Cmp-Levels should be 8."
    severity error;

  assert TIME_CMP_LEVELS <= 8
    report "ERROR: Time-Cmp-Levels should be smaller than 9."
    severity error;

  ----------------------------------------------
  -- Select the tracer-data- and valid-values --
  ----------------------------------------------

  tracer_data_multiplex : trace_multiplex
    generic map (
      DATA_BITS => TRACER_DATA_BITS,
      IMPL      => false
    )
    port map (
      inputs => tracer_data,
      sel    => current_tracer,
      output => tracer_data_sel
    );

  tracer_data_fill_multiplex : trace_multiplex
    generic map (
      DATA_BITS => TRACER_DATA_FILL_BITS,
      IMPL      => true

    )
    port map (
      inputs => tracer_data_fill,
      sel    => current_tracer,
      output => tracer_data_fill_sel
    );

  tracer_data_last_sel  <= tracer_data_last(to_integer(current_tracer)) when current_tracer < TRACER_CNT else 'X';

  -- cycle-accurate: add time-values

  cycle_accurate_gen : if CYCLE_ACCURATE generate

    signal first_tracer_data_r : std_logic := '1';

    signal time_enable_no_data  : std_logic;
    signal time_enable_first_tr : std_logic;
    signal time_enable_other_tr : std_logic;

    signal time_value_no_data  : std_logic_vector(TIME_VALUE_BITS-1 downto 0);
    signal time_value_first_tr : std_logic_vector(TIME_VALUE_BITS-1 downto 0);
    signal time_value_other_tr : std_logic_vector(TIME_VALUE_BITS-1 downto 0);
    signal time_value          : std_logic_vector(TIME_VALUE_BITS-1 downto 0);

    signal timeLength     : unsigned(log2ceil(TIME_CMP_LEVELS+1)-1 downto 0);
    signal timeLengthBits : unsigned(log2ceilnz(TIME_CMP_LEVELS*TIME_BITS+1)-1 downto 0);
    signal timeLengthBits_tmp : std_logic_vector(log2ceilnz(TIME_CMP_LEVELS*TIME_BITS+1)-1 downto 0);

    constant BIT_LENGTH : positive := log2ceilnz(TIME_CMP_LEVELS*TIME_BITS+1);
    type tTimeLengthBitArray is array(natural range<>) of std_logic_vector(BIT_LENGTH-1 downto 0);
    signal timeLengthBitsAll : tTimeLengthBitArray(TIME_CMP_LEVELS downto 0);

    signal tracer_data_fill_sel_masked : std_logic_vector(FILL_BITS-1 downto 0);

  begin

    -- mark first data from tracer, so time-bits can be added
    clk_proc : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        if rst_sys = '1' then
          first_tracer_data_r <= '1';
        else
          if done_tracer_i = '1' then
            first_tracer_data_r <= '1';
          elsif next_value_got_i = '1' and no_data = '0' and first_tracer_data_r = '1' then
            first_tracer_data_r <= '0';
          end if;
        end if;
      end if;
    end process clk_proc;

    -- data fill can contain valid value, but when there are full time-bits to send, mask this value
    with no_data select
      tracer_data_fill_sel_masked <= fill(tracer_data_fill_sel, FILL_BITS) when '0',
                                     (others => '1')                       when others;

    timeLengthBitsAll_gen : for i in 0 to TIME_CMP_LEVELS generate
      timeLengthBitsAll(i) <= std_logic_vector(to_unsigned(i*TIME_BITS, BIT_LENGTH));
    end generate timeLengthBitsAll_gen;

    ----------------
    -- time-value --
    ----------------

    time_value_no_data <= (others => '1');

    time_value_first_tr_gen : for i in 0 to TIME_CMP_LEVELS-1 generate
      signal match : std_logic;
    begin

      match <= '1' when current_level = i else '0';

      with match select
        time_value_first_tr((i+1)*TIME_BITS-1 downto i*TIME_BITS) <= current_time   when '1',
                                                                    (others => '1') when others;

    end generate time_value_first_tr_gen;

    time_value_other_tr(TIME_BITS-1 downto 0) <= (others => '0');
    time_value_other_tr_gen : for i in 1 to TIME_CMP_LEVELS-1 generate
      time_value_other_tr((i+1)*TIME_BITS-1 downto i*TIME_BITS) <= (others => '-');
    end generate time_value_other_tr_gen;

    time_value <= time_value_no_data  when time_enable_no_data = '1' else
                  time_value_first_tr when time_enable_first_tr = '1' else
                  time_value_other_tr;

    ----------------------------
    -- generate output values --
    ----------------------------

    time_enable_no_data  <= no_data;
    time_enable_first_tr <= first_tracer_data_r and first_tracer_in_level and not no_data;
    time_enable_other_tr <= first_tracer_data_r and not first_tracer_in_level and not no_data;

    timeLength <= to_unsigned(1,  timeLength'length)              when time_enable_other_tr = '1' else
                  fill(current_level, timeLength'length)+1        when time_enable_first_tr = '1' else
                  to_unsigned(TIME_CMP_LEVELS, timeLength'length) when time_enable_no_data = '1' else
                  to_unsigned(0,  timeLength'length);

    timeLengthBits_tmp <= timeLengthBitsAll(to_integer(timeLength)) when to_integer(timeLength) <= TIME_CMP_LEVELS
                                                                    else (others => 'X');

    timeLengthBits <= unsigned(timeLengthBits_tmp);

    -- fill output-value (multiplex)
    next_value_time_gen : for i in 0 to TIME_CMP_LEVELS-1 generate

      constant DATA_LEVEL      : positive := divideRoundUp(max(TRACER_DATA_BITS), TIME_BITS);
      constant DATA_LEVEL_USED : positive := minValue(DATA_LEVEL, i+1);
      constant OFFSETRANGE     : positive := (TIME_CMP_LEVELS-i)+DATA_LEVEL_USED;

      signal time_or_data : std_logic;

      signal time_out  : std_logic_vector(TIME_BITS-1 downto 0);
      signal data_used : std_logic_vector(DATA_LEVEL_USED*TIME_BITS-1 downto 0);
      signal data_sel  : unsigned(log2ceilnz(DATA_LEVEL_USED)-1 downto 0);
      signal data_out  : std_logic_vector(TIME_BITS-1 downto 0);

    begin

      time_or_data <= '1' when i < timeLength else '0';

      -- multiplex the values

      time_out <= time_value((i+1)*TIME_BITS-1 downto i*TIME_BITS);

      -- select the data from tracer_data, which is used here and fill with zeros
      data_used <= fillOrCut(tracer_data_sel, DATA_LEVEL_USED*TIME_BITS);
      data_sel  <= (to_unsigned(i, log2ceilnz(TIME_CMP_LEVELS))(log2ceilnz(DATA_LEVEL_USED)-1 downto 0))-(timeLength(log2ceilnz(DATA_LEVEL_USED)-1 downto 0));

      data_1_multiplex : trace_multiplex
        generic map (
          DATA_BITS => (DATA_LEVEL_USED-1 downto 0 => TIME_BITS),
          IMPL      => true
        )
        port map (
          inputs => data_used,
          sel    => data_sel,
          output => data_out
        );

      with time_or_data select
        next_value_i((i+1)*TIME_BITS-1 downto i*TIME_BITS) <= time_out when '1',
                                                              data_out when others;

    end generate next_value_time_gen;

    next_value_data_gen : for i in 0 to max(TRACER_DATA_BITS)-1 generate

      constant OFFSETRANGE : positive := ifThenElse(i >= max(TRACER_DATA_BITS)-TIME_BITS*TIME_CMP_LEVELS,
                                                    max(TRACER_DATA_BITS)-i,
                                                    TIME_BITS*TIME_CMP_LEVELS+1);

      signal data_sel : unsigned(log2ceilnz(OFFSETRANGE)-1 downto 0);
      signal data_out : std_logic_vector(0 downto 0);

    begin

      data_sel <= fillOrCut((to_unsigned(TIME_BITS*TIME_CMP_LEVELS, log2ceil(TIME_CMP_LEVELS*TIME_BITS+1))-
                  timeLengthBits), log2ceilnz(OFFSETRANGE));

      data_2_multiplex : trace_multiplex
        generic map (
          DATA_BITS => (OFFSETRANGE-1 downto 0 => 1),
          IMPL      => true
        )
        port map (
          inputs => tracer_data_sel(i+OFFSETRANGE-1 downto i),
          sel    => data_sel,
          output => data_out
        );

      next_value_i(TIME_BITS*TIME_CMP_LEVELS+i) <= data_out(0);

    end generate next_value_data_gen;

    next_value_fill_i   <= fill(timeLengthBits, FILL_BITS) + unsigned(tracer_data_fill_sel_masked);
    next_value_valid_i  <= valid_in;

    -- ack to tracer_time and global_time
    done_tracer_i <= next_value_got_i and not no_data and tracer_data_last_sel;
    done_level    <= next_value_got_i and (no_data or (tracer_data_last_sel and last_tracer_in_level));

  end generate cycle_accurate_gen;

  no_cycle_accurate_gen : if not CYCLE_ACCURATE generate
    next_value_i       <= tracer_data_sel;
    next_value_fill_i  <= unsigned(tracer_data_fill_sel);
    next_value_valid_i <= valid_in and not no_data;

    done_tracer_i <= valid_in and next_value_got_i and tracer_data_last_sel;
    done_level    <= '0';               -- not needed
  end generate no_cycle_accurate_gen;

  tracer_data_got_gen : for i in 0 to TRACER_CNT-1 generate
    tracer_data_got(i) <= next_value_got_i when no_data = '0' and current_tracer = i else '0';
  end generate tracer_data_got_gen;

  ----------------------
  -- registered ouput --
  ----------------------

  clk_proc : process (clk_sys)
  begin
    if rising_edge(clk_sys) then
      if rst_sys = '1' then
        next_value_valid_r <= '0';
      elsif next_value_got = '1' or next_value_valid_r = '0' then
        next_value_valid_r <= next_value_valid_i;
      end if;
        
      if next_value_got = '1' or next_value_valid_r = '0' then
        next_value_r       <= next_value_i;
        next_value_fill_r  <= next_value_fill_i;
      end if;
    end if;
  end process clk_proc;

  next_value_got_i <= (next_value_got or not next_value_valid_r) and next_value_valid_i;

  next_value       <= next_value_r;
  next_value_fill  <= next_value_fill_r;
  next_value_valid <= next_value_valid_r;

  done_tracer <= done_tracer_i;

end Behavioral;
