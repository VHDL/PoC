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


entity Eth_GEMAC_TX is
	generic (
		DEBUG						: boolean						:= FALSE
	);
	port (
		RS_TX_Clock								: in	std_logic;
		RS_TX_Reset								: in	std_logic;

		-- status interface
		BufferUnderrun						: out	std_logic;

		-- LocalLink interface
		TX_Valid									: in	std_logic;
		TX_Data										: in	T_SLV_8;
		TX_SOF										: in	std_logic;
		TX_EOF										: in	std_logic;
		TX_Ack										: out	std_logic;

		-- Reconcilation Sublayer interface
		RS_TX_Valid								: out	std_logic;
		RS_TX_Data								: out	T_SLV_8;
		RS_TX_Error								: out	std_logic
	);
end entity;


architecture rtl of Eth_GEMAC_TX is
	attribute KEEP										: boolean;
	attribute FSM_ENCODING						: string;

	type T_STATE is (
		ST_IDLE,
		ST_SEND_PREAMBLE,
		ST_SEND_START_OF_FRAME_DELIMITER,
		ST_SEND_DATA_0, ST_SEND_DATA_N, ST_SEND_DATA_PADDING,
		ST_SEND_CRC_BYTE_0, ST_SEND_CRC_BYTE_1, ST_SEND_CRC_BYTE_2, ST_SEND_CRC_BYTE_3,
		ST_SEND_INTER_FRAME_GAP,
		ST_DISCARD_FRAME
	);

	signal State											: T_STATE																				:= ST_IDLE;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING of State		: signal is ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	signal Is_SOF											: std_logic;
	signal Is_EOF											: std_logic;

	constant BYTE_COUNTER_BW					: positive																			:= log2ceilnz(imax(C_NET_ETH_PREMABLE_LENGTH, C_NET_ETH_INTER_FRAME_GAP_LENGTH));
	signal ByteCounter_rst						: std_logic;
	signal ByteCounter_en							: std_logic;
	signal ByteCounter_eq1						: std_logic;
	signal ByteCounter_eq2						: std_logic;
	signal ByteCounter_us							: unsigned(BYTE_COUNTER_BW - 1 downto 0)				:= (others => '0');

	signal PaddingCounter_rst					: std_logic;
	signal PaddingCounter_en					: std_logic;
	signal PaddingCounter_eq					: std_logic;
	signal PaddingCounter_us					: unsigned(5 downto 0)													:= (others => '0');

	signal CRC_rst										: std_logic;
	signal CRC_en											: std_logic;
	signal CRC_MaskInput							: std_logic;
	signal CRC_Value									: T_SLV_32;

	attribute KEEP of CRC_Value				: signal is DEBUG;

begin
	Is_SOF	<= TX_Valid and TX_SOF;
	Is_EOF	<= TX_Valid and TX_EOF;

	process(RS_TX_Clock)
	begin
		if rising_edge(RS_TX_Clock) then
			if (RS_TX_Reset = '1') then
				State			<= ST_IDLE;
			else
				State			<= NextState;
			end if;
		end if;
	end process;

	process(State, TX_Data, TX_Valid, Is_SOF, Is_EOF, ByteCounter_eq1, ByteCounter_eq2, PaddingCounter_eq, CRC_Value)
	begin
		NextState										<= State;

		BufferUnderrun							<= '0';

		TX_Ack											<= '0';

		RS_TX_Valid									<= '0';
		RS_TX_Data									<= x"55";
		RS_TX_Error									<= '0';

		ByteCounter_rst							<= '0';
		ByteCounter_en							<= '0';

		PaddingCounter_rst					<= '0';
		PaddingCounter_en						<= '0';

		CRC_rst											<= '0';
		CRC_en											<= '0';
		CRC_MaskInput								<= '0';

		case State is
			when ST_IDLE =>
				ByteCounter_rst					<= '1';
				PaddingCounter_rst			<= '1';
				CRC_rst									<= '1';

				if (Is_SOF = '1') then
					RS_TX_Valid						<= '1';
					NextState							<= ST_SEND_PREAMBLE;
				end if;

			when ST_SEND_PREAMBLE =>
				RS_TX_Valid							<= '1';
				ByteCounter_en					<= '1';

				if (ByteCounter_eq1 = '1') then
					NextState							<= ST_SEND_START_OF_FRAME_DELIMITER;
				end if;

			when ST_SEND_START_OF_FRAME_DELIMITER =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= x"D5";

				NextState								<= ST_SEND_DATA_0;

			when ST_SEND_DATA_0 =>
				TX_Ack									<= '1';
				RS_TX_Data							<= TX_Data;

				RS_TX_Valid							<= '1';
				CRC_en									<= '1';
				PaddingCounter_en				<= '1';

				if (TX_Valid = '1') then
					if (Is_EOF = '1') then
						if (PaddingCounter_eq = '1') then
							NextState					<= ST_SEND_CRC_BYTE_0;
						else
							NextState					<= ST_SEND_DATA_PADDING;
						end if;
					else
						if (PaddingCounter_eq = '1') then
							NextState					<= ST_SEND_DATA_N;
						end if;
					end if;
				else
					BufferUnderrun				<= '1';

					if (Is_EOF = '1') then
						NextState						<= ST_IDLE;
					else
						RS_TX_Error					<= '1';
						NextState						<= ST_DISCARD_FRAME;
					end if;
				end if;

			when ST_SEND_DATA_N =>
				TX_Ack									<= '1';
				RS_TX_Data							<= TX_Data;

				RS_TX_Valid							<= '1';
				CRC_en									<= '1';

				if (TX_Valid = '1') then
					if (Is_EOF = '1') then
						NextState						<= ST_SEND_CRC_BYTE_0;
					end if;
				else
					BufferUnderrun				<= '1';

					if (Is_EOF = '1') then
						NextState						<= ST_IDLE;
					else
						RS_TX_Error					<= '1';
						NextState						<= ST_DISCARD_FRAME;
					end if;
				end if;

			when ST_SEND_DATA_PADDING =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= x"00";
				CRC_en									<= '1';
				CRC_MaskInput						<= '1';
				PaddingCounter_en				<= '1';

				if (PaddingCounter_eq = '1') then
					NextState						<= ST_SEND_CRC_BYTE_0;
				end if;

			when ST_SEND_CRC_BYTE_0 =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= CRC_Value(7 downto 0);

				NextState								<= ST_SEND_CRC_BYTE_1;

			when ST_SEND_CRC_BYTE_1 =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= CRC_Value(15 downto 8);

				NextState								<= ST_SEND_CRC_BYTE_2;

			when ST_SEND_CRC_BYTE_2 =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= CRC_Value(23 downto 16);

				NextState								<= ST_SEND_CRC_BYTE_3;

			when ST_SEND_CRC_BYTE_3 =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= CRC_Value(31 downto 24);
				ByteCounter_rst			<= '1';

				NextState								<= ST_SEND_INTER_FRAME_GAP;

			when ST_SEND_INTER_FRAME_GAP =>
				RS_TX_Valid							<= '0';
				RS_TX_Data							<= x"00";
				ByteCounter_en					<= '1';

				if (ByteCounter_eq2 = '1') then
					NextState							<= ST_IDLE;
				end if;

			when ST_DISCARD_FRAME =>
				TX_Ack									<= '1';

				if (Is_EOF = '1') then
					NextState							<= ST_IDLE;
				end if;

		end case;
	end process;

	process(RS_TX_Clock)
	begin
		if rising_edge(RS_TX_Clock) then
			if (ByteCounter_rst = '1') then
				ByteCounter_us			<= (others => '0');
			else
				if (ByteCounter_en = '1') then
					ByteCounter_us		<= ByteCounter_us + 1;
				end if;
			end if;
		end if;
	end process;

	ByteCounter_eq1		<= to_sl(ByteCounter_us = (C_NET_ETH_PREMABLE_LENGTH - 2));
	ByteCounter_eq2		<= to_sl(ByteCounter_us = (C_NET_ETH_INTER_FRAME_GAP_LENGTH - 1));

	process(RS_TX_Clock)
	begin
		if rising_edge(RS_TX_Clock) then
			if (PaddingCounter_rst = '1') then
				PaddingCounter_us			<= (others => '0');
			else
				if (PaddingCounter_en = '1') then
					PaddingCounter_us		<= PaddingCounter_us + 1;
				end if;
			end if;
		end if;
	end process;

	PaddingCounter_eq		<= to_sl(PaddingCounter_us = 59);

	blkCRC : block
		constant CRC32_POLYNOMIAL					: bit_vector(35 downto 0) := x"104C11DB7";
		constant CRC32_INIT								: T_SLV_32								:=  x"FFFFFFFF";

		signal CRC_DataIn									: T_SLV_8;
		signal CRC_DataOut								: T_SLV_32;

	begin
		CRC_DataIn		<= reverse(TX_Data) and (TX_Data'range => not CRC_MaskInput);

		CRC : entity PoC.comm_crc
			generic map (
				GEN							=> CRC32_POLYNOMIAL(32 downto 0),		-- Generator Polynom
				BITS						=> CRC_DataIn'length								-- Number of Bits to be processed in parallel
			)
			port map (
				clk							=> RS_TX_Clock,											-- Clock

				set							=> CRC_rst,													-- Parallel Preload of Remainder
				init						=> CRC32_INIT,
				step						=> CRC_en,													-- Process Input Data (MSB first)
				din							=> CRC_DataIn,

				rmd							=> CRC_DataOut,											-- Remainder
				zero						=> open															-- Remainder is Zero
			);

		-- manipulate CRC value
		CRC_Value			<= not reverse(CRC_DataOut);
	end block;
end;
