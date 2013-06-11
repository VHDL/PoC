--
-- Copyright (c) 2007
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
-- Entity: fifo_dc_got_sm
-- Author(s): Martin Zabel
-- 
-- Small FIFO with dependent clocks and first-word-fall-through mode
--
-- Dependent clocks meens, that one clock must be a multiple of the other one.
-- And your synthesis tool must check for setup- and hold-time violations.
--
-- This implementation uses a small register-file for storing data. Your
-- synthesis tool might infer memory. This memory must
-- - either support asynchronous reads (as an register-file)
-- - or a synchronous read with mixed-port read-during-write (write-first).
--
-- First-word-fall-through (FWFT) mode is implemented, so data can be read out
-- as soon as 'valid' goes high. After the data has been captured, then the
-- signal 'got' must be asserted.
--
-- The advantage of the register file is, that data is available at the read
-- port after the rising edge of the write clock it has been written to.
--
-- Because implementing register-files onto a FPGA might require a lot of LUT
-- logic, use this implementation only for small FIFOs.
--
-- Another disadvantage is, that the signals 'full' and
-- 'valid' are combinatorial and include an adress comparator in their path.
--
-- The specified depth (MIN_DEPTH) is rounded up to the next suitable value.
--
-- Synchronous reset is used. Both resets must overlap.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2013-03-26 15:59:46 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

entity fifo_dc_got_sm is

  generic (
    D_BITS    : positive;-- := 8;
    MIN_DEPTH : positive--  := 15
  );

  port (
    -- Write Interface
    clk_wr : in  std_logic;
    rst_wr : in  std_logic;
    put    : in  std_logic;
    din    : in  std_logic_vector(D_BITS-1 downto 0);
    full   : out std_logic;

    -- Read Interface
    clk_rd : in  std_logic;
    rst_rd : in  std_logic;
    got    : in  std_logic;
    valid  : out std_logic;
    dout   : out std_logic_vector(D_BITS-1 downto 0)
  );

end fifo_dc_got_sm;

architecture rtl of fifo_dc_got_sm is
  constant A_BITS     : positive := log2ceil(MIN_DEPTH+1);
  constant REAL_DEPTH : positive := 2**A_BITS;

  -- Memory
  type ram_t is array(0 to REAL_DEPTH-1) of
    std_logic_vector(D_BITS-1 downto 0);
  signal ram : ram_t;

  attribute ram_style        : string;  -- XST specific
  attribute ram_style of ram : signal is "distributed";
  attribute ramstyle         : string;  -- Quartus specific
  attribute ramstyle of ram  : signal is "logic";
  
  -- Registers, clk_wr domain
  signal write_addr_r      : unsigned(A_BITS-1 downto 0) := (others => '0');
  signal write_nextaddr_r  : unsigned(A_BITS-1 downto 0) := to_unsigned(1, A_BITS);
  signal read_addr_clkwr_r : unsigned(A_BITS-1 downto 0) := (others => '0');

  -- Registers, clk_rd domain
  signal read_addr_r        : unsigned(A_BITS-1 downto 0) := (others => '0');
  signal write_addr_clkrd_r : unsigned(A_BITS-1 downto 0) := (others => '0');

  -- Control signals
  signal do_put : std_logic;
  signal do_got : std_logic;

  -- Internal versions of output signals
  signal valid_i : std_logic;
  signal full_i  : std_logic;

begin  -- rtl

  -----------------------------------------------------------------------------
  -- Write clock domain
  -----------------------------------------------------------------------------

  process (clk_wr)
  begin  -- process
    if rising_edge(clk_wr) then
      if rst_wr = '1' then
        write_addr_r     <= (others => '0');
        write_nextaddr_r <= to_unsigned(1, A_BITS);

      elsif do_put = '1' then
        write_addr_r     <= write_addr_r + 1;
        write_nextaddr_r <= write_nextaddr_r + 1;
      end if;

      if rst_wr = '1' then
        read_addr_clkwr_r <= (others => '0');
      else
        read_addr_clkwr_r <= read_addr_r;
      end if;
      
      if do_put = '1' then
        ram(to_integer(write_addr_r)) <= din;
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Read clock domain
  -----------------------------------------------------------------------------

  process (clk_rd)
  begin  -- process
    if rising_edge(clk_rd) then
      if rst_rd = '1' then
        read_addr_r       <= (others => '0');
      elsif do_got = '1' then
        read_addr_r       <= read_addr_r + 1;
      end if;

      if rst_rd = '1' then
        write_addr_clkrd_r <= (others => '0');
      else
        write_addr_clkrd_r <= write_addr_r;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Control
  -----------------------------------------------------------------------------

  -- Check validity.
  do_put <= put and (not full_i);
  do_got <= got and valid_i;

  -- A direction flag is not available because it cannot assigned to both clock
  -- domains.
  --
  -- Instead, one memory word is unused, so that read and write address only
  -- equal if the FIFO is empty.

  valid_i <= '1' when read_addr_r /= write_addr_clkrd_r else '0';

  full_i <= '1' when write_nextaddr_r = read_addr_clkwr_r else '0';

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------

  dout  <= ram(to_integer(read_addr_r));
  full  <= full_i;
  valid <= valid_i;
end rtl;
