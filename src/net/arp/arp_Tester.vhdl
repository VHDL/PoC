-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;
use			PoC.net.all;


entity arp_Tester is
	generic (
		CLOCK_FREQ									: FREQ																	:= 125 MHz;
		ARP_LOOKUP_INTERVAL					: TIME																	:= 100 ms
	);
	port (
		Clock												: in	STD_LOGIC;																	--
		Reset												: in	STD_LOGIC;																	--

		Command											: in	T_NET_ARP_TESTER_COMMAND;
		Status											: out	T_NET_ARP_TESTER_STATUS;

		IPCache_Lookup							: out	STD_LOGIC;
		IPCache_IPv4Address_rst			: in	STD_LOGIC;
		IPCache_IPv4Address_nxt			: in	STD_LOGIC;
		IPCache_IPv4Address_Data		: out	T_SLV_8;

		IPCache_Valid								: in	STD_LOGIC;
		IPCache_MACAddress_rst			: out	STD_LOGIC;
		IPCache_MACAddress_nxt			: out	STD_LOGIC;
		IPCache_MACAddress_Data			: in	T_SLV_8
	);
end entity;


architecture rtl of arp_Tester is
	attribute KEEP													: BOOLEAN;

	signal Tick															: STD_LOGIC;
	attribute KEEP of Tick									: signal is TRUE;

	constant LOOKUP_ADDRESSES								: T_NET_IPV4_ADDRESS_VECTOR														:= (
		0 =>			to_net_ipv4_address("192.168.99.1"),
		1 =>			to_net_ipv4_address("192.168.99.2"),
		2 =>			to_net_ipv4_address("192.168.99.3"),
		3 =>			to_net_ipv4_address("192.168.99.4"),
		4 =>			to_net_ipv4_address("192.168.99.2"),
		5 =>			to_net_ipv4_address("192.168.99.5"),
		6 =>			to_net_ipv4_address("192.168.99.6"),
		7 =>			to_net_ipv4_address("192.168.99.7"),
		8 =>			to_net_ipv4_address("192.168.99.3"),
		9 =>			to_net_ipv4_address("192.168.99.8"),
		10 =>			to_net_ipv4_address("192.168.99.9"),
		11 =>			to_net_ipv4_address("192.168.99.2"),
		12 =>			to_net_ipv4_address("192.168.99.3"),
		13 =>			to_net_ipv4_address("192.168.99.2"),
		14 =>			to_net_ipv4_address("192.168.99.3"),
		15 =>			to_net_ipv4_address("192.168.99.1")
	);

	subtype T_BYTE_INDEX										 is NATURAL range 0 to 3;

	type T_STATE IS (
		ST_IDLE,
		ST_IPCACHE_LOOKUP_WAIT,
		ST_IPCACHE_READ
	);

	signal State														: T_STATE																								:= ST_IDLE;
	signal NextState												: T_STATE;

	signal IPv4Address_we										: STD_LOGIC;
	signal IPv4Address_sel									: T_BYTE_INDEX;
	signal IPv4Address_d										: T_NET_IPV4_ADDRESS																		:= to_net_ipv4_address("192.168.99.1");

	attribute KEEP of IPCache_MACAddress_Data	: signal IS TRUE;

	SIGNAl Reader_Counter_en								: STD_LOGIC;
	SIGNAl Reader_Counter_us								: UNSIGNED(log2ceilnz(T_BYTE_INDEX'high) - 1 downto 0)	:= (others => '0');

	SIGNAl Lookup_Counter_en								: STD_LOGIC;
	SIGNAl Lookup_Counter_us								: UNSIGNED(3 downto 0)																	:= (others => '0');

begin
--	assert FALSE report "TICKCOUNTER_MAX: " & INTEGER'image(TimingToCycles(ARP_LOOKUP_INTERVAL, CLOCK_FREQ)) & "    ARP_LOOKUP_INTERVAL: " & REAL'image(ARP_LOOKUP_INTERVAL_MS) & " ms" severity NOTE;

		-- ARP_TestFSM
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State		<= ST_IDLE;
			else
				State		<= NextState;
			end if;
		end if;
	end process;

	process(State, Tick, IPCache_Valid, Reader_Counter_us)
	begin
		NextState											<= State;

		Status												<= NET_ARP_TESTER_STATUS_IDLE;

		IPCache_Lookup								<= '0';
		IPCache_MACAddress_rst				<= '0';
		IPCache_MACAddress_nxt				<= '0';

		Reader_Counter_en							<= '0';
--		IPv4Address_we								<= '0';
--		IPv4Address_sel								<= 0;
		Lookup_Counter_en							<= '0';

		case State is
			when ST_IDLE =>
				if (Tick = '1') then
					IPCache_Lookup					<= '1';
					NextState								<= ST_IPCACHE_LOOKUP_WAIT;
				end if;

			when ST_IPCACHE_LOOKUP_WAIT =>
				Status										<= NET_ARP_TESTER_STATUS_TESTING;

				IPCache_MACAddress_rst		<= '1';

				if (IPCache_Valid = '1') then
					IPCache_MACAddress_rst	<= '0';
					IPCache_MACAddress_nxt	<= '1';

					Reader_Counter_en				<= '1';
					NextState								<= ST_IPCACHE_READ;
				end if;

			when ST_IPCACHE_READ =>
				Status										<= NET_ARP_TESTER_STATUS_TESTING;
				Reader_Counter_en					<= '1';
				IPCache_MACAddress_nxt		<= '1';

				if (Reader_Counter_us = 3) then
					Status									<= NET_ARP_TESTER_STATUS_TEST_COMPLETE;
--					IPv4Address_we					<= '1';
					Lookup_Counter_en				<= '1';
					NextState								<= ST_IDLE;
				end if;

		end case;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reader_Counter_en = '0') then
				Reader_Counter_us		<= to_unsigned(0, Reader_Counter_us'length);
			else
				Reader_Counter_us		<= Reader_Counter_us + 1;
			end if;
		end if;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Lookup_Counter_us		<= to_unsigned(0, Lookup_Counter_us'length);
			elsif (Lookup_Counter_en = '1') then
				Lookup_Counter_us		<= Lookup_Counter_us + 1;
			end if;
		end if;
	end process;

--	process(Clock)
--	begin
--		if rising_edge(Clock) then
--			if (IPv4Address_we = '1') then
--				IPv4Address_d(IPv4Address_sel)		<= IPCache_MACAddress_Data;
--			end if;
--		end if;
--	end process;

	IPv4Address_d			<= LOOKUP_ADDRESSES(to_integer(Lookup_Counter_us));

	IPv4AddressSeq : entity PoC.misc_Sequencer
		generic map (
			INPUT_BITS						=> 32,
			OUTPUT_BITS						=> 8,
			REGISTERED						=> FALSE
		)
		port map (
			Clock									=> Clock,
			Reset									=> Reset,

			Input									=> to_slv(IPv4Address_d),
			rst										=> IPCache_IPv4Address_rst,
			rev										=> '1',
			nxt										=> IPCache_IPv4Address_nxt,
			Output								=> IPCache_IPv4Address_Data
		);

	-- lookup interval tick generator
	process(Clock)
		constant TICKCOUNTER_RES								: TIME																								:= ARP_LOOKUP_INTERVAL;
		constant TICKCOUNTER_MAX								: POSITIVE																						:= TimingToCycles(TICKCOUNTER_RES, CLOCK_FREQ);
		constant TICKCOUNTER_BITS								: POSITIVE																						:= log2ceilnz(TICKCOUNTER_MAX);

		variable TickCounter_s									: SIGNED(TICKCOUNTER_BITS downto 0)										:= to_signed(TICKCOUNTER_MAX, TICKCOUNTER_BITS + 1);
	begin
		if rising_edge(Clock) then
			if (Tick = '1') then
				TickCounter_s		:= to_signed(TICKCOUNTER_MAX, TickCounter_s'length);
			else
				TickCounter_s		:= TickCounter_s - 1;
			end if;
		end if;

		Tick			<= TickCounter_s(TickCounter_s'high);
	end process;

end architecture;