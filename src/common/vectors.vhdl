-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Martin Zabel
--                  Patrick Lehmann
--                  Stefan Unrein
--
-- Package:         Common functions and types
--
-- Description:
-- -------------------------------------
--    For detailed documentation see below.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;
use     PoC.strings.all;


package vectors is
	-- ==========================================================================
	-- Type declarations
	-- ==========================================================================
	-- STD_LOGIC_VECTORs
	subtype T_SLV_2             is std_logic_vector(1 downto 0);
	subtype T_SLV_3             is std_logic_vector(2 downto 0);
	subtype T_SLV_4             is std_logic_vector(3 downto 0);
	subtype T_SLV_8             is std_logic_vector(7 downto 0);
	subtype T_SLV_12            is std_logic_vector(11 downto 0);
	subtype T_SLV_16            is std_logic_vector(15 downto 0);
	subtype T_SLV_24            is std_logic_vector(23 downto 0);
	subtype T_SLV_32            is std_logic_vector(31 downto 0);
	subtype T_SLV_48            is std_logic_vector(47 downto 0);
	subtype T_SLV_64            is std_logic_vector(63 downto 0);
	subtype T_SLV_96            is std_logic_vector(95 downto 0);
	subtype T_SLV_128           is std_logic_vector(127 downto 0);
	subtype T_SLV_256           is std_logic_vector(255 downto 0);
	subtype T_SLV_512           is std_logic_vector(511 downto 0);
	-- UNSIGNEDs
	subtype T_SLU_2             is unsigned(1 downto 0);
	subtype T_SLU_3             is unsigned(2 downto 0);
	subtype T_SLU_4             is unsigned(3 downto 0);
	subtype T_SLU_8             is unsigned(7 downto 0);
	subtype T_SLU_12            is unsigned(11 downto 0);
	subtype T_SLU_16            is unsigned(15 downto 0);
	subtype T_SLU_24            is unsigned(23 downto 0);
	subtype T_SLU_32            is unsigned(31 downto 0);
	subtype T_SLU_48            is unsigned(47 downto 0);
	subtype T_SLU_64            is unsigned(63 downto 0);
	subtype T_SLU_96            is unsigned(95 downto 0);
	subtype T_SLU_128           is unsigned(127 downto 0);
	subtype T_SLU_256           is unsigned(255 downto 0);
	subtype T_SLU_512           is unsigned(511 downto 0);
	-- SIGNEDs
	subtype T_SLS_2             is signed(1 downto 0);
	subtype T_SLS_3             is signed(2 downto 0);
	subtype T_SLS_4             is signed(3 downto 0);
	subtype T_SLS_8             is signed(7 downto 0);
	subtype T_SLS_12            is signed(11 downto 0);
	subtype T_SLS_16            is signed(15 downto 0);
	subtype T_SLS_24            is signed(23 downto 0);
	subtype T_SLS_32            is signed(31 downto 0);
	subtype T_SLS_48            is signed(47 downto 0);
	subtype T_SLS_64            is signed(63 downto 0);
	subtype T_SLS_96            is signed(95 downto 0);
	subtype T_SLS_128           is signed(127 downto 0);
	subtype T_SLS_256           is signed(255 downto 0);
	subtype T_SLS_512           is signed(511 downto 0);

	-- Data BE Vector
	type T_DATA_BE is record
		be        : std_logic_vector;
		data      : std_logic_vector;
	end record;

	type T_DATA_BE_VECTOR is array(natural range <>) of T_DATA_BE;

	-- STD_LOGIC_VECTOR_VECTORs
	type    T_SLVV              is array(NATURAL range <>) of STD_LOGIC_VECTOR;          -- VHDL 2008 syntax - not yet supported by Xilinx
	subtype T_SLVV_2            is T_SLVV(open)(1 downto 0);
	subtype T_SLVV_3            is T_SLVV(open)(2 downto 0);
	subtype T_SLVV_4            is T_SLVV(open)(3 downto 0);
	subtype T_SLVV_8            is T_SLVV(open)(7 downto 0);
	subtype T_SLVV_12           is T_SLVV(open)(11 downto 0);
	subtype T_SLVV_16           is T_SLVV(open)(15 downto 0);
	subtype T_SLVV_24           is T_SLVV(open)(23 downto 0);
	subtype T_SLVV_32           is T_SLVV(open)(31 downto 0);
	subtype T_SLVV_48           is T_SLVV(open)(47 downto 0);
	subtype T_SLVV_64           is T_SLVV(open)(63 downto 0);
	subtype T_SLVV_128          is T_SLVV(open)(127 downto 0);
	subtype T_SLVV_256          is T_SLVV(open)(255 downto 0);
	subtype T_SLVV_512          is T_SLVV(open)(511 downto 0);
	-- UNSIGNED_VECTORs
	type    T_SLUV              is array(NATURAL range <>) of UNSIGNED;          -- VHDL 2008 syntax - not yet supported by Xilinx
	subtype T_SLUV_2            is T_SLUV(open)(1 downto 0);
	subtype T_SLUV_3            is T_SLUV(open)(2 downto 0);
	subtype T_SLUV_4            is T_SLUV(open)(3 downto 0);
	subtype T_SLUV_8            is T_SLUV(open)(7 downto 0);
	subtype T_SLUV_12           is T_SLUV(open)(11 downto 0);
	subtype T_SLUV_16           is T_SLUV(open)(15 downto 0);
	subtype T_SLUV_24           is T_SLUV(open)(23 downto 0);
	subtype T_SLUV_32           is T_SLUV(open)(31 downto 0);
	subtype T_SLUV_48           is T_SLUV(open)(47 downto 0);
	subtype T_SLUV_64           is T_SLUV(open)(63 downto 0);
	subtype T_SLUV_128          is T_SLUV(open)(127 downto 0);
	subtype T_SLUV_256          is T_SLUV(open)(255 downto 0);
	subtype T_SLUV_512          is T_SLUV(open)(511 downto 0);
	-- SIGNED_VECTORs
	type    T_SLSV              is array(NATURAL range <>) of SIGNED;          -- VHDL 2008 syntax - not yet supported by Xilinx
	subtype T_SLSV_2            is T_SLSV(open)(1 downto 0);
	subtype T_SLSV_3            is T_SLSV(open)(2 downto 0);
	subtype T_SLSV_4            is T_SLSV(open)(3 downto 0);
	subtype T_SLSV_8            is T_SLSV(open)(7 downto 0);
	subtype T_SLSV_12           is T_SLSV(open)(11 downto 0);
	subtype T_SLSV_16           is T_SLSV(open)(15 downto 0);
	subtype T_SLSV_24           is T_SLSV(open)(23 downto 0);
	subtype T_SLSV_32           is T_SLSV(open)(31 downto 0);
	subtype T_SLSV_48           is T_SLSV(open)(47 downto 0);
	subtype T_SLSV_64           is T_SLSV(open)(63 downto 0);
	subtype T_SLSV_128          is T_SLSV(open)(127 downto 0);
	subtype T_SLSV_256          is T_SLSV(open)(255 downto 0);
	subtype T_SLSV_512          is T_SLSV(open)(511 downto 0);

	-- STD_LOGIC_MATRIXs
	type    T_SLM               is array(natural range <>, natural range <>) of std_logic;

	-- STD_LOGIC_3D_MATRIXs
	type    T_SLM_8             is array(natural range <>, natural range <>) of T_SLV_8;
	type    T_SLM_32            is array(natural range <>, natural range <>) of T_SLV_32;
	-- ATTENTION:
	-- 1. you MUST initialize your matrix signal with 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	--    Example: signal myMatrix  : T_SLM(3 downto 0, 7 downto 0)      := (others => (others => 'Z'));
	-- 2. Xilinx iSIM bug: DON'T use myMatrix'range(n) for n >= 2
	--    myMatrix'range(2) returns always myMatrix'range(1); see work-around notes below
	--
	-- USAGE NOTES:
	--  dimension 1 => rows       - e.g. Words
	--  dimension 2 => columns    - e.g. Bits/Bytes in a word
	--
	-- WORKAROUND: for Xilinx ISE/iSim
	--  Version:  14.2
	--  Issue:    myMatrix'range(n) for n >= 2 returns always myMatrix'range(1)

	-- ==========================================================================
	-- Function declarations
	-- ==========================================================================
	-- slicing boundary calculations
	function low (lenvec : T_POSVEC; index : natural) return natural;
	function low (lenvec : T_NATVEC; index : natural) return natural;
	function high(lenvec : T_POSVEC; index : natural) return natural;
	function high(lenvec : T_NATVEC; index : natural) return natural;

	-- Make vector of constant
	function mk_const(const : std_logic;   length : natural) return std_logic_vector;
	function mk_const(const : T_SLV_8;     length : natural) return T_SLVV_8;  -- FIXME; input should be std_logic_vector and output any SLVV
	-- FIXME: provide also for SLUV, SLSV

	-- Assign procedures: assign_*
	procedure assign_row(signal slm : out T_SLM   ; slv : std_logic_vector; constant RowIndex : natural);                                  -- assign vector to complete row
	procedure assign_row(signal slm : out T_SLM_8 ; slv : T_SLVV_8        ; constant RowIndex : natural);                                  -- assign vector to complete row
	procedure assign_row(signal slm : out T_SLM_32; slv : T_SLVV_32       ; constant RowIndex : natural);                                  -- assign vector to complete row
	procedure assign_row(signal slm : out T_SLM   ; slv : std_logic_vector; constant RowIndex : natural; Position : natural);              -- assign short vector to row starting at position
	procedure assign_row(signal slm : out T_SLM   ; slv : std_logic_vector; constant RowIndex : natural; High : natural; Low : natural);    -- assign short vector to row in range high:low
	procedure assign_row(signal slm : out T_SLM_8 ; slv : T_SLVV_8        ; constant RowIndex : natural; High : natural; Low : natural);    -- assign short vector to row in range high:low
	procedure assign_col(signal slm : out T_SLM   ; slv : std_logic_vector; constant ColIndex : natural);                                  -- assign vector to complete column
	-- ATTENTION:  see T_SLM definition for further details and work-arounds

	-- Matrix to matrix conversion: slm_slice*
	function slm_slice(slm : T_SLM; RowIndex : natural; ColIndex : natural; Height : natural; Width : natural) return T_SLM;            -- get submatrix in boundingbox RowIndex,ColIndex,Height,Width
	function slm_slice_rows(slm : T_SLM; High : natural; Low : natural) return T_SLM;                                                   -- get submatrix / all rows in RowIndex range high:low
	function slm_slice_cols(slm : T_SLM; High : natural; Low : natural) return T_SLM;                                                   -- get submatrix / all columns in ColIndex range high:low

	-- Boolean Operators
	function "not" (a    : t_slm) return t_slm;
	function "and" (a, b : t_slm) return t_slm;
	function "or"  (a, b : t_slm) return t_slm;
	function "xor" (a, b : t_slm) return t_slm;
	function "nand"(a, b : t_slm) return t_slm;
	function "nor" (a, b : t_slm) return t_slm;
	function "xnor"(a, b : t_slm) return t_slm;
	-- FIXME: add binary operators for SLVV, SLUV, SLSV
	-- FIXME: add unary operators

	-- Matrix concatenation: slm_merge_*
	function slm_merge_rows(slm1 : T_SLM; slm2 : T_SLM) return T_SLM;
	function slm_merge_cols(slm1 : T_SLM; slm2 : T_SLM) return T_SLM;

	-- Matrix to vector conversion: get_*
	function get_col(slm     : T_SLM    ; ColIndex : natural) return std_logic_vector;                                  -- get a matrix column
	function get_row(slm     : T_SLM    ; RowIndex : natural) return std_logic_vector;                                  -- get a matrix row
	function get_row(slm     : T_SLM_8  ; RowIndex : natural) return T_SLVV_8;                                  -- get a matrix row
	function get_row(slm     : T_SLM_32 ; RowIndex : natural) return T_SLVV_32;                                  -- get a matrix row
	function get_row(slm     : T_SLM    ; RowIndex : natural; Length : positive) return std_logic_vector;              -- get a matrix row of defined length [length - 1 downto 0]
	function get_row(slm     : T_SLM    ; RowIndex : natural; High : natural; Low : natural) return std_logic_vector;    -- get a sub vector of a matrix row at high:low

	-- Vector-vector to vector conversion: extract_*
	function extract_row(slvv : T_SLVV; RowIndex : natural) return std_logic_vector;
	function extract_row(sluv : T_SLUV; RowIndex : natural) return unsigned;
	function extract_row(slsv : T_SLSV; RowIndex : natural) return signed;

	-- Convert to vector: to_slv
	function to_slv(slvv : T_SLVV)                return std_logic_vector;                -- convert vector-vector to flatten vector
	function to_slv(sluv : T_SLUV)                return std_logic_vector;                --
	function to_slv(slsv : T_SLSV)                return std_logic_vector;                --
	function to_unsigned(sluv : T_SLUV)           return unsigned;                        --
	function to_signed(slsv : T_SLSV)             return signed;                          --

	function to_slv(slm : T_SLM)                  return std_logic_vector;                -- convert matrix to flatten vector
	function to_unsigned(slm : T_SLM)             return unsigned;                        -- convert matrix to flatten vector
	function to_signed(slm : T_SLM)               return signed;                          -- convert matrix to flatten vector

	-- Convert flat vector to a vector-vector: to_slvv_*
	function to_slvv(slv : std_logic_vector; sub_element_length : natural)      return T_SLVV;        --
	function to_slvv_2(slv : std_logic_vector)    return T_SLVV_2;                        --
	function to_slvv_4(slv : std_logic_vector)    return T_SLVV_4;                        --
	function to_slvv_8(slv : std_logic_vector)    return T_SLVV_8;                        --
	function to_slvv_12(slv : std_logic_vector)   return T_SLVV_12;                       --
	function to_slvv_16(slv : std_logic_vector)   return T_SLVV_16;                       --
	function to_slvv_32(slv : std_logic_vector)   return T_SLVV_32;                       --
	function to_slvv_64(slv : std_logic_vector)   return T_SLVV_64;                       --
	function to_slvv_128(slv : std_logic_vector)  return T_SLVV_128;                      --
	function to_slvv_256(slv : std_logic_vector)  return T_SLVV_256;                      --
	function to_slvv_512(slv : std_logic_vector)  return T_SLVV_512;                      --

	-- Convert flat vector to a vector-vector: to_sluv_*
	function to_sluv(us : unsigned; sub_element_length : natural) return T_SLUV; --
	function to_sluv_2(us : unsigned)    return T_SLUV_2;                        --
	function to_sluv_4(us : unsigned)    return T_SLUV_4;                        --
	function to_sluv_8(us : unsigned)    return T_SLUV_8;                        --
	function to_sluv_12(us : unsigned)   return T_SLUV_12;                       --
	function to_sluv_16(us : unsigned)   return T_SLUV_16;                       --
	function to_sluv_32(us : unsigned)   return T_SLUV_32;                       --
	function to_sluv_64(us : unsigned)   return T_SLUV_64;                       --
	function to_sluv_128(us : unsigned)  return T_SLUV_128;                      --
	function to_sluv_256(us : unsigned)  return T_SLUV_256;                      --
	function to_sluv_512(us : unsigned)  return T_SLUV_512;                      --

	-- Convert flat vector to a vector-vector: to_slsv_*
	function to_slsv(s : signed; sub_element_length : natural) return T_SLSV; --
	function to_slsv_2(s : signed)    return T_SLSV_2;                        --
	function to_slsv_4(s : signed)    return T_SLSV_4;                        --
	function to_slsv_8(s : signed)    return T_SLSV_8;                        --
	function to_slsv_12(s : signed)   return T_SLSV_12;                       --
	function to_slsv_16(s : signed)   return T_SLSV_16;                       --
	function to_slsv_32(s : signed)   return T_SLSV_32;                       --
	function to_slsv_64(s : signed)   return T_SLSV_64;                       --
	function to_slsv_128(s : signed)  return T_SLSV_128;                      --
	function to_slsv_256(s : signed)  return T_SLSV_256;                      --
	function to_slsv_512(s : signed)  return T_SLSV_512;                      --


	-- Convert matrix to avector-vector: to_slvv_*
	function to_slvv(slm : T_SLM)     return T_SLVV;                                      --
	function to_slvv_2(slm : T_SLM)   return T_SLVV_2;                                    --
	function to_slvv_4(slm : T_SLM)   return T_SLVV_4;                                    --
	function to_slvv_8(slm : T_SLM)   return T_SLVV_8;                                    --
	function to_slvv_12(slm : T_SLM)  return T_SLVV_12;                                   --
	function to_slvv_16(slm : T_SLM)  return T_SLVV_16;                                   --
	function to_slvv_32(slm : T_SLM)  return T_SLVV_32;                                   --
	function to_slvv_64(slm : T_SLM)  return T_SLVV_64;                                   --
	function to_slvv_128(slm : T_SLM) return T_SLVV_128;                                  --
	function to_slvv_256(slm : T_SLM) return T_SLVV_256;                                  --
	function to_slvv_512(slm : T_SLM) return T_SLVV_512;                                  --

	-- Convert matrix to avector-vector: to_sluv_*
	function to_sluv(slm : T_SLM)     return T_SLUV;                                      --
	function to_sluv_2(slm : T_SLM)   return T_SLUV_2;                                    --
	function to_sluv_4(slm : T_SLM)   return T_SLUV_4;                                    --
	function to_sluv_8(slm : T_SLM)   return T_SLUV_8;                                    --
	function to_sluv_12(slm : T_SLM)  return T_SLUV_12;                                   --
	function to_sluv_16(slm : T_SLM)  return T_SLUV_16;                                   --
	function to_sluv_32(slm : T_SLM)  return T_SLUV_32;                                   --
	function to_sluv_64(slm : T_SLM)  return T_SLUV_64;                                   --
	function to_sluv_128(slm : T_SLM) return T_SLUV_128;                                  --
	function to_sluv_256(slm : T_SLM) return T_SLUV_256;                                  --
	function to_sluv_512(slm : T_SLM) return T_SLUV_512;                                  --

	-- Convert matrix to avector-vector: to_slsv_*
	function to_slsv(slm : T_SLM)     return T_SLSV;                                      --
	function to_slsv_2(slm : T_SLM)   return T_SLSV_2;                                    --
	function to_slsv_4(slm : T_SLM)   return T_SLSV_4;                                    --
	function to_slsv_8(slm : T_SLM)   return T_SLSV_8;                                    --
	function to_slsv_12(slm : T_SLM)  return T_SLSV_12;                                   --
	function to_slsv_16(slm : T_SLM)  return T_SLSV_16;                                   --
	function to_slsv_32(slm : T_SLM)  return T_SLSV_32;                                   --
	function to_slsv_64(slm : T_SLM)  return T_SLSV_64;                                   --
	function to_slsv_128(slm : T_SLM) return T_SLSV_128;                                  --
	function to_slsv_256(slm : T_SLM) return T_SLSV_256;                                  --
	function to_slsv_512(slm : T_SLM) return T_SLSV_512;                                  --


	-- Convert vector-vector to matrix: to_slm
	function to_slm(slv  : std_logic_vector; ROWS : positive; COLS : positive) return T_SLM; -- create matrix from vector
	function to_slm(us   : unsigned;         ROWS : positive; COLS : positive) return T_SLM; -- create matrix from vector
	function to_slm(s    : signed;           ROWS : positive; COLS : positive) return T_SLM; -- create matrix from vector
	function to_slm(slvv : T_SLVV)  return T_SLM;                                            -- create matrix from vector-vector
	function to_slm(sluv : T_SLUV)  return T_SLM;                                            -- create matrix from vector-vector
	function to_slm(slsv : T_SLSV)  return T_SLM;                                            -- create matrix from vector-vector

	-- Change vector direction
	function dir(slvv : T_SLVV)     return T_SLVV;
	function dir(sluv : T_SLUV)     return T_SLUV;
	function dir(slsv : T_SLSV)     return T_SLSV;

	-- Reverse vector elements
	function rev(slvv : T_SLVV)     return T_SLVV;
	function rev(sluv : T_SLUV)     return T_SLUV;
	function rev(slsv : T_SLSV)     return T_SLSV;

	-- TODO:
	function resize(slm : T_SLM; size : positive) return T_SLM;

	-- to_string
	function to_string(slvv : T_SLVV_8; sep : character := ':') return string;
	function to_string(slm : T_SLM; groups : positive := 4; format : character := 'b') return string;
end package vectors;


package body vectors is
	-- slicing boundary calulations
	-- ==========================================================================
	function low(lenvec : T_POSVEC; index : natural) return natural is
		variable pos    : natural   := 0;
	begin
		for i in lenvec'low to index - 1 loop
			pos := pos + lenvec(i);
		end loop;
		return pos;
	end function;

	function low(lenvec : T_NATVEC; index : natural) return natural is
		variable pos    : natural    := 0;
	begin
		for i in lenvec'low to index - 1 loop
			pos := pos + lenvec(i);
		end loop;
		return pos;
	end function;

	function high(lenvec : T_POSVEC; index : natural) return natural is
		variable pos    : natural   := 0;
	begin
		for i in lenvec'low to index loop
			pos := pos + lenvec(i);
		end loop;
		return pos - 1;
	end function;

	function high(lenvec : T_NATVEC; index : natural) return natural is
		variable pos    : natural    := 0;
	begin
		for i in lenvec'low to index loop
			pos := pos + lenvec(i);
		end loop;
		return pos - 1;
	end function;

	-- Make vector of constant
	function mk_const(const : std_logic;   length : natural) return std_logic_vector is
		variable slv : std_logic_vector(length -1 downto 0) := (others => const);  -- FIXME: use (length - 1 downto 0 => ...) directly in return statement
	begin
		return slv;
	end function;

	-- FIXME: input as std_logic, return an SLVV of that size
	function mk_const(const : T_SLV_8;     length : natural) return T_SLVV_8 is
		variable slv : T_SLVV_8(length -1 downto 0) := (others => const);  -- FIXME: use (length - 1 downto 0 => ...) directly in return statement
	begin
		return slv;
	end function;

	-- Assign procedures: assign_*
	-- ==========================================================================
	procedure assign_row(signal slm : out T_SLM; slv : std_logic_vector; constant RowIndex : natural) is
		variable temp : std_logic_vector(slm'high(2) downto slm'low(2));          -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		temp := slv;
		for i in temp'range loop
			slm(RowIndex, i)  <= temp(i);
		end loop;
	end procedure;

	--todo : test
	procedure assign_row(signal slm : out T_SLM_8; slv : T_SLVV_8; constant RowIndex : natural) is
		variable temp : T_SLVV_8(slm'high(2) downto slm'low(2));          -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		temp := slv;
		for i in temp'range loop
			slm(RowIndex, i)  <= temp(i);
		end loop;
	end procedure;

	--todo : test
	procedure assign_row(signal slm : out T_SLM_32; slv : T_SLVV_32; constant RowIndex : natural) is
		variable temp : T_SLVV_32(slm'high(2) downto slm'low(2));          -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		temp := slv;
		for i in temp'range loop
			slm(RowIndex, i)  <= temp(i);
		end loop;
	end procedure;

	procedure assign_row(signal slm : out T_SLM; slv : std_logic_vector; constant RowIndex : natural; Position : natural) is
		variable temp : std_logic_vector(Position + slv'length - 1 downto Position);  -- FIXME: check alias usage
	begin
		temp := slv;
		for i in temp'range loop
			slm(RowIndex, i)  <= temp(i);
		end loop;
	end procedure;

	procedure assign_row(signal slm : out T_SLM; slv : std_logic_vector; constant RowIndex : natural; High : natural; Low : natural) is
		variable temp : std_logic_vector(High downto Low);  -- FIXME: check alias usage
	begin
		temp := slv;
		for i in temp'range loop
			slm(RowIndex, i)  <= temp(i);
		end loop;
	end procedure;

	--todo : test
	procedure assign_row(signal slm : out T_SLM_8; slv : T_SLVV_8; constant RowIndex : natural; High : natural; Low : natural) is
		variable temp : T_SLVV_8(High downto Low);  -- FIXME: check alias usage
	begin
		temp := slv;
		for i in temp'range loop
			slm(RowIndex, i)  <= temp(i);
		end loop;
	end procedure;

	procedure assign_col(signal slm : out T_SLM; slv : std_logic_vector; constant ColIndex : natural) is
		variable temp : std_logic_vector(slm'range(1));  -- FIXME: check alias usage
	begin
		temp := slv;
		for i in temp'range loop
			slm(i, ColIndex)  <= temp(i);
		end loop;
	end procedure;

	-- Matrix to matrix conversion: slm_slice*
	-- ==========================================================================
	function slm_slice(slm : T_SLM; RowIndex : natural; ColIndex : natural; Height : natural; Width : natural) return T_SLM is
		variable Result   : T_SLM(Height - 1 downto 0, Width - 1 downto 0)    := (others => (others => '0'));
	begin
		for i in 0 to Height - 1 loop
			for j in 0 to Width - 1 loop
				Result(i, j)    := slm(RowIndex + i, ColIndex + j);
			end loop;
		end loop;
		return Result;
	end function;

	function slm_slice_rows(slm : T_SLM; High : natural; Low : natural) return T_SLM is
		variable Result   : T_SLM(High - Low downto 0, slm'length(2) - 1 downto 0)    := (others => (others => '0'));
	begin
		for i in 0 to High - Low loop
			for j in 0 to slm'length(2) - 1 loop
				Result(i, j)    := slm(Low + i, slm'low(2) + j);
			end loop;
		end loop;
		return Result;
	end function;

	function slm_slice_cols(slm : T_SLM; High : natural; Low : natural) return T_SLM is
		variable Result   : T_SLM(slm'length(1) - 1 downto 0, High - Low downto 0)    := (others => (others => '0'));
	begin
		for i in 0 to slm'length(1) - 1 loop
			for j in 0 to High - Low loop
				Result(i, j)    := slm(slm'low(1) + i, Low + j);
			end loop;
		end loop;
		return Result;
	end function;

	-- Boolean Operators
	function "not"(a : t_slm) return t_slm is
		variable  res : t_slm(a'range(1), a'range(2));
	begin
		for i in res'range(1) loop
			for j in res'range(2) loop
				res(i, j) := not a(i, j);
			end loop;
		end loop;
		return  res;
	end function;

	function "and"(a, b : t_slm) return t_slm is
		variable  bb, res : t_slm(a'range(1), a'range(2));
	begin
		bb := b;
		for i in res'range(1) loop
			for j in res'range(2) loop
				res(i, j) := a(i, j) and bb(i, j);
			end loop;
		end loop;
		return  res;
	end function;

	function "or"(a, b : t_slm) return t_slm is
		variable  bb, res : t_slm(a'range(1), a'range(2));
	begin
		bb := b;
		for i in res'range(1) loop
			for j in res'range(2) loop
				res(i, j) := a(i, j) or bb(i, j);
			end loop;
		end loop;
		return  res;
	end function;

	function "xor"(a, b : t_slm) return t_slm is
		variable  bb, res : t_slm(a'range(1), a'range(2));
	begin
		bb := b;
		for i in res'range(1) loop
			for j in res'range(2) loop
				res(i, j) := a(i, j) xor bb(i, j);
			end loop;
		end loop;
		return  res;
	end function;

	function "nand"(a, b : t_slm) return t_slm is
	begin
		return  not(a and b);
	end function;

	function "nor"(a, b : t_slm) return t_slm is
	begin
		return  not(a or b);
	end function;

	function "xnor"(a, b : t_slm) return t_slm is
	begin
		return  not(a xor b);
	end function;

	-- Matrix concatenation: slm_merge_*
	function slm_merge_rows(slm1 : T_SLM; slm2 : T_SLM) return T_SLM is
		constant ROWS     : positive    := slm1'length(1) + slm2'length(1);
		constant COLUMNS  : positive    := slm1'length(2);
		variable slm      : T_SLM(ROWS - 1 downto 0, COLUMNS - 1 downto 0);
	begin
		for i in slm1'range(1) loop
			for j in slm1'low(2) to slm1'high(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				slm(i, j)   := slm1(i, j);
			end loop;
		end loop;
		for i in slm2'range(1) loop
			for j in slm2'low(2) to slm2'high(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				slm(slm1'length(1) + i, j)    := slm2(i, j);
			end loop;
		end loop;
		return slm;
	end function;

	function slm_merge_cols(slm1 : T_SLM; slm2 : T_SLM) return T_SLM is
		constant ROWS     : positive    := slm1'length(1);
		constant COLUMNS  : positive    := slm1'length(2) + slm2'length(2);
		variable slm      : T_SLM(ROWS - 1 downto 0, COLUMNS - 1 downto 0);
	begin
		for i in slm1'range(1) loop
			for j in slm1'low(2) to slm1'high(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				slm(i, j)   := slm1(i, j);
			end loop;
			for j in slm2'low(2) to slm2'high(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				slm(i, slm1'length(2) + j)    := slm2(i, j);
			end loop;
		end loop;
		return slm;
	end function;


	-- Matrix to vector conversion: get_*
	-- ==========================================================================
	-- get a matrix column
	function get_col(slm : T_SLM; ColIndex : natural) return std_logic_vector is
		variable slv    : std_logic_vector(slm'range(1));
	begin
		for i in slm'range(1) loop
			slv(i)  := slm(i, ColIndex);
		end loop;
		return slv;
	end function;

	-- get a matrix row
	function get_row(slm : T_SLM; RowIndex : natural) return std_logic_vector is
		variable slv    : std_logic_vector(slm'high(2) downto slm'low(2));          -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		for i in slv'range loop
			slv(i)  := slm(RowIndex, i);
		end loop;
		return slv;
	end function;

	function get_row(slm : T_SLM; RowIndex : natural) return unsigned is
		variable us    : unsigned(slm'high(2) downto slm'low(2));          -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		for i in us'range loop
			us(i)  := slm(RowIndex, i);
		end loop;
		return us;
	end function;

	function get_row(slm : T_SLM; RowIndex : natural) return signed is
		variable s    : signed(slm'high(2) downto slm'low(2));          -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		for i in s'range loop
			s(i)  := slm(RowIndex, i);
		end loop;
		return s;
	end function;

	-- TODO: test
	function get_row(slm : T_SLM_8; RowIndex : natural)  return T_SLVV_8 is
		variable slv    : T_SLVV_8(slm'high(2) downto slm'low(2));          -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		for i in slv'range loop
			slv(i)  := slm(RowIndex, i);
		end loop;
		return slv;
	end function;

	-- TODO: test
	function get_row(slm : T_SLM_32; RowIndex : natural)  return T_SLVV_32 is
		variable slv    : T_SLVV_32(slm'high(2) downto slm'low(2));          -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		for i in slv'range loop
			slv(i)  := slm(RowIndex, i);
		end loop;
		return slv;
	end function;

	-- get a matrix row of defined length [length - 1 downto 0]
	function get_row(slm : T_SLM; RowIndex : natural; Length : positive) return std_logic_vector is
	begin
		return get_row(slm, RowIndex, (Length - 1), 0);
	end function;

	-- get a sub vector of a matrix row at high:low
	function get_row(slm : T_SLM; RowIndex : natural; High : natural; Low : natural) return std_logic_vector is
		variable slv    : std_logic_vector(High downto Low);
	begin
		for i in slv'range loop
			slv(i)  := slm(RowIndex, i);
		end loop;
		return slv;
	end function;

	-- Vector-vector to vector conversion: extract_*
	-- ==========================================================================
	-- get a vector-vector row
	function extract_row(slvv : T_SLVV; RowIndex : natural) return std_logic_vector is
		variable slv    : std_logic_vector(slvv'range);
	begin
		for i in slv'range loop
			slv(i)  := slvv(i)(RowIndex);
		end loop;
		return slv;
	end function;

	function extract_row(sluv : T_SLUV; RowIndex : natural) return unsigned is
		variable us    : unsigned(sluv'range);
	begin
		for i in us'range loop
			us(i)  := sluv(i)(RowIndex);
		end loop;
		return us;
	end function;

	function extract_row(slsv : T_SLSV; RowIndex : natural) return signed is
		variable s    : signed(slsv'range);
	begin
		for i in s'range loop
			s(i)  := slsv(i)(RowIndex);
		end loop;
		return s;
	end function;

	-- Convert to vector: to_slv
	-- ==========================================================================
	-- convert vector-vector to flatten vector
	function to_slv(slvv : T_SLVV) return std_logic_vector is
		constant first_len  : natural := slvv'length;
		constant second_len : natural := slvv(slvv'left)'length;
		variable slv        : std_logic_vector((first_len * second_len) - 1 downto 0);
	begin
		for i in slvv'range loop
			slv(((i - slvv'low) * second_len) + second_len -1 downto ((i - slvv'low) * second_len))   := slvv(i);
		end loop;
		return slv;
	end function;

	function to_slv(sluv : T_SLUV) return std_logic_vector is
		constant first_len  : natural := sluv'length;
		constant second_len : natural := sluv(sluv'left)'length;
		variable slv        : std_logic_vector((first_len * second_len) - 1 downto 0);
	begin
		for i in sluv'range loop
			slv(((i - sluv'low) * second_len) + second_len -1 downto ((i - sluv'low) * second_len))   := std_logic_vector(sluv(i));
		end loop;
		return slv;
	end function;

	function to_slv(slsv : T_SLSV) return std_logic_vector is
		constant first_len  : natural := slsv'length;
		constant second_len : natural := slsv(slsv'left)'length;
		variable slv        : std_logic_vector((first_len * second_len) - 1 downto 0);
	begin
		for i in slsv'range loop
			slv(((i - slsv'low) * second_len) + second_len -1 downto ((i - slsv'low) * second_len))   := std_logic_vector(slsv(i));
		end loop;
		return slv;
	end function;

	function to_unsigned(sluv : T_SLUV) return unsigned is
		constant first_len  : natural := sluv'length;
		constant second_len : natural := sluv(sluv'left)'length;
		variable us         : unsigned((first_len * second_len) - 1 downto 0);
	begin
		for i in sluv'range loop
			us((i * second_len) + second_len -1 downto (i * second_len))   := sluv(i);
		end loop;
		return us;
	end function;

	function to_signed(slsv : T_SLSV) return signed is
		constant first_len  : natural := slsv'length;
		constant second_len : natural := slsv(slsv'left)'length;
		variable s          : signed((first_len * second_len) - 1 downto 0);
	begin
		for i in slsv'range loop
			s((i * second_len) + second_len -1 downto (i * second_len))   := slsv(i);
		end loop;
		return s;
	end function;

	-- convert matrix to flatten vector
	function to_slv(slm : T_SLM) return std_logic_vector is
		variable slv : std_logic_vector((slm'length(1) * slm'length(2)) - 1 downto 0);
	begin
		for i in slm'range(1) loop
			for j in slm'high(2) downto slm'low(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				slv((i * slm'length(2)) + j)    := slm(i, j);
			end loop;
		end loop;
		return slv;
	end function;

	function to_unsigned(slm : T_SLM) return unsigned is
		variable us : unsigned((slm'length(1) * slm'length(2)) - 1 downto 0);
	begin
		for i in slm'range(1) loop
			for j in slm'high(2) downto slm'low(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				us((i * slm'length(2)) + j)    := slm(i, j);
			end loop;
		end loop;
		return us;
	end function;

	function to_signed(slm : T_SLM) return signed is
		variable s : signed((slm'length(1) * slm'length(2)) - 1 downto 0);
	begin
		for i in slm'range(1) loop
			for j in slm'high(2) downto slm'low(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				s((i * slm'length(2)) + j)    := slm(i, j);
			end loop;
		end loop;
		return s;
	end function;


	-- Convert flat vector to a vector-vector: to_slvv_*
	-- ==========================================================================
	-- create vector-vector from vector
	function to_slvv(slv : std_logic_vector; sub_element_length : natural) return T_SLVV is
		variable Result   : T_SLVV((slv'length / sub_element_length) - 1 downto 0)(sub_element_length -1 downto 0);
	begin
		assert ((slv'length mod sub_element_length) = 0) report "to_slvv: width mismatch - slv'length is no multiple of sub_element_length (slv'length=" & INTEGER'image(slv'length) & ")" severity FAILURE;
		assert slv'left >= slv'right report "to_slvv:: slv is not descending: slv'left=" & integer'image(slv'left) & ", slv'right=" & integer'image(slv'right) severity FAILURE;

		for i in Result'range loop
			Result(i) := slv((i * sub_element_length) + sub_element_length -1 +slv'low downto (i * sub_element_length) +slv'low);
		end loop;
		return Result;
	end function;

	function to_sluv(slv : std_logic_vector; sub_element_length : natural) return T_SLUV is
		variable Result   : T_SLUV((slv'length / sub_element_length) - 1 downto 0)(sub_element_length -1 downto 0);
	begin
		if ((slv'length mod sub_element_length) /= 0) then  report "to_sluv: width mismatch - slv'length is no multiple of sub_element_length (slv'length=" & INTEGER'image(slv'length) & ")" severity FAILURE; end if;

		for i in Result'range loop
			Result(i) := unsigned(slv((i * sub_element_length) + sub_element_length -1 +slv'low downto (i * sub_element_length) +slv'low));
		end loop;
		return Result;
	end function;

	function to_sluv(us : unsigned; sub_element_length : natural) return T_SLUV is
		variable Result   : T_SLUV((us'length / sub_element_length) - 1 downto 0)(sub_element_length -1 downto 0);
	begin
		if ((us'length mod sub_element_length) /= 0) then  report "to_sluv: width mismatch - us'length is no multiple of sub_element_length (us'length=" & INTEGER'image(us'length) & ")" severity FAILURE; end if;

		for i in Result'range loop
			Result(i) := us((i * sub_element_length) + sub_element_length -1 +us'low downto (i * sub_element_length) +us'low);
		end loop;
		return Result;
	end function;

	function to_slsv(slv : std_logic_vector; sub_element_length : natural) return T_SLSV is
		variable Result   : T_SLSV((slv'length / sub_element_length) - 1 downto 0)(sub_element_length -1 downto 0);
	begin
		if ((slv'length mod sub_element_length) /= 0) then  report "to_slsv: width mismatch - slv'length is no multiple of sub_element_length (slv'length=" & INTEGER'image(slv'length) & ")" severity FAILURE; end if;

		for i in Result'range loop
			Result(i) := signed(slv((i * sub_element_length) + sub_element_length -1 +slv'low downto (i * sub_element_length) +slv'low));
		end loop;
		return Result;
	end function;

	function to_slsv(s : signed; sub_element_length : natural) return T_SLSV is
		variable Result   : T_SLSV((s'length / sub_element_length) - 1 downto 0)(sub_element_length -1 downto 0);
	begin
		if ((s'length mod sub_element_length) /= 0) then  report "to_slsv: width mismatch - s'length is no multiple of sub_element_length (s'length=" & INTEGER'image(s'length) & ")" severity FAILURE; end if;

		for i in Result'range loop
			Result(i) := s((i * sub_element_length) + sub_element_length -1 +s'low downto (i * sub_element_length) +s'low);
		end loop;
		return Result;
	end function;

	-- create vector-vector from vector (2 bit)
	function to_slvv_2(slv : std_logic_vector) return T_SLVV_2 is
	begin
		return to_slvv(slv, 2);
	end function;

	function to_sluv_2(slv : std_logic_vector) return T_SLUV_2 is
	begin
		return to_sluv(slv, 2);
	end function;

	function to_sluv_2(us : unsigned) return T_SLUV_2 is
	begin
		return to_sluv(us, 2);
	end function;

	function to_slsv_2(slv : std_logic_vector) return T_SLSV_2 is
	begin
		return to_slsv(slv, 2);
	end function;

	function to_slsv_2(s : signed) return T_SLSV_2 is
	begin
		return to_slsv(s, 2);
	end function;

	-- create vector-vector from vector (4 bit)
	function to_slvv_4(slv : std_logic_vector) return T_SLVV_4 is
	begin
		return to_slvv(slv, 4);
	end function;

	function to_sluv_4(slv : std_logic_vector) return T_SLUV_4 is
	begin
		return to_sluv(slv, 4);
	end function;

	function to_sluv_4(us : unsigned) return T_SLUV_4 is
	begin
		return to_sluv(us, 4);
	end function;

	function to_slsv_4(slv : std_logic_vector) return T_SLSV_4 is
	begin
		return to_slsv(slv, 4);
	end function;

	function to_slsv_4(s : signed) return T_SLSV_4 is
	begin
		return to_slsv(s, 4);
	end function;

	-- create vector-vector from vector (8 bit)
	function to_slvv_8(slv : std_logic_vector) return T_SLVV_8 is
	begin
		return to_slvv(slv, 8);
	end function;

	function to_sluv_8(slv : std_logic_vector) return T_SLUV_8 is
	begin
		return to_sluv(slv, 8);
	end function;

	function to_sluv_8(us : unsigned) return T_SLUV_8 is
	begin
		return to_sluv(us, 8);
	end function;

	function to_slsv_8(slv : std_logic_vector) return T_SLSV_8 is
	begin
		return to_slsv(slv, 8);
	end function;

	function to_slsv_8(s : signed) return T_SLSV_8 is
	begin
		return to_slsv(s, 8);
	end function;

	-- create vector-vector from vector (12 bit)
	function to_slvv_12(slv : std_logic_vector) return T_SLVV_12 is
	begin
		return to_slvv(slv, 12);
	end function;

	function to_sluv_12(slv : std_logic_vector) return T_SLUV_12 is
	begin
		return to_sluv(slv, 12);
	end function;

	function to_sluv_12(us : unsigned) return T_SLUV_12 is
	begin
		return to_sluv(us, 12);
	end function;

	function to_slsv_12(slv : std_logic_vector) return T_SLSV_12 is
	begin
		return to_slsv(slv, 12);
	end function;

	function to_slsv_12(s : signed) return T_SLSV_12 is
	begin
		return to_slsv(s, 12);
	end function;

	-- create vector-vector from vector (16 bit)
	function to_slvv_16(slv : std_logic_vector) return T_SLVV_16 is
	begin
		return to_slvv(slv, 16);
	end function;

	function to_sluv_16(slv : std_logic_vector) return T_SLUV_16 is
	begin
		return to_sluv(slv, 16);
	end function;

	function to_sluv_16(us : unsigned) return T_SLUV_16 is
	begin
		return to_sluv(us, 16);
	end function;

	function to_slsv_16(slv : std_logic_vector) return T_SLSV_16 is
	begin
		return to_slsv(slv, 16);
	end function;

	function to_slsv_16(s : signed) return T_SLSV_16 is
	begin
		return to_slsv(s, 16);
	end function;

	-- create vector-vector from vector (32 bit)
	function to_slvv_32(slv : std_logic_vector) return T_SLVV_32 is
	begin
		return to_slvv(slv, 32);
	end function;

	function to_sluv_32(slv : std_logic_vector) return T_SLUV_32 is
	begin
		return to_sluv(slv, 32);
	end function;

	function to_sluv_32(us : unsigned) return T_SLUV_32 is
	begin
		return to_sluv(us, 32);
	end function;

	function to_slsv_32(slv : std_logic_vector) return T_SLSV_32 is
	begin
		return to_slsv(slv, 32);
	end function;

	function to_slsv_32(s : signed) return T_SLSV_32 is
	begin
		return to_slsv(s, 32);
	end function;

	-- create vector-vector from vector (64 bit)
	function to_slvv_64(slv : std_logic_vector) return T_SLVV_64 is
	begin
		return to_slvv(slv, 64);
	end function;

	function to_sluv_64(slv : std_logic_vector) return T_SLUV_64 is
	begin
		return to_sluv(slv, 64);
	end function;

	function to_sluv_64(us : unsigned) return T_SLUV_64 is
	begin
		return to_sluv(us, 64);
	end function;

	function to_slsv_64(slv : std_logic_vector) return T_SLSV_64 is
	begin
		return to_slsv(slv, 64);
	end function;

	function to_slsv_64(s : signed) return T_SLSV_64 is
	begin
		return to_slsv(s, 64);
	end function;

	-- create vector-vector from vector (128 bit)
	function to_slvv_128(slv : std_logic_vector) return T_SLVV_128 is
	begin
		return to_slvv(slv, 128);
	end function;

	function to_sluv_128(slv : std_logic_vector) return T_SLUV_128 is
	begin
		return to_sluv(slv, 128);
	end function;

	function to_sluv_128(us : unsigned) return T_SLUV_128 is
	begin
		return to_sluv(us, 128);
	end function;

	function to_slsv_128(slv : std_logic_vector) return T_SLSV_128 is
	begin
		return to_slsv(slv, 128);
	end function;

	function to_slsv_128(s : signed) return T_SLSV_128 is
	begin
		return to_slsv(s, 128);
	end function;

	-- create vector-vector from vector (256 bit)
	function to_slvv_256(slv : std_logic_vector) return T_SLVV_256 is
	begin
		return to_slvv(slv, 256);
	end function;

	function to_sluv_256(slv : std_logic_vector) return T_SLUV_256 is
	begin
		return to_sluv(slv, 256);
	end function;

	function to_sluv_256(us : unsigned) return T_SLUV_256 is
	begin
		return to_sluv(us, 256);
	end function;

	function to_slsv_256(slv : std_logic_vector) return T_SLSV_256 is
	begin
		return to_slsv(slv, 256);
	end function;

	function to_slsv_256(s : signed) return T_SLSV_256 is
	begin
		return to_slsv(s, 256);
	end function;

	-- create vector-vector from vector (512 bit)
	function to_slvv_512(slv : std_logic_vector) return T_SLVV_512 is
	begin
		return to_slvv(slv, 512);
	end function;

	function to_sluv_512(slv : std_logic_vector) return T_SLUV_512 is
	begin
		return to_sluv(slv, 512);
	end function;

	function to_sluv_512(us : unsigned) return T_SLUV_512 is
	begin
		return to_sluv(us, 512);
	end function;

	function to_slsv_512(slv : std_logic_vector) return T_SLSV_512 is
	begin
		return to_slsv(slv, 512);
	end function;

	function to_slsv_512(s : signed) return T_SLSV_512 is
	begin
		return to_slsv(s, 512);
	end function;

	-- Convert matrix to avector-vector: to_slvv_*
	-- ==========================================================================
	-- create vector-vector from matrix
	function to_slvv(slm : T_SLM) return T_SLVV is
		variable Result   : T_SLVV(slm'length(1) -1 downto 0)(slm'length(2) -1 downto 0);
	begin
		for i in slm'range(1) loop
			Result(i) := get_row(slm, i);
		end loop;
		return Result;
	end function;

	function to_sluv(slm : T_SLM) return T_SLUV is
		variable Result   : T_SLUV(slm'length(1) -1 downto 0)(slm'length(2) -1 downto 0);
	begin
		for i in slm'range(1) loop
			Result(i) := get_row(slm, i);
		end loop;
		return Result;
	end function;

	function to_slsv(slm : T_SLM) return T_SLSV is
		variable Result   : T_SLSV(slm'length(1) -1 downto 0)(slm'length(2) -1 downto 0);
	begin
		for i in slm'range(1) loop
			Result(i) := get_row(slm, i);
		end loop;
		return Result;
	end function;

	-- create vector-vector from matrix (2 bit)
	function to_slvv_2(slm : T_SLM) return T_SLVV_2 is
	begin
		if (slm'length(2) /= 2) then  report "to_slvv_2: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_2(slm : T_SLM) return T_SLUV_2 is
	begin
		if (slm'length(2) /= 2) then  report "to_sluv_2: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_2(slm : T_SLM) return T_SLSV_2 is
	begin
		if (slm'length(2) /= 2) then  report "to_slsv_2: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (4 bit)
	function to_slvv_4(slm : T_SLM) return T_SLVV_4 is
	begin
		if (slm'length(2) /= 4) then  report "to_slvv_4: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_4(slm : T_SLM) return T_SLUV_4 is
	begin
		if (slm'length(2) /= 4) then  report "to_sluv_4: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_4(slm : T_SLM) return T_SLSV_4 is
	begin
		if (slm'length(2) /= 4) then  report "to_slsv_4: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (8 bit)
	function to_slvv_8(slm : T_SLM) return T_SLVV_8 is
	begin
		if (slm'length(2) /= 8) then  report "to_slvv_8: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_8(slm : T_SLM) return T_SLUV_8 is
	begin
		if (slm'length(2) /= 8) then  report "to_sluv_8: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_8(slm : T_SLM) return T_SLSV_8 is
	begin
		if (slm'length(2) /= 8) then  report "to_slsv_8: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (12 bit)
	function to_slvv_12(slm : T_SLM) return T_SLVV_12 is
	begin
		if (slm'length(2) /= 12) then  report "to_slvv_12: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_12(slm : T_SLM) return T_SLUV_12 is
	begin
		if (slm'length(2) /= 12) then  report "to_sluv_12: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_12(slm : T_SLM) return T_SLSV_12 is
	begin
		if (slm'length(2) /= 12) then  report "to_slsv_12: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (16 bit)
	function to_slvv_16(slm : T_SLM) return T_SLVV_16 is
	begin
		if (slm'length(2) /= 16) then  report "to_slvv_16: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_16(slm : T_SLM) return T_SLUV_16 is
	begin
		if (slm'length(2) /= 16) then  report "to_sluv_16: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_16(slm : T_SLM) return T_SLSV_16 is
	begin
		if (slm'length(2) /= 16) then  report "to_slsv_16: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (32 bit)
	function to_slvv_32(slm : T_SLM) return T_SLVV_32 is
	begin
		if (slm'length(2) /= 32) then  report "to_slvv_32: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_32(slm : T_SLM) return T_SLUV_32 is
	begin
		if (slm'length(2) /= 32) then  report "to_sluv_32: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_32(slm : T_SLM) return T_SLSV_32 is
	begin
		if (slm'length(2) /= 32) then  report "to_slsv_32: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (64 bit)
	function to_slvv_64(slm : T_SLM) return T_SLVV_64 is
	begin
		if (slm'length(2) /= 64) then  report "to_slvv_64: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_64(slm : T_SLM) return T_SLUV_64 is
	begin
		if (slm'length(2) /= 64) then  report "to_sluv_64: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_64(slm : T_SLM) return T_SLSV_64 is
	begin
		if (slm'length(2) /= 64) then  report "to_slsv_64: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (128 bit)
	function to_slvv_128(slm : T_SLM) return T_SLVV_128 is
	begin
		if (slm'length(2) /= 128) then  report "to_slvv_128: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_128(slm : T_SLM) return T_SLUV_128 is
	begin
		if (slm'length(2) /= 128) then  report "to_sluv_128: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_128(slm : T_SLM) return T_SLSV_128 is
	begin
		if (slm'length(2) /= 128) then  report "to_slsv_128: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (256 bit)
	function to_slvv_256(slm : T_SLM) return T_SLVV_256 is
	begin
		if (slm'length(2) /= 256) then  report "to_slvv_256: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_256(slm : T_SLM) return T_SLUV_256 is
	begin
		if (slm'length(2) /= 256) then  report "to_sluv_256: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_256(slm : T_SLM) return T_SLSV_256 is
	begin
		if (slm'length(2) /= 256) then  report "to_slsv_256: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- create vector-vector from matrix (512 bit)
	function to_slvv_512(slm : T_SLM) return T_SLVV_512 is
	begin
		if (slm'length(2) /= 512) then  report "to_slvv_512: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slvv(slm);
	end function;

	function to_sluv_512(slm : T_SLM) return T_SLUV_512 is
	begin
		if (slm'length(2) /= 512) then  report "to_sluv_512: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_sluv(slm);
	end function;

	function to_slsv_512(slm : T_SLM) return T_SLSV_512 is
	begin
		if (slm'length(2) /= 512) then  report "to_slsv_512: type mismatch - slm'length(2)=" & integer'image(slm'length(2)) severity FAILURE; end if;
		return to_slsv(slm);
	end function;

	-- Convert vector-vector to matrix: to_slm
	-- ==========================================================================
	-- create matrix from vector
	function to_slm(slv : std_logic_vector; ROWS : positive; COLS : positive) return T_SLM is
		variable slm    : T_SLM(ROWS - 1 downto 0, COLS - 1 downto 0);
	begin
		for i in 0 to ROWS - 1 loop
			for j in 0 to COLS - 1 loop
				slm(i, j) := slv((i * COLS) + j);
			end loop;
		end loop;
		return slm;
	end function;

	function to_slm(us : unsigned; ROWS : positive; COLS : positive) return T_SLM is
		variable slm    : T_SLM(ROWS - 1 downto 0, COLS - 1 downto 0);
	begin
		for i in 0 to ROWS - 1 loop
			for j in 0 to COLS - 1 loop
				slm(i, j) := us((i * COLS) + j);
			end loop;
		end loop;
		return slm;
	end function;

	function to_slm(s : signed; ROWS : positive; COLS : positive) return T_SLM is
		variable slm    : T_SLM(ROWS - 1 downto 0, COLS - 1 downto 0);
	begin
		for i in 0 to ROWS - 1 loop
			for j in 0 to COLS - 1 loop
				slm(i, j) := s((i * COLS) + j);
			end loop;
		end loop;
		return slm;
	end function;

	-- create matrix from vector-vector
	function to_slm(slvv : T_SLVV) return T_SLM is
		variable slm    : T_SLM(slvv'range, slvv(slvv'left)'range);
	begin
		for i in slvv'range loop
			for j in slvv(slvv'left)'range loop
				slm(i, j)   := slvv(i)(j);
			end loop;
		end loop;
		return slm;
	end function;


	function to_slm(sluv : T_SLUV) return T_SLM is
		variable slm    : T_SLM(sluv'range, sluv(sluv'left)'range);
	begin
		for i in sluv'range loop
			for j in sluv(sluv'left)'range loop
				slm(i, j)   := sluv(i)(j);
			end loop;
		end loop;
		return slm;
	end function;


	function to_slm(slsv : T_SLSV) return T_SLM is
		variable slm    : T_SLM(slsv'range, slsv(slsv'left)'range);
	begin
		for i in slsv'range loop
			for j in slsv(slsv'left)'range loop
				slm(i, j)   := slsv(i)(j);
			end loop;
		end loop;
		return slm;
	end function;

	-- Change vector direction
	-- ==========================================================================
	function dir(slvv : T_SLVV) return T_SLVV is
		variable Result : T_SLVV(slvv'reverse_range)(slvv(slvv'low)'range);
	begin
		Result := slvv;
		return Result;
	end function;

	function dir(sluv : T_SLUV) return T_SLUV is
		variable Result : T_SLUV(sluv'reverse_range)(sluv(sluv'low)'range);
	begin
		Result := sluv;
		return Result;
	end function;

	function dir(slsv : T_SLSV) return T_SLSV is
		variable Result : T_SLSV(slsv'reverse_range)(slsv(slsv'low)'range);
	begin
		Result := slsv;
		return Result;
	end function;

	-- Reverse vector elements
	function rev(slvv : T_SLVV) return T_SLVV is
		variable Result : T_SLVV(slvv'range)(slvv(slvv'low)'range);
	begin
		for i in slvv'low to slvv'high loop
			Result(slvv'high - i) := slvv(i);
		end loop;
		return Result;
	end function;

	function rev(sluv : T_SLUV) return T_SLUV is
		variable Result : T_SLUV(sluv'range)(sluv(sluv'low)'range);
	begin
		for i in sluv'low to sluv'high loop
			Result(sluv'high - i) := sluv(i);
		end loop;
		return Result;
	end function;

	function rev(slsv : T_SLSV) return T_SLSV is
		variable Result : T_SLSV(slsv'range)(slsv(slsv'low)'range);
	begin
		for i in slsv'low to slsv'high loop
			Result(slsv'high - i) := slsv(i);
		end loop;
		return Result;
	end function;

	-- Resize functions
	-- ==========================================================================
	-- Resizes the vector to the specified length. Input vectors larger than the specified size are truncated from the left side. Smaller input
	-- vectors are extended on the left by the provided fill value (default: '0'). Use the resize functions of the numeric_std package for
	-- value-preserving resizes of the signed and unsigned data types.
	function resize(slm : T_SLM; size : positive) return T_SLM is
		variable Result   : T_SLM(size - 1 downto 0, slm'high(2) downto slm'low(2))   := (others => (others => '0'));         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
	begin
		for i in slm'range(1) loop
			for j in slm'high(2) downto slm'low(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				Result(i, j)  := slm(i, j);
			end loop;
		end loop;
		return Result;
	end function;

	function to_string(slvv : T_SLVV_8; sep : character := ':') return string is
		constant hex_len      : positive                := ite((sep = C_POC_NUL), (slvv'length * 2), (slvv'length * 3) - 1);
		variable Result       : string(1 to hex_len)    := (others => sep);
		variable pos          : positive                := 1;
	begin
		for i in slvv'range loop
			Result(pos to pos + 1)  := to_string(slvv(i), 'h');
			pos                     := pos + ite((sep = C_POC_NUL), 2, 3);
		end loop;
		return Result;
	end function;

	function to_string_bin(slm : T_SLM; groups : positive := 4; format : character := 'h') return string is
		variable PerLineOverheader  : positive  := div_ceil(slm'length(2), groups);
		variable Result             : string(1 to (slm'length(1) * (slm'length(2) + PerLineOverheader)) + 10);
		variable Writer             : positive;
		variable GroupCounter       : natural;
	begin
		Result        := (others => C_POC_NUL);
		Result(1)     := LF;
		Writer        := 2;
		GroupCounter  := 0;
		for i in slm'low(1) to slm'high(1) loop
			for j in slm'high(2) downto slm'low(2) loop         -- WORKAROUND: Xilinx iSIM work-around, because 'range(2) evaluates to 'range(1); see work-around notes at T_SLM type declaration
				Result(Writer)    := to_char(slm(i, j));
				Writer            := Writer + 1;
				GroupCounter      := GroupCounter + 1;
				if GroupCounter = groups then
					Result(Writer)  := ' ';
					Writer          := Writer + 1;
					GroupCounter    := 0;
				end if;
			end loop;
			Result(Writer - 1)  := LF;
			GroupCounter        := 0;
		end loop;
		return str_trim(Result);
	end function;

	function to_string(slm : T_SLM; groups : positive := 4; format : character := 'b') return string is
	begin
		if (format = 'b') then
			return to_string_bin(slm, groups);
		else
			return "Format not supported.";
		end if;
	end function;
end package body;
