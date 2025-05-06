-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Patrick Lehmann
--                  Stefan Unrein
--
-- Package:          Generic AMBA AXI4-Lite bus description.
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4-Lite description.
-- The bus created by the two main unconstrained records T_AXI4LITE_BUS_M2S and
-- T_AXI4LITE_BUS_S2M. *_M2S stands for Master-to-Slave and defines the direction
-- from master to the slave component of the bus. Vice versa for the *_S2M type.
--
-- Usage:
-- You can use this record type as a normal, unconstrained record. Create signal
-- with a constrained subtype and connect it to the desired components.
-- To avoid constraining overhead, you can use the generic sized-package:
-- package AXI4Lite_Sized_32A_64D is
--   new work.AXI4Lite_Sized
--   generic map(
--     ADDRESS_BITS  => 32,
--     DATA_BITS     => 64
--   );
-- Then simply use the sized subtypes:
-- signal DeMux_M2S : AXI4Lite_Sized_32A_64D.Sized_M2S;
-- signal DeMux_S2M : AXI4Lite_Sized_32A_64D.Sized_S2M;
--
-- If multiple components need to be connected, you can also use the predefined
-- vector type T_AXI4LITE_BUS_M2S_VECTOR and T_AXI4LITE_BUS_S2M_VECTOR, which
-- gives you a vector of AXI4Lite records. This is also available in the generic
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
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;
use     work.AXI4_Common.all;

package AXI4Lite is
	constant DEBUG : boolean := false;

	attribute Count        : integer;

	alias T_AXI4_Response               is work.AXI4_Common.T_AXI4_Response;
	alias C_AXI4_RESPONSE_OKAY          is work.AXI4_Common.C_AXI4_RESPONSE_OKAY;
	alias C_AXI4_RESPONSE_EX_OKAY       is work.AXI4_Common.C_AXI4_RESPONSE_EX_OKAY;
	alias C_AXI4_RESPONSE_SLAVE_ERROR   is work.AXI4_Common.C_AXI4_RESPONSE_SLAVE_ERROR;
	alias C_AXI4_RESPONSE_DECODE_ERROR  is work.AXI4_Common.C_AXI4_RESPONSE_DECODE_ERROR;
	alias C_AXI4_RESPONSE_INIT          is work.AXI4_Common.C_AXI4_RESPONSE_INIT;

	alias T_AXI4_Cache                  is work.AXI4_Common.T_AXI4_Cache;
	alias C_AXI4_CACHE_INIT             is work.AXI4_Common.C_AXI4_CACHE_INIT;
	alias C_AXI4_CACHE                  is work.AXI4_Common.C_AXI4_CACHE;

	alias T_AXI4_Protect                is work.AXI4_Common.T_AXI4_Protect;
	alias C_AXI4_PROTECT_INIT           is work.AXI4_Common.C_AXI4_PROTECT_INIT;
	alias C_AXI4_PROTECT                is work.AXI4_Common.C_AXI4_PROTECT;

	type T_AXI4LITE_BUS_M2S is record
		AWValid     : std_logic;
		AWAddr      : std_logic_vector;
		AWCache     : T_AXI4_Cache;
		AWProt      : T_AXI4_Protect;
		WValid      : std_logic;
		WData       : std_logic_vector;
		WStrb       : std_logic_vector;
		BReady      : std_logic;
		ARValid     : std_logic;
		ARAddr      : std_logic_vector;
		ARCache     : T_AXI4_Cache;
		ARProt      : T_AXI4_Protect;
		RReady      : std_logic;
	end record;

	type T_AXI4LITE_BUS_M2S_VECTOR is array(natural range <>) of T_AXI4LITE_BUS_M2S;

	function BlockTransaction(InBus : T_AXI4LITE_BUS_M2S;        Enable : std_logic) return T_AXI4LITE_BUS_M2S;
	function BlockTransaction(InBus : T_AXI4LITE_BUS_M2S_VECTOR; Enable : std_logic_vector) return T_AXI4LITE_BUS_M2S_VECTOR;

	function AddressTranslate(InBus : T_AXI4LITE_BUS_M2S; Offset : signed)           return T_AXI4LITE_BUS_M2S;
	function AddressMask(     InBus : T_AXI4LITE_BUS_M2S;   Mask : std_logic_vector) return T_AXI4LITE_BUS_M2S;

	type T_AXI4LITE_BUS_S2M is record
		WReady      : std_logic;
		BValid      : std_logic;
		BResp       : T_AXI4_Response;
		ARReady     : std_logic;
		AWReady     : std_logic;
		RValid      : std_logic;
		RData       : std_logic_vector;
		RResp       : T_AXI4_Response;
	end record;
	type T_AXI4LITE_BUS_S2M_VECTOR is array(natural range <>) of T_AXI4LITE_BUS_S2M;

	function BlockTransaction(InBus : T_AXI4LITE_BUS_S2M;        Enable : std_logic) return T_AXI4LITE_BUS_S2M;
	function BlockTransaction(InBus : T_AXI4LITE_BUS_S2M_VECTOR; Enable : std_logic_vector) return T_AXI4LITE_BUS_S2M_VECTOR;


	type T_AXI4Lite_Bus is record
		M2S   : T_AXI4LITE_BUS_M2S;
		S2M   : T_AXI4LITE_BUS_S2M;
	end record;
	type T_AXI4Lite_Bus_VECTOR is array(natural range <>) of T_AXI4Lite_Bus;

	function Initialize_AXI4Lite_Bus_M2S(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4LITE_BUS_M2S;
	function Initialize_AXI4Lite_Bus_S2M(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4LITE_BUS_S2M;
	function Initialize_AXI4Lite_Bus(    AddressBits : natural; DataBits : natural) return T_AXI4Lite_Bus;


	-------Define AXI Register structure-------------
	constant Address_Width  : natural := 32;
	constant Data_Width     : natural := 32;
	constant Name_Width     : natural := 64;

	type T_AXI4_Register is record
		Address : unsigned(Address_Width -1 downto 0);
		Data    : std_logic_vector(Data_Width -1 downto 0);
		Mask    : std_logic_vector(Data_Width -1 downto 0);
	end record;

	function to_AXI4_Register(Name : string := ""; Address : unsigned(Address_Width -1 downto 0); Data : std_logic_vector(Data_Width -1 downto 0); Mask : std_logic_vector(Data_Width -1 downto 0)) return T_AXI4_Register;
	function Initialize_AXI4_register(Value : std_logic := 'Z') return T_AXI4_Register;

	type T_AXI4_Register_Vector is array (natural range <>) of T_AXI4_Register;

	type T_AXI4_Register_Set is record
		AXI4_Register  : T_AXI4_Register_Vector;
		Last_Index     : natural;
	end record;

	type T_AXI4_Register_Set_VECTOR is array (natural range <>) of T_AXI4_Register_Set;

	function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector; size : natural) return T_AXI4_Register_Set;


	--------Define generic AXI4L Register Configuration--------
	type T_ReadWrite_Config is (
		constant_fromInit,
		readable, readable_non_reg,
		readWriteable, readWriteable_non_reg,
		latchValue_clearOnRead, latchValue_clearOnWrite,
		latchHighBit_clearOnRead, latchHighBit_clearOnWrite,
		latchLowBit_clearOnRead, latchLowBit_clearOnWrite,
		Reserved
	);
	attribute Count of T_ReadWrite_Config : type is T_ReadWrite_Config'pos(T_ReadWrite_Config'high) + 1;

	type T_AXI4_Register_Description is record
		Name                  : string(1 to Name_Width);
		Address               : unsigned(Address_Width-1 downto 0);
		rw_config             : T_ReadWrite_Config;
		Init_Value            : std_logic_vector(Data_Width-1 downto 0);
		Auto_Clear_Mask       : std_logic_vector(Data_Width-1 downto 0);
		Is_Interrupt_Register : boolean;
	end record;

	function to_string(reg : T_AXI4_Register_Description) return string;

	type T_AXI4_Register_Description_Vector is array (natural range <>) of T_AXI4_Register_Description;

	--------File IO--------
	impure function write_c_header_file(FileName : string; Name : string; reg : T_AXI4_Register_Description_Vector) return boolean;
	impure function write_c_header_file_t(FileName : string; Name : string; reg : T_AXI4_Register_Description_Vector) return boolean;
	impure function write_csv_file(FileName : string; reg : T_AXI4_Register_Description_Vector) return boolean;
	impure function read_csv_file(FileName : string) return T_AXI4_Register_Description_Vector;
	impure function write_yml_file(
		FileName : string;
		reg : T_AXI4_Register_Description_Vector;
		reg_name : string;
		defines : key_value_pair_v := (0 to 0 => C_key_value_pair_empty);
		enums : key_value_pair_v := (0 to 0 => C_key_value_pair_empty)
	) return boolean;

	--------Modify config--------
	function filter_Register_Description_Vector( str : string;    description_vector : T_AXI4_Register_Description_Vector) return T_AXI4_Register_Description_Vector;
	function filter_Register_Description_Vector(char : character; description_vector : T_AXI4_Register_Description_Vector) return T_AXI4_Register_Description_Vector;
	function Filter_DescriptionVector(                                        Config : T_AXI4_Register_Description_Vector; filter : std_logic_vector) return T_AXI4_Register_Description_Vector;
	function add_Prefix(prefix : string;                                      Config : T_AXI4_Register_Description_Vector; offset : unsigned(Address_Width -1 downto 0) := (others => '0')) return T_AXI4_Register_Description_Vector;

	function to_AXI4_Register_Description(
        Name                  : string                                   := "";
		Address               : unsigned(Address_Width -1 downto 0);
	    writeable             : boolean;
	    Init_Value            : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
	    Auto_Clear_Mask       : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		Is_Interrupt_Register : boolean                                  := false
	) return T_AXI4_Register_Description;

	function to_AXI4_Register_Description(
        Name                  : string                                   := "";
        Address               : unsigned(Address_Width -1 downto 0);
	    rw_config             : T_ReadWrite_Config                       := readWriteable;
	    Init_Value            : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
	    Auto_Clear_Mask       : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		Is_Interrupt_Register : boolean                                  := false
    ) return T_AXI4_Register_Description;


	--------Helper functions for usage--------
	function get_addresses(description_vector : T_AXI4_Register_Description_Vector)     return T_SLUV;
	function get_InitValue(description_vector : T_AXI4_Register_Description_Vector)     return T_SLVV;
	function get_AutoClearMask(description_vector : T_AXI4_Register_Description_Vector) return T_SLVV;

	function get_index(          Name : string;                              Register_Vector : T_AXI4_Register_Description_Vector) return integer;
	function get_NumberOfIndexes(Name : string;                              Register_Vector : T_AXI4_Register_Description_Vector) return integer;
	function get_indexRange(     Name : string;                              Register_Vector : T_AXI4_Register_Description_Vector) return T_INTVEC;
	function get_Address(        Name : string;                              Register_Vector : T_AXI4_Register_Description_Vector) return unsigned;
	function get_Name(        Address : unsigned(Address_Width -1 downto 0); Register_Vector : T_AXI4_Register_Description_Vector) return string;
	function get_Interrupt_count(                                            Register_Vector : T_AXI4_Register_Description_Vector) return natural;
	function get_Interrupt_range(                                            Register_Vector : T_AXI4_Register_Description_Vector) return T_NATVEC;
--	function get_index(Address : unsigned(Address_Width -1 downto 0); Register_Vector : T_AXI4_Register_Description_Vector) return integer;

	function get_RegisterAddressBits(Config : T_AXI4_Register_Description_Vector) return positive;

	function get_strobeVector(Config : T_AXI4_Register_Description_Vector) return std_logic_vector;

	function normalize(Config : T_AXI4_Register_Description_Vector) return T_AXI4_Register_Description_Vector;

	--------Special Register Configurations--------
	constant Atomic_RegisterDescription_Vector : T_AXI4_Register_Description_Vector(0 to 3);

	procedure Make_AtomicRegister(
--		signal   Clock                     : in  std_logic;
		constant Reset                     : in  std_logic;
		constant RegisterFile_ReadPort     : in  T_SLVV(Atomic_RegisterDescription_Vector'range)(Data_Width -1 downto 0);
		signal   RegisterFile_WritePort    : out T_SLVV(Atomic_RegisterDescription_Vector'range)(Data_Width -1 downto 0);
		constant RegisterFile_ReadPort_hit : in  std_logic_vector(Atomic_RegisterDescription_Vector'range);
		constant PL_WriteValue             : in  std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		constant PL_WriteStrobe            : in  std_logic := '0';
		constant Value_reg                 : in  std_logic_vector(Data_Width -1 downto 0); -- make this signal as `<= nextValue_reg when rising_edge(Clock);`
		signal   nextValue_reg             : out std_logic_vector(Data_Width -1 downto 0)
	);

	constant IO_RegisterDescription_Vector : T_AXI4_Register_Description_Vector(0 to 7);

	procedure Make_IORegister(
--		signal Clock                     : in  std_logic;
		constant Reset                     : in  std_logic;
		constant RegisterFile_ReadPort     : in  T_SLVV(IO_RegisterDescription_Vector'range)(Data_Width -1 downto 0);
		signal   RegisterFile_WritePort    : out T_SLVV(IO_RegisterDescription_Vector'range)(Data_Width -1 downto 0);
		constant RegisterFile_ReadPort_hit : in  std_logic_vector(IO_RegisterDescription_Vector'range);
		constant Input                     : in  std_logic_vector(Data_Width -1 downto 0);
		signal   Output                    : out std_logic_vector(Data_Width -1 downto 0);
		signal   Tristate                  : out std_logic_vector(Data_Width -1 downto 0);
		constant IO_reg                    : in  std_logic_vector(Data_Width -1 downto 0); -- make this signal as `<= nextIO_reg when rising_edge(Clock);`
		signal   nextIO_reg                : out std_logic_vector(Data_Width -1 downto 0);
		constant T_reg                     : in  std_logic_vector(Data_Width -1 downto 0); -- make this signal as `<= nextT_reg  when rising_edge(Clock);`
		signal   nextT_reg                 : out std_logic_vector(Data_Width -1 downto 0)
	);


	--NOTE: This procedure is simplifying the register definition. But it slows down the Synthesis a lot on Vivado.
	-- Tested with Vivado 2018.3, 10 Registers took 5mins to synthesize.
	-- TODO: Test in newer versions. If this works, reactivate.
	----------------------------------------------------------------------
	-- procedure to easily define a description vector inside a function--
	----------------------------------------------------------------------
	-- **To use this procedure, this variables need to be defined:
	--	  variable temp : T_AXI4_Register_Description_Vector(0 to 127);
	--	  variable idx  : natural := 0;
	--	  variable addr : natural := 0;
	-- **Example:
	--    assign(temp, idx, addr, Name => "Control", rw_Config => readWriteable);
--	procedure assign(
--		variable description_vector : inout T_AXI4_Register_Description_Vector;
--		variable idx                : inout natural;
--		variable addr               : inout natural;
--		constant offset             : in    natural := 4;
--		constant Name               : in    string := "";
--		constant writeable          : in    boolean;
--		constant Init_Value         : in    std_logic_vector(Data_Width -1 downto 0) := (others => '0');
--		constant Auto_Clear_Mask    : in    std_logic_vector(Data_Width -1 downto 0) := (others => '0');
--		constant Is_Interrupt_Register : in boolean := false
--	);
--	procedure assign(
--		variable description_vector : inout T_AXI4_Register_Description_Vector;
--		variable idx                : inout natural;
--		variable addr               : inout natural;
--		constant offset             : in    natural := 4;
--		constant Name               : in    string := "";
--		constant rw_config          : in    T_ReadWrite_Config;
--		constant Init_Value         : in    std_logic_vector(Data_Width -1 downto 0) := (others => '0');
--		constant Auto_Clear_Mask    : in    std_logic_vector(Data_Width -1 downto 0) := (others => '0');
--		constant Is_Interrupt_Register : in boolean := false
--	);

end package;


package body AXI4Lite is

	function BlockTransaction(InBus : T_AXI4LITE_BUS_M2S;        Enable : std_logic) return T_AXI4LITE_BUS_M2S is
		variable temp : InBus'subtype;
	begin
		temp.AWValid:= InBus.AWValid and Enable;
		temp.AWAddr := InBus.AWAddr;
		temp.AWCache:= InBus.AWCache;
		temp.AWProt := InBus.AWProt;
		temp.WValid := InBus.WValid and Enable;
		temp.WData  := InBus.WData;
		temp.WStrb  := InBus.WStrb  ;
		temp.BReady := InBus.BReady and Enable;
		temp.ARValid:= InBus.ARValid and Enable;
		temp.ARAddr := InBus.ARAddr ;
		temp.ARCache:= InBus.ARCache;
		temp.ARProt := InBus.ARProt ;
		temp.RReady := InBus.RReady and Enable;
		return temp;
	end function;

	function BlockTransaction(InBus : T_AXI4LITE_BUS_M2S_VECTOR; Enable : std_logic_vector) return T_AXI4LITE_BUS_M2S_VECTOR is
		variable temp : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i).AWValid:= InBus(i).AWValid and Enable(i);
			temp(i).AWAddr := InBus(i).AWAddr;
			temp(i).AWCache:= InBus(i).AWCache;
			temp(i).AWProt := InBus(i).AWProt;
			temp(i).WValid := InBus(i).WValid and Enable(i);
			temp(i).WData  := InBus(i).WData;
			temp(i).WStrb  := InBus(i).WStrb  ;
			temp(i).BReady := InBus(i).BReady and Enable(i);
			temp(i).ARValid:= InBus(i).ARValid and Enable(i);
			temp(i).ARAddr := InBus(i).ARAddr ;
			temp(i).ARCache:= InBus(i).ARCache;
			temp(i).ARProt := InBus(i).ARProt ;
			temp(i).RReady := InBus(i).RReady and Enable(i);
		end loop;
		return temp;
	end function;

	function AddressTranslate(InBus : T_AXI4LITE_BUS_M2S; Offset : signed) return T_AXI4LITE_BUS_M2S is
		variable temp : InBus'subtype;
	begin
		assert Offset'length = InBus.AWAddr'length report "PoC.AXI4Lite.AddressTranslate: Length of Offeset-Bits and Address-Bits is no equal!" severity failure;

		temp.AWValid:= InBus.AWValid;
		temp.AWAddr := std_logic_vector(unsigned(InBus.AWAddr) + unsigned(std_logic_vector(Offset)));
		temp.AWCache:= InBus.AWCache;
		temp.AWProt := InBus.AWProt;
		temp.WValid := InBus.WValid;
		temp.WData  := InBus.WData;
		temp.WStrb  := InBus.WStrb  ;
		temp.BReady := InBus.BReady ;
		temp.ARValid:= InBus.ARValid;
		temp.ARAddr := std_logic_vector(unsigned(InBus.ARAddr) + unsigned(std_logic_vector(Offset)));
		temp.ARCache:= InBus.ARCache;
		temp.ARProt := InBus.ARProt ;
		temp.RReady := InBus.RReady;
		return temp;
	end function;

	function AddressMask(     InBus : T_AXI4LITE_BUS_M2S;   Mask : std_logic_vector) return T_AXI4LITE_BUS_M2S is
		variable temp : InBus'subtype;
	begin
		assert Mask'length = InBus.AWAddr'length report "PoC.AXI4Lite.AddressTranslate: Length of Mask-Bits and Address-Bits is no equal!" severity failure;

		temp.AWValid:= InBus.AWValid;
		temp.AWAddr := InBus.AWAddr and Mask;
		temp.AWCache:= InBus.AWCache;
		temp.AWProt := InBus.AWProt;
		temp.WValid := InBus.WValid;
		temp.WData  := InBus.WData;
		temp.WStrb  := InBus.WStrb  ;
		temp.BReady := InBus.BReady ;
		temp.ARValid:= InBus.ARValid;
		temp.ARAddr := InBus.ARAddr and Mask;
		temp.ARCache:= InBus.ARCache;
		temp.ARProt := InBus.ARProt ;
		temp.RReady := InBus.RReady;
		return temp;
	end function;

	function BlockTransaction(InBus : T_AXI4LITE_BUS_S2M;        Enable : std_logic) return T_AXI4LITE_BUS_S2M is
		variable temp : InBus'subtype;
	begin
		temp.WReady := InBus.WReady and Enable;
		temp.BValid := InBus.BValid and Enable;
		temp.BResp  := InBus.BResp;
		temp.ARReady:= InBus.ARReady and Enable;
		temp.AWReady:= InBus.AWReady and Enable;
		temp.RValid := InBus.RValid and Enable;
		temp.RData  := InBus.RData;
		temp.RResp  := InBus.RResp;
		return temp;
	end function;

	function BlockTransaction(InBus : T_AXI4LITE_BUS_S2M_VECTOR; Enable : std_logic_vector) return T_AXI4LITE_BUS_S2M_VECTOR is
		variable temp : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i).WReady := InBus(i).WReady and Enable(i);
			temp(i).BValid := InBus(i).BValid and Enable(i);
			temp(i).BResp  := InBus(i).BResp;
			temp(i).ARReady:= InBus(i).ARReady and Enable(i);
			temp(i).AWReady:= InBus(i).AWReady and Enable(i);
			temp(i).RValid := InBus(i).RValid and Enable(i);
			temp(i).RData  := InBus(i).RData;
			temp(i).RResp  := InBus(i).RResp;
		end loop;
		return temp;
	end function;


	function Initialize_AXI4Lite_Bus_M2S(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4Lite_Bus_M2S is
		variable var : T_AXI4Lite_Bus_M2S(
			AWAddr(AddressBits -1 downto 0), WData(DataBits -1 downto 0),
			WStrb((DataBits /8) -1 downto 0), ARAddr(AddressBits -1 downto 0)) :=(
--        AClk    => Value,
--        AResetN => Value,
				AWValid => Value,
				AWCache => (others => Value),
				AWAddr  => (AddressBits-1 downto 0 => Value),
				AWProt  => (others => Value),
				WValid  => Value,
				WData   => (DataBits - 1 downto 0 => Value),
				WStrb   => ((DataBits / 8) - 1 downto 0 => Value),
				BReady  => Value,
				ARValid => Value,
				ARCache => (others => Value),
				ARAddr  => (AddressBits - 1 downto 0 => Value),
				ARProt  => (others => Value),
				RReady  => Value
			);
	begin
		return var;
	end function;

	function Initialize_AXI4Lite_Bus_S2M(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4Lite_Bus_S2M is
		variable var : T_AXI4Lite_Bus_S2M(RData(DataBits -1 downto 0)) :=(
			AWReady => Value,
			WReady  => Value,
			BValid  => Value,
			BResp   => (others => Value),
			ARReady => Value,
			RValid  => Value,
			RData   => (DataBits - 1 downto 0 => 'Z'),
			RResp   => (others => Value)
		);
	begin
		return var;
	end function;

	function Initialize_AXI4Lite_Bus(AddressBits : natural; DataBits : natural) return T_AXI4Lite_Bus is
	begin
		return (
			M2S => Initialize_AXI4Lite_Bus_M2S(AddressBits, DataBits),
			S2M => Initialize_AXI4Lite_Bus_S2M(AddressBits, DataBits)
		);
	end function;



	-------Define AXI Register structure-------------
--  function to_AXI4_Register(Address : unsigned; Data : std_logic_vector; Mask : std_logic_vector; AddressBits : natural; DataBits : natural) return T_AXI4_Register is
--    variable temp : T_AXI4_Register(
--      Address(AddressBits -1 downto 0),
--      Data(DataBits -1 downto 0),
--      Mask(DataBits -1 downto 0)) := (
--        Address => Address,
--        Data    => Data,
--        Mask    => Mask
--      );
--  begin
--    return temp;
--  end function;

	function to_AXI4_Register(Name : string := ""; Address : unsigned(Address_Width -1 downto 0); Data : std_logic_vector(Data_Width -1 downto 0); Mask : std_logic_vector(Data_Width -1 downto 0)) return T_AXI4_Register is
		variable temp : T_AXI4_Register := (
				Address => Address,
				Data    => Data,
				Mask    => Mask
			);
	begin
		return temp;
	end function;

--  function Initialize_AXI4_register(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4_Register is
--    variable temp : T_AXI4_Register(
--      Address(AddressBits -1 downto 0),
--      Data(DataBits -1 downto 0),
--      Mask(DataBits -1 downto 0)):=
--      to_AXI4_Register(
--        Address => (AddressBits -1 downto 0 => Value),
--        Data => (DataBits -1 downto 0 => Value),
--        Mask => (DataBits -1 downto 0 => Value),
--        AddressBits => AddressBits,
--        DataBits    => DataBits
--      );
--  begin
--    return temp;
--  end function;
	function Initialize_AXI4_register(Value : std_logic := 'Z') return T_AXI4_Register is
		variable temp : T_AXI4_Register :=
			to_AXI4_Register(
				Name    => "",
				Address => (Address_Width -1 downto 0 => Value),
				Data => (Data_Width -1 downto 0 => Value),
				Mask => (Data_Width -1 downto 0 => Value)
			);
	begin
		return temp;
	end function;
-------------------------------------------------------------------------------------------------------------

--  function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector; size : natural) return T_AXI4_Register_Set is
--    variable temp : T_AXI4_Register_Set(AXI4_Register(0 to size -1)(
--      Address(reg_vec(reg_vec'left).Address'range),
--      Data(reg_vec(reg_vec'left).Data'range),
--      Mask(reg_vec(reg_vec'left).Mask'range)
--    )--) := (
----      AXI4_Register =>
----        (others => Initialize_AXI4_register(reg_vec(reg_vec'left).Address'length, reg_vec(reg_vec'left).Data'length)),
----      Last_Index => 0
--    );

--  begin
--    temp.AXI4_Register(reg_vec'range) := reg_vec;
--    temp.Last_Index := reg_vec'length -1;
--    return temp;
--  end function;
	function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector; size : natural) return T_AXI4_Register_Set is
		variable temp : T_AXI4_Register_Set(AXI4_Register(0 to size -1)) := (
			AXI4_Register => (others => Initialize_AXI4_register),
			Last_Index    => 0
		);

	begin
		temp.AXI4_Register(reg_vec'range) := reg_vec;
		temp.Last_Index := reg_vec'length -1;
		return temp;
	end function;


	function to_string(reg : T_AXI4_Register_Description) return string is
	begin
		return " Name: " & str_replace_all(resize(reg.Name, Name_Width), NUL, ' ')
			& ", Address: 0x" & to_string(std_logic_vector(reg.address), 'h', 4)
			& ", Init_Value: 0x" & to_string(reg.Init_Value, 'h', 4)
			& ", Auto_Clear_Mask: 0x" & to_string(reg.Auto_Clear_Mask, 'h', 4)
			& ", rw_config: " & T_ReadWrite_Config'image(reg.rw_config);
	end function;

	impure function write_c_header_file(FileName : string; Name : string; reg : T_AXI4_Register_Description_Vector) return boolean is
		constant QM : character := '"';
		constant size_header    : natural := imax(FileName'length,51);
		file     FileHandle		  : TEXT open write_MODE is FileName;
  	variable CurrentLine	  : LINE;

  	procedure write(S : string) is
  	begin
  		write(CurrentLine, S);
  		writeline(FileHandle, CurrentLine);
  	end procedure;

	begin
		write("/*****************************************************");
		write("* Automatically generated File from VHDL PoC Library *");
		write("* Poc.AXI4Lite.T_AXI4_Register_Description           *");
		write("* generated C-Header File                            *");
		write("* " & FileName & " *");
		write("*****************************************************/");
		write(" ");
		write(" ");
		write(" ");
		write("enum AXI4Register_Function {");
		for i in 0 to T_ReadWrite_Config'Count -2 loop
			write("    " & T_ReadWrite_Config'image(T_ReadWrite_Config'val(i)) & ",");
		end loop;
		write("    " & T_ReadWrite_Config'image(T_ReadWrite_Config'val(T_ReadWrite_Config'Count -1)));
		write("};");
		write(" ");
		write("struct AXI4Register {");
		write("    char                  Name[" & integer'image(Name_Width) & "];");
		write("    uint32_t              Address;");
		write("    uint32_t              Init_Value;");
		write("    uint32_t              Auto_Clear_Mask;");
		write("    AXI4Register_Function rw_config;");
		write("};");
		write(" ");
		write("AXI4Register " & Name & "[]{");
		for i in 0 to reg'length -1 loop
			write("    { .Name            = " & QM & reg(i - reg'low).Name & QM & ",");
			write("      .Address         = 0x" & to_string(std_logic_vector(reg(i - reg'low).address), 'h', 4) & ",");
			write("      .Init_Value      = 0x" & to_string(std_logic_vector(reg(i - reg'low).Init_Value), 'h', 4) & ",");
			write("      .Auto_Clear_Mask = 0x" & to_string(std_logic_vector(reg(i - reg'low).Auto_Clear_Mask), 'h', 4) & ",");
			if i /= reg'high then
				write("      .rw_config       = " & T_ReadWrite_Config'image(reg(i - reg'low).rw_config) & " },");
			else
				write("      .rw_config       = " & T_ReadWrite_Config'image(reg(i - reg'low).rw_config) & " }");
			end if;
		end loop;
		write("};");
		write(" ");
		write("//end");
		return true;
	end function;

	impure function write_c_header_file_t(FileName : string; Name : string; reg : T_AXI4_Register_Description_Vector) return boolean is
		constant QM : character := '"';
		constant size_header    : natural := imax(FileName'length,51);
		file     FileHandle		  : TEXT open write_MODE is FileName;
  	variable CurrentLine	  : LINE;

  	subtype T_Name_String is string(1 to Name_Width);
  	type T_Name_String_V is array(natural range <>) of T_Name_String;

  	procedure write(S : string) is
  	begin
  		write(CurrentLine, S);
  		writeline(FileHandle, CurrentLine);
  	end procedure;

  	function resize(str : string) return string is
  	begin
  		return str_lalign(str, Name_Width, C_POC_NUL);
  	end function;

  	procedure ln is
  	begin
  		write(" ");
  	end procedure;

--  	procedure printInstanceStruct(S : string) is
--  	begin
--  	 write("struct AXI4RegisterOffset" & str_trim(str_normalize(S)) & " {");
--  	end procedure;

--  	procedure printInstanceStructE is
--  	begin
--  	 write("};");
--  	end procedure;

  	procedure printInstanceItem(S : string; preString : string := "uint32_t "; indent : natural := 1) is
  	begin
  	 write((1 to indent * 2 => ' ') & str_trim(str_replace(str_normalize(preString),".","_")) & "   " & str_trim(str_replace(str_normalize(S),".","_")) & ";");
  	end procedure;

--  	procedure printRegInstance(S : string; indent : natural := 1) is
--  	begin
--  	 write((1 to indent * 2 => ' ') & "." & str_trim(str_normalize(S)) & " {");
--  	end procedure;
--  	procedure printRegItem(S : string; i : natural; indent : natural := 2; last : boolean := false) is
--  	begin
--  	 write((1 to indent * 2 => ' ') & "." & str_trim(str_replace(str_normalize(S),".","_")) & " = 0x" & to_string(std_logic_vector(reg(i - reg'low).address), 'h', 4) & ite(last, "", ","));
--  	end procedure;


  	function numberItems(Inst : string; Inst_length : natural; Start_idx : natural) return natural is
  	begin
  		for i in Start_idx to reg'high loop
  			if reg(i).Name(1 to Inst_length) /= Inst(1 to Inst_length) then
--  				assert false report "NumberItems found: " & integer'image(i - Start_idx) severity warning;
  				return i - Start_idx;
  			end if;
  		end loop;
--  		assert false report "NumberItems found: " & integer'image(reg'high - Start_idx) severity warning;
  		return reg'high -Start_idx +1;
  	end function;

  	function subInstPos(Inst : string; Inst_length : natural; Start_idx : natural; Length_idx : natural) return integer is
  		variable ipos : integer;
  	begin
--  		assert false report "subInstPos::: Inst: " & Inst(1 to Inst_length -1) & ", Start_idx: " & integer'image(Start_idx) & ", Length_idx: " & integer'image(Length_idx) severity warning;
  		for i in Start_idx to Start_idx + Length_idx -1 loop
  			ipos := str_ipos(reg(i).Name(Inst_length +1 to Name_Width), '.');
  			if ipos >= 0 then
  				return i;
				end if;
  		end loop;
  		return -1;
  	end function;

  	function nextInstPos(Inst_length : natural; idx : natural) return integer is
  	begin
  		return str_ipos(reg(idx).Name(Inst_length +1 to Name_Width), '.');
  	end function;
  	function nextInstName(Inst_length : natural; idx : natural) return string is
  	begin
  		return resize(reg(idx).Name(1 to nextInstPos(Inst_length, idx)));
  	end function;


--  	function analyze(Inst : string; Inst_length : natural; Start_idx : natural) return natural is
--  		constant Inst_i        : T_Name_String := Inst;
--  		constant Inst_length_i : natural       := Inst_length;
--  		constant num_Items     : natural       := numberItems(Inst, Inst_length, Start_idx);
----  		variable num_Items_i   : natural       := numberItems(Inst, Inst_length, Start_idx);
--  		variable ipos          : integer;
--  		variable i             : natural       := Start_idx;
----  		variable j             : natural;
--  	begin
--  		assert false report "New Analyze::: Inst: " & Inst(1 to Inst_length) & ", Start idx: " & integer'image(Start_idx) & ", num_Items: " & integer'image(num_Items) severity warning;
----  		assert false report "Inst: " & Inst(1 to Inst_length) & ", Start idx: " & integer'image(Start_idx) severity warning;
--			while i <= Start_idx + num_Items -1 loop
----				assert false report "num_Items_i." severity warning;
----				num_Items_i := numberItems(Inst_i, Inst_length_i, i);
----				assert false report "num_Items_i: " & integer'image(num_Items_i) severity warning;
--				assert false report "i: " & integer'image(i) severity warning;
----				assert false report "ipos." severity warning;
--				ipos := subInstPos(Inst_i, Inst_length_i, i, num_Items -i +Start_idx);
--				assert false report "ipos: " & integer'image(ipos) severity warning;

--				if ipos = -1 then
--					assert false report "Found Group at: " & integer'image(i) severity warning;
--					for j in i to i + num_Items -1 loop
----						assert false report "i: " & integer'image(i) severity warning;
--						assert false report "Item at: " & integer'image(j) severity warning;
--						printInstanceItem(reg(j).Name);
--					end loop;
----					assert false report "i: " & integer'image(i) severity warning;
----					i := i + num_Items_i;
----					assert false report "i: " & integer'image(i) severity warning;
--					assert false report "Returning Group: " & integer'image(i + num_Items) severity warning;
--					return i + num_Items;
--				else
--					i := analyze(nextInstName(Inst_length_i, ipos), nextInstPos(Inst_length_i, ipos), ipos);
--				end if;

--			end loop;
--  		assert false report "End Analyze " & integer'image(i) severity warning;
--  		return i;
--  	end function;

--  	function analyze_Item(Inst : string; Inst_length : natural; Start_idx : natural) return natural is
--			variable subinst_num : natural := 0;

--  	begin
--  		for i in Start_idx to reg'high loop
--  			if str_ipos(reg(i).Name, '.') = -1 then
--  				subinst_num := subinst_num +1;
--  			else

--  			end if;
--  		end loop;
--  		return reg'high;
--  	end function;


--  	variable Names : T_Name_String_V(reg'range) := (others => (others => C_POC_NUL));

    function count_depth(str : string) return natural is
        variable num : natural := 0;
    begin
        for i in str'range loop
            if str(i) = '.' then
                num := num +1;
            end if;
        end loop;
        return num;
    end function;

  	variable Inst         : T_Name_String_V(0 to 5)     := (others => (others => ' '));
  	variable Inst_length  : T_NATVEC(0 to 5)            := (others => 0);
  	variable items        : T_NATVEC(0 to 5)            := (others => 0);
	variable length       : natural                     := 0;
  	variable Pos          : natural                     := 0;
  	variable i            : natural                     := reg'low;
  	variable List         : std_logic_vector(reg'range) := (others => '0');
  	variable depth        : T_NATVEC(reg'range)         := (others => 0);

	begin
		write("/*****************************************************");
		write("* Automatically generated File from VHDL PoC Library *");
		write("* Poc.AXI4Lite.T_AXI4_Register_Description           *");
		write("* generated C-Header File                            *");
		write("* " & FileName & " *");
		write("*****************************************************/");
		ln;ln;

		for i in depth'range loop
			depth(i) := count_depth(reg(i).Name);
			assert false report"depth(" & integer'image(i) & ") = " & integer'image(depth(i)) severity warning;
		end loop;

--		items(Pos) := numberItems(Inst(Pos), Inst_length(Pos), i);
--		assert false report"Pos: " & integer'image(Pos) & ", items(Pos): " & integer'image( items(Pos) ) severity warning;

--		while subInstPos(Inst(Pos), Inst_length(Pos), i, items(Pos)) /= -1 loop
--			Pos := Pos +1;
--			items(Pos) := numberItems(Inst(Pos), Inst_length(Pos), i);
--			assert false report"Pos: " & integer'image(Pos) & ", items(Pos): " & integer'image( items(Pos) ) severity warning;
--		end loop;
--		items(Pos) := numberItems(Inst(Pos), Inst_length(Pos), i);
--		assert false report"subInstPos: " & integer'image( subInstPos(Inst(Pos), Inst_length(Pos), i, items(Pos)) ) severity warning;


--		while i <= reg'high loop

--		end loop;



--		for i in reg'range loop
--			Names(i) := reg(i).Name;
--			inner_loop: for j in 1 to Name_Width loop
--				Names(i) := str_replace(Names(i), "(", "_");
--				Names(i) := resize(str_replace(Names(i), ")", ""));
----				Names(i) := str_replace(Names(i), " ", "");
--				exit inner_loop when str_pos(Names(i), "(") = -1;
--			end loop;
----			assert false report "Names(" & integer'image(i) & ")='" & Names(i) & "'" severity warning;
--		end loop;
--		while Pos < reg'high loop
--			Inst_length := str_ipos(reg(Pos).Name(1 to Name_Width), '.');--nextInstPos(0, 0);
--			Instance    := resize(reg(Pos).Name(1 to Inst_length));--nextInstName(0, 0);
--			assert false report "Loopcount: " & integer'image(Pos) severity warning;
--			Pos := analyze(resize(" "), 0, 0);
--			length := numberItems(Instance, Inst_length, Pos);
--			assert false report "Pos: " & integer'image(Pos) severity warning;
--			Pos := Pos + length;
--		end loop;
--		length := str_ipos(Names(0), '.');
--		Instance := resize(Names(0)(1 to length -1));
--		printInstanceStruct("_" & Instance(1 to length -1));
----		assert false report "Length=" & integer'image(length) severity warning;
----		assert false report "Instance=" & Instance(1 to length -1) severity warning;
----		assert false report "Sub=" & Names(0)(length +1 to Name_Width) severity warning;
--		for i in reg'range loop
--			if Instance(1 to length -1) = Names(i)(1 to length -1) then
----				assert false report "Instance=" & Instance(1 to length -1) severity warning;
----				assert false report "Sub=" & Names(i)(length +1 to Name_Width) severity warning;
--				printInstanceItem(Names(i)(length +1 to Name_Width));
--			else
--				printInstanceStructE;
--				ln;
----				assert false report "New Instance" severity warning;
--				length := str_ipos(Names(i), '.');
--				Instance := resize(Names(i)(1 to length -1));
--				printInstanceStruct("_" & Instance(1 to length -1));
--				printInstanceItem(Names(i)(length +1 to Name_Width));
----				assert false report "Instance=" & Instance(1 to length -1) severity warning;
----				assert false report "Sub=" & Names(i)(length +1 to Name_Width) severity warning;
--			end if;
--		end loop;
--		printInstanceStructE;

--		ln;ln;

--		length := str_ipos(Names(0), '.');
--		Instance := resize(Names(0)(1 to length -1));
--		printInstanceStruct("");
--		printInstanceItem(Instance, "AXI4RegisterOffset_" & Instance);
--		for i in reg'range loop
--			if Instance(1 to length -1) /= Names(i)(1 to length -1) then
--				length := str_ipos(Names(i), '.');
--				Instance := resize(Names(i)(1 to length -1));
--				printInstanceItem(Instance, "AXI4RegisterOffset_" & Instance);
--			end if;
--		end loop;
--		printInstanceStructE;

--		ln;ln;
--		write("static const AXI4RegisterOffset " & Name & " = {");

--		length := str_ipos(Names(0), '.');
--		Instance := resize(Names(0)(1 to length -1));
--		printRegInstance(Instance);
----		printRegItem(Instance(length +1 to Name_Width),0);
--		for i in reg'range loop
--			if i = reg'high then
--				printRegItem(Names(i)(length +1 to Name_Width), i, last => true);
--				write("  }");
--			elsif Instance(1 to length -1) /= Names(i +1)(1 to length -1) then
--				printRegItem(Names(i)(length +1 to Name_Width), i, last => true);
--				write("  },");
--				length := str_ipos(Names(i +1), '.');
--				Instance := resize(Names(i +1)(1 to length -1));
--				printRegInstance(Instance);
--			else
--				printRegItem(Names(i)(length +1 to Name_Width), i);
--			end if;
--		end loop;
--		printInstanceStructE;

		return false;
	end function;

	impure function write_csv_file(FileName : string; reg : T_AXI4_Register_Description_Vector) return boolean is
		constant QM : character := '"';
		constant size_header    : natural := imax(FileName'length,51);
		file     FileHandle		  : TEXT open write_MODE is FileName;
  	variable CurrentLine	  : LINE;

  	procedure write(S : string) is
  	begin
  		write(CurrentLine, S);
  		writeline(FileHandle, CurrentLine);
  	end procedure;

	begin
		write("Automatically generated File from VHDL PoC Library");
		write("Poc.AXI4Lite.T_AXI4_Register_Description");
		write("generated CSV File");
		write(" ");
		write(" ");
		write(" ");
		write("Config(i) ; Name ; Address ; Init_Value ; Auto_Clear_Mask ; rw_config ; Is_Interrupt_Register");
		for i in 0 to reg'length -1 loop
			write( integer'image(i)                                                             & " ; " &
			       reg(i - reg'low).Name                                                        & " ; " &
			       "0x" & to_string(std_logic_vector(reg(i - reg'low).address), 'h', 4)         & " ; " &
			       "0x" & to_string(std_logic_vector(reg(i - reg'low).Init_Value), 'h', 4)      & " ; " &
			       "0x" & to_string(std_logic_vector(reg(i - reg'low).Auto_Clear_Mask), 'h', 4) & " ; " &
			       T_ReadWrite_Config'image(reg(i - reg'low).rw_config)                         & " ; " &
						 boolean'image(reg(i - reg'low).Is_Interrupt_Register)
			);
		end loop;
		write(" ");
		return true;
	end function;


	impure function read_csv_file(FileName : string) return T_AXI4_Register_Description_Vector is
		file     FileHandle		  : TEXT open read_MODE is FileName;
  		variable CurrentLine	  : LINE;
		variable Len              : natural;

		constant Init             : string(1 to 128) := (others => NUL);
		variable result_s         : string(1 to 128) := Init;

  		variable Pos  : natural := 0;
		variable temp : T_AXI4_Register_Description_Vector(0 to 511);

		variable elem : T_POSVEC(0 to 5);

		variable Name                  : string(1 to Name_Width);
		variable Address               : unsigned(Address_Width -1 downto 0);
		variable rw_config             : T_ReadWrite_Config := readWriteable;
		variable Init_Value            : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		variable Auto_Clear_Mask       : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		variable Is_Interrupt_Register : boolean := false;
	begin
		while true loop
			readline(FileHandle, CurrentLine);
			Len := CurrentLine'length;
			read(CurrentLine, result_s(1 to Len));
			if result_s(1) = '0' then
				exit;
			end if;
		end loop;
--		result_s(Len +1 to result_s'high) := (others => NUL);

		while true loop
			-------------------------------------------
			elem(0) := str_pos(result_s(1 to Len), ';');
			for i in 1 to elem'high loop
				elem(i) := str_pos(result_s(1 to Len), ';', elem(i -1) +1);
			end loop;

			Name            := resize(result_s(elem(0) +2 to elem(1) -2), Name_Width);
			Address         :=                  to_unsigned(to_natural_hex(result_s(elem(1) +4 to elem(2) -2)), Address'length);
			Init_Value      := std_logic_vector(to_unsigned(to_natural_hex(result_s(elem(2) +4 to elem(3) -2)), Init_Value'length));
			Auto_Clear_Mask := std_logic_vector(to_unsigned(to_natural_hex(result_s(elem(3) +4 to elem(4) -2)), Auto_Clear_Mask'length));
			for i in 0 to T_ReadWrite_Config'pos(T_ReadWrite_Config'high) loop
				if T_ReadWrite_Config'image(T_ReadWrite_Config'val(i)) = result_s(elem(4) +2 to elem(5) -2) then
					rw_config := T_ReadWrite_Config'val(i);
				end if;
			end loop;
			if result_s(elem(5) +2 to elem(5) +5) = "true" then
				Is_Interrupt_Register := true;
			else
				Is_Interrupt_Register := false;
			end if;

			temp(Pos) := to_AXI4_Register_Description(
				Name                  ,--: string := "";
				Address               ,--: unsigned(Address_Width -1 downto 0);
				rw_config             ,--: T_ReadWrite_Config := readWriteable;
				Init_Value            ,--: std_logic_vector(Data_Width -1 downto 0) := (others => '0');
				Auto_Clear_Mask       ,--: std_logic_vector(Data_Width -1 downto 0) := (others => '0');
				Is_Interrupt_Register --: boolean := false
			);
			------------------------------------------
			Pos := Pos +1;
			readline(FileHandle, CurrentLine);
			Len := CurrentLine'length;
			read(CurrentLine, result_s(1 to Len));
--			result_s(Len +1 to result_s'high) := (others => NUL);
			if result_s(1) = ' ' then
				exit;
			end if;
		end loop;
		return temp(0 to Pos -1);
	end function;


	impure function write_yml_file(FileName : string; reg : T_AXI4_Register_Description_Vector; reg_name : string; defines : key_value_pair_v := (0 to 0 => C_key_value_pair_empty); enums : key_value_pair_v := (0 to 0 => C_key_value_pair_empty)) return boolean is
		constant QM : character := '"';
		constant size_header    : natural := imax(FileName'length,51);
		file     FileHandle		  : TEXT open write_MODE is FileName;
  	variable CurrentLine	  : LINE;

  	procedure write(S : string) is
  	begin
  		write(CurrentLine, S);
  		writeline(FileHandle, CurrentLine);
  	end procedure;

	begin
		write("# Automatically generated File from VHDL PoC Library");
		write("# Poc.AXI4Lite.T_AXI4_Register_Description");
		write("# generated CSV File");
		write(" ");
		write(" ");
		write(" ");
		write("common:");
		write("  reg_name: " & reg_name);
		write(" ");

		if defines(0) /= C_key_value_pair_empty then
			write("defines:");
			for i in 0 to defines'length -1 loop
				write("  - name: "  & defines(i + defines'low).key);
				write("    value: " & defines(i + defines'low).value);
			end loop;
			write(" ");
		end if;

		if enums(0) /= C_key_value_pair_empty then
			write("enums:");
			for i in 0 to enums'length -1 loop
				write("  - name: "  & enums(i + enums'low).key);
				write("    value: " & enums(i + enums'low).value);
			end loop;
			write(" ");
		end if;

		write("register:");
--		write("Config(i) ; Name ; Address ; Init_Value ; Auto_Clear_Mask ; rw_config ; Is_Interrupt_Register");
		for i in 0 to reg'length -1 loop
			write( "  - Name: "                  & reg(i + reg'low).Name);
			write( "    Address: 0x"             & to_string(std_logic_vector(reg(i + reg'low).address), 'h', 4));
			write( "    Init_Value: 0x"          & to_string(std_logic_vector(reg(i + reg'low).Init_Value), 'h', 4));
			write( "    Auto_Clear_Mask: 0x"     & to_string(std_logic_vector(reg(i + reg'low).Auto_Clear_Mask), 'h', 4));
			write( "    rw_config: "             & T_ReadWrite_Config'image(reg(i + reg'low).rw_config));
			write( "    Is_Interrupt_Register: " & boolean'image(reg(i + reg'low).Is_Interrupt_Register));
		end loop;
		write(" ");
		return true;
	end function;


	function normalize(Config : T_AXI4_Register_Description_Vector) return T_AXI4_Register_Description_Vector is
		variable temp : T_AXI4_Register_Description_Vector(0 to Config'length -1);
	begin
		for i in 0 to Config'length -1 loop
			temp(i) := Config(i + Config'low);
		end loop;
		return temp;
	end function;

	function to_AXI4_Register_Description(  Name                  : string := "";
	                                        Address               : unsigned(Address_Width -1 downto 0);
	                                        writeable             : boolean;
	                                        Init_Value            : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
	                                        Auto_Clear_Mask       : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
	                                        Is_Interrupt_Register : boolean := false
	                                      ) return T_AXI4_Register_Description is
		variable temp : T_AXI4_Register_Description := (
			Name                  => resize(Name,Name_Width),
			Address               => Address,
			rw_config             => readWriteable,
			Init_Value            => Init_Value,
			Auto_Clear_Mask       => Auto_Clear_Mask,
			Is_Interrupt_Register => Is_Interrupt_Register
		);
	begin
		if not writeable then
			temp.rw_config := readable;
		end if;
		return temp;
	end function;

	function to_AXI4_Register_Description(	Name                  : string := "";
											Address               : unsigned(Address_Width -1 downto 0);
	                                        rw_config             : T_ReadWrite_Config := readWriteable;
	                                        Init_Value            : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
	                                        Auto_Clear_Mask       : std_logic_vector(Data_Width -1 downto 0) := (others => '0');
											Is_Interrupt_Register : boolean := false
	                                     ) return T_AXI4_Register_Description is
		variable temp : T_AXI4_Register_Description := (
			Name            => resize(Name,Name_Width),
			Address         => Address,
			rw_config       => rw_config,
			Init_Value      => Init_Value,
			Auto_Clear_Mask	=> Auto_Clear_Mask,
			Is_Interrupt_Register => Is_Interrupt_Register
		);
	begin
		return temp;
	end function;

	procedure assign(
		variable description_vector    : inout T_AXI4_Register_Description_Vector;
		variable idx                   : inout natural;
		variable addr                  : inout natural;
		constant offset                : in    natural := 4;
		constant Name                  : in    string := "";
		constant writeable             : in    boolean;
		constant Init_Value            : in    std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		constant Auto_Clear_Mask       : in    std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		constant Is_Interrupt_Register : in boolean := false
	) is
	begin
		description_vector(idx) := to_AXI4_Register_Description(
			Name => Name,
			Address => to_unsigned(addr, 32),
			writeable => writeable,
			Init_Value => Init_Value,
			Auto_Clear_Mask => Auto_Clear_Mask,
			Is_Interrupt_Register => Is_Interrupt_Register
		);
		idx  := idx +1;
		addr := addr + offset;
	end procedure;

	procedure assign(
		variable description_vector    : inout T_AXI4_Register_Description_Vector;
		variable idx                   : inout natural;
		variable addr                  : inout natural;
		constant offset                : in    natural := 4;
		constant Name                  : in    string := "";
		constant rw_config             : in    T_ReadWrite_Config;
		constant Init_Value            : in    std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		constant Auto_Clear_Mask       : in    std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		constant Is_Interrupt_Register : in boolean := false
	) is
	begin
		description_vector(idx) := to_AXI4_Register_Description(
			Name                  => Name,
			Address               => to_unsigned(addr, 32),
			rw_Config             => rw_config,
			Init_Value            => Init_Value,
			Auto_Clear_Mask       => Auto_Clear_Mask,
			Is_Interrupt_Register => Is_Interrupt_Register
		);
		idx  := idx +1;
		addr := addr + offset;
	end procedure;


	function filter_Register_Description_Vector(str : string; description_vector : T_AXI4_Register_Description_Vector) return T_AXI4_Register_Description_Vector is
		variable temp : description_vector'subtype;
		variable pos  : integer := 0;
	begin
		for i in description_vector'range loop
			if description_vector(i).name(str'range) /= str then
--			if not str_ifind(description_vector(i).name, str) then
				temp(pos) := description_vector(i);
				pos       := pos +1;
			end if;
		end loop;
		return temp(0 to pos -1);
	end function;

	function filter_Register_Description_Vector(char : character; description_vector : T_AXI4_Register_Description_Vector) return T_AXI4_Register_Description_Vector is
		variable temp : description_vector'subtype;
		variable pos  : integer := 0;
	begin
		for i in description_vector'range loop
			if description_vector(i).name(1) /= char then
--			if not str_ifind(description_vector(i).name, str) then
				temp(pos) := description_vector(i);
				pos       := pos +1;
			end if;
		end loop;
		return temp(0 to pos -1);
	end function;

	function add_Prefix(prefix : string; Config : T_AXI4_Register_Description_Vector; offset : unsigned(Address_Width -1 downto 0) := (others => '0')) return T_AXI4_Register_Description_Vector is
		variable temp : Config'subtype;
	begin
		for i in temp'range loop
			temp(i)         := Config(i);
			temp(i).Name    := resize(prefix & Config(i).Name, Name_Width);
			temp(i).Address := Config(i).Address + offset;
		end loop;
		return temp;
	end function;

	function get_addresses(description_vector : T_AXI4_Register_Description_Vector) return T_SLUV is
		variable temp : T_SLUV(description_vector'range)(Address_Width -1 downto 0);
	begin
		for i in temp'range loop
			temp(i) := description_vector(i).address;
		end loop;
		return temp;
	end function;

	function get_initValue(description_vector : T_AXI4_Register_Description_Vector) return T_SLVV is
		variable temp : T_SLVV(description_vector'range)(Data_Width -1 downto 0);
	begin
		for i in temp'range loop
			temp(i) := description_vector(i).init_value;
		end loop;
		return temp;
	end function;

	function get_AutoClearMask(description_vector : T_AXI4_Register_Description_Vector) return T_SLVV is
		variable temp : T_SLVV(description_vector'range)(Data_Width -1 downto 0);
	begin
		for i in temp'range loop
			temp(i) := description_vector(i).Auto_Clear_Mask;
		end loop;
		return temp;
	end function;

	function get_RegisterAddressBits(Config : T_AXI4_Register_Description_Vector) return positive is
		variable temp : positive := 1;
	begin
		for i in Config'range loop
			if to_integer(Config(i).address) > temp then
				temp := to_integer(Config(i).address);
			end if;
		end loop;
		return log2ceil(temp +1);
	end function;

	function get_strobeVector(Config : T_AXI4_Register_Description_Vector) return std_logic_vector is
		variable temp : std_logic_vector(Config'range);
	begin
		for i in Config'range loop
			if Config(i).rw_config = readWriteable then
				temp(i) := '0';
			else
				temp(i) := '1';
			end if;
		end loop;
		return temp;
	end function;

	function Filter_DescriptionVector(Config : T_AXI4_Register_Description_Vector; filter : std_logic_vector) return T_AXI4_Register_Description_Vector is
		variable temp : T_AXI4_Register_Description_Vector(0 to hamming_weight(filter) -1);
		variable pos  : natural := 0;
	begin
		assert Config'length = filter'length report "PoC.AXI4Lite.pkg: Filter_DescriptionVector: Config has not the same size as Filter!" severity failure;
		for i in temp'range loop
			if filter(i) = '1' then
				temp(pos) := Config(i);
				pos := pos +1;
			end if;
		end loop;
		return temp;
	end function;

	function get_index(Name : string; Register_Vector : T_AXI4_Register_Description_Vector) return integer is
	begin
		for i in Register_Vector'range loop
			if str_imatch(Register_Vector(i).Name, Name) then
				assert not DEBUG report "PoC.AXI4Lite.pkg.vhdl: get_index('" & Name & "' , Register_Vector) : found at " & integer'image(i) severity note;
				return i;
			end if;
		end loop;
		if DEBUG then
			assert false report "PoC.AXI4Lite.pkg.vhdl: get_index('" & Name & "' , Register_Vector) : no match found!" severity warning;
			return 0;
		else
			assert false report "PoC.AXI4Lite.pkg.vhdl: get_index('" & Name & "' , Register_Vector) : no match found!" severity failure;
		end if;
		return -1;
	end function;

	function get_NumberOfIndexes(Name : string; Register_Vector : T_AXI4_Register_Description_Vector) return integer is
		variable temp : integer := 0;
	begin
		for i in Register_Vector'range loop
			if str_ifind(Register_Vector(i).Name, Name) then
				temp := temp +1;
			end if;
		end loop;
		return temp;
	end function;

	function get_indexRange(Name : string; Register_Vector : T_AXI4_Register_Description_Vector) return T_INTVEC is
		variable temp : T_INTVEC(0 to get_NumberOfIndexes(Name, Register_Vector) -1) := (others => -1);
		variable pos  : integer := 0;
	begin
		for i in Register_Vector'range loop
			if str_ifind(Register_Vector(i).Name, Name) then
				temp(pos) := i;
				pos       := pos +1;
			end if;
		end loop;
		return temp;
	end function;

--	function get_index(Address : unsigned(Address_Width -1 downto 0); Register_Vector : T_AXI4_Register_Description_Vector) return integer is
--	begin
--		for i in Register_Vector'range loop
--			if Register_Vector(i).Address = Address then
--				return i;
--			end if;
--		end loop;
--		assert false report "PoC.AXI4Lite.pkg.vhdl: get_index(" & to_string(std_logic_vector(Address), 'h', 4) & " , Register_Vector) : no match found!" severity failure;
--		return -1;
--	end function;

	function get_Address(Name : string; Register_Vector : T_AXI4_Register_Description_Vector) return unsigned is
	begin
		for i in Register_Vector'range loop
			if str_imatch(Register_Vector(i).Name, Name) then
				assert not DEBUG report "PoC.AXI4Lite.pkg.vhdl: get_Address('" & Name & "' , Register_Vector) : found at " & integer'image(i) severity note;
				return Register_Vector(i).Address;
			end if;
		end loop;
		if DEBUG then
			assert false report "PoC.AXI4Lite.pkg.vhdl: get_Address('" & Name & "' , Register_Vector) : no match found!" severity warning;
		else
			assert false report "PoC.AXI4Lite.pkg.vhdl: get_Address('" & Name & "' , Register_Vector) : no match found!" severity failure;
		end if;
		return unsigned'(Address_Width -1 downto 0 => '1');
	end function;

	function get_Name(Address : unsigned(Address_Width -1 downto 0); Register_Vector : T_AXI4_Register_Description_Vector) return string is
	begin
		for i in Register_Vector'range loop
			if Register_Vector(i).Address = Address then
				assert not DEBUG report "PoC.AXI4Lite.pkg.vhdl: get_Name(" & to_string(std_logic_vector(Address), 'h', 4) & " , Register_Vector) : found match at " & integer'image(i) severity note;
				return Register_Vector(i).Name;
			end if;
		end loop;
		if DEBUG then
			assert false report "PoC.AXI4Lite.pkg.vhdl: get_Name(" & to_string(std_logic_vector(Address), 'h', 4) & " , Register_Vector) : no match found!" severity warning;
		else
			assert false report "PoC.AXI4Lite.pkg.vhdl: get_Name(" & to_string(std_logic_vector(Address), 'h', 4) & " , Register_Vector) : no match found!" severity failure;
		end if;
		return resize("",Name_Width);
	end function;


	function get_Interrupt_count(Register_Vector : T_AXI4_Register_Description_Vector) return natural is
		variable temp : natural := 0;
	begin
		for i in Register_Vector'range loop
			if Register_Vector(i).Is_Interrupt_Register then
				temp := temp +1;
			end if;
		end loop;
		return temp;
	end function;

	function get_Interrupt_range(Register_Vector : T_AXI4_Register_Description_Vector) return T_NATVEC is
		variable temp  : T_NATVEC(0 to get_Interrupt_count(Register_Vector) -1) := (others => 0);
		variable count : natural := 0;
	begin
		for i in Register_Vector'range loop
			if Register_Vector(i).Is_Interrupt_Register then
				temp(count) := i;
				count       := count +1;
			end if;
		end loop;

		return temp;
	end function;

	procedure Make_AtomicRegister(
--		signal   Clock                     : in  std_logic;
		constant Reset                     : in  std_logic;
		constant RegisterFile_ReadPort     : in  T_SLVV(Atomic_RegisterDescription_Vector'range)(Data_Width -1 downto 0);
		signal   RegisterFile_WritePort    : out T_SLVV(Atomic_RegisterDescription_Vector'range)(Data_Width -1 downto 0);
		constant RegisterFile_ReadPort_hit : in  std_logic_vector(Atomic_RegisterDescription_Vector'range);
		constant PL_WriteValue             : in  std_logic_vector(Data_Width -1 downto 0) := (others => '0');
		constant PL_WriteStrobe            : in  std_logic := '0';
		constant Value_reg                 : in  std_logic_vector(Data_Width -1 downto 0);
		signal   nextValue_reg             : out std_logic_vector(Data_Width -1 downto 0)
	) is
		constant Value_idx               : natural := 0;
		constant BitSet_idx              : natural := 1;
		constant BitClr_idx              : natural := 2;
		constant BitTgl_idx              : natural := 3;

		variable newValue                : std_logic_vector(Data_Width -1 downto 0);
	begin
		RegisterFile_WritePort(Value_idx)  <= Value_reg;
		RegisterFile_WritePort(BitSet_idx) <= PL_WriteValue;
		RegisterFile_WritePort(BitClr_idx) <= (others => '0');
		RegisterFile_WritePort(BitTgl_idx) <= (others => '0');

		newValue   := PL_WriteValue when PL_WriteStrobe = '1' else Value_reg;
		if Reset = '1' then
			newValue := (others => '0');
		elsif RegisterFile_ReadPort_hit(Value_idx) = '1' then
			newValue := RegisterFile_ReadPort(Value_idx);
		elsif RegisterFile_ReadPort_hit(BitSet_idx) = '1' then
			newValue := newValue or RegisterFile_ReadPort(BitSet_idx);
		elsif RegisterFile_ReadPort_hit(BitClr_idx) = '1' then
			newValue := newValue and not RegisterFile_ReadPort(BitClr_idx);
		elsif RegisterFile_ReadPort_hit(BitTgl_idx) = '1' then
			newValue := newValue xor RegisterFile_ReadPort(BitTgl_idx);
		end if;
		nextValue_reg                    <= newValue;
	end procedure;

	procedure Make_IORegister(
--		signal Clock                     : in  std_logic;
		constant Reset                     : in  std_logic;
		constant RegisterFile_ReadPort     : in  T_SLVV(IO_RegisterDescription_Vector'range)(Data_Width -1 downto 0);
		signal   RegisterFile_WritePort    : out T_SLVV(IO_RegisterDescription_Vector'range)(Data_Width -1 downto 0);
		constant RegisterFile_ReadPort_hit : in  std_logic_vector(IO_RegisterDescription_Vector'range);
		constant Input                     : in  std_logic_vector(Data_Width -1 downto 0);
		signal   Output                    : out std_logic_vector(Data_Width -1 downto 0);
		signal   Tristate                  : out std_logic_vector(Data_Width -1 downto 0);
		constant IO_reg                    : in  std_logic_vector(Data_Width -1 downto 0);
		signal   nextIO_reg                : out std_logic_vector(Data_Width -1 downto 0);
		constant T_reg                     : in  std_logic_vector(Data_Width -1 downto 0);
		signal   nextT_reg                 : out std_logic_vector(Data_Width -1 downto 0)
	) is
		constant Value_idx               : natural := 0;
		constant BitSet_idx              : natural := 1;
		constant BitClr_idx              : natural := 2;
		constant BitTgl_idx              : natural := 3;

		variable newValue                : std_logic_vector(Data_Width -1 downto 0);
	begin
		--IO Register
		Output <= IO_reg;
		Make_AtomicRegister(
			Reset => Reset, RegisterFile_ReadPort => RegisterFile_ReadPort(0 to 3),
			RegisterFile_WritePort => RegisterFile_WritePort(0 to 3), RegisterFile_ReadPort_hit => RegisterFile_ReadPort_hit(0 to 3),
			PL_WriteValue => Input, Value_reg => IO_reg, nextValue_reg => nextIO_reg
		);

		--T Reg
		Tristate <= T_reg;
		Make_AtomicRegister(
			Reset => Reset, RegisterFile_ReadPort => RegisterFile_ReadPort(4 to 7),
			RegisterFile_WritePort => RegisterFile_WritePort(4 to 7), RegisterFile_ReadPort_hit => RegisterFile_ReadPort_hit(4 to 7),
			Value_reg => T_reg, nextValue_reg => nextT_reg
		);
	end procedure;

--		type T_ReadWrite_Config is (
--		readWriteable, readable,
--		latchValue_clearOnRead, latchValue_clearOnWrite,
--		latchHighBit_clearOnRead, latchHighBit_clearOnWrite,
--		latchLowBit_clearOnRead, latchLowBit_clearOnWrite
--	);
--  function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector) return T_AXI4_Register_Set is
--    variable temp : T_AXI4_Register_Set(AXI4_Register(reg_vec'length -1 downto 0), Last_Index(log2ceilnz(reg_vec'length) -1 downto 0)) := (
--      AXI4_Register => reg_vec,
--      Last_Index    => to_unsigned(reg_vec'length, log2ceilnz(reg_vec'length))
--    );
--  begin
--    return temp;
--  end function;

--  -----------Wirte Address
--  function Initialize_AXI4Lite_WriteAddress_Bus(AddressBits : natural) return T_AXI4Lite_WriteAddress_Bus is
--  begin
--    return (
--      AWValid => 'Z',
--      AWReady => 'Z',
--      AWCache => C_AXI4_CACHE_INIT,
--      AWAddr  => (AddressBits-1 downto 0 => 'Z'),
--      AWProt  => C_AXI4_PROTECT_INIT
--    );
--  end function;

--  -----------Write Data
--  function Initialize_AXI4Lite_WriteData_Bus(DataBits : natural) return T_AXI4Lite_WriteData_Bus is
--  begin
--    return (
--      WValid  => 'Z',
--      WReady  => 'Z',
--      WData   => (DataBits - 1 downto 0 => 'Z'),
--      WStrb   => ((DataBits / 8) - 1 downto 0 => 'Z')
--    );
--  end function;

--  -----------Write Response
--  function Initialize_AXI4Lite_WriteResponse_Bus return T_AXI4Lite_WriteResponse_Bus is
--  begin
--    return (
--      BValid  => 'Z',
--      BReady  => 'Z',
--      BResp   => C_AXI4_RESPONSE_INIT
--    );
--  end function;

--  -------------Read Address
--  function Initialize_AXI4Lite_ReadAddress_Bus(AddressBits : natural) return T_AXI4Lite_ReadAddress_Bus is
--  begin
--    return (
--      ARValid => 'Z',
--      ARReady => 'Z',
--      ARCache => C_AXI4_CACHE_INIT,
--      ARAddr  => (AddressBits - 1 downto 0 => 'Z'),
--      ARProt  => C_AXI4_PROTECT_INIT
--    );
--  end function;

--  -----------------Read Data
--  function Initialize_AXI4Lite_ReadData_Bus(DataBits : natural) return T_AXI4Lite_ReadData_Bus is
--  begin
--    return (
--      RValid  => 'Z',
--      RReady  => 'Z',
--      RData   => (DataBits - 1 downto 0 => 'Z'),
--      RResp   => C_AXI4_RESPONSE_INIT
--    );
--  end function;

	--------------INIT
	constant Atomic_RegisterDescription_Vector : T_AXI4_Register_Description_Vector(0 to 3) := (
			0 => to_AXI4_Register_Description("ATOMIC_Value",  to_unsigned(0, 32),  readWriteable_non_reg),
			1 => to_AXI4_Register_Description("ATOMIC_BitTgl", to_unsigned(4, 32),  readWriteable_non_reg),
			2 => to_AXI4_Register_Description("ATOMIC_BitSet", to_unsigned(8, 32),  readWriteable_non_reg),
			3 => to_AXI4_Register_Description("ATOMIC_BitClr", to_unsigned(12, 32), readWriteable_non_reg)
		);

	constant IO_RegisterDescription_Vector : T_AXI4_Register_Description_Vector(0 to 7) := (
			add_Prefix("IO.", Atomic_RegisterDescription_Vector, to_unsigned(0, Address_Width)) &
			add_Prefix("T.", Atomic_RegisterDescription_Vector, to_unsigned(Atomic_RegisterDescription_Vector'length *4, Address_Width))
	);

 end package body;

 use work.AXI4Lite.all;


package AXI4Lite_Sized is
	generic (
		ADDRESS_BITS  : positive;
		DATA_BITS     : positive
	);

	subtype SIZED_M2S is T_AXI4LITE_BUS_M2S(
		AWAddr(ADDRESS_BITS - 1 downto 0),
		WData(DATA_BITS - 1 downto 0),
		WStrb(DATA_BITS / 8 - 1 downto 0),
		ARAddr(ADDRESS_BITS - 1 downto 0)
	);
	subtype SIZED_S2M is T_AXI4LITE_BUS_S2M(
		RData(DATA_BITS - 1 downto 0)
	);

	subtype SIZED_M2S_VECTOR is T_AXI4LITE_BUS_M2S_VECTOR(open)(
		AWAddr(ADDRESS_BITS - 1 downto 0),
		WData(DATA_BITS - 1 downto 0),
		WStrb(DATA_BITS / 8 - 1 downto 0),
		ARAddr(ADDRESS_BITS - 1 downto 0)
	);
	subtype SIZED_S2M_VECTOR is T_AXI4LITE_BUS_S2M_VECTOR(open)(
		RData(DATA_BITS - 1 downto 0)
	);
end package;
