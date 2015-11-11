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
-- Entity: trace_statistic
-- Author(s): Stefan Alex, Martin Zabel
-- 
-- Event counter.
--
-- Reset and increment can be asserted at the same time. This counts as 1
-- event.
--
-- Current counter state is written out:
-- a) if maximum value is reached and an incoming event should be counted, or
-- b) if counter is resetted.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2010-04-30 07:21:35 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trace_statistic is
  generic (
    COUNTER_BITS : positive
  );
  port (
    clk_trc : in std_logic;
    rst_trc : in std_logic;

    -- inputs
    inc : in std_logic;
    rst : in std_logic;

    -- Data-Fifo
    counter_value : out std_logic_vector(COUNTER_BITS-1 downto 0);
    counter_stb   : out std_logic
  );
end trace_statistic;

architecture Behavioral of trace_statistic is

  signal counter_r     : unsigned(COUNTER_BITS-1 downto 0);
  signal counter_init  : unsigned(COUNTER_BITS-1 downto 0);
  signal counter_ov    : std_logic;
  signal counter_stb_i : std_logic;
begin


  -- Outputs
  -- For counter_stb see documentation in file header.

  counter_value <= std_logic_vector(counter_r);
  counter_ov    <= '1' when counter_r = (COUNTER_BITS-1 downto 0 => '1') else '0';
  counter_stb_i <= (counter_ov and inc) or rst;
  counter_stb   <= counter_stb_i;
  
  -- Intial value upon reset. Separate signal for correct counter-macro
  -- inference.
  g1: if COUNTER_BITS>1 generate
    counter_init(COUNTER_BITS-1 downto 1) <= (others => '0');
  end generate g1;
  counter_init(0) <= (not rst_trc) and inc;

  clk_proc : process(clk_trc)
  begin
    if rising_edge(clk_trc) then
      if (rst_trc or counter_stb_i) = '1' then
        -- Requires initialization with 1 on overflow!
        counter_r <= counter_init;
      elsif inc = '1' then
        counter_r <= counter_r + 1;
      end if;
    end if;
  end process clk_proc;

end Behavioral;
