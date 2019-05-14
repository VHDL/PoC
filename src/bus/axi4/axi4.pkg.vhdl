-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann; Stefan Unrein
--
-- Entity:				 	Generic AMBA AXI4 bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4 description for:
--
-- * AXI4 Lite
-- * AXI4 Full
--
-- License:
-- =============================================================================
-- Copyright 2017-2018 Patrick Lehmann - Bötzingen, Germany
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

library PoC;
use PoC.utils.all;

  
  -- Generic
--    axi_addr_width   : natural := 32;
--    axi_data_width   : natural := 32;
--    axi_id_width     : natural := 2;
--    axi_user_width   : natural := 4


package AXI4 is
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
  
  ----^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  
  
  
  subtype  T_AXI4_Response is std_logic_vector(1 downto 0);
	constant C_AXI4_RESPONSE_OKAY         : T_AXI4_Response := "00";
	constant C_AXI4_RESPONSE_EX_OKAY      : T_AXI4_Response := "01";
	constant C_AXI4_RESPONSE_SLAVE_ERROR  : T_AXI4_Response := "10";
	constant C_AXI4_RESPONSE_DECODE_ERROR : T_AXI4_Response := "11";
	constant C_AXI4_RESPONSE_INIT         : T_AXI4_Response := "ZZ";
  
  subtype  T_AXI4_Cache    is std_logic_vector(3 downto 0);
  constant C_AXI4_CACHE_INIT : T_AXI4_Cache := "ZZZZ";  
  constant C_AXI4_CACHE      : T_AXI4_Cache := "0011";  
  
  subtype  T_AXI4_QoS    is std_logic_vector(3 downto 0);
  constant C_AXI4_QOS_INIT : T_AXI4_QoS := "ZZZZ";  
  
  subtype  T_AXI4_Region    is std_logic_vector(3 downto 0);
  constant C_AXI4_REGION_INIT : T_AXI4_Region := "ZZZZ";
  
  subtype  T_AXI4_Size   is std_logic_vector(2 downto 0);
  constant C_AXI4_SIZE_1        : T_AXI4_Size := "000";
  constant C_AXI4_SIZE_2        : T_AXI4_Size := "001";
  constant C_AXI4_SIZE_4        : T_AXI4_Size := "010";
  constant C_AXI4_SIZE_8        : T_AXI4_Size := "011";
  constant C_AXI4_SIZE_16       : T_AXI4_Size := "100";
  constant C_AXI4_SIZE_32       : T_AXI4_Size := "101";
  constant C_AXI4_SIZE_64       : T_AXI4_Size := "110";
  constant C_AXI4_SIZE_128      : T_AXI4_Size := "111";
  constant C_AXI4_SIZE_INIT     : T_AXI4_Size := "ZZZ";
  
  subtype  T_AXI4_Burst  is std_logic_vector(1 downto 0);
  constant C_AXI4_BURST_FIXED   : T_AXI4_Burst := "00";
  constant C_AXI4_BURST_INCR    : T_AXI4_Burst := "01";
  constant C_AXI4_BURST_WRAP    : T_AXI4_Burst := "10";
  constant C_AXI4_BURST_INIT    : T_AXI4_Burst := "ZZ";

  subtype T_AXI4_Protect is std_logic_vector(2 downto 0);
  -- Bit 0: 0 Unprivileged access   1 Privileged access
  -- Bit 1: 0 Secure access         1 Non-secure access
  -- Bit 2: 0 Data access           1 Instruction access
  constant C_AXI4_PROTECT_INIT : T_AXI4_Protect := "ZZZ"; 
  constant C_AXI4_PROTECT      : T_AXI4_Protect := "000"; 

  -- ------- Write Address Channel
	-- -- AXI4-Lite 
   type T_AXI4Lite_WriteAddress_Bus is record
		 AWValid     : std_logic; 
		 AWReady     : std_logic;
		 AWAddr      : std_logic_vector; 
     AWCache     : T_AXI4_Cache;
		 AWProt      : T_AXI4_Protect;
	 end record; 	
  -- -- AXI4
  -- type T_AXI4_WriteAddress_Bus is record
    -- AWID        : unsigned; 
		-- AWAddr      : unsigned; 
    -- AWLen       : unsigned(7 downto 0); 
    -- AWSize      : T_AXI4_Size; 
    -- AWBurst     : T_AXI4_Burst; 
    -- AWLock      : std_logic; 
    -- AWQOS       : T_AXI4_QoS;
    -- AWRegion    : T_AXI4_Region;
    -- AWUser      : std_logic_vector;
		-- AWValid     : std_logic; 
		-- AWReady     : std_logic;
    -- AWCache     : T_AXI4_Cache;
		-- AWProt      : T_AXI4_Protect;
	-- end record; 

	-- function Initialize_AXI4Lite_WriteAddress_Bus(AddressBits : natural) return T_AXI4Lite_WriteAddress_Bus;
	-- function Initialize_AXI4_WriteAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteAddress_Bus;

  -- ------- Write Data Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_WriteData_Bus is record
		 WValid      : std_logic;
		 WReady      : std_logic;
		 WData       : std_logic_vector;
		 WStrb       : std_logic_vector;
	 end record;
	-- -- AXI4
	-- type T_AXI4_WriteData_Bus is record
		-- WValid      : std_logic;
		-- WReady      : std_logic;
    -- WLast       : std_logic;
    -- WUser       : std_logic_vector;
		-- WData       : std_logic_vector;
		-- WStrb       : std_logic_vector;
	-- end record;

	-- function Initialize_AXI4Lite_WriteData_Bus(DataBits : natural) return T_AXI4Lite_WriteData_Bus;
	-- function Initialize_AXI4_WriteData_Bus(DataBits : natural; UserBits : natural := 0) return T_AXI4_WriteData_Bus;

  -- -------- Write Response Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_WriteResponse_Bus is record
		 BValid      : std_logic;
		 BReady      : std_logic;
		 BResp       : T_AXI4_Response; 
	 end record; 
	-- -- AXI4
	-- type T_AXI4_WriteResponse_Bus is record
		-- BValid      : std_logic;
		-- BReady      : std_logic;
		-- BResp       : T_AXI4_Response; 
    -- BID         : unsigned; 
    -- BUser       : std_logic_vector;
	-- end record; 

	-- function Initialize_AXI4Lite_WriteResponse_Bus return T_AXI4Lite_WriteResponse_Bus;
	-- function Initialize_AXI4_WriteResponse_Bus(UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteResponse_Bus;

  -- ------ Read Address Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_ReadAddress_Bus is record
		 ARValid     : std_logic;
		 ARReady     : std_logic;
		 ARAddr      : std_logic_vector;
     ARCache     : T_AXI4_Cache;
		 ARProt      : T_AXI4_Protect;
	 end record;
	-- -- AXI4
	-- type T_AXI4_ReadAddress_Bus is record
		-- ARValid     : std_logic;
		-- ARReady     : std_logic;
		-- ARAddr      : unsigned;
    -- ARCache     : T_AXI4_Cache;
		-- ARProt      : T_AXI4_Protect;
    -- ARID        : unsigned;
    -- ARLen       : unsigned(7 downto 0);
    -- ARSize      : T_AXI4_Size;
    -- ARBurst     : T_AXI4_Burst;
    -- ARLock      : std_logic;
    -- ARQOS       : T_AXI4_QoS;
    -- ARRegion    : T_AXI4_Region;
    -- ARUser      : std_logic_vector;
	-- end record;

	-- function Initialize_AXI4Lite_ReadAddress_Bus(AddressBits : natural) return T_AXI4Lite_ReadAddress_Bus;
	-- function Initialize_AXI4_ReadAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadAddress_Bus;

  -- ------- Read Data Channel
	-- -- AXI4-Lite 
	 type T_AXI4Lite_ReadData_Bus is record
		 RValid      : std_logic;
		 RReady      : std_logic;
		 RData       : std_logic_vector;
		 RResp       : T_AXI4_Response;
	 end record;
	-- -- AXI4
	-- type T_AXI4_ReadData_Bus is record
		-- RValid      : std_logic;
		-- RReady      : std_logic;
		-- RData       : std_logic_vector;
		-- RResp       : T_AXI4_Response;
    -- RID         : unsigned;
    -- RLast       : std_logic;
    -- RUser       : std_logic_vector;
	-- end record;
  
	-- function Initialize_AXI4Lite_ReadData_Bus(DataBits : natural ) return T_AXI4Lite_ReadData_Bus;
	-- function Initialize_AXI4_ReadData_Bus(DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadData_Bus;


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
	type T_AXI4Lite_Bus_M2S is record
--    AClk        : std_logic;
--    AResetN     : std_logic;
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
  type T_AXI4Lite_Bus is record
    M2S   : T_AXI4Lite_Bus_M2S;
    S2M   : T_AXI4Lite_Bus_S2M;
  end record;

	type T_AXI4_Bus_S2M is record
		AWReady     : std_logic;
		WReady      : std_logic;
		BValid      : std_logic;
		BResp       : T_AXI4_Response; 
    BID         : std_logic_vector; 
    BUser       : std_logic_vector;
		ARReady     : std_logic;
		RValid      : std_logic;
		RData       : std_logic_vector;
		RResp       : T_AXI4_Response;
    RID         : std_logic_vector;
    RLast       : std_logic;
    RUser       : std_logic_vector;
	end record;
	type T_AXI4_Bus_M2S is record
		AWID        : std_logic_vector; 
		AWAddr      : std_logic_vector; 
    AWLen       : std_logic_vector(7 downto 0); 
    AWSize      : T_AXI4_Size; 
    AWBurst     : T_AXI4_Burst; 
    AWLock      : std_logic_vector(0 to 0); 
    AWQOS       : T_AXI4_QoS;
    AWRegion    : T_AXI4_Region;
    AWUser      : std_logic_vector;
		AWValid     : std_logic; 
    AWCache     : T_AXI4_Cache;
		AWProt      : T_AXI4_Protect;
		WValid      : std_logic;
    WLast       : std_logic;
    WUser       : std_logic_vector;
		WData       : std_logic_vector;
		WStrb       : std_logic_vector;
		BReady      : std_logic;
		ARValid     : std_logic;
		ARAddr      : std_logic_vector;
    ARCache     : T_AXI4_Cache;
		ARProt      : T_AXI4_Protect;
    ARID        : std_logic_vector;
    ARLen       : std_logic_vector(7 downto 0);
    ARSize      : T_AXI4_Size;
    ARBurst     : T_AXI4_Burst;
    ARLock      : std_logic_vector(0 to 0);
    ARQOS       : T_AXI4_QoS;
    ARRegion    : T_AXI4_Region;
    ARUser      : std_logic_vector;
		RReady      : std_logic;
	end record;
  
  type T_AXI4Lite_Bus_S2M_VECTOR is array(natural range <>) of T_AXI4Lite_Bus_S2M;
  type T_AXI4_Bus_S2M_VECTOR is array(natural range <>) of T_AXI4_Bus_S2M;  
  type T_AXI4Lite_Bus_M2S_VECTOR is array(natural range <>) of T_AXI4Lite_Bus_M2S;
  type T_AXI4_Bus_M2S_VECTOR is array(natural range <>) of T_AXI4_Bus_M2S;
	
	function Initialize_AXI4Lite_Bus_S2M(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4Lite_Bus_S2M;
	function Initialize_AXI4_Bus_S2M(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_S2M;
	function Initialize_AXI4Lite_Bus_M2S(AddressBits : natural; DataBits : natural; Value : std_logic := 'Z') return T_AXI4Lite_Bus_M2S;
	function Initialize_AXI4_Bus_M2S(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_M2S;
  
  type T_AXI4_Bus is record
    M2S   : T_AXI4_Bus_M2S;
    S2M   : T_AXI4_Bus_S2M;
  end record;


	-- type T_AXI4Lite_Bus is record
    -- AClk           : std_logic;
    -- AResetN        : std_logic;
		-- WriteAddress   : T_AXI4Lite_WriteAddress_Bus;
		-- WriteData      : T_AXI4Lite_WriteData_Bus;
		-- WriteResponse  : T_AXI4Lite_WriteResponse_Bus;
		-- ReadAddress    : T_AXI4Lite_ReadAddress_Bus;
		-- ReadData       : T_AXI4Lite_ReadData_Bus;
	-- end record;

	-- type T_AXI4_Bus is record
    -- AClk           : std_logic;
    -- AResetN        : std_logic;
		-- WriteAddress   : T_AXI4_WriteAddress_Bus;
		-- WriteData      : T_AXI4_WriteData_Bus;
		-- WriteResponse  : T_AXI4_WriteResponse_Bus;
		-- ReadAddress    : T_AXI4_ReadAddress_Bus;
		-- ReadData       : T_AXI4_ReadData_Bus;
	-- end record;

  type T_AXI4Lite_Bus_VECTOR is array(natural range <>) of T_AXI4Lite_Bus;
  type T_AXI4_Bus_VECTOR is array(natural range <>) of T_AXI4_Bus;
	
	function Initialize_AXI4Lite_Bus(AddressBits : natural; DataBits : natural) return T_AXI4Lite_Bus;
	function Initialize_AXI4_Bus(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_Bus;
	
	
	
end package;


package body AXI4 is 
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
--  function Initialize_AXI4_WriteAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteAddress_Bus is
--  begin
--    return (
--      AWValid => 'Z',
--      AWReady => 'Z',
--      AWCache => C_AXI4_CACHE_INIT,
--      AWAddr  => (AddressBits-1 downto 0 => 'Z'), 
--      AWProt  => C_AXI4_PROTECT_INIT,
--      AWID    => (IDBits-1 downto 0 => 'Z'), 
--      AWLen   => (others => 'Z'),
--      AWSize  => C_AXI4_SIZE_INIT,
--      AWBurst => C_AXI4_BURST_INIT,
--      AWLock  => 'Z',
--      AWQOS   => C_AXI4_QOS_INIT,
--      AWRegion=> C_AXI4_REGION_INIT,
--      AWUser  => (UserBits-1 downto 0 => 'Z')
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
--  function Initialize_AXI4_WriteData_Bus(DataBits : natural; UserBits : natural := 0) return T_AXI4_WriteData_Bus is
--  begin
--    return (
--      WValid  => 'Z',
--      WReady  => 'Z',
--      WData   => (DataBits - 1 downto 0 => 'Z'),
--      WStrb   => ((DataBits / 8) - 1 downto 0 => 'Z'),
--      WLast   => 'Z',
--      WUser   => (UserBits - 1 downto 0 => 'Z')
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
--  function Initialize_AXI4_WriteResponse_Bus(UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteResponse_Bus is
--  begin
--    return (
--      BValid  => 'Z',
--      BReady  => 'Z',
--      BResp   => C_AXI4_RESPONSE_INIT,
--      BID     => (IDBits - 1 downto 0 => 'Z'),
--      BUser   => (UserBits - 1 downto 0 => 'Z')
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
--  function Initialize_AXI4_ReadAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadAddress_Bus is
--  begin
--    return (
--      ARValid => 'Z',
--      ARReady => 'Z',
--      ARCache => C_AXI4_CACHE_INIT,
--      ARAddr  => (AddressBits - 1 downto 0 => 'Z'),
--      ARProt  => C_AXI4_PROTECT_INIT,
--      ARID    => (IDBits - 1 downto 0 => 'Z'),
--      ARLen   => (others => 'Z'),
--      ARSize  => C_AXI4_SIZE_INIT,
--      ARBurst => C_AXI4_BURST_INIT,
--      ARLock  => 'Z',
--      ARQOS   => C_AXI4_QOS_INIT,
--      ARRegion=> C_AXI4_REGION_INIT,
--      ARUser  => (UserBits - 1 downto 0 => 'Z')
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
--  function Initialize_AXI4_ReadData_Bus(DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadData_Bus is
--  begin
--    return (
--      RValid  => 'Z',
--      RReady  => 'Z',
--      RData   => (DataBits - 1 downto 0 => 'Z'),
--      RResp   => C_AXI4_RESPONSE_INIT,
--      RID     => (IDBits - 1 downto 0 => 'Z'),
--      RLast   => 'Z',
--      RUser   => (UserBits - 1 downto 0 => 'Z')
--    );
--  end function;

  --------------INIT
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
  
  
  function Initialize_AXI4_Bus_S2M(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_S2M is
    variable var : T_AXI4_Bus_S2M(
      BID(IDBits - 1 downto 0), RID(IDBits - 1 downto 0),
      BUser(UserBits - 1 downto 0), RUser(UserBits - 1 downto 0),
      RData(DataBits - 1 downto 0)
    ) := (
      AWReady => Value,
      WReady  => Value,
      BValid  => Value,
      BResp   => (others => Value),
      BID     => (IDBits - 1 downto 0 => Value),
      BUser   => (UserBits - 1 downto 0 => Value),
      ARReady => Value,
      RValid  => Value,
      RData   => (DataBits - 1 downto 0 => Value),
      RResp   => (others => Value),
      RID     => (IDBits - 1 downto 0 => Value),
      RLast   => Value,
      RUser   => (UserBits - 1 downto 0 => Value)
    );
  begin
    return var;
  end function;
	
  function Initialize_AXI4_Bus_M2S(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_M2S is
    variable var : T_AXI4_Bus_M2S(
      AWID(IDBits - 1 downto 0), ARID(IDBits - 1 downto 0),
      AWUser(UserBits - 1 downto 0), ARUser(UserBits - 1 downto 0), WUser(UserBits - 1 downto 0),
      WData(DataBits - 1 downto 0), WStrb((DataBits / 8) - 1 downto 0),
      AWAddr(AddressBits-1 downto 0), ARAddr(AddressBits - 1 downto 0)
    ) := (
      AWValid => Value,
      AWCache => (others => Value),
      AWAddr  => (AddressBits-1 downto 0 => Value), 
      AWProt  => (others => Value),
      AWID    => (IDBits-1 downto 0 => Value), 
      AWLen   => (others => Value),
      AWSize  => (others => Value),
      AWBurst => (others => Value),
      AWLock  => (others => Value),
      AWQOS   => (others => Value),
      AWRegion=> (others => Value),
      AWUser  => (UserBits-1 downto 0 => Value),
      WValid  => Value,
      WData   => (DataBits - 1 downto 0 => Value),
      WStrb   => ((DataBits / 8) - 1 downto 0 => Value),
      WLast   => Value,
      WUser   => (UserBits - 1 downto 0 => Value),
      BReady  => Value,
      ARValid => Value,
      ARCache => (others => Value),
      ARAddr  => (AddressBits - 1 downto 0 => Value),
      ARProt  => (others => Value),
      ARID    => (IDBits - 1 downto 0 => Value),
      ARLen   => (others => Value),
      ARSize  => (others => Value),
      ARBurst => (others => Value),
      ARLock  => (others => Value),
      ARQOS   => (others => Value),
      ARRegion=> (others => Value),
      ARUser  => (UserBits - 1 downto 0 => Value),
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
  
  -- --------------INIT
  -- function Initialize_AXI4Lite_Bus(AddressBits : natural; DataBits : natural) return T_AXI4Lite_Bus is
  -- begin
    -- return ( 
      -- AClk          => 'Z',
      -- AResetN       => 'Z',
      -- WriteAddress  => Initialize_AXI4Lite_WriteAddress_Bus(AddressBits),
      -- WriteData     => Initialize_AXI4Lite_WriteData_Bus(DataBits),
      -- WriteResponse => Initialize_AXI4Lite_WriteResponse_Bus,
      -- ReadAddress   => Initialize_AXI4Lite_ReadAddress_Bus(AddressBits),
      -- ReadData      => Initialize_AXI4Lite_ReadData_Bus(DataBits)
    -- );
  -- end function; 
  -- function Initialize_AXI4_Bus(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_Bus is
  -- begin
    -- return ( 
      -- AClk          => 'Z',
      -- AResetN       => 'Z',
      -- WriteAddress  => Initialize_AXI4_WriteAddress_Bus(AddressBits, UserBits, IDBits),
      -- WriteData     => Initialize_AXI4_WriteData_Bus(DataBits, UserBits),
      -- WriteResponse => Initialize_AXI4_WriteResponse_Bus(UserBits, IDBits),
      -- ReadAddress   => Initialize_AXI4_ReadAddress_Bus(AddressBits, UserBits, IDBits),
      -- ReadData      => Initialize_AXI4_ReadData_Bus(DataBits, UserBits, IDBits)
    -- );
  -- end function; 
end package body;
