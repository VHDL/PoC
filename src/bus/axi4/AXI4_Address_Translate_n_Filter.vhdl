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

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.axi4_full.all;
use     work.utils.all;
use     work.vectors.all;


entity AXI4_Address_Translate_n_Filter is
	Generic (
		Number_of_Spaces : positive := 1;
		Address_Bits     : positive := 32;
		Data_Bits        : positive := 32;
		ID_Bits          : positive := 1;
		User_Bits        : positive := 1
	);
	port ( 
		Clock          : in  std_logic;
		Reset          : in  std_logic;
									 
		In_AXI4_M2S    : in  T_AXI4_Bus_M2S;
		In_AXI4_S2M    : out T_AXI4_Bus_S2M;
		Out_AXI4_M2S   : out T_AXI4_Bus_M2S;
		Out_AXI4_S2M   : in  T_AXI4_Bus_S2M;
									 
		Base_address   : in  T_SLUV(0 to Number_of_Spaces -1)(Address_Bits -1 downto 0);
		Length_Bits    : in  T_SLUV(0 to Number_of_Spaces -1)(log2ceilnz(Address_Bits) -1 downto 0);
		Offset         : in  T_SLSV(0 to Number_of_Spaces -1)(Address_Bits -1 downto 0);
									 
		Config_Error   : out std_logic;
		Access_Error_r : out std_logic;
		Access_Error_w : out std_logic
	);
end entity;

architecture rtl of AXI4_Address_Translate_n_Filter is
	type T_State is (Idle, Data, Response);
	signal wState     : T_State := Idle;
	signal nxt_wState : T_State;
	signal rState     : T_State := Idle;
	signal nxt_rState : T_State;
	
	signal in_Range_w_v     : std_logic_vector(0 to Number_of_Spaces -1);
	signal in_Range_r_v     : std_logic_vector(0 to Number_of_Spaces -1);
--	signal over_Range_w_v     : std_logic_vector(0 to Number_of_Spaces -1);
--	signal over_Range_r_v     : std_logic_vector(0 to Number_of_Spaces -1);
	signal Config_Error_v : std_logic_vector(0 to Number_of_Spaces -1);
	
--	signal Block_AW : std_logic;
--	signal Block_W  : std_logic;
--	signal Enable_AW : std_logic;
--	signal Enable_W  : std_logic;
	
	signal save_write_index      : std_logic;
	signal save_read_index       : std_logic;
	signal Current_Write_index_d : std_logic_vector(0 to Number_of_Spaces -1) := (others => '0');
	signal Current_Write_index   : std_logic_vector(0 to Number_of_Spaces -1);
	signal Current_Read_index_d  : std_logic_vector(0 to Number_of_Spaces -1) := (others => '0');
	signal Current_Read_index    : std_logic_vector(0 to Number_of_Spaces -1);

begin
	--Write Port Signals
	Out_AXI4_M2S.AWID        <= In_AXI4_M2S.AWID    ;
	Out_AXI4_M2S.AWAddr      <= std_logic_vector(unsigned(In_AXI4_M2S.AWAddr) + unsigned(std_logic_vector(Offset(lssb_idx(Current_Write_index)))));
	Out_AXI4_M2S.AWLen       <= In_AXI4_M2S.AWLen   ;
	Out_AXI4_M2S.AWSize      <= In_AXI4_M2S.AWSize  ;
	Out_AXI4_M2S.AWBurst     <= In_AXI4_M2S.AWBurst ;
	Out_AXI4_M2S.AWLock      <= In_AXI4_M2S.AWLock  ;
	Out_AXI4_M2S.AWQOS       <= In_AXI4_M2S.AWQOS   ;
	Out_AXI4_M2S.AWRegion    <= In_AXI4_M2S.AWRegion;
	Out_AXI4_M2S.AWUser      <= In_AXI4_M2S.AWUser  ;
	Out_AXI4_M2S.AWCache     <= In_AXI4_M2S.AWCache ;
	Out_AXI4_M2S.AWProt      <= In_AXI4_M2S.AWProt  ;
	Out_AXI4_M2S.WUser       <= In_AXI4_M2S.WUser   ;
	Out_AXI4_M2S.WData       <= In_AXI4_M2S.WData   ;
	Out_AXI4_M2S.WStrb       <= In_AXI4_M2S.WStrb   ;
	
	In_AXI4_S2M.BID         <= Out_AXI4_S2M.BID    ;
	In_AXI4_S2M.BUser       <= Out_AXI4_S2M.BUser  ;
	
	--Read Port Signals
	Out_AXI4_M2S.ARAddr     <= std_logic_vector(unsigned(In_AXI4_M2S.ARAddr) + unsigned(std_logic_vector(Offset(lssb_idx(Current_Read_index)))));
	Out_AXI4_M2S.ARCache    <= In_AXI4_M2S.ARCache ;
	Out_AXI4_M2S.ARProt     <= In_AXI4_M2S.ARProt  ;
	Out_AXI4_M2S.ARID       <= In_AXI4_M2S.ARID    ;
	Out_AXI4_M2S.ARLen      <= In_AXI4_M2S.ARLen   ;
	Out_AXI4_M2S.ARSize     <= In_AXI4_M2S.ARSize  ;
	Out_AXI4_M2S.ARBurst    <= In_AXI4_M2S.ARBurst ;
	Out_AXI4_M2S.ARLock     <= In_AXI4_M2S.ARLock  ;
	Out_AXI4_M2S.ARQOS      <= In_AXI4_M2S.ARQOS   ;
	Out_AXI4_M2S.ARRegion   <= In_AXI4_M2S.ARRegion;
	Out_AXI4_M2S.ARUser     <= In_AXI4_M2S.ARUser  ;
	
	In_AXI4_S2M.RData       <= Out_AXI4_S2M.RData  ;
	In_AXI4_S2M.RID         <= Out_AXI4_S2M.RID    ;
	In_AXI4_S2M.RUser       <= Out_AXI4_S2M.RUser  ;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if Reset = '1' then
				wState <= Idle;
				rState <= Idle;
			else
				wState <= nxt_wState;
				rState <= nxt_rState;
			end if;
		end if;
	end process;
	
	Current_Write_index_d <= in_Range_w_v when rising_edge(Clock) and save_write_index = '1';
	Current_Write_index   <= in_Range_w_v when In_AXI4_M2S.AWValid = '1' else Current_Write_index_d;
	Current_Read_index_d  <= in_Range_r_v when rising_edge(Clock) and save_read_index = '1';
	Current_Read_index    <= in_Range_r_v when In_AXI4_M2S.ARValid = '1' else Current_Read_index_d;
	
	Access_Error_w <= to_sl(unsigned(Current_Write_index) = 0) when wState /= Idle else '0';
	Access_Error_r <= to_sl(unsigned(Current_Read_index) = 0)  when rState /= Idle else '0';
	
	process(wState, In_AXI4_M2S, Out_AXI4_S2M, in_Range_w_v)
	begin
		nxt_wState    <= wState;
		save_write_index <= '0';
		
		Out_AXI4_M2S.AWValid     <= In_AXI4_M2S.AWValid;
		Out_AXI4_M2S.WValid      <= In_AXI4_M2S.WValid;
		Out_AXI4_M2S.WLast       <= In_AXI4_M2S.WLast;
		Out_AXI4_M2S.BReady      <= In_AXI4_M2S.BReady;
		
		In_AXI4_S2M.AWReady     <= Out_AXI4_S2M.AWReady;
		In_AXI4_S2M.WReady      <= Out_AXI4_S2M.WReady;
		In_AXI4_S2M.BValid      <= Out_AXI4_S2M.BValid ;
		In_AXI4_S2M.BResp       <= Out_AXI4_S2M.BResp  ;
		
		case wState is
			when Idle =>
				if In_AXI4_M2S.AWValid = '1' and Out_AXI4_S2M.AWReady = '1' then
					save_write_index <= '1';
					if (In_AXI4_M2S.WValid and In_AXI4_M2S.WLast and Out_AXI4_S2M.WReady) = '1' then
						if (Out_AXI4_S2M.BValid and In_AXI4_M2S.BReady) = '1' then
							nxt_wState <= Idle;
						else
							nxt_wState <= Response;
						end if;
					else
						nxt_wState <= Data;
					end if;
				end if;
			when Data =>
				In_AXI4_S2M.AWReady  <= '0';
				Out_AXI4_M2S.AWValid <= '0';
				if (In_AXI4_M2S.WValid and In_AXI4_M2S.WLast and Out_AXI4_S2M.WReady) = '1' then
					if (Out_AXI4_S2M.BValid and In_AXI4_M2S.BReady) = '1' then
						nxt_wState <= Idle;
					else
						nxt_wState <= Response;
					end if;
				end if;
			when Response =>
				In_AXI4_S2M.AWReady  <= '0';
				Out_AXI4_M2S.AWValid <= '0';
				Out_AXI4_M2S.WValid  <= '0';
				In_AXI4_S2M.WReady   <= '0';
				if (Out_AXI4_S2M.BValid and In_AXI4_M2S.BReady) = '1' then
						nxt_wState <= Idle;
				end if;
--			when Discard =>
--				In_AXI4_S2M.AWReady <= '1';
--				In_AXI4_S2M.WReady  <= '1';
--				Access_Error_w      <= '1';
		end case;
	end process;
	
	process(In_AXI4_M2S, rState)
	begin
		nxt_rState    <= rState;
		save_read_index <= '0';
		
		Out_AXI4_M2S.ARValid    <= In_AXI4_M2S.ARValid ;
		Out_AXI4_M2S.RReady     <= In_AXI4_M2S.RReady  ;
		In_AXI4_S2M.RLast       <= Out_AXI4_S2M.RLast  ;
		In_AXI4_S2M.ARReady     <= Out_AXI4_S2M.ARReady;
		In_AXI4_S2M.RValid      <= Out_AXI4_S2M.RValid ;
		In_AXI4_S2M.RResp       <= Out_AXI4_S2M.RResp  ;
		
		case rState is
			when Idle =>
				if In_AXI4_M2S.ARValid = '1' and Out_AXI4_S2M.ARReady = '1' then
					save_read_index <= '1';
					if (Out_AXI4_S2M.RValid and Out_AXI4_S2M.RLast and In_AXI4_M2S.RReady) = '1' then
						nxt_rState <= Idle;
					else
						nxt_rState <= Data;
					end if;
				end if;
			when Data =>
				In_AXI4_S2M.ARReady  <= '0';
				Out_AXI4_M2S.ARValid <= '0';
				if (Out_AXI4_S2M.RValid and Out_AXI4_S2M.RLast and In_AXI4_M2S.RReady) = '1' then
					nxt_rState <= Idle;
				end if;
			when others =>
				nxt_rState <= Idle;
--			when Response =>
--				In_AXI4_S2M.AWReady  <= '0';
--				Out_AXI4_M2S.AWValid <= '0';
--				Out_AXI4_M2S.WValid  <= '0';
--				In_AXI4_S2M.WReady   <= '0';
--				if (Out_AXI4_S2M.BValid and In_AXI4_M2S.BReady) = '1' then
--						nxt_rState <= Idle;
--				end if;
--			when Discard =>
--				In_AXI4_S2M.AWReady <= '1';
--				In_AXI4_S2M.WReady  <= '1';
--				Access_Error_w      <= '1';
		end case;
		
	end process;
	
	
	
	range_gen : for i in 0 to Number_of_Spaces -1 generate
		function mask(in_vec : std_logic_vector; len : unsigned) return std_logic_vector is
			variable temp : std_logic_vector(in_vec'range);
		begin
			for i in temp'range loop
				if i < to_integer(len) then
					temp(i) := '0';
				else
					temp(i) := '1';
				end if;
			end loop;
			return in_vec and temp;
		end function;
		
		signal Base_address_i : unsigned(Base_address(0)'range);
		signal Length_Bits_i  : unsigned(Length_Bits(0)'range);
	begin
		Base_address_i <= Base_address(i);
		Length_Bits_i  <= Length_Bits(i);
		
		Config_Error_v(i) <= '0' when Base_address_i(to_integer(Length_Bits_i -1) downto 0) = 0 else '1';

		in_Range_w_v(i) <= '1' when mask(In_AXI4_M2S.AWAddr,Length_Bits_i) = std_logic_vector(Base_address_i) else '0';
--		over_Range_w_v(i) <= '1' when mask(In_AXI4_M2S.AWAddr,Length_Bits_i) = std_logic_vector(Base_address_i) else '0';
		in_Range_r_v(i) <= '1' when mask(In_AXI4_M2S.ARAddr,Length_Bits_i) = std_logic_vector(Base_address_i) else '0';
	end generate;


end architecture;
