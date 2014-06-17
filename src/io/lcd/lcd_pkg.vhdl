-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;


PACKAGE lcd IS
	SUBTYPE T_BCD						IS UNSIGNED(3 DOWNTO 0);
	TYPE		T_BCD_VECTOR		IS ARRAY (NATURAL RANGE <>)	OF T_BCD;
	
	-- define array indices
	CONSTANT MAX_LCD_COLUMN_COUNT			: POSITIVE			:= 16;
	CONSTANT MAX_LCD_ROW_COUNT				: POSITIVE			:= 2;
	
	CONSTANT T_LCD_COLUMN_INDEX_BW		: POSITIVE			:= log2ceilnz(MAX_LCD_COLUMN_COUNT);
	CONSTANT T_LCD_ROW_INDEX_BW				: POSITIVE			:= log2ceilnz(MAX_LCD_ROW_COUNT);
	
	SUBTYPE T_LCD_COLUMN_INDEX				IS INTEGER RANGE 0 TO MAX_LCD_COLUMN_COUNT - 1;
	SUBTYPE T_LCD_ROW_INDEX						IS INTEGER RANGE 0 TO MAX_LCD_ROW_COUNT - 1;

	TYPE T_LCD_CHAR IS (
		LCD_CHAR_SPACE,
		LCD_CHAR_DASH, LCD_CHAR_ASSIGN, LCD_CHAR_DOT, LCD_CHAR_CDOT, LCD_CHAR_COLON, LCD_CHAR_ARROW_R, LCD_CHAR_ARROW_L,
		LCD_CHAR_AT, LCD_CHAR_EXMARK, LCD_CHAR_QMARK, LCD_CHAR_SHARP,
		
		LCD_CHAR_0, LCD_CHAR_1, LCD_CHAR_2, LCD_CHAR_3, LCD_CHAR_4, LCD_CHAR_5, LCD_CHAR_6, LCD_CHAR_7, LCD_CHAR_8, LCD_CHAR_9,
		LCD_UCHAR_A, LCD_UCHAR_B, LCD_UCHAR_C, LCD_UCHAR_D, LCD_UCHAR_E, LCD_UCHAR_F, LCD_UCHAR_G, LCD_UCHAR_H, LCD_UCHAR_I, LCD_UCHAR_J,
		LCD_UCHAR_K, LCD_UCHAR_L, LCD_UCHAR_M, LCD_UCHAR_N, LCD_UCHAR_O, LCD_UCHAR_P, LCD_UCHAR_Q, LCD_UCHAR_R, LCD_UCHAR_S, LCD_UCHAR_T,
		LCD_UCHAR_U, LCD_UCHAR_V, LCD_UCHAR_W, LCD_UCHAR_X, LCD_UCHAR_Y, LCD_UCHAR_Z,
		
		LCD_LCHAR_a, LCD_LCHAR_b, LCD_LCHAR_c, LCD_LCHAR_d, LCD_LCHAR_e, LCD_LCHAR_f, LCD_LCHAR_g, LCD_LCHAR_h, LCD_LCHAR_i, LCD_LCHAR_j,
		LCD_LCHAR_k, LCD_LCHAR_l, LCD_LCHAR_m, LCD_LCHAR_n, LCD_LCHAR_o, LCD_LCHAR_p, LCD_LCHAR_q, LCD_LCHAR_r, LCD_LCHAR_s, LCD_LCHAR_t,
		LCD_LCHAR_u, LCD_LCHAR_v, LCD_LCHAR_w, LCD_LCHAR_x, LCD_LCHAR_y, LCD_LCHAR_z
	);

	TYPE T_LCD_CHAR_VECTOR	IS ARRAY(NATURAL RANGE <>)	OF T_LCD_CHAR;	
	
	SUBTYPE T_LCD_ROW				IS T_RAWSTRING(0 TO MAX_LCD_COLUMN_COUNT - 1);						-- don't use "IS ARRAY (T_LCD_COLUMN_INDEX)" => expression is not sliceable
	TYPE		T_LCD						IS ARRAY (T_LCD_ROW_INDEX)	OF T_LCD_ROW;

	CONSTANT LCDCMD_NONE							: T_SLV_8		:= x"00";			-- no command
	CONSTANT LCDCMD_DISPLAY_ON				: T_SLV_8		:= x"0C";			-- Display ON; cursor OFF; blink OFF
	CONSTANT LCDCMD_DISPLAY_CLEAR			: T_SLV_8		:= x"01";			-- 
	CONSTANT LCDCMD_RETURN_HOME				: T_SLV_8		:= x"02";			-- 
	CONSTANT LCDCMD_GO_HOME						: T_SLV_8		:= x"10";			-- 
	CONSTANT LCDCMD_SET_FUNCTION			: T_SLV_8		:= x"2C";			-- (4 Bit interface, 2-line, 5x8 dots)
	CONSTANT LCDCMD_ENTRY_MODE				: T_SLV_8		:= x"06";			-- entry mode: move: RIGHT; shift OFF

	PROCEDURE LCDBufferProjection(SIGNAL buffer1 : IN T_LCD_CHAR_VECTOR; SIGNAL buffer2 : OUT T_LCD_CHAR_VECTOR);

	FUNCTION Bin2BCD(Sum_In : T_BCD; C_In : STD_LOGIC) RETURN UNSIGNED;

	FUNCTION calc_length(slv_length : POSITIVE) RETURN POSITIVE;

	FUNCTION to_LCD_CHAR_VECTOR(slv : STD_LOGIC_VECTOR) RETURN T_LCD_CHAR_VECTOR;
	FUNCTION to_LCD_CHAR_VECTOR(rawstr : T_RAWSTRING) RETURN T_LCD_CHAR_VECTOR;
	FUNCTION to_LCD_CHAR_VECTOR(str : STRING) RETURN T_LCD_CHAR_VECTOR;
	
	FUNCTION to_LCD_CHAR(slv : T_SLV_4) RETURN T_LCD_CHAR;
	FUNCTION to_LCD_CHAR2(rawchar : T_RAWCHAR) RETURN T_LCD_CHAR;
	FUNCTION to_LCD_CHAR(char : CHARACTER) RETURN T_LCD_CHAR;
	
	FUNCTION LCD_CHAR2Bin(char : T_LCD_CHAR) RETURN T_SLV_8;
	
	FUNCTION lcd_go_home(row_us : UNSIGNED) RETURN T_SLV_8;
	FUNCTION lcd_display_on(ShowCursor : BOOLEAN; Blink : BOOLEAN) RETURN T_SLV_8;
	
	FUNCTION ite(cond : BOOLEAN; value1 : T_LCD_CHAR; value2 : T_LCD_CHAR) RETURN T_LCD_CHAR;
	FUNCTION ite(cond : BOOLEAN; value1 : T_LCD_CHAR_VECTOR; value2 : T_LCD_CHAR_VECTOR) RETURN T_LCD_CHAR_VECTOR;

END;


PACKAGE BODY lcd IS
	FUNCTION to_char(bcd : T_BCD) RETURN CHARACTER IS
		VARIABLE temp		: T_UINT_8;
	BEGIN
		temp	:= to_integer(bcd);
		RETURN ite((temp <= 9), CHARACTER'val(temp), '?');
	END;

	FUNCTION calc_length(slv_length : POSITIVE) RETURN POSITIVE IS
	BEGIN
		RETURN ((slv_length - 1) / 4) + 1;
	END;

	FUNCTION to_LCD_CHAR_VECTOR(slv : STD_LOGIC_VECTOR) RETURN T_LCD_CHAR_VECTOR IS
		CONSTANT Segments		: POSITIVE																	:= calc_length(slv'length);
		
		VARIABLE Result			: T_LCD_CHAR_VECTOR(0 TO Segments - 1)	:= (OTHERS => LCD_CHAR_0);
		VARIABLE SliceStart	: NATURAL;
		VARIABLE Slice			: T_SLV_4;
	BEGIN
		FOR I IN Segments - 1 DOWNTO 0 LOOP
			SliceStart				:= (I * 4) + slv'low;
		
			Slice							:= (OTHERS => '0');
			FOR J IN 0 TO 3 LOOP
				EXIT WHEN ((SliceStart + J) > slv'high);
				Slice(J)				:= slv(SliceStart + J);
			END LOOP;
			
			Result(I)					:= to_LCD_CHAR(Slice);
		END LOOP;
	
		RETURN Result;
	END;

	FUNCTION to_LCD_CHAR_VECTOR(rawstr : T_RAWSTRING) RETURN T_LCD_CHAR_VECTOR IS
		VARIABLE Result			: T_LCD_CHAR_VECTOR(0 TO rawstr'length - 1)	:= (OTHERS => LCD_CHAR_SPACE);
	BEGIN
		FOR I IN 0 TO rawstr'length - 1 LOOP
			Result(I)					:= to_LCD_CHAR2(rawstr(I));
		END LOOP;
	
		RETURN Result;
	END;

	FUNCTION to_LCD_CHAR_VECTOR(str : STRING) RETURN T_LCD_CHAR_VECTOR IS
		VARIABLE Result			: T_LCD_CHAR_VECTOR(0 TO str'length - 1)	:= (OTHERS => LCD_CHAR_SPACE);
	BEGIN
		FOR I IN 1 TO str'length LOOP
			Result(I - 1)			:= to_LCD_CHAR(str(I));
		END LOOP;
	
		RETURN Result;
	END;

	PROCEDURE LCDBufferProjection(SIGNAL buffer1 : IN T_LCD_CHAR_VECTOR; SIGNAL buffer2 : OUT T_LCD_CHAR_VECTOR) IS
	BEGIN
		FOR I IN buffer1'low TO buffer1'high LOOP
			EXIT WHEN I > buffer2'high;
			buffer2(I)	<= buffer1(I);
		END LOOP;
	END;

	FUNCTION to_LCD_CHAR(slv : T_SLV_4) RETURN T_LCD_CHAR IS
	BEGIN
		CASE slv IS
			WHEN x"0" =>		RETURN LCD_CHAR_0;
			WHEN x"1" =>		RETURN LCD_CHAR_1;
			WHEN x"2" =>		RETURN LCD_CHAR_2;
			WHEN x"3" =>		RETURN LCD_CHAR_3;
			WHEN x"4" =>		RETURN LCD_CHAR_4;
			WHEN x"5" =>		RETURN LCD_CHAR_5;
			WHEN x"6" =>		RETURN LCD_CHAR_6;
			WHEN x"7" =>		RETURN LCD_CHAR_7;
			WHEN x"8" =>		RETURN LCD_CHAR_8;
			WHEN x"9" =>		RETURN LCD_CHAR_9;
			WHEN x"A" =>		RETURN LCD_UCHAR_A;
			WHEN x"B" =>		RETURN LCD_UCHAR_B;
			WHEN x"C" =>		RETURN LCD_UCHAR_C;
			WHEN x"D" =>		RETURN LCD_UCHAR_D;
			WHEN x"E" =>		RETURN LCD_UCHAR_E;
			WHEN x"F" =>		RETURN LCD_UCHAR_F;
			WHEN OTHERS =>	RETURN LCD_UCHAR_X;
		END CASE;
	END;
	
	FUNCTION to_LCD_CHAR(char : CHARACTER) RETURN T_LCD_CHAR IS
	BEGIN
		CASE char IS
			WHEN ' ' =>			RETURN LCD_CHAR_SPACE;
			WHEN '-' =>			RETURN LCD_CHAR_DASH;
			WHEN '=' =>			RETURN LCD_CHAR_ASSIGN;
			WHEN '.' =>			RETURN LCD_CHAR_DOT;
			WHEN ':' =>			RETURN LCD_CHAR_COLON;
			WHEN '>' =>			RETURN LCD_CHAR_ARROW_R;
			WHEN '<' =>			RETURN LCD_CHAR_ARROW_L;
			WHEN '@' =>			RETURN LCD_CHAR_AT;
			WHEN '!' =>			RETURN LCD_CHAR_EXMARK;
			WHEN '?' =>			RETURN LCD_CHAR_QMARK;
			WHEN '#' =>			RETURN LCD_CHAR_SHARP;
			WHEN '~' =>			RETURN LCD_CHAR_CDOT;
		
			WHEN '0' =>			RETURN LCD_CHAR_0;
			WHEN '1' =>			RETURN LCD_CHAR_1;
			WHEN '2' =>			RETURN LCD_CHAR_2;
			WHEN '3' =>			RETURN LCD_CHAR_3;
			WHEN '4' =>			RETURN LCD_CHAR_4;
			WHEN '5' =>			RETURN LCD_CHAR_5;
			WHEN '6' =>			RETURN LCD_CHAR_6;
			WHEN '7' =>			RETURN LCD_CHAR_7;
			WHEN '8' =>			RETURN LCD_CHAR_8;
			WHEN '9' =>			RETURN LCD_CHAR_9;
			
			WHEN 'A' =>			RETURN LCD_UCHAR_A;
			WHEN 'B' =>			RETURN LCD_UCHAR_B;
			WHEN 'C' =>			RETURN LCD_UCHAR_C;
			WHEN 'D' =>			RETURN LCD_UCHAR_D;
			WHEN 'E' =>			RETURN LCD_UCHAR_E;
			WHEN 'F' =>			RETURN LCD_UCHAR_F;
			WHEN 'G' =>			RETURN LCD_UCHAR_G;
			WHEN 'H' =>			RETURN LCD_UCHAR_H;
			WHEN 'I' =>			RETURN LCD_UCHAR_I;
			WHEN 'J' =>			RETURN LCD_UCHAR_J;
			WHEN 'K' =>			RETURN LCD_UCHAR_K;
			WHEN 'L' =>			RETURN LCD_UCHAR_L;
			WHEN 'M' =>			RETURN LCD_UCHAR_M;
			WHEN 'N' =>			RETURN LCD_UCHAR_N;
			WHEN 'O' =>			RETURN LCD_UCHAR_O;
			WHEN 'P' =>			RETURN LCD_UCHAR_P;
			WHEN 'Q' =>			RETURN LCD_UCHAR_Q;
			WHEN 'R' =>			RETURN LCD_UCHAR_R;
			WHEN 'S' =>			RETURN LCD_UCHAR_S;
			WHEN 'T' =>			RETURN LCD_UCHAR_T;
			WHEN 'U' =>			RETURN LCD_UCHAR_U;
			WHEN 'V' =>			RETURN LCD_UCHAR_V;
			WHEN 'W' =>			RETURN LCD_UCHAR_W;
			WHEN 'X' =>			RETURN LCD_UCHAR_X;
			WHEN 'Y' =>			RETURN LCD_UCHAR_Y;
			WHEN 'Z' =>			RETURN LCD_UCHAR_Z;
			
			WHEN 'a' =>			RETURN LCD_LCHAR_a;
			WHEN 'b' =>			RETURN LCD_LCHAR_b;
			WHEN 'c' =>			RETURN LCD_LCHAR_c;
			WHEN 'd' =>			RETURN LCD_LCHAR_d;
			WHEN 'e' =>			RETURN LCD_LCHAR_e;
			WHEN 'f' =>			RETURN LCD_LCHAR_f;
			WHEN 'g' =>			RETURN LCD_LCHAR_g;
			WHEN 'h' =>			RETURN LCD_LCHAR_h;
			WHEN 'i' =>			RETURN LCD_LCHAR_i;
			WHEN 'j' =>			RETURN LCD_LCHAR_j;
			WHEN 'k' =>			RETURN LCD_LCHAR_k;
			WHEN 'l' =>			RETURN LCD_LCHAR_l;
			WHEN 'm' =>			RETURN LCD_LCHAR_m;
			WHEN 'n' =>			RETURN LCD_LCHAR_n;
			WHEN 'o' =>			RETURN LCD_LCHAR_o;
			WHEN 'p' =>			RETURN LCD_LCHAR_p;
			WHEN 'q' =>			RETURN LCD_LCHAR_q;
			WHEN 'r' =>			RETURN LCD_LCHAR_r;
			WHEN 's' =>			RETURN LCD_LCHAR_s;
			WHEN 't' =>			RETURN LCD_LCHAR_t;
			WHEN 'u' =>			RETURN LCD_LCHAR_u;
			WHEN 'v' =>			RETURN LCD_LCHAR_v;
			WHEN 'w' =>			RETURN LCD_LCHAR_w;
			WHEN 'x' =>			RETURN LCD_LCHAR_x;
			WHEN 'y' =>			RETURN LCD_LCHAR_y;
			WHEN 'z' =>			RETURN LCD_LCHAR_z;
			
			WHEN OTHERS =>	RETURN LCD_CHAR_SPACE;
		END CASE;
	END;
	
	FUNCTION to_LCD_CHAR2(rawchar : T_RAWCHAR) RETURN T_LCD_CHAR IS
	BEGIN
		CASE rawchar IS
			WHEN x"20" =>		RETURN LCD_CHAR_SPACE;
			WHEN x"2D" =>		RETURN LCD_CHAR_DASH;
			WHEN x"3D" =>		RETURN LCD_CHAR_ASSIGN;
			WHEN x"2E" =>		RETURN LCD_CHAR_DOT;
			WHEN x"3A" =>		RETURN LCD_CHAR_COLON;
			WHEN x"3E" =>		RETURN LCD_CHAR_ARROW_R;
			WHEN x"3C" =>		RETURN LCD_CHAR_ARROW_L;
			WHEN x"40" =>		RETURN LCD_CHAR_AT;
			WHEN x"21" =>		RETURN LCD_CHAR_EXMARK;
			WHEN x"3F" =>		RETURN LCD_CHAR_QMARK;
			WHEN x"23" =>		RETURN LCD_CHAR_SHARP;
			WHEN x"7E" =>		RETURN LCD_CHAR_CDOT;
				
			WHEN x"30" =>		RETURN LCD_CHAR_0;
			WHEN x"31" =>		RETURN LCD_CHAR_1;
			WHEN x"32" =>		RETURN LCD_CHAR_2;
			WHEN x"33" =>		RETURN LCD_CHAR_3;
			WHEN x"34" =>		RETURN LCD_CHAR_4;
			WHEN x"35" =>		RETURN LCD_CHAR_5;
			WHEN x"36" =>		RETURN LCD_CHAR_6;
			WHEN x"37" =>		RETURN LCD_CHAR_7;
			WHEN x"38" =>		RETURN LCD_CHAR_8;
			WHEN x"39" =>		RETURN LCD_CHAR_9;
			
			WHEN x"41" =>		RETURN LCD_UCHAR_A;
			WHEN x"42" =>		RETURN LCD_UCHAR_B;
			WHEN x"43" =>		RETURN LCD_UCHAR_C;
			WHEN x"44" =>		RETURN LCD_UCHAR_D;
			WHEN x"45" =>		RETURN LCD_UCHAR_E;
			WHEN x"46" =>		RETURN LCD_UCHAR_F;
			WHEN x"47" =>		RETURN LCD_UCHAR_G;
			WHEN x"48" =>		RETURN LCD_UCHAR_H;
			WHEN x"49" =>		RETURN LCD_UCHAR_I;
			WHEN x"4A" =>		RETURN LCD_UCHAR_J;
			WHEN x"4B" =>		RETURN LCD_UCHAR_K;
			WHEN x"4C" =>		RETURN LCD_UCHAR_L;
			WHEN x"4D" =>		RETURN LCD_UCHAR_M;
			WHEN x"4E" =>		RETURN LCD_UCHAR_N;
			WHEN x"4F" =>		RETURN LCD_UCHAR_O;
			WHEN x"50" =>		RETURN LCD_UCHAR_P;
			WHEN x"51" =>		RETURN LCD_UCHAR_Q;
			WHEN x"52" =>		RETURN LCD_UCHAR_R;
			WHEN x"53" =>		RETURN LCD_UCHAR_S;
			WHEN x"54" =>		RETURN LCD_UCHAR_T;
			WHEN x"55" =>		RETURN LCD_UCHAR_U;
			WHEN x"56" =>		RETURN LCD_UCHAR_V;
			WHEN x"57" =>		RETURN LCD_UCHAR_W;
			WHEN x"58" =>		RETURN LCD_UCHAR_X;
			WHEN x"59" =>		RETURN LCD_UCHAR_Y;
			WHEN x"5A" =>		RETURN LCD_UCHAR_Z;
			
			WHEN x"61" =>		RETURN LCD_LCHAR_a;
			WHEN x"62" =>		RETURN LCD_LCHAR_b;
			WHEN x"63" =>		RETURN LCD_LCHAR_c;
			WHEN x"64" =>		RETURN LCD_LCHAR_d;
			WHEN x"65" =>		RETURN LCD_LCHAR_e;
			WHEN x"66" =>		RETURN LCD_LCHAR_f;
			WHEN x"67" =>		RETURN LCD_LCHAR_g;
			WHEN x"68" =>		RETURN LCD_LCHAR_h;
			WHEN x"69" =>		RETURN LCD_LCHAR_i;
			WHEN x"6A" =>		RETURN LCD_LCHAR_j;
			WHEN x"6B" =>		RETURN LCD_LCHAR_k;
			WHEN x"6C" =>		RETURN LCD_LCHAR_l;
			WHEN x"6D" =>		RETURN LCD_LCHAR_m;
			WHEN x"6E" =>		RETURN LCD_LCHAR_n;
			WHEN x"6F" =>		RETURN LCD_LCHAR_o;
			WHEN x"70" =>		RETURN LCD_LCHAR_p;
			WHEN x"71" =>		RETURN LCD_LCHAR_q;
			WHEN x"72" =>		RETURN LCD_LCHAR_r;
			WHEN x"73" =>		RETURN LCD_LCHAR_s;
			WHEN x"74" =>		RETURN LCD_LCHAR_t;
			WHEN x"75" =>		RETURN LCD_LCHAR_u;
			WHEN x"76" =>		RETURN LCD_LCHAR_v;
			WHEN x"77" =>		RETURN LCD_LCHAR_w;
			WHEN x"78" =>		RETURN LCD_LCHAR_x;
			WHEN x"79" =>		RETURN LCD_LCHAR_y;
			WHEN x"7A" =>		RETURN LCD_LCHAR_z;
			
			WHEN OTHERS =>	RETURN LCD_CHAR_SPACE;
		END CASE;
	END;
	
	FUNCTION LCD_CHAR2Bin(char : T_LCD_CHAR) RETURN T_SLV_8 IS
	BEGIN
		CASE char IS
			WHEN LCD_CHAR_SPACE =>		RETURN x"20";
			WHEN LCD_CHAR_DASH =>			RETURN x"2D";
			WHEN LCD_CHAR_ASSIGN =>		RETURN x"3D";
			WHEN LCD_CHAR_DOT =>			RETURN x"2E";
			WHEN LCD_CHAR_COLON =>		RETURN x"3A";
			WHEN LCD_CHAR_ARROW_R =>	RETURN x"7E";
			WHEN LCD_CHAR_ARROW_L =>	RETURN x"7F";
			
			WHEN LCD_CHAR_AT =>				RETURN x"40";
			WHEN LCD_CHAR_EXMARK =>		RETURN x"21";
			WHEN LCD_CHAR_QMARK =>		RETURN x"3F";
			WHEN LCD_CHAR_SHARP =>		RETURN x"23";
			WHEN LCD_CHAR_CDOT =>			RETURN x"A5";

			WHEN LCD_CHAR_0 =>		RETURN x"30";
			WHEN LCD_CHAR_1 =>		RETURN x"31";
			WHEN LCD_CHAR_2 =>		RETURN x"32";
			WHEN LCD_CHAR_3 =>		RETURN x"33";
			WHEN LCD_CHAR_4 =>		RETURN x"34";
			WHEN LCD_CHAR_5 =>		RETURN x"35";
			WHEN LCD_CHAR_6 =>		RETURN x"36";
			WHEN LCD_CHAR_7 =>		RETURN x"37";
			WHEN LCD_CHAR_8 =>		RETURN x"38";
			WHEN LCD_CHAR_9 =>		RETURN x"39";
			
			WHEN LCD_UCHAR_A =>		RETURN x"41";
			WHEN LCD_UCHAR_B =>		RETURN x"42";
			WHEN LCD_UCHAR_C =>		RETURN x"43";
			WHEN LCD_UCHAR_D =>		RETURN x"44";
			WHEN LCD_UCHAR_E =>		RETURN x"45";
			WHEN LCD_UCHAR_F =>		RETURN x"46";
			WHEN LCD_UCHAR_G =>		RETURN x"47";
			WHEN LCD_UCHAR_H =>		RETURN x"48";
			WHEN LCD_UCHAR_I =>		RETURN x"49";
			WHEN LCD_UCHAR_J =>		RETURN x"4A";
			WHEN LCD_UCHAR_K =>		RETURN x"4B";
			WHEN LCD_UCHAR_L =>		RETURN x"4C";
			WHEN LCD_UCHAR_M =>		RETURN x"4D";
			WHEN LCD_UCHAR_N =>		RETURN x"4E";
			WHEN LCD_UCHAR_O =>		RETURN x"4F";
			WHEN LCD_UCHAR_P =>		RETURN x"50";
			WHEN LCD_UCHAR_Q =>		RETURN x"51";
			WHEN LCD_UCHAR_R =>		RETURN x"52";
			WHEN LCD_UCHAR_S =>		RETURN x"53";
			WHEN LCD_UCHAR_T =>		RETURN x"54";
			WHEN LCD_UCHAR_U =>		RETURN x"55";
			WHEN LCD_UCHAR_V =>		RETURN x"56";
			WHEN LCD_UCHAR_W =>		RETURN x"57";
			WHEN LCD_UCHAR_X =>		RETURN x"58";
			WHEN LCD_UCHAR_Y =>		RETURN x"59";
			WHEN LCD_UCHAR_Z =>		RETURN x"5A";
			
			WHEN LCD_LCHAR_a =>		RETURN x"61";
			WHEN LCD_LCHAR_b =>		RETURN x"62";
			WHEN LCD_LCHAR_c =>		RETURN x"63";
			WHEN LCD_LCHAR_d =>		RETURN x"64";
			WHEN LCD_LCHAR_e =>		RETURN x"65";
			WHEN LCD_LCHAR_f =>		RETURN x"66";
			WHEN LCD_LCHAR_g =>		RETURN x"67";
			WHEN LCD_LCHAR_h =>		RETURN x"68";
			WHEN LCD_LCHAR_i =>		RETURN x"69";
			WHEN LCD_LCHAR_j =>		RETURN x"6A";
			WHEN LCD_LCHAR_k =>		RETURN x"6B";
			WHEN LCD_LCHAR_l =>		RETURN x"6C";
			WHEN LCD_LCHAR_m =>		RETURN x"6D";
			WHEN LCD_LCHAR_n =>		RETURN x"6E";
			WHEN LCD_LCHAR_o =>		RETURN x"6F";
			WHEN LCD_LCHAR_p =>		RETURN x"70";
			WHEN LCD_LCHAR_q =>		RETURN x"71";
			WHEN LCD_LCHAR_r =>		RETURN x"72";
			WHEN LCD_LCHAR_s =>		RETURN x"73";
			WHEN LCD_LCHAR_t =>		RETURN x"74";
			WHEN LCD_LCHAR_u =>		RETURN x"75";
			WHEN LCD_LCHAR_v =>		RETURN x"76";
			WHEN LCD_LCHAR_w =>		RETURN x"77";
			WHEN LCD_LCHAR_x =>		RETURN x"78";
			WHEN LCD_LCHAR_y =>		RETURN x"79";
			WHEN LCD_LCHAR_z =>		RETURN x"7A";
			
			WHEN OTHERS =>				RETURN x"FF";
		END CASE;
	END;
	
	FUNCTION lcd_go_home(row_us : UNSIGNED) RETURN T_SLV_8 IS
		VARIABLE slv		: STD_LOGIC_VECTOR(row_us'range)		:= std_logic_vector(row_us);
	BEGIN
		RETURN '1' & slv(0) & "000000";
	END;

	FUNCTION lcd_display_on(ShowCursor : BOOLEAN; Blink : BOOLEAN) RETURN T_SLV_8 IS
		VARIABLE Result	: T_SLV_8														:= x"00";
	BEGIN
		Result(3)		:= '1';
		Result(2)		:= '1';			-- display on/off bit
	
		IF (ShowCursor = TRUE) THEN
			Result(1)	:= '1';			-- show cursor on/off bit
		END IF;
		IF (Blink = TRUE) THEN
			Result(0)	:= '1';			-- blinking on/off bit
		END IF;
		
		RETURN Result;
	END;

	FUNCTION ite(cond : BOOLEAN; value1 : T_LCD_CHAR; value2 : T_LCD_CHAR) RETURN T_LCD_CHAR IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END;
	
	FUNCTION ite(cond : BOOLEAN; value1 : T_LCD_CHAR_VECTOR; value2 : T_LCD_CHAR_VECTOR) RETURN T_LCD_CHAR_VECTOR IS
	BEGIN
		IF (cond = TRUE) THEN
			RETURN value1;
		ELSE
			RETURN value2;
		END IF;
	END;
	
	FUNCTION Bin2BCD(Sum_In : T_BCD; C_In : STD_LOGIC) RETURN UNSIGNED IS
	BEGIN
		IF C_In = '0' THEN
			CASE Sum_In IS
				WHEN x"0" =>		RETURN x"0";
				WHEN x"1" =>		RETURN x"2";
				WHEN x"2" =>		RETURN x"4";
				WHEN x"3" =>		RETURN x"6";
				WHEN x"4" =>		RETURN x"8";
				WHEN x"5" =>		RETURN x"0";
				WHEN x"6" =>		RETURN x"2";
				WHEN x"7" =>		RETURN x"4";
				WHEN x"8" =>		RETURN x"6";
				WHEN x"9" =>		RETURN x"8";
				WHEN OTHERS =>	RETURN x"0";
			END CASE;
		ELSE
			CASE Sum_In IS
				WHEN x"0" =>		RETURN x"1";
				WHEN x"1" =>		RETURN x"3";
				WHEN x"2" =>		RETURN x"5";
				WHEN x"3" =>		RETURN x"7";
				WHEN x"4" =>		RETURN x"9";
				WHEN x"5" =>		RETURN x"1";
				WHEN x"6" =>		RETURN x"3";
				WHEN x"7" =>		RETURN x"5";
				WHEN x"8" =>		RETURN x"7";
				WHEN x"9" =>		RETURN x"9";
				WHEN OTHERS =>	RETURN x"0";
			END CASE;
		END IF;
	END;
	
END PACKAGE BODY;
