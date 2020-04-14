-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	A slave-side bus Sink module for AXI4 (full).
--
-- Description:
-- -------------------------------------
-- This entity is a bus sink module for AXI4 (full) that represents a
-- dummy slave. This slave collects all data on write port and sends 
-- out dummy data on read port.
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
use     work.vectors.all;
use     work.axi4_Full.all;


entity AXI4_Sink_Slave is
	port ( 
    Clock     : in std_logic;
    Reset     : in std_logic;
		AXI4_M2S  : in  T_AXI4_Bus_M2S;
		AXI4_S2M  : out T_AXI4_Bus_S2M
	);
end entity;


architecture rtl of AXI4_Sink_Slave is
	constant AddressBits  : natural := AXI4_M2S.AWAddr'length;
	constant IDBits       : natural := AXI4_M2S.AWID'length;
	constant UserBits     : natural := AXI4_M2S.AWUser'length;
	constant DataBits     : natural := AXI4_M2S.WData'length;
  constant WData_Pos    : natural := 0;
  constant WBurst_Pos   : natural := 1;
  constant RData_Pos    : natural := 2;
  constant RBurst_Pos   : natural := 3;
  constant Split        : T_POSVEC := (
    WData_Pos   => DataBits / 4, 
    WBurst_Pos  => DataBits / 4, 
    RData_Pos   => DataBits / 4, 
    RBurst_Pos  => DataBits - ( 3* (DataBits / 4))
  );

	signal AXI4_M2S_i     : T_AXI4_Bus_M2S (
			AWID(IDBits - 1 downto 0), ARID(IDBits - 1 downto 0),
			AWUser(UserBits - 1 downto 0), ARUser(UserBits - 1 downto 0), WUser(UserBits - 1 downto 0),
			WData(DataBits - 1 downto 0), WStrb((DataBits / 8) - 1 downto 0),
			AWAddr(AddressBits-1 downto 0), ARAddr(AddressBits - 1 downto 0)
		);
	signal AXI4_S2M_i     : T_AXI4_Bus_S2M (
			BID(IDBits - 1 downto 0), RID(IDBits - 1 downto 0),
			BUser(UserBits - 1 downto 0), RUser(UserBits - 1 downto 0),
			RData(DataBits - 1 downto 0)
		);
    
  signal WData_inc      : std_logic;
  signal WBurst_inc     : std_logic;
  signal WData_Count    : unsigned(Split(WData_Pos) -1 downto 0)  := (others => '0');
  signal WBurst_Count   : unsigned(Split(WBurst_Pos) -1 downto 0) := (others => '0');
  signal RData_inc      : std_logic;
  signal RBurst_inc     : std_logic;
  signal RData_Count    : unsigned(Split(RData_Pos) -1 downto 0)  := (others => '0');
  signal RBurst_Count   : unsigned(Split(RBurst_Pos) -1 downto 0) := (others => '0');
  
  signal WTransf_Inc    : std_logic;
  signal WTransf_Rst    : std_logic;
  signal WTransf_count  : unsigned(7 downto 0)                     := (others => '0');
  signal RTransf_Inc    : std_logic;
  signal RTransf_Rst    : std_logic;
  signal RTransf_count  : unsigned(7 downto 0)                     := (others => '0');
  
  
  type T_wstate is (Idle, Write_data, Write_resp_OK, Write_resp_Error);
  type T_rstate is (Idle, Read_send, Read_resp);
  
  signal wstate         : T_wstate := Idle;
  signal rstate         : T_rstate := Idle;
  signal nxt_wstate     : T_wstate;
  signal nxt_rstate     : T_rstate;
  
  signal AWLen_d        : std_logic_vector(7 downto 0); 
  signal AWLen          : std_logic_vector(7 downto 0); 
  signal ARLen_d        : std_logic_vector(7 downto 0); 
  signal ARLen          : std_logic_vector(7 downto 0); 
  signal AWID_d         : std_logic_vector(IDBits-1 downto 0); 
  signal AWID           : std_logic_vector(IDBits-1 downto 0); 
  signal ARID_d         : std_logic_vector(IDBits-1 downto 0); 
  signal ARID           : std_logic_vector(IDBits-1 downto 0); 
  
  signal Is_WriteData   : std_logic;
  signal Is_ReadData    : std_logic;
  
begin
  AXI4_M2S_i <= AXI4_M2S;
  AXI4_S2M   <= AXI4_S2M_i;  
  
  AXI4_S2M_i.RUser   <= (others => '0');
  AXI4_S2M_i.BUser   <= (others => '0');
  
  AXI4_S2M_i.RData(high(Split,WBurst_Pos) downto low(Split,WBurst_Pos)) <= std_logic_vector(WBurst_Count);
  AXI4_S2M_i.RData(high(Split,WData_Pos)  downto low(Split,WData_Pos))  <= std_logic_vector(WData_Count);
  AXI4_S2M_i.RData(high(Split,RBurst_Pos) downto low(Split,RBurst_Pos)) <= std_logic_vector(RBurst_Count);
  AXI4_S2M_i.RData(high(Split,RData_Pos)  downto low(Split,RData_Pos))  <= std_logic_vector(RData_Count);
  
  WData_inc   <= Is_WriteData and AXI4_S2M_i.WReady and AXI4_M2S_i.WValid;
  WTransf_Inc <= WData_inc;
  WBurst_inc  <= Is_WriteData and AXI4_S2M_i.WReady and AXI4_M2S_i.WValid and AXI4_M2S_i.WLast;
  WTransf_Rst <= WBurst_inc;-- when rising_edge(Clock);
  RData_inc   <= Is_ReadData  and AXI4_S2M_i.RValid and AXI4_M2S_i.RReady;
  RTransf_Inc <= RData_inc;
  RBurst_inc  <= Is_ReadData  and AXI4_S2M_i.RValid and AXI4_M2S_i.RReady and AXI4_S2M_i.RLast;
  RTransf_Rst <= RBurst_inc;-- when rising_edge(Clock);
  
    
  AWLen_d <= AXI4_M2S.AWLen when rising_edge(Clock) and (AXI4_M2S_i.AWValid and AXI4_S2M_i.AWReady) = '1';
  AWLen   <= AXI4_M2S.AWLen when (AXI4_M2S_i.AWValid and AXI4_S2M_i.AWReady) = '1' else AWLen_d;
  ARLen_d <= AXI4_M2S.ARLen when rising_edge(Clock) and (AXI4_M2S_i.ARValid and AXI4_S2M_i.ARReady) = '1';
  ARLen   <= AXI4_M2S.ARLen when (AXI4_M2S_i.ARValid and AXI4_S2M_i.ARReady) = '1' else ARLen_d;
  
  AXI4_S2M_i.RLast <= '1' when unsigned(ARLen) = RTransf_count else '0';
  
  AWID_d  <= AXI4_M2S.AWID when rising_edge(Clock) and (AXI4_M2S_i.AWValid and AXI4_S2M_i.AWReady) = '1';
  AWID    <= AXI4_M2S.AWID when (AXI4_M2S_i.AWValid and AXI4_S2M_i.AWReady) = '1' else AWID_d;
  ARID_d  <= AXI4_M2S.ARID when rising_edge(Clock) and (AXI4_M2S_i.ARValid and AXI4_S2M_i.ARReady) = '1';
  ARID    <= AXI4_M2S.ARID when (AXI4_M2S_i.ARValid and AXI4_S2M_i.ARReady) = '1' else ARID_d;
  
  
  AXI4_S2M_i.BID <= AWID;
  AXI4_S2M_i.RID <= ARID;
  
  Is_WriteData <= '1' when wState = Write_data else '0';
  Is_ReadData  <= '1' when rState = Read_send  else '0';
  
  AXI4_S2M_i.WReady  <= Is_WriteData;-- and AXI4_M2S_i.WValid;
  AXI4_S2M_i.RValid  <= Is_ReadData;
  
  
  write_proc : process(wState, AXI4_M2S_i, WTransf_count, AWLen, AXI4_S2M_i)
  begin
    nxt_wstate             <= wState;
    
    AXI4_S2M_i.AWReady     <= '0';
    AXI4_S2M_i.BResp       <= C_AXI4_RESPONSE_OKAY;
    AXI4_S2M_i.BValid      <= '0';

    
    case wState is
      when Idle =>
        if AXI4_M2S_i.AWValid = '1' then
          AXI4_S2M_i.AWReady  <= '1';
          nxt_wstate          <= Write_data;
        end if;
        
      when Write_data =>
        if (WTransf_count = unsigned(AWLen)) and (AXI4_S2M_i.WReady and AXI4_M2S_i.WValid and AXI4_M2S_i.WLast) = '1' then
          nxt_wstate          <= Write_resp_OK;
        elsif (AXI4_S2M_i.WReady and AXI4_M2S_i.WValid and AXI4_M2S_i.WLast) = '1' then
          nxt_wstate          <= Write_resp_Error;
        end if;
        
      when Write_resp_OK =>
        AXI4_S2M_i.BValid     <= '1';
        if AXI4_M2S_i.BReady  = '1' then
          nxt_wstate          <= Idle;
        end if;
        
      when Write_resp_Error =>
        AXI4_S2M_i.BValid     <= '1';
        AXI4_S2M_i.BResp      <= C_AXI4_RESPONSE_DECODE_ERROR;
        if AXI4_M2S_i.BReady  = '1' then
          nxt_wstate          <= Idle;
        end if;
        
      when others =>  nxt_wstate  <= Idle; 
        
    end case;
  end process;  
  
  read_proc : process(rState, AXI4_M2S_i, AXI4_S2M_i)
  begin
    nxt_rstate             <= rState;
    AXI4_S2M_i.ARReady     <= '0';
    AXI4_S2M_i.RResp       <= C_AXI4_RESPONSE_OKAY;
    
    case rState is 
      when Idle => 
        if AXI4_M2S_i.ARValid = '1' then
          AXI4_S2M_i.ARReady     <= '1';
          nxt_rstate             <= Read_send;
        end if;
      
      when Read_send =>
        if (AXI4_S2M_i.RLast and AXI4_S2M_i.RValid and AXI4_M2S_i.RReady) = '1' then
          nxt_rstate             <= Idle;
        end if;
      
      when others =>  nxt_rstate  <= Idle;
    end case;
  end process;
  
  process(Clock)
  begin
    if rising_edge(Clock) then
      if Reset = '1' then
        wState <= Idle;
        rState <= Idle;
      else
        wState <= nxt_wstate;
        rState <= nxt_rstate;
      end if;
    end if;
  end process;

  process(Clock)
  begin
    if rising_edge(Clock) then
      if Reset = '1' then
        WData_Count     <= (others => '0');
        WBurst_Count    <= (others => '0');
        RData_Count     <= (others => '0');
        RBurst_Count    <= (others => '0');
        WTransf_count   <= (others => '0');
        RTransf_count   <= (others => '0');
      else
        if WData_inc = '1' then
          WData_Count <= WData_Count +1;
        end if;
        if WBurst_inc = '1' then
          WBurst_Count <= WBurst_Count +1;
        end if;
        if RData_inc = '1' then
          RData_Count <= RData_Count +1;
        end if;
        if RBurst_inc = '1' then
          RBurst_Count <= RBurst_Count +1;
        end if;
        if WTransf_Rst = '1' then
          WTransf_count <= (others => '0');
        elsif WTransf_Inc = '1' then
          WTransf_count <= WTransf_count +1;
        end if;
        if RTransf_Rst = '1' then
          RTransf_count <= (others => '0');
        elsif RTransf_Inc = '1' then
          RTransf_count <= RTransf_count +1;
        end if;
      end if;
    end if;
  end process;

end architecture;
