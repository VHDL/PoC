-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Stefan Unrein
--
-- Package:          Generic AMBA AXI4 bus description.
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4 (also known as AXI4-Full or AXI4-MM) description.
-- The bus created by the two main unconstrained records T_AXI4_BUS_M2S and
-- T_AXI4_BUS_S2M. *_M2S stands for Master-to-Slave and defines the direction
-- from master to the slave component of the bus. Vice versa for the *_S2M type.
--
-- Usage:
-- You can use this record type as a normal, unconstrained record. Create signal
-- with a constrained subtype and connect it to the desired components.
-- To avoid constraining overhead, you can use the generic sized-package:
-- package AXI4Full_Sized_32A_64D is
--   new work.AXI4Full_Sized
--   generic map(
--     ADDRESS_BITS  => 32,
--     DATA_BITS     => 64
--   );
-- Then simply use the sized subtypes:
-- signal DeMux_M2S : AXI4Full_Sized_32A_64D.Sized_M2S;
-- signal DeMux_S2M : AXI4Full_Sized_32A_64D.Sized_S2M;
--
-- If multiple components need to be connected, you can also use the predefined
-- vector type T_AXI4_BUS_M2S_VECTOR and T_AXI4_BUS_S2M_VECTOR, which
-- gives you a vector of AXI4Lite records. This is also available in the generic
-- package as Sized_M2S_Vector and Sized_S2M_Vector.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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

use     work.utils.all;
use     work.strings.all;
use     work.AXI4_Common.all;


package AXI4_Full is
	alias T_AXI4_Response is work.AXI4_Common.T_AXI4_Response;
	alias C_AXI4_RESPONSE_OKAY is work.AXI4_Common.C_AXI4_RESPONSE_OKAY;
	alias C_AXI4_RESPONSE_EX_OKAY is work.AXI4_Common.C_AXI4_RESPONSE_EX_OKAY;
	alias C_AXI4_RESPONSE_SLAVE_ERROR is work.AXI4_Common.C_AXI4_RESPONSE_SLAVE_ERROR;
	alias C_AXI4_RESPONSE_DECODE_ERROR is work.AXI4_Common.C_AXI4_RESPONSE_DECODE_ERROR;
	alias C_AXI4_RESPONSE_INIT is work.AXI4_Common.C_AXI4_RESPONSE_INIT;

	alias T_AXI4_Cache is work.AXI4_Common.T_AXI4_Cache;
	alias C_AXI4_CACHE_INIT is work.AXI4_Common.C_AXI4_CACHE_INIT;
	alias C_AXI4_CACHE is work.AXI4_Common.C_AXI4_CACHE;

	alias T_AXI4_Protect is work.AXI4_Common.T_AXI4_Protect;
	alias C_AXI4_PROTECT_INIT is work.AXI4_Common.C_AXI4_PROTECT_INIT;
	alias C_AXI4_PROTECT is work.AXI4_Common.C_AXI4_PROTECT;

	alias T_AXI4_QoS is work.AXI4_Common.T_AXI4_QoS;
	alias C_AXI4_QOS_INIT is work.AXI4_Common.C_AXI4_QOS_INIT;

	alias T_AXI4_Region is work.AXI4_Common.T_AXI4_Region;
	alias C_AXI4_REGION_INIT is work.AXI4_Common.C_AXI4_REGION_INIT;

	alias T_AXI4_Size is work.AXI4_Common.T_AXI4_Size;
	alias C_AXI4_SIZE_1 is work.AXI4_Common.C_AXI4_SIZE_1;
	alias C_AXI4_SIZE_2 is work.AXI4_Common.C_AXI4_SIZE_2;
	alias C_AXI4_SIZE_4 is work.AXI4_Common.C_AXI4_SIZE_4;
	alias C_AXI4_SIZE_8 is work.AXI4_Common.C_AXI4_SIZE_8;
	alias C_AXI4_SIZE_16 is work.AXI4_Common.C_AXI4_SIZE_16;
	alias C_AXI4_SIZE_32 is work.AXI4_Common.C_AXI4_SIZE_32;
	alias C_AXI4_SIZE_64 is work.AXI4_Common.C_AXI4_SIZE_64;
	alias C_AXI4_SIZE_128 is work.AXI4_Common.C_AXI4_SIZE_128;
	alias C_AXI4_SIZE_INIT is work.AXI4_Common.C_AXI4_SIZE_INIT;

	alias T_AXI4_Burst is work.AXI4_Common.T_AXI4_Burst;
	alias C_AXI4_BURST_FIXED is work.AXI4_Common.C_AXI4_BURST_FIXED;
	alias C_AXI4_BURST_INCR is work.AXI4_Common.C_AXI4_BURST_INCR;
	alias C_AXI4_BURST_WRAP is work.AXI4_Common.C_AXI4_BURST_WRAP;
	alias C_AXI4_BURST_INIT is work.AXI4_Common.C_AXI4_BURST_INIT;

	type T_AXI4_Bus_S2M is record
		AWReady : std_logic;
		WReady  : std_logic;
		BValid  : std_logic;
		BResp   : T_AXI4_Response;
		BID     : std_logic_vector;
		BUser   : std_logic_vector;
		ARReady : std_logic;
		RValid  : std_logic;
		RData   : std_logic_vector;
		RResp   : T_AXI4_Response;
		RID     : std_logic_vector;
		RLast   : std_logic;
		RUser   : std_logic_vector;
	end record;
	type T_AXI4_Bus_S2M_VECTOR is array(natural range <>) of T_AXI4_Bus_S2M;

	function EnableTransaction(InBus : T_AXI4_Bus_S2M; Enable : std_logic) return T_AXI4_Bus_S2M;
	function EnableTransaction(InBus : T_AXI4_Bus_S2M_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_S2M_VECTOR;

	function DisableWrite(InBus : T_AXI4_Bus_S2M) return T_AXI4_Bus_S2M;
	function DisableWrite(InBus : T_AXI4_Bus_S2M_VECTOR) return T_AXI4_Bus_S2M_VECTOR;
	function DisableRead(InBus  : T_AXI4_Bus_S2M) return T_AXI4_Bus_S2M;
	function DisableRead(InBus  : T_AXI4_Bus_S2M_VECTOR) return T_AXI4_Bus_S2M_VECTOR;

	type T_AXI4_Bus_M2S is record
		AWID     : std_logic_vector;
		AWAddr   : std_logic_vector;
		AWLen    : std_logic_vector(7 downto 0);
		AWSize   : T_AXI4_Size;
		AWBurst  : T_AXI4_Burst;
		AWLock   : std_logic_vector(0 to 0);
		AWQOS    : T_AXI4_QoS;
		AWRegion : T_AXI4_Region;
		AWUser   : std_logic_vector;
		AWValid  : std_logic;
		AWCache  : T_AXI4_Cache;
		AWProt   : T_AXI4_Protect;
		WValid   : std_logic;
		WLast    : std_logic;
		WUser    : std_logic_vector;
		WData    : std_logic_vector;
		WStrb    : std_logic_vector;
		BReady   : std_logic;
		ARValid  : std_logic;
		ARAddr   : std_logic_vector;
		ARCache  : T_AXI4_Cache;
		ARProt   : T_AXI4_Protect;
		ARID     : std_logic_vector;
		ARLen    : std_logic_vector(7 downto 0);
		ARSize   : T_AXI4_Size;
		ARBurst  : T_AXI4_Burst;
		ARLock   : std_logic_vector(0 to 0);
		ARQOS    : T_AXI4_QoS;
		ARRegion : T_AXI4_Region;
		ARUser   : std_logic_vector;
		RReady   : std_logic;
	end record;
	type T_AXI4_Bus_M2S_VECTOR is array(natural range <>) of T_AXI4_Bus_M2S;

	function EnableTransaction(InBus : T_AXI4_Bus_M2S; Enable : std_logic) return T_AXI4_Bus_M2S;
	function EnableTransaction(InBus : T_AXI4_Bus_M2S_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_M2S_VECTOR;

	function DisableWrite(InBus : T_AXI4_Bus_M2S) return T_AXI4_Bus_M2S;
	function DisableWrite(InBus : T_AXI4_Bus_M2S_VECTOR) return T_AXI4_Bus_M2S_VECTOR;
	function DisableRead(InBus  : T_AXI4_Bus_M2S) return T_AXI4_Bus_M2S;
	function DisableRead(InBus  : T_AXI4_Bus_M2S_VECTOR) return T_AXI4_Bus_M2S_VECTOR;

	function AddressTranslate(InBus : T_AXI4_Bus_M2S; Offset : signed) return T_AXI4_Bus_M2S;
	function AddressMask(InBus : T_AXI4_Bus_M2S; AddressBits : natural) return T_AXI4_Bus_M2S;
	function AddressMask(InBus : T_AXI4_Bus_M2S; Mask : std_logic_vector) return T_AXI4_Bus_M2S;
	function AddressResize(InBus : T_AXI4_Bus_M2S; AddressBits : natural) return T_AXI4_Bus_M2S;

	function Initialize_AXI4_Bus_S2M(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_S2M;
	function Initialize_AXI4_Bus_M2S(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_M2S;

	procedure ConnectAndResize(signal In_M2S : in T_AXI4_Bus_M2S; signal In_S2M : out T_AXI4_Bus_S2M; signal Out_M2S : out T_AXI4_Bus_M2S; signal Out_S2M : in T_AXI4_Bus_S2M; constant Info_Prefix : string := "");
	type T_AXI4_Bus is record
		M2S : T_AXI4_Bus_M2S;
		S2M : T_AXI4_Bus_S2M;
	end record;
	type T_AXI4_Bus_VECTOR is array(natural range <>) of T_AXI4_Bus;

	function Initialize_AXI4_Bus(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_Bus;

	type T_Address_Translate_Command is (None, Increase, Decrease, Hold);
	type T_Address_Translate_Command_Vector is array(natural range <>) of T_Address_Translate_Command;
end package;
package body AXI4_Full is

	function EnableTransaction(InBus : T_AXI4_Bus_M2S; Enable : std_logic) return T_AXI4_Bus_M2S is
		variable temp : InBus'subtype;
	begin
		temp.AWID     := InBus.AWID;
		temp.AWAddr   := InBus.AWAddr;
		temp.AWLen    := InBus.AWLen;
		temp.AWSize   := InBus.AWSize;
		temp.AWBurst  := InBus.AWBurst;
		temp.AWLock   := InBus.AWLock;
		temp.AWQOS    := InBus.AWQOS;
		temp.AWRegion := InBus.AWRegion;
		temp.AWUser   := InBus.AWUser;
		temp.AWValid  := InBus.AWValid and Enable;
		temp.AWCache  := InBus.AWCache;
		temp.AWProt   := InBus.AWProt;
		temp.WValid   := InBus.WValid and Enable;
		temp.WLast    := InBus.WLast;
		temp.WUser    := InBus.WUser;
		temp.WData    := InBus.WData;
		temp.WStrb    := InBus.WStrb;
		temp.BReady   := InBus.BReady and Enable;
		temp.ARValid  := InBus.ARValid and Enable;
		temp.ARAddr   := InBus.ARAddr;
		temp.ARCache  := InBus.ARCache;
		temp.ARProt   := InBus.ARProt;
		temp.ARID     := InBus.ARID;
		temp.ARLen    := InBus.ARLen;
		temp.ARSize   := InBus.ARSize;
		temp.ARBurst  := InBus.ARBurst;
		temp.ARLock   := InBus.ARLock;
		temp.ARQOS    := InBus.ARQOS;
		temp.ARRegion := InBus.ARRegion;
		temp.ARUser   := InBus.ARUser;
		temp.RReady   := InBus.RReady and Enable;
		return temp;
	end function;

	function EnableTransaction(InBus : T_AXI4_Bus_M2S_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_M2S_VECTOR is
		variable temp : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i) := EnableTransaction(InBus(i), Enable(i));
		end loop;
		return temp;
	end function;

	function AddressTranslate(InBus : T_AXI4_Bus_M2S; Offset : signed) return T_AXI4_Bus_M2S is
		variable temp : InBus'subtype;
	begin
		assert Offset'length = InBus.AWAddr'length report "PoC.AXI4_Full.AddressTranslate: Length of Offeset-Bits and Address-Bits is no equal!" severity failure;

		temp.AWID     := InBus.AWID;
		temp.AWAddr   := std_logic_vector(unsigned(InBus.AWAddr) + unsigned(std_logic_vector(Offset)));
		temp.AWLen    := InBus.AWLen;
		temp.AWSize   := InBus.AWSize;
		temp.AWBurst  := InBus.AWBurst;
		temp.AWLock   := InBus.AWLock;
		temp.AWQOS    := InBus.AWQOS;
		temp.AWRegion := InBus.AWRegion;
		temp.AWUser   := InBus.AWUser;
		temp.AWValid  := InBus.AWValid;
		temp.AWCache  := InBus.AWCache;
		temp.AWProt   := InBus.AWProt;
		temp.WValid   := InBus.WValid;
		temp.WLast    := InBus.WLast;
		temp.WUser    := InBus.WUser;
		temp.WData    := InBus.WData;
		temp.WStrb    := InBus.WStrb;
		temp.BReady   := InBus.BReady;
		temp.ARValid  := InBus.ARValid;
		temp.ARAddr   := std_logic_vector(unsigned(InBus.ARAddr) + unsigned(std_logic_vector(Offset)));
		temp.ARCache  := InBus.ARCache;
		temp.ARProt   := InBus.ARProt;
		temp.ARID     := InBus.ARID;
		temp.ARLen    := InBus.ARLen;
		temp.ARSize   := InBus.ARSize;
		temp.ARBurst  := InBus.ARBurst;
		temp.ARLock   := InBus.ARLock;
		temp.ARQOS    := InBus.ARQOS;
		temp.ARRegion := InBus.ARRegion;
		temp.ARUser   := InBus.ARUser;
		temp.RReady   := InBus.RReady;
		return temp;
	end function;

	function AddressMask(InBus : T_AXI4_Bus_M2S; AddressBits : natural) return T_AXI4_Bus_M2S is
		constant Mask : std_logic_vector(InBus.AWAddr'range) := (InBus.AWAddr'length - 1 downto AddressBits => '0') & (AddressBits - 1 downto 0 => '1');
		variable temp : InBus'subtype;
	begin
		temp.AWID     := InBus.AWID;
		temp.AWAddr   := InBus.AWAddr and Mask;
		temp.AWLen    := InBus.AWLen;
		temp.AWSize   := InBus.AWSize;
		temp.AWBurst  := InBus.AWBurst;
		temp.AWLock   := InBus.AWLock;
		temp.AWQOS    := InBus.AWQOS;
		temp.AWRegion := InBus.AWRegion;
		temp.AWUser   := InBus.AWUser;
		temp.AWValid  := InBus.AWValid;
		temp.AWCache  := InBus.AWCache;
		temp.AWProt   := InBus.AWProt;
		temp.WValid   := InBus.WValid;
		temp.WLast    := InBus.WLast;
		temp.WUser    := InBus.WUser;
		temp.WData    := InBus.WData;
		temp.WStrb    := InBus.WStrb;
		temp.BReady   := InBus.BReady;
		temp.ARValid  := InBus.ARValid;
		temp.ARAddr   := InBus.ARAddr and Mask;
		temp.ARCache  := InBus.ARCache;
		temp.ARProt   := InBus.ARProt;
		temp.ARID     := InBus.ARID;
		temp.ARLen    := InBus.ARLen;
		temp.ARSize   := InBus.ARSize;
		temp.ARBurst  := InBus.ARBurst;
		temp.ARLock   := InBus.ARLock;
		temp.ARQOS    := InBus.ARQOS;
		temp.ARRegion := InBus.ARRegion;
		temp.ARUser   := InBus.ARUser;
		temp.RReady   := InBus.RReady;
		return temp;
	end function;

	function AddressMask(InBus : T_AXI4_Bus_M2S; Mask : std_logic_vector) return T_AXI4_Bus_M2S is
		variable temp : InBus'subtype;
	begin
		assert Mask'length = InBus.AWAddr'length report "PoC.AXI4_Full.AddressTranslate: Length of Mask-Bits and Address-Bits is no equal!" severity failure;

		temp.AWID     := InBus.AWID;
		temp.AWAddr   := InBus.AWAddr and Mask;
		temp.AWLen    := InBus.AWLen;
		temp.AWSize   := InBus.AWSize;
		temp.AWBurst  := InBus.AWBurst;
		temp.AWLock   := InBus.AWLock;
		temp.AWQOS    := InBus.AWQOS;
		temp.AWRegion := InBus.AWRegion;
		temp.AWUser   := InBus.AWUser;
		temp.AWValid  := InBus.AWValid;
		temp.AWCache  := InBus.AWCache;
		temp.AWProt   := InBus.AWProt;
		temp.WValid   := InBus.WValid;
		temp.WLast    := InBus.WLast;
		temp.WUser    := InBus.WUser;
		temp.WData    := InBus.WData;
		temp.WStrb    := InBus.WStrb;
		temp.BReady   := InBus.BReady;
		temp.ARValid  := InBus.ARValid;
		temp.ARAddr   := InBus.ARAddr and Mask;
		temp.ARCache  := InBus.ARCache;
		temp.ARProt   := InBus.ARProt;
		temp.ARID     := InBus.ARID;
		temp.ARLen    := InBus.ARLen;
		temp.ARSize   := InBus.ARSize;
		temp.ARBurst  := InBus.ARBurst;
		temp.ARLock   := InBus.ARLock;
		temp.ARQOS    := InBus.ARQOS;
		temp.ARRegion := InBus.ARRegion;
		temp.ARUser   := InBus.ARUser;
		temp.RReady   := InBus.RReady;
		return temp;
	end function;

	function AddressResize(InBus : T_AXI4_Bus_M2S; AddressBits : natural) return T_AXI4_Bus_M2S is
		variable temp : T_AXI4_Bus_M2S(
		AWID(InBus.AWID'range), ARID(InBus.ARID'range),
		AWUser(InBus.AWUser'range), ARUser(InBus.ARUser'range), WUser(InBus.WUser'range),
		WData(InBus.WData'range), WStrb(InBus.WStrb'range),
		AWAddr(AddressBits - 1 downto 0), ARAddr(AddressBits - 1 downto 0)
		);
	begin
		temp.AWID     := InBus.AWID;
		temp.AWAddr   := resize(InBus.AWAddr, AddressBits);
		temp.AWLen    := InBus.AWLen;
		temp.AWSize   := InBus.AWSize;
		temp.AWBurst  := InBus.AWBurst;
		temp.AWLock   := InBus.AWLock;
		temp.AWQOS    := InBus.AWQOS;
		temp.AWRegion := InBus.AWRegion;
		temp.AWUser   := InBus.AWUser;
		temp.AWValid  := InBus.AWValid;
		temp.AWCache  := InBus.AWCache;
		temp.AWProt   := InBus.AWProt;
		temp.WValid   := InBus.WValid;
		temp.WLast    := InBus.WLast;
		temp.WUser    := InBus.WUser;
		temp.WData    := InBus.WData;
		temp.WStrb    := InBus.WStrb;
		temp.BReady   := InBus.BReady;
		temp.ARValid  := InBus.ARValid;
		temp.ARAddr   := resize(InBus.ARAddr, AddressBits);
		temp.ARCache  := InBus.ARCache;
		temp.ARProt   := InBus.ARProt;
		temp.ARID     := InBus.ARID;
		temp.ARLen    := InBus.ARLen;
		temp.ARSize   := InBus.ARSize;
		temp.ARBurst  := InBus.ARBurst;
		temp.ARLock   := InBus.ARLock;
		temp.ARQOS    := InBus.ARQOS;
		temp.ARRegion := InBus.ARRegion;
		temp.ARUser   := InBus.ARUser;
		temp.RReady   := InBus.RReady;
		return temp;
	end function;

	function EnableTransaction(InBus : T_AXI4_Bus_S2M; Enable : std_logic) return T_AXI4_Bus_S2M is
		variable temp : InBus'subtype;
	begin
		temp.AWReady := InBus.AWReady and Enable;
		temp.WReady  := InBus.WReady and Enable;
		temp.BValid  := InBus.BValid and Enable;
		temp.BResp   := InBus.BResp;
		temp.BID     := InBus.BID;
		temp.BUser   := InBus.BUser;
		temp.ARReady := InBus.ARReady and Enable;
		temp.RValid  := InBus.RValid and Enable;
		temp.RData   := InBus.RData;
		temp.RResp   := InBus.RResp;
		temp.RID     := InBus.RID;
		temp.RLast   := InBus.RLast;
		temp.RUser   := InBus.RUser;
		return temp;
	end function;

	function EnableTransaction(InBus : T_AXI4_Bus_S2M_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_S2M_VECTOR is
		variable temp : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i) := EnableTransaction(InBus(i), Enable(i));
		end loop;
		return temp;
	end function;

	function DisableWrite(InBus : T_AXI4_Bus_M2S) return T_AXI4_Bus_M2S is
		variable temp               : InBus'subtype;
	begin
		temp.AWID     := (InBus.AWID'range     => '0');
		temp.AWAddr   := (InBus.AWAddr'range   => '0');
		temp.AWLen    := (InBus.AWLen'range    => '0');
		temp.AWSize   := (InBus.AWSize'range   => '0');
		temp.AWBurst  := (InBus.AWBurst'range  => '0');
		temp.AWLock   := (InBus.AWLock'range   => '0');
		temp.AWQOS    := (InBus.AWQOS'range    => '0');
		temp.AWRegion := (InBus.AWRegion'range => '0');
		temp.AWUser   := (InBus.AWUser'range   => '0');
		temp.AWCache  := (InBus.AWCache'range  => '0');
		temp.AWProt   := (InBus.AWProt'range   => '0');
		temp.WUser    := (InBus.WUser'range    => '0');
		temp.WData    := (InBus.WData'range    => '0');
		temp.WStrb    := (InBus.WStrb'range    => '0');
		temp.BReady   := '0';
		temp.AWValid  := '0';
		temp.WValid   := '0';
		temp.WLast    := '0';

		temp.ARValid  := InBus.ARValid;
		temp.ARAddr   := InBus.ARAddr;
		temp.ARCache  := InBus.ARCache;
		temp.ARProt   := InBus.ARProt;
		temp.ARID     := InBus.ARID;
		temp.ARLen    := InBus.ARLen;
		temp.ARSize   := InBus.ARSize;
		temp.ARBurst  := InBus.ARBurst;
		temp.ARLock   := InBus.ARLock;
		temp.ARQOS    := InBus.ARQOS;
		temp.ARRegion := InBus.ARRegion;
		temp.ARUser   := InBus.ARUser;
		temp.RReady   := InBus.RReady;
		return temp;
	end function;

	function DisableRead(InBus : T_AXI4_Bus_M2S) return T_AXI4_Bus_M2S is
		variable temp              : InBus'subtype;
	begin
		temp.AWID     := InBus.AWID;
		temp.AWAddr   := InBus.AWAddr;
		temp.AWLen    := InBus.AWLen;
		temp.AWSize   := InBus.AWSize;
		temp.AWBurst  := InBus.AWBurst;
		temp.AWLock   := InBus.AWLock;
		temp.AWQOS    := InBus.AWQOS;
		temp.AWRegion := InBus.AWRegion;
		temp.AWUser   := InBus.AWUser;
		temp.AWValid  := InBus.AWValid;
		temp.AWCache  := InBus.AWCache;
		temp.AWProt   := InBus.AWProt;
		temp.WValid   := InBus.WValid;
		temp.WLast    := InBus.WLast;
		temp.WUser    := InBus.WUser;
		temp.WData    := InBus.WData;
		temp.WStrb    := InBus.WStrb;
		temp.BReady   := InBus.BReady;

		temp.ARValid  := '0';
		temp.ARAddr   := (InBus.ARAddr'range   => '0');
		temp.ARCache  := (InBus.ARCache'range  => '0');
		temp.ARProt   := (InBus.ARProt'range   => '0');
		temp.ARID     := (InBus.ARID'range     => '0');
		temp.ARLen    := (InBus.ARLen'range    => '0');
		temp.ARSize   := (InBus.ARSize'range   => '0');
		temp.ARBurst  := (InBus.ARBurst'range  => '0');
		temp.ARLock   := (InBus.ARLock'range   => '0');
		temp.ARQOS    := (InBus.ARQOS'range    => '0');
		temp.ARRegion := (InBus.ARRegion'range => '0');
		temp.ARUser   := (InBus.ARUser'range   => '0');
		temp.RReady   := '0';
		return temp;
	end function;

	function DisableWrite(InBus : T_AXI4_Bus_S2M) return T_AXI4_Bus_S2M is
		variable temp               : InBus'subtype;
	begin
		temp.AWReady := '0';
		temp.WReady  := '0';
		temp.BValid  := '0';
		temp.BResp   := (InBus.BResp'range => '0');
		temp.BID     := (InBus.BID'range   => '0');
		temp.BUser   := (InBus.BUser'range => '0');

		temp.ARReady := InBus.ARReady;
		temp.RValid  := InBus.RValid;
		temp.RData   := InBus.RData;
		temp.RResp   := InBus.RResp;
		temp.RID     := InBus.RID;
		temp.RLast   := InBus.RLast;
		temp.RUser   := InBus.RUser;
		return temp;
	end function;

	function DisableRead(InBus : T_AXI4_Bus_S2M) return T_AXI4_Bus_S2M is
		variable temp              : InBus'subtype;
	begin
		temp.AWReady := InBus.AWReady;
		temp.WReady  := InBus.WReady;
		temp.BValid  := InBus.BValid;
		temp.BResp   := InBus.BResp;
		temp.BID     := InBus.BID;
		temp.BUser   := InBus.BUser;

		temp.ARReady := '0';
		temp.RValid  := '0';
		temp.RLast   := '0';
		temp.RData   := (InBus.RData'range => '0');
		temp.RResp   := (InBus.RResp'range => '0');
		temp.RID     := (InBus.RID'range   => '0');
		temp.RUser   := (InBus.RUser'range => '0');
		return temp;
	end function;
	function DisableWrite(InBus : T_AXI4_Bus_M2S_VECTOR) return T_AXI4_Bus_M2S_VECTOR is
		variable temp               : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i) := DisableWrite(InBus(i));
		end loop;
		return temp;
	end function;

	function DisableRead(InBus : T_AXI4_Bus_M2S_VECTOR) return T_AXI4_Bus_M2S_VECTOR is
		variable temp              : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i) := DisableRead(InBus(i));
		end loop;
		return temp;
	end function;

	function DisableWrite(InBus : T_AXI4_Bus_S2M_VECTOR) return T_AXI4_Bus_S2M_VECTOR is
		variable temp               : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i) := DisableWrite(InBus(i));
		end loop;
		return temp;
	end function;

	function DisableRead(InBus : T_AXI4_Bus_S2M_VECTOR) return T_AXI4_Bus_S2M_VECTOR is
		variable temp              : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i) := DisableRead(InBus(i));
		end loop;
		return temp;
	end function;

	function Initialize_AXI4_Bus_S2M(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_S2M is
		variable var : T_AXI4_Bus_S2M(
		BID(ite(IDBits = 0, 1, IDBits) - 1 downto 0), RID(ite(IDBits = 0, 1, IDBits) - 1 downto 0),
		BUser(ite(UserBits = 0, 1, UserBits) - 1 downto 0), RUser(ite(UserBits = 0, 1, UserBits) - 1 downto 0),
		RData(DataBits - 1 downto 0)
		) := (
		AWReady => Value,
		WReady  => Value,
		BValid  => Value,
		BResp => (others => Value),
		BID => (ite(IDBits = 0, 1, IDBits) - 1 downto 0 => Value),
		BUser => (ite(UserBits = 0, 1, UserBits) - 1 downto 0 => Value),
		ARReady => Value,
		RValid  => Value,
		RData => (DataBits - 1 downto 0 => Value),
		RResp => (others => Value),
		RID => (ite(IDBits = 0, 1, IDBits) - 1 downto 0 => Value),
		RLast   => Value,
		RUser => (ite(UserBits = 0, 1, UserBits) - 1 downto 0 => Value)
		);
	begin
		return var;
	end function;

	function Initialize_AXI4_Bus_M2S(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_M2S is
		variable var : T_AXI4_Bus_M2S(
		AWID(ite(IDBits = 0, 1, IDBits) - 1 downto 0), ARID(ite(IDBits = 0, 1, IDBits) - 1 downto 0),
		AWUser(ite(UserBits = 0, 1, UserBits) - 1 downto 0), ARUser(ite(UserBits = 0, 1, UserBits) - 1 downto 0), WUser(ite(UserBits = 0, 1, UserBits) - 1 downto 0),
		WData(DataBits - 1 downto 0), WStrb((DataBits / 8) - 1 downto 0),
		AWAddr(AddressBits - 1 downto 0), ARAddr(AddressBits - 1 downto 0)
		) := (
		AWValid => Value,
		AWCache => (others => Value),
		AWAddr => (AddressBits - 1 downto 0 => Value),
		AWProt => (others => Value),
		AWID => (ite(IDBits = 0, 1, IDBits) - 1 downto 0 => Value),
		AWLen => (others => Value),
		AWSize => (others => Value),
		AWBurst => (others => Value),
		AWLock => (others => Value),
		AWQOS => (others => Value),
		AWRegion => (others => Value),
		AWUser => (ite(UserBits = 0, 1, UserBits) - 1 downto 0 => Value),
		WValid  => Value,
		WData => (DataBits - 1 downto 0 => Value),
		WStrb => ((DataBits / 8) - 1 downto 0 => Value),
		WLast   => Value,
		WUser => (ite(UserBits = 0, 1, UserBits) - 1 downto 0 => Value),
		BReady  => Value,
		ARValid => Value,
		ARCache => (others => Value),
		ARAddr => (AddressBits - 1 downto 0 => Value),
		ARProt => (others => Value),
		ARID => (ite(IDBits = 0, 1, IDBits) - 1 downto 0 => Value),
		ARLen => (others => Value),
		ARSize => (others => Value),
		ARBurst => (others => Value),
		ARLock => (others => Value),
		ARQOS => (others => Value),
		ARRegion => (others => Value),
		ARUser => (ite(UserBits = 0, 1, UserBits) - 1 downto 0 => Value),
		RReady  => Value
		);
	begin
		return var;
	end function;

	function Initialize_AXI4_Bus(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_Bus is
	begin
		return (
		M2S => Initialize_AXI4_Bus_M2S(AddressBits, DataBits, UserBits, IDBits),
		S2M => Initialize_AXI4_Bus_S2M(AddressBits, DataBits, UserBits, IDBits)
		);
	end function;

	procedure ConnectAndResize(signal In_M2S : in T_AXI4_Bus_M2S; signal In_S2M : out T_AXI4_Bus_S2M; signal Out_M2S : out T_AXI4_Bus_M2S; signal Out_S2M : in T_AXI4_Bus_S2M; constant Info_Prefix : string := "") is
	begin
		assert In_S2M.RID'length = Out_S2M.RID'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing RID from " & to_string(Out_S2M.RID'length) & " to " & to_string(In_S2M.RID'length) severity NOTE;
		assert In_S2M.BID'length = Out_S2M.BID'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing BID from " & to_string(Out_S2M.BID'length) & " to " & to_string(In_S2M.BID'length) severity NOTE;
		assert In_S2M.BUser'length = Out_S2M.BUser'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing BUser from " & to_string(Out_S2M.BUser'length) & " to " & to_string(In_S2M.BUser'length) severity NOTE;
		assert In_S2M.RUser'length = Out_S2M.RUser'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing RUser from " & to_string(Out_S2M.RUser'length) & " to " & to_string(In_S2M.RUser'length) severity NOTE;
		In_S2M.RUser   <= resize(Out_S2M.RUser, In_S2M.RUser'length);--: std_logic_vector;
		In_S2M.BUser   <= resize(Out_S2M.BUser, In_S2M.BUser'length);--: std_logic_vector;
		In_S2M.BID     <= resize(Out_S2M.BID, In_S2M.BID'length);--: std_logic_vector;
		In_S2M.RID     <= resize(Out_S2M.RID, In_S2M.RID'length);--: std_logic_vector;
		In_S2M.AWReady <= Out_S2M.AWReady;--: std_logic;
		In_S2M.WReady  <= Out_S2M.WReady;--: std_logic;
		In_S2M.BValid  <= Out_S2M.BValid;--: std_logic;
		In_S2M.BResp   <= Out_S2M.BResp;--: T_AXI4_Response;
		In_S2M.ARReady <= Out_S2M.ARReady;--: std_logic;
		In_S2M.RValid  <= Out_S2M.RValid;--: std_logic;
		In_S2M.RData   <= Out_S2M.RData;--: std_logic_vector;
		In_S2M.RResp   <= Out_S2M.RResp;--: T_AXI4_Response;
		In_S2M.RLast   <= Out_S2M.RLast;--: std_logic;

		assert Out_M2S.ARID'length = In_M2S.ARID'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing ARID from " & to_string(In_M2S.ARID'length) & " to " & to_string(Out_M2S.ARID'length) severity NOTE;
		assert Out_M2S.AWID'length = In_M2S.AWID'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing AWID from " & to_string(In_M2S.AWID'length) & " to " & to_string(Out_M2S.AWID'length) severity NOTE;
		assert Out_M2S.AWAddr'length = In_M2S.AWAddr'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing AWAddr from " & to_string(In_M2S.AWAddr'length) & " to " & to_string(Out_M2S.AWAddr'length) severity NOTE;
		assert Out_M2S.ARAddr'length = In_M2S.ARAddr'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing ARAddr from " & to_string(In_M2S.ARAddr'length) & " to " & to_string(Out_M2S.ARAddr'length) severity NOTE;
		assert Out_M2S.ARUser'length = In_M2S.ARUser'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing ARUser from " & to_string(In_M2S.ARUser'length) & " to " & to_string(Out_M2S.ARUser'length) severity NOTE;
		assert Out_M2S.AWUser'length = In_M2S.AWUser'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing AWUser from " & to_string(In_M2S.AWUser'length) & " to " & to_string(Out_M2S.AWUser'length) severity NOTE;
		assert Out_M2S.WUser'length = In_M2S.WUser'length report Info_Prefix & " AXI4_Full.pkg.ConnectAndResize:: Resizing WUser from " & to_string(In_M2S.WUser'length) & " to " & to_string(Out_M2S.WUser'length) severity NOTE;
		Out_M2S.ARID     <= resize(In_M2S.ARID, Out_M2S.ARID'length);--: std_logic_vector;
		Out_M2S.AWID     <= resize(In_M2S.AWID, Out_M2S.AWID'length);--: std_logic_vector;
		Out_M2S.AWAddr   <= resize(In_M2S.AWAddr, Out_M2S.AWAddr'length);--: std_logic_vector;
		Out_M2S.ARAddr   <= resize(In_M2S.ARAddr, Out_M2S.ARAddr'length);--: std_logic_vector;
		Out_M2S.ARUser   <= resize(In_M2S.ARUser, Out_M2S.ARUser'length);--: std_logic_vector;
		Out_M2S.AWUser   <= resize(In_M2S.AWUser, Out_M2S.AWUser'length);--: std_logic_vector;
		Out_M2S.WUser    <= resize(In_M2S.WUser, Out_M2S.WUser'length);--: std_logic_vector;
		Out_M2S.AWLen    <= In_M2S.AWLen;--: std_logic_vector(7 downto 0);
		Out_M2S.AWSize   <= In_M2S.AWSize;--: T_AXI4_Size;
		Out_M2S.AWBurst  <= In_M2S.AWBurst;--: T_AXI4_Burst;
		Out_M2S.AWLock   <= In_M2S.AWLock;--: std_logic_vector(0 to 0);
		Out_M2S.AWQOS    <= In_M2S.AWQOS;--: T_AXI4_QoS;
		Out_M2S.AWRegion <= In_M2S.AWRegion;--: T_AXI4_Region;
		Out_M2S.AWValid  <= In_M2S.AWValid;--: std_logic;
		Out_M2S.AWCache  <= In_M2S.AWCache;--: T_AXI4_Cache;
		Out_M2S.AWProt   <= In_M2S.AWProt;--: T_AXI4_Protect;
		Out_M2S.WValid   <= In_M2S.WValid;--: std_logic;
		Out_M2S.WLast    <= In_M2S.WLast;--: std_logic;
		Out_M2S.WData    <= In_M2S.WData;--: std_logic_vector;
		Out_M2S.WStrb    <= In_M2S.WStrb;--: std_logic_vector;
		Out_M2S.BReady   <= In_M2S.BReady;--: std_logic;
		Out_M2S.ARValid  <= In_M2S.ARValid;--: std_logic;
		Out_M2S.ARCache  <= In_M2S.ARCache;--: T_AXI4_Cache;
		Out_M2S.ARProt   <= In_M2S.ARProt;--: T_AXI4_Protect;
		Out_M2S.ARLen    <= In_M2S.ARLen;--: std_logic_vector(7 downto 0);
		Out_M2S.ARSize   <= In_M2S.ARSize;--: T_AXI4_Size;
		Out_M2S.ARBurst  <= In_M2S.ARBurst;--: T_AXI4_Burst;
		Out_M2S.ARLock   <= In_M2S.ARLock;--: std_logic_vector(0 to 0);
		Out_M2S.ARQOS    <= In_M2S.ARQOS;--: T_AXI4_QoS;
		Out_M2S.ARRegion <= In_M2S.ARRegion;--: T_AXI4_Region;
		Out_M2S.RReady   <= In_M2S.RReady;--: std_logic;
	end procedure;
end package body;

use work.AXI4_Full.all;

package AXI4Full_Sized is
	generic (
		ADDRESS_BITS : positive;
		DATA_BITS    : positive;
		USER_BITS    : positive := 1;
		ID_BITS      : positive := 1
	);

	subtype SIZED_M2S is T_AXI4_BUS_M2S(
	AWID(ID_BITS - 1 downto 0),
	AWAddr(ADDRESS_BITS - 1 downto 0),
	AWUser(USER_BITS - 1 downto 0),
	WUser(USER_BITS - 1 downto 0),
	WData(DATA_BITS - 1 downto 0),
	WStrb(DATA_BITS / 8 - 1 downto 0),
	ARAddr(ADDRESS_BITS - 1 downto 0),
	ARID(ID_BITS - 1 downto 0),
	ARUser(USER_BITS - 1 downto 0)
	);

	subtype SIZED_S2M is T_AXI4_BUS_S2M(
	BID(ID_BITS - 1 downto 0),
	BUser(USER_BITS - 1 downto 0),
	RData(DATA_BITS - 1 downto 0),
	RID(ID_BITS - 1 downto 0),
	RUser(USER_BITS - 1 downto 0)
	);

	subtype SIZED_M2S_VECTOR is T_AXI4_BUS_M2S_VECTOR(open)(
	AWID(ID_BITS - 1 downto 0),
	AWAddr(ADDRESS_BITS - 1 downto 0),
	AWUser(USER_BITS - 1 downto 0),
	WUser(USER_BITS - 1 downto 0),
	WData(DATA_BITS - 1 downto 0),
	WStrb(DATA_BITS / 8 - 1 downto 0),
	ARAddr(ADDRESS_BITS - 1 downto 0),
	ARID(ID_BITS - 1 downto 0),
	ARUser(USER_BITS - 1 downto 0)
	);

	subtype SIZED_S2M_VECTOR is T_AXI4_BUS_S2M_VECTOR(open)(
	BID(ID_BITS - 1 downto 0),
	BUser(USER_BITS - 1 downto 0),
	RData(DATA_BITS - 1 downto 0),
	RID(ID_BITS - 1 downto 0),
	RUser(USER_BITS - 1 downto 0)
	);
end package;
