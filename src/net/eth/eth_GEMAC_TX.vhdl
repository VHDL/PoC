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

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY Eth_GEMAC_TX IS
	GENERIC (
		DEBUG						: BOOLEAN						:= FALSE
	);
	PORT (
		RS_TX_Clock								: IN	STD_LOGIC;
		RS_TX_Reset								: IN	STD_LOGIC;

		-- status interface
		BufferUnderrun						: OUT	STD_LOGIC;

		-- LocalLink interface
		TX_Valid									: IN	STD_LOGIC;
		TX_Data										: IN	T_SLV_8;
		TX_SOF										: IN	STD_LOGIC;
		TX_EOF										: IN	STD_LOGIC;
		TX_Ack										: OUT	STD_LOGIC;

		-- Reconcilation Sublayer interface
		RS_TX_Valid								: OUT	STD_LOGIC;
		RS_TX_Data								: OUT	T_SLV_8;
		RS_TX_Error								: OUT	STD_LOGIC
	);
end entity;


ARCHITECTURE rtl OF Eth_GEMAC_TX IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	TYPE T_STATE IS (
		ST_IDLE,
		ST_SEND_PREAMBLE,
		ST_SEND_START_OF_FRAME_DELIMITER,
		ST_SEND_DATA_0, ST_SEND_DATA_N, ST_SEND_DATA_PADDING,
		ST_SEND_CRC_BYTE_0, ST_SEND_CRC_BYTE_1, ST_SEND_CRC_BYTE_2, ST_SEND_CRC_BYTE_3,
		ST_SEND_INTER_FRAME_GAP,
		ST_DISCARD_FRAME
	);

	SIGNAL State											: T_STATE																				:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL Is_SOF											: STD_LOGIC;
	SIGNAL Is_EOF											: STD_LOGIC;

	CONSTANT BYTE_COUNTER_BW					: POSITIVE																			:= log2ceilnz(imax(C_NET_ETH_PREMABLE_LENGTH, C_NET_ETH_INTER_FRAME_GAP_LENGTH));
	SIGNAL ByteCounter_rst						: STD_LOGIC;
	SIGNAL ByteCounter_en							: STD_LOGIC;
	SIGNAL ByteCounter_eq1						: STD_LOGIC;
	SIGNAL ByteCounter_eq2						: STD_LOGIC;
	SIGNAL ByteCounter_us							: UNSIGNED(BYTE_COUNTER_BW - 1 DOWNTO 0)				:= (OTHERS => '0');

	SIGNAL PaddingCounter_rst					: STD_LOGIC;
	SIGNAL PaddingCounter_en					: STD_LOGIC;
	SIGNAL PaddingCounter_eq					: STD_LOGIC;
	SIGNAL PaddingCounter_us					: UNSIGNED(5 DOWNTO 0)													:= (OTHERS => '0');

	SIGNAL CRC_rst										: STD_LOGIC;
	SIGNAL CRC_en											: STD_LOGIC;
	SIGNAL CRC_MaskInput							: STD_LOGIC;
	SIGNAL CRC_Value									: T_SLV_32;

	ATTRIBUTE KEEP OF CRC_Value				: SIGNAL IS DEBUG;

BEGIN
	Is_SOF	<= TX_Valid AND TX_SOF;
	Is_EOF	<= TX_Valid AND TX_EOF;

	PROCESS(RS_TX_Clock)
	BEGIN
		IF rising_edge(RS_TX_Clock) THEN
			IF (RS_TX_Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, TX_Data, TX_Valid, Is_SOF, Is_EOF, ByteCounter_eq1, ByteCounter_eq2, PaddingCounter_eq, CRC_Value)
	BEGIN
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

		CASE State IS
			WHEN ST_IDLE =>
				ByteCounter_rst					<= '1';
				PaddingCounter_rst			<= '1';
				CRC_rst									<= '1';

				IF (Is_SOF = '1') THEN
					RS_TX_Valid						<= '1';
					NextState							<= ST_SEND_PREAMBLE;
				END IF;

			WHEN ST_SEND_PREAMBLE =>
				RS_TX_Valid							<= '1';
				ByteCounter_en					<= '1';

				IF (ByteCounter_eq1 = '1') THEN
					NextState							<= ST_SEND_START_OF_FRAME_DELIMITER;
				END IF;

			WHEN ST_SEND_START_OF_FRAME_DELIMITER =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= x"D5";

				NextState								<= ST_SEND_DATA_0;

			WHEN ST_SEND_DATA_0 =>
				TX_Ack									<= '1';
				RS_TX_Data							<= TX_Data;

				RS_TX_Valid							<= '1';
				CRC_en									<= '1';
				PaddingCounter_en				<= '1';

				IF (TX_Valid = '1') THEN
					IF (Is_EOF = '1') THEN
						IF (PaddingCounter_eq = '1') THEN
							NextState					<= ST_SEND_CRC_BYTE_0;
						ELSE
							NextState					<= ST_SEND_DATA_PADDING;
						END IF;
					ELSE
						IF (PaddingCounter_eq = '1') THEN
							NextState					<= ST_SEND_DATA_N;
						END IF;
					END IF;
				ELSE
					BufferUnderrun				<= '1';

					IF (Is_EOF = '1') THEN
						NextState						<= ST_IDLE;
					ELSE
						RS_TX_Error					<= '1';
						NextState						<= ST_DISCARD_FRAME;
					END IF;
				END IF;

			WHEN ST_SEND_DATA_N =>
				TX_Ack									<= '1';
				RS_TX_Data							<= TX_Data;

				RS_TX_Valid							<= '1';
				CRC_en									<= '1';

				IF (TX_Valid = '1') THEN
					IF (Is_EOF = '1') THEN
						NextState						<= ST_SEND_CRC_BYTE_0;
					END IF;
				ELSE
					BufferUnderrun				<= '1';

					IF (Is_EOF = '1') THEN
						NextState						<= ST_IDLE;
					ELSE
						RS_TX_Error					<= '1';
						NextState						<= ST_DISCARD_FRAME;
					END IF;
				END IF;

			WHEN ST_SEND_DATA_PADDING =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= x"00";
				CRC_en									<= '1';
				CRC_MaskInput						<= '1';
				PaddingCounter_en				<= '1';

				IF (PaddingCounter_eq = '1') THEN
					NextState						<= ST_SEND_CRC_BYTE_0;
				END IF;

			WHEN ST_SEND_CRC_BYTE_0 =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= CRC_Value(7 DOWNTO 0);

				NextState								<= ST_SEND_CRC_BYTE_1;

			WHEN ST_SEND_CRC_BYTE_1 =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= CRC_Value(15 DOWNTO 8);

				NextState								<= ST_SEND_CRC_BYTE_2;

			WHEN ST_SEND_CRC_BYTE_2 =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= CRC_Value(23 DOWNTO 16);

				NextState								<= ST_SEND_CRC_BYTE_3;

			WHEN ST_SEND_CRC_BYTE_3 =>
				RS_TX_Valid							<= '1';
				RS_TX_Data							<= CRC_Value(31 DOWNTO 24);
				ByteCounter_rst			<= '1';

				NextState								<= ST_SEND_INTER_FRAME_GAP;

			WHEN ST_SEND_INTER_FRAME_GAP =>
				RS_TX_Valid							<= '0';
				RS_TX_Data							<= x"00";
				ByteCounter_en					<= '1';

				IF (ByteCounter_eq2 = '1') THEN
					NextState							<= ST_IDLE;
				END IF;

			WHEN ST_DISCARD_FRAME =>
				TX_Ack									<= '1';

				IF (Is_EOF = '1') THEN
					NextState							<= ST_IDLE;
				END IF;

		END CASE;
	END PROCESS;

	PROCESS(RS_TX_Clock)
	BEGIN
		IF rising_edge(RS_TX_Clock) THEN
			IF (ByteCounter_rst = '1') THEN
				ByteCounter_us			<= (OTHERS => '0');
			ELSE
				IF (ByteCounter_en = '1') THEN
					ByteCounter_us		<= ByteCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	ByteCounter_eq1		<= to_sl(ByteCounter_us = (C_NET_ETH_PREMABLE_LENGTH - 2));
	ByteCounter_eq2		<= to_sl(ByteCounter_us = (C_NET_ETH_INTER_FRAME_GAP_LENGTH - 1));

	PROCESS(RS_TX_Clock)
	BEGIN
		IF rising_edge(RS_TX_Clock) THEN
			IF (PaddingCounter_rst = '1') THEN
				PaddingCounter_us			<= (OTHERS => '0');
			ELSE
				IF (PaddingCounter_en = '1') THEN
					PaddingCounter_us		<= PaddingCounter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;

	PaddingCounter_eq		<= to_sl(PaddingCounter_us = 59);

	blkCRC : BLOCK
		CONSTANT CRC32_POLYNOMIAL					: BIT_VECTOR(35 DOWNTO 0) := x"104C11DB7";
		CONSTANT CRC32_INIT								: T_SLV_32								:=  x"FFFFFFFF";

		SIGNAL CRC_DataIn									: T_SLV_8;
		SIGNAL CRC_DataOut								: T_SLV_32;

	BEGIN
		CRC_DataIn		<= reverse(TX_Data) AND (TX_Data'range => NOT CRC_MaskInput);

		CRC : ENTITY PoC.comm_crc
			GENERIC MAP (
				GEN							=> CRC32_POLYNOMIAL(32 DOWNTO 0),		-- Generator Polynom
				BITS						=> CRC_DataIn'length								-- Number of Bits to be processed in parallel
			)
			PORT MAP (
				clk							=> RS_TX_Clock,											-- Clock

				set							=> CRC_rst,													-- Parallel Preload of Remainder
				init						=> CRC32_INIT,
				step						=> CRC_en,													-- Process Input Data (MSB first)
				din							=> CRC_DataIn,

				rmd							=> CRC_DataOut,											-- Remainder
				zero						=> OPEN															-- Remainder is Zero
			);

		-- manipulate CRC value
		CRC_Value			<= NOT reverse(CRC_DataOut);
	END BLOCK;
END;
