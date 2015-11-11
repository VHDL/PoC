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
-- Entity: reset_sync
-- Author(s): Martin Zabel
-- 
-- Reset synchronizer for multiple clock domains with synchronous resets.
-- - Each reset output is synchronous to its associated clock.
-- - Resets are asserted and removed synchronously.
-- - Reset removal is not coordinated. Resets are removed at nearly the same
--   time, depending on the clock speeds.
-- - The number of clocks is configurable by generic N.
--
-- Input/Output Signals:
--
-- - rst_a: Asynchronous reset input. Asserted by push buttons, PLL lock
--          outputs (negated), etc.
--
-- - clk  : Vector of clocks. The slowest clcok must be assigned to clk(0).
--
-- - rst_s: Synchronized resets. rst_s(i) applies to clk(i).
--
-- Application Example: Just copy and uncomment.
--
--  -- Equation for asynchronous reset input, e.g. low-active reset-button and
--  -- PLL lock.
--  rst_a <= (not btn_reset_n) and (not pll_lock);
--
--  my_reset_sync: reset_sync
--    generic map (
--      N => 3)
--    port map (
--      rst_a    => rst_a,
--      clk(0)   => clk_lcd,
--      clk(1)   => clk_eth,
--      clk(2)   => clk_dsp,
--      rst_s(0) => rst_lcd,
--      rst_s(1) => rst_eth,
--      rst_s(2) => rst_dsp);
--
-- END OF EXAMPLE
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-09-09 14:01:28 $
--


library ieee;
use ieee.std_logic_1164.all;

entity reset_sync is
  
  generic (
    N : positive := 3);

  port (
    rst_a : in  std_logic;
    clk   : in  std_logic_vector(N-1 downto 0);
    rst_s : out std_logic_vector(N-1 downto 0));

end reset_sync;

architecture rtl of reset_sync is

begin  -- rtl

  -----------------------------------------------------------------------------
  -- Single Clock
  --
  -- Just synchronize reset like any other asynchronous signal.
  -----------------------------------------------------------------------------
  g1: if N = 1 generate
    signal rst_r : std_logic_vector(1 downto 0) := (others => '0');
  begin

    process (clk(0))
    begin  -- process
      if rising_edge(clk(0)) then
        rst_r <= rst_r(rst_r'left-1 downto 0) & rst_a;
      end if;
    end process;

    rst_s(0) <= rst_r(rst_r'left);
  end generate g1;

  -----------------------------------------------------------------------------
  -- Multiple Clocks
  --
  -- 1. Stretch reset impulse, so that all resets (outputs) overlap.
  -- 2. Synchronize stretched reset with all clock domains.
  -----------------------------------------------------------------------------

  gM: if N > 1 generate
    signal stretched_r   : std_logic_vector(2 downto 0) := (others => '0');
    signal stretched_rst : std_logic;
    signal slow_clk      : std_logic;

  begin

    -- Seperate assignment required for ISim.
    slow_clk <= clk(0);
    
    -- Use slowest clock for impulse stretching.
    process (slow_clk)
    begin  -- process
      if rising_edge(slow_clk) then
        stretched_r <= stretched_r(stretched_r'left-1 downto 0) & rst_a;
      end if;
    end process;

    stretched_rst <= '1' when stretched_r /= (stretched_r'range => '0') else
                     '0';

    -- Synchronize to individual clock domains
    s: for i in 0 to N-1 generate
      signal rst_r : std_logic_vector(1 downto 0) := (others => '0');
      signal my_clk : std_logic;
    begin
      -- Seperate assignment required for ISim.
      my_clk <= clk(i);
      
      process (my_clk)
      begin  -- process
        if rising_edge(my_clk) then
          rst_r <= rst_r(rst_r'left-1 downto 0) & stretched_rst;
        end if;
      end process;

      rst_s(i) <= rst_r(rst_r'left);
    end generate s;
  end generate gM;
end rtl;
