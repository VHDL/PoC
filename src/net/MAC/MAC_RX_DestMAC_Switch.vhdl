-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================
-- Module:				 	TODO
--
-- Authors:				 	Patrick Lehmann
-- 
-- Description:
-- ------------------------------------
--		TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
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


ENTITY MAC_RX_DestMAC_Switch IS
	GENERIC (
		DEBUG													: BOOLEAN													:= FALSE;
		MAC_ADDRESSES									: T_NET_MAC_ADDRESS_VECTOR		:= (0 => C_NET_MAC_ADDRESS_EMPTY);
		MAC_ADDRESSE_MASKS						: T_NET_MAC_ADDRESS_VECTOR		:= (0 => C_NET_MAC_MASK_DEFAULT)
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		In_Valid											: IN	STD_LOGIC;
		In_Data												: IN	T_SLV_8;
		In_SOF												: IN	STD_LOGIC;
		In_EOF												: IN	STD_LOGIC;
		In_Ready											: OUT	STD_LOGIC;

		Out_Valid											: OUT	STD_LOGIC_VECTOR(MAC_ADDRESSES'length - 1 DOWNTO 0);
		Out_Data											: OUT	T_SLVV_8(MAC_ADDRESSES'length - 1 DOWNTO 0);
		Out_SOF												: OUT	STD_LOGIC_VECTOR(MAC_ADDRESSES'length - 1 DOWNTO 0);
		Out_EOF												: OUT	STD_LOGIC_VECTOR(MAC_ADDRESSES'length - 1 DOWNTO 0);
		Out_Ready											: IN	STD_LOGIC_VECTOR(MAC_ADDRESSES'length - 1 DOWNTO 0);
		Out_Meta_DestMACAddress_rst		: IN	STD_LOGIC_VECTOR(MAC_ADDRESSES'length - 1 DOWNTO 0);
		Out_Meta_DestMACAddress_nxt		: IN	STD_LOGIC_VECTOR(MAC_ADDRESSES'length - 1 DOWNTO 0);
		Out_Meta_DestMACAddress_Data	: OUT	T_SLVV_8(MAC_ADDRESSES'length - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF MAC_RX_DestMAC_Switch IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	CONSTANT PORTS										: POSITIVE																		:= MAC_ADDRESSES'length;
	CONSTANT MAC_ADDRESSES_I					: T_NET_MAC_ADDRESS_VECTOR(0 TO PORTS - 1)		:= MAC_ADDRESSES;
	CONSTANT MAC_ADDRESSE_MASKS_I			: T_NET_MAC_ADDRESS_VECTOR(0 TO PORTS - 1)		:= MAC_ADDRESSE_MASKS;

	TYPE T_STATE		IS (
		ST_IDLE,
			ST_DEST_MAC_1,
			ST_DEST_MAC_2,
			ST_DEST_MAC_3,
			ST_DEST_MAC_4,
			ST_DEST_MAC_5,
			ST_PAYLOAD_1,
			ST_PAYLOAD_N,
		ST_DISCARD_FRAME
	);
	
	SUBTYPE T_MAC_BYTEINDEX	 IS NATURAL RANGE 0 TO 5;
	
	SIGNAL State											: T_STATE																			:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ready_i									: STD_LOGIC;
	SIGNAL Is_DataFlow								: STD_LOGIC;
	SIGNAL Is_SOF											: STD_LOGIC;
	SIGNAL Is_EOF											: STD_LOGIC;
			
	SIGNAL New_Valid_i								: STD_LOGIC;
	SIGNAL New_SOF_i									: STD_LOGIC;
	SIGNAL Out_Ready_i								: STD_LOGIC;
			
	SIGNAL MAC_ByteIndex							: T_MAC_BYTEINDEX;
			
	SIGNAL CompareRegister_rst				: STD_LOGIC;
	SIGNAL CompareRegister_init				: STD_LOGIC;
	SIGNAL CompareRegister_clear			: STD_LOGIC;
	SIGNAL CompareRegister_en					: STD_LOGIC;
	SIGNAL CompareRegister_d					: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)				:= (OTHERS => '1');
	SIGNAL NoHits											: STD_LOGIC;
	
	CONSTANT MAC_ADDRESS_LENGTH				: POSITIVE																		:= 6;			-- MAC -> 6 bytes
	CONSTANT READER_COUNTER_BITS			: POSITIVE																		:= log2ceilnz(MAC_ADDRESS_LENGTH);

	SIGNAL Reader_Counter_rst					: STD_LOGIC;
	SIGNAL Reader_Counter_en					: STD_LOGIC;
	SIGNAL Reader_Counter_us					: UNSIGNED(READER_COUNTER_BITS - 1 DOWNTO 0)	:= (OTHERS => '0');
	
	SIGNAL DestinationMAC_rst					: STD_LOGIC;
	SIGNAL DestinationMAC_en					: STD_LOGIC;
	SIGNAL DestinationMAC_sel					: T_MAC_BYTEINDEX;
	SIGNAL DestinationMAC_d						: T_NET_MAC_ADDRESS											:= C_NET_MAC_ADDRESS_EMPTY;
	
	SIGNAL Out_Meta_DestMACAddress_rst_i	: STD_LOGIC;
	SIGNAL Out_Meta_DestMACAddress_nxt_i	: STD_LOGIC;
	
BEGIN
	ASSERT FALSE REPORT "RX_DestMAC_Switch:  ports=" & INTEGER'image(PORTS)					SEVERITY NOTE;

	In_Ready			<= In_Ready_i;
	Is_DataFlow		<= In_Valid AND In_Ready_i;
	Is_SOF				<= In_Valid AND In_SOF;
	Is_EOF				<= In_Valid AND In_EOF;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State		<= ST_IDLE;
			ELSE
				State		<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Is_DataFlow, Is_SOF, Is_EOF, In_Valid, NoHits, Out_Ready_i)
	BEGIN
		NextState										<= State;

		In_Ready_i									<= '0';
		
		New_Valid_i									<= '0';
		New_SOF_i										<= '0';

		CompareRegister_en					<= '0';
		CompareRegister_rst					<= '0';
		CompareRegister_init				<= Is_SOF;
		CompareRegister_clear				<= Is_EOF;

		MAC_ByteIndex								<= 0;
		
		DestinationMAC_rst					<= '0';
		DestinationMAC_en						<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				MAC_ByteIndex						<= 5;
				DestinationMAC_en				<= In_Valid;
			
				IF (Is_SOF = '1') THEN
					In_Ready_i						<= '1';
				
					IF (Is_EOF = '0') THEN
						NextState						<= ST_DEST_MAC_1;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_DEST_MAC_1 =>
				MAC_ByteIndex						<= 4;
				CompareRegister_en			<= In_Valid;
				DestinationMAC_en				<= In_Valid;
			
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
				
					IF (Is_EOF = '0') THEN
						NextState						<= ST_DEST_MAC_2;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_DEST_MAC_2 =>
				MAC_ByteIndex						<= 3;
				CompareRegister_en			<= In_Valid;
				DestinationMAC_en				<= In_Valid;
			
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
					
					IF (Is_EOF = '0') THEN
						NextState						<= ST_DEST_MAC_3;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_DEST_MAC_3 =>
				MAC_ByteIndex						<= 2;
				CompareRegister_en			<= In_Valid;
				DestinationMAC_en				<= In_Valid;
			
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
					
					IF (Is_EOF = '0') THEN
						NextState						<= ST_DEST_MAC_4;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_DEST_MAC_4 =>
				MAC_ByteIndex						<= 1;
				CompareRegister_en			<= In_Valid;
				DestinationMAC_en				<= In_Valid;
				
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
					
					IF (Is_EOF = '0') THEN
						NextState						<= ST_DEST_MAC_5;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_DEST_MAC_5 =>
				MAC_ByteIndex						<= 0;
				CompareRegister_en			<= In_Valid;
				DestinationMAC_en				<= In_Valid;
				
				IF (In_Valid = '1') THEN
					In_Ready_i						<= '1';
					
					IF (Is_EOF = '0') THEN
						NextState						<= ST_PAYLOAD_1;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_PAYLOAD_1 =>
				IF (NoHits = '1') THEN
					IF (Is_EOF = '0') THEN
						In_Ready_i					<= '1';
						NextState						<= ST_DISCARD_FRAME;
					ELSE
						NextState						<= ST_IDLE;
					END IF;
				ELSE
					In_Ready_i						<= Out_Ready_i;
					New_Valid_i						<= In_Valid;
					New_SOF_i							<= '1';
				
					IF (IS_DataFlow = '1') THEN
						IF (Is_EOF = '0') THEN
							NextState					<= ST_PAYLOAD_N;
						ELSE
							NextState					<= ST_IDLE;
						END IF;
					END IF;
				END IF;
				
			WHEN ST_PAYLOAD_N =>
				In_Ready_i							<= Out_Ready_i;
				New_Valid_i							<= In_Valid;
			
				IF ((IS_DataFlow AND Is_EOF) = '1') THEN
					NextState							<= ST_IDLE;
				END IF;
				
			WHEN ST_DISCARD_FRAME =>
				In_Ready_i							<= '1';
			
				IF ((IS_DataFlow AND Is_EOF) = '1') THEN
					NextState							<= ST_IDLE;
				END IF;
				
		END CASE;
	END PROCESS;

	
	gen0 : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL Hit								: STD_LOGIC;
	BEGIN
		Hit <= to_sl((In_Data AND MAC_ADDRESSE_MASKS_I(I)(MAC_ByteIndex)) = (MAC_ADDRESSES_I(I)(MAC_ByteIndex) AND MAC_ADDRESSE_MASKS_I(I)(MAC_ByteIndex)));
		
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF ((Reset OR CompareRegister_rst) = '1') THEN
					CompareRegister_d(I)				<= '0';
				ELSE
					IF (CompareRegister_init	= '1') THEN
						CompareRegister_d(I)			<= Hit;
					ELSIF (CompareRegister_clear	= '1') THEN
						CompareRegister_d(I)			<= '0';
					ELSIF (CompareRegister_en  = '1') THEN
						CompareRegister_d(I)			<= CompareRegister_d(I) AND Hit;
					END IF;
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;

	NoHits									<= slv_nor(CompareRegister_d);

	DestinationMAC_sel			<= MAC_ByteIndex;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR DestinationMAC_rst) = '1') THEN
				DestinationMAC_d	<= C_NET_MAC_ADDRESS_EMPTY;
			ELSE
				IF (DestinationMAC_en = '1') THEN
					DestinationMAC_d(DestinationMAC_sel) <= In_Data;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	Reader_Counter_rst	<= Out_Meta_DestMACAddress_rst_i;
	Reader_Counter_en		<= Out_Meta_DestMACAddress_nxt_i;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Reader_Counter_rst) = '1') THEN
				Reader_Counter_us				<= to_unsigned(T_MAC_BYTEINDEX'high, Reader_Counter_us'length);
			ELSE
				IF (Reader_Counter_en = '1') THEN
					Reader_Counter_us			<= Reader_Counter_us - 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	Out_Valid											<= (Out_Valid'range => New_Valid_i)		AND CompareRegister_d;
	Out_Data											<= (Out_Data'range	=> In_Data);
	Out_SOF												<= (Out_SOF'range		=> New_SOF_i);
	Out_EOF												<= (Out_EOF'range		=> In_EOF);
	Out_Ready_i										<= slv_or(Out_Ready										AND CompareRegister_d);
	Out_Meta_DestMACAddress_rst_i	<= slv_or(Out_Meta_DestMACAddress_rst AND CompareRegister_d);
	Out_Meta_DestMACAddress_nxt_i	<= slv_or(Out_Meta_DestMACAddress_nxt AND CompareRegister_d);
	Out_Meta_DestMACAddress_Data	<= (Out_Data'range	=> DestinationMAC_d(to_index(Reader_Counter_us, DestinationMAC_d'high)));
	
END ARCHITECTURE;
