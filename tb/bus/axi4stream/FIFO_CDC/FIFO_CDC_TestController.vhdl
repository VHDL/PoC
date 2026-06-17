-- =============================================================================
-- Authors:
--   Adrian Weiland
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
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

library osvvm_AXI4;
context osvvm_AXI4.AxiStreamContext;

entity FIFO_CDC_TestController is
	generic(
		Test_index : natural
	);
	port (
		TestDone             : inout integer_barrier;
		Clock                : in  std_logic;
		Reset                : in  std_logic;

		AXIStreamTransmitter : inout StreamRecType;
		AXIStreamReceiver    : inout StreamRecType;

		Receiver_Pause       : out std_logic;
		Buffer_Full          : in  std_logic;
		Buffer_Empty         : in  std_logic
	);

	-- Simplifying access to Burst FIFOs using aliases
	alias TxBurstFifo : ScoreboardIdType is AXIStreamTransmitter.BurstFifo ;
	alias RxBurstFifo : ScoreboardIdType is AXIStreamReceiver.BurstFifo ;
	alias FIFO_WIDTH is << constant .FIFO_CDC_TestHarness.AXISTREAM_DATA_WIDTH  : positive >>;
end entity;
