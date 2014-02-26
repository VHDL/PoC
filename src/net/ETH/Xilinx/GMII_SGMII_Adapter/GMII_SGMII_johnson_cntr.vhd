--------------------------------------------------------------------------------
-- File       : GMII_SGMII_johnson_cntr.vhd
-- Author     : Xilinx Inc.
--------------------------------------------------------------------------------
-- (c) Copyright 2004-2008 Xilinx, Inc. All rights reserved.
--
-- 
--------------------------------------------------------------------------------
-- Description:  This logic describes a standard johnson counter to
--               create divided down clocks.  A divide by 10 clock is
--               created.
--
--               The capabilities of this Johnson counter are extended
--               with the use of the clock enables - it is only the
--               clock-enabled cycles which are divided down.
--
--               The divide by 10 clock is output directly from a rising
--               edge triggered flip-flop (clocked on the input clk).


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity GMII_SGMII_johnson_cntr is
  port (
    reset             : in  std_logic;      -- Synchronous Reset
    clk               : in  std_logic;      -- Input clock
    clk_en            : in std_logic;       -- Clock enable for rising edge triggered flip flops
    clk_div10         : out std_logic       -- (Clock, gated with clock enable) divide by 10
    );
end;


architecture rtl  of GMII_SGMII_johnson_cntr is
  signal reg1         : std_logic;          -- first flip flop
  signal reg2         : std_logic;          -- second flip flop
  signal reg3         : std_logic;          -- third flip flop
  signal reg4         : std_logic;          -- fourth flip flop
  signal reg5         : std_logic;          -- fifth flip flop

begin
  -- Create a 5-stage shift register
  reg_gen: process (clk)
  begin
    if clk'event and clk = '1' then
      if reset = '1' then
        reg1    <= '0';
        reg2    <= '0';
        reg3    <= '0';
        reg4    <= '0';
        reg5    <= '0';
      elsif clk_en = '1' then
         if reg5 = '1' and reg4 = '0' then  -- ensure that LFSR self corrects on every repetition
           reg1    <= '0';
           reg2    <= '0';
           reg3    <= '0';
           reg4    <= '0';
           reg5    <= '0';
         else
           reg1    <= not reg5;
           reg2    <= reg1;
           reg3    <= reg2;
           reg4    <= reg3;
           reg5    <= reg4;
         end if;
      end if;
    end if;
  end process reg_gen;

  -- The 5-stage shift register causes reg3 to toggle every 5 clock
  -- enabled cycles, effectively creating a divide by 10 clock
  clk_div10 <= reg3;
end;

