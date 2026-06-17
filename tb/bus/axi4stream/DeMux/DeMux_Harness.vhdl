-- =============================================================================
-- Authors:
--
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
use     IEEE.std_logic_1164.ALL;
use     IEEE.numeric_std.ALL;

library PoC;
use     PoC.config.all;
use     PoC.utils.all;
use     PoC.strings.all;
use     PoC.vectors.all;
use     PoC.physical.all;
use     PoC.axi4stream.all;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_AXI4 ;
context osvvm_AXI4.AxiStreamContext ;

entity DeMux_Harness is

end entity;

architecture Harness of DeMux_Harness is
	constant IS_SIM              : boolean := true;

	--clocks
	constant CLOCK_FREQ_sys      : FREQ     := 200000 kHz;

	constant AXI_DATA_WIDTH      : natural  := 64;
	constant AXI_STRB_WIDTH      : natural  := AXI_DATA_WIDTH / 8;
	constant DATA_BITS           : natural  := 64;
	constant STREAM_BITS         : natural  := DATA_BITS + DATA_BITS / 8;
	constant NUMBER_PORTS        : positive := 4;

	component TestControl is
		generic (
			MIN_PACKET_SIZE    : positive := 1;
			MAX_PACKET_SIZE    : positive := 500;
			NUM_PACKETS        : positive := 15;
			MIN_WAIT_CYCLE     : natural  := 1;
			MAX_WAIT_CYCLE     : natural  := 1000;
			MIN_BACKPRESS_CYCLE: natural  := 1;
			MAX_BACKPRESS_CYCLE: natural  := 500
		);
		port (
			-- Global Signal Interface
			Clock_sys           : In    std_logic ;
			Reset_sys           : In    std_logic ;

			Stream_RX_Pause     : out std_logic_vector;
			Hit_Vector          : out std_logic_vector;

			Stream_TX_Transaction       : inout StreamRecType;
			Stream_RX_Transaction       : inout StreamRecArrayType
		);
	end component;

	component axi4stream_DeMux is
	generic (
		ADD_MIRROR_MODE     : boolean   := false;
		OUTPUT_STAGES       : natural   := 0;
		ENABLE_REVERSE_USER : boolean   := false
	);
	port (
		Clock               : in  std_logic;
		Reset               : in  std_logic;
		-- Control interface
		DeMuxControl        : in  std_logic_vector;
		-- IN Port
		In_M2S              : in  T_AXI4STREAM_M2S;
		In_S2M              : out T_AXI4STREAM_S2M;
		-- OUT Ports
		Out_M2S             : out T_AXI4STREAM_M2S_VECTOR;
		Out_S2M             : in  T_AXI4STREAM_S2M_VECTOR
	);
	end component;

	package axi4stream_D64 is
		new PoC.axi4stream_Sized
		generic map(
			DATA_BITS     => DATA_BITS
		);

	signal Stream_TX_m2s : AXI4Stream_D64.Sized_M2S;
	signal Stream_TX_s2m : AXI4Stream_D64.Sized_S2M;
	signal Stream_RX_m2s : AXI4Stream_D64.Sized_M2S_Vector(0 to NUMBER_PORTS -1);
	signal Stream_RX_s2m : AXI4Stream_D64.Sized_S2M_Vector(0 to NUMBER_PORTS -1);

	signal Hit_Vector    : std_logic_vector(NUMBER_PORTS -1 downto 0);

	signal Stream_Pause  : std_logic_vector(0 to NUMBER_PORTS -1);


	signal Clock_sys           : std_logic :='0';
	signal Reset_sys           : std_logic :='1';


	signal Stream_RX_Transaction : StreamRecArrayType(0 to NUMBER_PORTS -1)(
		DataToModel   (STREAM_BITS-1  downto 0),
		ParamToModel  (4-1 downto 0),
		DataFromModel (STREAM_BITS-1  downto 0),
		ParamFromModel(4-1 downto 0)
	);
	signal Stream_TX_Transaction : StreamRecType(
		DataToModel   (STREAM_BITS-1  downto 0),
		ParamToModel  (4-1 downto 0),
		DataFromModel (STREAM_BITS-1  downto 0),
		ParamFromModel(4-1 downto 0)
	);

begin

	Reset_Clock_blk : block
	begin
		Osvvm.ClockResetPkg.CreateClock (
			Clk        => Clock_sys,
			Period     => to_time(CLOCK_FREQ_sys)
		);

		Osvvm.ClockResetPkg.CreateReset (
			Reset       => Reset_sys,
			ResetActive => '1',
			Clk         => Clock_sys,
			Period      => 200 ns,
			tpd         => 1 ns
		) ;
	end block;

	TestControl_inst : TestControl
	port map(
		-- Global Signal Interface
		Clock_sys            => Clock_sys,
		Reset_sys            => Reset_sys,

		Stream_TX_Transaction       => Stream_TX_Transaction,
		Stream_RX_Transaction       => Stream_RX_Transaction,
		Stream_RX_Pause             => Stream_Pause,
		Hit_Vector                  => Hit_Vector
	);

	Components_blk : block
		signal signal_open : std_logic_vector(0 downto 0);

		signal Stream_TX_Data : std_logic_vector(STREAM_BITS -1 downto 0);
	begin
		Stream_Transmitter : entity OSVVM_AXI4.AxiStreamTransmitter
		generic map(
			tperiod_Clk    => to_time(CLOCK_FREQ_sys)
		)
		port map(
			-- Globals
			Clk       => Clock_sys,
			nReset    => not Reset_sys,

			-- AXI Master Functional Interface
			TValid    => Stream_TX_m2s.Valid,
			TReady    => Stream_TX_s2m.Ready,
			TID       => signal_open,
			TDest     => signal_open,
			TUser     => Stream_TX_m2s.User,
			TData     => Stream_TX_Data,
			TStrb     => signal_open,
			TKeep     => signal_open,
			TLast     => Stream_TX_m2s.Last,

			-- Testbench Transaction Interface
			TransRec  => Stream_TX_Transaction
		);
		Stream_TX_m2s.Keep <= Stream_TX_Data(Stream_TX_Data'high downto DATA_BITS);
		Stream_TX_m2s.data <= Stream_TX_Data(DATA_BITS -1 downto 0);


		Port_gen : for i in 0 to NUMBER_PORTS -1 generate
			signal Stream_RX_Data : std_logic_vector(STREAM_BITS -1 downto 0);

			signal Stream_RX_m2s_i : Stream_RX_m2s(i)'subtype;
			signal Stream_RX_s2m_i : Stream_RX_s2m(i)'subtype;
		begin
			Stream_Receiver : entity OSVVM_AXI4.AxiStreamReceiver
			generic map(
				tperiod_Clk    => to_time(CLOCK_FREQ_sys) ,
				tpd_Clk_TReady => 0.5 ns
			)
			port map(
				-- Globals
				Clk       => Clock_sys,
				nReset    => not Reset_sys,

				-- AXI Master Functional Interface
				TValid    => Stream_RX_m2s_i.Valid,
				TReady    => Stream_RX_s2m_i.Ready,
				TID       => "0",
				TDest     => "0",
				TUser     => Stream_RX_m2s_i.User,
				TData     => Stream_RX_Data,
				TStrb     => "1",
				TKeep     => "1",
				TLast     => Stream_RX_m2s_i.Last,

				-- Testbench Transaction Interface
				TransRec  => Stream_RX_Transaction(i)
			);
			Stream_RX_Data <= Stream_RX_m2s_i.Keep & Stream_RX_m2s_i.data;

			pause : entity PoC.axi4stream_Pause
			port map(
				Pause               => Stream_Pause(i),
				-- IN Port
				In_M2S              => Stream_RX_m2s(i),
				In_S2M              => Stream_RX_s2m(i),
				-- OUT Ports
				Out_M2S             => Stream_RX_m2s_i,
				Out_S2M             => Stream_RX_s2m_i
			);
		end generate;

	end block;

	DUT : axi4stream_DeMux
	generic map(
		ADD_MIRROR_MODE     =>  true,
		OUTPUT_STAGES       =>  1,
		ENABLE_REVERSE_USER =>  false
	)
	port map(
		Clock               => Clock_sys,
		Reset               => Reset_sys,
		-- Control interface
		DeMuxControl        => Hit_Vector,
		-- IN Port
		In_M2S              => Stream_TX_m2s,
		In_S2M              => Stream_TX_s2m,
		-- OUT Ports
		Out_M2S             => Stream_RX_m2s,
		Out_S2M             => Stream_RX_s2m
	);
end architecture;
