-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		TODO
-- 
-- License:
-- =============================================================================
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
-- =============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
USE			PoC.sata.ALL;


ENTITY sata_FISDecoder IS
	GENERIC (
		DEBUG												: BOOLEAN						:= FALSE
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		Status												: OUT	T_SATA_FISDECODER_STATUS;
		FISType												: OUT T_SATA_FISTYPE;
		
		UpdateATARegisters						: OUT	STD_LOGIC;
		ATADeviceRegisters						: OUT	T_SATA_DEVICE_REGISTERS;

		-- TransportLayer RX_ interface
		RX_Commit											: OUT	STD_LOGIC;
		RX_Rollback										: OUT	STD_LOGIC;
		RX_Valid											: OUT	STD_LOGIC;
		RX_Data												: OUT	T_SLV_32;
		RX_SOP												: OUT	STD_LOGIC;
		RX_EOP												: OUT	STD_LOGIC;
		RX_Ready											: IN	STD_LOGIC;
		
		-- LinkLayer FIFO interface
		Link_RX_Ready									: OUT	STD_LOGIC;
		Link_RX_Data									: IN	T_SLV_32;
		Link_RX_SOF										: IN	STD_LOGIC;
		Link_RX_EOF										: IN	STD_LOGIC;
		Link_RX_Valid									: IN	STD_LOGIC;
		
		-- LinkLayer FS-FIFO interface
		Link_RX_FS_Ready							: OUT	STD_LOGIC;
		Link_RX_FS_CRC_OK							: IN	STD_LOGIC;
		Link_RX_FS_Abort							: IN	STD_LOGIC;
		Link_RX_FS_Valid							: IN	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF sata_FISDecoder IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;

	TYPE T_STATE IS (
		ST_IDLE,
		ST_FIS_REG_DEV_HOST_WORD_1,	ST_FIS_REG_DEV_HOST_WORD_2,	ST_FIS_REG_DEV_HOST_WORD_3,	ST_FIS_REG_DEV_HOST_WORD_4,	ST_FIS_REG_DEV_HOST_CHECK_FRAMESTATE,
		ST_FIS_PIO_SETUP_WORD_1,		ST_FIS_PIO_SETUP_WORD_2,		ST_FIS_PIO_SETUP_WORD_3,		ST_FIS_PIO_SETUP_WORD_4,		ST_FIS_PIO_SETUP_CHECK_FRAMESTATE,
																																																										ST_FIS_DMA_ACTIVATE_CHECK_FRAMESTATE,
		ST_FIS_DATA_1,							ST_FIS_DATA_N,																																			ST_FIS_DATA_CHECK_FRAMESTATE,
		ST_DELAY_TRANSFER_OK,
		ST_DISCARD_FRAME
	);
	
	-- Alias-Definitions for FISType Register Transfer Device => Host (34h)
	-- ====================================================================================
	-- Word 0
	ALIAS Alias_FISType										: T_SLV_8													IS Link_RX_Data(7 DOWNTO 0);
	ALIAS Alias_FlagReg										: T_SLV_8													IS Link_RX_Data(15 DOWNTO 8);				-- Flag bits
	ALIAS Alias_StatusReg									: T_SLV_8													IS Link_RX_Data(23 DOWNTO 16);			-- Status register
	ALIAS Alias_ErrorReg									: T_SLV_8													IS Link_RX_Data(31 DOWNTO 24);			-- Error register
	-- Word 1
	ALIAS Alias_LBA0											: T_SLV_8													IS Link_RX_Data(7 DOWNTO 0);				-- Sector Number
	ALIAS Alias_LBA16											: T_SLV_8													IS Link_RX_Data(15 DOWNTO 8);				-- Cylinder Low
	ALIAS Alias_LBA32											: T_SLV_8													IS Link_RX_Data(23 DOWNTO 16);			-- Cylinder High
	ALIAS Alias_Head											: T_SLV_4													IS Link_RX_Data(27 DOWNTO 24);			-- Head number
	ALIAS Alias_Device										: STD_LOGIC_VECTOR(0 DOWNTO 0)		IS Link_RX_Data(28 DOWNTO 28);			-- Device number
	
	-- Word 2
	ALIAS Alias_LBA8											: T_SLV_8													IS Link_RX_Data(7 DOWNTO 0);				-- Sector Number expanded
	ALIAS Alias_LBA24											: T_SLV_8													IS Link_RX_Data(15 DOWNTO 8);				-- Cylinder Low expanded
	ALIAS Alias_LBA40											: T_SLV_8													IS Link_RX_Data(23 DOWNTO 16);			-- Cylinder High expanded
	
	-- Word 3
	ALIAS Alias_SecCount0									: T_SLV_8													IS Link_RX_Data(7 DOWNTO 0);				-- Sector Count
	ALIAS Alias_SecCount8									: T_SLV_8													IS Link_RX_Data(15 DOWNTO 8);				-- Sector Count expanded

	-- Word 4
	ALIAS Alias_TransferCount							: T_SLV_16												IS Link_RX_Data(15 DOWNTO 0);				-- Transfer Count
	
	-- Alias-Definitions for FISType PIO Setup (5Fh)
	-- ====================================================================================
	-- Word 3
	ALIAS Alias_EndStatusReg							: T_SLV_8													IS Link_RX_Data(31 DOWNTO 24);			-- EndStatus Register
	
	SIGNAL IsFISHeader										: STD_LOGIC;
	SIGNAL FISType_i											: T_SATA_FISTYPE;
	
	SIGNAL State													: T_STATE													:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS ite(DEBUG					, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	SIGNAL FlagRegister										: T_SLV_8													:= (OTHERS => '0');
	SIGNAL StatusRegister									: T_SLV_8													:= (OTHERS => '0');
	SIGNAL EndStatusRegister							: T_SLV_8													:= (OTHERS => '0');
	SIGNAL ErrorRegister									: T_SLV_8													:= (OTHERS => '0');
	SIGNAL AddressRegister								: T_SLV_48												:= (OTHERS => '0');
	SIGNAL SectorCountRegister						: T_SLV_16												:= (OTHERS => '0');
	SIGNAL TransferCountRegister					: T_SLV_16												:= (OTHERS => '0');

	SIGNAL FlagRegister_en								: STD_LOGIC;	
	SIGNAL StatusRegister_en							: STD_LOGIC;
	SIGNAL EndStatusRegister_en						: STD_LOGIC;
	SIGNAL ErrorRegister_en								: STD_LOGIC;
	SIGNAL AddressRegister_en0						: STD_LOGIC;
	SIGNAL AddressRegister_en8						: STD_LOGIC;
	SIGNAL AddressRegister_en16						: STD_LOGIC;
	SIGNAL AddressRegister_en24						: STD_LOGIC;
	SIGNAL AddressRegister_en32						: STD_LOGIC;
	SIGNAL AddressRegister_en40						: STD_LOGIC;
	SIGNAL SectorCountRegister_en0				: STD_LOGIC;
	SIGNAL SectorCountRegister_en8				: STD_LOGIC;
	SIGNAL TransferCountRegister_en				: STD_LOGIC;
	
BEGIN

	IsFISHeader		<= Link_RX_Valid AND Link_RX_SOF;
	FISType_i			<= to_sata_fistype(Alias_FISType, Link_RX_Valid);

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(State, IsFISHeader, FISType_i, Link_RX_Valid, Link_RX_Data, Link_RX_SOF, Link_RX_EOF, Link_RX_FS_Valid, Link_RX_FS_CRC_OK, Link_RX_FS_Abort, RX_Ready)
	BEGIN
		NextState										<= State;
		
		Status											<= SATA_FISD_STATUS_RECEIVING;
		
		Link_RX_Ready								<= '0';
		Link_RX_FS_Ready						<= '0';
		
		RX_Data											<= Link_RX_Data;	
		RX_SOP											<= '0';
		RX_EOP											<= '0';
		RX_Valid										<= '0';
		RX_Commit										<= '0';
		RX_Rollback									<= '0';
		
		FlagRegister_en							<= '0';
		StatusRegister_en						<= '0';
		EndStatusRegister_en				<= '0';
		ErrorRegister_en						<= '0';
		AddressRegister_en0					<= '0';
		AddressRegister_en8					<= '0';
		AddressRegister_en16				<= '0';
		AddressRegister_en24				<= '0';
		AddressRegister_en32				<= '0';
		AddressRegister_en40				<= '0';
		SectorCountRegister_en0			<= '0';
		SectorCountRegister_en8			<= '0';
		TransferCountRegister_en		<= '0';

		UpdateATARegisters					<= '0';

		CASE State IS
			WHEN ST_IDLE =>
				IF (IsFISHeader = '1' ) THEN
					IF (FISType_i = SATA_FISTYPE_PIO_SETUP) THEN
						Link_RX_Ready								<= '1';
						
						FlagRegister_en							<= '1';
						StatusRegister_en						<= '1';
						ErrorRegister_en						<= '1';
						
						IF (Link_RX_EOF = '0') THEN
							NextState 								<= ST_FIS_PIO_SETUP_WORD_1;
						ELSE
							Status										<= SATA_FISD_STATUS_ERROR;
							NextState 								<= ST_IDLE;
						END IF;
					ELSIF (FISType_i = SATA_FISTYPE_REG_DEV_HOST) THEN
						Link_RX_Ready								<= '1';
						
						FlagRegister_en							<= '1';
						StatusRegister_en						<= '1';
						ErrorRegister_en						<= '1';
						
						IF (Link_RX_EOF = '0') THEN
							NextState 								<= ST_FIS_REG_DEV_HOST_WORD_1;
						ELSE
							Status										<= SATA_FISD_STATUS_ERROR;
							NextState 								<= ST_IDLE;
						END IF;
					ELSIF (FISType_i = SATA_FISTYPE_DMA_ACTIVATE) THEN
						Link_RX_Ready								<= '1';
						
						IF (Link_RX_EOF = '1') THEN
							NextState 								<= ST_FIS_DMA_ACTIVATE_CHECK_FRAMESTATE;
						ELSE
							Status										<= SATA_FISD_STATUS_ERROR;
							NextState 								<= ST_IDLE;
						END IF;
						
					ELSIF (FISType_i = SATA_FISTYPE_DATA) THEN
						Link_RX_Ready								<= '1';											-- skip header word
						
						IF (Link_RX_EOF = '0') THEN
							NextState 								<= ST_FIS_DATA_1;						-- goto DataFIS processing
						ELSE
							Status										<= SATA_FISD_STATUS_ERROR;
							NextState 								<= ST_IDLE;
						END IF;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;	-- FISType_i
				ELSE
					Status												<= SATA_FISD_STATUS_IDLE;
				END IF;	-- IsHeader
			
			-- ============================================================
			-- register transfer: device => host
			-- ============================================================
			WHEN ST_FIS_REG_DEV_HOST_WORD_1 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ready									<= '1';
					
					AddressRegister_en0						<= '1';
					AddressRegister_en16					<= '1';
					AddressRegister_en32					<= '1';
					-- DeviceNumber / Heads
					
					IF (Link_RX_EOF = '0') THEN
						NextState 									<= ST_FIS_REG_DEV_HOST_WORD_2;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
		
			WHEN ST_FIS_REG_DEV_HOST_WORD_2 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ready									<= '1';
					
					AddressRegister_en8						<= '1';
					AddressRegister_en24					<= '1';
					AddressRegister_en40					<= '1';
					
					IF (Link_RX_EOF = '0') THEN
						NextState 									<= ST_FIS_REG_DEV_HOST_WORD_3;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_FIS_REG_DEV_HOST_WORD_3 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ready									<= '1';
					
					SectorCountRegister_en0				<= '1';
					SectorCountRegister_en8				<= '1';
					
					IF (Link_RX_EOF = '0') THEN
						NextState 									<= ST_FIS_REG_DEV_HOST_WORD_4;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_FIS_REG_DEV_HOST_WORD_4 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ready									<= '1';
					
					IF (Link_RX_EOF = '1') THEN
						-- last word -> check framestate
						IF (Link_RX_FS_Valid = '1') THEN
							IF (Link_RX_FS_Abort = '1') THEN
								IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
									UpdateATARegisters		<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_DELAY_TRANSFER_OK;
								ELSE																					-- abort with bad crc => ERROR
									Status								<= SATA_FISD_STATUS_CRC_ERROR;
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								END IF;	-- CRC_OK
							ELSE	-- Abort
								IF (Link_RX_FS_CRC_OK = '1') THEN							-- good crc => normal frame
									UpdateATARegisters		<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_DELAY_TRANSFER_OK;
								ELSE																					-- abort with bad crc => ERROR
									Status								<= SATA_FISD_STATUS_CRC_ERROR;
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								END IF;	-- CRC_OK
							END IF;	-- Abort
						ELSE	-- Link_RX_FS_Valid
							NextState 								<= ST_FIS_REG_DEV_HOST_CHECK_FRAMESTATE;
						END IF;
					ELSE
						-- TODO: discard frame and framestate?
					
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_FIS_REG_DEV_HOST_CHECK_FRAMESTATE =>
				Status													<= SATA_FISD_STATUS_CHECKING_CRC;
			
				-- check for FrameState information
				IF (Link_RX_FS_Valid = '1') THEN
					IF (Link_RX_FS_Abort = '1') THEN
						IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
							UpdateATARegisters				<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_DELAY_TRANSFER_OK;
						ELSE																					-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_CRC_ERROR;
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						END IF;	-- CRC_OK
					ELSE	-- Abort
						IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
							UpdateATARegisters				<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_DELAY_TRANSFER_OK;
						ELSE																					-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_CRC_ERROR;
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						END IF;	-- CRC_OK
					END IF;
				END IF;
			
			-- ============================================================
			-- PIO Setup
			-- ============================================================
			WHEN ST_FIS_PIO_SETUP_WORD_1 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ready									<= '1';
					
					AddressRegister_en0						<= '1';
					AddressRegister_en16					<= '1';
					AddressRegister_en32					<= '1';
					-- DeviceNumber / Heads
					
					IF (Link_RX_EOF = '0') THEN
						NextState 									<= ST_FIS_PIO_SETUP_WORD_2;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
		
			WHEN ST_FIS_PIO_SETUP_WORD_2 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ready									<= '1';
					
					AddressRegister_en8						<= '1';
					AddressRegister_en24					<= '1';
					AddressRegister_en40					<= '1';
					
					IF (Link_RX_EOF = '0') THEN
						NextState 									<= ST_FIS_PIO_SETUP_WORD_3;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_FIS_PIO_SETUP_WORD_3 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ready									<= '1';
					
					SectorCountRegister_en0				<= '1';
					SectorCountRegister_en8				<= '1';
					EndStatusRegister_en					<= '1';
					
					IF (Link_RX_EOF = '0') THEN
						NextState 									<= ST_FIS_PIO_SETUP_WORD_4;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_FIS_PIO_SETUP_WORD_4 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ready									<= '1';
					
					TransferCountRegister_en			<= '1';
					
					IF (Link_RX_EOF = '1') THEN
						-- last word -> check framestate
						IF (Link_RX_FS_Valid = '1') THEN
							IF (Link_RX_FS_Abort = '1') THEN
								IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
									UpdateATARegisters		<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_DELAY_TRANSFER_OK;
								ELSE																					-- abort with bad crc => ERROR
									Status								<= SATA_FISD_STATUS_CRC_ERROR;
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								END IF;	-- CRC_OK
							ELSE	-- Abort
								IF (Link_RX_FS_CRC_OK = '1') THEN							-- good crc => normal frame
									UpdateATARegisters		<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_DELAY_TRANSFER_OK;
								ELSE																					-- abort with bad crc => ERROR
									Status								<= SATA_FISD_STATUS_CRC_ERROR;
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								END IF;	-- CRC_OK
							END IF;	-- Abort
						ELSE	-- Link_RX_FS_Valid
							NextState 								<= ST_FIS_PIO_SETUP_CHECK_FRAMESTATE;
						END IF;
					ELSE
						-- TODO: discard frame and framestate?
					
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_FIS_PIO_SETUP_CHECK_FRAMESTATE =>
				Status													<= SATA_FISD_STATUS_CHECKING_CRC;
			
				-- check for FrameState information
				IF (Link_RX_FS_Valid = '1') THEN
					IF (Link_RX_FS_Abort = '1') THEN
						IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
							UpdateATARegisters				<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_DELAY_TRANSFER_OK;
						ELSE																					-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_CRC_ERROR;
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						END IF;	-- CRC_OK
					ELSE	-- Abort
						IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
							UpdateATARegisters				<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_DELAY_TRANSFER_OK;
						ELSE																					-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_CRC_ERROR;
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						END IF;	-- CRC_OK
					END IF;
				END IF;

			WHEN ST_FIS_DMA_ACTIVATE_CHECK_FRAMESTATE =>
				Status													<= SATA_FISD_STATUS_CHECKING_CRC;
			
				-- check for FrameState information
				IF (Link_RX_FS_Valid = '1') THEN
					IF (Link_RX_FS_Abort = '1') THEN
						IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
--							UpdateATARegisters				<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_DELAY_TRANSFER_OK;
						ELSE																					-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_CRC_ERROR;
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						END IF;	-- CRC_OK
					ELSE	-- Abort
						IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
--							UpdateATARegisters				<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_DELAY_TRANSFER_OK;
						ELSE																					-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_CRC_ERROR;
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						END IF;	-- CRC_OK
					END IF;
				END IF;
			
			WHEN ST_DELAY_TRANSFER_OK =>
				Status													<= SATA_FISD_STATUS_RECEIVE_OK;
				NextState												<= ST_IDLE;
			
			-- ============================================================
			-- Data
			-- ============================================================
			WHEN ST_FIS_DATA_1 =>
				-- passthrought handshaking signals
				RX_Valid												<= Link_RX_Valid;
				Link_RX_Ready										<= RX_Ready;
        RX_EOP                          <= Link_RX_EOF;

				-- if streaming is possible => stream first Word; set SOP; goto DATA_N
				IF ((Link_RX_Valid = '1') AND (RX_Ready = '1')) THEN
					RX_SOP												<= '1';
				
					IF (Link_RX_EOF = '1') THEN
						-- check for FrameState information
						IF (Link_RX_FS_Valid = '1') THEN
							IF (Link_RX_FS_Abort = '1') THEN
								IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
									Status								<= SATA_FISD_STATUS_RECEIVE_OK;
									RX_Commit							<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								ELSE																					-- abort with bad crc => ERROR
									Status								<= SATA_FISD_STATUS_CRC_ERROR;
									RX_Rollback						<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								END IF;	-- CRC_OK
							ELSE	-- Abort
								IF (Link_RX_FS_CRC_OK = '1') THEN							-- good crc => normal frame
									Status								<= SATA_FISD_STATUS_RECEIVE_OK;
									RX_Commit							<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								ELSE																					-- abort with bad crc => ERROR
									Status								<= SATA_FISD_STATUS_CRC_ERROR;
									RX_Rollback						<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								END IF;	-- CRC_OK
							END IF;	-- Abort
						ELSE	-- Link_RX_FS_Valid
							NextState 								<= ST_FIS_DATA_CHECK_FRAMESTATE;
						END IF;
					ELSE	-- EOF
						IF (Link_RX_FS_Valid = '1') THEN
							IF ((Link_RX_FS_Abort = '1') AND (Link_RX_FS_CRC_OK = '0')) THEN		-- abort with bad crc => ERROR
								Status									<= SATA_FISD_STATUS_ERROR;
								RX_Rollback							<= '1';
								Link_RX_FS_Ready				<= '1';
									
								NextState 							<= ST_DISCARD_FRAME;
							END IF;
						ELSE
							NextState									<= ST_FIS_DATA_N;
						END IF;
					END IF;
				ELSE -- streaming is possible
					IF (Link_RX_FS_Valid = '1') THEN
						IF ((Link_RX_FS_Abort = '1') AND (Link_RX_FS_CRC_OK = '0')) THEN		-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_ERROR;
							RX_Rollback								<= '1';
							Link_RX_FS_Ready					<= '1';
								
							NextState 								<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NULL;		-- wait in this state
					END IF;
				END IF;
				
			WHEN ST_FIS_DATA_N =>
				RX_Valid												<= Link_RX_Valid;
				Link_RX_Ready										<= RX_Ready;
        RX_EOP                          <= Link_RX_EOF;
        
				-- if streaming is possible => stream first Word; set SOP; goto DATA_N
				IF ((Link_RX_Valid = '1') AND (RX_Ready = '1')) THEN
					IF (Link_RX_EOF = '1') THEN
						-- check for FrameState information
						IF (Link_RX_FS_Valid = '1') THEN
							IF (Link_RX_FS_Abort = '1') THEN
								IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
									Status								<= SATA_FISD_STATUS_RECEIVE_OK;
									RX_Commit							<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								ELSE																					-- abort with bad crc => ERROR
									Status								<= SATA_FISD_STATUS_CRC_ERROR;
									RX_Rollback						<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								END IF;	-- CRC_OK
							ELSE	-- Abort
								IF (Link_RX_FS_CRC_OK = '1') THEN							-- good crc => normal frame
									Status								<= SATA_FISD_STATUS_RECEIVE_OK;
									RX_Commit							<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								ELSE																					-- abort with bad crc => ERROR
									Status								<= SATA_FISD_STATUS_CRC_ERROR;
									RX_Rollback						<= '1';
									Link_RX_FS_Ready			<= '1';
									
									NextState 						<= ST_IDLE;
								END IF;	-- CRC_OK
							END IF;	-- Abort
						ELSE	-- Link_RX_FS_Valid
							NextState 								<= ST_FIS_DATA_CHECK_FRAMESTATE;
						END IF;
					ELSE	-- EOF
						IF (Link_RX_FS_Valid = '1') THEN
							IF ((Link_RX_FS_Abort = '1') AND (Link_RX_FS_CRC_OK = '0')) THEN		-- abort with bad crc => ERROR
								Status									<= SATA_FISD_STATUS_ERROR;
								RX_Rollback							<= '1';
								Link_RX_FS_Ready				<= '1';
									
								NextState 							<= ST_DISCARD_FRAME;
							END IF;
						ELSE
							NULL;		-- wait in this state
						END IF;
					END IF;
				ELSE -- streaming is possible
					IF (Link_RX_FS_Valid = '1') THEN
						IF ((Link_RX_FS_Abort = '1') AND (Link_RX_FS_CRC_OK = '0')) THEN		-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_ERROR;
							RX_Rollback								<= '1';
							Link_RX_FS_Ready					<= '1';
								
							NextState 								<= ST_DISCARD_FRAME;
						END IF;
					ELSE
						NULL;		-- wait in this state
					END IF;
				END IF;
			
			WHEN ST_FIS_DATA_CHECK_FRAMESTATE =>
				Status													<= SATA_FISD_STATUS_CHECKING_CRC;
			
				-- check for FrameState information
				IF (Link_RX_FS_Valid = '1') THEN
					IF (Link_RX_FS_Abort = '1') THEN
						IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
							Status										<= SATA_FISD_STATUS_RECEIVE_OK;
							RX_Commit									<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						ELSE																					-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_CRC_ERROR;
							RX_Rollback								<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						END IF;	-- CRC_OK
					ELSE	-- Abort
						IF (Link_RX_FS_CRC_OK = '1') THEN							-- abort with good crc => shortend frame
							Status										<= SATA_FISD_STATUS_RECEIVE_OK;
							RX_Commit									<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						ELSE																					-- abort with bad crc => ERROR
							Status										<= SATA_FISD_STATUS_CRC_ERROR;
							RX_Rollback								<= '1';
							Link_RX_FS_Ready					<= '1';
							
							NextState 								<= ST_IDLE;
						END IF;	-- CRC_OK
					END IF;
				END IF;
		
			WHEN ST_DISCARD_FRAME =>
				Status													<= SATA_FISD_STATUS_DISCARD_FRAME;
				Link_RX_Ready										<= '1';
				
				IF ((Link_RX_Valid = '1') AND (Link_RX_EOF = '1')) THEN
					NextState 										<= ST_IDLE;
				END IF;
			
		END CASE;
	END PROCESS;

	-- ================================================================
	-- ATA registers - temporary saved
	-- ================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				FlagRegister					<= (OTHERS => '0');
				StatusRegister				<= (OTHERS => '0');
				ErrorRegister					<= (OTHERS => '0');
				AddressRegister				<= (OTHERS => '0');
				SectorCountRegister		<= (OTHERS => '0');
				TransferCountRegister	<= (OTHERS => '0');
			ELSE
				-- FlagRegister
				IF (FlagRegister_en	= '1') THEN
					FlagRegister	<= Alias_FlagReg;
				END IF;
				
				-- StatusRegister
				IF (StatusRegister_en	= '1') THEN
					StatusRegister	<= Alias_StatusReg;
				END IF;
				
				-- EndStatusRegister
				IF (EndStatusRegister_en	= '1') THEN
					EndStatusRegister	<= Alias_EndStatusReg;
				END IF;
				
				-- ErrorRegister
				IF (ErrorRegister_en	= '1') THEN
					ErrorRegister	<= Alias_StatusReg;
				END IF;
				
				-- AddressRegister
				IF (AddressRegister_en0	= '1') THEN
					AddressRegister(7 DOWNTO 0)	<= Alias_LBA0;
				END IF;
				
				IF (AddressRegister_en8	= '1') THEN
					AddressRegister(15 DOWNTO 8)	<= Alias_LBA8;
				END IF;
				
				IF (AddressRegister_en16	= '1') THEN
					AddressRegister(23 DOWNTO 16)	<= Alias_LBA16;
				END IF;
				
				IF (AddressRegister_en24	= '1') THEN
					AddressRegister(31 DOWNTO 24)	<= Alias_LBA24;
				END IF;
				
				IF (AddressRegister_en32	= '1') THEN
					AddressRegister(39 DOWNTO 32)	<= Alias_LBA32;
				END IF;
				
				IF (AddressRegister_en40	= '1') THEN
					AddressRegister(47 DOWNTO 40)	<= Alias_LBA40;
				END IF;
				
				-- SectorCountRegister
				IF (SectorCountRegister_en0	= '1') THEN
					SectorCountRegister(7 DOWNTO 0)		<= Alias_SecCount0;
				END IF;
				
				IF (SectorCountRegister_en8	= '1') THEN
					SectorCountRegister(15 DOWNTO 8)	<= Alias_SecCount8;
				END IF;
				
				-- TransferCountRegister
				IF (TransferCountRegister_en	= '1') THEN
					TransferCountRegister				<= Alias_TransferCount;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	FISType															<= FISType_i;
	
	ATADeviceRegisters.Flags						<= to_ata_device_flags(FlagRegister);
	ATADeviceRegisters.Status						<= to_ata_device_register_status(StatusRegister);
	ATADeviceRegisters.EndStatus				<= to_ata_device_register_status(EndStatusRegister);
	ATADeviceRegisters.Error						<= to_ata_device_register_error(ErrorRegister);
	ATADeviceRegisters.LBlockAddress		<= AddressRegister;
	ATADeviceRegisters.SectorCount			<= SectorCountRegister;
	ATADeviceRegisters.TransferCount		<= TransferCountRegister WHEN (TransferCountRegister_en = '0') ELSE Alias_TransferCount;

END;
