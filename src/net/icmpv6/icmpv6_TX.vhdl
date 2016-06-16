-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
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
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.net.all;


entity icmpv6_TX is
	port (
		Clock											: in	STD_LOGIC;																	--
		Reset											: in	STD_LOGIC;																	--

		TX_Valid									: out	STD_LOGIC;
		TX_Data										: out	T_SLV_8;
		TX_SOF										: out	STD_LOGIC;
		TX_EOF										: out	STD_LOGIC;
		TX_Ack										: in	STD_LOGIC;

		Send_EchoResponse					: in	STD_LOGIC;
		Send_Complete							: out STD_LOGIC
	);
end entity;


architecture rtl of icmpv6_TX is
	attribute FSM_ENCODING						: STRING;

	type T_STATE		is (
		ST_IDLE,
			ST_SEND_ECHOREQUEST_TYPE,
				ST_SEND_ECHOREQUEST_CODEFIELD,
				ST_SEND_ECHOREQUEST_CHECKSUM_0,
				ST_SEND_ECHOREQUEST_CHECKSUM_1,
				ST_SEND_ECHOREQUEST_IDENTIFIER_0,
				ST_SEND_ECHOREQUEST_IDENTIFIER_1,
				ST_SEND_ECHOREQUEST_SEQUENCENUMBER_0,
				ST_SEND_ECHOREQUEST_SEQUENCENUMBER_1,
				ST_SEND_DATA,
		ST_COMPLETE
	);

	signal State											: T_STATE											:= ST_IDLE;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING of State		: signal is "gray";		--"speed1";

begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State			<= ST_IDLE;
			else
				State			<= NextState;
			end if;
		end if;
	end process;

	process(State, Send_EchoResponse, TX_Ack)
	begin
		NextState							<= State;

		TX_Valid							<= '1';
		TX_Data								<= (others => '0');
		TX_SOF								<= '0';
		TX_EOF								<= '0';

		case State is
			when ST_IDLE =>
				TX_Valid					<= '0';

				if (Send_EchoResponse = '1') then
					NextState				<= ST_SEND_ECHOREQUEST_TYPE;
				end if;

			when ST_SEND_ECHOREQUEST_TYPE =>
				null;

			when ST_SEND_ECHOREQUEST_CODEFIELD =>
				null;

			when ST_SEND_ECHOREQUEST_CHECKSUM_0 =>
				null;

			when ST_SEND_ECHOREQUEST_CHECKSUM_1 =>
				null;

			when ST_SEND_ECHOREQUEST_IDENTIFIER_0 =>
				null;

			when ST_SEND_ECHOREQUEST_IDENTIFIER_1 =>
				null;

			when ST_SEND_ECHOREQUEST_SEQUENCENUMBER_0 =>
				null;

			when ST_SEND_ECHOREQUEST_SEQUENCENUMBER_1 =>
				null;

			when ST_SEND_DATA =>
				null;

			when ST_COMPLETE =>
				null;

		end case;
	end process;

end architecture;
