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
--										 Chair of VLSI-Design, Diagnostics and Architecture
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


entity icmpv6_RX is
	port (
		Clock											: in	std_logic;																	--
		Reset											: in	std_logic;																	--

		Error											: out	std_logic;

		RX_Valid									: in	std_logic;
		RX_Data										: in	T_SLV_8;
		RX_SOF										: in	std_logic;
		RX_EOF										: in	std_logic;
		RX_Ack										: out	std_logic;

		Received_EchoRequest			: out	std_logic
	);
end entity;


architecture rtl of icmpv6_RX is
	attribute FSM_ENCODING						: string;

	type T_STATE		is (
		ST_IDLE,
			ST_RECEIVED_ECHOREQUEST,
				ST_RECEIVED_ECHOREQUEST_CODEFIELD,
				ST_RECEIVED_ECHOREQUEST_CHECKSUM_0,
				ST_RECEIVED_ECHOREQUEST_CHECKSUM_1,
		ST_DISCARD_FRAME, ST_ERROR
	);

	signal State											: T_STATE											:= ST_IDLE;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING of State		: signal is "gray";		--"speed1";

	signal Is_SOF											: std_logic;
	signal Is_EOF											: std_logic;

begin

	Is_SOF		<= RX_Valid and RX_SOF;
	Is_EOF		<= RX_Valid and RX_EOF;

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

	process(State, Is_SOF, Is_EOF, RX_Valid, RX_Data)
	begin
		NextState													<= State;

		RX_Ack														<= '0';

		Received_EchoRequest							<= '0';

		case State is
			when ST_IDLE =>
				if (Is_SOF = '1') then
					RX_Ack									<= '1';

					if (Is_EOF = '0') then
						if (RX_Data = x"08") then
							NextState							<= ST_RECEIVED_ECHOREQUEST;
						else
							NextState							<= ST_DISCARD_FRAME;
						end if;
					else
						NextState								<= ST_ERROR;
					end if;
				end if;

			when ST_RECEIVED_ECHOREQUEST =>
				RX_Ack										<= '1';

				if (Is_EOF = '0') then
					if (RX_Data = x"00") then
						NextState							<= ST_RECEIVED_ECHOREQUEST_CODEFIELD;
					else
						NextState							<= ST_DISCARD_FRAME;
					end if;
				else
					NextState								<= ST_ERROR;
				end if;

			when ST_RECEIVED_ECHOREQUEST_CODEFIELD =>
				RX_Ack										<= '1';

				if (Is_EOF = '0') then
					if (RX_Data = x"00") then
						NextState							<= ST_RECEIVED_ECHOREQUEST_CHECKSUM_0;
					else
						NextState							<= ST_DISCARD_FRAME;
					end if;
				else
					NextState								<= ST_ERROR;
				end if;

			when ST_RECEIVED_ECHOREQUEST_CHECKSUM_0 =>
				RX_Ack										<= '1';

				if (Is_EOF = '1') then
					if (RX_Data = x"00") then
						Received_EchoRequest	<= '1';
						NextState							<= ST_IDLE;
					else
						NextState							<= ST_ERROR;
					end if;
				else
					NextState								<= ST_DISCARD_FRAME;
				end if;

			when ST_RECEIVED_ECHOREQUEST_CHECKSUM_1 =>
				null;

			when ST_DISCARD_FRAME =>
				RX_Ack											<= '1';

				if (Is_EOF = '1') then
					NextState									<= ST_ERROR;
				end if;

			when ST_ERROR =>
				Error												<= '1';
				NextState										<= ST_IDLE;

		end case;
	end process;

end architecture;
