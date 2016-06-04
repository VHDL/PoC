-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Authors:				 	Patrick Lehmann
--									Thomas B. Preußer
--
-- Entity:				 	TODO
--
-- Description:
-- ------------------------------------
-- .. TODO:: No documentation available.
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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;


package lcd is

	-- define array indices
	constant MAX_LCD_COLUMN_COUNT			: POSITIVE			:= 16;
	constant MAX_LCD_ROW_COUNT				: POSITIVE			:= 2;

	constant T_LCD_COLUMN_INDEX_BW		: POSITIVE			:= log2ceilnz(MAX_LCD_COLUMN_COUNT);
	constant T_LCD_ROW_INDEX_BW				: POSITIVE			:= log2ceilnz(MAX_LCD_ROW_COUNT);

	subtype T_LCD_COLUMN_INDEX				is INTEGER range 0 to MAX_LCD_COLUMN_COUNT - 1;
	subtype T_LCD_ROW_INDEX						is INTEGER range 0 to MAX_LCD_ROW_COUNT - 1;

	type T_LCD_CHAR is (
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

	type T_LCD_CHAR_VECTOR	is array(NATURAL range <>)	of T_LCD_CHAR;

	subtype T_LCD_ROW				is T_RAWSTRING(0 to MAX_LCD_COLUMN_COUNT - 1);						-- don't use "IS ARRAY (T_LCD_COLUMN_INDEX)" => expression is not sliceable
	type		T_LCD						is array (T_LCD_ROW_INDEX)	of T_LCD_ROW;


	type T_LCD_CONTROLLER is (
		LCD_CTRL_KS0066U,					-- Samsung KS0066U - Dot Matrix LCD Driver
		LCD_CTRL_ST7066U					-- Sitromix ST7066U - Dot Matrix LCD Controller/Driver (compatible to KS0066U)
	);

	type T_LCD_BUSCTRL_COMMAND is (
		LCD_BUSCTRL_CMD_NONE,
		LCD_BUSCTRL_CMD_READ,
		LCD_BUSCTRL_CMD_WRITE
	);

	type T_LCD_BUSCTRL_STATUS is (
		LCD_BUSCTRL_STATUS_IDLE,
		LCD_BUSCTRL_STATUS_READING,
		LCD_BUSCTRL_STATUS_READ_COMPLETE,
		LCD_BUSCTRL_STATUS_WRITING,
		LCD_BUSCTRL_STATUS_WRITE_COMPLETE,
		LCD_BUSCTRL_STATUS_ERROR
	);

	type T_LCD_CTRL_COMMAND is (
		LCD_CTRL_CMD_NONE,
		LCD_CTRL_CMD_INITIALIZE,
		LCD_CTRL_CMD_CLEAR_DISPLAY,
		LCD_CTRL_CMD_GOTO_HOME,
		LCD_CTRL_CMD_GOTO_POSITION,
		LCD_CTRL_CMD_WRITE_CHAR
	);

	type T_LCD_CTRL_STATUS is (
		LCD_CTRL_STATUS_IDLE,
		LCD_CTRL_STATUS_INITIALIZING,
		LCD_CTRL_STATUS_INITIALIZE_COMPLETE,
		LCD_CTRL_STATUS_EXECUTING,
		LCD_CTRL_STATUS_EXECUTE_COMPLETE,
		LCD_CTRL_STATUS_WRITING,
		LCD_CTRL_STATUS_WRITE_COMPLETE
	);


	-- command bytes for a KS0066U LCD controller
	-- ===========================================================================
	constant KS0066U_REG_COMMAND							: STD_LOGIC	:= '0';
	constant KS0066U_REG_DATA									: STD_LOGIC	:= '1';


	-- command bytes for a KS0066U LCD controller
	-- ===========================================================================
	constant KS0066U_CMD_NONE									: T_SLV_8		:= x"00";			-- no command
	constant KS0066U_CMD_DISPLAY_ON						: T_SLV_8		:= x"0C";			-- Display ON; cursor OFF; blink OFF
	constant KS0066U_CMD_DISPLAY_CLEAR				: T_SLV_8		:= x"01";			--
	constant KS0066U_CMD_return_HOME					: T_SLV_8		:= x"02";			--
	constant KS0066U_CMD_GO_HOME							: T_SLV_8		:= x"10";			--
	constant KS0066U_CMD_SET_FUNCTION					: T_SLV_8		:= x"2C";			-- (4 Bit interface, 2-line, 5x8 dots)
	constant KS0066U_CMD_ENTRY_MODE						: T_SLV_8		:= x"06";			-- entry mode: move: RIGHT; shift OFF

	component lcd_dotmatrix is
		generic(
			CLOCK_FREQ : FREQ;
			DATA_WIDTH : positive;  				-- Width of data bus (4 or 8)

			T_W        : time     :=  500 ns; -- Minimum width of E pulse
			T_SU       : time     :=   60 ns; -- Minimum RS + R/W setup time
			T_H        : time     :=   20 ns; -- Minimum RS + R/W hole time
			T_C        : time     := 1000 ns; -- Minimum cycle time

			B_RECOVER_TIME : time := 5 us  -- Recover time after cleared Busy flag
		);
		port(
			-- Global Reset and Clock
			clk, rst : in std_logic;

			skip_bf : in std_logic := '0';  		-- Skip test for cleared busy flag

			-- Upper Layer Interface
			rdy : out std_logic;  									 -- ready for command or data
			stb : in  std_logic;  									 -- input strobe
			cmd : in  std_logic;  									 -- command / no data selector
			dat : in  std_logic_vector(7 downto 0);  -- command or data word

			-- LCD Connections
			lcd_e     : out std_logic;  -- Enable
			lcd_rs    : out std_logic;  -- Register Select
			lcd_rw    : out std_logic;  -- Read /Write, Data Direction Selector
			lcd_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);  -- Data Input
			lcd_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0)  	-- Data Output
		);
	end component;

  function lcd_functionset(datalength : positive; lines : positive; font : natural) return T_SLV_8;
  function lcd_displayctrl(turn_on : boolean; cursor : boolean; blink : boolean) return T_SLV_8;
  function lcd_entrymode(inc_ndec : boolean; shift : boolean) return T_SLV_8;

	procedure LCDBufferProjection(signal buffer1 : in T_LCD_CHAR_VECTOR; signal buffer2 : out T_LCD_CHAR_VECTOR);

	function Bin2BCD(Sum_In : T_BCD; C_In : STD_LOGIC) return T_BCD;

	function calc_length(slv_length : POSITIVE) return POSITIVE;

	function to_LCD_CHAR_VECTOR(slv : STD_LOGIC_VECTOR) return T_LCD_CHAR_VECTOR;
	function to_LCD_CHAR_VECTOR(rawstr : T_RAWSTRING) return T_LCD_CHAR_VECTOR;
	function to_LCD_CHAR_VECTOR(str : STRING) return T_LCD_CHAR_VECTOR;

	function to_LCD_CHAR(slv : T_SLV_4) return T_LCD_CHAR;
	function to_LCD_CHAR2(rawchar : T_RAWCHAR) return T_LCD_CHAR;
	function to_LCD_CHAR(char : CHARACTER) return T_LCD_CHAR;

	function LCD_CHAR2Bin(char : T_LCD_CHAR) return T_SLV_8;

	function lcd_go_home(row_us : std_logic_vector) return T_SLV_8;
	function lcd_display_on(ShowCursor : BOOLEAN; Blink : BOOLEAN) return T_SLV_8;

	function ite(cond : BOOLEAN; value1 : T_LCD_CHAR; value2 : T_LCD_CHAR) return T_LCD_CHAR;
	function ite(cond : BOOLEAN; value1 : T_LCD_CHAR_VECTOR; value2 : T_LCD_CHAR_VECTOR) return T_LCD_CHAR_VECTOR;

END;

library	IEEE;
use			IEEE.numeric_std.all;

package body lcd is
	FUNCTION to_char(bcd : T_BCD) return CHARACTER IS
		VARIABLE temp		: T_UINT_8;
	BEGIN
		temp := to_integer(unsigned(bcd));
		return ite((temp <= 9), CHARACTER'val(temp), '?');
	END;

	FUNCTION calc_length(slv_length : POSITIVE) return POSITIVE IS
	BEGIN
		return ((slv_length - 1) / 4) + 1;
	END;

	FUNCTION to_LCD_CHAR_VECTOR(slv : STD_LOGIC_VECTOR) return T_LCD_CHAR_VECTOR IS
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

		return Result;
	END;

	FUNCTION to_LCD_CHAR_VECTOR(rawstr : T_RAWSTRING) return T_LCD_CHAR_VECTOR IS
		VARIABLE Result			: T_LCD_CHAR_VECTOR(0 TO rawstr'length - 1)	:= (OTHERS => LCD_CHAR_SPACE);
	BEGIN
		FOR I IN 0 TO rawstr'length - 1 LOOP
			Result(I)					:= to_LCD_CHAR2(rawstr(I));
		END LOOP;

		return Result;
	END;

	FUNCTION to_LCD_CHAR_VECTOR(str : STRING) return T_LCD_CHAR_VECTOR IS
		VARIABLE Result			: T_LCD_CHAR_VECTOR(0 TO str'length - 1)	:= (OTHERS => LCD_CHAR_SPACE);
	BEGIN
		FOR I IN 1 TO str'length LOOP
			Result(I - 1)			:= to_LCD_CHAR(str(I));
		END LOOP;

		return Result;
	END;

	procedure LCDBufferProjection(signal buffer1 : in T_LCD_CHAR_VECTOR; signal buffer2 : out T_LCD_CHAR_VECTOR) is
	begin
		for i in buffer1'low to buffer1'high loop
			exit when i > buffer2'high;
			buffer2(i)	<= buffer1(i);
		end loop;
	end;

	function to_LCD_CHAR(slv : T_SLV_4) return T_LCD_CHAR is
	begin
		case slv is
			when x"0" =>		return LCD_CHAR_0;
			when x"1" =>		return LCD_CHAR_1;
			when x"2" =>		return LCD_CHAR_2;
			when x"3" =>		return LCD_CHAR_3;
			when x"4" =>		return LCD_CHAR_4;
			when x"5" =>		return LCD_CHAR_5;
			when x"6" =>		return LCD_CHAR_6;
			when x"7" =>		return LCD_CHAR_7;
			when x"8" =>		return LCD_CHAR_8;
			when x"9" =>		return LCD_CHAR_9;
			when x"A" =>		return LCD_UCHAR_A;
			when x"B" =>		return LCD_UCHAR_B;
			when x"C" =>		return LCD_UCHAR_C;
			when x"D" =>		return LCD_UCHAR_D;
			when x"E" =>		return LCD_UCHAR_E;
			when x"F" =>		return LCD_UCHAR_F;
			when others =>	return LCD_UCHAR_X;
		end case;
	end;

	function to_LCD_CHAR(char : CHARACTER) return T_LCD_CHAR is
	begin
		case char is
			when ' ' =>			return LCD_CHAR_SPACE;
			when '-' =>			return LCD_CHAR_DASH;
			when '=' =>			return LCD_CHAR_ASSIGN;
			when '.' =>			return LCD_CHAR_DOT;
			when ':' =>			return LCD_CHAR_COLON;
			when '>' =>			return LCD_CHAR_ARROW_R;
			when '<' =>			return LCD_CHAR_ARROW_L;
			when '@' =>			return LCD_CHAR_AT;
			when '!' =>			return LCD_CHAR_EXMARK;
			when '?' =>			return LCD_CHAR_QMARK;
			when '#' =>			return LCD_CHAR_SHARP;
			when '~' =>			return LCD_CHAR_CDOT;

			when '0' =>			return LCD_CHAR_0;
			when '1' =>			return LCD_CHAR_1;
			when '2' =>			return LCD_CHAR_2;
			when '3' =>			return LCD_CHAR_3;
			when '4' =>			return LCD_CHAR_4;
			when '5' =>			return LCD_CHAR_5;
			when '6' =>			return LCD_CHAR_6;
			when '7' =>			return LCD_CHAR_7;
			when '8' =>			return LCD_CHAR_8;
			when '9' =>			return LCD_CHAR_9;

			when 'A' =>			return LCD_UCHAR_A;
			when 'B' =>			return LCD_UCHAR_B;
			when 'C' =>			return LCD_UCHAR_C;
			when 'D' =>			return LCD_UCHAR_D;
			when 'E' =>			return LCD_UCHAR_E;
			when 'F' =>			return LCD_UCHAR_F;
			when 'G' =>			return LCD_UCHAR_G;
			when 'H' =>			return LCD_UCHAR_H;
			when 'I' =>			return LCD_UCHAR_I;
			when 'J' =>			return LCD_UCHAR_J;
			when 'K' =>			return LCD_UCHAR_K;
			when 'L' =>			return LCD_UCHAR_L;
			when 'M' =>			return LCD_UCHAR_M;
			when 'N' =>			return LCD_UCHAR_N;
			when 'O' =>			return LCD_UCHAR_O;
			when 'P' =>			return LCD_UCHAR_P;
			when 'Q' =>			return LCD_UCHAR_Q;
			when 'R' =>			return LCD_UCHAR_R;
			when 'S' =>			return LCD_UCHAR_S;
			when 'T' =>			return LCD_UCHAR_T;
			when 'U' =>			return LCD_UCHAR_U;
			when 'V' =>			return LCD_UCHAR_V;
			when 'W' =>			return LCD_UCHAR_W;
			when 'X' =>			return LCD_UCHAR_X;
			when 'Y' =>			return LCD_UCHAR_Y;
			when 'Z' =>			return LCD_UCHAR_Z;

			when 'a' =>			return LCD_LCHAR_a;
			when 'b' =>			return LCD_LCHAR_b;
			when 'c' =>			return LCD_LCHAR_c;
			when 'd' =>			return LCD_LCHAR_d;
			when 'e' =>			return LCD_LCHAR_e;
			when 'f' =>			return LCD_LCHAR_f;
			when 'g' =>			return LCD_LCHAR_g;
			when 'h' =>			return LCD_LCHAR_h;
			when 'i' =>			return LCD_LCHAR_i;
			when 'j' =>			return LCD_LCHAR_j;
			when 'k' =>			return LCD_LCHAR_k;
			when 'l' =>			return LCD_LCHAR_l;
			when 'm' =>			return LCD_LCHAR_m;
			when 'n' =>			return LCD_LCHAR_n;
			when 'o' =>			return LCD_LCHAR_o;
			when 'p' =>			return LCD_LCHAR_p;
			when 'q' =>			return LCD_LCHAR_q;
			when 'r' =>			return LCD_LCHAR_r;
			when 's' =>			return LCD_LCHAR_s;
			when 't' =>			return LCD_LCHAR_t;
			when 'u' =>			return LCD_LCHAR_u;
			when 'v' =>			return LCD_LCHAR_v;
			when 'w' =>			return LCD_LCHAR_w;
			when 'x' =>			return LCD_LCHAR_x;
			when 'y' =>			return LCD_LCHAR_y;
			when 'z' =>			return LCD_LCHAR_z;

			when others =>	return LCD_CHAR_SPACE;
		end case;
	end;

	function to_LCD_CHAR2(rawchar : T_RAWCHAR) return T_LCD_CHAR is
	begin
		case rawchar is
			when x"20" =>		return LCD_CHAR_SPACE;
			when x"2D" =>		return LCD_CHAR_DASH;
			when x"3D" =>		return LCD_CHAR_ASSIGN;
			when x"2E" =>		return LCD_CHAR_DOT;
			when x"3A" =>		return LCD_CHAR_COLON;
			when x"3E" =>		return LCD_CHAR_ARROW_R;
			when x"3C" =>		return LCD_CHAR_ARROW_L;
			when x"40" =>		return LCD_CHAR_AT;
			when x"21" =>		return LCD_CHAR_EXMARK;
			when x"3F" =>		return LCD_CHAR_QMARK;
			when x"23" =>		return LCD_CHAR_SHARP;
			when x"7E" =>		return LCD_CHAR_CDOT;

			when x"30" =>		return LCD_CHAR_0;
			when x"31" =>		return LCD_CHAR_1;
			when x"32" =>		return LCD_CHAR_2;
			when x"33" =>		return LCD_CHAR_3;
			when x"34" =>		return LCD_CHAR_4;
			when x"35" =>		return LCD_CHAR_5;
			when x"36" =>		return LCD_CHAR_6;
			when x"37" =>		return LCD_CHAR_7;
			when x"38" =>		return LCD_CHAR_8;
			when x"39" =>		return LCD_CHAR_9;

			when x"41" =>		return LCD_UCHAR_A;
			when x"42" =>		return LCD_UCHAR_B;
			when x"43" =>		return LCD_UCHAR_C;
			when x"44" =>		return LCD_UCHAR_D;
			when x"45" =>		return LCD_UCHAR_E;
			when x"46" =>		return LCD_UCHAR_F;
			when x"47" =>		return LCD_UCHAR_G;
			when x"48" =>		return LCD_UCHAR_H;
			when x"49" =>		return LCD_UCHAR_I;
			when x"4A" =>		return LCD_UCHAR_J;
			when x"4B" =>		return LCD_UCHAR_K;
			when x"4C" =>		return LCD_UCHAR_L;
			when x"4D" =>		return LCD_UCHAR_M;
			when x"4E" =>		return LCD_UCHAR_N;
			when x"4F" =>		return LCD_UCHAR_O;
			when x"50" =>		return LCD_UCHAR_P;
			when x"51" =>		return LCD_UCHAR_Q;
			when x"52" =>		return LCD_UCHAR_R;
			when x"53" =>		return LCD_UCHAR_S;
			when x"54" =>		return LCD_UCHAR_T;
			when x"55" =>		return LCD_UCHAR_U;
			when x"56" =>		return LCD_UCHAR_V;
			when x"57" =>		return LCD_UCHAR_W;
			when x"58" =>		return LCD_UCHAR_X;
			when x"59" =>		return LCD_UCHAR_Y;
			when x"5A" =>		return LCD_UCHAR_Z;

			when x"61" =>		return LCD_LCHAR_a;
			when x"62" =>		return LCD_LCHAR_b;
			when x"63" =>		return LCD_LCHAR_c;
			when x"64" =>		return LCD_LCHAR_d;
			when x"65" =>		return LCD_LCHAR_e;
			when x"66" =>		return LCD_LCHAR_f;
			when x"67" =>		return LCD_LCHAR_g;
			when x"68" =>		return LCD_LCHAR_h;
			when x"69" =>		return LCD_LCHAR_i;
			when x"6A" =>		return LCD_LCHAR_j;
			when x"6B" =>		return LCD_LCHAR_k;
			when x"6C" =>		return LCD_LCHAR_l;
			when x"6D" =>		return LCD_LCHAR_m;
			when x"6E" =>		return LCD_LCHAR_n;
			when x"6F" =>		return LCD_LCHAR_o;
			when x"70" =>		return LCD_LCHAR_p;
			when x"71" =>		return LCD_LCHAR_q;
			when x"72" =>		return LCD_LCHAR_r;
			when x"73" =>		return LCD_LCHAR_s;
			when x"74" =>		return LCD_LCHAR_t;
			when x"75" =>		return LCD_LCHAR_u;
			when x"76" =>		return LCD_LCHAR_v;
			when x"77" =>		return LCD_LCHAR_w;
			when x"78" =>		return LCD_LCHAR_x;
			when x"79" =>		return LCD_LCHAR_y;
			when x"7A" =>		return LCD_LCHAR_z;

			when others =>	return LCD_CHAR_SPACE;
		end case;
	end;

	function LCD_CHAR2Bin(char : T_LCD_CHAR) return T_SLV_8 is
	begin
		case char is
			when LCD_CHAR_SPACE =>		return x"20";
			when LCD_CHAR_DASH =>			return x"2D";
			when LCD_CHAR_ASSIGN =>		return x"3D";
			when LCD_CHAR_DOT =>			return x"2E";
			when LCD_CHAR_COLON =>		return x"3A";
			when LCD_CHAR_ARROW_R =>	return x"7E";
			when LCD_CHAR_ARROW_L =>	return x"7F";

			when LCD_CHAR_AT =>				return x"40";
			when LCD_CHAR_EXMARK =>		return x"21";
			when LCD_CHAR_QMARK =>		return x"3F";
			when LCD_CHAR_SHARP =>		return x"23";
			when LCD_CHAR_CDOT =>			return x"A5";

			when LCD_CHAR_0 =>		return x"30";
			when LCD_CHAR_1 =>		return x"31";
			when LCD_CHAR_2 =>		return x"32";
			when LCD_CHAR_3 =>		return x"33";
			when LCD_CHAR_4 =>		return x"34";
			when LCD_CHAR_5 =>		return x"35";
			when LCD_CHAR_6 =>		return x"36";
			when LCD_CHAR_7 =>		return x"37";
			when LCD_CHAR_8 =>		return x"38";
			when LCD_CHAR_9 =>		return x"39";

			when LCD_UCHAR_A =>		return x"41";
			when LCD_UCHAR_B =>		return x"42";
			when LCD_UCHAR_C =>		return x"43";
			when LCD_UCHAR_D =>		return x"44";
			when LCD_UCHAR_E =>		return x"45";
			when LCD_UCHAR_F =>		return x"46";
			when LCD_UCHAR_G =>		return x"47";
			when LCD_UCHAR_H =>		return x"48";
			when LCD_UCHAR_I =>		return x"49";
			when LCD_UCHAR_J =>		return x"4A";
			when LCD_UCHAR_K =>		return x"4B";
			when LCD_UCHAR_L =>		return x"4C";
			when LCD_UCHAR_M =>		return x"4D";
			when LCD_UCHAR_N =>		return x"4E";
			when LCD_UCHAR_O =>		return x"4F";
			when LCD_UCHAR_P =>		return x"50";
			when LCD_UCHAR_Q =>		return x"51";
			when LCD_UCHAR_R =>		return x"52";
			when LCD_UCHAR_S =>		return x"53";
			when LCD_UCHAR_T =>		return x"54";
			when LCD_UCHAR_U =>		return x"55";
			when LCD_UCHAR_V =>		return x"56";
			when LCD_UCHAR_W =>		return x"57";
			when LCD_UCHAR_X =>		return x"58";
			when LCD_UCHAR_Y =>		return x"59";
			when LCD_UCHAR_Z =>		return x"5A";

			when LCD_LCHAR_a =>		return x"61";
			when LCD_LCHAR_b =>		return x"62";
			when LCD_LCHAR_c =>		return x"63";
			when LCD_LCHAR_d =>		return x"64";
			when LCD_LCHAR_e =>		return x"65";
			when LCD_LCHAR_f =>		return x"66";
			when LCD_LCHAR_g =>		return x"67";
			when LCD_LCHAR_h =>		return x"68";
			when LCD_LCHAR_i =>		return x"69";
			when LCD_LCHAR_j =>		return x"6A";
			when LCD_LCHAR_k =>		return x"6B";
			when LCD_LCHAR_l =>		return x"6C";
			when LCD_LCHAR_m =>		return x"6D";
			when LCD_LCHAR_n =>		return x"6E";
			when LCD_LCHAR_o =>		return x"6F";
			when LCD_LCHAR_p =>		return x"70";
			when LCD_LCHAR_q =>		return x"71";
			when LCD_LCHAR_r =>		return x"72";
			when LCD_LCHAR_s =>		return x"73";
			when LCD_LCHAR_t =>		return x"74";
			when LCD_LCHAR_u =>		return x"75";
			when LCD_LCHAR_v =>		return x"76";
			when LCD_LCHAR_w =>		return x"77";
			when LCD_LCHAR_x =>		return x"78";
			when LCD_LCHAR_y =>		return x"79";
			when LCD_LCHAR_z =>		return x"7A";

			when others =>				return x"FF";
		end case;
	end;

  function lcd_functionset(datalength : positive; lines : positive; font : natural) return T_SLV_8 is
		variable dl : std_logic;
  begin
    assert datalength = 4 or datalength = 8 report "Invalid display data length." severity error;
    case datalength is
      when 4      => dl := '0';
      when 8      => dl := '1';
      when others => dl := 'X';
    end case;
		assert lines <= 2 report "Invalid display line number." severity error;
		assert font <= 1 report "Invalid display font selection." severity error;
    return "001" & dl & to_sl(lines = 2) & to_sl(font > 0) & "--";
  end;

  function lcd_displayctrl(turn_on : boolean; cursor : boolean; blink : boolean) return T_SLV_8 is
	begin
		return "00001" & to_sl(turn_on) & to_sl(cursor) & to_sl(blink);
	end;

  function lcd_entrymode(inc_ndec : boolean; shift : boolean) return T_SLV_8 is
	begin
		return "000001" & to_sl(inc_ndec) & to_sl(shift);
	end;

	FUNCTION lcd_go_home(row_us : std_logic_vector) return T_SLV_8 IS
	BEGIN
		return '1' & row_us(0) & "000000";
	END;

	FUNCTION lcd_display_on(ShowCursor : BOOLEAN; Blink : BOOLEAN) return T_SLV_8 IS
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

		return Result;
	END;

	function ite(cond : BOOLEAN; value1 : T_LCD_CHAR; value2 : T_LCD_CHAR) return T_LCD_CHAR is
	begin
		if (cond = TRUE) then
			return value1;
		else
			return value2;
		end if;
	end;

	function ite(cond : BOOLEAN; value1 : T_LCD_CHAR_VECTOR; value2 : T_LCD_CHAR_VECTOR) return T_LCD_CHAR_VECTOR is
	begin
		if (cond = TRUE) then
			return value1;
		else
			return value2;
		end if;
	end;

	function Bin2BCD(Sum_In : T_BCD; C_In : STD_LOGIC) return T_BCD is
	begin
		if C_In = '0' then
			case Sum_In is
				when x"0" =>		return x"0";
				when x"1" =>		return x"2";
				when x"2" =>		return x"4";
				when x"3" =>		return x"6";
				when x"4" =>		return x"8";
				when x"5" =>		return x"0";
				when x"6" =>		return x"2";
				when x"7" =>		return x"4";
				when x"8" =>		return x"6";
				when x"9" =>		return x"8";
				when others =>	return x"0";
			end case;
		else
			case Sum_In is
				when x"0" =>		return x"1";
				when x"1" =>		return x"3";
				when x"2" =>		return x"5";
				when x"3" =>		return x"7";
				when x"4" =>		return x"9";
				when x"5" =>		return x"1";
				when x"6" =>		return x"3";
				when x"7" =>		return x"5";
				when x"8" =>		return x"7";
				when x"9" =>		return x"9";
				when others =>	return x"0";
			end case;
		end if;
	end;

end package body;
