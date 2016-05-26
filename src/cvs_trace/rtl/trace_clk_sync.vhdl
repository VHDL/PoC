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
-- Entity: trace_clk_sync
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- Bring a signal to another clock-domain.          --
-- The component instantiates a register-chain      --
-- for synchronization.                             --
------------------------------------------------------
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-03-29 15:44:33 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trace_clk_sync is
  port (
    clk_dst   : in  std_logic;
    value_in  : in  std_logic;
    value_out : out std_logic
  );
end trace_clk_sync;

architecture rtl of trace_clk_sync is
  signal value_delay_1 : std_logic := '0';
  signal value_delay_2 : std_logic := '0';
begin

  clk_dst_proc : process(clk_dst)
  begin
    if rising_edge(clk_dst) then
      value_delay_1 <= value_in;
      value_delay_2 <= value_delay_1;
    end if;
  end process clk_dst_proc;

  value_out <= value_delay_2;

end rtl;
