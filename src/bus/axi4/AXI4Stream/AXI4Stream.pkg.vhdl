-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Max Kraft-Kugler
--                  Stefan Unrein
--                  Patrick Lehmann
--
-- Package:          Generic AMBA AXI4-Stream bus description.
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4-Stream description.
-- The bus created by the two main unconstrained records T_AXI4Stream_BUS_M2S and
-- T_AXI4Stream_BUS_S2M. *_M2S stands for Master-to-Slave and defines the direction
-- from master to the slave component of the bus. Vice versa for the *_S2M type.
--
-- Usage:
-- You can use this record type as a normal, unconstrained record. Create signal
-- with a constrained subtype and connect it to the desired components.
-- To avoid constraining overhead, you can use the generic sized-package:
-- package AXI4Stream_Sized_64D_1ID_1Dest_1User is
--   new work.AXI4Stream_Sized
--   generic map(
--     DATA_BITS     => 64
--   );
-- Then simply use the sized subtypes:
-- signal DeMux_M2S : AXI4Stream_Sized_64D_1ID_1Dest_1User.Sized_M2S;
-- signal DeMux_S2M : AXI4Stream_Sized_64D_1ID_1Dest_1User.Sized_S2M;
--
-- If multiple components need to be connected, you can also use the predefined
-- vector type T_AXI4Stream_BUS_M2S_VECTOR and T_AXI4Stream_BUS_S2M_VECTOR, which
-- gives you a vector of AXI4Stream records. This is also available in the generic
-- package as Sized_M2S_Vector and Sized_S2M_Vector.
--
-- License:
-- =============================================================================
-- Copyright 2024      PLC2 Design GmbH - Endingen, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;


package AXI4Stream is
	type T_AXI4Stream_M2S is record
		Valid : std_logic;
		Data  : std_logic_vector;
		Keep  : std_logic_vector;
		Last  : std_logic;
		User  : std_logic_vector;
		Dest  : std_logic_vector;
		ID    : std_logic_vector;
	end record;

	type T_AXI4Stream_S2M is record
		Ready : std_logic;
		User  : std_logic_vector;
	end record;

	type T_AXI4Stream_M2S_VECTOR is array(natural range <>) of T_AXI4Stream_M2S;
	type T_AXI4Stream_S2M_VECTOR is array(natural range <>) of T_AXI4Stream_S2M;

	function Initialize_AXI4Stream_M2S(DataBits : natural; UserBits : positive := 1; DestBits : positive := 1; IDBits : positive := 1; Value : std_logic := 'Z') return T_AXI4Stream_M2S;
	function Initialize_AXI4Stream_S2M(UserBits : positive := 1; Value : std_logic := 'Z') return T_AXI4Stream_S2M;

	function BlockTransaction(BlockTransaction : std_logic; In_M2S : T_AXI4Stream_M2S) return T_AXI4Stream_M2S;
	function BlockTransaction(BlockTransaction : std_logic; In_S2M : T_AXI4Stream_S2M) return T_AXI4Stream_S2M;
	function get_TotalDataBits(In_M2S : T_AXI4Stream_M2S) return positive;
	function serialize(In_M2S         : T_AXI4Stream_M2S) return std_logic_vector; --Puts all data-fields in a std_logic_vector
	function get_LastFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic;
	function get_DataFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector;
	function get_UserFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector;
	function get_DestFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector;
	function get_IDFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector;
	function get_KeepFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector;

end package;

package body AXI4Stream is

	function Initialize_AXI4Stream_M2S(DataBits : natural; UserBits : positive := 1; DestBits : positive := 1; IDBits : positive := 1; Value : std_logic := 'Z') return T_AXI4Stream_M2S is
		constant init : T_AXI4Stream_M2S(
			Data(DataBits - 1 downto 0),
			User(UserBits - 1 downto 0),
			Dest(DestBits - 1 downto 0),
			ID(IDBits - 1 downto 0),
			Keep((DataBits / 8) - 1 downto 0)
		) := (
			Valid => Value,
			Data => (others => Value),
			Keep => (others => Value),
			Last  => Value,
			Dest => (others => Value),
			ID => (others => Value),
			User => (others => Value)
		);
	begin
		return init;
	end function;

	function Initialize_AXI4Stream_S2M(UserBits : positive := 1; Value : std_logic := 'Z') return T_AXI4Stream_S2M is
		constant init : T_AXI4Stream_S2M(User(UserBits - 1 downto 0)) := (
			Ready => Value,
			User => (others => Value)
		);
	begin
		return init;
	end function;

	function BlockTransaction(BlockTransaction : std_logic; In_M2S : T_AXI4Stream_M2S) return T_AXI4Stream_M2S is
		variable temp : In_M2S'subtype;
	begin
		temp.Valid := In_M2S.Valid and not BlockTransaction;
		temp.Data  := In_M2S.Data;
		temp.Keep  := In_M2S.Keep;
		temp.Last  := In_M2S.Last;
		temp.User  := In_M2S.User;
		temp.Dest  := In_M2S.Dest;
		temp.ID    := In_M2S.ID;
		return temp;
	end function;

	function BlockTransaction(BlockTransaction : std_logic; In_S2M : T_AXI4Stream_S2M) return T_AXI4Stream_S2M is
		variable temp : In_S2M'subtype;
	begin
		temp.Ready := In_S2M.Ready and not BlockTransaction;
		temp.User  := In_S2M.User;
		return temp;
	end function;

	function get_TotalDataBits(In_M2S : T_AXI4Stream_M2S) return positive is
	begin
		return In_M2S.Data'length + 1 + In_M2S.User'length + In_M2S.Dest'length + In_M2S.ID'length + In_M2S.Keep'length;
	end function;

	function serialize(In_M2S : T_AXI4Stream_M2S) return std_logic_vector is
	begin
		return In_M2S.ID & In_M2S.Dest & In_M2S.User & In_M2S.Last & In_M2S.Keep & In_M2S.Data;
	end function;

	function get_LastFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic is
	begin
		assert get_TotalDataBits(In_M2S) = Serialized'length report "AXI4Stream.pkg.get_LastFromSerialized:: Size of Serialized Data does not metch packing size of In_M2S!" severity failure;
		return Serialized(In_M2S.Data'length + In_M2S.Keep'length + Serialized'low);
	end function;

	function get_DataFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector is
	begin
		assert get_TotalDataBits(In_M2S) = Serialized'length report "AXI4Stream.pkg.get_LastFromSerialized:: Size of Serialized Data does not metch packing size of In_M2S!" severity failure;
		return Serialized(In_M2S.Data'length - 1 + Serialized'low downto Serialized'low);
	end function;

	function get_KeepFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector is
	begin
		assert get_TotalDataBits(In_M2S) = Serialized'length report "AXI4Stream.pkg.get_LastFromSerialized:: Size of Serialized Data does not metch packing size of In_M2S!" severity failure;
		return Serialized(In_M2S.Keep'length - 1 + In_M2S.Data'length + Serialized'low downto In_M2S.Data'length + Serialized'low);
	end function;

	function get_UserFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector is
	begin
		assert get_TotalDataBits(In_M2S) = Serialized'length report "AXI4Stream.pkg.get_LastFromSerialized:: Size of Serialized Data does not metch packing size of In_M2S!" severity failure;
		return Serialized(In_M2S.User'length - 1 + 1 + In_M2S.Keep'length + In_M2S.Data'length + Serialized'low downto
		1 + In_M2S.Keep'length + In_M2S.Data'length + Serialized'low);
	end function;

	function get_DestFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector is
	begin
		assert get_TotalDataBits(In_M2S) = Serialized'length report "AXI4Stream.pkg.get_LastFromSerialized:: Size of Serialized Data does not metch packing size of In_M2S!" severity failure;
		return Serialized(In_M2S.Dest'length - 1 + In_M2S.User'length + 1 + In_M2S.Keep'length + In_M2S.Data'length + Serialized'low downto
		In_M2S.User'length + 1 + In_M2S.Keep'length + In_M2S.Data'length + Serialized'low);
	end function;

	function get_IDFromSerialized(Serialized : std_logic_vector; In_M2S : T_AXI4Stream_M2S) return std_logic_vector is
	begin
		assert get_TotalDataBits(In_M2S) = Serialized'length report "AXI4Stream.pkg.get_LastFromSerialized:: Size of Serialized Data does not metch packing size of In_M2S!" severity failure;
		return Serialized(In_M2S.ID'length - 1 + In_M2S.Dest'length + In_M2S.User'length + 1 + In_M2S.Keep'length + In_M2S.Data'length + Serialized'low downto
		In_M2S.Dest'length + In_M2S.User'length + 1 + In_M2S.Keep'length + In_M2S.Data'length + Serialized'low);
	end function;

end package body;

use work.AXI4Stream.all;
package AXI4Stream_Sized is
	generic (
		DATA_BITS     : positive;
		USER_BITS     : positive := 1;
		DEST_BITS     : positive := 1;
		ID_BITS       : positive := 1;
		KEEP_BITS     : positive := DATA_BITS / 8;
		REV_USER_BITS : positive := 1
	);

	subtype SIZED_M2S is T_AXI4STREAM_M2S(
		Data(DATA_BITS - 1 downto 0),
		Keep(KEEP_BITS - 1 downto 0),
		Dest(DEST_BITS - 1 downto 0),
		ID(ID_BITS - 1 downto 0),
		User(USER_BITS - 1 downto 0)
	);
	subtype SIZED_S2M is T_AXI4STREAM_S2M(
		User(REV_USER_BITS - 1 downto 0)
	);

	subtype SIZED_M2S_VECTOR is T_AXI4STREAM_M2S_VECTOR(open)(
		Data(DATA_BITS - 1 downto 0),
		Keep(KEEP_BITS - 1 downto 0),
		Dest(DEST_BITS - 1 downto 0),
		ID(ID_BITS - 1 downto 0),
		User(USER_BITS - 1 downto 0)
	);
	subtype SIZED_S2M_VECTOR is T_AXI4STREAM_S2M_VECTOR(open)(
		User(REV_USER_BITS - 1 downto 0)
	);
end package;
