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

  
  -- Generic
--    axi_addr_width   : natural := 32;
--    axi_data_width   : natural := 32;
--    axi_id_width     : natural := 2;
--    axi_user_width   : natural := 4


package AXI4 is
  subtype  T_AXI4_Response is std_logic_vector(1 downto 0);
	constant C_AXI4_RESPONSE_OKAY         : T_AXI4_Response := "00";
	constant C_AXI4_RESPONSE_EX_OKAY      : T_AXI4_Response := "01";
	constant C_AXI4_RESPONSE_SLAVE_ERROR  : T_AXI4_Response := "10";
	constant C_AXI4_RESPONSE_DECODE_ERROR : T_AXI4_Response := "11";
	constant C_AXI4_RESPONSE_INIT         : T_AXI4_Response := "ZZ";
  
  subtype  T_AXI4_Cache    is std_logic_vector(3 downto 0);
  constant C_AXI4_CACHE_INIT : T_AXI4_Cache := "ZZZZ";  
  
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

  ------- Write Address Channel
	-- AXI4-Lite 
  type T_AXI4Lite_WriteAddress_Bus is record
		AWValid     : std_logic; 
		AWReady     : std_logic;
		AWAddr      : unsigned; 
    AWCache     : T_AXI4_Cache;
		AWProt      : T_AXI4_Protect;
	end record; 	
  -- AXI4
  type T_AXI4_WriteAddress_Bus is record
    AWID        : unsigned; 
		AWAddr      : unsigned; 
    AWLen       : unsigned(7 downto 0); 
    AWSize      : T_AXI4_Size; 
    AWBurst     : T_AXI4_Burst; 
    AWLock      : std_logic; 
    AWQOS       : T_AXI4_QoS;
    AWRegion    : T_AXI4_Region;
    AWUser      : std_logic_vector;
		AWValid     : std_logic; 
		AWReady     : std_logic;
    AWCache     : T_AXI4_Cache;
		AWProt      : T_AXI4_Protect;
	end record; 

	function Initialize_AXI4Lite_WriteAddress_Bus(AddressBits : natural) return T_AXI4Lite_WriteAddress_Bus;
	function Initialize_AXI4_WriteAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteAddress_Bus;

  ------- Write Data Channel
	-- AXI4-Lite 
	type T_AXI4Lite_WriteData_Bus is record
		WValid      : std_logic;
		WReady      : std_logic;
		WData       : std_logic_vector;
		WStrb       : std_logic_vector;
	end record;
	-- AXI4
	type T_AXI4_WriteData_Bus is record
		WValid      : std_logic;
		WReady      : std_logic;
    WLast       : std_logic;
    WUser       : std_logic_vector;
		WData       : std_logic_vector;
		WStrb       : std_logic_vector;
	end record;

	function Initialize_AXI4Lite_WriteData_Bus(DataBits : natural) return T_AXI4Lite_WriteData_Bus;
	function Initialize_AXI4_WriteData_Bus(DataBits : natural; UserBits : natural := 0) return T_AXI4_WriteData_Bus;

  -------- Write Response Channel
	-- AXI4-Lite 
	type T_AXI4Lite_WriteResponse_Bus is record
		BValid      : std_logic;
		BReady      : std_logic;
		BResp       : T_AXI4_Response; 
	end record; 
	-- AXI4
	type T_AXI4_WriteResponse_Bus is record
		BValid      : std_logic;
		BReady      : std_logic;
		BResp       : T_AXI4_Response; 
    BID         : unsigned; 
    BUser       : std_logic_vector;
	end record; 

	function Initialize_AXI4Lite_WriteResponse_Bus return T_AXI4Lite_WriteResponse_Bus;
	function Initialize_AXI4_WriteResponse_Bus(UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteResponse_Bus;

  ------ Read Address Channel
	-- AXI4-Lite 
	type T_AXI4Lite_ReadAddress_Bus is record
		ARValid     : std_logic;
		ARReady     : std_logic;
		ARAddr      : unsigned;
    ARCache     : T_AXI4_Cache;
		ARProt      : T_AXI4_Protect;
	end record;
	-- AXI4
	type T_AXI4_ReadAddress_Bus is record
		ARValid     : std_logic;
		ARReady     : std_logic;
		ARAddr      : unsigned;
    ARCache     : T_AXI4_Cache;
		ARProt      : T_AXI4_Protect;
    ARID        : unsigned;
    ARLen       : unsigned(7 downto 0);
    ARSize      : T_AXI4_Size;
    ARBurst     : T_AXI4_Burst;
    ARLock      : std_logic;
    ARQOS       : T_AXI4_QoS;
    ARRegion    : T_AXI4_Region;
    ARUser      : std_logic_vector;
	end record;

	function Initialize_AXI4Lite_ReadAddress_Bus(AddressBits : natural) return T_AXI4Lite_ReadAddress_Bus;
	function Initialize_AXI4_ReadAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadAddress_Bus;

  ------- Read Data Channel
	-- AXI4-Lite 
	type T_AXI4Lite_ReadData_Bus is record
		RValid      : std_logic;
		RReady      : std_logic;
		RData       : std_logic_vector;
		RResp       : T_AXI4_Response;
	end record;
	-- AXI4
	type T_AXI4_ReadData_Bus is record
		RValid      : std_logic;
		RReady      : std_logic;
		RData       : std_logic_vector;
		RResp       : T_AXI4_Response;
    RID         : unsigned;
    RLast       : std_logic;
    RUser       : std_logic_vector;
	end record;
  
	function Initialize_AXI4Lite_ReadData_Bus(DataBits : natural ) return T_AXI4Lite_ReadData_Bus;
	function Initialize_AXI4_ReadData_Bus(DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadData_Bus;


	type T_AXI4Lite_Bus is record
    AClk        : std_logic;
    AResetN     : std_logic;
		AWValid     : std_logic; 
		AWReady     : std_logic;
		AWAddr      : unsigned; 
    AWCache     : T_AXI4_Cache;
		AWProt      : T_AXI4_Protect;
		WValid      : std_logic;
		WReady      : std_logic;
		WData       : std_logic_vector;
		WStrb       : std_logic_vector;
		BValid      : std_logic;
		BReady      : std_logic;
		BResp       : T_AXI4_Response; 
		ARValid     : std_logic;
		ARReady     : std_logic;
		ARAddr      : unsigned;
    ARCache     : T_AXI4_Cache;
		ARProt      : T_AXI4_Protect;
		RValid      : std_logic;
		RReady      : std_logic;
		RData       : std_logic_vector;
		RResp       : T_AXI4_Response;
	end record;

	type T_AXI4_Bus is record
    AClk        : std_logic;
    AResetN     : std_logic;
		AWID        : unsigned; 
		AWAddr      : unsigned; 
    AWLen       : unsigned(7 downto 0); 
    AWSize      : T_AXI4_Size; 
    AWBurst     : T_AXI4_Burst; 
    AWLock      : std_logic; 
    AWQOS       : T_AXI4_QoS;
    AWRegion    : T_AXI4_Region;
    AWUser      : std_logic_vector;
		AWValid     : std_logic; 
		AWReady     : std_logic;
    AWCache     : T_AXI4_Cache;
		AWProt      : T_AXI4_Protect;
		WValid      : std_logic;
		WReady      : std_logic;
    WLast       : std_logic;
    WUser       : std_logic_vector;
		WData       : std_logic_vector;
		WStrb       : std_logic_vector;
		BValid      : std_logic;
		BReady      : std_logic;
		BResp       : T_AXI4_Response; 
    BID         : unsigned; 
    BUser       : std_logic_vector;
		ARValid     : std_logic;
		ARReady     : std_logic;
		ARAddr      : unsigned;
    ARCache     : T_AXI4_Cache;
		ARProt      : T_AXI4_Protect;
    ARID        : unsigned;
    ARLen       : unsigned(7 downto 0);
    ARSize      : T_AXI4_Size;
    ARBurst     : T_AXI4_Burst;
    ARLock      : std_logic;
    ARQOS       : T_AXI4_QoS;
    ARRegion    : T_AXI4_Region;
    ARUser      : std_logic_vector;
		RValid      : std_logic;
		RReady      : std_logic;
		RData       : std_logic_vector;
		RResp       : T_AXI4_Response;
    RID         : unsigned;
    RLast       : std_logic;
    RUser       : std_logic_vector;
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
  -----------Wirte Address
  function Initialize_AXI4Lite_WriteAddress_Bus(AddressBits : natural) return T_AXI4Lite_WriteAddress_Bus is
  begin
    return (
      AWValid => 'Z',
      AWReady => 'Z',
      AWCache => C_AXI4_CACHE_INIT,
      AWAddr  => (AddressBits-1 downto 0 => 'Z'), 
      AWProt  => C_AXI4_PROTECT_INIT
    );
  end function;
  function Initialize_AXI4_WriteAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteAddress_Bus is
  begin
    return (
      AWValid => 'Z',
      AWReady => 'Z',
      AWCache => C_AXI4_CACHE_INIT,
      AWAddr  => (AddressBits-1 downto 0 => 'Z'), 
      AWProt  => C_AXI4_PROTECT_INIT,
      AWID    => (IDBits-1 downto 0 => 'Z'), 
      AWLen   => (others => 'Z'),
      AWSize  => C_AXI4_SIZE_INIT,
      AWBurst => C_AXI4_BURST_INIT,
      AWLock  => 'Z',
      AWQOS   => C_AXI4_QOS_INIT,
      AWRegion=> C_AXI4_REGION_INIT,
      AWUser  => (UserBits-1 downto 0 => 'Z')
    );
  end function;
  
  -----------Write Data
  function Initialize_AXI4Lite_WriteData_Bus(DataBits : natural) return T_AXI4Lite_WriteData_Bus is
  begin
    return (
      WValid  => 'Z',
      WReady  => 'Z',
      WData   => (DataBits - 1 downto 0 => 'Z'),
      WStrb   => ((DataBits / 8) - 1 downto 0 => 'Z') 
    );
  end function;
  function Initialize_AXI4_WriteData_Bus(DataBits : natural; UserBits : natural := 0) return T_AXI4_WriteData_Bus is
  begin
    return (
      WValid  => 'Z',
      WReady  => 'Z',
      WData   => (DataBits - 1 downto 0 => 'Z'),
      WStrb   => ((DataBits / 8) - 1 downto 0 => 'Z'),
      WLast   => 'Z',
      WUser   => (UserBits - 1 downto 0 => 'Z')
    );
  end function;

  -----------Write Response
  function Initialize_AXI4Lite_WriteResponse_Bus return T_AXI4Lite_WriteResponse_Bus is
  begin
    return (
      BValid  => 'Z',
      BReady  => 'Z',
      BResp   => C_AXI4_RESPONSE_INIT  
    );
  end function;
  function Initialize_AXI4_WriteResponse_Bus(UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteResponse_Bus is
  begin
    return (
      BValid  => 'Z',
      BReady  => 'Z',
      BResp   => C_AXI4_RESPONSE_INIT,
      BID     => (IDBits - 1 downto 0 => 'Z'),
      BUser   => (UserBits - 1 downto 0 => 'Z')
    );
  end function;

  -------------Read Address
  function Initialize_AXI4Lite_ReadAddress_Bus(AddressBits : natural) return T_AXI4Lite_ReadAddress_Bus is
  begin
    return (
      ARValid => 'Z',
      ARReady => 'Z',
      ARCache => C_AXI4_CACHE_INIT,
      ARAddr  => (AddressBits - 1 downto 0 => 'Z'),
      ARProt  => C_AXI4_PROTECT_INIT
    );
  end function;
  function Initialize_AXI4_ReadAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadAddress_Bus is
  begin
    return (
      ARValid => 'Z',
      ARReady => 'Z',
      ARCache => C_AXI4_CACHE_INIT,
      ARAddr  => (AddressBits - 1 downto 0 => 'Z'),
      ARProt  => C_AXI4_PROTECT_INIT,
      ARID    => (IDBits - 1 downto 0 => 'Z'),
      ARLen   => (others => 'Z'),
      ARSize  => C_AXI4_SIZE_INIT,
      ARBurst => C_AXI4_BURST_INIT,
      ARLock  => 'Z',
      ARQOS   => C_AXI4_QOS_INIT,
      ARRegion=> C_AXI4_REGION_INIT,
      ARUser  => (UserBits - 1 downto 0 => 'Z')
    );
  end function;

  -----------------Read Data
  function Initialize_AXI4Lite_ReadData_Bus(DataBits : natural) return T_AXI4Lite_ReadData_Bus is
  begin
    return (
      RValid  => 'Z',
      RReady  => 'Z',
      RData   => (DataBits - 1 downto 0 => 'Z'),
      RResp   => C_AXI4_RESPONSE_INIT
    );
  end function;
  function Initialize_AXI4_ReadData_Bus(DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadData_Bus is
  begin
    return (
      RValid  => 'Z',
      RReady  => 'Z',
      RData   => (DataBits - 1 downto 0 => 'Z'),
      RResp   => C_AXI4_RESPONSE_INIT,
      RID     => (IDBits - 1 downto 0 => 'Z'),
      RLast   => 'Z',
      RUser   => (UserBits - 1 downto 0 => 'Z')
    );
  end function;

  --------------INIT
  function Initialize_AXI4Lite_Bus(AddressBits : natural; DataBits : natural) return T_AXI4Lite_Bus is
  begin
    return ( 
      AClk    => 'Z',
      AResetN => 'Z',
      AWValid => 'Z',
      AWReady => 'Z',
      AWCache => C_AXI4_CACHE_INIT,
      AWAddr  => (AddressBits-1 downto 0 => 'Z'), 
      AWProt  => C_AXI4_PROTECT_INIT,
      WValid  => 'Z',
      WReady  => 'Z',
      WData   => (DataBits - 1 downto 0 => 'Z'),
      WStrb   => ((DataBits / 8) - 1 downto 0 => 'Z'),
      BValid  => 'Z',
      BReady  => 'Z',
      BResp   => C_AXI4_RESPONSE_INIT,
      ARValid => 'Z',
      ARReady => 'Z',
      ARCache => C_AXI4_CACHE_INIT,
      ARAddr  => (AddressBits - 1 downto 0 => 'Z'),
      ARProt  => C_AXI4_PROTECT_INIT,
      RValid  => 'Z',
      RReady  => 'Z',
      RData   => (DataBits - 1 downto 0 => 'Z'),
      RResp   => C_AXI4_RESPONSE_INIT
    );
  end function; 
  function Initialize_AXI4_Bus(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_Bus is
  begin
    return ( 
      AClk    => 'Z',
      AResetN => 'Z',
      AWValid => 'Z',
      AWReady => 'Z',
      AWCache => C_AXI4_CACHE_INIT,
      AWAddr  => (AddressBits-1 downto 0 => 'Z'), 
      AWProt  => C_AXI4_PROTECT_INIT,
      AWID    => (IDBits-1 downto 0 => 'Z'), 
      AWLen   => (others => 'Z'),
      AWSize  => C_AXI4_SIZE_INIT,
      AWBurst => C_AXI4_BURST_INIT,
      AWLock  => 'Z',
      AWQOS   => C_AXI4_QOS_INIT,
      AWRegion=> C_AXI4_REGION_INIT,
      AWUser  => (UserBits-1 downto 0 => 'Z'),
      WValid  => 'Z',
      WReady  => 'Z',
      WData   => (DataBits - 1 downto 0 => 'Z'),
      WStrb   => ((DataBits / 8) - 1 downto 0 => 'Z'),
      WLast   => 'Z',
      WUser   => (UserBits - 1 downto 0 => 'Z'),
      BValid  => 'Z',
      BReady  => 'Z',
      BResp   => C_AXI4_RESPONSE_INIT,
      BID     => (IDBits - 1 downto 0 => 'Z'),
      BUser   => (UserBits - 1 downto 0 => 'Z'),
      ARValid => 'Z',
      ARReady => 'Z',
      ARCache => C_AXI4_CACHE_INIT,
      ARAddr  => (AddressBits - 1 downto 0 => 'Z'),
      ARProt  => C_AXI4_PROTECT_INIT,
      ARID    => (IDBits - 1 downto 0 => 'Z'),
      ARLen   => (others => 'Z'),
      ARSize  => C_AXI4_SIZE_INIT,
      ARBurst => C_AXI4_BURST_INIT,
      ARLock  => 'Z',
      ARQOS   => C_AXI4_QOS_INIT,
      ARRegion=> C_AXI4_REGION_INIT,
      ARUser  => (UserBits - 1 downto 0 => 'Z'),
      RValid  => 'Z',
      RReady  => 'Z',
      RData   => (DataBits - 1 downto 0 => 'Z'),
      RResp   => C_AXI4_RESPONSE_INIT,
      RID     => (IDBits - 1 downto 0 => 'Z'),
      RLast   => 'Z',
      RUser   => (UserBits - 1 downto 0 => 'Z')
    );

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
