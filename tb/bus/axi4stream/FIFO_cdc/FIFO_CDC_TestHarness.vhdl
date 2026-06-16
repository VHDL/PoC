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
use     PoC.axi4stream.all;

-- library tb_common;

context PoC.common;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_axi4;
context osvvm_axi4.Axi4Context;
context osvvm_axi4.AxiStreamContext;


entity FIFO_CDC_TestHarness is
end entity;

architecture sim of FIFO_CDC_TestHarness is
	type Test_rec is record
		In_Clock_Freq  : time;
		Out_Clock_Freq : time;
	end record;
	type Test_v is array(NATURAL range <>) of Test_rec;

	constant FIFO_CDC_Test_vector : Test_v := (
		0 => (In_Clock_Freq => 10 ns, Out_Clock_Freq => 10 ns),  -- Same freq
		1 => (In_Clock_Freq => 20 ns, Out_Clock_Freq => 10 ns),  --double input
		2 => (In_Clock_Freq => 20 ns, Out_Clock_Freq => 5 ns),   --quadruple input
		3 => (In_Clock_Freq => 50 ns, Out_Clock_Freq => 5 ns),   --ten times input
		4 => (In_Clock_Freq => 10 ns, Out_Clock_Freq => 20 ns),  --double output
		5 => (In_Clock_Freq => 5 ns, Out_Clock_Freq => 20 ns),   --quadruple output
		6 => (In_Clock_Freq => 5 ns, Out_Clock_Freq => 50 ns)    --ten times output
	);


	constant AXISTREAM_DATA_WIDTH  : positive := 64;
	constant AXISTREAM_BYTE_WIDTH  : positive := AXISTREAM_DATA_WIDTH / 8;
	constant AXISTREAM_PARAM_WIDTH : positive := 8 + 8 + 8 +1;

	constant FRAMES : positive := 8;
	constant MAX_PACKET_DEPTH : positive := 8;
	--constant RAM_TYPE : T_RAM_TYPE := ??;  -- todo: import lib
	constant USER_IS_DYNAMIC : boolean := true;

	component FIFO_CDC_TestController is
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
	end component;

	signal TestDone : integer_barrier := 1;
begin
	Test_Vector_gen : for i in FIFO_CDC_Test_vector'range generate
		signal In_Clock : std_logic := '1';
		signal In_Reset : std_logic := '1';
		signal Out_Clock : std_logic := '1';
		signal Out_Reset : std_logic := '1';

		signal In_M2S  : T_AXI4Stream_M2S(Data(AXISTREAM_DATA_WIDTH -1 downto 0), User(7 downto 0), Dest(7 downto 0), ID(7 downto 0), Keep(AXISTREAM_BYTE_WIDTH -1 downto 0));
		signal In_S2M  : T_AXI4Stream_S2M(User(-1 downto 0));
		signal Out_M2S : In_M2S'subtype;
		signal Out_S2M : In_S2M'subtype;


		subtype StreamRecType_constr is StreamRecType(
						DataToModel   (AXISTREAM_DATA_WIDTH - 1  downto 0),
						DataFromModel (AXISTREAM_DATA_WIDTH - 1  downto 0),
						ParamToModel  (AXISTREAM_PARAM_WIDTH - 1 downto 0),
						ParamFromModel(AXISTREAM_PARAM_WIDTH - 1 downto 0)
		);
		signal AXIStreamTransmitter : StreamRecType_constr;
		signal AXIStreamReceiver    : StreamRecType_constr;

		signal Receiver_Pause       : std_logic := '0';
		signal Buffer_Full          : std_logic := '0';
		signal Buffer_Empty         : std_logic := '0';

	begin
		Osvvm.ClockResetPkg.CreateClock(
			Clk    => In_Clock,
			Period => FIFO_CDC_Test_vector(i).In_Clock_Freq
		);
		Osvvm.ClockResetPkg.CreateClock(
			Clk    => Out_Clock,
			Period => FIFO_CDC_Test_vector(i).Out_Clock_Freq
		);

		Osvvm.ClockResetPkg.CreateReset(
			Reset       => In_Reset,
			ResetActive => '1',
			Clk         => In_Clock,
			Period      => 100 ns,
			tpd         => 0 ns
		);
		Osvvm.ClockResetPkg.CreateReset(
			Reset       => Out_Reset,
			ResetActive => '1',
			Clk         => Out_Clock,
			Period      => 100 ns,
			tpd         => 0 ns
		);

		DUT : entity PoC.axi4stream_FIFO_CDC
		generic map (
			FRAMES              => FRAMES,
			MAX_PACKET_DEPTH    => MAX_PACKET_DEPTH,
			--RAM_TYPE            => RAM_TYPE,
			USER_IS_DYNAMIC => USER_IS_DYNAMIC
		)
		port map (
			In_Clock  => In_Clock,
			In_Reset  => In_Reset,
			In_M2S    => In_M2S,
			In_S2M    => In_S2M,

			Out_Clock => Out_Clock,
			Out_Reset => Out_Reset,
			Out_M2S   => Out_M2S,
			Out_S2M.Ready   => Out_S2M.Ready and not Receiver_Pause,
			Out_S2M.User    => Out_S2M.User
		);

			Buffer_Full  <= not In_S2M.Ready;
			Buffer_Empty <= not Out_M2S.Valid;

		blkTX: block
			signal Dummy_Strb        : std_logic_vector(-1 downto 0);
		begin
			Transmitter: entity osvvm_axi4.AxiStreamTransmitter
			generic map (
				INIT_USER      => "",

				tperiod_Clk    => FIFO_CDC_Test_vector(i).In_Clock_Freq,
				DEFAULT_DELAY  => 0 ns
			)
			port map (
				-- Testbench Transaction Interface
				TransRec => AXIStreamTransmitter,
				-- Globals
				Clk       => In_Clock,
				nReset    => not In_Reset,
				-- AXI Stream Interface
				TValid    => In_M2S.Valid,
				TReady    => In_S2M.Ready,
				TID       => In_M2S.ID,
				TDest     => In_M2S.Dest,
				TUser     => In_M2S.User,
				TData     => In_M2S.Data,
				TStrb     => Dummy_Strb,
				TKeep     => In_M2S.Keep,
				TLast     => In_M2S.Last
			);
		end block;

		Receiver: entity osvvm_axi4.AxiStreamReceiver
		generic map (
			tperiod_Clk    => FIFO_CDC_Test_vector(i).Out_Clock_Freq,
			tpd_Clk_TReady => 0 ns
		)
		port map (
			-- Testbench Transaction Interface
			TransRec => AXIStreamReceiver,
			-- Globals
			Clk      => Out_Clock,
			nReset   => not Out_Reset,
			-- AXI Master Functional Interface
			TValid   => Out_M2S.Valid and not Receiver_Pause,
			TReady   => Out_S2M.Ready,
			TID      => Out_M2S.ID,
			TDest    => Out_M2S.Dest,
			TUser    => Out_M2S.User,
			TData    => Out_M2S.Data,
			TStrb    => "1",
			TKeep    => Out_M2S.Keep,
			TLast    => Out_M2S.Last
		);


		TestCtrl: component FIFO_CDC_TestController
		generic map(
			Test_index => i
		)
		port map (
			TestDone             => TestDone,
			Clock                => Out_Clock,
			Reset                => Out_Reset,
			AXIStreamTransmitter => AXIStreamTransmitter,
			AXIStreamReceiver    => AXIStreamReceiver,
			Receiver_Pause       => Receiver_Pause,
			Buffer_Full          => Buffer_Full,
			Buffer_Empty         => Buffer_Empty
		);
	end generate;
end architecture;
