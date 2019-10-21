-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	Bridge from AXI4Lite to DRP Interface.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
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
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

use			work.utils.all;
use			work.axi4lite.all;
use			work.drp.all;


entity DRP_To_AXI4Lite_Bridge is
	generic (
		DRP_COUNT         : positive                  := 1;
    DRP_ADDR_BITS     : positive                  := 4
  );
	port (
    Clock             : in	std_logic;
    Reset             : in	std_logic;
		-- IN Port
		AXI4Lite_M2S   : in  T_AXI4Lite_Bus_M2S;
		AXI4Lite_S2M   : out T_AXI4Lite_Bus_S2M;
		-- OUT Port
		DRP_M2S       : out T_DRP_Bus_M2S_VECTOR(0 to DRP_COUNT - 1);
		DRP_S2M       : in  T_DRP_Bus_S2M_VECTOR(0 to DRP_COUNT - 1)
	);
end entity;


architecture rtl of DRP_To_AXI4Lite_Bridge is
  constant DRP_DATA_BITS   : positive := 16;
  constant C_COUNT_BITS    : natural  := log2ceil(DRP_COUNT);
  constant C_AXI_ADDR_BITS : natural  := C_COUNT_BITS + DRP_ADDR_BITS + 2;
  
  subtype T_AXI4Lite_constr_M2S is T_AXI4Lite_Bus_M2S(
      AWAddr(C_AXI_ADDR_BITS -1 downto 0), WData(32 -1 downto 0), 
      WStrb((32 /8) -1 downto 0), ARAddr(C_AXI_ADDR_BITS -1 downto 0));
  subtype T_AXI4Lite_constr_S2M is T_AXI4Lite_Bus_S2M(RData(32 -1 downto 0));
  
  subtype T_DRP_constr_M2S is T_DRP_Bus_M2S(
      Address(DRP_ADDR_BITS -1 downto 0), DataIn(DRP_DATA_BITS -1 downto 0));
  subtype T_DRP_constr_S2M is T_DRP_Bus_S2M(DataOut(DRP_DATA_BITS -1 downto 0));
  
  signal AXI4Lite_M2S_i : T_AXI4Lite_constr_M2S := Initialize_AXI4Lite_Bus_M2S(C_AXI_ADDR_BITS, 32);
	signal AXI4Lite_S2M_i : T_AXI4Lite_constr_S2M := Initialize_AXI4Lite_Bus_S2M(C_AXI_ADDR_BITS, 32);
  
  signal DRP_M2S_i : DRP_M2S'subtype;--T_DRP_Bus_M2S_VECTOR(0 to DRP_COUNT - 1) := (0 to DRP_COUNT - 1 => Initialize_DRP_Bus_M2S(DRP_ADDR_BITS, DRP_DATA_BITS));
	signal DRP_S2M_i : DRP_S2M'subtype;--T_DRP_Bus_S2M_VECTOR(0 to DRP_COUNT - 1) := (0 to DRP_COUNT - 1 => Initialize_DRP_Bus_S2M(               DRP_DATA_BITS));

  signal DRP_Enable       : std_logic_vector(0 to DRP_COUNT - 1);
  signal DRP_WriteEnable  : std_logic_vector(0 to DRP_COUNT - 1);
  signal DRP_Address      : unsigned(DRP_ADDR_BITS -1 downto 0)         := (others => '0');
  signal DRP_DataIn       : std_logic_vector(DRP_DATA_BITS -1 downto 0) := (others => '0');
  -- signal DRP_DataOut      : std_logic_vector(DRP_DATA_BITS -1 downto 0) := (others => '0');
  
  type T_State is (idle, read, read_wait, read_error, write, write_wait, write_error);
  signal State     : T_State := idle;
  signal State_nxt : T_State;
begin

  AXI4Lite_M2S_i <= AXI4Lite_M2S;
  AXI4Lite_S2M   <= AXI4Lite_S2M_i;
  
  DRP_M2S       <= DRP_M2S_i;
  DRP_S2M_i     <= DRP_S2M;
  
  process(DRP_Address, DRP_DataIn, DRP_Enable, DRP_WriteEnable)
  begin
    for i in 0 to DRP_COUNT - 1 loop
      DRP_M2S_i(i).Address      <= DRP_Address;
      DRP_M2S_i(i).DataIn       <= DRP_DataIn;
      DRP_M2S_i(i).Enable       <= DRP_Enable(i);
      DRP_M2S_i(i).WriteEnable  <= DRP_WriteEnable(i);
    end loop;
  end process;
  
  process(Clock)
  begin
    if rising_edge(Clock) then
      if Reset = '1' then
        State <= Idle;
      else
        State <= State_nxt;
      end if;
    end if;
  end process;
  
  process(State, AXI4Lite_M2S_i, DRP_S2M_i)
    variable DRP_port : unsigned(C_COUNT_BITS - 1 downto 0) := (others => '0');
  begin
    State_nxt       <= State;
    DRP_Enable      <= (others => '0');
    DRP_WriteEnable <= (others => '0');
    AXI4Lite_S2M_i.AWReady <= '0';
    AXI4Lite_S2M_i.WReady  <= '0';
    AXI4Lite_S2M_i.BValid  <= '0';
    AXI4Lite_S2M_i.BResp   <= C_AXI4_RESPONSE_OKAY;
    AXI4Lite_S2M_i.RResp   <= C_AXI4_RESPONSE_OKAY;
    
    AXI4Lite_S2M_i.ARReady <= '0';
	AXI4Lite_S2M_i.RValid  <= '0';
	
    case State is
      when Idle =>
        if (AXI4Lite_M2S_i.AWValid and AXI4Lite_M2S_i.WValid) = '1' then
          DRP_DataIn  <= resize(AXI4Lite_M2S_i.WData, DRP_DataIn'length);
          DRP_Address <= unsigned(AXI4Lite_M2S_i.AWAddr(DRP_ADDR_BITS + 1 downto 2));
          DRP_port    := unsigned(AXI4Lite_M2S_i.AWAddr(C_AXI_ADDR_BITS -1 downto DRP_ADDR_BITS + 2));
          AXI4Lite_S2M_i.AWReady <= '1';
          AXI4Lite_S2M_i.WReady  <= '1';
          
          if DRP_port < DRP_COUNT then
            DRP_Enable(to_integer(DRP_port))      <= '1';
            DRP_WriteEnable(to_integer(DRP_port)) <= '1';
            if DRP_S2M_i(to_integer(DRP_port)).Ready = '1' then
              State_nxt <= write_wait;
            else 
              State_nxt <= write;
            end if;
          else
            State_nxt <= write_error;
          end if;
        elsif AXI4Lite_M2S_i.ARValid = '1' then
          DRP_Address <= unsigned(AXI4Lite_M2S_i.ARAddr(DRP_ADDR_BITS + 1 downto 2));
          DRP_port    := unsigned(AXI4Lite_M2S_i.ARAddr(C_AXI_ADDR_BITS -1 downto DRP_ADDR_BITS + 2));
          AXI4Lite_S2M_i.ARReady <= '1';
          
          if DRP_port < DRP_COUNT then
            DRP_Enable(to_integer(DRP_port))      <= '1';
            if DRP_S2M_i(to_integer(DRP_port)).Ready = '1' then
              State_nxt <= read_wait;
              AXI4Lite_S2M_i.RData   <= resize(DRP_S2M_i(to_integer(DRP_port)).DataOut, AXI4Lite_S2M_i.RData'length);
            else 
              State_nxt <= read;
            end if;
          else
            State_nxt <= read_error;
          end if;
        
        end if;
        
      when read =>
        if DRP_S2M_i(to_integer(DRP_port)).Ready = '1' then
          AXI4Lite_S2M_i.RValid  <= '1';
					AXI4Lite_S2M_i.RData   <= resize(DRP_S2M_i(to_integer(DRP_port)).DataOut, AXI4Lite_S2M_i.RData'length);
          if AXI4Lite_M2S_i.RReady = '1' then 
            State_nxt <= idle;
          else
            State_nxt <= read_wait;
          end if;
        end if;
        
      when read_wait =>
        AXI4Lite_S2M_i.RValid  <= '1';
        if AXI4Lite_M2S_i.RReady = '1' then 
          State_nxt <= idle;
        end if;
      
      when read_error =>
        AXI4Lite_S2M_i.RValid  <= '1';
        AXI4Lite_S2M_i.RResp   <= C_AXI4_RESPONSE_DECODE_ERROR;
        AXI4Lite_S2M_i.RData   <= (others => '0');
        if AXI4Lite_M2S_i.RReady = '1' then 
            State_nxt <= idle;
        end if;
      
      when write =>
        if DRP_S2M_i(to_integer(DRP_port)).Ready = '1' then
          AXI4Lite_S2M_i.BValid  <= '1';
          if AXI4Lite_M2S_i.BReady = '1' then 
            State_nxt <= idle;
          else
            State_nxt <= write_wait;
          end if;
        end if;
      when write_wait =>
        AXI4Lite_S2M_i.BValid  <= '1';
        if AXI4Lite_M2S_i.BReady = '1' then 
            State_nxt <= idle;
        end if;
      when write_error =>
        AXI4Lite_S2M_i.BValid  <= '1';
        AXI4Lite_S2M_i.BResp   <= C_AXI4_RESPONSE_DECODE_ERROR;
        if AXI4Lite_M2S_i.BReady = '1' then 
            State_nxt <= idle;
        end if;
		end case;
  end process;
  

end architecture;
