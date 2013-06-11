--
-- Copyright (c) 2008
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
-- Entity: fifo_cc_got_tempgot
-- Author(s): Martin Zabel
-- 
-- A typical fifo_cc_got with temporary got.
--
-- Data is read by the got-interface as normal. But in addition, a marker can
-- be set with 'store' at the current read position. With 'load', you can
-- return to the last "stored" read position.
--
-- Please note, that data is not removed from the FIFO until 'store' is issued.
-- The data is required in the case that 'load' is called.
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2009-01-09 15:50:08 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;
use poc.ocram.all;

entity fifo_cc_got_tempgot is
  
  generic (
    D_BITS    : positive := 8;
    MIN_DEPTH : positive := 4;
    FSTATE_BITS : positive := 1;
    CHECK     : boolean  := true);      -- Check Puts / Gots on Validity

  port (
    clk : in std_logic;
    rst : in std_logic;

    -- Write Interface
    put  : in  std_logic;
    din  : in  std_logic_vector(D_BITS-1 downto 0);
    full : out std_logic;
    fstate : out unsigned(FSTATE_BITS-1 downto 0);

    -- Read Interface
    got   : in  std_logic;
    valid : out std_logic;
    dout  : out std_logic_vector(D_BITS-1 downto 0);

    -- Temporary got control
    store : in std_logic;
    load  : in std_logic);

end fifo_cc_got_tempgot;

architecture rtl of fifo_cc_got_tempgot is
  constant A_BITS     : positive := log2ceil(MIN_DEPTH+1);
  constant REAL_DEPTH : positive := 2**A_BITS;

  -- internal standard FIFO
  signal int_put    : std_logic;
  signal int_get    : std_logic;
  signal int_full   : std_logic;
  signal int_empty  : std_logic;
  signal int_din    : std_logic_vector(D_BITS-1 downto 0);
  signal int_dout   : std_logic_vector(D_BITS-1 downto 0);
  signal write_addr : unsigned(A_BITS-1 downto 0);
  signal read_addr  : unsigned(A_BITS-1 downto 0);
  signal next_write_addr : unsigned(A_BITS-1 downto 0);

  -- fill state specific
  signal ptrDiff : unsigned(A_BITS-1 downto 0);
  
  -- Temporary state
  signal temp_read_addr : unsigned(A_BITS-1 downto 0);
  
  -- FWFT control
  signal do_put : std_logic;
  signal do_got : std_logic;

  signal lastempty : std_logic;
  signal lastload  : std_logic;
  signal valid_reg : std_logic;
  signal clr_valid : std_logic;
  signal set_valid : std_logic;
  
begin  -- rtl

  -- Validity check
  do_put <= put and (not int_full) when CHECK else put;
  do_got <= got and valid_reg      when CHECK else got;

  -----------------------------------------------------------------------------
  -- FWFT Control

  int_din <= din;
  int_put <= do_put;
  full    <= int_full;

  -- After getting the first entry, the internal FIFO would be empty again (->
  -- lastempty = '1'). Thus, we must prohibit another 'get' if there is already
  -- a valid value (valid_reg = '1') in the output register int_dout.
  -- After a 'load' operation, the temp_read_addr is resetted to read_addr.
  -- After this, the current value must be re-get from the FIFO.
  int_get <= ((not int_empty) and ((lastempty and not valid_reg) or do_got)) or
             lastload;

  dout  <= int_dout;
  valid <= valid_reg;

  set_valid <= (lastempty or lastload) and (not int_empty);
  clr_valid <= (do_got and int_empty) or load;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        lastempty <= '0';               -- prohibit 'get' in next cycle
        lastload  <= '0';
      else
        lastempty <= int_empty;
        lastload  <= load;
      end if;

      if (clr_valid or rst) = '1' then
        valid_reg <= '0';
      elsif set_valid = '1' then
        valid_reg <= '1';
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Internal standard FIFO

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if rst = '1' then
        read_addr <= (others => '0');
      elsif store= '1' then
        if valid_reg = '1' then
          -- read is already one element ahead
          read_addr <= temp_read_addr - 1;
        else
          read_addr <= temp_read_addr;
        end if;
      end if;

      if rst = '1' then
        temp_read_addr <= (others => '0');
      elsif int_get = '1' then
        temp_read_addr <= temp_read_addr + 1;
      elsif load = '1' then
        temp_read_addr <= read_addr;
      end if;

      if rst = '1' then
        write_addr <= (others => '0');
      elsif int_put = '1' then
        write_addr <= next_write_addr;
      end if;
      
    end if;
  end process;

  next_write_addr <= write_addr + 1;
  
  -- 'int_empty' can be combinatorial because it is registered in this
  -- component again, not influencing outer combinatorial paths
  int_empty <= '1' when write_addr = temp_read_addr else '0';

  -- 'int_full' is directly connected to the output 'full', leading to a
  -- long clock-to-output delay. TODO: Can this be improved?
  int_full  <= '1' when next_write_addr = read_addr else '0';

  -- fstate denotes the real state (and not the temporary state) of the FIFO.
  ptrDiff <= write_addr - read_addr;
  fstate <= ptrDiff(A_BITS-1 downto A_BITS-FSTATE_BITS);
  
  ram : ocram_sdp
    generic map (
        A_BITS => A_BITS,
        D_BITS => D_BITS)
    port map (
        rclk => clk,
        rce  => int_get,
        wclk => clk,
        wce  => '1',
        we   => int_put,
        ra   => temp_read_addr,
        wa   => write_addr,
        d    => int_din,
        q    => int_dout);

end rtl;
