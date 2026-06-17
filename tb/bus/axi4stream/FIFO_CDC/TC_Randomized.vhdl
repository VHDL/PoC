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

library PoC;
context PoC.common;

library osvvm;
context osvvm.OsvvmContext;

architecture Randomized of FIFO_CDC_TestController is

	shared variable AXI4Stream_SB0 : ScoreboardPType;

	signal Transmitter_Send          : bit := '0';
	signal Transmitter_Done          : bit := '0';
	signal Transmitter_Bytes_to_Send : natural;

	signal Transmitter_OP_Lower : integer;
	signal Transmitter_OP_Upper : integer;
	signal Transmitter_NoOP_Lower : integer;
	signal Transmitter_NoOP_Upper : integer;
	signal Transmitter_Gap_Lower : integer;
	signal Transmitter_Gap_Upper : integer;

	signal BackPressure_Op_Lower : integer;
	signal BackPressure_Op_Upper : integer;
	signal BackPressure_NoOp_Lower : integer;
	signal BackPressure_NoOp_Upper : integer;

begin
	BasicProc: process
	begin
		-- Initialization of test
		if Test_index = 0 then
			SetTestName("TC_Randomized");
		end if;
		SetLogEnable(PASSED, FALSE);    -- Enable PASSED logs
		SetLogEnable(INFO,   FALSE);    -- Enable INFO logs

		-- Wait for testbench initialization
		wait for 0 ns; wait for 0 ns;
		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		AXI4Stream_SB0.SetAlertLogId("AXI4Stream_" & integer'image(Test_index));

		-- Wait for Design Reset
		wait until Reset = '0';
		ClearAlerts;

		-- Wait for test to finish
		WaitForBarrier(TestDone, 10 ms);
		AlertIf(now >= 10 ms,       "Test finished due to timeout");
		AlertIf(GetAffirmCount < 100, "Test is not Self-Checking");

		EndOfTestReports(ReportAll => TRUE);
		TranscriptClose;
		std.env.stop;
		wait;
	end process;

	ControlProc : process
		variable BytesRV   : RandomPType ;

		variable fifo_size : natural := 0;
	begin

		Transmitter_OP_Lower    <= 1;
		Transmitter_OP_Upper    <= 8;
		Transmitter_NoOP_Lower  <= 0;
		Transmitter_NoOP_Upper  <= 3;
		Transmitter_Gap_Lower   <= 0;
		Transmitter_Gap_Upper   <= 3;

		BackPressure_Op_Lower   <= 0;
		BackPressure_Op_Upper   <= 0;
		BackPressure_NoOp_Lower <= 1;
		BackPressure_NoOp_Upper <= 1;

		Transmitter_Bytes_to_Send <= 8;

		while Buffer_Full = '0' loop
			fifo_size := fifo_size + 8;
			Toggle(Transmitter_Send);
			wait until Transmitter_Done = '1';
		end loop;
		-- AffirmIf(fifo_size <= 8*8*8, "Fifo-size is " & integer'image(fifo_size -8), ", expected 512B.");


		BackPressure_Op_Lower   <= 0;
		BackPressure_Op_Upper   <= 3;
		BackPressure_NoOp_Lower <= 0;
		BackPressure_NoOp_Upper <= 2;

		while Buffer_Empty = '0' loop
			wait for 10 ns;
		end loop;

		for i in 0 to 511 loop   --Big Packets
			Transmitter_Bytes_to_Send <= BytesRV.RandInt(1, 256);

			Toggle(Transmitter_Send);
			wait until Transmitter_Done = '1';
		end loop;
		while Buffer_Empty = '0' loop
			wait for 10 ns;
		end loop;

		for i in 0 to 511 loop   --Medium Packets
			Transmitter_Bytes_to_Send <= BytesRV.RandInt(1, 128);

			Toggle(Transmitter_Send);
			wait until Transmitter_Done = '1';
		end loop;
		while Buffer_Empty = '0' loop
			wait for 10 ns;
		end loop;

		for i in 0 to 511 loop   --Small Packets
			Transmitter_Bytes_to_Send <= BytesRV.RandInt(1, 20);

			Toggle(Transmitter_Send);
			wait until Transmitter_Done = '1';
		end loop;
		while Buffer_Empty = '0' loop
			wait for 10 ns;
		end loop;

		wait on Clock until (Buffer_Empty = '1') or AXI4Stream_SB0.Empty;

		wait for 1 us;
		AffirmIf(Buffer_Full = '0', "Buffer full check.", "Buffer is Full!");
		AffirmIf(Buffer_Empty = '1', "Buffer empty check.", "Buffer should be empty.");
		AffirmIf(AXI4Stream_SB0.Empty, "SC empty check.", "SC should be empty.");
		WaitForBarrier(TestDone);
		wait;
	end process;


	AxiTransmitterProc : process
		variable DataRV    : RandomPType ;
		variable OpRV      : RandomPType ;
		variable NoOpRV    : RandomPType ;
		variable GapRV     : RandomPType ;
		variable Bytes     : natural;
		variable i         : natural;
		variable Data      : std_logic_vector(63 downto 0);
		variable Dest      : std_logic_vector(7 downto 0);
		variable ID        : std_logic_vector(7 downto 0);
		variable User      : std_logic_vector(7 downto 0);
	begin

		DataRV.InitSeed(DataRV'instance_name);
		OpRV.InitSeed(OpRv'instance_name);
		NoOpRV.InitSeed(NoOpRV'instance_name);
		GapRV.InitSeed(GapRV'instance_name);

		Transmitter_Done <= '0';

		wait until Reset = '0';
		WaitForClock(AXIStreamTransmitter, 2);

		loop
			Transmitter_Done <= '1';
			WaitForToggle(Transmitter_Send);

			Transmitter_Done <= '0';

			Bytes := Transmitter_Bytes_to_Send;
			i     := 0;
			Dest  := DataRV.RandSlv(size => 8);
			ID    := DataRV.RandSlv(size => 8);

			Byte_loop : while i < Bytes loop
				for j in 0 to OpRV.RandInt(Transmitter_OP_Lower, Transmitter_OP_Upper) loop
					User   := DataRV.RandSlv(size => 8);
					Data   := DataRV.RandSlv(size => 64);

					if (i + 8) >= Bytes then

						if (Bytes mod 8) > 0 then
							Data(Data'high downto 8 * (Bytes mod 8)) := (others => 'U');
						end if;
						AXI4Stream_SB0.Push(ID & Dest & User & "1" & Data);
						Send(AXIStreamTransmitter, Data, ID & Dest & User & "1");

						exit Byte_loop;
					else
						AXI4Stream_SB0.Push(ID & Dest & User & "0" & Data);
						Send(AXIStreamTransmitter, Data, ID & Dest & User & "0");
						i := i +8;
					end if;
				end loop;

				WaitForClock(AXIStreamTransmitter, NoOpRV.RandInt(Transmitter_NoOP_Lower, Transmitter_NoOP_Upper));

			end loop;

			WaitForClock(AXIStreamTransmitter, GapRV.RandInt(Transmitter_Gap_Lower, Transmitter_Gap_Upper));
		end loop;

	end process AxiTransmitterProc;


	AxiReceiverProc : process
		variable Data : std_logic_vector(63 downto 0) ;
		variable Param : std_logic_vector(24 downto 0);
	begin

		wait until Reset = '0';

		loop
			Get(AXIStreamReceiver, Data, Param);
			AXI4Stream_SB0.Check(Param & Data);
		end loop;
	end process AxiReceiverProc;

	Receiver_Pause_Proc : process
		variable OpRV      : RandomPType ;
		variable NoOpRV    : RandomPType ;
	begin
		OpRV.InitSeed(OpRv'instance_name);
		NoOpRV.InitSeed(NoOpRV'instance_name);

		Receiver_Pause <= '0';

		wait until Reset = '0';

		loop
			Receiver_Pause <= '0';
			WaitForClock(Clock, OpRV.RandInt(BackPressure_Op_Lower, BackPressure_Op_Upper));

			Receiver_Pause <= '1';
			WaitForClock(Clock, NoOpRV.RandInt(BackPressure_NoOp_Lower, BackPressure_NoOp_Upper));
		end loop;

	end process;

end architecture;


configuration TC_Randomized of FIFO_CDC_TestHarness is
	for sim
		for Test_Vector_gen
			for TestCtrl: FIFO_CDC_TestController
				use entity work.FIFO_CDC_TestController(Randomized);
			end for;
		end for;
	end for;
end configuration;
