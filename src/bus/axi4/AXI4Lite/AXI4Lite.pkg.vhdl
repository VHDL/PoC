-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:				 	Generic AMBA AXI4-Lite bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4-Lite description.
--
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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
use			STD.TextIO.all;

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.strings.all;
use     work.vectors.all;
use     work.AXI4_Common.all;


	-- Generic
--    axi_addr_width   : natural := 32;
--    axi_data_width   : natural := 32;
--    axi_id_width     : natural := 2;
--    axi_user_width   : natural := 4


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
	
	function AddressTranslate(InBus : T_AXI4LITE_BUS_M2S; Offset : signed) return T_AXI4LITE_BUS_M2S;

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
--    AClk        : std_logic;
--    AResetN     : std_logic;
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
--  type T_AXI4_Register is record
--    Address : unsigned;
--    Data    : std_logic_vector;
--    Mask    : std_logic_vector;
--  end record;
	type T_AXI4_Register is record
		Address : unsigned(Address_Width -1 downto 0);
		Data    : std_logic_vector(Data_Width -1 downto 0);
		Mask    : std_logic_vector(Data_Width -1 downto 0);
	end record;
	
--  function to_AXI4_Register(Address : unsigned; Data : std_logic_vector; Mask : std_logic_vector; AddressBits : natural; DataBits : natural) return T_AXI4_Register;
	function to_AXI4_Register(Name : string := ""; Address : unsigned(Address_Width -1 downto 0); Data : std_logic_vector(Data_Width -1 downto 0); Mask : std_logic_vector(Data_Width -1 downto 0)) return T_AXI4_Register;
--  function Initialize_AXI4_register(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4_Register;
	function Initialize_AXI4_register(Value : std_logic := 'Z') return T_AXI4_Register;
	
	type T_AXI4_Register_Vector is array (natural range <>) of T_AXI4_Register;
	
	type T_AXI4_Register_Set is record
		AXI4_Register  : T_AXI4_Register_Vector;
		Last_Index     : natural;
	end record;
	
	type T_AXI4_Register_Set_VECTOR is array (natural range <>) of T_AXI4_Register_Set;
	
	function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector; size : natural) return T_AXI4_Register_Set;
	
	type T_ReadWrite_Config is (
		readWriteable, readable, 
		latchValue_clearOnRead, latchValue_clearOnWrite, 
		latchHighBit_clearOnRead, latchHighBit_clearOnWrite, 
		latchLowBit_clearOnRead, latchLowBit_clearOnWrite
	);
	attribute Count of T_ReadWrite_Config : type is T_ReadWrite_Config'pos(T_ReadWrite_Config'high) + 1;

	type T_AXI4_Register_Description is record
		Name                : string(1 to Name_Width);
		Address             : unsigned(Address_Width-1 downto 0);
		rw_config           : T_ReadWrite_Config;
		Init_Value          : std_logic_vector(Data_Width-1 downto 0);
		Auto_Clear_Mask     : std_logic_vector(Data_Width-1 downto 0);
	end record;
	
	function to_string(reg : T_AXI4_Register_Description) return string;
--	function to_c_header_string(reg : T_AXI4_Register_Description) return string;
	
	type T_AXI4_Register_Description_Vector is array (natural range <>) of T_AXI4_Register_Description;
	
	
	function get_addresses(description_vector : T_AXI4_Register_Description_Vector) return T_SLUV;
	function get_InitValue(description_vector : T_AXI4_Register_Description_Vector) return T_SLVV;
	function get_AutoClearMask(description_vector : T_AXI4_Register_Description_Vector) return T_SLVV;
	
	impure function write_c_header_file(FileName : string; Name : string; reg : T_AXI4_Register_Description_Vector) return boolean;
	impure function write_csv_file(FileName : string; reg : T_AXI4_Register_Description_Vector) return boolean;
	
	function get_index(Name : string; Register_Vector : T_AXI4_Register_Description_Vector) return integer;
	function get_NumberOfIndexes(Name : string; Register_Vector : T_AXI4_Register_Description_Vector) return integer;
	function get_indexRange(Name : string; Register_Vector : T_AXI4_Register_Description_Vector) return T_INTVEC;
	function get_Address(Name : string; Register_Vector : T_AXI4_Register_Description_Vector) return unsigned;
	function get_Name(Address : unsigned(Address_Width -1 downto 0); Register_Vector : T_AXI4_Register_Description_Vector) return string;
--	function get_index(Address : unsigned(Address_Width -1 downto 0); Register_Vector : T_AXI4_Register_Description_Vector) return integer;
	
	function get_RegisterAddressBits(Config : T_AXI4_Register_Description_Vector) return positive; 
	
	function get_strobeVector(Config : T_AXI4_Register_Description_Vector) return std_logic_vector; 

	function to_AXI4_Register_Description(  Name : string := "";
																					Address : unsigned(Address_Width -1 downto 0); 
	                                        writeable : boolean; 
	                                        Init_Value : std_logic_vector(Data_Width -1 downto 0) := (others => '0'); 
	                                        Auto_Clear_Mask : std_logic_vector(Data_Width -1 downto 0) := (others => '0')
	                                    ) return T_AXI4_Register_Description;
	
	
	function to_AXI4_Register_Description(	Name : string := "";
																					Address : unsigned(Address_Width -1 downto 0); 
	                                        rw_config : T_ReadWrite_Config := readWriteable; 
	                                        Init_Value : std_logic_vector(Data_Width -1 downto 0) := (others => '0'); 
	                                        Auto_Clear_Mask : std_logic_vector(Data_Width -1 downto 0) := (others => '0')
	                                    ) return T_AXI4_Register_Description;
	
	
	-- ------- Write Address Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_WriteAddress_Bus is record
		 AWValid     : std_logic; 
		 AWReady     : std_logic;
		 AWAddr      : std_logic_vector; 
		 AWCache     : T_AXI4_Cache;
		 AWProt      : T_AXI4_Protect;
	 end record; 	

	-- function Initialize_AXI4Lite_WriteAddress_Bus(AddressBits : natural) return T_AXI4Lite_WriteAddress_Bus;

	-- ------- Write Data Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_WriteData_Bus is record
		 WValid      : std_logic;
		 WReady      : std_logic;
		 WData       : std_logic_vector;
		 WStrb       : std_logic_vector;
	 end record;

	-- function Initialize_AXI4Lite_WriteData_Bus(DataBits : natural) return T_AXI4Lite_WriteData_Bus;

	-- -------- Write Response Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_WriteResponse_Bus is record
		 BValid      : std_logic;
		 BReady      : std_logic;
		 BResp       : T_AXI4_Response; 
	 end record; 

	-- function Initialize_AXI4Lite_WriteResponse_Bus return T_AXI4Lite_WriteResponse_Bus;

	-- ------ Read Address Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_ReadAddress_Bus is record
		 ARValid     : std_logic;
		 ARReady     : std_logic;
		 ARAddr      : std_logic_vector;
		 ARCache     : T_AXI4_Cache;
		 ARProt      : T_AXI4_Protect;
	 end record;

	-- function Initialize_AXI4Lite_ReadAddress_Bus(AddressBits : natural) return T_AXI4Lite_ReadAddress_Bus;

	-- ------- Read Data Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_ReadData_Bus is record
		 RValid      : std_logic;
		 RReady      : std_logic;
		 RData       : std_logic_vector;
		 RResp       : T_AXI4_Response;
	 end record;
	
	-- function Initialize_AXI4Lite_ReadData_Bus(DataBits : natural ) return T_AXI4Lite_ReadData_Bus;
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
		return " Name: " & resize(reg.Name,Name_Width)
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
		write("Config(i) ; Name ; Address ; Init_Value ; Auto_Clear_Mask");
		for i in 0 to reg'length -1 loop
			write( integer'image(i)                                                             & " ; " & 
			       reg(i - reg'low).Name                                                        & " ; " & 
			       "0x" & to_string(std_logic_vector(reg(i - reg'low).address), 'h', 4)         & " ; " &
			       "0x" & to_string(std_logic_vector(reg(i - reg'low).Init_Value), 'h', 4)      & " ; " &
			       "0x" & to_string(std_logic_vector(reg(i - reg'low).Auto_Clear_Mask), 'h', 4)
			);
		end loop;
		write(" ");
		return true;
	end function;	
	
	function to_AXI4_Register_Description(  Name : string := "";
																					Address : unsigned(Address_Width -1 downto 0); 
	                                        writeable : boolean; 
	                                        Init_Value : std_logic_vector(Data_Width -1 downto 0) := (others => '0'); 
	                                        Auto_Clear_Mask : std_logic_vector(Data_Width -1 downto 0) := (others => '0')
	                                    ) return T_AXI4_Register_Description is
		variable temp : T_AXI4_Register_Description := (
			Name             => resize(Name,Name_Width),
			Address          => Address,
			rw_config        => readWriteable,
			Init_Value       => Init_Value,
			Auto_Clear_Mask  => Auto_Clear_Mask
		);
	begin
		if not writeable then
			temp.rw_config := readable;
		end if; 
		return temp;
	end function;
	
	function to_AXI4_Register_Description(	Name : string := "";
																					Address : unsigned(Address_Width -1 downto 0); 
	                                        rw_config : T_ReadWrite_Config := readWriteable; 
	                                        Init_Value : std_logic_vector(Data_Width -1 downto 0) := (others => '0'); 
	                                        Auto_Clear_Mask : std_logic_vector(Data_Width -1 downto 0) := (others => '0')
	                                     ) return T_AXI4_Register_Description is
		variable temp : T_AXI4_Register_Description := (
			Name            => resize(Name,Name_Width),
			Address         => Address,
			rw_config       => rw_config,
			Init_Value      => Init_Value,
			Auto_Clear_Mask	=> Auto_Clear_Mask
		);
	begin
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
			if log2ceil(to_integer(Config(i).address) +1) > temp then
				temp := log2ceil(to_integer(Config(i).address) +1);
			end if;
		end loop;
		return temp;
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
 end package body;
