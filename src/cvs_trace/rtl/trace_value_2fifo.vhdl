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
-- Entity: trace_value_2fifo
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- Put value to fifo                                --
--                                                  --
-- in_value_fill is number of valid bits minus 1    --
------------------------------------------------------
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-03-29 15:44:33 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_functions.all;
use poc.trace_types.all;
use poc.trace_internals.all;

entity trace_value_2fifo is
  generic (
    BLOCK_BITS   : positive := 1;
    IN_BLOCKS    : positive := 4;
    OUT_BLOCKS   : positive := 2
    );
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    -- input-values
    in_value_got   : out std_logic;
    in_value       : in  std_logic_vector(IN_BLOCKS*BLOCK_BITS-1 downto 0);
    in_value_fill  : in  unsigned(log2ceilnz(IN_BLOCKS)-1 downto 0);
    in_value_valid : in  std_logic;
    -- output-fifo-interface
    fifo_dat  : out std_logic_vector(OUT_BLOCKS*BLOCK_BITS-1 downto 0);
    fifo_put  : out std_logic;
    fifo_full : in  std_logic;
    fifo_ptr  : out unsigned(log2ceil(OUT_BLOCKS)-1 downto 0)
    );
end trace_value_2fifo;

architecture Behavioral of trace_value_2fifo is

  constant IN_BITS  : positive := IN_BLOCKS*BLOCK_BITS;
  constant OUT_BITS : positive := OUT_BLOCKS*BLOCK_BITS;

  constant REG_BITS : positive := (OUT_BLOCKS-1)*BLOCK_BITS;

  signal reg_value_r   : std_logic_vector(REG_BITS-1 downto 0) := (others => '0');
  signal reg_value_nxt : std_logic_vector(REG_BITS-1 downto 0);
  signal reg_value_ce  : std_logic;

  signal fill_value : std_logic_vector(OUT_BITS-1 downto 0);
  signal fill_value_filled : std_logic;

  signal regFill_r   : unsigned(log2ceil(OUT_BLOCKS)-1 downto 0) := (others => '0');
  signal regFill_nxt : unsigned(log2ceil(OUT_BLOCKS)-1 downto 0);
  signal regFill_ce  : std_logic;
  signal regPtr      : unsigned(log2ceil(OUT_BLOCKS)-1 downto 0);

  signal inPtr : unsigned(log2ceil(IN_BLOCKS)-1 downto 0);

  signal inPtr_fill_tmp : unsigned(log2ceil(max(IN_BLOCKS, OUT_BLOCKS))-1 downto 0);
  signal inPtr_fill     : unsigned(log2ceil(IN_BLOCKS)-1 downto 0);
  signal inPtr_reg      : unsigned(log2ceil(IN_BLOCKS)-1 downto 0);

  signal reg_blocks  : unsigned(log2ceil(IN_BLOCKS)-1 downto 0);
  signal fill_blocks : unsigned(log2ceil(IN_BLOCKS+OUT_BLOCKS)-1 downto 0);

  signal fifo_put_i : std_logic;

  signal in_value_fill_p1 : unsigned(log2ceil(IN_BLOCKS+1)-1 downto 0);

begin

  assert OUT_BLOCKS > 1 and IN_BLOCKS > 1
    severity error;

  regPtr <= regFill_r - 1;

  inPtr_fill_tmp <= inPtr - regFill_r;
  inPtr_fill     <= inPtr_fill_tmp(inPtr_fill'left downto 0);

  -- select the fill_value
  fill_value_gen : for i in 0 to OUT_BLOCKS-2 generate
    signal getFromReg   : std_logic;
    signal offset       : unsigned(log2ceil(IN_BLOCKS)-1 downto 0);
    signal in_value_off : std_logic_vector(BLOCK_BITS-1 downto 0);

    signal fill_value_i : std_logic_vector(BLOCK_BITS-1 downto 0);
    signal reg_value_i  : std_logic_vector(BLOCK_BITS-1 downto 0);

  begin

    reg_value_i <= reg_value_r((i+1)*BLOCK_BITS-1 downto i*BLOCK_BITS);

    getFromReg <= '1' when i < regFill_r else '0';

    offset     <= inPtr_fill+i;

    -- select the input-value
    in_value_multiplex : trace_multiplex
      generic map (
        DATA_BITS => (IN_BLOCKS-1 downto 0 => BLOCK_BITS),
        IMPL      => true
      )
      port map (
        inputs => in_value,
        sel    => offset,
        output => in_value_off
      );

    -- multiplex between register and input
    with getFromReg select
      fill_value_i <= reg_value_i  when '1',
                      in_value_off when others;

    fill_value((i+1)*BLOCK_BITS-1 downto i*BLOCK_BITS) <= fill_value_i;

  end generate fill_value_gen;

  -- select the fill_value
  last_fill_value_blk : block
    constant I : natural := OUT_BLOCKS-1;
    signal offset       : unsigned(log2ceil(IN_BLOCKS)-1 downto 0);
    signal in_value_off : std_logic_vector(BLOCK_BITS-1 downto 0);

    signal fill_value_i : std_logic_vector(BLOCK_BITS-1 downto 0);

  begin

    offset <= inPtr_fill+i;

    -- select the input-value
    in_value_multiplex : trace_multiplex
      generic map (
        DATA_BITS => (IN_BLOCKS-1 downto 0 => BLOCK_BITS),
        IMPL      => true
      )
      port map (
        inputs => in_value,
        sel    => offset,
        output => in_value_off
      );

    fill_value_i <= in_value_off;

    fill_value((i+1)*BLOCK_BITS-1 downto i*BLOCK_BITS) <= fill_value_i;

  end block last_fill_value_blk;

  inPtr_reg <= inPtr_fill+OUT_BLOCKS;

  -- select next register-value
  reg_byte_gen : for i in 0 to OUT_BLOCKS-2 generate
    signal offset       : unsigned(log2ceil(IN_BLOCKS)-1 downto 0);
    signal in_value_off : std_logic_vector(BLOCK_BITS-1 downto 0);

    signal fill_value_i    : std_logic_vector(BLOCK_BITS-1 downto 0);
    signal reg_value_nxt_i : std_logic_vector(BLOCK_BITS-1 downto 0);

  begin

    fill_value_i <= fill_value((i+1)*BLOCK_BITS-1 downto i*BLOCK_BITS);

    offset <= inPtr_reg+i;

    -- select the input-value
    in_value_multiplex : trace_multiplex
      generic map (
        DATA_BITS => (IN_BLOCKS-1 downto 0 => BLOCK_BITS),
        IMPL      => true
      )
      port map (
        inputs => in_value,
        sel    => offset,
        output => in_value_off
      );

    with fill_value_filled select
      reg_value_nxt_i <= in_value_off when '1',
                         fill_value_i when others;

    reg_value_nxt((i+1)*BLOCK_BITS-1 downto i*BLOCK_BITS) <= reg_value_nxt_i;

  end generate reg_byte_gen;

  -- calculate the register-pointer

  in_value_fill_p1 <= fill(in_value_fill, log2ceil(IN_BLOCKS+1)) + 1;

  fill_value_filled <= '1' when OUT_BLOCKS <= fill_blocks else '0';

  fill_blocks <= fill(in_value_fill_p1 - inPtr, log2ceil(IN_BLOCKS+OUT_BLOCKS)) +
                 fill(regFill_r,                log2ceil(IN_BLOCKS+OUT_BLOCKS));

  reg_blocks  <= cut(fill_blocks - OUT_BLOCKS, log2ceil(IN_BLOCKS));

  regFill_nxt  <= to_unsigned(OUT_BLOCKS-1, regFill_nxt'length) when fill_value_filled = '1' and reg_blocks >= OUT_BLOCKS-1 else
                  reg_blocks(regFill_nxt'left downto 0)         when fill_value_filled = '1' else
                  fill_blocks(regFill_nxt'left downto 0);

  regFill_ce   <= in_value_valid and not fifo_full;
  reg_value_ce <= regFill_ce;

  fifo_put_i   <= fill_value_filled and not fifo_full and in_value_valid;

  in_value_got  <= '1' when fifo_full = '0' and in_value_valid = '1'
                        and (fill_value_filled = '0' or (fill_value_filled = '1' and reg_blocks <= OUT_BLOCKS-1))
                       else '0';

  fifo_put <= fifo_put_i;
  fifo_dat <= fill_value;

  with fifo_put_i select
    fifo_ptr <= to_unsigned(OUT_BLOCKS-1, fifo_ptr'length) when '1',
                regPtr                                     when others;

  clk_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        reg_value_r <= (others => '0');
        regFill_r   <= (others => '0');
      else
        if reg_value_ce = '1' then
          reg_value_r <= reg_value_nxt;
        end if;
        if regFill_ce = '1' then
          regFill_r <= regFill_nxt;
        end if;
      end if;
    end if;
  end process clk_proc;

  -- inPtr-logic

  inPtr_gen : if IN_BLOCKS > OUT_BLOCKS generate
    signal inPtr_nxt : unsigned(log2ceil(IN_BLOCKS)-1 downto 0);
    signal inPtr_ce  : std_logic;
    signal inPtr_r   : unsigned(log2ceil(IN_BLOCKS)-1 downto 0) := (others => '0');
  begin

    inPtr_nxt <= inPtr_reg + OUT_BLOCKS-1 when fill_value_filled = '1' and reg_blocks > OUT_BLOCKS-1 else (others => '0');
    inPtr_ce  <= in_value_valid and not fifo_full;

    inPtr     <= inPtr_r;

    clk_proc : process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          inPtr_r     <= (others => '0');
        else
          if inPtr_ce = '1' then
            inPtr_r <= inPtr_nxt;
          end if;
        end if;
      end if;
    end process clk_proc;

  end generate inPtr_gen;

  no_inPtr_gen : if IN_BLOCKS = OUT_BLOCKS generate
    inPtr <= (others => '0');
  end generate no_inPtr_gen;

end Behavioral;

