-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 
-- Testbench:				pipelined division
-- 
-- Description:
-- ------------------------------------
--	This file hosts two entities:
--	- arith_div_pipelined	is the top-level module
--	- arith_div_element		is the module used for recursive instantiation
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library PoC;
use 		PoC.utils.all;
use			PoC.components.all;


entity arith_div_pipelined is
	generic (
		DIVIDEND_BITS		: POSITIVE	:= 32;
		DIVISOR_BITS		: POSITIVE	:= 32;
		RADIX						: POSITIVE	:= 16
	);
	port (
		Clock					: in	STD_LOGIC;
		Reset					: in	STD_LOGIC;
		Enable				: in	STD_LOGIC;
		Dividend			: in	STD_LOGIC_VECTOR(DIVIDEND_BITS - 1 downto 0);
		Divisor				: in	STD_LOGIC_VECTOR(DIVISOR_BITS - 1 downto 0);
		Quotient			: out	STD_LOGIC_VECTOR(DIVIDEND_BITS - 1 downto 0);
		Valid					: out STD_LOGIC
	);
end entity;


library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library PoC;
use 		PoC.utils.all;
use			PoC.components.all;


entity arith_div_element is
	generic (
		DIVIDEND_BITS		: POSITIVE;
		DIVISOR_BITS		: POSITIVE;
		QUOTIENT_BITS		: POSITIVE;
		RADIX						: POSITIVE
	);
	port (
		Clock					: in	STD_LOGIC;
		Reset					: in	STD_LOGIC;
		Enable				: in	STD_LOGIC;
		Dividend			: in	UNSIGNED(DIVIDEND_BITS - 1 downto 0);
		Divisor				: in	UNSIGNED(DIVISOR_BITS - 1 downto 0);
		RemainerIn		: in	UNSIGNED(DIVISOR_BITS - 1 downto 0);
		
		Quotient			: out	UNSIGNED(DIVIDEND_BITS - 1 downto 0);
		Valid					: out	STD_LOGIC
	);
end entity;


architecture rtl of arith_div_pipelined is
	signal Dividend_us	: UNSIGNED(Dividend'range);
	signal Divisor_us		: UNSIGNED(Divisor'range);
	signal Quotient_us	: UNSIGNED(Quotient'range);
	signal Valid_i			: STD_LOGIC;
	
	signal Quotient_d		: STD_LOGIC_VECTOR(Quotient'range)		:= (others => '0');
	signal Valid_d			: STD_LOGIC														:= '0';
begin

	Dividend_us		<= unsigned(Dividend);
	Divisor_us		<= unsigned(Divisor);

	elem : entity PoC.arith_div_element
		generic map (
			DIVIDEND_BITS		=> DIVIDEND_BITS,
			DIVISOR_BITS		=> DIVISOR_BITS,
			QUOTIENT_BITS		=> DIVIDEND_BITS,
			RADIX						=> RADIX
		)
		port map (
			Clock					=> Clock,
			Reset					=> Reset,
			Enable				=> Enable,
			
			RemainerIn		=> (others => '0'),
			Dividend			=> Dividend_us,
			Divisor				=> Divisor_us,
			Quotient			=> Quotient_us,
			Valid					=> Valid_i
		);

	Quotient_d	<= std_logic_vector(Quotient_us)										when rising_edge(Clock);
	Valid_d			<= ffdre(q => Valid_d, d => Valid_i, rst => Reset)	when rising_edge(Clock);
	
	Quotient		<= Quotient_d;
	Valid				<= Valid_d;
end architecture;


architecture rtl of arith_div_element is
	signal Window		: UNSIGNED(RemainerIn'length downto 0);
	signal Result		: STD_LOGIC;

begin
	Window	<= RemainerIn & Dividend(Dividend'high);
	Result	<= to_sl(Window >= Divisor);

	genRecursive : if (DIVIDEND_BITS >= 2) generate
		signal NewRemainer		: UNSIGNED(Window'range);
		signal Quotient_i			: UNSIGNED(QUOTIENT_BITS - 2 downto 0);
		
		signal Enable_d				: STD_LOGIC															:= '0';
		signal NewRemainer_d	: UNSIGNED(DIVISOR_BITS - 1 downto 0)		:= (others => '0');
		signal Dividend_d			: UNSIGNED(DIVIDEND_BITS - 2 downto 0)	:= (others => '0');
		signal Divisor_d			: UNSIGNED(DIVISOR_BITS - 1 downto 0)		:= (others => '0');
		
		signal Result_d				: UNSIGNED(DIVIDEND_BITS - 2 downto 0)	:= (others => '0');
	begin
		NewRemainer	<= mux(Result, Window, Window - Divisor);
	
		genNoReg : if (DIVIDEND_BITS mod log2ceil(RADIX) /= 0) generate
			Enable_d			<= Enable;
			NewRemainer_d	<= NewRemainer(NewRemainer'high - 1 downto 0);
			Dividend_d		<= Dividend(Dividend'high - 1 downto 0);
			Divisor_d			<= Divisor;
		end generate;
		genReg : if (DIVIDEND_BITS mod log2ceil(RADIX) = 0) generate
			Enable_d			<= ffdre(q => Enable_d, d => Enable, rst => Reset)	when rising_edge(Clock);
			NewRemainer_d	<= NewRemainer(NewRemainer'high - 1 downto 0)				when rising_edge(Clock);
			Dividend_d		<= Dividend(Dividend'high - 1 downto 0)							when rising_edge(Clock);
			Divisor_d			<= Divisor																					when rising_edge(Clock);
		end generate;
	
		elem : entity PoC.arith_div_element
			generic map (
				DIVIDEND_BITS		=> DIVIDEND_BITS - 1,
				DIVISOR_BITS		=> DIVISOR_BITS,
				QUOTIENT_BITS		=> QUOTIENT_BITS - 1,
				RADIX						=> RADIX
			)
			port map (
				Clock					=> Clock,
				Reset					=> Reset,
				Enable				=> Enable_d,
				
				RemainerIn		=> NewRemainer_d,
				Dividend			=> Dividend_d,
				Divisor				=> Divisor_d,
				
				Quotient			=> Quotient_i,
				Valid					=> Valid
			);
		
		Result_d															<= Result_d(Result_d'high - 1 downto 0) & Result	when rising_edge(Clock);
		
		Quotient(Quotient'high)								<= Result_d(Result_d'high);
		Quotient(Quotient'high - 1 downto 0)	<= Quotient_i;
	end generate;
	genNoRecursive : if (DIVIDEND_BITS = 1) generate
		Quotient(0)		<= Result;
		Valid					<= Enable;
	end generate;
end architecture;
