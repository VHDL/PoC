-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors: Thomas B. Preußer
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--                     Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--              http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;

entity ml605_idle is
  generic (
    CLK_FREQ_MHZ : real := 200.0
  );
  port (
    sysclk_p  : in  std_logic;
    sysclk_n  : in  std_logic;
    cpu_reset : in  std_logic;

    fan_tacho : in  std_logic;
    fan_pwm   : out std_logic
  );
end ml605_idle;


library PoC;
use PoC.io.io_FanControl;

library unisim;
use unisim.vcomponents.all;

architecture rtl of ml605_idle is

  signal clk   : std_logic;
  signal rst   : std_logic;
  signal rst_r : std_logic_vector(5 downto 0) := (others => '1');

begin

  -- Clock Net Feed
  buf : IBUFGDS
    port map(
      O  => clk,
      I  => sysclk_p,
      IB => sysclk_n
   );

  -- Synchronization of Reset
  process(cpu_reset, clk)
  begin
    if cpu_reset = '0' then
      rst_r <= (others => '1');
    elsif rising_edge(clk) then
      rst_r <= rst_r(rst_r'left-1 downto 0) & '0';
    end if;
  end process;
  rst <= rst_r(rst_r'left);

  fan: io_FanControl
    generic map (
      CLOCK_FREQ_MHZ => CLK_FREQ_MHZ
    )
    port map (
      Clock          => clk,
      Reset          => rst,
      Fan_PWM        => fan_pwm,
      Fan_Tacho      => fan_tacho,
      TachoFrequency => open
    );

end rtl;
