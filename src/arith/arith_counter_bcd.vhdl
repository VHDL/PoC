-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	BCD counter.
--
-- Authors:				 	Martin Zabel
--									Thomas B. Preusser
-- 
-- Description:
-- ------------------------------------
-- Counter with output in binary coded decimal (BCD).
-- The number of BCD digits is configurable.
--
-- All control signals (reset 'rst', increment 'inc') are high-active and
-- synchronous to clock 'clk'.
-- The output 'val' is the current counter state. Groups of 4 bit represent one
-- BCD digit. The lowest significant digit is specified by val(3 downto 0).
-- 
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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

library	ieee;
use			ieee.std_logic_1164.all;
use			ieee.numeric_std.all;

library poc;
use poc.utils.all;

entity arith_counter_bcd is
	generic (
		DIGITS : positive														-- Number of BCD digits
	);
	port (
		clk : in	std_logic;
		rst : in	std_logic;												-- Reset to 0
		inc : in	std_logic;												-- Increment
		val : out T_BCD_VECTOR(DIGITS-1 downto 0) 	-- Value output
	);
end arith_counter_bcd;


architecture rtl of arith_counter_bcd is
	-- carry(i) = carry-in of stage 'i' and carry-out of stage 'i-1'
	signal carry : std_logic_vector(DIGITS downto 0);
	
begin
	carry(0) <= '1';

	-- Generate for each BCD stage
	gDigit : for i in 0 to DIGITS-1 generate
		signal cnt_r		: unsigned(3 downto 0) := x"0";	 -- Counter of stage
		signal cnt_done : std_logic;						 -- reached last digit
		
	begin
		cnt_done	 <= '1' when cnt_r = x"9" else '0';
		val(i)		 <= T_BCD(cnt_r);							 -- map to output
		carry(i+1) <= cnt_done and carry(i);		 -- carry-out of our stage
		
		process(clk)
		begin
			if(rising_edge(clk)) then
				if rst = '1' then
					cnt_r <= (others => '0');
				elsif (inc and carry(i)) = '1' then  -- short critical path for 'inc'
					if cnt_done = '1' then -- our counter reached last digit
						cnt_r <= x"0";
					else
						cnt_r <= cnt_r + 1;
					end if;
				end if;
			end if;
		end process;
	end generate gDigit;
end rtl;
