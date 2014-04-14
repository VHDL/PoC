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
-- Entity: ocram_sp
-- Author(s): Martin Zabel
-- 
-- Inferring / instantiating single-port RAM
--
-- - single clock, clock enable
-- - 1 read/write port
-- 
-- Written data is passed through the memory and output again as read-data 'q'.
-- This is the normal behaviour of a single-port RAM and also known as
-- write-first mode or read-through-write behaviour.
--
-- Revision:    $Revision: 1.4 $
-- Last change: $Date: 2012-07-31 11:34:11 $

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.config.all;

entity ocram_sp is
  
  generic (
    A_BITS : positive;-- := 10;
    D_BITS : positive--  := 32
  );

  port (
    clk : in  std_logic;
    ce  : in  std_logic;
    we  : in  std_logic;
    a   : in  unsigned(A_BITS-1 downto 0);
    d   : in  std_logic_vector(D_BITS-1 downto 0);
    q   : out std_logic_vector(D_BITS-1 downto 0)
  );

end ocram_sp;

architecture rtl of ocram_sp is
  
  component ocram_sp_altera
    generic (
      A_BITS : positive;
      D_BITS : positive);
    port (
      clk : in  std_logic;
      ce  : in  std_logic;
      we  : in  std_logic;
      a   : in  unsigned(A_BITS-1 downto 0);
      d   : in  std_logic_vector(D_BITS-1 downto 0);
      q   : out std_logic_vector(D_BITS-1 downto 0));
  end component;

  constant DEPTH : positive := 2**A_BITS;

begin  -- rtl

  gInfer: if VENDOR = VENDOR_XILINX generate
    -- RAM can be infered correctly
    -- XST Advanced HDL Synthesis generates single-port memory as expected.
    type ram_t is array(0 to DEPTH-1) of std_logic_vector(D_BITS-1 downto 0);
    signal ram : ram_t;

    signal a_reg : unsigned(A_BITS-1 downto 0);
  
  begin
    process (clk)
    begin
      if rising_edge(clk) then
        if ce = '1' then
          if we = '1' then
            ram(to_integer(a)) <= d;
          end if;

          a_reg <= a;
        end if;
      end if;
    end process;

    q <= ram(to_integer(a_reg));          -- gets new data
  end generate gInfer;

  gAltera: if VENDOR = VENDOR_ALTERA generate
    -- Direct instantiation of altsyncram (including component
    -- declaration above) is not sufficient for ModelSim.
    -- That requires also usage of altera_mf library.
    i: ocram_sp_altera
      generic map (
        A_BITS => A_BITS,
        D_BITS => D_BITS)
      port map (
        clk => clk,
        ce  => ce,
        we  => we,
        a   => a,
        d   => d,
        q   => q);
    
  end generate gAltera;
  
  assert VENDOR = VENDOR_XILINX or VENDOR = VENDOR_ALTERA
    report "Device not yet supported."
    severity failure;
end rtl;
