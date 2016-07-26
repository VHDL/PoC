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
-- Entity: trace_global_time
-- Author(s): Stefan Alex, Martin Zabel
--
-- Global time basis. Count clock cycles between messages.
--
-- Outputs for value_sel:
-- ----------------------
-- Outputs are valid if 'valid_out' = '1'.
--
-- 'no_data' = '1': no messages at all time-levels.
--    => component 'value_sel' must insert TIME_CMP_LEVELS
--    time-stamps with value all-one.
--
-- 'no_data' = '0': message(s) strobed with time 'current_time' at level
--    'current_level'. if 'current_level' > 0 then component 'value_sel'
--    must insert 'current_level' time-stamps with value all-one before
--    inserting the current time-stamp with value 'current-time'.
--
-- Revision:    $Revision: 1.6 $
-- Last change: $Date: 2010-04-29 12:05:53 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_internals.all;
use poc.trace_types.all;
use poc.trace_functions.all;

entity trace_global_time is
  generic (
    TIME_BITS                 : positive;
    TIME_CMP_LEVELS           : positive;
    GLOBAL_TIME_SAFE_DISTANCE : positive;
    GLOBAL_TIME_FIFO_DEPTH    : positive
    );
  port (
    clk_trc : in std_logic;
    rst_trc : in std_logic;
    clk_sys : in std_logic;
    rst_sys : in std_logic;

    -- clk-trc-domain (inputs)
    enable     : in  std_logic;
    ov_stop    : out std_logic;
    ov_danger  : out std_logic;
    tracer_stb : in  std_logic;
    stb_en     : out std_logic;

    -- clk-sys-domain (outputs)
    current_level : out unsigned(log2ceilnz(TIME_CMP_LEVELS)-1 downto 0);
    current_time  : out std_logic_vector(TIME_BITS-1 downto 0);
    no_data       : out std_logic;
    done_level    : in  std_logic;
    valid_out     : out std_logic
    );
end trace_global_time;

architecture rtl of trace_global_time is
  signal global_time_got   : std_logic;
  signal global_time       : std_logic_vector(7 downto 0);
  signal global_time_valid : std_logic;
begin

  assert TIME_BITS > 1
    report "ERROR: Time-Bits should be greater than 1."
    severity error;

  --------------------------
  -- the global-time-fifo --
  --------------------------

  fifo_blk : block
    constant GLOBAL_TIME_FIFO_BITS : positive := TIME_BITS*TIME_CMP_LEVELS;

    -- clk-trc-domain
    signal gt_fifo_put  : std_logic;
    signal gt_fifo_din  : std_logic_vector(GLOBAL_TIME_FIFO_BITS-1 downto 0);
    signal gt_fifo_full : std_logic;
    signal gt_fifo_sd   : std_logic;

    signal time_val  : std_logic_vector(TIME_BITS-1 downto 0);
    signal time_put  : std_logic;
    signal time_en   : std_logic;
    signal add_en    : std_logic;
    signal keep_enabled : std_logic;

    -- clk-eth-domain
    signal gt_fifo_got   : std_logic;
    signal gt_fifo_valid : std_logic;
    signal gt_fifo_dout  : std_logic_vector(GLOBAL_TIME_FIFO_BITS-1 downto 0);
  begin

    assert GLOBAL_TIME_FIFO_DEPTH > GLOBAL_TIME_SAFE_DISTANCE
      report "ERROR: Reduce Global-Time-Safe-Distance"
      severity error;

    global_time_inst : trace_fifo_ic
      generic map (
        D_BITS     => GLOBAL_TIME_FIFO_BITS,
        MIN_DEPTH  => GLOBAL_TIME_FIFO_DEPTH,
        THRESHOLD  => GLOBAL_TIME_SAFE_DISTANCE,
        OUTPUT_REG => false
      )
      port map (
        clk_wr => clk_trc,
        rst_wr => rst_trc,
        put    => gt_fifo_put,
        din    => gt_fifo_din,
        full   => gt_fifo_full,
        thres  => gt_fifo_sd,
        clk_rd => clk_sys,
        rst_rd => rst_sys,
        got    => gt_fifo_got,
        valid  => gt_fifo_valid,
        dout   => gt_fifo_dout
      );

    --------------
    -- overflow --
    --------------

    ov_blk : block
      signal ov_r        : std_logic;
      signal ov_rst      : std_logic;
      signal ov_set      : std_logic;
      signal ov_danger_i : std_logic;
    begin

      -- overflow-policy
      -- when data-fifo overflows, no time-event is marked
      -- when tracer_time-fifo overflows, no data is added to data-fifo and no event is marked in tracer-time-fifo
      -- if global-time-fifo overflows, everything is stopped, this means tracing and tracer-time-fifo
      -- => data is resynchronized in data-fifo in every case

      time_en <= (enable or keep_enabled) and not ov_r;
      stb_en  <= not ov_r;

      clk_proc : process(clk_trc)
      begin
        if rising_edge(clk_trc) then
          if rst_trc = '1' or ov_rst = '1' then
            ov_r <= '0';
          elsif ov_set = '1' then
            ov_r <= '1';
          end if;
        end if;
      end process clk_proc;

      ov_rst <= not ov_danger_i;
      ov_set <= gt_fifo_full and gt_fifo_put;

      ov_stop <= ov_rst and ov_r;

      ov_danger_i <= gt_fifo_sd;
      ov_danger   <= ov_danger_i;

    end block ov_blk;

    -----------------
    -- cycle-count --
    -----------------

    global_time_blk : block
      signal time_inc      : std_logic;
      signal time_r        : unsigned(TIME_BITS-1 downto 0);
      signal time_full     : std_logic;
    begin

      -- The maximum cycle count is 2**TIME_BITS-2. If a tracer strobes
      -- in this cycle, then this value is inserted as time-value.
      -- If no tracer strobes in this cycle, then the time-value 2**TIME_BITS-1
      -- is inserted to indicate, that no message follows.
      time_full     <= '1' when time_r = ((time_r'left downto 1 => '1') & "0")
                            else '0';
      time_put      <= (tracer_stb or time_full) and time_en;
      time_inc      <= not time_put;

      with tracer_stb select
        time_val <= (time_val'range => '1')  when '0',
                    std_logic_vector(time_r) when others; -- '1';

      clk_proc : process(clk_trc)
      begin
        if rising_edge(clk_trc) then
          if rst_trc = '1' or (time_put = '1' and add_en = '1') then
            time_r <= to_unsigned(1, TIME_BITS);
          elsif time_inc = '1' and time_en = '1' then
            time_r <= time_r + 1;
          end if;
        end if;
      end process clk_proc;

    end block global_time_blk;

    ----------------------------
    -- global-time fifo-input --
    ----------------------------

    -- manage time-levels and put data to fifo

    one_cmp_level_in_gen : if TIME_CMP_LEVELS = 1 generate
      gt_fifo_put <= time_put;
      gt_fifo_din <= time_val;
      add_en      <= not gt_fifo_full;
      keep_enabled<= '0';
    end generate one_cmp_level_in_gen;

    more_cmp_levels_in_gen : if TIME_CMP_LEVELS > 1 generate
      -- one-hot encoded time-level
      signal level_r    : unsigned(log2ceil(TIME_CMP_LEVELS)-1 downto 0);
      signal level_rst  : std_logic;
      signal level_inc  : std_logic;
      signal level_last : std_logic;

      -- saved time values
      signal time_r : std_logic_vector(TIME_BITS*(TIME_CMP_LEVELS-1)-1 downto 0);

    begin
      level_last <= '1' when level_r = TIME_CMP_LEVELS-1 else '0';
      level_rst  <= gt_fifo_put and not gt_fifo_full;
      level_inc  <= time_put and not level_last;

      gt_fifo_put <= (time_put and level_last);
      gt_fifo_din <= time_val & time_r;  -- insert at top, see also below

      add_en       <= not (level_last and gt_fifo_full);

      clk_proc : process(clk_trc)
      begin
        if rising_edge(clk_trc) then
          if (rst_trc or level_rst) = '1' then
            level_r    <= (others => '0');
          elsif level_inc = '1' then
            level_r <= level_r + 1;
          end if;

          if level_inc = '1' then
            -- Insert time_val at top.
            if TIME_CMP_LEVELS > 2 then
              time_r(time_r'left-TIME_BITS downto 0) <=
                time_r(time_r'left downto TIME_BITS);
            end if;

            time_r(time_r'left downto time_r'left-TIME_BITS+1) <= time_val;
          end if;

          -- In case of trace-stop: keep enabled until a complete time-vector
          -- with all-ones has been written to the FIFO.
          -- Because 'level_sel_blk/more_cmp_levels_gen' requires a valid
          -- 'global_time' to write out time-values stored in prev_time_r.
          if rst_trc  = '1' then
            keep_enabled <= '0';
          elsif enable = '1' then
            keep_enabled <= '1';
          elsif (level_rst = '1') and
                (gt_fifo_din = (gt_fifo_din'range => '1'))
          then
            -- clear, when vector with all-ones has been written to the FIFO.
            keep_enabled <= '0';
          end if;
        end if;
      end process clk_proc;

    end generate more_cmp_levels_in_gen;

    -------------
    -- Outputs --
    -------------

    global_time_valid <= gt_fifo_valid;
    global_time       <= gt_fifo_dout;
    gt_fifo_got       <= global_time_got;

  end block fifo_blk;

  ------------------
  -- Level select --
  ------------------
  level_sel_blk : block
    signal done_level_i    : std_logic;
    signal no_data_nxt     : std_logic;
    signal valid_out_nxt   : std_logic;
    signal valid_out_r     : std_logic;
    signal current_time_nxt: std_logic_vector(TIME_BITS-1 downto 0);
  begin

    one_cmp_level_gen : if TIME_CMP_LEVELS = 1 generate
      global_time_got <= done_level_i;
      no_data_nxt     <= '1' when global_time = (global_time'left downto 0 => '1') else '0';
      current_level   <= to_unsigned(0, current_level'length);
      current_time_nxt<= global_time;
    end generate one_cmp_level_gen;

    more_cmp_levels_gen : if TIME_CMP_LEVELS > 1 generate
      signal prev_time_r : std_logic_vector(TIME_BITS*TIME_CMP_LEVELS-1 downto 0);
      signal full_time  : std_logic_vector(TIME_BITS*TIME_CMP_LEVELS*2-1 downto 0);
      -- integer range 0 to TIME_CMP_LEVELS-1
      signal current_level_nxt : unsigned(log2ceil(TIME_CMP_LEVELS)-1 downto 0);

      -- shift global_time into prev_time_r
      signal shift1 : std_logic;
      signal shift2 : std_logic;

      type TIME_ARRAY is array(natural range<>) of
        std_logic_vector(TIME_BITS-1 downto 0);

      signal window          : TIME_ARRAY(0 to TIME_CMP_LEVELS-1);

      -- Using integers did not work with simulation, due to possibly undefined
      -- time values.
      signal window_ptr_r    : -- integer range 0 to TIME_CMP_LEVELS
        unsigned(log2ceil(TIME_CMP_LEVELS+1)-1 downto 0);
      signal window_ptr_nxt  : -- integer range 0 to TIME_CMP_LEVELS*2
        unsigned(log2ceil(TIME_CMP_LEVELS*2+1)-1 downto 0);
      signal window_ptr_spec : -- integer range 0 to TIME_CMP_LEVELS*2
        unsigned(log2ceil(TIME_CMP_LEVELS*2+1)-1 downto 0);
    begin

      ------------------------------------------
      -- select window to search for time-values
      ------------------------------------------
      full_time <= global_time & prev_time_r;

      g1: for i in 0 to TIME_CMP_LEVELS-1 generate
        -- range to select from
        signal sel_range : TIME_ARRAY(0 to TIME_CMP_LEVELS);
      begin

        -- The logic below equals:
        -- window(i) <= full_time_arr(window_ptr_r+i);
        -- where full_time_arr is full_time as TIME_ARRAY

        g2: for j in sel_range'range generate
          sel_range(j) <= full_time((i+j+1)*TIME_BITS-1 downto (i+j)*TIME_BITS);
        end generate g2;

        window(i) <= sel_range(to_integer(window_ptr_r));
      end generate g1;

      ------------------------------------------
      -- search for time-value and select it
      ------------------------------------------
      compare_proc: process (window)
        constant CMP_VALUE : std_logic_vector(TIME_BITS-1 downto 0) := (others => '1');
        variable found : boolean;
      begin  -- process
        found := false;
        current_level_nxt <= (others => '-');

        for i in 0 to TIME_CMP_LEVELS-1 loop

          if (not found) and (window(i) /= CMP_VALUE) then
            found := true;
            current_level_nxt <= to_unsigned(i, current_level_nxt'length);
          end if;
        end loop;  -- i

        if found then
          no_data_nxt <= '0';
        else
          no_data_nxt <= '1';
        end if;
      end process;

      current_time_nxt <= (others => 'X') when
                                Is_X(std_logic_vector(current_level_nxt)) else
                          window(to_integer(current_level_nxt));

      ------------------------------------------
      -- new state calculation
      -- Note: state is only updated if done_level_i = '1',
      -- and thus, if global_time_valid = '1'.
      ------------------------------------------

      -- calculate speculative new window_ptr for case
      -- time-value has been found
      window_ptr_spec <= (others => 'X') when
                               Is_X(std_logic_vector(current_level_nxt)) else
                         fill(window_ptr_r, window_ptr_spec'length) +
                         to_integer(current_level_nxt) + 1;

      -- Shift global_time into prev_time_r, if:
      -- a) no time value found (see clk_proc), or
      -- b) new window_ptr would point into global_time.
      -- Two statements because window_ptr_nxt does not depend on no_data_nxt
      -- => shorter critical path.
      shift1 <= 'X' when Is_X(std_logic_vector(window_ptr_spec)) else
               '1' when window_ptr_spec >= TIME_CMP_LEVELS else '0';
      shift2 <= shift1 or no_data_nxt;

      -- new window_ptr:
      -- if no time value has been found, then window_ptr is not changed,
      -- but shift = '1'. See clk_proc.
      -- Post-Condition: window_ptr_nxt < TIME_CMP_LEVELS or no_data_nxt = '1'
      with shift1 select window_ptr_nxt <=
        window_ptr_spec - TIME_CMP_LEVELS when '1',
        window_ptr_spec                   when others;

      global_time_got <= done_level_i and shift2;

      clk_proc : process(clk_sys)
      begin
        if rising_edge(clk_sys) then
          -- current state
          if rst_sys = '1' then
            window_ptr_r <= to_unsigned(TIME_CMP_LEVELS, window_ptr_r'length);
          elsif (done_level_i and not no_data_nxt) = '1' then
            -- Only update if no_data_nxt = '0', See also comment on
            -- window_ptr_nxt.
            assert window_ptr_nxt <= TIME_CMP_LEVELS
              report "Wrong new window_ptr"
              severity error;
            window_ptr_r <= window_ptr_nxt(window_ptr_r'range);
          end if;

          if (done_level_i and shift2) = '1' then
            prev_time_r <= global_time;
          end if;

          -- additional output buffer, see also below
          if done_level = '1' or valid_out_r = '0' then
            current_level <= current_level_nxt;
          end if;
        end if;
      end process clk_proc;

    end generate more_cmp_levels_gen;

    -------------
    -- Outputs --
    -------------

    valid_out_nxt <= global_time_valid;

    -- output buffer, current_level is set above
    clk_out_proc : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        if rst_sys = '1' then
          valid_out_r  <= '0';
          current_time <= (others => '-');
          no_data      <= '-';
        elsif done_level = '1' or valid_out_r = '0' then
          current_time <= current_time_nxt;
          no_data      <= no_data_nxt;
          valid_out_r  <= valid_out_nxt;
        end if;
      end if;
    end process clk_out_proc;

    done_level_i <= (done_level or not valid_out_r) and valid_out_nxt;
    valid_out    <= valid_out_r;

  end block level_sel_blk;

end rtl;
