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
-- Entity: trace_tracer_time
-- Author(s): Stefan Alex
-- 
------------------------------------------------------
-- Collect tracer time values                       --
------------------------------------------------------
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2010-04-24 18:16:40 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_internals.all;
use poc.trace_functions.all;

entity trace_tracer_time is
  generic (
    TRACER                    : positive;
    TRACER_TIME_SAFE_DISTANCE : positive;
    TRACER_TIME_FIFO_DEPTH    : positive
    );
  port (
    clk_trc : in std_logic;
    rst_trc : in std_logic;
    clk_sys : in std_logic;
    rst_sys : in std_logic;

    -- clk-trc-domain (inputs)
    tracer_stbs    : in  std_logic_vector(TRACER-1 downto 0);
    tracer_data_se : in  std_logic_vector(TRACER-1 downto 0);
    tracer_sel     : out std_logic_vector(TRACER-1 downto 0);
    stb_en_in      : in  std_logic;
    stb_en_out     : out std_logic;
    ov_stop        : out std_logic;
    ov_danger      : out std_logic;

    -- clk-eth-domain (outputs)
    done_tracer           : in  std_logic;
    current_tracer        : out unsigned(log2ceilnz(TRACER)-1 downto 0);
    first_tracer_in_level : out std_logic;
    last_tracer_in_level  : out std_logic;
    valid_out             : out std_logic

    );
end trace_tracer_time;

architecture Behavioral of trace_tracer_time is

  signal tracer_time       : std_logic_vector(TRACER-1 downto 0);
  signal tracer_time_got   : std_logic;
  signal tracer_time_valid : std_logic;

  signal tracer_stb         : std_logic;
  signal tracer_stb_enabled : std_logic;
  signal stb_en_out_i       : std_logic;

begin

  --------------------------
  -- the tracer-time-fifo --
  --------------------------

  fifo_blk : block
    -- clk-trc-domain
    signal tt_fifo_put  : std_logic;
    signal tt_fifo_din  : std_logic_vector(TRACER-1 downto 0);
    signal tt_fifo_full : std_logic;
    signal tt_fifo_sd   : std_logic;

    -- clk-eth-domain
    signal tt_fifo_valid : std_logic;
    signal tt_fifo_dout  : std_logic_vector(TRACER-1 downto 0);
    signal tt_fifo_got   : std_logic;
  begin

    assert TRACER_TIME_FIFO_DEPTH > TRACER_TIME_SAFE_DISTANCE
      report "ERROR: Reduce Tracer-Time-Safe-Distance."
      severity error;

    tracer_time_fifo_inst : trace_fifo_ic
      generic map (
        D_BITS     => TRACER,
        MIN_DEPTH  => TRACER_TIME_FIFO_DEPTH,
        THRESHOLD  => TRACER_TIME_SAFE_DISTANCE,
        OUTPUT_REG => false
      )
      port map (
        clk_wr => clk_trc,
        rst_wr => rst_trc,
        put    => tt_fifo_put,
        din    => tt_fifo_din,
        full   => tt_fifo_full,
        thres  => tt_fifo_sd,
        clk_rd => clk_sys,
        rst_rd => rst_sys,
        got    => tt_fifo_got,
        valid  => tt_fifo_valid,
        dout   => tt_fifo_dout
      );

    tt_fifo_din <= tracer_stbs;
    tt_fifo_put <= tracer_stb_enabled;

    tt_fifo_got <= tracer_time_got;

    --------------
    -- overflow --
    --------------

    ov_blk : block
      signal ov_r        : std_logic := '0';
      signal ov_rst      : std_logic;
      signal ov_set      : std_logic;
      signal ov_danger_i : std_logic;
    begin

      -- overflow-policy
      -- when data-fifo overflows, no time-event is marked
      -- when tracer_time-fifo overflows, no data is added to data-fifo and no event is marked in tracer-time-fifo
      -- if global-time-fifo overflows, everything is stopped, this means tracing and tracer-time-fifo
      -- => data is resynchronized in data-fifo in every case

      stb_en_out_i <= not tt_fifo_full and not ov_r;
      stb_en_out   <= stb_en_out_i;

      tracer_stb         <= '1' when unsigned(tracer_stbs) /= 0 else '0';
      tracer_stb_enabled <= tracer_stb and stb_en_in and stb_en_out_i;

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
      ov_set <= tracer_stb and not stb_en_out_i;

      ov_stop <= ov_rst and ov_r;

      ov_danger_i <= tt_fifo_sd;
      ov_danger   <= ov_danger_i;

    end block ov_blk;

    -------------
    -- Outputs --
    -------------

    tracer_time       <= tt_fifo_dout;
    tt_fifo_got       <= tracer_time_got;
    tracer_time_valid <= tt_fifo_valid;

  end block fifo_blk;

  -------------------
  -- Tracer select --
  -------------------

  tracer_sel_blk : block
    signal valid_tracer_r   : std_logic_vector(TRACER-1 downto 0) := (others => '1');
    signal valid_tracer_rst : std_logic;
    signal valid_tracer_set : std_logic;

    signal current_tracer_i          : unsigned(log2ceilnz(TRACER)-1 downto 0);
    signal current_tracer_r          : unsigned(log2ceilnz(TRACER)-1 downto 0) := (others => '0');
    signal next_tracer_valid_i       : std_logic;
    signal next_tracer_valid_r       : std_logic := '0';
    signal first_tracer_in_level_set : std_logic;
    signal first_tracer_in_level_rst : std_logic;
    signal first_tracer_in_level_r   : std_logic := '1';
    signal first_tracer_in_level_r_2 : std_logic := '1';
    signal valid_out_i               : std_logic;
    signal valid_out_r               : std_logic := '0';
    signal tracer_data_se_sel        : std_logic;

    signal done_tracer_i : std_Logic;

    signal tracer_time_masked : std_logic_vector(TRACER-1 downto 0);

  begin

    clk_proc : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        if rst_sys = '1' then
          valid_tracer_r  <= (others => '1');
        else

          if first_tracer_in_level_rst = '1' then
            first_tracer_in_level_r <= '0';
          elsif first_tracer_in_level_set = '1' then
            first_tracer_in_level_r <= '1';
          end if;

          if tracer_time_valid = '1' then
            if valid_tracer_rst = '1' and current_tracer_i < TRACER then
              valid_tracer_r(to_integer(current_tracer_i)) <= '0';
            elsif valid_tracer_set = '1' then
              valid_tracer_r <= (others => '1');
            end if;
          end if;
        end if;
      end if;
    end process clk_proc;

    -- mask finished time-data (only needed, when there are more than 2 tracer)
    tracer_time_masked <= tracer_time and valid_tracer_r;

    first_tracer_in_level_set <= tracer_time_got;
    first_tracer_in_level_rst <= not tracer_time_got and done_tracer_i;

    -- select the first valid pointer

    com_proc : process(tracer_time_masked)
      variable haveFirst  : boolean;
      variable haveSecond : boolean;
    begin

      haveFirst  := false;
      haveSecond := false;

      next_tracer_valid_i <= '0';

      current_tracer_i <= to_unsigned(0, current_tracer_i'length);

      for i in 0 to tracer_time_masked'length-1 loop
        if tracer_time_masked(i) = '1' then
          if not haveFirst then
            current_tracer_i <= to_unsigned(i, current_tracer_i'length);
            haveFirst        := true;
          elsif not haveSecond then
            next_tracer_valid_i <= '1';
            haveSecond          := true;
          end if;
        end if;
      end loop;

    end process com_proc;

    tracer_time_got <= done_tracer_i and not next_tracer_valid_i;

    valid_tracer_set <= tracer_time_got;
    valid_tracer_rst <= done_tracer_i and next_tracer_valid_i;

    -------------
    -- Outputs --
    -------------

    -- select tracer
    sel_gen : for i in 0 to TRACER-1 generate
      tracer_sel(i) <= '1' when current_tracer_r = i and valid_out_r = '1' else '0';
    end generate sel_gen;

    valid_out_i <= tracer_time_valid;

    clk_out_proc : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        if rst_sys = '1' then
          valid_out_r               <= '0';
          first_tracer_in_level_r_2 <= '0';
        else

          if ((done_tracer and tracer_data_se_sel) = '1') or valid_out_r = '0' then
            current_tracer_r    <= current_tracer_i;
            valid_out_r         <= valid_out_i;
            next_tracer_valid_r <= next_tracer_valid_i;
          end if;

          if ((done_tracer and tracer_data_se_sel) = '1') or valid_out_r = '0' then
            first_tracer_in_level_r_2 <= first_tracer_in_level_r;
          elsif done_tracer = '1' and tracer_data_se_sel = '0' then
            first_tracer_in_level_r_2 <= '0';
          end if;

        end if;
      end if;
    end process clk_out_proc;

    done_tracer_i <= ((done_tracer and tracer_data_se_sel) or not valid_out_r) and valid_out_i;

    tracer_data_se_sel <= tracer_data_se(to_integer(current_tracer_r));

    current_tracer        <= current_tracer_r;
    first_tracer_in_level <= first_tracer_in_level_r_2;
    last_tracer_in_level  <= not next_tracer_valid_r and tracer_data_se_sel;
    valid_out             <= valid_out_r;

  end block tracer_sel_blk;

end Behavioral;
