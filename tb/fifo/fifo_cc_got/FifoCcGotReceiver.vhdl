-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Gustavo Martin
--
-- Entity:          FifoCcGotReceiver
--
-- Description:
-- -------------------------------------
-- OSVVM-based Verification Component - FIFO Receiver (Read side)
-- Implements the read interface (got/dout/valid) for fifo_cc_got
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

entity FifoCcGotReceiver is
  generic (
    MODEL_ID_NAME  : string := "";
    DATA_WIDTH     : integer := 8;
    FSTATE_WIDTH   : integer := 2;
    tpd_Clk_got    : time := 2 ns
  );
  port (
    -- Global Signals
    Clk           : in  std_logic;
    nReset        : in  std_logic;
    
    -- FIFO Read Interface
    got           : out std_logic;
    dout          : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    valid         : in  std_logic;
    fstate_rd     : in  std_logic_vector(FSTATE_WIDTH-1 downto 0);
    
    -- Transaction Interface (OSVVM Standard)
    TransRec      : inout StreamRecType
  );
end entity FifoCcGotReceiver;


architecture VC of FifoCcGotReceiver is

  constant MODEL_INSTANCE_NAME : string :=
    IfElse(MODEL_ID_NAME'length > 0, MODEL_ID_NAME, 
           to_lower(PathTail(FifoCcGotReceiver'path_name)));

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
    variable ExpectedData  : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable NumWords      : integer;
    variable IntOption     : integer;
    variable Available     : boolean;
  begin
    -- Initialize outputs
    got <= '0';
    
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
        -- GET - Blocking read
        ---------------------------------------------------------
        when GET =>
          -- Acknowledge read (handshake) - hold until valid confirmed
          got <= '1';
          loop
            WaitForClock(Clk, 1);
            exit when valid = '1';
          end loop;
          
          -- Capture data when both valid and got are high
          LocalData := dout;
          
          -- Deassert got
          got <= '0';
          
          TransRec.DataFromModel <= SafeResize(LocalData, TransRec.DataFromModel'length);
          TransactionCount <= TransactionCount + 1;
          Log(ModelID, "GET: 0x" & to_hstring(LocalData), DEBUG);
        
        ---------------------------------------------------------
        -- TRY_GET - Non-blocking read
        ---------------------------------------------------------
        when TRY_GET =>
          if valid = '1' then
            -- Acknowledge read (handshake)
            got <= '1';
            WaitForClock(Clk, 1);
            
            -- Capture data if handshake confirmed
            if valid = '1' then
              LocalData := dout;
            end if;
            
            got <= '0';
            
            TransRec.DataFromModel <= SafeResize(LocalData, TransRec.DataFromModel'length);
            TransRec.BoolFromModel <= true;
            TransactionCount <= TransactionCount + 1;
            Log(ModelID, "TRY_GET success: 0x" & to_hstring(LocalData), DEBUG);
          else
            TransRec.BoolFromModel <= false;
            Log(ModelID, "TRY_GET failed: FIFO empty", DEBUG);
          end if;
        
        ---------------------------------------------------------
        -- CHECK - Blocking read with verification
        ---------------------------------------------------------
        when CHECK =>
          ExpectedData := SafeResize(TransRec.DataToModel, DATA_WIDTH);
          
          -- Acknowledge read (handshake) - hold until valid confirmed
          got <= '1';
          loop
            WaitForClock(Clk, 1);
            exit when valid = '1';
          end loop;
          
          -- Capture data when both valid and got are high
          LocalData := dout;
          
          got <= '0';
          
          TransRec.DataFromModel <= SafeResize(LocalData, TransRec.DataFromModel'length);
          TransactionCount <= TransactionCount + 1;
          
          -- Verify data
          AffirmIf(ModelID,
            LocalData = ExpectedData,
            "CHECK: Got 0x" & to_hstring(LocalData) & 
            ", Expected 0x" & to_hstring(ExpectedData));
        
        ---------------------------------------------------------
        -- TRY_CHECK - Non-blocking check
        ---------------------------------------------------------
        when TRY_CHECK =>
          ExpectedData := SafeResize(TransRec.DataToModel, DATA_WIDTH);
          
          if valid = '1' then
            -- Acknowledge read (handshake)
            got <= '1';
            WaitForClock(Clk, 1);
            
            -- Capture data if handshake confirmed
            if valid = '1' then
              LocalData := dout;
            end if;
            
            got <= '0';
            
            TransRec.DataFromModel <= SafeResize(LocalData, TransRec.DataFromModel'length);
            TransRec.BoolFromModel <= true;
            TransactionCount <= TransactionCount + 1;
            
            AffirmIf(ModelID,
              LocalData = ExpectedData,
              "TRY_CHECK: Got 0x" & to_hstring(LocalData) & 
              ", Expected 0x" & to_hstring(ExpectedData));
          else
            TransRec.BoolFromModel <= false;
          end if;
        
        ---------------------------------------------------------
        -- GET_BURST - Read burst into BurstFifo
        ---------------------------------------------------------
        when GET_BURST =>
          NumWords := TransRec.IntToModel;
          Log(ModelID, "GET_BURST: " & integer'image(NumWords) & " words", INFO);
          
          for i in 1 to NumWords loop
            -- Acknowledge read (handshake) - hold until valid confirmed
            got <= '1';
            loop
              WaitForClock(Clk, 1);
              exit when valid = '1';
            end loop;
            
            -- Capture data when both valid and got are high
            LocalData := dout;
            
            got <= '0';
            
            -- Push to burst FIFO
            Push(TransRec.BurstFifo, SafeResize(LocalData, TransRec.DataFromModel'length));
            
            TransactionCount <= TransactionCount + 1;
          end loop;
        
        ---------------------------------------------------------
        -- TRY_GET_BURST - Non-blocking burst read
        ---------------------------------------------------------
        when TRY_GET_BURST =>
          NumWords := TransRec.IntToModel;
          TransRec.IntFromModel <= 0;
          Log(ModelID, "TRY_GET_BURST: " & integer'image(NumWords) & " words requested", INFO);
          
          for i in 1 to NumWords loop
            if valid = '0' then
              exit;
            end if;
            
            -- Acknowledge read (handshake)
            got <= '1';
            WaitForClock(Clk, 1);
            
            -- Capture data if handshake confirmed
            if valid = '0' then
              got <= '0';
              exit;
            end if;
            LocalData := dout;
            
            got <= '0';
            
            Push(TransRec.BurstFifo, SafeResize(LocalData, TransRec.DataFromModel'length));
            TransactionCount <= TransactionCount + 1;
            TransRec.IntFromModel <= i;
          end loop;
        
        ---------------------------------------------------------
        -- CHECK_BURST - Read and verify against BurstFifo
        ---------------------------------------------------------
        when CHECK_BURST =>
          NumWords := TransRec.IntToModel;
          Log(ModelID, "CHECK_BURST: " & integer'image(NumWords) & " words", INFO);
          
          for i in 1 to NumWords loop
            -- Acknowledge read (handshake) - hold until valid confirmed
            got <= '1';
            loop
              WaitForClock(Clk, 1);
              exit when valid = '1';
            end loop;
            
            -- Capture data when both valid and got are high
            LocalData := dout;
            
            got <= '0';
            
            -- Use OSVVM Check with BurstFifo scoreboard
            Check(TransRec.BurstFifo, SafeResize(LocalData, TransRec.DataFromModel'length));
            
            TransactionCount <= TransactionCount + 1;
          end loop;
        
        ---------------------------------------------------------
        -- TRY_CHECK_BURST - Non-blocking check burst
        ---------------------------------------------------------
        when TRY_CHECK_BURST =>
          NumWords := TransRec.IntToModel;
          TransRec.IntFromModel <= 0;
          Log(ModelID, "TRY_CHECK_BURST: " & integer'image(NumWords) & " words", INFO);
          
          for i in 1 to NumWords loop
            if valid = '0' then
              exit;
            end if;
            
            -- Acknowledge read (handshake)
            got <= '1';
            WaitForClock(Clk, 1);
            
            -- Capture data if handshake confirmed
            if valid = '0' then
              got <= '0';
              exit;
            end if;
            LocalData := dout;
            
            got <= '0';
            
            -- Use OSVVM Check with BurstFifo scoreboard
            Check(TransRec.BurstFifo, SafeResize(LocalData, TransRec.DataFromModel'length));
            
            TransactionCount <= TransactionCount + 1;
            TransRec.IntFromModel <= i;
          end loop;
        
        ---------------------------------------------------------
        -- GOT_BURST - Check if burst data is available
        ---------------------------------------------------------
        when GOT_BURST =>
          NumWords := TransRec.IntToModel;
          Available := (valid = '1');  -- Check if at least one word available
          TransRec.BoolFromModel <= Available;
        
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
          -- Wait for data to become available
          if valid = '0' then
            wait until valid = '1';
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
