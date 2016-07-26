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
-- Entity: trace_messageTracer
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- Message Tracer                                   --
--                                                  --
-- data_fill is number of valid bits minus 1        --
------------------------------------------------------
--
-- Revision:    $Revision: 1.5 $
-- Last change: $Date: 2010-04-28 08:13:26 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_types.all;
use poc.trace_functions.all;
use poc.trace_internals.all;

entity trace_messageTracer is
  generic (
    MSG_PORTS  : tPorts;
    FIFO_DEPTH : positive;
    FIFO_SDS   : positive;
    CODING     : boolean;
    CODING_VAL : std_logic_vector;
    TIME_BITS  : natural
  );
  port (
    clk_trc : in std_logic;
    rst_trc : in std_logic;
    clk_sys : in std_logic;
    rst_sys : in std_logic;

    -- port-interface (clk-trc-domain)
    msgs : in std_logic_vector(sumWidths(MSG_PORTS)-1 downto 0);
    stb  : in std_logic;

    stb_out : out std_logic;

    -- controller-output (clk-sys-domain)
    data_out   : out std_logic_vector(getMessageDataOutBits(MSG_PORTS, ifThenElse(CODING, CODING_VAL'length, 0),
                                                            TIME_BITS)-1 downto 0);
    data_got   : in  std_logic;
    data_fill  : out unsigned(log2ceilnz(getMessageDataOutBits(MSG_PORTS, ifThenElse(CODING, CODING_VAL'length, 0),
                                                               TIME_BITS))-1 downto 0);
    data_last  : out std_logic;
    data_se    : out std_logic;
    data_valid : out std_logic;
    sel        : in  std_logic;

    -- enable-interface (clk-trc-domain)
    trc_enable  : in std_logic;
    stb_enable  : in std_logic;
    send_enable : in std_logic;

    -- overflow-interface (clk-trc-domain)
    ov        : out std_logic;
    ov_start  : out std_logic;
    ov_stop   : out std_logic;
    ov_danger : out std_logic
    );
end trace_messageTracer;

architecture Behavioral of trace_messageTracer is

  constant COMPRESSION             : boolean  := haveCompression(MSG_PORTS);
  constant MSG_BITS                : positive := sumWidths(MSG_PORTS);
  constant CODING_BITS             : natural  := ifThenElse(CODING, CODING_VAL'length, 0);
  constant HEADER_VAL_BITS         : natural  := sumTracerHeaderValBits(MSG_PORTS);
  constant HEADER_LEN_BITS         : natural  := sumTracerHeaderLenBits(MSG_PORTS);
  constant HEADER_BITS             : positive := HEADER_VAL_BITS + HEADER_LEN_BITS;
  constant CODING_AND_HEADER_BITS  : positive := CODING_BITS + HEADER_BITS;
  constant CODING_AND_HEADER_BYTES : positive := getBytesUp(CODING_AND_HEADER_BITS);
  constant VAR_VAL_BYTES           : natural  := sumTracerVarValBytes(MSG_PORTS);
  constant VAR_VAL                 : boolean  := VAR_VAL_BYTES > 0;
  constant DATA_OUT_BITS           : positive := getMessageDataOutBits(MSG_PORTS, ifThenElse(CODING, CODING_VAL'length, 0),
                                                                       TIME_BITS);
  constant DATA_FILL_BITS          : positive := log2ceilnz(DATA_OUT_BITS);
  constant OUT_CH_STEPS            : positive := ifThenElse(CODING_AND_HEADER_BITS mod DATA_OUT_BITS > 0,
                                                           (CODING_AND_HEADER_BITS / DATA_OUT_BITS)+1,
                                                            CODING_AND_HEADER_BITS / DATA_OUT_BITS);
  constant OUT_STEPS               : positive := OUT_CH_STEPS + VAR_VAL_BYTES;
  constant SEND_FIRST_BITS         : positive := ifThenElse(CODING_AND_HEADER_BITS mod DATA_OUT_BITS = 0,
                                                            DATA_OUT_BITS,
                                                            CODING_AND_HEADER_BITS mod DATA_OUT_BITS);
  constant OUT_WIDTHS              : tNat_array
                                   := SEND_FIRST_BITS &
                                      ifThenElse(OUT_CH_STEPS > 1,
                                                (max(OUT_CH_STEPS,2)-2 downto 0 => DATA_OUT_BITS), (0,0)) &
                                      ifThenElse(VAR_VAL_BYTES > 0 , (notZero(VAR_VAL_BYTES)-1 downto 0 => 8), (0,0));


  -- clk-trc-domain-signals

  signal stb_tracing : std_logic;
  signal stb_fifordy : std_logic;
  signal stb_i       : std_logic;
  signal stb_en_nov  : std_logic;

  signal fifo_full       : std_logic;
  signal fifo_sd         : std_logic;
  signal fifo_sd_clk_trc : std_logic;

  -- clk-sys-domain-signals

  signal fifo_sd_clk_sys : std_logic;

  signal load_message    : std_logic;
  signal done_message    : std_logic;
  signal done_message_sd : std_logic;
  signal send_enabled    : std_logic;

  signal data_out_all : std_logic_vector(CODING_AND_HEADER_BITS+VAR_VAL_BYTES*8-1 downto 0);

  signal data_out_i   : std_logic_vector(DATA_OUT_BITS-1 downto 0);
  signal data_fill_i  : unsigned(DATA_FILL_BITS-1 downto 0);
  signal data_last_i  : std_logic;
  signal data_got_i   : std_logic;
  signal data_valid_i : std_logic;
  signal data_se_i    : std_logic;

  signal out_counter_r   : unsigned(log2ceilnz(OUT_STEPS)-1 downto 0) := (others => '0');
  signal out_counter_nxt : unsigned(log2ceilnz(OUT_STEPS)-1 downto 0);

begin

  assert FIFO_DEPTH > FIFO_SDS
    report "ERROR: Reduce safe-distance in message-tracer."
    severity error;

  assert countPorts(MSG_PORTS) > 0
    report "ERROR: No valid port in message-tracer."
    severity error;

  -- clk-trc-domain

  fifo_sd_clk_trc <= fifo_sd;

  stb_tracing <= stb and trc_enable;
  stb_fifordy <= stb_tracing and stb_en_nov;
  stb_i       <= stb_enable and stb_fifordy;
  stb_out     <= stb_fifordy and send_enable;

  -- overflow
  ov_blk : block
    signal ov_r        : std_logic := '0';
    signal ov_rst      : std_logic;
    signal ov_set      : std_logic;
    signal ov_danger_i : std_logic;
    signal ov_danger_r : std_logic := '0'; --register signal to prevent timing-error
  begin

    ov_rst <= not ov_danger_r;
    ov_set <= (stb_tracing and fifo_full);

    clk_proc : process(clk_trc)
    begin
      if rising_edge(clk_trc) then
        ov_danger_r <= ov_danger_i;
        if (rst_trc or ov_rst) = '1' then
          ov_r <= '0';
        elsif ov_set = '1' then
          ov_r <= '1';
        end if;
      end if;
    end process clk_proc;

    stb_en_nov  <= not ov_r and not fifo_full;

    -- outputs
    ov          <= ov_r;
    ov_start    <= ov_set and not ov_r;
    ov_stop     <= ov_rst and ov_r;
    ov_danger_i <= fifo_sd_clk_trc;
    ov_danger   <= ov_danger_i;

  end block ov_blk;

  -- bring fifo_sd to clk_sys-domain

  sd_sync : trace_clk_sync
    port map (
      clk_dst   => clk_sys,
      value_in  => fifo_sd_clk_trc,     -- must be a registered value
      value_out => fifo_sd_clk_sys
  );

  -------------------------------------------------------------
  -- implementation with minimal logic and more memory-usage --
  -------------------------------------------------------------

  main_blk : block

    constant FIFO_BITS : positive := MSG_BITS+1;

    -- clk-trc-domain-signals

    signal fifo_din : std_logic_vector(FIFO_BITS-1 downto 0);
    signal fifo_put : std_logic;

    -- clk-sys-domain-signals

    signal header       : std_logic_vector(HEADER_BITS-1 downto 0);
    signal header_out   : std_logic_vector(HEADER_BITS-1 downto 0);
    signal codingHeader : std_logic_vector(CODING_AND_HEADER_BITS-1 downto 0);

    signal fifo_got   : std_logic;
    signal fifo_dout  : std_logic_vector(FIFO_BITS-1 downto 0);
    signal fifo_valid : std_logic;

  begin

    fifo_inst : trace_fifo_ic
      generic map (
        D_BITS     => FIFO_BITS,
        MIN_DEPTH  => FIFO_DEPTH,
        THRESHOLD  => FIFO_SDS,
        OUTPUT_REG => false
      )
      port map (
        clk_wr => clk_trc,
        rst_wr => rst_trc,
        put    => fifo_put,
        din    => fifo_din,
        full   => fifo_full,
        thres  => fifo_sd,
        clk_rd => clk_sys,
        rst_rd => rst_sys,
        got    => fifo_got,
        valid  => fifo_valid,
        dout   => fifo_dout
      );

    --------------------
    -- clk-trc-domain --
    --------------------

    fifo_din <= send_enable & msgs;
    fifo_put <= stb_i;

    --------------------
    -- clk-sys-domain --
    --------------------

    fifo_got     <= load_message;
    send_enabled <= fifo_dout(FIFO_BITS-1);

    -- select header-values
    header_val_proc : process(fifo_dout)
      variable bitmarker  : natural;
      variable bits       : natural;
      variable msgmarker  : natural;
      variable header_val : std_logic_vector(notZero(HEADER_VAL_BITS)-1 downto 0);
    begin
      bitmarker := 0;
      msgmarker := 0;

      if HEADER_VAL_BITS > 0 then

        for i in 0 to countPorts(MSG_PORTS)-1 loop
          if MSG_PORTS(i).COMP /= noneC then
            bits := MSG_PORTS(i).WIDTH mod 8;
          else
            bits := MSG_PORTS(i).WIDTH;
          end if;
          if bits > 0 then
            header_val(bitmarker+bits-1 downto bitmarker) := fifo_dout(msgmarker+bits-1 downto msgmarker);
            bitmarker := bitmarker + bits;
          end if;
          msgmarker := msgmarker + MSG_PORTS(i).WIDTH;
        end loop;
        header(HEADER_LEN_BITS + HEADER_VAL_BITS-1 downto HEADER_LEN_BITS) <= header_val;

      end if;

    end process header_val_proc;

    -- compression
    comp_gen : if COMPRESSION generate

      signal len_mark : std_logic_vector(VAR_VAL_BYTES-1 downto 0);
      signal comp_out : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0);

    begin

      comp_blk : block
        signal comp_stb  : std_logic;
        signal compress  : std_logic;

        -- registered compression-output
        signal lengths_i       : unsigned(HEADER_LEN_BITS-1 downto 0);
        signal len_mark_i      : std_logic_vector(VAR_VAL_BYTES-1 downto 0);
        signal comp_out_i      : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0);
        signal len_mark_r      : std_logic_vector(VAR_VAL_BYTES-1 downto 0) := (others => '0');
        signal comp_out_r      : std_logic_vector(VAR_VAL_BYTES*8-1 downto 0) := (others => '0');
        signal header_r        : std_logic_vector(HEADER_BITS-1 downto 0) := (others => '0');
        signal valid_message_r : std_logic := '0';
        signal send_enabled_r  : std_logic := '0';
      begin

        -- TODO: Compression must be resetted when:
        -- - Every time a message is not transmitted. IMPORTANT!
        --   That is, compress only transmitted messages, except first one.
        -- - Tracing is (re-)started. Should be fixed together with above.
        -- - More cases?
        assert false
          report "Compression for trace messages does not work properly."
          severity error;

        comp_stb <= load_message;

        -- synchronisation

        sync_proc: process (clk_sys)
        begin  -- process sync_proc
          if rising_edge(clk_sys) then
            if rst_sys = '1' then
              compress <= '0';
            else
              -- compression is activated after first message with 'send_enabled'
              compress <= send_enabled;
            end if;
          end if;
        end process sync_proc;

        -- compression

        comp_loop_gen : for i in 0 to countPorts(MSG_PORTS)-1 generate
          constant BITS   : positive := MSG_PORTS(i).WIDTH;
          constant BYTES  : natural  := getTracerVarValBytes(MSG_PORTS(i));
          constant COMP   : tComp    := MSG_PORTS(i).COMP;
          constant LENGTH : natural  := log2ceil(BYTES+1);
        begin

          this_comp_gen : if haveCompression(MSG_PORTS(i)) generate
            constant MSG_INDEX      : natural := sumWidths(MSG_PORTS, i);
            constant MSG_CONST_BITS : natural := MSG_PORTS(i).WIDTH mod 8;
            constant LEN_INDEX      : natural := sumMessageCompLenBits(MSG_PORTS, i);
            constant LEN_MARK_INDEX : natural := sumMessageCompLenMarkBits(MSG_PORTS, i);
            constant COMP_OUT_INDEX : natural := sumMessageCompOutBits(MSG_PORTS, i);
            signal comp_in  : std_logic_vector(BYTES*8-1 downto 0);
          begin

            comp_in <= fifo_dout(MSG_INDEX+BITS-1 downto MSG_INDEX+MSG_CONST_BITS);

            comp_inst : trace_compression
              generic map (
                NUM_BYTES   => BYTES,
                COMPRESSION => COMP
              )
              port map (
                clk      => clk_sys,
                rst      => rst_sys,
                data_in  => comp_in,
                ie       => comp_stb,
                compress => compress,
                len_mark => len_mark_i(LEN_MARK_INDEX+BYTES-1 downto LEN_MARK_INDEX),
                len      => lengths_i(LEN_INDEX+LENGTH-1 downto LEN_INDEX),
                data_out => comp_out_i(COMP_OUT_INDEX+(BYTES*8)-1 downto COMP_OUT_INDEX)
              );

          end generate this_comp_gen;
        end generate comp_loop_gen;

        header(HEADER_LEN_BITS-1 downto 0) <= std_logic_vector(lengths_i);

        -- registered values

        clk_proc : process(clk_sys)
        begin
          if rising_edge(clk_sys) then
            if rst_sys = '1' then
              valid_message_r <= '0';
              send_enabled_r  <= '0';
            elsif done_message = '1' or valid_message_r = '0' then
              len_mark_r      <= len_mark_i;
              comp_out_r      <= comp_out_i;
              header_r        <= header;
              valid_message_r <= fifo_valid;
              send_enabled_r  <= send_enabled;
            end if;
          end if;
        end process clk_proc;

        load_message <= (done_message or not valid_message_r) and fifo_valid;

        len_mark     <= len_mark_r;
        comp_out     <= comp_out_r;
        header_out   <= header_r;
        data_valid_i <= valid_message_r;
        data_se_i    <= send_enabled_r;

      end block comp_blk;

      -- generate outputs for compressed values
      one_byte_out_gen : if VAR_VAL_BYTES = 1 generate
        signal vv_valid  : std_logic;
      begin

        vv_valid <= '1' when len_mark /= "0" else '0';

        -- var-val-bytes

        data_last_i <= '1' when (vv_valid = '0' and out_counter_r = OUT_CH_STEPS-1) or
                                (vv_valid = '1' and out_counter_r = OUT_STEPS-1) else '0';

        data_out_all(CODING_AND_HEADER_BITS+VAR_VAL_BYTES*8-1 downto CODING_AND_HEADER_BITS) <= comp_out;

        out_counter_nxt <= out_counter_r + 1;

      end generate one_byte_out_gen;

      more_bytes_out_gen : if VAR_VAL_BYTES > 1 generate

        signal last_byte       : std_logic;

      begin

--        com_proc : process(lengths, out_counter_r, header)
--          variable index          : natural;
--          variable next_port      : natural;
--          variable current_port   : natural;
--          variable no_port        : boolean;
--          variable last_byte_of_port : boolean;
--          variable last_index     : tNat_array(0 to max(2, countPorts(MSG_PORTS))-1);
--          variable first_index    : tNat_array(0 to max(2, countPorts(MSG_PORTS))-1);
--          variable valid_ports    : std_logic_vector(countPorts(MSG_PORTS)-1 downto 0);
--          variable length_index   : natural;
--          variable length_bits    : natural;
--          variable length         : natural;
--          variable has_next_port  : boolean;
--          variable finish         : std_logic_vector(countPorts(MSG_PORTS)-1 downto 0);
--        begin
--
--          has_next_port   := false;
--          valid_ports     := (others => '0');
--          last_index      := (others => 0);
--          current_port    := 0;
--          next_port       := 0;
--          out_counter_nxt <= out_counter_r + 1;
--
--          -- first index
--
--          for i in 0 to countPorts(MSG_PORTS)-1 loop
--            if haveCompression(MSG_PORTS(i)) then
--              first_index(i) := OUT_CH_STEPS+sumTracerVarValBytes(MSG_PORTS, i);
--            end if;
--          end loop;
--
--          -- last index
--
--          for i in 0 to countPorts(MSG_PORTS)-1 loop
--            if haveCompression(MSG_PORTS(i)) then
--              last_index(i) := OUT_CH_STEPS+sumTracerVarValBytes(MSG_PORTS, i+1)-1;
--            end if;
--          end loop;
--
--          -- caluclate valid ports and finish
--
--          index := 0;
--          for i in 0 to countPorts(MSG_PORTS)-1 loop
--            if haveCompression(MSG_PORTS(i)) then
--              length_index := sumMessageCompLenBits(MSG_PORTS, i);
--              length_bits  := log2ceil(getBytesUp(MSG_PORTS(i).WIDTH)+1);
--              length       := to_integer(lengths(length_index+length_bits-1 downto length_index));
--              if length > 0 then
--                valid_ports(index) := '1';
--              else
--                valid_ports(index) := '0';
--              end if;
--
--            end if;
--            index := index + 1;
--          end loop;
--
--          -- caluclate current port
--
--          no_port := (out_counter_r < OUT_CH_STEPS);
--
--          for i in 0 to countPorts(MSG_PORTS)-1 loop
--            if haveCompression(MSG_PORTS(i)) then
--              if out_counter_r >= first_index(i) and
--                 out_counter_r <= last_index(i) then
--                current_port := i;
--              end if;
--            end if;
--          end loop;
--
--          -- calculate next port
--
--          for i in 0 to countPorts(MSG_PORTS)-1 loop
--            if not has_next_port then
--              if haveCompression(MSG_PORTS(i)) then
--                if (no_port and i >= current_port) or (not no_port and i > current_port) then
--                  if valid_ports(i) = '1' then
--                    next_port     := i;
--                    has_next_port := true;
--                  end if;
--                end if;
--              end if;
--            end if;
--          end loop;
--
--          -- check, if current byte is last of current port
--          if out_counter_r = last_index(current_port) then
--            last_byte_of_port := true;
--          else
--            last_byte_of_port := false;
--          end if;
--
--          -- outputs
--
--          if not has_next_port and (last_byte_of_port or no_port) then
--            finish_message <= '1';
--          else
--            finish_message <= '0';
--          end if;
--
--          if (no_port and out_counter_r = OUT_CH_STEPS-1) then
--            out_counter_nxt <= to_unsigned(first_index(next_port), out_counter_nxt'length);
--          elsif no_port then
--            out_counter_nxt <= out_counter_r + 1;
--          elsif last_byte_of_port then
--            out_counter_nxt <= to_unsigned(first_index(next_port), out_counter_nxt'length);
--          end if;
--
--        end process com_proc;

        com_proc : process(len_mark, out_counter_r)
          variable found : boolean;
        begin
          last_byte       <= '0';
          out_counter_nxt <= out_counter_r + 1;
          found           := false;

          if out_counter_r >= OUT_CH_STEPS-1 then
            last_byte <= '1';
            for i in OUT_CH_STEPS to OUT_STEPS-1 loop
              if i > to_integer(out_counter_r) then
                if not found then
                  if len_mark(i-OUT_CH_STEPS) = '1' then
                    out_counter_nxt <= to_unsigned(i, out_counter_nxt'length);
                    found     := true;
                    last_byte <= '0';
                  end if;
                end if;
              end if;
            end loop;
          end if;
        end process com_proc;

        data_last_i <= last_byte;

        -- put data-output to central vector
        data_out_all(CODING_AND_HEADER_BITS+VAR_VAL_BYTES*8-1 downto CODING_AND_HEADER_BITS) <= comp_out;

      end generate more_bytes_out_gen;

    end generate comp_gen;

    -- no compression

    no_comp_gen : if not haveCompression(MSG_PORTS) generate
      header_out      <= header;
      load_message    <= done_message;
      data_last_i     <= '1' when out_counter_r = OUT_CH_STEPS-1 else '0';
      data_valid_i    <= fifo_valid;
      data_se_i       <= send_enabled;
      out_counter_nxt <= out_counter_r + 1;
    end generate no_comp_gen;

    -- header-output

    coding_gen : if CODING generate
      codingHeader <= header_out & CODING_VAL;
    end generate coding_gen;

    no_coding_gen : if not CODING generate
      codingHeader <= header_out;
    end generate no_coding_gen;

    data_out_all(CODING_AND_HEADER_BITS-1 downto 0) <= codingHeader;

  end block main_blk;

  -------------
  -- Outputs --
  -------------

  out_blk : block

    signal out_counter_set : std_logic;
    signal out_counter_rst : std_logic;

  begin

    clk_proc : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        if rst_sys = '1' or out_counter_rst = '1' then
          out_counter_r <= (others => '0');
        elsif out_counter_set = '1' then
          out_counter_r <= out_counter_nxt;
        end if;
      end if;
    end process clk_proc;

    data_out_multiplex : trace_multiplex
      generic map (
        DATA_BITS => OUT_WIDTHS,
        IMPL      => false
      )
      port map (
        inputs => data_out_all,
        sel    => out_counter_r,
        output => data_out_i(max(OUT_WIDTHS)-1 downto 0)
      );

    data_fill_i  <= to_unsigned(DATA_OUT_BITS-1, DATA_FILL_BITS) when out_counter_r > 0 and out_counter_r < OUT_CH_STEPS else
                    to_unsigned(7, DATA_FILL_BITS)               when out_counter_r >= OUT_CH_STEPS else
                    to_unsigned(SEND_FIRST_BITS-1, DATA_FILL_BITS);

    done_message_sd <= not data_se_i and not sel and fifo_sd_clk_sys;

    done_message <= (data_got_i and data_last_i) or done_message_sd;

    out_counter_rst <= done_message;
    out_counter_set <= data_got_i;

    data_got_i <= data_got;

    data_fill  <= data_fill_i;
    data_last  <= data_last_i;
    data_out   <= data_out_i;
    data_valid <= data_valid_i;
    data_se    <= data_se_i;

  end block out_blk;

end Behavioral;
