-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:				 	Generic AMBA AXI4 (full) bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic AMBA AXI4 (full) description.
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


package AXI4_Full is
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
	
	alias T_AXI4_QoS                    is work.AXI4_Common.T_AXI4_QoS;
	alias C_AXI4_QOS_INIT               is work.AXI4_Common.C_AXI4_QOS_INIT;

	alias T_AXI4_Region                 is work.AXI4_Common.T_AXI4_Region;
	alias C_AXI4_REGION_INIT            is work.AXI4_Common.C_AXI4_REGION_INIT;

	alias T_AXI4_Size                   is work.AXI4_Common.T_AXI4_Size;
	alias C_AXI4_SIZE_1                 is work.AXI4_Common.C_AXI4_SIZE_1;
	alias C_AXI4_SIZE_2                 is work.AXI4_Common.C_AXI4_SIZE_2;
	alias C_AXI4_SIZE_4                 is work.AXI4_Common.C_AXI4_SIZE_4;
	alias C_AXI4_SIZE_8                 is work.AXI4_Common.C_AXI4_SIZE_8;
	alias C_AXI4_SIZE_16                is work.AXI4_Common.C_AXI4_SIZE_16;
	alias C_AXI4_SIZE_32                is work.AXI4_Common.C_AXI4_SIZE_32;
	alias C_AXI4_SIZE_64                is work.AXI4_Common.C_AXI4_SIZE_64;
	alias C_AXI4_SIZE_128               is work.AXI4_Common.C_AXI4_SIZE_128;
	alias C_AXI4_SIZE_INIT              is work.AXI4_Common.C_AXI4_SIZE_INIT;

	alias T_AXI4_Burst                  is work.AXI4_Common.T_AXI4_Burst;
	alias C_AXI4_BURST_FIXED            is work.AXI4_Common.C_AXI4_BURST_FIXED;
	alias C_AXI4_BURST_INCR             is work.AXI4_Common.C_AXI4_BURST_INCR;
	alias C_AXI4_BURST_WRAP             is work.AXI4_Common.C_AXI4_BURST_WRAP;
	alias C_AXI4_BURST_INIT             is work.AXI4_Common.C_AXI4_BURST_INIT;


	-- ------- Write Address Channel
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

	-- function Initialize_AXI4_WriteAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteAddress_Bus;

	-- ------- Write Data Channel
	-- -- AXI4
	-- type T_AXI4_WriteData_Bus is record
		-- WValid      : std_logic;
		-- WReady      : std_logic;
		-- WLast       : std_logic;
		-- WUser       : std_logic_vector;
		-- WData       : std_logic_vector;
		-- WStrb       : std_logic_vector;
	-- end record;

	-- function Initialize_AXI4_WriteData_Bus(DataBits : natural; UserBits : natural := 0) return T_AXI4_WriteData_Bus;

	-- -------- Write Response Channel
	-- -- AXI4
	-- type T_AXI4_WriteResponse_Bus is record
		-- BValid      : std_logic;
		-- BReady      : std_logic;
		-- BResp       : T_AXI4_Response; 
		-- BID         : unsigned; 
		-- BUser       : std_logic_vector;
	-- end record; 

	-- function Initialize_AXI4_WriteResponse_Bus(UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_WriteResponse_Bus;

	-- ------ Read Address Channel
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

	-- function Initialize_AXI4_ReadAddress_Bus(AddressBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadAddress_Bus;

	-- ------- Read Data Channel
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
	
	-- function Initialize_AXI4_ReadData_Bus(DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_ReadData_Bus;


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
	type T_AXI4_Bus_S2M_VECTOR is array(natural range <>) of T_AXI4_Bus_S2M;
	
	function BlockTransaction(Bus : T_AXI4_Bus_S2M;        Enable : std_logic) return T_AXI4_Bus_S2M;
	function BlockTransaction(Bus : T_AXI4_Bus_S2M_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_S2M_VECTOR;
	
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
	type T_AXI4_Bus_M2S_VECTOR is array(natural range <>) of T_AXI4_Bus_M2S;
	
	function BlockTransaction(Bus : T_AXI4_Bus_M2S;        Enable : std_logic) return T_AXI4_Bus_M2S;
	function BlockTransaction(Bus : T_AXI4_Bus_M2S_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_M2S_VECTOR;

	function Initialize_AXI4_Bus_S2M(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_S2M;
	function Initialize_AXI4_Bus_M2S(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_M2S;
	
	type T_AXI4_Bus is record
		M2S   : T_AXI4_Bus_M2S;
		S2M   : T_AXI4_Bus_S2M;
	end record;
	type T_AXI4_Bus_VECTOR is array(natural range <>) of T_AXI4_Bus;
	
	function Initialize_AXI4_Bus(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0) return T_AXI4_Bus;
end package;


package body AXI4_Full is 
	
	function BlockTransaction(Bus : T_AXI4_Bus_M2S;        Enable : std_logic) return T_AXI4_Bus_M2S is
		variable temp : Bus'subtype;
	begin
		temp.AWID    := Bus.AWID    ;
		temp.AWAddr  := Bus.AWAddr  ;
		temp.AWLen   := Bus.AWLen   ;
		temp.AWSize  := Bus.AWSize  ;
		temp.AWBurst := Bus.AWBurst ;
		temp.AWLock  := Bus.AWLock  ;
		temp.AWQOS   := Bus.AWQOS   ;
		temp.AWRegion:= Bus.AWRegion;
		temp.AWUser  := Bus.AWUser  ;
		temp.AWValid := Bus.AWValid and Enable;
		temp.AWCache := Bus.AWCache ;
		temp.AWProt  := Bus.AWProt  ;
		temp.WValid  := Bus.WValid and Enable;
		temp.WLast   := Bus.WLast   ;
		temp.WUser   := Bus.WUser   ;
		temp.WData   := Bus.WData   ;
		temp.WStrb   := Bus.WStrb   ;
		temp.BReady  := Bus.BReady and Enable;
		temp.ARValid := Bus.ARValid and Enable;
		temp.ARAddr  := Bus.ARAddr  ;
		temp.ARCache := Bus.ARCache ;
		temp.ARProt  := Bus.ARProt  ;
		temp.ARID    := Bus.ARID    ;
		temp.ARLen   := Bus.ARLen   ;
		temp.ARSize  := Bus.ARSize  ;
		temp.ARBurst := Bus.ARBurst ;
		temp.ARLock  := Bus.ARLock  ;
		temp.ARQOS   := Bus.ARQOS   ;
		temp.ARRegion:= Bus.ARRegion;
		temp.ARUser  := Bus.ARUser  ;
		temp.RReady  := Bus.RReady and Enable;
		return temp;
	end function;
	
	function BlockTransaction(Bus : T_AXI4_Bus_M2S_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_M2S_VECTOR is
		variable temp : Bus'subtype;
	begin
		for i in Bus'range loop
			temp(i).AWID    := Bus(i).AWID    ;
			temp(i).AWAddr  := Bus(i).AWAddr  ;
			temp(i).AWLen   := Bus(i).AWLen   ;
			temp(i).AWSize  := Bus(i).AWSize  ;
			temp(i).AWBurst := Bus(i).AWBurst ;
			temp(i).AWLock  := Bus(i).AWLock  ;
			temp(i).AWQOS   := Bus(i).AWQOS   ;
			temp(i).AWRegion:= Bus(i).AWRegion;
			temp(i).AWUser  := Bus(i).AWUser  ;
			temp(i).AWValid := Bus(i).AWValid and Enable;
			temp(i).AWCache := Bus(i).AWCache ;
			temp(i).AWProt  := Bus(i).AWProt  ;
			temp(i).WValid  := Bus(i).WValid and Enable;
			temp(i).WLast   := Bus(i).WLast   ;
			temp(i).WUser   := Bus(i).WUser   ;
			temp(i).WData   := Bus(i).WData   ;
			temp(i).WStrb   := Bus(i).WStrb   ;
			temp(i).BReady  := Bus(i).BReady and Enable;
			temp(i).ARValid := Bus(i).ARValid and Enable;
			temp(i).ARAddr  := Bus(i).ARAddr  ;
			temp(i).ARCache := Bus(i).ARCache ;
			temp(i).ARProt  := Bus(i).ARProt  ;
			temp(i).ARID    := Bus(i).ARID    ;
			temp(i).ARLen   := Bus(i).ARLen   ;
			temp(i).ARSize  := Bus(i).ARSize  ;
			temp(i).ARBurst := Bus(i).ARBurst ;
			temp(i).ARLock  := Bus(i).ARLock  ;
			temp(i).ARQOS   := Bus(i).ARQOS   ;
			temp(i).ARRegion:= Bus(i).ARRegion;
			temp(i).ARUser  := Bus(i).ARUser  ;
			temp(i).RReady  := Bus(i).RReady and Enable;
		end loop;
		return temp;
	end function;
	
	function BlockTransaction(Bus : T_AXI4_Bus_S2M;        Enable : std_logic) return T_AXI4_Bus_S2M is
		variable temp : Bus'subtype;
	begin
		temp.AWReady:= Bus.AWReady and Enable;
		temp.WReady := Bus.WReady and Enable;
		temp.BValid := Bus.BValid and Enable;
		temp.BResp  := Bus.BResp  ;
		temp.BID    := Bus.BID    ;
		temp.BUser  := Bus.BUser  ;
		temp.ARReady:= Bus.ARReady and Enable;
		temp.RValid := Bus.RValid and Enable;
		temp.RData  := Bus.RData  ;
		temp.RResp  := Bus.RResp  ;
		temp.RID    := Bus.RID    ;
		temp.RLast  := Bus.RLast  ;
		temp.RUser  := Bus.RUser  ;
		return temp;
	end function;
	
	function BlockTransaction(Bus : T_AXI4_Bus_S2M_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_S2M_VECTOR is
		variable temp : Bus'subtype;
	begin
		for i in Bus'range loop
			temp(i).AWReady:= Bus(i).AWReady and Enable;
			temp(i).WReady := Bus(i).WReady and Enable;
			temp(i).BValid := Bus(i).BValid and Enable;
			temp(i).BResp  := Bus(i).BResp  ;
			temp(i).BID    := Bus(i).BID    ;
			temp(i).BUser  := Bus(i).BUser  ;
			temp(i).ARReady:= Bus(i).ARReady and Enable;
			temp(i).RValid := Bus(i).RValid and Enable;
			temp(i).RData  := Bus(i).RData  ;
			temp(i).RResp  := Bus(i).RResp  ;
			temp(i).RID    := Bus(i).RID    ;
			temp(i).RLast  := Bus(i).RLast  ;
			temp(i).RUser  := Bus(i).RUser  ;
		end loop;
		return temp;
	end function;
	
	
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
