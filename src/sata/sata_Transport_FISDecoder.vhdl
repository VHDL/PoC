-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Module:					FIS Decoder for SATA Transport Layer
--
-- Description:
-- ------------------------------------
-- See notes on module 'sata_TransportLayer'.
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
use			PoC.strings.all;
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_FISDecoder is
	generic (
		DEBUG													: BOOLEAN						:= FALSE;
		ENABLE_DEBUGPORT							: BOOLEAN						:= FALSE
	);
	port (
		Clock													: in	STD_LOGIC;
		Reset													: in	STD_LOGIC;
		
		Status												: out	T_SATA_FISDECODER_STATUS;
		FISType												: out T_SATA_FISTYPE;
		UpdateATARegisters						: out	STD_LOGIC;
		ATADeviceRegisters						: out	T_SATA_ATA_DEVICE_REGISTERS;
		
		-- debugPort
		DebugPortOut									: out	T_SATADBG_TRANS_FISD_OUT;
		
		-- TransportLayer RX_ interface
		RX_Valid											: out	STD_LOGIC;
		RX_Data												: out	T_SLV_32;
		RX_SOP												: out	STD_LOGIC;
		RX_EOP												: out	STD_LOGIC;
		RX_Ack												: in	STD_LOGIC;
		
		-- LinkLayer CSE
		Link_Status										: IN	T_SATA_LINK_STATUS;
		
		-- LinkLayer FIFO interface
		Link_RX_Ack										: out	STD_LOGIC;
		Link_RX_Data									: in	T_SLV_32;
		Link_RX_SOF										: in	STD_LOGIC;
		Link_RX_EOF										: in	STD_LOGIC;
		Link_RX_Valid									: in	STD_LOGIC;
		
		-- LinkLayer FS-FIFO interface
		Link_RX_FS_Ack								: out	STD_LOGIC;
		Link_RX_FS_CRCOK							: in	STD_LOGIC;
		Link_RX_FS_SyncEsc						: in	STD_LOGIC;
		Link_RX_FS_Valid							: in	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF sata_FISDecoder IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;

	TYPE T_STATE IS (
		ST_RESET, ST_IDLE,
		ST_FIS_REG_DEV_HOST_WORD_1,	ST_FIS_REG_DEV_HOST_WORD_2,	ST_FIS_REG_DEV_HOST_WORD_3,	ST_FIS_REG_DEV_HOST_WORD_4,
		ST_FIS_PIO_SETUP_WORD_1,		ST_FIS_PIO_SETUP_WORD_2,		ST_FIS_PIO_SETUP_WORD_3,		ST_FIS_PIO_SETUP_WORD_4,
		ST_FIS_DATA_1,							ST_FIS_DATA_N,
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
	
	SIGNAL State													: T_STATE													:= ST_RESET;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS getFSMEncoding_gray(DEBUG);
	
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
				State			<= ST_RESET;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(State, Link_Status, IsFISHeader, FISType_i, Link_RX_Valid, Link_RX_Data, Link_RX_SOF, Link_RX_EOF, Link_RX_FS_Valid, Link_RX_FS_CRCOK, Link_RX_FS_SyncEsc, RX_Ack	)
	BEGIN
		NextState										<= State;
		
		Status											<= SATA_FISD_STATUS_RECEIVING;
		
		Link_RX_Ack									<= '0';
		Link_RX_FS_Ack							<= '0';
		
		RX_Data											<= Link_RX_Data;	
		RX_SOP											<= '0';
		RX_EOP											<= '0';
		RX_Valid										<= '0';
		
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
			when ST_RESET =>
				-- Clock might be unstable is this state. In this case either
				-- a) Reset is asserted because inital reset of the SATAController is
				--    not finished yet.
				-- b) Phy_Status is constant and not equal to SATA_LINK_STATUS_IDLE
				--    This may happen during reconfiguration due to speed negotiation.
        Status													<= SATA_FISD_STATUS_RESET;
        
        if (Link_Status = SATA_LINK_STATUS_IDLE) then
					NextState <= ST_IDLE;
        end if;
				
			WHEN ST_IDLE =>
				if (Link_RX_FS_Valid = '0') then
					-- wait for frame state
					Status												<= SATA_FISD_STATUS_IDLE;
				elsif (Link_RX_FS_CRCOK = '1') then
					IF (IsFISHeader = '1' ) THEN
						-- frame is OK and now processed
						Link_RX_FS_Ack 							<= '1';
						
						IF (FISType_i = SATA_FISTYPE_PIO_SETUP) THEN
							Link_RX_Ack								<= '1';
							
							FlagRegister_en						<= '1';
							StatusRegister_en					<= '1';
							ErrorRegister_en					<= '1';
							
							IF (Link_RX_EOF = '0') THEN
								NextState 							<= ST_FIS_PIO_SETUP_WORD_1;
							ELSE
								Status									<= SATA_FISD_STATUS_ERROR;
								NextState 							<= ST_IDLE;
							END IF;
						ELSIF (FISType_i = SATA_FISTYPE_REG_DEV_HOST) THEN
							Link_RX_Ack								<= '1';
							
							FlagRegister_en						<= '1';
							StatusRegister_en					<= '1';
							ErrorRegister_en					<= '1';
							
							IF (Link_RX_EOF = '0') THEN
								NextState 							<= ST_FIS_REG_DEV_HOST_WORD_1;
							ELSE
								Status									<= SATA_FISD_STATUS_ERROR;
								NextState 							<= ST_IDLE;
							END IF;
						ELSIF (FISType_i = SATA_FISTYPE_DMA_ACTIVATE) THEN
							Link_RX_Ack								<= '1';
							
							IF (Link_RX_EOF = '1') THEN
								NextState 							<= ST_DELAY_TRANSFER_OK;
							ELSE
								Status									<= SATA_FISD_STATUS_ERROR;
								NextState 							<= ST_DISCARD_FRAME;
							END IF;
							
						ELSIF (FISType_i = SATA_FISTYPE_DATA) THEN
							Link_RX_Ack								<= '1';											-- skip header word
							
							IF (Link_RX_EOF = '0') THEN
								NextState 							<= ST_FIS_DATA_1;						-- goto DataFIS processing
							ELSE
								Status									<= SATA_FISD_STATUS_ERROR;
								NextState 							<= ST_IDLE;
							END IF;
						ELSE
							Status										<= SATA_FISD_STATUS_ERROR;
							NextState 								<= ST_IDLE;
						END IF;	-- FISType_i
					ELSE
						-- wait for SOF, do not ack FS yet
						Status											<= SATA_FISD_STATUS_IDLE;
					END IF;	-- IsHeader
				elsif (Link_RX_FS_SyncEsc = '1') then
					Link_RX_FS_Ack 								<= '1';
					Status 												<= SATA_FISD_STATUS_ERROR;
				else
					Link_RX_FS_Ack 								<= '1';
					Status 												<= SATA_FISD_STATUS_CRC_ERROR;
				end if;
				 
			-- ============================================================
			-- register transfer: device => host
			-- ============================================================
			WHEN ST_FIS_REG_DEV_HOST_WORD_1 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ack										<= '1';
					
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
					Link_RX_Ack										<= '1';
					
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
					Link_RX_Ack										<= '1';
					
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
					Link_RX_Ack										<= '1';
					
					IF (Link_RX_EOF = '1') THEN
						UpdateATARegisters					<= '1';
						NextState 									<= ST_DELAY_TRANSFER_OK;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_DISCARD_FRAME;
					END IF;
				END IF;
			
			-- ============================================================
			-- PIO Setup
			-- ============================================================
			WHEN ST_FIS_PIO_SETUP_WORD_1 =>
				IF (Link_RX_Valid = '1') THEN
					Link_RX_Ack										<= '1';
					
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
					Link_RX_Ack										<= '1';
					
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
					Link_RX_Ack										<= '1';
					
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
					Link_RX_Ack										<= '1';
					
					TransferCountRegister_en			<= '1';
					
					IF (Link_RX_EOF = '1') THEN
						UpdateATARegisters					<= '1';
						NextState 									<= ST_DELAY_TRANSFER_OK;
					ELSE
						Status											<= SATA_FISD_STATUS_ERROR;
						NextState 									<= ST_DISCARD_FRAME;
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
				Link_RX_Ack											<= RX_Ack;
        RX_EOP                          <= Link_RX_EOF;
				RX_SOP													<= '1';

				-- if streaming is possible => stream first Word; set SOP; goto DATA_N
				IF ((Link_RX_Valid = '1') AND (RX_Ack = '1')) THEN
					IF (Link_RX_EOF = '1') THEN
						Status											<= SATA_FISD_STATUS_RECEIVE_OK;
						NextState 									<= ST_IDLE;
					ELSE	-- EOF
						NextState										<= ST_FIS_DATA_N;
					END IF;
				END IF;
				
			WHEN ST_FIS_DATA_N =>
				RX_Valid												<= Link_RX_Valid;
				Link_RX_Ack											<= RX_Ack;
        RX_EOP                          <= Link_RX_EOF;
        
				-- if streaming is possible => stream first Word; set SOP; goto DATA_N
				IF ((Link_RX_Valid = '1') AND (RX_Ack = '1')) THEN
					IF (Link_RX_EOF = '1') THEN
						Status											<= SATA_FISD_STATUS_RECEIVE_OK;
						NextState 									<= ST_IDLE;
					END IF;
				END IF;
		
			-- ============================================================
			-- Discard remaining frame
			-- ============================================================
			WHEN ST_DISCARD_FRAME =>
				Status													<= SATA_FISD_STATUS_DISCARD_FRAME;
				Link_RX_Ack											<= '1';
				
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
					ErrorRegister	<= Alias_ErrorReg;
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
				end if;
			end if;
		end if;
	end process;
	
	FISType															<= FISType_i;
	
	ATADeviceRegisters.Flags						<= to_sata_ata_device_flags(FlagRegister);
	ATADeviceRegisters.Status						<= to_sata_ata_device_register_status(StatusRegister);
	ATADeviceRegisters.EndStatus				<= to_sata_ata_device_register_status(EndStatusRegister);
	ATADeviceRegisters.Error						<= to_sata_ata_device_register_error(ErrorRegister);
	ATADeviceRegisters.LBlockAddress		<= AddressRegister;
	ATADeviceRegisters.SectorCount			<= SectorCountRegister;
	ATADeviceRegisters.TransferCount		<= TransferCountRegister WHEN (TransferCountRegister_en = '0') ELSE Alias_TransferCount;

	-- debug ports
	-- ==========================================================================================================================================================
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeState(st : T_STATE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_STATE'pos(st), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
		end function;
		
	begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_GenerateStateEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_STATE loop
					STD.TextIO.write(l, str_replace(T_STATE'image(i), "st_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_generateStatusEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_FISDECODER_STATUS loop
					STD.TextIO.write(l, str_replace(T_SATA_FISDECODER_STATUS'image(i), "sata_fisd_status_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Transport Layer FIS-Decoder - FSM", dbg_GenerateStateEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/FSM_TransLayer_FISD.tok"),
				1 => dbg_ExportEncoding("Transport Layer FIS-Decoder - Status", dbg_GenerateStatusEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Trans_FISD_Status.tok")
			);
		begin
		end generate;
		
		DebugPortOut.FSM		<= dbg_EncodeState(State);
	end generate;
end;
