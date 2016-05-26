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
-- Entity: trace_compression
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- trace_compression.vhdl                           --
-- Xor-, Diff- or Trim-Compression                  --
------------------------------------------------------
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2010-04-26 13:37:32 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_types.all;

entity trace_compression is
  generic (
    NUM_BYTES   : positive := 8;
    COMPRESSION : tComp := XorC
  );
  port (

    -- Globals --
    clk : in  std_logic; -- Clock
    rst : in  std_logic; -- Reset

    -- Inputs --
    data_in  : in std_logic_vector(NUM_BYTES*8-1 downto 0); -- Input Data
    ie       : in std_logic;                                -- Input Enable
    compress : in std_logic;

    -- Outputs --
    len      : out unsigned(log2ceil(NUM_BYTES+1)-1 downto 0); -- Data Length
    len_mark : out std_logic_vector(NUM_BYTES-1 downto 0);             -- Data Length (mark-coding)
    data_out : out std_logic_vector(NUM_BYTES*8-1 downto 0)            -- Output Data
  );
end trace_compression;

architecture rtl of trace_compression is
begin

  ---------------------
  -- XOR-Compression --
  ---------------------

  xor_gen : if COMPRESSION = XorC generate

    signal mark       : std_logic_vector(NUM_BYTES-1 downto 0);
    signal cmp        : std_logic;
    signal msbs_i     : std_logic;
    signal len_i      : unsigned(log2ceil(NUM_BYTES+1)-1 downto 0);
    signal len_mark_i : std_logic_vector(NUM_BYTES-1 downto 0);
    signal value_r    : std_logic_vector(NUM_BYTES*8-1 downto 0) := (others => '0');

  begin

    -- save old value

    clk_proc : process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          value_r <= (others => '0');
        elsif ie = '1' then
          value_r <= data_in;
        end if;
      end if;
    end process clk_proc;

    -- mark all bytes, that could be trimmed

    mark_gen : for i in NUM_BYTES-1 downto 0 generate
    begin
      mark(i) <= '0' when data_in(8*(i+1)-1 downto 8*i) = value_r(8*(i+1)-1 downto 8*i)
                     else '1';
    end generate mark_gen;

    -- cut

    len_mark_i(NUM_BYTES-1) <= mark(NUM_BYTES-1);

    cut_gen : for i in NUM_BYTES-2 downto 0 generate
    begin
      len_mark_i(i) <= mark(i) or len_mark_i(i+1);
    end generate cut_gen;

    -- count bytes

    com_proc : process(len_mark_i)
      variable cnt : natural;
    begin
      cnt := 0;
      for i in NUM_BYTES-1 downto 0 loop
        if len_mark_i(i) = '1' then
          cnt := cnt + 1;
        end if;
      end loop;
      len_i <= to_unsigned(cnt, len_i'length);
    end process com_proc;

    -- outputs

    with compress select
      len <= len_i                              when '1',
             to_unsigned(NUM_BYTES, len'length) when others;

    with compress select
      len_mark <= len_mark_i                    when '1',
                  (NUM_BYTES-1 downto 0 => '1') when others;

    data_out <= data_in;

  end generate xor_gen;

  ----------------------
  -- Diff-Compression --
  ----------------------

  diff_gen : if COMPRESSION = DiffC generate

    signal value_r   : unsigned(NUM_BYTES*8-1 downto 0) := (others => '0');

    signal diff : unsigned(NUM_BYTES*8 downto 0);

    signal len_i      : unsigned(log2ceil(NUM_BYTES+1)-1 downto 0);
    signal len_mark_i : std_logic_vector(NUM_BYTES-1 downto 0);
    signal data_out_i : std_logic_vector(NUM_BYTES*8-1 downto 0);

    signal no_comp      : std_logic;
    signal compress_out : std_logic;

  begin

    compress_out <= not no_comp and compress;

    diff <= unsigned('0' & data_in) - ('0' & value_r);

    com_proc : process(ie, compress, diff)
      variable marker   : unsigned(log2ceil(NUM_BYTES+1)-1 downto 0);
      variable done     : boolean;
      variable cmp_byte : unsigned(7 downto 0);
    begin

      marker     := to_unsigned(NUM_BYTES, log2ceil(NUM_BYTES+1));
      done       := false;
      len_i      <= to_unsigned(NUM_BYTES, len_i'length);
      len_mark_i <= (others => '1');
      no_comp    <= '0';

      if compress = '1' then
        if NUM_BYTES > 1 then
          cmp_byte := (7 downto 0 => diff(NUM_BYTES*8));
          for i in NUM_BYTES-1 downto 1 loop
            if(not done) then
              if diff(8*(i+1)-1 downto 8*i) = cmp_byte and diff(8*i-1) = diff(NUM_BYTES*8) then
                len_mark_i(i) <= '0';
                marker        := marker-1;
              else
                done := true;
                if i = NUM_BYTES-1 then
                  no_comp <= '1';
                end if;
              end if;
            end if;
          end loop;
        end if;
        if (not done) then
          if diff(7 downto 0) = 0 and diff(NUM_BYTES*8) = '0' then
            len_mark_i(0) <= '0';
            marker        := marker-1;
          elsif NUM_BYTES = 1 then
            no_comp <= '1';
          end if;
        end if;
        len_i <= marker;
      end if;

    end process com_proc;

    with(compress_out) select
      data_out_i <= std_logic_vector(diff(NUM_BYTES*8-1 downto 0)) when '1',
                    std_logic_vector(data_in)                      when others; -- '0';

    clk_proc : process(clk)
    begin
      if rising_edge(clk) then
        if(rst = '1') then
          value_r    <= (others => '0');
        elsif ie = '1' then
          value_r    <= unsigned(data_in);
        end if;
      end if;
    end process clk_proc;

    -- outputs

    len      <= len_i;
    len_mark <= len_mark_i;
    data_out <= data_out_i;

  end generate diff_gen;

  ----------------------
  -- Trim Compression --
  ----------------------

  trim_gen : if COMPRESSION = TrimC generate

    signal mark       : std_logic_vector(NUM_BYTES-1 downto 0);
    signal cmp        : std_logic;
    signal len_i      : unsigned(log2ceil(NUM_BYTES+1)-1 downto 0);
    signal len_mark_i : std_logic_vector(NUM_BYTES-1 downto 0);

  begin

    cmp <= data_in(NUM_BYTES*8-1);

    -- mark all bytes, that could be trimmed

    mark_gen : for i in NUM_BYTES-1 downto 1 generate
    begin
      mark(i) <= '0' when data_in(8*(i+1)-1 downto 8*i) = (7 downto 0 => cmp)
                      and data_in(8*i-1) = cmp
                     else '1';
    end generate mark_gen;

    mark(0) <= '0' when unsigned(data_in(7 downto 0)) = 0 and cmp = '0' else '1';

    -- cut

    len_mark_i(NUM_BYTES-1) <= mark(NUM_BYTES-1);

    cut_gen : for i in NUM_BYTES-2 downto 0 generate
    begin
      len_mark_i(i) <= mark(i) or len_mark_i(i+1);
    end generate cut_gen;

    -- count bytes

    com_proc : process(len_mark_i)
      variable cnt : natural;
    begin
      cnt := 0;
      for i in NUM_BYTES-1 downto 0 loop
        if len_mark_i(i) = '1' then
          cnt := cnt + 1;
        end if;
      end loop;
      len_i <= to_unsigned(cnt, len_i'length);
    end process com_proc;

    -- outputs

    with compress select
      len <= len_i                              when '1',
             to_unsigned(NUM_BYTES, len'length) when others;

    with compress select
      len_mark <= len_mark_i                    when '1',
                  (NUM_BYTES-1 downto 0 => '1') when others;

    data_out <= data_in;

  end generate trim_gen;

  --------------------
  -- No Compression --
  --------------------

  no_gen : if COMPRESSION = NoneC generate
  begin

    len      <= to_unsigned(NUM_BYTES, len'length);
    len_mark <= (others => '1');
    data_out <= data_in;

  end generate no_gen;

end rtl;
