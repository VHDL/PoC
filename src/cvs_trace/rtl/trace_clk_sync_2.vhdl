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
-- Entity: trace_clk_sync_2
-- Author(s): Martin Zabel (re-implemenation)
-- 
-- Transmit an event to another clock-domain.
--
-- 'signal_event' must be asserted for only one 'clk_from' cycle.
-- 'event_signaled' is signaled for one 'clk_to' cycle.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trace_clk_sync_2 is
  generic (
    SYNC_STAGES : positive := 1);
  port (
    clk_from       : in  std_logic;
    clk_to         : in  std_logic;
    signal_event   : in  std_logic;
    event_signaled : out std_logic
  );
end trace_clk_sync_2;

architecture rtl of trace_clk_sync_2 is

  ----
  -- power up registers with '0'
  ----
  
  -- state inside the clk_from domain
  signal state_from_r : std_logic := '0';

  -- synchronized state inside the clk_to domain
  signal sync_state_to_r : std_logic_vector(SYNC_STAGES downto 1)
    := (others => '0');

  -- state inside the clk_to domain
  signal state_to    : std_logic;
  signal state_to_p1 : std_logic := '0';  -- delayed one cycle

begin

  -----------------------------------------------------------------------------
  -- clk_from domain
  -----------------------------------------------------------------------------

  process (clk_from)
  begin  -- process
    if rising_edge(clk_from) then
      if signal_event = '1' then
        state_from_r <= not state_from_r;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- clk_to domain
  -----------------------------------------------------------------------------

  -- synchronizing flipflops
  process (clk_to)
  begin  -- process
    if rising_edge(clk_to) then
      sync_state_to_r(1) <= state_from_r;  -- asynchronous!

      if SYNC_STAGES > 1 then
        sync_state_to_r(SYNC_STAGES downto 2) <=
          sync_state_to_r(SYNC_STAGES-1 downto 1);
      end if;
    end if;
  end process;

  state_to <= sync_state_to_r(SYNC_STAGES);
  
  -- edge detection
  process (clk_to)
  begin  -- process
    if rising_edge(clk_to) then
      -- delay one clock cylce
      state_to_p1 <= state_to;
    end if;
  end process;

  event_signaled <= state_to xor state_to_p1;
end rtl; 
