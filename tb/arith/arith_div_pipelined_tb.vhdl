-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 
-- Testbench:				Pipelined division module
-- 
-- Description:
-- ------------------------------------
--		Automated testbench for PoC.arith.div_pipelined
--
-- License:
-- =============================================================================
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
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.simulation.all;


entity arith_div_pipelined_tb IS
end;


architecture test OF arith_div_pipelined_tb IS
	constant CLOCK_PERIOD_100MHZ			: TIME															:= 10.0 ns;

	signal SimStop			: std_logic := '0';

	signal Clock				: STD_LOGIC			:= '1';
	signal Reset				: STD_LOGIC			:= '0';

	constant DIVIDEND_BITS	: POSITIVE	:= 8;
	constant DIVISOR_BITS		: POSITIVE	:= 4;
	
	signal Enable				: STD_LOGIC			:= '0';
	signal Dividend			: STD_LOGIC_VECTOR(DIVIDEND_BITS - 1 downto 0);
	signal Divisor			: STD_LOGIC_VECTOR(DIVISOR_BITS - 1 downto 0);
	
begin

	Clock <= Clock xnor SimStop after CLOCK_PERIOD_100MHZ / 2.0;

	div : entity PoC.arith_div_pipelined
		generic map (
			DIVIDEND_BITS		=> DIVIDEND_BITS,
			DIVISOR_BITS		=> DIVISOR_BITS--,
--			RADIX						=> 2
		)
		port map (
			Clock			=> Clock,						
			Reset			=> Reset,

			Enable		=> Enable,
			Dividend	=> Dividend,
			Divisor		=> Divisor,
			
			Quotient	=> open,
			Valid			=> open
		);
	
	process
	begin
		wait until falling_edge(Clock);
		
		Reset						<= '1';
		wait until falling_edge(Clock);
	
		Reset						<= '0';
		wait until falling_edge(Clock);

		for i in 0 to 255 loop
			Enable			<= '1';
			for j in 1 to 15 loop
				Dividend	<= to_slv(i, 8);
				Divisor		<= to_slv(j, 4);
				wait until falling_edge(Clock);
			end loop;
			
			Enable			<= '0';
			Dividend		<= (others => 'U');
			Divisor			<= (others => 'U');
			for k in 0 to 7 loop
				wait until falling_edge(Clock);
			end loop;
		end loop;
		
		-- Report overall simulation result
		tbPrintResult;
		SimStop	<= '1';
		wait;
	end process;


end architecture;
