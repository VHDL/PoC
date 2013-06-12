--
-- Copyright (c) 2013
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
-- Entity: arith_prefix_and
-- Author(s): Thomas Preusser <thomas.preusser@tu-dresden.de>
-- 
-- Prefix AND computation:
--   y(i) <= '1' when x(i downto 0) = (i downto 0 => '1') else '0'
--
-- This implementation uses carry chains for wider implementations.
--
library IEEE;
use IEEE.std_logic_1164.all;

entity arith_prefix_and is
  generic (
    N : positive
  );
  port (
    x : in  std_logic_vector(N-1 downto 0);
    y : out std_logic_vector(N-1 downto 0)
  );
end arith_prefix_and;

library poc;
use poc.config.all;

library IEEE;
use IEEE.numeric_std.all;

architecture rtl of arith_prefix_and is
begin
  y(0) <= x(0);
  gen1: if N > 1 generate
    signal  p : unsigned(N-1 downto 1);
  begin
    p(1) <= x(0) and x(1);
    gen2: if N > 2 generate
      p(N-1 downto 2) <= unsigned(x(N-1 downto 2));

      -- Generic Carry Chain through Addition
      genGeneric: if VENDOR /= VENDOR_XILINX generate
        signal  s : std_logic_vector(N downto 1);
      begin
        s <= std_logic_vector(('0' & p) + 1);
        y(N-1 downto 2) <= s(N downto 3) xor ('0' & x(N-1 downto 3));
      end generate genGeneric;

      -- Direct Carry Chain by MUXCY Instantiation
      genXilinx: if VENDOR = VENDOR_XILINX generate
        component MUXCY
          port (
            S  : in  std_logic;
            DI : in  std_logic;
            CI : in  std_logic;
            O  : out std_logic
          );
        end component;
        signal  c : std_logic_vector(N-1 downto 0);
      begin
        c(0) <= '1';
        genChain: for i in 1 to N-1 generate
          mux : MUXCY
            port map (
              S  => p(i),
              DI => '0',
              CI => c(i-1),
              O  => c(i)
            );
        end generate genChain;
	y(N-1 downto 2) <= c(N-1 downto 2);
      end generate genXilinx;

    end generate gen2;
    y(1) <= p(1);
  end generate gen1;
end rtl;
