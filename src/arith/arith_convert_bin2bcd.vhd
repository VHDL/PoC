-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					Converter binary numbers to BCD encoded numbers.
--
-- Description:
-- ------------------------------------
--		TODO
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
use			IEEE.STD_LOGIC_1164.ALL;
use			IEEE.NUMERIC_STD.ALL;

library	PoC;
use			PoC.utils.all;
use			PoC.components.all;


entity arith_convert_bin2bcd is
	generic (
		IS_SIGNED			: BOOLEAN			:= FALSE;
		BITS					: POSITIVE		:= 8;
		DIGITS				: POSITIVE		:= 3
	);
	port (
		Clock					: IN	STD_LOGIC;
		Reset					: IN	STD_LOGIC;
		
		Start					: IN	STD_LOGIC;
		Busy					: OUT	STD_LOGIC;
		
		Binary				:	IN	STD_LOGIC_VECTOR(BITS - 1 DOWNTO 0);
		BCDDigits			: OUT	T_BCD_VECTOR(DIGITS - 1 DOWNTO 0);
		Sign					: OUT STD_LOGIC
	);
end;


architecture rtl of arith_convert_bin2bcd is
	type T_STATE is (ST_IDLE, ST_neg, ST_CONVERT);
	
	signal State						: T_STATE		:= ST_IDLE;
	signal NextState				: T_STATE;
	
	signal Digit_Shift_rst	: STD_LOGIC;
	signal Digit_Shift_en		: STD_LOGIC;
	signal Digit_Shift_in		: STD_LOGIC_VECTOR(DIGITS downto 0);
	
	signal Binary_en				: STD_LOGIC;
	signal Binary_neg				: STD_LOGIC;
	signal Binary_rl				: STD_LOGIC;
	signal Binary_d					: STD_LOGIC_VECTOR(BITS - 1 downto 0)			:= (others => '0');
	signal Binary_Sign			: STD_LOGIC;
	
	signal Sign_d						: STD_LOGIC																:= '0';
	
	signal ShiftCounter_rst	: STD_LOGIC;
	signal ShiftCounter_eq	: STD_LOGIC;
	signal ShiftCounter_s		: SIGNED(log2ceilnz(BITS - 1) downto 0)		:= (others => '0');

begin
	Binary_Sign				<= Binary(Binary'high);

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State		<= ST_IDLE;
			else
				State		<= NextState;
			end if;
		end if;
	end process;

	process(State, Start, Binary_Sign, ShiftCounter_eq)
	begin
		NextState					<= State;
		Busy							<= '0';
		
		Binary_en					<= '0';
		Binary_neg				<= '0';
		Binary_rl					<= '0';
		Digit_Shift_rst		<= '0';
		Digit_Shift_en		<= '0';
		ShiftCounter_rst	<= '1';
		
	  case State is
			when ST_IDLE =>
				if (Start = '1') then
					Binary_en				<= '1';
					Digit_Shift_rst	<= '1';
				
					if (IS_SIGNED and (Binary_Sign = '1')) then
						NextState			<= ST_neg;
					else
						NextState			<= ST_CONVERT;
					end if;
				end if;
			
			when ST_neg =>
				Busy							<= '1';
				Binary_neg				<= '1';
				NextState					<= ST_CONVERT;
				
			when ST_CONVERT =>
				Busy							<= '1';
				Binary_rl					<= '1';
				Digit_Shift_en		<= '1';
				ShiftCounter_rst	<= '0';
				
				if (ShiftCounter_eq = '1') then
					NextState				<= ST_IDLE;
				end if;
			
		end case;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Binary_d	<= (others => '0');
			elsif (Binary_en = '1') then
				Binary_d	<= Binary;
				Sign_d		<= '0';
			elsif (Binary_neg = '1') then
				Binary_d	<= neg(Binary_d);		-- 2's component
				Sign_d		<= '1';
			elsif (Binary_rl = '1') then
				Binary_d	<= Binary_d(Binary_d'high - 1 downto 0) & Binary_d(Binary_d'high);
			end if;
		end if;
	end process;
	
	Sign							<= Sign_d;
	Digit_Shift_in(0)	<= Binary_d(Binary_d'high);
	
	-- count shift operations from BITS-2 downto -1
	ShiftCounter_s		<= counter_dec(ShiftCounter_s, ShiftCounter_rst, '1', BITS - 2) when rising_edge(Clock);
	ShiftCounter_eq		<= ShiftCounter_s(ShiftCounter_s'high);
	
	-- generate DIGITS many systolic elements
	genDigits : for i in 0 to DIGITS - 1 generate
		signal Digit_ext	: UNSIGNED(T_BCD'length downto 0);
		signal Digit_ov		: STD_LOGIC;
		signal Digit_d		: T_BCD				:= "0000";
	begin
		Digit_ext							<= Digit_d & Digit_Shift_in(i);
		Digit_ov							<= to_sl(Digit_ext > 9);
		Digit_Shift_in(i + 1)	<= Digit_ov;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if (Digit_Shift_rst = '1') then
					Digit_d		<= "0000";
				elsif (Digit_Shift_en = '1') then
					if (Digit_ov = '0') then
						Digit_d	<= Digit_ext(Digit_d'range);
					else
						Digit_d	<= resize(Digit_ext - 10, Digit_d'length);
					end if;
				end if;
			end if;
		end process;
		
		BCDDigits(i)	<= Digit_d;
	end generate;
end;
