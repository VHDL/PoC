-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Authors:					Patrick Lehmann
--
-- Module:					CRC Generator for 1-Wire
-- 
-- Description:
-- ------------------------------------
--	TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
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

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;


entity ow_CRCGenerator is
  port (
		Clock				: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;
		CE					: in	STD_LOGIC;
		Signal_In		: in	STD_LOGIC;
		CRC_Out			: out	STD_LOGIC_VECTOR(7 downto 0)
	);
end entity;


architecture rtl of ow_CRCGenerator is
  signal Feedback		: STD_LOGIC;
  signal ShiftReg		: STD_LOGIC_VECTOR(7 downto 0);
begin
	Feedback <= Signal_In XOR ShiftReg(7);

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				ShiftReg <= (others => '0');
			else
				ShiftReg(0) <= Feedback;
				ShiftReg(1) <= ShiftReg(0);
				ShiftReg(2) <= ShiftReg(1);
				ShiftReg(3) <= ShiftReg(2);
				ShiftReg(4) <= ShiftReg(3) xor Feedback;
				ShiftReg(5) <= ShiftReg(4) xor Feedback;
				ShiftReg(6) <= ShiftReg(5);
				ShiftReg(7) <= ShiftReg(6);
			end if;
		end if;
	end process;

	CRC_Out <= ShiftReg(7) & ShiftReg(6) & ShiftReg(5) & ShiftReg(4) & ShiftReg(3) & ShiftReg(2) & ShiftReg(1) & ShiftReg(0);
end architecture;
