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
		Number_of_Offsets     : positive := 8;
		Offset_Bits           : positive := 32;
		Buffer_Mask           : std_logic_vector := (63 downto 0 => x"0000000F00000000");
		Interface_Mask        : std_logic_vector := (63 downto 0 => x"00000FF000000000")
	);
	port ( 
		Clock                 : in  std_logic;
		Reset                 : in  std_logic;
									        
		In_AXI4_M2S           : in  T_AXI4_Bus_M2S;--AXI4_A64_D128.SIZED_M2S;--
		In_AXI4_S2M           : out T_AXI4_Bus_S2M;--AXI4_A64_D128.SIZED_S2M;--
		Out_AXI4_M2S          : out T_AXI4_Bus_M2S;--AXI4_A64_D128.SIZED_M2S;--
		Out_AXI4_S2M          : in  T_AXI4_Bus_S2M;--AXI4_A64_D128.SIZED_S2M;--
		
		Offset                : in  T_SLSV(0 to (Number_of_Interfaces * Number_of_Offsets) -1)(Offset_Bits -1 downto 0);
		
		Offset_Pos            : out T_SLUV(0 to Number_of_Interfaces -1)(log2ceilnz(Number_of_Offsets) -1 downto 0);
		Config_Error          : out std_logic;
		Access_Error_r        : out std_logic;
		Access_Error_w        : out std_logic
	);
end entity;

architecture rtl of AXI4_Address_Translate is
	attribute DONT_TOUCH : string;
	
	constant Adder_Bits : positive := lssb_idx(Buffer_Mask or Interface_Mask);
	constant IF_high    : positive := mssb_idx(Interface_Mask);
	constant IF_low     : positive := lssb_idx(Interface_Mask);
	
	signal Match_IF     : std_logic_vector(0 to Number_of_Interfaces -1);
	signal address      : T_SLUV(0 to Number_of_Interfaces -1)(Offset_Bits -1 downto 0);
	
	signal Is_AW        : std_logic;
--	attribute DONT_TOUCH of Match_IF: signal is "TRUE";
--	attribute DONT_TOUCH of address: signal is "TRUE";
--	attribute DONT_TOUCH of Is_AW: signal is "TRUE";
begin
	Is_AW    <= In_AXI4_M2S.AWValid and Out_AXI4_S2M.AWReady;
	
	--Write Port Signals
	Out_AXI4_M2S.AWValid     <= In_AXI4_M2S.AWValid ;
	Out_AXI4_M2S.AWAddr      <= resize(std_logic_vector(address(lssb_idx(Match_IF))), Out_AXI4_M2S.AWAddr'length);
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
		signal Offset_i                : T_SLSV(0 to Number_of_Offsets -1)(Offset_Bits -1 downto 0);
		signal position                : unsigned(log2ceilnz(Number_of_Offsets) -1 downto 0) := (others => '0');
	begin
		assert false report "IF_high = " & integer'image(IF_high) & "; IF_low = " & integer'image(IF_low) severity warning;
		Match_IF(i)   <= '1' when unsigned(In_AXI4_M2S.AWAddr(IF_high downto IF_low)) = to_unsigned(i, IF_high - IF_low +1) else '0';
		Offset_Pos(i) <= position;
		Offset_i      <= Offset((i * Number_of_Offsets) to ((i + 1) * Number_of_Offsets) -1);
		address(i)      <= unsigned(In_AXI4_M2S.AWAddr(Offset_Bits -1 downto 0)) + unsigned(std_logic_vector(Offset_i(to_integer(position))));

		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					position <= (others => '0');
				else
					if (Match_IF(i) = '1') and (Is_AW = '1') then
						if position < Number_of_Offsets -1 then
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
