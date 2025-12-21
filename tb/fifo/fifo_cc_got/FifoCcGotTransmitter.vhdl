-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Gustavo Martin
--
-- Entity:          FifoCcGotTransmitter
--
-- Description:
-- -------------------------------------
-- OSVVM-based Verification Component - FIFO Transmitter (Write side)
-- Implements the write interface (put/din/full) for fifo_cc_got
-- Uses OSVVM's standard StreamRecType for transaction interface
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
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

library osvvm;
context osvvm.OsvvmContext;
use     osvvm.ScoreboardPkg_slv.all;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;
use     osvvm_common.FifoFillPkg_slv.all;

entity FifoCcGotTransmitter is
  generic (
    MODEL_ID_NAME  : string := "";
    DATA_WIDTH     : integer := 8;
    ESTATE_WIDTH   : integer := 2;
    tpd_Clk_put    : time := 2 ns;
    tpd_Clk_din    : time := 2 ns
  );
  port (
    -- Global Signals
    Clk           : in  std_logic;
    nReset        : in  std_logic;
    
    -- FIFO Write Interface
    put           : out std_logic;
    din           : out std_logic_vector(DATA_WIDTH-1 downto 0);
    full          : in  std_logic;
    estate_wr     : in  std_logic_vector(ESTATE_WIDTH-1 downto 0);
    
    -- Transaction Interface (OSVVM Standard)
    TransRec      : inout StreamRecType
  );
end entity FifoCcGotTransmitter;


architecture VC of FifoCcGotTransmitter is

  constant MODEL_INSTANCE_NAME : string :=
    IfElse(MODEL_ID_NAME'length > 0, MODEL_ID_NAME, 
           to_lower(PathTail(FifoCcGotTransmitter'path_name)));

  signal ModelID          : AlertLogIDType;
  signal TransactionCount : integer := 0;

begin

  ------------------------------------------------------------
  -- Initialize
  ------------------------------------------------------------
  Initialize : process
    variable ID : AlertLogIDType;
  begin
    ID := NewID(MODEL_INSTANCE_NAME);
    ModelID <= ID;
    wait;
  end process;

  ------------------------------------------------------------
  -- Transaction Handler
  ------------------------------------------------------------
  TransactionHandler : process
    variable LocalData     : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable NumWords      : integer;
    variable IntOption     : integer;
  begin
    -- Initialize outputs
    put <= '0';
    din <= (others => '0');
    
    -- Wait for model ID initialization
    wait for 0 ns;
    
    -- Wait for reset release
    wait until nReset = '1';
    WaitForClock(Clk, 2);
    
    -- Main transaction loop
    TransactionLoop: loop
      -- Wait for transaction request
      WaitForTransaction(
        Rdy => TransRec.Rdy,
        Ack => TransRec.Ack
      );
      
      case TransRec.Operation is
        
        ---------------------------------------------------------
        -- SEND - Blocking write
        ---------------------------------------------------------
        when SEND =>
          LocalData := SafeResize(TransRec.DataToModel, DATA_WIDTH);
          
          -- Assert write request with data
          din <= LocalData;
          put <= '1';
          
          -- Hold put='1' until clock edge with full='0' (handshake confirmed)
          loop
            WaitForClock(Clk);
            exit when full = '0';
          end loop;
          
          -- Deassert after handshake completes
          put <= '0';
          
          TransactionCount <= TransactionCount + 1;
          Log(ModelID, "SEND: 0x" & to_hstring(LocalData), DEBUG);
        
        ---------------------------------------------------------
        -- SEND_ASYNC - Non-blocking write (immediate return)
        ---------------------------------------------------------
        when SEND_ASYNC =>
          LocalData := SafeResize(TransRec.DataToModel, DATA_WIDTH);
          
          -- Assert write request
          din <= LocalData;
          put <= '1';
          WaitForClock(Clk);
          
          -- Check if write was accepted on this clock edge
          if full = '0' then
            TransactionCount <= TransactionCount + 1;
            Log(ModelID, "SEND_ASYNC: 0x" & to_hstring(LocalData), DEBUG);
          else
            Alert(ModelID, "SEND_ASYNC failed: FIFO full", WARNING);
          end if;
          
          put <= '0';
        
        ---------------------------------------------------------
        -- SEND_BURST - Write burst from BurstFifo
        ---------------------------------------------------------
        when SEND_BURST =>
          NumWords := TransRec.IntToModel;
          Log(ModelID, "SEND_BURST: " & integer'image(NumWords) & " words", INFO);
          
          for i in 1 to NumWords loop
            LocalData := SafeResize(Pop(TransRec.BurstFifo), DATA_WIDTH);
            
            -- Assert write request with data
            din <= LocalData;
            put <= '1';
            
            -- Hold put='1' until clock edge with full='0' (handshake confirmed)
            loop
              WaitForClock(Clk);
              exit when full = '0';
            end loop;
            
            TransactionCount <= TransactionCount + 1;
          end loop;
          
          -- Deassert put after burst completes
          put <= '0';
        
        ---------------------------------------------------------
        -- SEND_BURST_ASYNC - Non-blocking burst
        ---------------------------------------------------------
        when SEND_BURST_ASYNC =>
          NumWords := TransRec.IntToModel;
          Log(ModelID, "SEND_BURST_ASYNC: " & integer'image(NumWords) & " words", INFO);
          
          for i in 1 to NumWords loop
            LocalData := SafeResize(Pop(TransRec.BurstFifo), DATA_WIDTH);
            
            -- Assert write request
            din <= LocalData;
            put <= '1';
            WaitForClock(Clk);
            
            -- Check if write was accepted on this clock edge
            if full = '0' then
              TransactionCount <= TransactionCount + 1;
            else
              -- FIFO full - exit burst early
              put <= '0';
              Alert(ModelID, "SEND_BURST_ASYNC: FIFO full at word " & integer'image(i), WARNING);
              exit;
            end if;
          end loop;
          
          -- Deassert put after burst completes
          put <= '0';
        
        ---------------------------------------------------------
        -- WAIT_FOR_CLOCK
        ---------------------------------------------------------
        when WAIT_FOR_CLOCK =>
          NumWords := TransRec.IntToModel;
          WaitForClock(Clk, NumWords);
        
        ---------------------------------------------------------
        -- GET_TRANSACTION_COUNT
        ---------------------------------------------------------
        when GET_TRANSACTION_COUNT =>
          TransRec.IntFromModel <= TransactionCount;
        
        ---------------------------------------------------------
        -- WAIT_FOR_TRANSACTION
        ---------------------------------------------------------
        when WAIT_FOR_TRANSACTION =>
          -- Wait for any pending transactions to complete
          if full = '1' then
            wait until full = '0';
          end if;
        
        ---------------------------------------------------------
        -- GET_ALERTLOG_ID
        ---------------------------------------------------------
        when GET_ALERTLOG_ID =>
          TransRec.IntFromModel <= integer(ModelID);
        
        ---------------------------------------------------------
        -- SET_MODEL_OPTIONS
        ---------------------------------------------------------
        when SET_MODEL_OPTIONS =>
          IntOption := TransRec.Options;
          case IntOption is
            when others =>
              Alert(ModelID, "SetModelOptions: Unknown option: " & integer'image(IntOption), FAILURE);
          end case;
        
        ---------------------------------------------------------
        -- GET_MODEL_OPTIONS  
        ---------------------------------------------------------
        when GET_MODEL_OPTIONS =>
          IntOption := TransRec.Options;
          case IntOption is
            when others =>
              Alert(ModelID, "GetModelOptions: Unknown option: " & integer'image(IntOption), FAILURE);
          end case;
        
        ---------------------------------------------------------
        -- Others
        ---------------------------------------------------------
        when others =>
          Alert(ModelID, "Unsupported operation: " & StreamOperationType'image(TransRec.Operation), ERROR);
          
      end case;
      
    end loop TransactionLoop;
  end process;

end architecture VC;
