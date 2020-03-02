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
	
	function BlockTransaction(InBus : T_AXI4_Bus_S2M;        Enable : std_logic) return T_AXI4_Bus_S2M;
	function BlockTransaction(InBus : T_AXI4_Bus_S2M_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_S2M_VECTOR;
	
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
	
	function BlockTransaction(InBus : T_AXI4_Bus_M2S;        Enable : std_logic) return T_AXI4_Bus_M2S;
	function BlockTransaction(InBus : T_AXI4_Bus_M2S_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_M2S_VECTOR;
	
	function AddressTranslate(InBus : T_AXI4_Bus_M2S;        Offset : signed) return T_AXI4_Bus_M2S;
	
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
	
	function BlockTransaction(InBus : T_AXI4_Bus_M2S;        Enable : std_logic) return T_AXI4_Bus_M2S is
		variable temp : InBus'subtype;
	begin
		temp.AWID    := InBus.AWID    ;
		temp.AWAddr  := InBus.AWAddr  ;
		temp.AWLen   := InBus.AWLen   ;
		temp.AWSize  := InBus.AWSize  ;
		temp.AWBurst := InBus.AWBurst ;
		temp.AWLock  := InBus.AWLock  ;
		temp.AWQOS   := InBus.AWQOS   ;
		temp.AWRegion:= InBus.AWRegion;
		temp.AWUser  := InBus.AWUser  ;
		temp.AWValid := InBus.AWValid and Enable;
		temp.AWCache := InBus.AWCache ;
		temp.AWProt  := InBus.AWProt  ;
		temp.WValid  := InBus.WValid and Enable;
		temp.WLast   := InBus.WLast   ;
		temp.WUser   := InBus.WUser   ;
		temp.WData   := InBus.WData   ;
		temp.WStrb   := InBus.WStrb   ;
		temp.BReady  := InBus.BReady and Enable;
		temp.ARValid := InBus.ARValid and Enable;
		temp.ARAddr  := InBus.ARAddr  ;
		temp.ARCache := InBus.ARCache ;
		temp.ARProt  := InBus.ARProt  ;
		temp.ARID    := InBus.ARID    ;
		temp.ARLen   := InBus.ARLen   ;
		temp.ARSize  := InBus.ARSize  ;
		temp.ARBurst := InBus.ARBurst ;
		temp.ARLock  := InBus.ARLock  ;
		temp.ARQOS   := InBus.ARQOS   ;
		temp.ARRegion:= InBus.ARRegion;
		temp.ARUser  := InBus.ARUser  ;
		temp.RReady  := InBus.RReady and Enable;
		return temp;
	end function;
	
	function BlockTransaction(InBus : T_AXI4_Bus_M2S_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_M2S_VECTOR is
		variable temp : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i).AWID    := InBus(i).AWID    ;
			temp(i).AWAddr  := InBus(i).AWAddr  ;
			temp(i).AWLen   := InBus(i).AWLen   ;
			temp(i).AWSize  := InBus(i).AWSize  ;
			temp(i).AWBurst := InBus(i).AWBurst ;
			temp(i).AWLock  := InBus(i).AWLock  ;
			temp(i).AWQOS   := InBus(i).AWQOS   ;
			temp(i).AWRegion:= InBus(i).AWRegion;
			temp(i).AWUser  := InBus(i).AWUser  ;
			temp(i).AWValid := InBus(i).AWValid and Enable(i);
			temp(i).AWCache := InBus(i).AWCache ;
			temp(i).AWProt  := InBus(i).AWProt  ;
			temp(i).WValid  := InBus(i).WValid and Enable(i);
			temp(i).WLast   := InBus(i).WLast   ;
			temp(i).WUser   := InBus(i).WUser   ;
			temp(i).WData   := InBus(i).WData   ;
			temp(i).WStrb   := InBus(i).WStrb   ;
			temp(i).BReady  := InBus(i).BReady and Enable(i);
			temp(i).ARValid := InBus(i).ARValid and Enable(i);
			temp(i).ARAddr  := InBus(i).ARAddr  ;
			temp(i).ARCache := InBus(i).ARCache ;
			temp(i).ARProt  := InBus(i).ARProt  ;
			temp(i).ARID    := InBus(i).ARID    ;
			temp(i).ARLen   := InBus(i).ARLen   ;
			temp(i).ARSize  := InBus(i).ARSize  ;
			temp(i).ARBurst := InBus(i).ARBurst ;
			temp(i).ARLock  := InBus(i).ARLock  ;
			temp(i).ARQOS   := InBus(i).ARQOS   ;
			temp(i).ARRegion:= InBus(i).ARRegion;
			temp(i).ARUser  := InBus(i).ARUser  ;
			temp(i).RReady  := InBus(i).RReady and Enable(i);
		end loop;
		return temp;
	end function;
	
	function AddressTranslate(InBus : T_AXI4_Bus_M2S; Offset : signed) return T_AXI4_Bus_M2S is
		variable temp : InBus'subtype;
	begin
		assert Offset'length = InBus.AWAddr'length report "PoC.AXI4_Full.AddressTranslate: Length of Offeset-Bits and Address-Bits is no equal!" severity failure;
		
		temp.AWID    := InBus.AWID    ;
		temp.AWAddr  := std_logic_vector(unsigned(InBus.AWAddr) + unsigned(std_logic_vector(Offset)));
		temp.AWLen   := InBus.AWLen   ;
		temp.AWSize  := InBus.AWSize  ;
		temp.AWBurst := InBus.AWBurst ;
		temp.AWLock  := InBus.AWLock  ;
		temp.AWQOS   := InBus.AWQOS   ;
		temp.AWRegion:= InBus.AWRegion;
		temp.AWUser  := InBus.AWUser  ;
		temp.AWValid := InBus.AWValid;
		temp.AWCache := InBus.AWCache ;
		temp.AWProt  := InBus.AWProt  ;
		temp.WValid  := InBus.WValid;
		temp.WLast   := InBus.WLast   ;
		temp.WUser   := InBus.WUser   ;
		temp.WData   := InBus.WData   ;
		temp.WStrb   := InBus.WStrb   ;
		temp.BReady  := InBus.BReady;
		temp.ARValid := InBus.ARValid;
		temp.ARAddr  := std_logic_vector(unsigned(InBus.ARAddr) + unsigned(std_logic_vector(Offset)));
		temp.ARCache := InBus.ARCache ;
		temp.ARProt  := InBus.ARProt  ;
		temp.ARID    := InBus.ARID    ;
		temp.ARLen   := InBus.ARLen   ;
		temp.ARSize  := InBus.ARSize  ;
		temp.ARBurst := InBus.ARBurst ;
		temp.ARLock  := InBus.ARLock  ;
		temp.ARQOS   := InBus.ARQOS   ;
		temp.ARRegion:= InBus.ARRegion;
		temp.ARUser  := InBus.ARUser  ;
		temp.RReady  := InBus.RReady;
		return temp;
	end function;
	
	function BlockTransaction(InBus : T_AXI4_Bus_S2M;        Enable : std_logic) return T_AXI4_Bus_S2M is
		variable temp : InBus'subtype;
	begin
		temp.AWReady:= InBus.AWReady and Enable;
		temp.WReady := InBus.WReady and Enable;
		temp.BValid := InBus.BValid and Enable;
		temp.BResp  := InBus.BResp  ;
		temp.BID    := InBus.BID    ;
		temp.BUser  := InBus.BUser  ;
		temp.ARReady:= InBus.ARReady and Enable;
		temp.RValid := InBus.RValid and Enable;
		temp.RData  := InBus.RData  ;
		temp.RResp  := InBus.RResp  ;
		temp.RID    := InBus.RID    ;
		temp.RLast  := InBus.RLast  ;
		temp.RUser  := InBus.RUser  ;
		return temp;
	end function;
	
	function BlockTransaction(InBus : T_AXI4_Bus_S2M_VECTOR; Enable : std_logic_vector) return T_AXI4_Bus_S2M_VECTOR is
		variable temp : InBus'subtype;
	begin
		for i in InBus'range loop
			temp(i).AWReady:= InBus(i).AWReady and Enable(i);
			temp(i).WReady := InBus(i).WReady and Enable(i);
			temp(i).BValid := InBus(i).BValid and Enable(i);
			temp(i).BResp  := InBus(i).BResp  ;
			temp(i).BID    := InBus(i).BID    ;
			temp(i).BUser  := InBus(i).BUser  ;
			temp(i).ARReady:= InBus(i).ARReady and Enable(i);
			temp(i).RValid := InBus(i).RValid and Enable(i);
			temp(i).RData  := InBus(i).RData  ;
			temp(i).RResp  := InBus(i).RResp  ;
			temp(i).RID    := InBus(i).RID    ;
			temp(i).RLast  := InBus(i).RLast  ;
			temp(i).RUser  := InBus(i).RUser  ;
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
			BID(ite(IDBits = 0,1,IDBits) - 1 downto 0), RID(ite(IDBits = 0,1,IDBits) - 1 downto 0),
			BUser(ite(UserBits = 0,1,UserBits) - 1 downto 0), RUser(ite(UserBits = 0,1,UserBits) - 1 downto 0),
			RData(DataBits - 1 downto 0)
		) := (
			AWReady => Value,
			WReady  => Value,
			BValid  => Value,
			BResp   => (others => Value),
			BID     => (ite(IDBits = 0,1,IDBits) - 1 downto 0 => Value),
			BUser   => (ite(UserBits = 0,1,UserBits) - 1 downto 0 => Value),
			ARReady => Value,
			RValid  => Value,
			RData   => (DataBits - 1 downto 0 => Value),
			RResp   => (others => Value),
			RID     => (ite(IDBits = 0,1,IDBits) - 1 downto 0 => Value),
			RLast   => Value,
			RUser   => (ite(UserBits = 0,1,UserBits) - 1 downto 0 => Value)
		);
	begin
		return var;
	end function;
	
	function Initialize_AXI4_Bus_M2S(AddressBits : natural; DataBits : natural; UserBits : natural := 0; IDBits : natural := 0; Value : std_logic := 'Z') return T_AXI4_Bus_M2S is
		variable var : T_AXI4_Bus_M2S(
			AWID(ite(IDBits = 0,1,IDBits) - 1 downto 0), ARID(ite(IDBits = 0,1,IDBits) - 1 downto 0),
			AWUser(ite(UserBits = 0,1,UserBits) - 1 downto 0), ARUser(ite(UserBits = 0,1,UserBits) - 1 downto 0), WUser(ite(UserBits = 0,1,UserBits) - 1 downto 0),
			WData(DataBits - 1 downto 0), WStrb((DataBits / 8) - 1 downto 0),
			AWAddr(AddressBits-1 downto 0), ARAddr(AddressBits - 1 downto 0)
		) := (
			AWValid => Value,
			AWCache => (others => Value),
			AWAddr  => (AddressBits-1 downto 0 => Value), 
			AWProt  => (others => Value),
			AWID    => (ite(IDBits = 0,1,IDBits)-1 downto 0 => Value), 
			AWLen   => (others => Value),
			AWSize  => (others => Value),
			AWBurst => (others => Value),
			AWLock  => (others => Value),
			AWQOS   => (others => Value),
			AWRegion=> (others => Value),
			AWUser  => (ite(UserBits = 0,1,UserBits)-1 downto 0 => Value),
			WValid  => Value,
			WData   => (DataBits - 1 downto 0 => Value),
			WStrb   => ((DataBits / 8) - 1 downto 0 => Value),
			WLast   => Value,
			WUser   => (ite(UserBits = 0,1,UserBits) - 1 downto 0 => Value),
			BReady  => Value,
			ARValid => Value,
			ARCache => (others => Value),
			ARAddr  => (AddressBits - 1 downto 0 => Value),
			ARProt  => (others => Value),
			ARID    => (ite(IDBits = 0,1,IDBits) - 1 downto 0 => Value),
			ARLen   => (others => Value),
			ARSize  => (others => Value),
			ARBurst => (others => Value),
			ARLock  => (others => Value),
			ARQOS   => (others => Value),
			ARRegion=> (others => Value),
			ARUser  => (ite(UserBits = 0,1,UserBits) - 1 downto 0 => Value),
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
