-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Martin Zabel
--                  Patrick Lehmann
-- 
-- Module:					Sub-module for Vivado synthesis check.
--
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

library ieee;
use ieee.std_logic_1164.all;

library poc;
use poc.physical.all;

entity shift_reg is
  
  generic (
    STAGES	 : integer;
    CLOCK_FREQ   : freq;
    DELAY_TIME   : time;
    CLOCK_PERIOD : time;
    RES_REAL     : real;
    RES_NAT      : natural;
    TIME_1_FS    : time;
    TIME_1_PS    : time;
    TIME_1_NS    : time;
    TIME_1_US    : time;
    TIME_1_MS    : time;
    TIME_1_S     : time;
    TIME_1_MIN   : time;
    TIME_1_HR    : time);

  port (
    clk : in  std_logic;
    d	: in  std_logic;
    q	: out std_logic);

end entity shift_reg;

architecture rtl of shift_reg is

begin  -- architecture rtl

	g0: if STAGES = 0 generate
		q <= d;
	end generate g0;

	g1: if STAGES > 0 generate
		signal reg : std_logic_vector(STAGES downto 1);
	begin
		reg <= reg(STAGES-1 downto 1) & d when rising_edge(clk);
		q   <= reg(STAGES);
	end generate g1;
  


end architecture rtl;
