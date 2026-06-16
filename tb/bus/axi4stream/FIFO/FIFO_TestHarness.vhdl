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


entity FIFO_TestHarness is
end entity;

architecture sim of FIFO_TestHarness is
	constant TPERIOD_CLOCK : time := 10 ns;

	constant AXISTREAM_DATA_WIDTH  : positive := 64;
	constant AXISTREAM_BYTE_WIDTH  : positive := AXISTREAM_DATA_WIDTH / 8;
	constant AXISTREAM_USER_WIDTH  : natural  := 1;
	constant AXISTREAM_PARAM_WIDTH : positive := AXISTREAM_USER_WIDTH + 3;

	constant FRAMES : positive := 8;
	constant MAX_PACKET_DEPTH : positive := 8;
	--constant RAM_TYPE : T_RAM_TYPE := ??;  -- todo: import lib
	constant METADATA_IS_DYNAMIC : boolean := true;

	signal Clock_100 : std_logic := '1';
	signal Reset_100 : std_logic := '1';

	signal In_M2S  : T_AXI4Stream_M2S(Data(AXISTREAM_DATA_WIDTH -1 downto 0), User(0 downto 0), Dest(0 downto 0), ID(0 downto 0), Keep(AXISTREAM_BYTE_WIDTH -1 downto 0));
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

	component FIFO_TestController is
	port (
		Clock                : in  std_logic;
		Reset                : in  std_logic;
		AXIStreamTransmitter : inout StreamRecType;
		AXIStreamReceiver    : inout StreamRecType;
		Receiver_Pause       : out std_logic;
		Buffer_Full          : in  std_logic;
		Buffer_Empty         : in  std_logic
	);
	end component;
begin
	Osvvm.ClockResetPkg.CreateClock(
			Clk    => Clock_100,
			Period => TPERIOD_CLOCK
	);

	Osvvm.ClockResetPkg.CreateReset(
			Reset       => Reset_100,
			ResetActive => '1',
			Clk         => Clock_100,
			Period      => 5 * TPERIOD_CLOCK,
			tpd         => 0 ns
	);

	DUT : entity PoC.axi4stream_FIFO
		generic map (
			FRAMES              => FRAMES,
			MAX_PACKET_DEPTH    => MAX_PACKET_DEPTH,
			--RAM_TYPE            => RAM_TYPE,
			METADATA_IS_DYNAMIC => METADATA_IS_DYNAMIC
		)
		port map (
			Clock     => Clock_100,
			Reset     => Reset_100,
			In_m2s    => In_M2S,
			In_s2m    => In_S2M,
			Out_m2s   => Out_M2S,
			Out_s2m.Ready   => Out_S2M.Ready and not Receiver_Pause,
			Out_s2m.User    => Out_S2M.User
		);

		Buffer_Full  <= not In_S2M.Ready;
		Buffer_Empty <= not Out_M2S.Valid;

	blkTX: block
		signal Dummy_ID          : std_logic_vector(0 downto 0);
		signal Dummy_Destination : std_logic_vector(0 downto 0);
		signal Dummy_Strb        : std_logic_vector(0 downto 0);
	begin
		Transmitter: entity osvvm_axi4.AxiStreamTransmitter
			generic map (
				INIT_USER      => "",

				tperiod_Clk    => TPERIOD_CLOCK,
				DEFAULT_DELAY  => 0 ns
			)
			port map (
				-- Testbench Transaction Interface
				TransRec => AXIStreamTransmitter,
				-- Globals
				Clk       => Clock_100,
				nReset    => not Reset_100,
				-- AXI Stream Interface
				TValid    => In_M2S.Valid,
				TReady    => In_S2M.Ready,
				TID       => Dummy_ID,
				TDest     => Dummy_Destination,
				TUser     => In_M2S.User,
				TData     => In_M2S.Data,
				TStrb     => Dummy_Strb,
				TKeep     => In_M2S.Keep,
				TLast     => In_M2S.Last
			);
	end block;

	Receiver: entity osvvm_axi4.AxiStreamReceiver
		generic map (
			tperiod_Clk    => TPERIOD_CLOCK,
			tpd_Clk_TReady => 0 ns
		)
		port map (
			-- Testbench Transaction Interface
			TransRec => AXIStreamReceiver,
			-- Globals
			Clk      => Clock_100,
			nReset   => not Reset_100,
			-- AXI Master Functional Interface
			TValid   => Out_M2S.Valid and not Receiver_Pause,
			TReady   => Out_S2M.Ready,
			TID      => "",
			TDest    => "",
			TUser    => Out_M2S.User,
			TData    => Out_M2S.Data,
			TStrb    => "1",
			TKeep    => Out_M2S.Keep,
			TLast    => Out_M2S.Last
		);


	TestCtrl: component FIFO_TestController
		port map (
			Clock                => Clock_100,
			Reset                => Reset_100,
			AXIStreamTransmitter => AXIStreamTransmitter,
			AXIStreamReceiver    => AXIStreamReceiver,
			Receiver_Pause       => Receiver_Pause,
			Buffer_Full          => Buffer_Full,
			Buffer_Empty         => Buffer_Empty
		);

end architecture;
