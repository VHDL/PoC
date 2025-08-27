-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:          Patrick Lehmann
--
-- Entity:           mac_TX_Type_Prepender
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2024-2025 The PoC-Library Authors
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
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
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;


use     work.config.all;
use     work.utils.all;
use     work.vectors.all;
use     work.net.all;


entity mac_TX_Type_Prepender is
	generic (
		DEBUG                         : boolean                          := FALSE;
		ETHERNET_TYPES                : T_NET_MAC_ETHERNETTYPE_VECTOR    := (0 => to_net_mac_ethernettype(x"0000"))
	);
	port (
		Clock                         : in  std_logic;
		Reset                         : in  std_logic;

		In_Valid                      : in  std_logic_vector(ETHERNET_TYPES'length - 1 downto 0);
		In_Data                       : in  T_SLVV_8(ETHERNET_TYPES'length - 1 downto 0);
		In_SOF                        : in  std_logic_vector(ETHERNET_TYPES'length - 1 downto 0);
		In_EOF                        : in  std_logic_vector(ETHERNET_TYPES'length - 1 downto 0);
		In_Ack                        : out std_logic_vector(ETHERNET_TYPES'length - 1 downto 0);
		In_Meta_rst                   : out std_logic_vector(ETHERNET_TYPES'length - 1 downto 0);
		In_Meta_DestMACAddress_nxt    : out std_logic_vector(ETHERNET_TYPES'length - 1 downto 0);
		In_Meta_DestMACAddress_Data   : in  T_SLVV_8(ETHERNET_TYPES'length - 1 downto 0);

		Out_Valid                     : out std_logic;
		Out_Data                      : out T_SLV_8;
		Out_SOF                       : out std_logic;
		Out_EOF                       : out std_logic;
		Out_Ack                       : in  std_logic;
		Out_Meta_rst                  : in  std_logic;
		Out_Meta_DestMACAddress_nxt   : in  std_logic;
		Out_Meta_DestMACAddress_Data  : out T_SLV_8
	);
end entity;


architecture rtl of mac_TX_Type_Prepender is
	attribute FSM_ENCODING            : string;

	constant PORTS                    : positive        := ETHERNET_TYPES'length;

	constant META_RST_BIT             : natural         := 0;
	constant META_DEST_NXT_BIT        : natural         := 1;

	constant META_BITS                : positive        := 24;
	constant META_REV_BITS            : positive        := 2;

	type T_STATE is (
		ST_IDLE,
		ST_PREPEND_TYPE_1,
		ST_PAYLOAD
	);

	signal State                      : T_STATE                                            := ST_IDLE;
	signal NextState                  : T_STATE;
	attribute FSM_ENCODING of State   : signal is ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	signal LLMux_In_Valid             : std_logic_vector(PORTS - 1 downto 0);
	signal LLMux_In_Data              : T_SLM(PORTS - 1 downto 0, T_SLV_8'range)                := (others => (others => 'Z'));    -- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	signal LLMux_In_Meta              : T_SLM(PORTS - 1 downto 0, META_BITS - 1 downto 0)        := (others => (others => 'Z'));    -- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	signal LLMux_In_Meta_rev          : T_SLM(PORTS - 1 downto 0, META_REV_BITS - 1 downto 0)    := (others => (others => 'Z'));    -- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	signal LLMux_In_SOF               : std_logic_vector(PORTS - 1 downto 0);
	signal LLMux_In_EOF               : std_logic_vector(PORTS - 1 downto 0);
	signal LLMux_In_Ack               : std_logic_vector(PORTS - 1 downto 0);

	signal LLMux_Out_Valid            : std_logic;
	signal LLMux_Out_Data             : T_SLV_8;
	signal LLMux_Out_Meta             : std_logic_vector(META_BITS - 1 downto 0);
	signal LLMux_Out_Meta_rev         : std_logic_vector(META_REV_BITS - 1 downto 0);
	signal LLMux_Out_SOF              : std_logic;
	signal LLMux_Out_EOF              : std_logic;
	signal LLMux_Out_Ack              : std_logic;

	signal Is_DataFlow                : std_logic;
	signal Is_SOF                     : std_logic;
	signal Is_EOF                     : std_logic;

begin

	LLMux_In_Valid    <= In_Valid;
	LLMux_In_Data     <= to_slm(In_Data);
	LLMux_In_SOF      <= In_SOF;
	LLMux_In_EOF      <= In_EOF;
	In_Ack            <= LLMux_In_Ack;

	genLLMuxIn : for i in 0 to PORTS - 1 generate
		signal Meta      : std_logic_vector(META_BITS - 1 downto 0);
	begin
		Meta  (15 downto  0)  <= to_slv(ETHERNET_TYPES(i));
		Meta  (23 downto 16)  <= In_Meta_DestMACAddress_Data(i);

		assign_row(LLMux_In_Meta, Meta, i);
	end generate;

	In_Meta_rst                 <= get_col(LLMux_In_Meta_rev, META_RST_BIT);
	In_Meta_DestMACAddress_nxt  <= get_col(LLMux_In_Meta_rev, META_DEST_NXT_BIT);

	LLMux : entity work.stream_Mux
		generic map (
			PORTS                 => PORTS,
			DATA_BITS             => LLMux_Out_Data'length,
			META_BITS             => LLMux_Out_Meta'length,
			META_REV_BITS         => LLMux_Out_Meta_rev'length
		)
		port map(
			Clock                 => Clock,
			Reset                 => Reset,

			In_Valid              => LLMux_In_Valid,
			In_Data               => LLMux_In_Data,
			In_Meta               => LLMux_In_Meta,
			In_Meta_rev           => LLMux_In_Meta_rev,
			In_SOF                => LLMux_In_SOF,
			In_EOF                => LLMux_In_EOF,
			In_Ack                => LLMux_In_Ack,

			Out_Valid             => LLMux_Out_Valid,
			Out_Data              => LLMux_Out_Data,
			Out_Meta              => LLMux_Out_Meta,
			Out_Meta_rev          => LLMux_Out_Meta_rev,
			Out_SOF               => LLMux_Out_SOF,
			Out_EOF               => LLMux_Out_EOF,
			Out_Ack               => LLMux_Out_Ack
		);

	LLMux_Out_Meta_rev(META_RST_BIT)        <= Out_Meta_rst;
	LLMux_Out_Meta_rev(META_DEST_NXT_BIT)   <= Out_Meta_DestMACAddress_nxt;

	Is_DataFlow   <= LLMux_Out_Valid and Out_Ack;
	Is_SOF        <= LLMux_Out_Valid and LLMux_Out_SOF;
	Is_EOF        <= LLMux_Out_Valid and LLMux_Out_EOF;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State      <= ST_IDLE;
			else
				State      <= NextState;
			end if;
		end if;
	end process;

	process(all)
	begin
		NextState            <= State;

		Out_Valid            <= '0';
		Out_Data             <= LLMux_Out_Data;
		Out_SOF              <= '0';
		Out_EOF              <= '0';

		LLMux_Out_Ack        <= '0';

		case State is
			when ST_IDLE =>
				if (Is_SOF = '1') then
					Out_Valid       <= '1';
					Out_SOF         <= '1';
					Out_Data        <= LLMux_Out_Meta(15 downto 8);

					if (Out_Ack   = '1') then
						NextState     <= ST_PREPEND_TYPE_1;
					end if;
				end if;

			when ST_PREPEND_TYPE_1 =>
				Out_Valid         <= '1';
				Out_Data          <= LLMux_Out_Meta(7 downto 0);

				if (Out_Ack   = '1') then
					NextState       <= ST_PAYLOAD;
				end if;

			when ST_PAYLOAD =>
				Out_Valid        <= LLMux_Out_Valid;
				Out_EOF          <= LLMux_Out_EOF;
				LLMux_Out_Ack    <= Out_Ack;

				if ((Is_DataFlow and Is_EOF) = '1') then
					NextState      <= ST_IDLE;
				end if;

		end case;
	end process;

	Out_Meta_DestMACAddress_Data    <= LLMux_Out_Meta(23 downto 16);

end architecture;
