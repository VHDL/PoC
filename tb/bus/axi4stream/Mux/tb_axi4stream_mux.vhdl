-- =============================================================================
-- Authors:         Iqbal Asif
--
-- Entity:          Testbench for AXI4 stream multiplexer.
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
use     IEEE.numeric_std_unsigned.all ;

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.axi4stream.all;

library osvvm;
context osvvm.OsvvmContext;

library osvvm_AXI4;
context osvvm_AXI4.AxiStreamContext;


entity tb_axi4stream_mux is
end entity tb_axi4stream_mux;

architecture TestHarness of tb_axi4stream_mux is

	constant DEST_PORTS : positive := 5;

	constant AXI_DATA_WIDTH : integer := 32;

	constant TID_MAX_WIDTH      : integer := 8;
	constant TDEST_TX_MAX_WIDTH : integer := 4;
	constant TDEST_RX_MAX_WIDTH : integer := 4 + log2ceilnz(DEST_PORTS);
	constant TUSER_MAX_WIDTH    : integer := 4;

	constant INIT_TX_ID   : std_logic_vector(TID_MAX_WIDTH - 1 downto 0)      := (others => '0');
	constant INIT_TX_DEST : std_logic_vector(TDEST_TX_MAX_WIDTH - 1 downto 0) := (others => '0');
	constant INIT_TX_USER : std_logic_vector(TUSER_MAX_WIDTH - 1 downto 0)    := (others => '0');

	constant INIT_RX_ID   : std_logic_vector(TID_MAX_WIDTH - 1 downto 0)      := (others => '0');
	constant INIT_RX_DEST : std_logic_vector(TDEST_RX_MAX_WIDTH - 1 downto 0) := (others => '0');
	constant INIT_RX_USER : std_logic_vector(TUSER_MAX_WIDTH - 1 downto 0)    := (others => '0');

	constant AXI_TX_PARAM_WIDTH : integer := TID_MAX_WIDTH + TDEST_TX_MAX_WIDTH + TUSER_MAX_WIDTH + 1;
	constant AXI_RX_PARAM_WIDTH : integer := TID_MAX_WIDTH + TDEST_RX_MAX_WIDTH + TUSER_MAX_WIDTH + 1;

	constant tpd         : time := 2 ns;
	constant tperiod_Clk : time := 10 ns;
	constant tpd_stream  : time := 0 ns;

	signal Clock    : std_logic := '0';
	signal Reset  : std_logic := '1';

	signal RxTStrb : std_logic_vector(AXI_DATA_WIDTH/8 - 1 downto 0);

	signal MuxControl : std_logic_vector(DEST_PORTS - 1 downto 0) := (others => '1');

	signal StreamTxRec : StreamRecArrayType(0 to DEST_PORTS - 1)(
		DataToModel (AXI_DATA_WIDTH - 1 downto 0),
		DataFromModel (AXI_DATA_WIDTH - 1 downto 0),
		ParamToModel (AXI_TX_PARAM_WIDTH - 1 downto 0),
		ParamFromModel(AXI_TX_PARAM_WIDTH - 1 downto 0)
	);

	signal StreamRxRec : StreamRecType(
		DataToModel (AXI_DATA_WIDTH - 1 downto 0),
		DataFromModel (AXI_DATA_WIDTH - 1 downto 0),
		ParamToModel (AXI_RX_PARAM_WIDTH - 1 downto 0),
		ParamFromModel(AXI_RX_PARAM_WIDTH - 1 downto 0)
	);

	signal StreamIn_m2s : T_AXI4Stream_M2S_VECTOR(DEST_PORTS - 1 downto 0)(
		Data (AXI_DATA_WIDTH - 1 downto 0),
		User (TUSER_MAX_WIDTH - 1 downto 0),
		Dest (TDEST_TX_MAX_WIDTH - 1 downto 0),
		ID (TID_MAX_WIDTH - 1 downto 0),
		Keep ((AXI_DATA_WIDTH/8) - 1 downto 0)
	);

	signal StreamIn_s2m : T_AXI4Stream_S2M_VECTOR(DEST_PORTS - 1 downto 0)(
		User(0 downto 0)
	);

	signal StreamOut_m2s : T_AXI4Stream_M2S(
		Data (AXI_DATA_WIDTH - 1 downto 0),
		User (TUSER_MAX_WIDTH - 1 downto 0),
		Dest (TDEST_RX_MAX_WIDTH - 1 downto 0),
		ID (TID_MAX_WIDTH - 1 downto 0),
		Keep ((AXI_DATA_WIDTH/8) - 1 downto 0)
	);
	signal StreamOut_s2m : T_AXI4Stream_S2M(
		User(0 downto 0)
	);

	component TestController is
		generic (
			ID_LEN     : natural;
			DEST_LEN   : natural;
			USER_LEN   : natural
		);
		port (
			-- Global Signal Interface
			Reset : in std_logic;

			-- Transaction Interfaces
			StreamTxRec  : inout StreamRecArrayType;
			StreamRxRec  : inout StreamRecType
		);
	end component;

begin

	-- create Clock for TB and 100 Mhz
	Osvvm.ClockResetPkg.CreateClock (
		Clk    => Clock,
		Period => Tperiod_Clk
	);

	-- create nReset
	Osvvm.ClockResetPkg.CreateReset (
		Reset       => Reset,
		ResetActive => '1',
		Clk         => Clock,
		Period      => 7 * tperiod_Clk,
		tpd         => tpd
	);

	TestCtrl : component TestController
	generic map(
		ID_LEN     => StreamIn_m2s(0).ID'length,
		DEST_LEN   => StreamIn_m2s(0).Dest'length,
		USER_LEN   => StreamIn_m2s(0).User'length
	)
	port map(
		Reset => Reset,

		StreamTxRec => StreamTxRec,
		StreamRxRec => StreamRxRec
	);

	Transmitter_gen : for i in 0 to DEST_PORTS - 1 generate
		signal TxTStrb : std_logic_vector(AXI_DATA_WIDTH/8 - 1 downto 0);
	begin

		AXI4Stream_Transmitter : entity OSVVM_AXI4.AxiStreamTransmitter
		generic map (
			INIT_ID   => INIT_TX_ID,
			INIT_DEST => INIT_TX_DEST,
			INIT_USER => INIT_TX_USER,
			INIT_LAST => 0,

			tperiod_Clk => tperiod_Clk,

			tpd_Clk_TValid => tpd_stream,
			tpd_Clk_TID    => tpd_stream,
			tpd_Clk_TDest  => tpd_stream,
			tpd_Clk_TUser  => tpd_stream,
			tpd_Clk_TData  => tpd_stream,
			tpd_Clk_TStrb  => tpd_stream,
			tpd_Clk_TKeep  => tpd_stream,
			tpd_Clk_TLast  => tpd_stream
		)
		port map (
			-- Globals
			Clk    => Clock,
			nReset => not Reset,

			-- AXI Stream Interface
			TValid => StreamIn_m2s(i).Valid,
			TReady => StreamIn_s2m(i).Ready,
			TID    => StreamIn_m2s(i).ID,
			TDest  => StreamIn_m2s(i).Dest,
			TUser  => StreamIn_m2s(i).User,
			TData  => StreamIn_m2s(i).Data,
			TStrb  => TxTStrb,
			TKeep  => StreamIn_m2s(i).Keep,
			TLast  => StreamIn_m2s(i).Last,

			-- Testbench Transaction Interface
			TransRec => StreamTxRec(i)
		);
	end generate;

	AXI4Stream_Receiver : entity OSVVM_AXI4.AxiStreamReceiver
	generic map(
		tperiod_Clk => tperiod_Clk,
		INIT_ID     => INIT_RX_ID,
		INIT_DEST   => INIT_RX_DEST,
		INIT_USER   => INIT_RX_USER,
		INIT_LAST   => 0,

		tpd_Clk_TReady => tpd_stream
	)
	port map
	(
		-- Globals
		Clk    => Clock,
		nReset => not Reset,

		-- AXI Stream Interface
		-- From TB Receiver to DUT Transmitter
		TValid => StreamOut_m2s.Valid,
		TReady => StreamOut_s2m.Ready,
		TID    => StreamOut_m2s.ID,
		TDest  => StreamOut_m2s.Dest,
		TUser  => StreamOut_m2s.User,
		TData  => StreamOut_m2s.Data,
		TStrb  => RxTStrb,
		TKeep  => StreamOut_m2s.Keep,
		TLast  => StreamOut_m2s.Last,

		-- Testbench Transaction Interface
		TransRec => StreamRxRec
	);

	DUT : entity PoC.AXI4Stream_Mux
	generic map(
		USE_CONTROL_VECTOR => FALSE,
		APPEND_DEST_BITS   => TRUE,
		PORTS              => DEST_PORTS
	)
	port map
	(
		Clock => Clock,
		Reset => Reset,

		-- Control interface
		MuxControl => MuxControl,

		-- IN AXIS Port
		In_M2S => StreamIn_m2s,
		In_S2M => StreamIn_s2m,

		-- OUT AXIS Port
		Out_M2S => StreamOut_m2s,
		Out_S2M => StreamOut_s2m
	);

end architecture TestHarness;
