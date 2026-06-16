-- =============================================================================
-- Authors:         Stefan Unrein
--
-- Entity:          Testcases for AXI4 stream Multiplexer.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
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

library PoC;
use     PoC.config.all;
use     PoC.stream.all;
use     PoC.vectors.all;
use     PoC.strings.all;
use     PoC.utils.all;

library OSVVM;
context OSVVM.OsvvmContext;
use     OSVVM.ScoreBoardPkg_slv.all;

library OSVVM_AXI4;
context OSVVM_AXI4.AxiStreamContext;


architecture RandomTransfer_delay of TestController is
	constant MIN_PACKET_SIZE : positive := 1;
	constant MAX_PACKET_SIZE : positive := 5 * DATA_BYTES;
	constant NUM_PACKETS     : positive := 20000;

	constant TestName : string          := "TC_RandomTransfer_delay";
	signal TestDone   : integer_barrier := 1;
	signal Sync       : integer_barrier := 1;

	signal AXI4StreamData_SB  : ScoreboardIDArrayType(0 to DEST_PORTS - 1);
	signal AXI4StreamParam_SB : ScoreboardIDArrayType(0 to DEST_PORTS - 1);
begin

	------------------------------------------------------------
	-- ControlProc
	--   Set up AlertLog and wait for end of test
	------------------------------------------------------------
	ControlProc : process
	begin
		-- Initialization of test
		SetTestName(TestName);
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		AXI4StreamData_SB  <= NewID("AXI4StreamData_SB", DEST_PORTS);
		AXI4StreamParam_SB <= NewID("AXI4StreamParam_SB", DEST_PORTS);

		SetLogEnable(PASSED, FALSE); -- Enable PASSED logs
		SetLogEnable(INFO, FALSE);   -- Enable INFO logs

		-- Wait for testbench initialization
		wait for 0 ns;
		wait for 0 ns;

		-- Wait for Design Reset
		wait until Reset = '0';
		ClearAlerts;
		LOG("Start of Transactions");

		-- Wait for test to finish
		WaitForBarrier(TestDone, 10 ms);

		AlertIf(now >= 10 ms, "Test finished due to timeout");
		AlertIf(GetAffirmCount < NUM_PACKETS, "Test is not Self-Checking");

		wait for 1 ns;

		EndOfTestReports(ReportAll => TRUE);
		TranscriptClose;
		std.env.stop;
		wait;
	end process;

	------------------------------------------------------------
	-- AxiTransmitterProc
	--   Generate transactions for AxiTransmitter
	------------------------------------------------------------
	Transmitter_gen : for i in 0 to DEST_PORTS - 1 generate
		AxiTransmitterProc : process
			variable OpRV    : RandomPType;
			variable BytesRV : RandomPType;
			variable Bytes   : natural;
			variable Data    : integer_vector(1 to MAX_PACKET_SIZE);

			variable ID   : std_logic_vector(ID_LEN - 1 downto 0);
			variable Dest : std_logic_vector(DEST_LEN - 1 downto 0);
			variable User : std_logic_vector(USER_LEN - 1 downto 0);
			variable Param      : std_logic_vector(ID_LEN + DEST_LEN + USER_LEN downto 0);
			variable ExpParam   : std_logic_vector(ID_LEN + DEST_LEN  +2 + USER_LEN downto 0);
		begin
			OpRV.InitSeed(OpRv'instance_name);
			BytesRV.InitSeed(BytesRV'instance_name);

			wait until Reset = '0';
			SetBurstMode(StreamTxRec(i), STREAM_BURST_BYTE_MODE); -- Put Burst FIFO in Byte Mode
			SetUseRandomDelays(StreamTxRec(i));
			WaitForClock(StreamTxRec(i), 2);

			for packet in 1 to NUM_PACKETS loop
				Bytes            := BytesRV.RandInt(MIN_PACKET_SIZE, MAX_PACKET_SIZE);
				Data(1 to Bytes) := BytesRV.RandIntV(0, 255, Bytes); -- Generate a packetBytes

				ID   := to_slv(to_unsigned(i, ID_LEN));
				Dest := BytesRV.RandSlv(DEST_LEN);
				User := BytesRV.RandSlv(USER_LEN);
				Param := ID & Dest & User & '1';
				ExpParam := ID & ID(2 downto 0) & Dest & User;

				Log("IF " & to_string(i) & ": Sending Packet " & to_string(packet) & " of length " & to_string(Bytes) & " with param=" & PoC.strings.to_string(Param(Param'high downto 1), 'h'), INFO);

				wait for 1 ns;
				PushBurstVector(AXI4StreamData_SB(i), Data(1 to Bytes), 8);
				Push(           AXI4StreamParam_SB(i), ExpParam);
				wait for 1 ns;
				SendBurstVector(StreamTxRec(i), Data(1 to Bytes), Param, 8);
			end loop;

			-- Wait for outputs to propagate and signal TestDone
			WaitForClock(StreamTxRec(i), 2);
			WaitForBarrier(TestDone);
			wait;
		end process;
	end generate;

	------------------------------------------------------------
	-- AxiReceiverProc
	--   Generate transactions for AxiReceiver
	------------------------------------------------------------
	AxiReceiverProc : process
		variable ExpData, RxData : std_logic_vector(DATA_WIDTH - 1 downto 0);
		variable OffSet          : integer;
		variable TryCount        : integer;
		variable Available       : boolean;

		variable ID           : std_logic_vector(ID_LEN - 1 downto 0);
		variable Dest         : std_logic_vector(DEST_LEN + 2 downto 0);
		variable User         : std_logic_vector(USER_LEN - 1 downto 0);
		variable Last         : std_logic;
		variable RxParam      : std_logic_vector(ID_LEN + DEST_LEN +3 + USER_LEN downto 0);
		variable Data         : integer_vector(1 to MAX_PACKET_SIZE);
		variable PacketLength : natural;
		variable index        : natural;
	begin
		wait until Reset = '0';
		SetBurstMode(StreamRxRec, STREAM_BURST_BYTE_MODE); -- Put Burst FIFO in Byte Mode
		SetUseRandomDelays(StreamRxRec);
		WaitForClock(StreamRxRec);

		for i in 0 to DEST_PORTS * NUM_PACKETS - 1 loop
			GetBurst(StreamRxRec, PacketLength, RxParam);
			(ID, Dest, User, Last) := RxParam;
			index            := to_integer(unsigned(ID));

			Log("Received Packet of length " & to_string(PacketLength) & " with ID=" & PoC.strings.to_string(ID, 'h') & " with Dest=" & PoC.strings.to_string(Dest, 'h') & " with User=" & PoC.strings.to_string(User, 'h'), INFO);

			Check(AXI4StreamParam_SB(index), ID & Dest & User);
			CheckBurstFifo(AXI4StreamData_SB(index), StreamRxRec.BurstFifo, PacketLength);
		end loop;
		wait;
	end process;

end architecture;

configuration TC_RandomTransfer_delay of tb_axi4stream_mux is
	for TestHarness
		for TestCtrl : TestController
			use entity work.TestController(RandomTransfer_delay);
		end for;
	end for;
end configuration;
