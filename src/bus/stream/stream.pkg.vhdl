-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:                     Patrick Lehmann
--
-- Package:                     VHDL package for component declarations, types and functions
--                              associated to the PoC.bus.stream namespace
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
-----------------
-- Example::
-- library PoC;
-- package Stream_D128 is
-- new PoC.Stream_Sized
--     generic map (
--         DATA_BITS    => 128,
--         BE_BITS      => 16,
--         Meta_BITS    => 1
--     );
-----------------
--    signal My_m2s          : Stream_D128.SIZED_M2S;
--    signal My_s2m          : Stream_D128.SIZED_S2M;
--
--
-- License:
-- =============================================================================
-- Copryright 2017-2025 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;

use     work.utils.all;
use     work.vectors.all;
use     work.strings.all;


package stream is
		type T_Stream_M2S is record
				Valid : std_logic;
				Data  : std_logic_vector;
				SoF   : std_logic;
				EoF   : std_logic;
				BE    : std_logic_vector;
				Meta  : std_logic_vector;
		end record;

		type T_Stream_S2M is record
				ACK  : std_logic;
				Meta : std_logic_vector;
		end record;

		type T_Stream_M2S_VECTOR is array(natural range <>) of T_Stream_M2S;
		type T_Stream_S2M_VECTOR is array(natural range <>) of T_Stream_S2M;

		function Initialize(DataBits : natural; MetaBits : positive := 1; Value : std_logic := 'Z') return T_Stream_M2S;
		function Initialize(                    MetaBits : positive := 1; Value : std_logic := 'Z') return T_Stream_S2M;

		function Get_Valid_vector(M2S : T_Stream_M2S_VECTOR) return std_logic_vector;
		function Get_SoF_vector(  M2S : T_Stream_M2S_VECTOR) return std_logic_vector;
		function Get_EoF_vector(  M2S : T_Stream_M2S_VECTOR) return std_logic_vector;
		function Get_ACK_vector(  S2M : T_Stream_S2M_VECTOR) return std_logic_vector;
		function Get_Data_vector( M2S : T_Stream_M2S_VECTOR) return T_SLVV;
		function Get_BE_vector(   M2S : T_Stream_M2S_VECTOR) return T_SLVV;
		function Get_Meta_vector( M2S : T_Stream_M2S_VECTOR) return T_SLVV;
		function Get_Meta_vector( S2M : T_Stream_S2M_VECTOR) return T_SLVV;
		function Resize_meta(    M2S : T_Stream_M2S; length : natural) return T_Stream_M2S;
		function Replace_meta(   M2S : T_Stream_M2S; slv : std_logic_vector) return T_Stream_M2S;

		type T_Stream_Glue_Meta_Kind is (
				With_Data,
				None,
				Single_Reg
		);
		function ite(cond : boolean; value1 : T_Stream_Glue_Meta_Kind; value2 : T_Stream_Glue_Meta_Kind) return T_Stream_Glue_Meta_Kind;


	attribute Count : integer;

		--types for stream_FrameGenerator
		type T_FRAMEGEN_COMMAND is (
				FRAMEGEN_CMD_NONE,
				FRAMEGEN_CMD_SEQUENCE,
				FRAMEGEN_CMD_RANDOM,
				FRAMEGEN_CMD_SINGLE_FRAME,
				FRAMEGEN_CMD_SINGLE_FRAMEGROUP,
				FRAMEGEN_CMD_ALL_FRAMES
		);
		attribute Count of T_FRAMEGEN_COMMAND : type is T_FRAMEGEN_COMMAND'pos(T_FRAMEGEN_COMMAND'high) + 1;
		function to_slv(val : T_FRAMEGEN_COMMAND) return std_logic_vector;
		function to_FRAMEGEN_COMMAND(slv : std_logic_vector) return T_FRAMEGEN_COMMAND;

		type T_FRAMEGEN_STATUS is (
				FRAMEGEN_STATUS_IDLE,
				FRAMEGEN_STATUS_GENERATING,
				FRAMEGEN_STATUS_COMPLETE,
				FRAMEGEN_STATUS_ERROR
		);
		attribute Count of T_FRAMEGEN_STATUS : type is T_FRAMEGEN_STATUS'pos(T_FRAMEGEN_STATUS'high) + 1;
		function to_slv(val : T_FRAMEGEN_STATUS) return std_logic_vector;
		function to_FRAMEGEN_STATUS(slv : std_logic_vector) return T_FRAMEGEN_STATUS;

		-- single dataword for TestRAM
		type T_SIM_STREAM_WORD_8 is record
				Valid : std_logic;
				Data  : T_SLV_8;
				SOF   : std_logic;
				EOF   : std_logic;
				Ready : std_logic;
				EOFG  : boolean;
		end record;

		type T_SIM_STREAM_WORD_32 is record
				Valid : std_logic;
				Data  : T_SLV_32;
				SOF   : std_logic;
				EOF   : std_logic;
				Ready : std_logic;
				EOFG  : boolean;
		end record;

		-- define array indices
		constant C_SIM_STREAM_MAX_PATTERN_COUNT    : positive := 128;-- * 1024;                -- max data size per testcase
		constant C_SIM_STREAM_MAX_FRAMEGROUP_COUNT : positive := 8;

		constant C_SIM_STREAM_WORD_INDEX_BW       : positive := log2ceilnz(C_SIM_STREAM_MAX_PATTERN_COUNT);
		constant C_SIM_STREAM_FRAMEGROUP_INDEX_BW : positive := log2ceilnz(C_SIM_STREAM_MAX_FRAMEGROUP_COUNT);

		subtype T_SIM_STREAM_WORD_INDEX       is integer range 0 to C_SIM_STREAM_MAX_PATTERN_COUNT - 1;
		subtype T_SIM_STREAM_FRAMEGROUP_INDEX is integer range 0 to C_SIM_STREAM_MAX_FRAMEGROUP_COUNT - 1;

		subtype T_SIM_DELAY        is T_UINT_16;
		type    T_SIM_DELAY_VECTOR is array (natural range <>) of T_SIM_DELAY;

		-- define array of datawords
		type        T_SIM_STREAM_WORD_VECTOR_8  is array (natural range <>) of T_SIM_STREAM_WORD_8;
		type        T_SIM_STREAM_WORD_VECTOR_32 is array (natural range <>) of T_SIM_STREAM_WORD_32;

		-- define link layer directions
		type        T_SIM_STREAM_DIRECTION is (Send, RECEIVE);

		-- define framegroup information
		type T_SIM_STREAM_FRAMEGROUP_8 is record
				Active    : boolean;
				Name      : string(1 to 64);
				PrePause  : natural;
				PostPause : natural;
				DataCount : T_SIM_STREAM_WORD_INDEX;
				Data      : T_SIM_STREAM_WORD_VECTOR_8(0 to C_SIM_STREAM_MAX_PATTERN_COUNT - 1);
		end record;

		type T_SIM_STREAM_FRAMEGROUP_32 is record
				Active    : boolean;
				Name      : string(1 to 64);
				PrePause  : natural;
				PostPause : natural;
				DataCount : T_SIM_STREAM_WORD_INDEX;
				Data      : T_SIM_STREAM_WORD_VECTOR_32(T_SIM_STREAM_WORD_INDEX);
		end record;

		-- define array of framegroups
		type T_SIM_STREAM_FRAMEGROUP_VECTOR_8  is array (natural range <>) of T_SIM_STREAM_FRAMEGROUP_8;
		type T_SIM_STREAM_FRAMEGROUP_VECTOR_32 is array (natural range <>) of T_SIM_STREAM_FRAMEGROUP_32;

		-- define constants (stored in RAMB36's parity-bits)
		constant C_SIM_STREAM_WORD_8_EMPTY    : T_SIM_STREAM_WORD_8  := (Valid => '0', Data => (others => 'U'),    SOF => '0', EOF => '0', Ready => '0', EOFG => FALSE);
		constant C_SIM_STREAM_WORD_32_EMPTY   : T_SIM_STREAM_WORD_32 := (Valid => '0', Data => (others => 'U'),    SOF => '0', EOF => '0', Ready => '0', EOFG => FALSE);
		constant C_SIM_STREAM_WORD_8_INVALID  : T_SIM_STREAM_WORD_8  := (Valid => '0', Data => (others => 'U'),    SOF => '0', EOF => '0', Ready => '0', EOFG => FALSE);
		constant C_SIM_STREAM_WORD_32_INVALID : T_SIM_STREAM_WORD_32 := (Valid => '0', Data => (others => 'U'),    SOF => '0', EOF => '0', Ready => '0', EOFG => FALSE);
		constant C_SIM_STREAM_WORD_8_ZERO     : T_SIM_STREAM_WORD_8  := (Valid => '1', Data => (others => 'Z'),    SOF => '0', EOF => '0', Ready => '0', EOFG => FALSE);
		constant C_SIM_STREAM_WORD_32_ZERO    : T_SIM_STREAM_WORD_32 := (Valid => '1', Data => (others => 'Z'),    SOF => '0', EOF => '0', Ready => '0', EOFG => FALSE);
		constant C_SIM_STREAM_WORD_8_UNDEF    : T_SIM_STREAM_WORD_8  := (Valid => '1', Data => (others => 'U'),    SOF => '0', EOF => '0', Ready => '0', EOFG => FALSE);
		constant C_SIM_STREAM_WORD_32_UNDEF   : T_SIM_STREAM_WORD_32 := (Valid => '1', Data => (others => 'U'),    SOF => '0', EOF => '0', Ready => '0', EOFG => FALSE);

		constant C_SIM_STREAM_FRAMEGROUP_8_EMPTY : T_SIM_STREAM_FRAMEGROUP_8 := (
				Active    => FALSE,
				Name      => (others => C_POC_NUL),
				PrePause  => 0,
				PostPause => 0,
				DataCount => 0,
				Data      => (others => C_SIM_STREAM_WORD_8_EMPTY)
		);
		constant C_SIM_STREAM_FRAMEGROUP_32_EMPTY : T_SIM_STREAM_FRAMEGROUP_32 := (
				Active    => FALSE,
				Name      => (others => C_POC_NUL),
				PrePause  => 0,
				PostPause => 0,
				DataCount => 0,
				Data      => (others => C_SIM_STREAM_WORD_32_EMPTY)
		);

		function CountPatterns(Data : T_SIM_STREAM_WORD_VECTOR_8)  return natural;
		function CountPatterns(Data : T_SIM_STREAM_WORD_VECTOR_32) return natural;

		function dat(slv    : T_SLV_8)                    return T_SIM_STREAM_WORD_8;
		function dat(slvv   : T_SLVV_8)                   return T_SIM_STREAM_WORD_VECTOR_8;
		function dat(slv    : T_SLV_32)                   return T_SIM_STREAM_WORD_32;
		function dat(slvv   : T_SLVV_32)                  return T_SIM_STREAM_WORD_VECTOR_32;
		function sof(slv    : T_SLV_8)                    return T_SIM_STREAM_WORD_8;
		function sof(slvv   : T_SLVV_8)                   return T_SIM_STREAM_WORD_VECTOR_8;
		function sof(slv    : T_SLV_32)                   return T_SIM_STREAM_WORD_32;
		function sof(slvv   : T_SLVV_32)                  return T_SIM_STREAM_WORD_VECTOR_32;
		function eof(slv    : T_SLV_8)                    return T_SIM_STREAM_WORD_8;
		function eof(slvv   : T_SLVV_8)                   return T_SIM_STREAM_WORD_VECTOR_8;
		function eof(slv    : T_SLV_32)                   return T_SIM_STREAM_WORD_32;
		function eof(slvv   : T_SLVV_32)                  return T_SIM_STREAM_WORD_VECTOR_32;
		function eof(stmw   : T_SIM_STREAM_WORD_8)        return T_SIM_STREAM_WORD_8;
		function eof(stmwv  : T_SIM_STREAM_WORD_VECTOR_8) return T_SIM_STREAM_WORD_VECTOR_8;
		function eof(stmw   : T_SIM_STREAM_WORD_32)       return T_SIM_STREAM_WORD_32;
		function eofg(stmw  : T_SIM_STREAM_WORD_8)        return T_SIM_STREAM_WORD_8;
		function eofg(stmwv : T_SIM_STREAM_WORD_VECTOR_8) return T_SIM_STREAM_WORD_VECTOR_8;
		function eofg(stmw  : T_SIM_STREAM_WORD_32)       return T_SIM_STREAM_WORD_32;

		function to_string(stmw : T_SIM_STREAM_WORD_8)    return string;
		function to_string(stmw : T_SIM_STREAM_WORD_32)   return string;

		-- checksum functions
		-- ================================================================
		function sim_CRC8(words        : T_SIM_STREAM_WORD_VECTOR_8) return std_logic_vector;
--    function sim_CRC16(words    : T_SIM_STREAM_WORD_VECTOR_8) return STD_LOGIC_VECTOR;

		function Stream_serialize(Data      : std_logic_vector; BE : std_logic_vector; SoF : std_logic; EoF : std_logic) return std_logic_vector;
		function Stream_get_EoF(Serialized  : std_logic_vector) return std_logic;
		function Stream_get_SoF(Serialized  : std_logic_vector) return std_logic;
		function Stream_get_BE(Serialized   : std_logic_vector) return std_logic_vector;
		function Stream_get_Data(Serialized : std_logic_vector) return std_logic_vector;

end;

package body stream is
		function Initialize(DataBits : natural; MetaBits : positive := 1; Value : std_logic := 'Z') return T_Stream_M2S is
				constant init : T_Stream_M2S(
								Data(DataBits -1 downto 0),
								Meta(MetaBits -1 downto 0),
								BE((DataBits / 8) -1 downto 0)
						) := (
								Valid => Value,
								Data  => (others => Value),
								BE    => (others => Value),
								SoF   => Value,
								EoF   => Value,
								Meta  => (others => Value)
						);
		begin
				return init;
		end function;

		function Initialize(MetaBits : positive := 1; Value : std_logic := 'Z') return T_Stream_S2M is
				constant init : T_Stream_S2M(Meta(MetaBits -1 downto 0)) := (
						ACK  => Value,
						Meta => (others => Value)
				);
		begin
				return init;
		end function;

		function Get_Valid_vector(M2S : T_Stream_M2S_VECTOR) return std_logic_vector is
				variable temp : std_logic_vector(M2S'range);
		begin
				for i in temp'range loop
						temp(i) := M2S(i).Valid;
				end loop;
				return temp;
		end function;

		function Get_SoF_vector(  M2S : T_Stream_M2S_VECTOR) return std_logic_vector is
				variable temp : std_logic_vector(M2S'range);
		begin
				for i in temp'range loop
						temp(i) := M2S(i).SoF;
				end loop;
				return temp;
		end function;

		function Get_EoF_vector(  M2S : T_Stream_M2S_VECTOR) return std_logic_vector is
				variable temp : std_logic_vector(M2S'range);
		begin
				for i in temp'range loop
						temp(i) := M2S(i).EoF;
				end loop;
				return temp;
		end function;

		function Get_ACK_vector(  S2M : T_Stream_S2M_VECTOR) return std_logic_vector is
				variable temp : std_logic_vector(S2M'range);
		begin
				for i in temp'range loop
						temp(i) := S2M(i).ACK;
				end loop;
				return temp;
		end function;

		function Get_Data_vector( M2S : T_Stream_M2S_VECTOR) return T_SLVV is
				variable temp : T_SLVV(M2S'range)(M2S(M2S'low).Data'range);
		begin
				for i in temp'range loop
						temp(i) := M2S(i).Data;
				end loop;
				return temp;
		end function;

		function Get_BE_vector(   M2S : T_Stream_M2S_VECTOR) return T_SLVV is
				variable temp : T_SLVV(M2S'range)(M2S(M2S'low).BE'range);
		begin
				for i in temp'range loop
						temp(i) := M2S(i).BE;
				end loop;
				return temp;
		end function;

		function Get_Meta_vector( M2S : T_Stream_M2S_VECTOR) return T_SLVV is
				variable temp : T_SLVV(M2S'range)(M2S(M2S'low).Meta'range);
		begin
				for i in temp'range loop
						temp(i) := M2S(i).Meta;
				end loop;
				return temp;
		end function;

		function Get_Meta_vector( S2M : T_Stream_S2M_VECTOR) return T_SLVV is
				variable temp : T_SLVV(S2M'range)(S2M(S2M'low).Meta'range);
		begin
				for i in temp'range loop
						temp(i) := S2M(i).Meta;
				end loop;
				return temp;
		end function;


		function to_slv(val : T_FRAMEGEN_COMMAND) return std_logic_vector is
		begin
				return std_logic_vector(to_unsigned(T_FRAMEGEN_COMMAND'pos(val),log2ceilnz(T_FRAMEGEN_COMMAND'Count)));
		end function;

		function to_FRAMEGEN_COMMAND(slv : std_logic_vector) return T_FRAMEGEN_COMMAND is
		begin
				if to_integer(unsigned(slv)) > T_FRAMEGEN_COMMAND'count -1 then
						return FRAMEGEN_CMD_NONE;
				else
						return T_FRAMEGEN_COMMAND'val(to_integer(unsigned(slv)));
				end if;
		end function;

		function to_slv(val : T_FRAMEGEN_STATUS) return std_logic_vector is
		begin
				return std_logic_vector(to_unsigned(T_FRAMEGEN_STATUS'pos(val),log2ceilnz(T_FRAMEGEN_STATUS'Count)));
		end function;

		function to_FRAMEGEN_STATUS(slv : std_logic_vector) return T_FRAMEGEN_STATUS is
		begin
				if to_integer(unsigned(slv)) > T_FRAMEGEN_STATUS'count -1 then
						return FRAMEGEN_STATUS_ERROR;
				else
						return T_FRAMEGEN_STATUS'val(to_integer(unsigned(slv)));
				end if;
		end function;

		function CountPatterns(Data : T_SIM_STREAM_WORD_VECTOR_8) return natural is
		begin
				for i in 0 to Data'length - 1 loop
						if (Data(i).EOFG = TRUE) then
								return i + 1;
						end if;
				end loop;

				return 0;
		end;

		function CountPatterns(Data : T_SIM_STREAM_WORD_VECTOR_32) return natural is
		begin
				for i in 0 to Data'length - 1 loop
						if (Data(i).EOFG = TRUE) then
								return i + 1;
						end if;
				end loop;

				return 0;
		end;

		function dat(slv : T_SLV_8) return T_SIM_STREAM_WORD_8 is
				variable result : T_SIM_STREAM_WORD_8;
		begin
				result := (Valid => '1', Data    => slv,    SOF    => '0',    EOF    => '0', Ready => '-', EOFG => FALSE);
				report "dat: " & to_string(result) severity NOTE;
				return result;
		end;

		function dat(slvv : T_SLVV_8) return T_SIM_STREAM_WORD_VECTOR_8 is
				variable result            : T_SIM_STREAM_WORD_VECTOR_8(slvv'range);
		begin
				for i in slvv'range loop
						result(i)        := dat(slvv(i));
				end loop;

				return result;
		end;

		function dat(slv : T_SLV_32) return T_SIM_STREAM_WORD_32 is
				variable result : T_SIM_STREAM_WORD_32;
		begin
				result := (Valid => '1', Data    => slv,    SOF    => '0',    EOF    => '0', Ready => '-', EOFG => FALSE);
				report "dat: " & to_string(result) severity NOTE;
				return result;
		end;

		function dat(slvv : T_SLVV_32) return T_SIM_STREAM_WORD_VECTOR_32 is
				variable result            : T_SIM_STREAM_WORD_VECTOR_32(slvv'range);
		begin
				for i in slvv'range loop
						result(i)        := dat(slvv(i));
				end loop;

				return result;
		end;

		function sof(slv : T_SLV_8) return T_SIM_STREAM_WORD_8 is
				variable result : T_SIM_STREAM_WORD_8;
		begin
				result := (Valid => '1', Data    => slv,    SOF    => '1',    EOF    => '0', Ready => '-', EOFG => FALSE);
				report "sof: " & to_string(result) severity NOTE;
				return result;
		end;

		function sof(slvv : T_SLVV_8) return T_SIM_STREAM_WORD_VECTOR_8 is
				variable result            : T_SIM_STREAM_WORD_VECTOR_8(slvv'range);
		begin
				result(slvv'low)        := sof(slvv(slvv'low));
				for i in slvv'low + 1 to slvv'high loop
						result(i)        := dat(slvv(i));
				end loop;
				return result;
		end;

		function sof(slv : T_SLV_32) return T_SIM_STREAM_WORD_32 is
				variable result : T_SIM_STREAM_WORD_32;
		begin
				result := (Valid => '1', Data    => slv,    SOF    => '1',    EOF    => '0', Ready => '-', EOFG => FALSE);
				report "sof: " & to_string(result) severity NOTE;
				return result;
		end;

		function sof(slvv : T_SLVV_32) return T_SIM_STREAM_WORD_VECTOR_32 is
				variable result            : T_SIM_STREAM_WORD_VECTOR_32(slvv'range);
		begin
				result(slvv'low)        := sof(slvv(slvv'low));
				for i in slvv'low + 1 to slvv'high loop
						result(i)        := dat(slvv(i));
				end loop;
				return result;
		end;

		function eof(slv : T_SLV_8) return T_SIM_STREAM_WORD_8 is
				variable result : T_SIM_STREAM_WORD_8;
		begin
				result := (Valid => '1', Data    => slv,    SOF    => '0',    EOF    => '1', Ready => '-', EOFG => FALSE);
				report "eof: " & to_string(result) severity NOTE;
				return result;
		end;

		function eof(slvv : T_SLVV_8) return T_SIM_STREAM_WORD_VECTOR_8 is
				variable result            : T_SIM_STREAM_WORD_VECTOR_8(slvv'range);
		begin
				for i in slvv'low to slvv'high - 1 loop
						result(i)        := dat(slvv(i));
				end loop;
				result(slvv'high)        := eof(slvv(slvv'high));
				return result;
		end;

		function eof(slv : T_SLV_32) return T_SIM_STREAM_WORD_32 is
				variable result : T_SIM_STREAM_WORD_32;
		begin
				result := (Valid => '1', Data    => slv,    SOF    => '0',    EOF    => '1', Ready => '-', EOFG => FALSE);
				report "eof: " & to_string(result) severity NOTE;
				return result;
		end;

		function eof(slvv : T_SLVV_32) return T_SIM_STREAM_WORD_VECTOR_32 is
				variable result            : T_SIM_STREAM_WORD_VECTOR_32(slvv'range);
		begin
				for i in slvv'low to slvv'high - 1 loop
						result(i)        := dat(slvv(i));
				end loop;
				result(slvv'high)        := eof(slvv(slvv'high));
				return result;
		end;

		function eof(stmw : T_SIM_STREAM_WORD_8) return T_SIM_STREAM_WORD_8 is
		begin
				return T_SIM_STREAM_WORD_8'(
						Valid => stmw.Valid,
						Data  => stmw.Data,
						SOF   => stmw.SOF,
						EOF   => '1',
						Ready => '-',
						EOFG  => stmw.EOFG);
		end function;

		function eof(stmw : T_SIM_STREAM_WORD_32) return T_SIM_STREAM_WORD_32 is
		begin
				return T_SIM_STREAM_WORD_32'(
						Valid => stmw.Valid,
						Data  => stmw.Data,
						SOF   => stmw.SOF,
						EOF   => '1',
						Ready => '-',
						EOFG  => stmw.EOFG);
		end function;

		function eof(stmwv : T_SIM_STREAM_WORD_VECTOR_8) return T_SIM_STREAM_WORD_VECTOR_8 is
				variable result            : T_SIM_STREAM_WORD_VECTOR_8(stmwv'range);
		begin
				for i in stmwv'low to stmwv'high - 1 loop
						result(i) := stmwv(i);
				end loop;
				result(stmwv'high) := eof(stmwv(stmwv'high));

				return result;
		end;

		function eofg(stmw : T_SIM_STREAM_WORD_8) return T_SIM_STREAM_WORD_8 is
		begin
				return T_SIM_STREAM_WORD_8'(
						Valid => stmw.Valid,
						Data  => stmw.Data,
						SOF   => stmw.SOF,
						EOF   => stmw.EOF,
						Ready => stmw.Ready,
						EOFG  => TRUE);
		end function;

		function eofg(stmw : T_SIM_STREAM_WORD_32) return T_SIM_STREAM_WORD_32 is
		begin
				return T_SIM_STREAM_WORD_32'(
						Valid => stmw.Valid,
						Data  => stmw.Data,
						SOF   => stmw.SOF,
						EOF   => stmw.EOF,
						Ready => stmw.Ready,
						EOFG  => TRUE);
		end function;

		function eofg(stmwv : T_SIM_STREAM_WORD_VECTOR_8) return T_SIM_STREAM_WORD_VECTOR_8 is
				variable result : T_SIM_STREAM_WORD_VECTOR_8(stmwv'range);
		begin
				for i in stmwv'low to stmwv'high - 1 loop
						result(i) := stmwv(i);
				end loop;
				result(stmwv'high) := eofg(stmwv(stmwv'high));

				return result;
		end;

		function to_flag1_string(stmw : T_SIM_STREAM_WORD_8) return string is
				variable flag : std_logic_vector(2 downto 0)    := to_sl(stmw.EOFG) & stmw.EOF & stmw.SOF;
		begin
				case flag is
						when "000"  => return "";
						when "001"  => return "SOF";
						when "010"  => return "EOF";
						when "011"  => return "SOF+EOF";
						when "100"  => return "*";
						when "101"  => return "SOF*";
						when "110"  => return "EOF*";
						when "111"  => return "SOF+EOF*";
						when others => return "ERROR";
				end case;
		end function;

		function to_flag1_string(stmw : T_SIM_STREAM_WORD_32) return string is
				variable flag : std_logic_vector(2 downto 0)    := to_sl(stmw.EOFG) & stmw.EOF & stmw.SOF;
		begin
				case flag is
						when "000"  => return "";
						when "001"  => return "SOF";
						when "010"  => return "EOF";
						when "011"  => return "SOF+EOF";
						when "100"  => return "*";
						when "101"  => return "SOF*";
						when "110"  => return "EOF*";
						when "111"  => return "SOF+EOF*";
						when others => return "ERROR";
				end case;
		end function;

		function to_flag2_string(stmw : T_SIM_STREAM_WORD_8) return string is
				variable flag : std_logic_vector(1 downto 0)    := stmw.Ready & stmw.Valid;
		begin
				case flag is
						when "00"   => return "  ";
						when "01"   => return " V";
						when "10"   => return "R ";
						when "11"   => return "RV";
						when "-0"   => return "- ";
						when "-1"   => return "-V";
						when others => return "??";
				end case;
		end function;

		function to_flag2_string(stmw : T_SIM_STREAM_WORD_32) return string is
				variable flag : std_logic_vector(1 downto 0)    := stmw.Ready & stmw.Valid;
		begin
				case flag is
						when "00"   => return "  ";
						when "01"   => return " V";
						when "10"   => return "R ";
						when "11"   => return "RV";
						when "-0"   => return "- ";
						when "-1"   => return "-V";
						when others => return "??";
				end case;
		end function;

		function to_string(stmw : T_SIM_STREAM_WORD_8) return string is
		begin
				return to_flag2_string(stmw) & " 0x" & to_string(stmw.Data, 'h') & " " & to_flag1_string(stmw);
		end function;

		function to_string(stmw : T_SIM_STREAM_WORD_32) return string is
		begin
				return to_flag2_string(stmw) & " 0x" & to_string(stmw.Data, 'h') & " " & to_flag1_string(stmw);
		end function;

		-- checksum functions
		-- ================================================================
--    -- Private function to_01 copied from GlobalTypes
--    function to_01(slv : STD_LOGIC_VECTOR) return STD_LOGIC_VECTOR is
--    begin
--      return  to_stdlogicvector(to_bitvector(slv));
--    end;

		function sim_CRC8(words : T_SIM_STREAM_WORD_VECTOR_8) return std_logic_vector is
				constant CRC8_INIT       : T_SLV_8 := x"FF";
				constant CRC8_POLYNOMIAL : T_SLV_8 := x"31";            -- 0x131

				variable CRC8_Value      : T_SLV_8 := CRC8_INIT;

--        variable Pattern                        : T_DATAFifO_PATTERN;
				variable Word            : unsigned(T_SLV_8'range);
		begin
				-- report "Computing CRC8 for Words " & to_string(words'low) & " to " & to_string(words'high) severity NOTE;

				for i in words'range loop
						if (words(i).Valid = '1') then
								Word    := to_01(unsigned(words(i).Data));

--                    assert (J > 9) report str_merge("  Word: 0x", hstr(Word), "    CRC16_Value: 0x", hstr(CRC16_Value)) severity NOTE;

								for j in Word'range loop
												CRC8_Value := (CRC8_Value(CRC8_Value'high - 1 downto 0) & '0') xor (CRC8_POLYNOMIAL and (CRC8_POLYNOMIAL'range => (Word(j) xor CRC8_Value(CRC8_Value'high))));
								end loop;
						end if;

						exit when (words(i).EOFG = TRUE);
				end loop;

				-- report "  CRC8: 0x" & to_string(CRC8_Value, 'h') severity NOTE;

				return CRC8_Value;
		end;

--    function sim_CRC16(words : T_SIM_STREAM_WORD_VECTOR_8) return STD_LOGIC_VECTOR is
--        constant CRC16_INIT                    : T_SLV_16                    := x"FFFF";
--        constant CRC16_POLYNOMIAL        : T_SLV_16                    := x"8005";            -- 0x18005
--
--        variable CRC16_Value                : T_SLV_16                    := CRC16_INIT;
--
--        variable Pattern                        : T_DATAFifO_PATTERN;
--        variable Word                                : T_SLV_32;
--    begin
--        report str_merge("Computing CRC16 for Frames ", str(Frames'low), " to ", str(Frames'high)) severity NOTE;
--
--        for i in Frames'range loop
--            NEXT when (NOT ((Frames(i).Direction    = DEV_HOST) AND (Frames(i).DataFifOPatterns(0).Data(7 downto 0) = x"46")));
--
----            report Frames(i).Name severity NOTE;
--
--            for j in 1 to Frames(i).Count - 1 loop
--                Pattern        := Frames(i).DataFifOPatterns(J);
--
--                if (Pattern.Valid = '1') then
--                    Word    := to_01(Pattern.Data);
--
----                    assert (J > 9) report str_merge("  Word: 0x", hstr(Word), "    CRC16_Value: 0x", hstr(CRC16_Value)) severity NOTE;
--
--                    for k in Word'range loop
--                        CRC16_Value := (CRC16_Value(CRC16_Value'high - 1 downto 0) & '0') XOR (CRC16_POLYNOMIAL AND (CRC16_POLYNOMIAL'range => (Word(K) XOR CRC16_Value(CRC16_Value'high))));
--                    end loop;
--                end if;
--
--                EXIT when (Pattern.EOTP = TRUE);
--            end loop;
--        end loop;
--
--        report str_merge("  CRC16: 0x", hstr(CRC16_Value)) severity NOTE;
--
--        return CRC16_Value;
--    end;


		function Stream_serialize(Data : std_logic_vector; BE : std_logic_vector; SoF : std_logic; EoF : std_logic) return std_logic_vector is
				variable temp : std_logic_vector(Data'length + BE'length +1 downto 0);
		begin
				assert Data'length / 8 = BE'length report "PoC.stream.pkg:: Stream_serialize: Data-Width / 8 is not equal to BE-Width!" severity warning;
				temp(Data'length -1 downto 0) := Data;
				temp(Data'length + BE'length -1 downto Data'length) := BE;
				temp(Data'length + BE'length) := SoF;
				temp(Data'length + BE'length +1) := EoF;
				return temp;
		end function;

		function Stream_get_EoF(Serialized : std_logic_vector) return std_logic is
		begin
				return Serialized(Serialized'high);
		end function;

		function Stream_get_SoF(Serialized : std_logic_vector) return std_logic is
		begin
				return Serialized(Serialized'high -1);
		end function;

		function Stream_get_BE(Serialized : std_logic_vector) return std_logic_vector is
				constant num_Bytes : natural := (Serialized'length -2) / 9;
		begin
				return Serialized(Serialized'high -2 downto 8 * num_Bytes);
		end function;

		function Stream_get_Data(Serialized : std_logic_vector) return std_logic_vector is
				constant num_Bytes : natural := (Serialized'length -2) / 9;
		begin
				return Serialized(8 * num_Bytes -1 downto 0);
		end function;


		function Resize_meta(    M2S : T_Stream_M2S; length : natural) return T_Stream_M2S is
				variable temp : T_Stream_M2S(Data(M2S.Data'range), BE(M2S.BE'range), Meta(length -1 downto 0));
		begin
				temp.Valid := M2S.Valid;
				temp.Data  := M2S.Data;
				temp.BE    := M2S.BE;
				temp.SoF   := M2S.SoF;
				temp.EoF   := M2S.EoF;
				temp.Meta  := resize(M2S.Meta, length);
				return temp;
		end function;

		function Replace_meta(   M2S : T_Stream_M2S; slv : std_logic_vector) return T_Stream_M2S is
				variable temp : T_Stream_M2S(Data(M2S.Data'range), BE(M2S.BE'range), Meta(slv'range));
		begin
				temp.Valid := M2S.Valid;
				temp.Data  := M2S.Data;
				temp.BE    := M2S.BE;
				temp.SoF   := M2S.SoF;
				temp.EoF   := M2S.EoF;
				temp.Meta  := slv;
				return temp;
		end function;


		function ite(cond : boolean; value1 : T_Stream_Glue_Meta_Kind; value2 : T_Stream_Glue_Meta_Kind) return T_Stream_Glue_Meta_Kind is
		begin
				if cond then
						return value1;
				else
						return value2;
				end if;
		end function;

end package body;


use work.Stream.all;

package Stream_Sized is
		generic (
				DATA_BITS : positive;
				META_BITS : positive := 1;
				BE_BITS   : positive := DATA_BITS / 8
		);

		subtype SIZED_M2S is T_STREAM_M2S(
				Data(DATA_BITS - 1 downto 0),
				BE(BE_BITS -1 downto 0),
				Meta(META_BITS - 1 downto 0)
		);
		subtype SIZED_S2M is T_STREAM_S2M(
				Meta(META_BITS - 1 downto 0)
		);

		subtype SIZED_M2S_VECTOR is T_STREAM_M2S_VECTOR(open)(
				Data(DATA_BITS - 1 downto 0),
				BE(BE_BITS -1 downto 0),
				Meta(META_BITS - 1 downto 0)
		);
		subtype SIZED_S2M_VECTOR is T_STREAM_S2M_VECTOR(open)(
				Meta(META_BITS - 1 downto 0)
		);
end package;
