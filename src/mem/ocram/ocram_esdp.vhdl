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
-- Entity: ocram_esdp
-- Author(s): Martin Zabel
-- 
-- Inferring / instantiating simple dual-port memory.
--
-- - dual clock, clock enable
-- - 1 read/write port (1st port) plus 1 read port (2nd port)
-- 
-- Reading from 2nd port at write address returns unknown data.
-- Putting the different RAM
-- behaviours (Altera, Xilinx, some ASICs) together, then the Altera M512/M4K
-- TriMatrix memory defines the minimum time after which the written data can
-- be read out again. As stated in the Stratix Handbook, Volum2, page 2-13, the
-- data is actually written with the falling (instead of the rising) edge of
-- the clock. So that data can be read out after half of the write-clock period
-- plus the write-cycle time.
--
-- To generalize this behaviour, it can be assumed, that written data is 
-- available at the read-port with the next rising write!-clock edge. Both,
-- read- and write-clock edge might be at the same time, to satisfy this rule.
-- An example would be, that write- and read-clock are the same.
--
-- Written data is passed through the memory and output again as read-data on
-- 1st port 'q1' only! This is the normal behaviour for the same port and also
-- known as write-first mode or read-through-write behaviour.
--
-- If latency is an issue, then memory blocks should be directly instantiated.
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2012-07-31 11:39:28 $
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.config.all;

entity ocram_esdp is
  
  generic (
    A_BITS : positive;-- := 10;
    D_BITS : positive--  := 32
  );

  port (
    clk1 : in  std_logic;
    clk2 : in  std_logic;
    ce1  : in  std_logic;
    ce2  : in  std_logic;
    we1  : in  std_logic;
    a1   : in  unsigned(A_BITS-1 downto 0);
    a2   : in  unsigned(A_BITS-1 downto 0);
    d1   : in  std_logic_vector(D_BITS-1 downto 0);
    q1   : out std_logic_vector(D_BITS-1 downto 0);
    q2   : out std_logic_vector(D_BITS-1 downto 0)
  );

end ocram_esdp;

architecture rtl of ocram_esdp is

  component ocram_esdp_altera
    generic (
      A_BITS : positive;
      D_BITS : positive);
    port (
      clk1 : in  std_logic;
      clk2 : in  std_logic;
      ce1  : in  std_logic;
      ce2  : in  std_logic;
      we1  : in  std_logic;
      a1   : in  unsigned(A_BITS-1 downto 0);
      a2   : in  unsigned(A_BITS-1 downto 0);
      d1   : in  std_logic_vector(D_BITS-1 downto 0);
      q1   : out std_logic_vector(D_BITS-1 downto 0);
      q2   : out std_logic_vector(D_BITS-1 downto 0));
  end component;
  
  constant DEPTH : positive := 2**A_BITS;
  
begin  -- rtl

  gInfer: if VENDOR = VENDOR_XILINX generate
    -- RAM can be infered correctly
    -- XST Advanced HDL Synthesis generates extended simple dual-port
    -- memory as expected.
    type ram_t is array(0 to DEPTH-1) of std_logic_vector(D_BITS-1 downto 0);
    signal ram : ram_t;

    signal a1_reg : unsigned(A_BITS-1 downto 0);
    signal a2_reg : unsigned(A_BITS-1 downto 0);
  
  begin
    process (clk1)
    begin
      if rising_edge(clk1) then
        if ce1 = '1' then
          if we1 = '1' then
            ram(to_integer(a1)) <= d1;
          end if;

          a1_reg <= a1;
        end if;
      end if;
    end process;

    q1 <= ram(to_integer(a1_reg));        -- gets new data

    process (clk2)
    begin  -- process
      if rising_edge(clk2) then
        if ce2 = '1' then
          a2_reg <= a2;
        end if;
      end if;
    end process;
    
    -- read data is unknown, when reading at write address
    q2 <= ram(to_integer(a2_reg));
    
  end generate gInfer;

  gAltera: if VENDOR = VENDOR_ALTERA generate
    -- Direct instantiation of altsyncram (including component
    -- declaration above) is not sufficient for ModelSim.
    -- That requires also usage of altera_mf library.
    i: ocram_esdp_altera
      generic map (
        A_BITS => A_BITS,
        D_BITS => D_BITS)
      port map (
        clk1 => clk1,
        clk2 => clk2,
        ce1  => ce1,
        ce2  => ce2,
        we1  => we1,
        a1   => a1,
        a2   => a2,
        d1   => d1,
        q1   => q1,
        q2   => q2);
    
  end generate gAltera;
  
  assert VENDOR = VENDOR_XILINX or VENDOR = VENDOR_ALTERA
    report "Device not yet supported."
    severity failure;
end rtl;
