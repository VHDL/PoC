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

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.AXI4_Common.all;


  -- Generic
--    axi_addr_width   : natural := 32;
--    axi_data_width   : natural := 32;
--    axi_id_width     : natural := 2;
--    axi_user_width   : natural := 4


package AXI4Lite is
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

	type T_AXI4Lite_Bus_S2M is record
		WReady      : std_logic;
		BValid      : std_logic;
		BResp       : T_AXI4_Response; 
		ARReady     : std_logic;
		AWReady     : std_logic;
		RValid      : std_logic;
		RData       : std_logic_vector;
		RResp       : T_AXI4_Response;
	end record;
  type T_AXI4Lite_Bus_S2M_VECTOR is array(natural range <>) of T_AXI4Lite_Bus_S2M;

	type T_AXI4Lite_Bus_M2S is record
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
  type T_AXI4Lite_Bus_M2S_VECTOR is array(natural range <>) of T_AXI4Lite_Bus_M2S;	
	
  type T_AXI4Lite_Bus is record
--    AClk        : std_logic;
--    AResetN     : std_logic;
    M2S   : T_AXI4Lite_Bus_M2S;
    S2M   : T_AXI4Lite_Bus_S2M;
  end record;
  type T_AXI4Lite_Bus_VECTOR is array(natural range <>) of T_AXI4Lite_Bus;
	
	function Initialize_AXI4Lite_Bus_S2M(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4Lite_Bus_S2M;
	function Initialize_AXI4Lite_Bus_M2S(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4Lite_Bus_M2S;
	function Initialize_AXI4Lite_Bus(    AddressBits : natural; DataBits : natural) return T_AXI4Lite_Bus;


  -------Define AXI Register structure-------------
  constant Address_Width  : natural := 32;
  constant Data_Width  : natural := 32;
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
  function to_AXI4_Register(Address : unsigned(Address_Width -1 downto 0); Data : std_logic_vector(Data_Width -1 downto 0); Mask : std_logic_vector(Data_Width -1 downto 0)) return T_AXI4_Register;
--  function Initialize_AXI4_register(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4_Register;
  function Initialize_AXI4_register(Value : std_logic := 'Z') return T_AXI4_Register;
  
  type T_AXI4_Register_Vector is array (natural range <>) of T_AXI4_Register;
  
  type T_AXI4_Register_Set is record
    AXI4_Register  : T_AXI4_Register_Vector;
    Last_Index     : natural;
  end record;
  
  type T_AXI4_Register_Set_VECTOR is array (natural range <>) of T_AXI4_Register_Set;
  
  function to_AXI4_Register_Set(reg_vec : T_AXI4_Register_Vector; size : natural) return T_AXI4_Register_Set;
  

  type T_AXI4_Register_Description is record
		Address             : unsigned(Address_Width-1 downto 0);
		Writeable           : boolean;
		Init_Value          : std_logic_vector(Data_Width-1 downto 0);
		Auto_Clear_Mask     : std_logic_vector(Data_Width-1 downto 0);
  end record;
  
  type T_AXI4_Register_Description_Vector is array (natural range <>) of T_AXI4_Register_Description;
  
  function to_AXI4_Register_Description(	Address : unsigned(Address_Width -1 downto 0); 
  																				Writeable : boolean := true; 
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

  function to_AXI4_Register(Address : unsigned(Address_Width -1 downto 0); Data : std_logic_vector(Data_Width -1 downto 0); Mask : std_logic_vector(Data_Width -1 downto 0)) return T_AXI4_Register is
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
  
	function to_AXI4_Register_Description(	Address : unsigned(Address_Width -1 downto 0); 
  																				Writeable : boolean := true; 
  																				Init_Value : std_logic_vector(Data_Width -1 downto 0) := (others => '0'); 
  																				Auto_Clear_Mask : std_logic_vector(Data_Width -1 downto 0) := (others => '0')
																				) return T_AXI4_Register_Description is
																				
		variable temp : T_AXI4_Register_Description := (
			Address         => Address,
			Writeable       => Writeable,
			Init_Value      => Init_Value,
			Auto_Clear_Mask	=> Auto_Clear_Mask
		);
	begin
		return temp;
	end function;
  
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
