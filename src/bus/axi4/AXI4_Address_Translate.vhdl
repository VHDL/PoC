-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--                  
--
-- Entity:				 	
--
-- Description:
-- -------------------------------------
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

library PoC;
package AXI4_A64_D128 is
new PoC.AXI4Full_Sized
	generic map (
		ADDRESS_BITS => 64,
		DATA_BITS    => 16,
		USER_BITS    => 1,
		ID_BITS      => 1
	);


library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.axi4_full.all;
use     work.utils.all;
use     work.vectors.all;

use     work.AXI4_A64_D128;

entity AXI4_Address_Translate is
	Generic (
		Number_of_Interfaces  : positive := 20;
		Max_Offsets           : positive := 8;
		Offset_Bits           : positive := 32;
		Buffer_Mask           : std_logic_vector;
		Interface_Mask        : std_logic_vector
	);
	port ( 
		Clock                 : in  std_logic;
		Reset                 : in  std_logic;
									        
		In_AXI4_M2S           : in  T_AXI4_Bus_M2S;--AXI4_A64_D128.SIZED_M2S;--
		In_AXI4_S2M           : out T_AXI4_Bus_S2M;--AXI4_A64_D128.SIZED_S2M;--
		Out_AXI4_M2S          : out T_AXI4_Bus_M2S;--AXI4_A64_D128.SIZED_M2S;--
		Out_AXI4_S2M          : in  T_AXI4_Bus_S2M;--AXI4_A64_D128.SIZED_S2M;--
		
		Number_of_Offsets     : in  unsigned(log2ceilnz(Max_Offsets) -1 downto 0);
		Offset                : in  T_SLUV(0 to (Number_of_Interfaces * Max_Offsets) -1)(Offset_Bits -1 downto 0);
		
		Offset_Pos            : out T_SLUV(0 to Number_of_Interfaces -1)(log2ceilnz(Max_Offsets) -1 downto 0);
		Offset_Inc            : out std_logic_vector(0 to Number_of_Interfaces -1);
		Config_Error          : out std_logic;
		Access_Error_r        : out std_logic;
		Access_Error_w        : out std_logic
	);
end entity;

architecture rtl of AXI4_Address_Translate is
	attribute MARK_DEBUG    : string;
	
	constant Mask_Bits      : positive := lssb_idx(Buffer_Mask or Interface_Mask);
	constant Address_Bits   : positive := ite(Mask_Bits < Offset_Bits, Mask_Bits, Offset_Bits);
	constant Buffer_high    : positive := mssb_idx(Buffer_Mask);
	constant Buffer_low     : positive := lssb_idx(Buffer_Mask);
	constant IF_high        : positive := mssb_idx(Interface_Mask);
	constant IF_low         : positive := lssb_idx(Interface_Mask);
	
--	signal IF_Addres        : std_logic_vector(IF_high - IF_low downto 0);
--	signal IF_Addres_d      : std_logic_vector(IF_high - IF_low downto 0) := (others => '0');
--	signal IF_Addres_fe     : std_logic;
	
	signal Match_IF         : std_logic_vector(0 to Number_of_Interfaces -1);
	signal address          : T_SLUV(0 to Number_of_Interfaces -1)(Offset_Bits downto 0);
	
	alias In_AWAddress_Buffer  : std_logic_vector(Buffer_high -Buffer_low downto 0) is In_AXI4_M2S.AWAddr(Buffer_high downto Buffer_low);
	alias In_AWAddress_IF      : std_logic_vector(IF_high -IF_low downto 0)         is In_AXI4_M2S.AWAddr(IF_high downto IF_low);
	alias In_AWAddress_Data    : std_logic_vector(Address_Bits -1 downto 0)         is In_AXI4_M2S.AWAddr(Address_Bits -1 downto 0);
	alias In_AWValid           : std_logic                                          is In_AXI4_M2S.AWValid;
	alias In_AWReady           : std_logic                                          is In_AXI4_S2M.AWReady;
	
	signal In_AWAddress_Data_d : std_logic_vector(Address_Bits -1 downto 0) := (others => '0');
--	alias Out_AWAddress_Buffer : std_logic_vector(Buffer_high -Buffer_low downto 0) is Out_AXI4_M2S.AWAddr(Buffer_high downto Buffer_low);
--	alias Out_AWAddress_IF     : std_logic_vector(IF_high -IF_low downto 0)         is Out_AXI4_M2S.AWAddr(IF_high downto IF_low);
--	alias Out_AWAddress_Data   : std_logic_vector(Address_Bits -1 downto 0)         is Out_AXI4_M2S.AWAddr(Address_Bits -1 downto 0);
	alias Out_AWValid          : std_logic                                          is Out_AXI4_M2S.AWValid;
	alias Out_AWReady          : std_logic                                          is Out_AXI4_S2M.AWReady;
	
	signal Out_AWValid_d       : std_logic_vector(3 downto 0) := (others => '0');
	signal Is_AW            : std_logic;
	attribute MARK_DEBUG of Match_IF: signal is "TRUE";
--	attribute MARK_DEBUG of address: signal is "TRUE";
--	attribute MARK_DEBUG of Is_AW: signal is "TRUE";
begin
	Is_AW            <= In_AWValid and Out_AWReady;
	
	In_AWAddress_Data_d <= In_AWAddress_Data when rising_edge(Clock);
	Out_AWValid_d    <= Out_AWValid_d(Out_AWValid_d'high -1 downto 0) & In_AWValid when rising_edge(Clock);
--	IF_Addres        <= In_AXI4_M2S.AWAddr(IF_high downto IF_low);
--	IF_Addres_d      <= IF_Addres when rising_edge(Clock) and Is_AW = '1';
--	IF_Addres_fe     <= '1' when IF_Addres /= IF_Addres_d else '0';
	
	
	--Write Port Signals
	Out_AXI4_M2S.AWValid     <= Out_AWValid_d(Out_AWValid_d'high);
	Out_AXI4_M2S.AWAddr      <= resize(std_logic_vector(address(lssb_idx(Match_IF))), Out_AXI4_M2S.AWAddr'length) when rising_edge(Clock);
	Out_AXI4_M2S.AWID        <= In_AXI4_M2S.AWID    ;
	Out_AXI4_M2S.AWLen       <= In_AXI4_M2S.AWLen   ;
	Out_AXI4_M2S.AWSize      <= In_AXI4_M2S.AWSize  ;
	Out_AXI4_M2S.AWBurst     <= In_AXI4_M2S.AWBurst ;
	Out_AXI4_M2S.AWLock      <= In_AXI4_M2S.AWLock  ;
	Out_AXI4_M2S.AWQOS       <= In_AXI4_M2S.AWQOS   ;
	Out_AXI4_M2S.AWRegion    <= In_AXI4_M2S.AWRegion;
	Out_AXI4_M2S.AWUser      <= In_AXI4_M2S.AWUser  ;
	Out_AXI4_M2S.AWCache     <= In_AXI4_M2S.AWCache ;
	Out_AXI4_M2S.AWProt      <= In_AXI4_M2S.AWProt  ;
	Out_AXI4_M2S.WValid      <= In_AXI4_M2S.WValid  ;
	Out_AXI4_M2S.WLast       <= In_AXI4_M2S.WLast   ;
	Out_AXI4_M2S.WUser       <= In_AXI4_M2S.WUser   ;
	Out_AXI4_M2S.WData       <= In_AXI4_M2S.WData   ;
	Out_AXI4_M2S.WStrb       <= In_AXI4_M2S.WStrb   ;
	Out_AXI4_M2S.BReady      <= In_AXI4_M2S.BReady  ;
	
	In_AXI4_S2M.AWReady      <= Out_AXI4_S2M.AWReady;
	In_AXI4_S2M.WReady       <= Out_AXI4_S2M.WReady ;
	In_AXI4_S2M.BValid       <= Out_AXI4_S2M.BValid ;
	In_AXI4_S2M.BResp        <= Out_AXI4_S2M.BResp  ;
	In_AXI4_S2M.BID          <= Out_AXI4_S2M.BID    ;
	In_AXI4_S2M.BUser        <= Out_AXI4_S2M.BUser  ;
	
	--Read Port Signals
	Out_AXI4_M2S.ARValid     <= In_AXI4_M2S.ARValid ;
	Out_AXI4_M2S.ARAddr      <= resize(In_AXI4_M2S.ARAddr, Out_AXI4_M2S.ARAddr'length);
	Out_AXI4_M2S.ARCache     <= In_AXI4_M2S.ARCache ;
	Out_AXI4_M2S.ARProt      <= In_AXI4_M2S.ARProt  ;
	Out_AXI4_M2S.ARID        <= In_AXI4_M2S.ARID    ;
	Out_AXI4_M2S.ARLen       <= In_AXI4_M2S.ARLen   ;
	Out_AXI4_M2S.ARSize      <= In_AXI4_M2S.ARSize  ;
	Out_AXI4_M2S.ARBurst     <= In_AXI4_M2S.ARBurst ;
	Out_AXI4_M2S.ARLock      <= In_AXI4_M2S.ARLock  ;
	Out_AXI4_M2S.ARQOS       <= In_AXI4_M2S.ARQOS   ;
	Out_AXI4_M2S.ARRegion    <= In_AXI4_M2S.ARRegion;
	Out_AXI4_M2S.ARUser      <= In_AXI4_M2S.ARUser  ;
	Out_AXI4_M2S.RReady      <= In_AXI4_M2S.RReady  ;
	
	In_AXI4_S2M.ARReady      <= Out_AXI4_S2M.ARReady;
	In_AXI4_S2M.RLast        <= Out_AXI4_S2M.RLast  ;
	In_AXI4_S2M.RValid       <= Out_AXI4_S2M.RValid ;
	In_AXI4_S2M.RResp        <= Out_AXI4_S2M.RResp  ;
	In_AXI4_S2M.RData        <= Out_AXI4_S2M.RData  ;
	In_AXI4_S2M.RID          <= Out_AXI4_S2M.RID    ;
	In_AXI4_S2M.RUser        <= Out_AXI4_S2M.RUser  ;
	
	Adder_gen : for i in 0 to Number_of_Interfaces -1 generate
		signal Offset_i         : T_SLUV(0 to Max_Offsets -1)(Offset_Bits -1 downto 0);
		signal position         : unsigned(log2ceilnz(Max_Offsets) -1 downto 0) := (others => '0');
		signal Buffer_Addres_d  : std_logic_vector(Buffer_high - Buffer_low downto 0) := (others => '0');
		signal Buffer_Addres_fe : std_logic;
		
		signal Match_IF_i       : std_logic;
		signal Match_IF_d       : std_logic_vector(3 downto 0) := (others => '0');
		
		attribute MARK_DEBUG of position: signal is "TRUE";
		attribute MARK_DEBUG of Buffer_Addres_fe: signal is "TRUE";
	begin
		Match_IF_i   <= '1' when unsigned(In_AWAddress_IF) = to_unsigned(i +1, IF_high - IF_low +1) else '0';
		Match_IF_d   <= Match_IF_d(Match_IF_d'high -1 downto 0) & Match_IF_i when rising_edge(Clock);
		Match_IF(i)  <= Match_IF_d(Match_IF_d'high);
		
		Offset_Pos(i) <= position;
		Offset_i      <= Offset((i * Max_Offsets) to ((i + 1) * Max_Offsets) -1) when rising_edge(Clock);


		address(i)    <= unsigned(resize(In_AWAddress_Data_d, Offset_Bits +1)) + unsigned('0' & std_logic_vector(Offset_i(to_integer(position)))) when rising_edge(Clock) and Match_IF_d(1) = '1';



		Buffer_Addres_d  <= In_AWAddress_Buffer when rising_edge(Clock) and Is_AW = '1' and Match_IF(i) = '1';
		Buffer_Addres_fe <= Match_IF(i) when In_AWAddress_Buffer /= Buffer_Addres_d else '0';

		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					position <= (others => '0');
					Offset_Inc(i) <= '0';
				else
					Offset_Inc(i) <= '0';
					if (Match_IF(i) = '1') and (Is_AW = '1') and (Buffer_Addres_fe = '1') then
						Offset_Inc(i) <= '1';
						if (position < Max_Offsets -1) or (position < Number_of_Offsets -1) then
							position <= position +1;
						else
							position <= (others => '0');
						end if;
					end if;
				end if;
			end if;
		end process;
	end generate;
	
end architecture;
