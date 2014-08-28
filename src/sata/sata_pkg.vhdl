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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.sata_transceivertypes.all;


package sata is
	-- ===========================================================================
	-- SATA Transceiver Types
	-- ===========================================================================
	-- OOB signals (Out-Of-Band)
	TYPE T_SATA_OOB IS (
		SATA_OOB_NONE,
		SATA_OOB_READY,
		SATA_OOB_COMRESET,
		SATA_OOB_COMWAKE,
		SATA_OOB_COMSAS
	);
	
	-- transceiver commands
	TYPE T_SATA_TRANSCEIVER_COMMAND IS (
		SATA_TRANSCEIVER_CMD_NONE,
		SATA_TRANSCEIVER_CMD_RESET,
		SATA_TRANSCEIVER_CMD_RECONFIG,
		SATA_TRANSCEIVER_CMD_UNLOCK
	);
	
	-- transceiver status
	TYPE T_SATA_TRANSCEIVER_STATUS IS (
		SATA_TRANSCEIVER_STATUS_POWERED_DOWN,
		SATA_TRANSCEIVER_STATUS_RESETING,
		SATA_TRANSCEIVER_STATUS_RECONFIGURING,
		SATA_TRANSCEIVER_STATUS_RELOADING,
		SATA_TRANSCEIVER_STATUS_READY,
		SATA_TRANSCEIVER_STATUS_READY_LOCKED,
		SATA_TRANSCEIVER_STATUS_NO_DEVICE,
		SATA_TRANSCEIVER_STATUS_NEW_DEVICE,
		SATA_TRANSCEIVER_STATUS_ERROR
	);

	-- transceiver error
	TYPE T_SATA_TRANSCEIVER_ERROR IS (
		SATA_TRANSCEIVER_ERROR_NONE,
		SATA_TRANSCEIVER_ERROR_FSM
	);

	-- transmitter errors
	TYPE T_SATA_TRANSCEIVER_TX_ERROR IS (
		SATA_TRANSCEIVER_TX_ERROR_NONE,
		SATA_TRANSCEIVER_TX_ERROR_ENCODER,
		SATA_TRANSCEIVER_TX_ERROR_BUFFER
	);
	
	-- receiver errors
	TYPE T_SATA_TRANSCEIVER_RX_ERROR IS (
		SATA_TRANSCEIVER_RX_ERROR_NONE,
		SATA_TRANSCEIVER_RX_ERROR_ALIGNEMENT,
		SATA_TRANSCEIVER_RX_ERROR_DISPARITY,
		SATA_TRANSCEIVER_RX_ERROR_DECODER,
		SATA_TRANSCEIVER_RX_ERROR_BUFFER
	);

	TYPE T_SATA_OOB_VECTOR										IS ARRAY (NATURAL RANGE <>) OF T_SATA_OOB;
	TYPE T_SATA_TRANSCEIVER_COMMAND_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_SATA_TRANSCEIVER_COMMAND;
	TYPE T_SATA_TRANSCEIVER_STATUS_VECTOR			IS ARRAY (NATURAL RANGE <>) OF T_SATA_TRANSCEIVER_STATUS;
	TYPE T_SATA_TRANSCEIVER_TX_ERROR_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_SATA_TRANSCEIVER_TX_ERROR;
	TYPE T_SATA_TRANSCEIVER_RX_ERROR_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_SATA_TRANSCEIVER_RX_ERROR;

	-- ===========================================================================
	-- SATA Physical Layer Types
	-- ===========================================================================
	SUBTYPE T_SATA_GENERATION				IS INTEGER RANGE 0 TO 5;
	
	CONSTANT SATA_GENERATION_1			: T_SATA_GENERATION		:= 0;
	CONSTANT SATA_GENERATION_2			: T_SATA_GENERATION		:= 1;
	CONSTANT SATA_GENERATION_3			: T_SATA_GENERATION		:= 2;
	CONSTANT SATA_GENERATION_AUTO		: T_SATA_GENERATION		:= 4;
	CONSTANT SATA_GENERATION_ERROR	: T_SATA_GENERATION		:= 5;
	
	CONSTANT C_SATA_GENERATION_MAX	: T_SATA_GENERATION		:= SATA_GENERATION_3;
	
	TYPE T_SATA_PHY_COMMAND IS (
		SATA_PHY_CMD_NONE,					-- no command
		SATA_PHY_CMD_RESET,					-- reset retry and generation counters => reprogramm to initial configuration
		SATA_PHY_CMD_NEWLINK_UP			-- reset retry counter use same generation
	);

	TYPE T_SATA_PHY_STATUS IS (
		SATA_PHY_STATUS_RESET,
		SATA_PHY_STATUS_LINK_UP,
		SATA_PHY_STATUS_LINK_OK,
		SATA_PHY_STATUS_LINK_BROKEN,
		SATA_PHY_STATUS_RECEIVED_RESET,
		SATA_PHY_STATUS_CHANGE_SPEED,
		SATA_PHY_STATUS_ERROR							-- FIXME: unused?
	);

	-- FIXME: unused?
	TYPE T_SATA_PHY_ERROR IS (
		SATA_PHY_ERROR_NONE,
		SATA_PHY_ERROR_COMRESET,
		SATA_PHY_ERROR_LINK_DEAD,
		SATA_PHY_ERROR_NEGOTIATION_ERROR,
		SATA_PHY_ERROR_FSM
	);

	TYPE T_SGEN_SGEN								IS ARRAY (T_SATA_GENERATION) OF T_SATA_GENERATION;			-- REFACTOR:
	TYPE T_SGEN2_SGEN								IS ARRAY (T_SATA_GENERATION) OF T_SGEN_SGEN;						-- REFACTOR:
	TYPE T_SGEN3_SGEN								IS ARRAY (T_SATA_GENERATION) OF T_SGEN2_SGEN;						-- REFACTOR:
	
	TYPE T_SGEN_INT									IS ARRAY (T_SATA_GENERATION) OF INTEGER;								-- REFACTOR:
	TYPE T_SGEN2_INT								IS ARRAY (T_SATA_GENERATION) OF T_SGEN_INT;							-- REFACTOR:
	
	TYPE T_SATA_GENERATION_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_SATA_GENERATION;
	TYPE T_SATA_PHY_COMMAND_VECTOR	IS ARRAY (NATURAL RANGE <>) OF T_SATA_PHY_COMMAND;
	TYPE T_SATA_PHY_STATUS_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_SATA_PHY_STATUS;
	TYPE T_SATA_PHY_ERROR_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_SATA_PHY_ERROR;

	-- ===========================================================================
	-- SATA Link Layer Types
	-- ===========================================================================
	TYPE T_SATA_LINK_COMMAND IS (
		SATA_LINK_CMD_NONE,
		SATA_LINK_CMD_RESET
	);

	TYPE T_SATA_LINK_STATUS IS (
		SATA_LINK_STATUS_IDLE,
		SATA_LINK_STATUS_SENDING,
		SATA_LINK_STATUS_RECEIVING,
		SATA_LINK_STATUS_COMMUNICATION_ERROR,
		SATA_LINK_STATUS_ERROR
	);
	
	TYPE T_SATA_LINK_ERROR IS (
		SATA_LINK_ERROR_NONE,
		SATA_LINK_ERROR_PHY_COMRESET,
		SATA_LINK_ERROR_PHY_8B10B_ERROR,
		SATA_LINK_ERROR_LINK_RXFIFO_FULL,
		SATA_LINK_ERROR_LINK_FSM
	);
	
	TYPE T_SATA_PRIMITIVE IS (					-- Primitive Name				Byte 3,	Byte 2,	Byte 1,	Byte 0
		SATA_PRIMITIVE_NONE,							-- no primitive
		SATA_PRIMITIVE_ALIGN,							-- ALIGN								D27.3,	D10.2,	D10.2,	K28.5
		SATA_PRIMITIVE_SYNC,							-- SYNC									D21.5,	D21.5,	D21.4,	K28.3
		SATA_PRIMITIVE_DIAL_TONE,					-- D10.2								D10.2,	D10.2,	D10.2,	D10.2
		SATA_PRIMITIVE_SOF,								-- SOF									D23.1,	D23.1,	D21.5,	K28.3
		SATA_PRIMITIVE_EOF,								-- EOF									D21.6,	D21.6,	D21.5,	K28.3
		SATA_PRIMITIVE_HOLD,							-- HOLD									D21.6,	D21.6,	D10.5,	K28.3
		SATA_PRIMITIVE_HOLD_ACK,					-- HOLDA								D21.4,	D21.4,	D10.5,	K28.3
		SATA_PRIMITIVE_CONT,							-- CONT									D25.4,	D25.4,	D10.5,	K28.3
		SATA_PRIMITIVE_R_OK,							-- R_OK									D21.1,	D21.1,	D21.5,	K28.3
		SATA_PRIMITIVE_R_ERROR,						-- R_ERR								D22.2,	D22.2,	D21.5,	K28.3
		SATA_PRIMITIVE_R_IP,							-- R_IP									D21.2,	D21.2,	D21.5,	K28.3
		SATA_PRIMITIVE_RX_RDY,						-- R_RDY								D10.2,	D10.2,	D21.4,	K28.3
		SATA_PRIMITIVE_TX_RDY,						-- X_RDY								D23.2,	D23.2,	D21.5,	K28.3
		SATA_PRIMITIVE_DMA_TERM,					-- DMAT									D22.1,	D22.1,	D21.5,	K28.3
		SATA_PRIMITIVE_WAIT_TERM,					-- WTRM									D24.2,	D24.2,	D21.5,	K28.3
		SATA_PRIMITIVE_PM_ACK,						-- PMACK								D
		SATA_PRIMITIVE_PM_NACK,						-- PMNAK								D
		SATA_PRIMITIVE_PM_REQ_P,					-- PMREQ_P							D	
		SATA_PRIMITIVE_PM_REQ_S,					-- PMREQ_S							D	
		SATA_PRIMITIVE_ILLEGAL
	);
	CONSTANT T_SATA_PRIMITIVE_COUNT		: INTEGER										:= T_SATA_PRIMITIVE'pos(SATA_PRIMITIVE_ILLEGAL) + 1;

	CONSTANT SATA_MAX_FRAMESIZE_B			: POSITIVE									:= 8192;
	CONSTANT SATA_WORD_BITS						: POSITIVE									:= 32;

	TYPE T_SATA_LINK_COMMAND_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_SATA_LINK_COMMAND;
	TYPE T_SATA_LINK_STATUS_VECTOR		IS ARRAY (NATURAL RANGE <>) OF T_SATA_LINK_STATUS;
	TYPE T_SATA_LINK_ERROR_VECTOR			IS ARRAY (NATURAL RANGE <>) OF T_SATA_LINK_ERROR;

	FUNCTION to_slv(Primitive : T_SATA_PRIMITIVE)				RETURN STD_LOGIC_VECTOR;
	FUNCTION to_sata_word(Primitive : T_SATA_PRIMITIVE)	RETURN T_SLV_32;
	function to_sata_primitive(Data : T_SLV_32; CharIsK : T_SLV_4; DetectDialTone : BOOLEAN := FALSE)	return T_SATA_PRIMITIVE;
	
	-- ===========================================================================
	-- Common SATA Types
	-- ===========================================================================
	TYPE T_SATA_DEVICE_TYPE IS (
		SATA_DEVICE_TYPE_HOST,
		SATA_DEVICE_TYPE_DEVICE
	);

	TYPE T_SATA_DEVICE_TYPE_VECTOR		IS ARRAY (NATURAL RANGE <>) OF  T_SATA_DEVICE_TYPE;	
	-- ===========================================================================
	-- SATA Controller Types
	-- ===========================================================================
	TYPE T_SATA_COMMAND IS (
		SATA_CMD_NONE,
		SATA_CMD_RESET,
		SATA_CMD_RESET_CONNECTION,				-- invoke COMRESET / COMINIT
		SATA_CMD_RESET_LINKLAYER					-- reset LinkLayer => send SYNC-primitive
	);

	TYPE T_SATA_STATUS IS RECORD
		LinkLayer							: T_SATA_LINK_STATUS;
		PhysicalLayer					: T_SATA_PHY_STATUS;
		TransceiverLayer			: T_SATA_TRANSCEIVER_STATUS;
	END RECORD;
	
	TYPE T_SATA_ERROR IS RECORD
		LinkLayer							: T_SATA_LINK_ERROR;
		PhysicalLayer					: T_SATA_PHY_ERROR;
		TransceiverLayer_TX		: T_SATA_TRANSCEIVER_TX_ERROR;
		TransceiverLayer_RX		: T_SATA_TRANSCEIVER_RX_ERROR;
	END RECORD;

	
	TYPE T_SATA_COMMAND_VECTOR				IS ARRAY (NATURAL RANGE <>) OF  T_SATA_COMMAND;
	TYPE T_SATA_STATUS_VECTOR					IS ARRAY (NATURAL RANGE <>) OF  T_SATA_STATUS;
	TYPE T_SATA_ERROR_VECTOR					IS ARRAY (NATURAL RANGE <>) OF  T_SATA_ERROR;

	-- ===========================================================================
	-- ATA Command Layer Types
	-- ===========================================================================
	TYPE T_SATA_CMD_COMMAND IS (
		SATA_CMD_CMD_NONE,
		SATA_CMD_CMD_RESET,
		SATA_CMD_CMD_READ,
		SATA_CMD_CMD_WRITE,
		SATA_CMD_CMD_FLUSH_CACHE,
		SATA_CMD_CMD_IDENTIFY_DEVICE,
		SATA_CMD_CMD_ABORT
	);

	TYPE T_SATA_CMD_STATUS IS (
		SATA_CMD_STATUS_RESET,
		SATA_CMD_STATUS_INITIALIZING,
		SATA_CMD_STATUS_IDLE,
		SATA_CMD_STATUS_SENDING,
		SATA_CMD_STATUS_RECEIVING,
		SATA_CMD_STATUS_EXECUTING,
		SATA_CMD_STATUS_ABORTING,
		SATA_CMD_STATUS_ERROR
	);
	
	TYPE T_SATA_CMD_ERROR IS (
		SATA_CMD_ERROR_NONE,
		SATA_CMD_ERROR_IDENTIFY_DEVICE_ERROR,
		SATA_CMD_ERROR_DEVICE_NOT_SUPPORTED,
		SATA_CMD_ERROR_TRANSPORT_ERROR,
		SATA_CMD_ERROR_REQUEST_INCOMPLETE,
		SATA_CMD_ERROR_FSM												-- ILLEGAL_TRANSITION
	);
	
	TYPE T_SATA_ATA_COMMAND IS (
		SATA_ATA_CMD_NONE,
		SATA_ATA_CMD_IDENTIFY_DEVICE,
		SATA_ATA_CMD_DMA_READ_EXT,
		SATA_ATA_CMD_DMA_WRITE_EXT,
		SATA_ATA_CMD_FLUSH_CACHE_EXT,
		SATA_ATA_CMD_UNKNOWN
	);
	
	-- ===========================================================================
	-- SATA Transport Layer Types
	-- ===========================================================================
	TYPE T_SATA_TRANS_COMMAND IS (
		SATA_TRANS_CMD_NONE,
		SATA_TRANS_CMD_RESET,
		SATA_TRANS_CMD_TRANSFER,
		SATA_TRANS_CMD_ABORT
	);

	TYPE T_SATA_TRANS_STATUS IS (
		SATA_TRANS_STATUS_RESET,
		SATA_TRANS_STATUS_IDLE,
		SATA_TRANS_STATUS_TRANSFERING,
		SATA_TRANS_STATUS_TRANSFERING_DISCONTINUED,
		SATA_TRANS_STATUS_TRANSFER_OK,
		SATA_TRANS_STATUS_ERROR
	);
	
	TYPE T_SATA_TRANS_ERROR IS (
		SATA_TRANS_ERROR_NONE,
		SATA_TRANS_ERROR_FISENCODER,
		SATA_TRANS_ERROR_FISDECODER,
		SATA_TRANS_ERROR_TRANSMIT_ERROR,
		SATA_TRANS_ERROR_RECEIVE_ERROR,
		SATA_TRANS_ERROR_DEVICE_ERROR,
		SATA_TRANS_ERROR_INCOMPLETE,
		SATA_TRANS_ERROR_FSM												-- ILLEGAL_TRANSITION
	);

	TYPE T_SATA_COMMAND_CATEGORY IS (
		SATA_CMDCAT_NON_DATA,
		SATA_CMDCAT_PIO_IN,
		SATA_CMDCAT_PIO_OUT,
		SATA_CMDCAT_DMA_IN,
		SATA_CMDCAT_DMA_OUT,
		SATA_CMDCAT_DMA_IN_QUEUED,
		SATA_CMDCAT_DMA_OUT_QUEUED,
		SATA_CMDCAT_PACKET,
		SATA_CMDCAT_SERVICE,
		SATA_CMDCAT_DEVICE_RESET,
		SATA_CMDCAT_DEVICE_DIAGNOSTICS,
		SATA_CMDCAT_UNKNOWN
	);
	
	TYPE T_SATA_FISTYPE IS (
		SATA_FISTYPE_UNKNOWN,
		SATA_FISTYPE_REG_HOST_DEV,
		SATA_FISTYPE_REG_DEV_HOST,
		SATA_FISTYPE_SET_DEV_BITS,
		SATA_FISTYPE_DMA_ACTIVATE,
		SATA_FISTYPE_DMA_SETUP,
		SATA_FISTYPE_BIST,
		SATA_FISTYPE_PIO_SETUP,
		SATA_FISTYPE_DATA
	);

	TYPE T_SATA_FISENCODER_STATUS IS (
		SATA_FISE_STATUS_IDLE,
		SATA_FISE_STATUS_SENDING,
		SATA_FISE_STATUS_SENDING_DISCONTINUED,
		SATA_FISE_STATUS_SEND_OK,
		SATA_FISE_STATUS_ERROR
	);
	
	TYPE T_SATA_FISDECODER_STATUS IS (
		SATA_FISD_STATUS_IDLE,
		SATA_FISD_STATUS_RECEIVING,
		SATA_FISD_STATUS_CHECKING_CRC,
		SATA_FISD_STATUS_DISCARD_FRAME,
		SATA_FISD_STATUS_RECEIVE_OK,
		SATA_FISD_STATUS_ERROR,
		SATA_FISD_STATUS_CRC_ERROR
	);
	
	TYPE T_SATA_ATA_HOST_REGISTERS IS RECORD
		Flag_C						: STD_LOGIC;
		Command						: T_SLV_8;
		Control						: T_SLV_8;
		Feature						: T_SLV_8;
		LBlockAddress			: T_SLV_48;
		SectorCount				: T_SLV_16;
	END RECORD;
	
	TYPE T_SATA_ATA_DEVICE_FLAGS IS RECORD
		Interrupt					: STD_LOGIC;
		Direction					: STD_LOGIC;
		C									: STD_LOGIC;
	END RECORD;
	
	TYPE T_SATA_ATA_DEVICE_REGISTER_STATUS IS RECORD
		Error							: STD_LOGIC;
		DataRequest				: STD_LOGIC;
		DeviceFault				: STD_LOGIC;
		DataReady					: STD_LOGIC;
		Busy							: STD_LOGIC;
	END RECORD;
	
	TYPE T_SATA_ATA_DEVICE_REGISTER_ERROR IS RECORD
		NoMediaPresent				: STD_LOGIC;
		CommandAborted				: STD_LOGIC;
		MediaChangeRequest		: STD_LOGIC;
		IDNotFound						: STD_LOGIC;
		MediaChange						: STD_LOGIC;
		UncorrectableError		: STD_LOGIC;
		InterfaceCRCError			: STD_LOGIC;
	END RECORD;
	
	TYPE T_SATA_ATA_DEVICE_REGISTERS IS RECORD
		Flags							: T_SATA_ATA_DEVICE_FLAGS;
		Status						: T_SATA_ATA_DEVICE_REGISTER_STATUS;
		EndStatus					: T_SATA_ATA_DEVICE_REGISTER_STATUS;
		Error							: T_SATA_ATA_DEVICE_REGISTER_ERROR;
		LBlockAddress			: T_SLV_48;
		SectorCount				: T_SLV_16;
		TransferCount			: T_SLV_16;
	END RECORD;
	
	TYPE T_SATA_HOST_REGISTER_STATUS IS RECORD
		Detect						: T_SLV_4;
		Speed							: T_SLV_4;
		PowerManagement		: T_SLV_4;
		-- reserved				: T_SLV_20
	END RECORD;

	TYPE T_SATA_HOST_REGISTER_ERROR IS RECORD
		-- error field
		DataIntegrityError						: STD_LOGIC;
		LinkCommunicationError				: STD_LOGIC;
		TransientDataIntegrityError		: STD_LOGIC;
		CommunicationError						: STD_LOGIC;
		ProtocolError									: STD_LOGIC;
		InternalError									: STD_LOGIC;
		
		-- diagnostic field
		PhyReadyChanged								: STD_LOGIC;
		InternalPhyError							: STD_LOGIC;
		COMWAKEDetected								: STD_LOGIC;
		DecodedError									: STD_LOGIC;
		DisparityError								: STD_LOGIC;
		CRCError											: STD_LOGIC;
		HandshakeError								: STD_LOGIC;
		LinkSequenceError							: STD_LOGIC;
		TransportStateTransitionError	: STD_LOGIC;
		FISUnrecognized								: STD_LOGIC;
		Exchanged											: STD_LOGIC;
		PortSelectorDetected					: STD_LOGIC;
	END RECORD;
	
	TYPE T_SATA_HOST_REGISTERS IS RECORD
		Status				: T_SATA_HOST_REGISTER_STATUS;
		Error					: T_SATA_HOST_REGISTER_ERROR;
	END RECORD;
	
	CONSTANT C_SATA_ATA_MAX_BLOCKCOUNT			: POSITIVE				:= 2**16; 			--	= 32 MiB at 512 Bytes logical blocks
	CONSTANT C_SIM_MAX_BLOCKCOUNT						: POSITIVE				:= 64; 					--	= 32 KiB at 512 Bytes logical blocks
	
	-- ===========================================================================
	-- SATA StreamingController types
	-- ===========================================================================
	TYPE T_SATA_STREAMC_COMMAND IS (
		SATA_STREAMC_CMD_NONE,
		SATA_STREAMC_CMD_RESET,
		SATA_STREAMC_CMD_READ,
		SATA_STREAMC_CMD_WRITE,
		SATA_STREAMC_CMD_FLUSH_CACHE,
		SATA_STREAMC_CMD_ABORT
	);

	TYPE T_SATA_STREAMC_STATUS IS RECORD
		CommandLayer			: T_SATA_CMD_STATUS;
		TransportLayer		: T_SATA_TRANS_STATUS;
	END RECORD;
	
	TYPE T_SATA_STREAMC_ERROR IS RECORD
		CommandLayer			: T_SATA_CMD_ERROR;
		TransportLayer		: T_SATA_TRANS_ERROR;
	END RECORD;
	
	-- ===========================================================================
	-- ATA Drive Information
	-- ===========================================================================
	TYPE T_SATA_ATA_CAPABILITY IS RECORD
		SupportsDMA								: STD_LOGIC;
		SupportsLBA								: STD_LOGIC;
		Supports48BitLBA					: STD_LOGIC;
		SupportsSMART							: STD_LOGIC;
		SupportsFLUSH_CACHE				: STD_LOGIC;
		SupportsFLUSH_CACHE_EXT		: STD_LOGIC;
	END RECORD;
	
	TYPE T_SATA_SATA_CAPABILITY IS RECORD
		SupportsNCQ								: STD_LOGIC;
		SATAGenerationMin					: T_SATA_GENERATION;
		SATAGenerationMax					: T_SATA_GENERATION;
	END RECORD;
	
	TYPE T_SATA_DRIVE_INFORMATION IS RECORD
		DriveName									: T_RAWSTRING(0 TO 39);
		DriveSize_LB							: UNSIGNED(63 DOWNTO 0); -- unit is Drive Logical Blocks (DevLB)
		PhysicalBlockSize_ldB			: UNSIGNED(7 DOWNTO 0);  -- log_2(size_in_bytes)
		LogicalBlockSize_ldB			: UNSIGNED(7 DOWNTO 0);  -- log_2(DevLB_size_in_bytes)
		ATACapabilityFlags				: T_SATA_ATA_CAPABILITY;
		SATACapabilityFlags				: T_SATA_SATA_CAPABILITY;
		
		Valid											: STD_LOGIC;
	END RECORD;
	
	
	-- to_slv
	-- ===========================================================================
	function to_slv(SATAGen : T_SATA_GENERATION)							return STD_LOGIC_VECTOR;
	function to_slv(FISType : T_SATA_FISTYPE)									return STD_LOGIC_VECTOR;
	function to_slv(Command : T_SATA_ATA_COMMAND)							return STD_LOGIC_VECTOR;
	function to_slv(reg : T_SATA_ATA_DEVICE_FLAGS)						return STD_LOGIC_VECTOR;
	function to_slv(reg : T_SATA_ATA_DEVICE_REGISTER_STATUS)	return STD_LOGIC_VECTOR;
	function to_slv(reg	: T_SATA_ATA_DEVICE_REGISTER_ERROR)		return STD_LOGIC_VECTOR;
	
	function to_sata_generation(slv : STD_LOGIC_VECTOR)	return T_SATA_GENERATION;
	FUNCTION to_sata_fistype(slv : T_SLV_8; valid : STD_LOGIC := '1') RETURN T_SATA_FISTYPE;
	FUNCTION to_sata_ata_command(slv : T_SLV_8) RETURN T_SATA_ATA_COMMAND;
	FUNCTION to_sata_cmdcat(cmd : T_SATA_ATA_COMMAND) RETURN T_SATA_COMMAND_CATEGORY;
	FUNCTION is_lba48_command(cmd : T_SATA_ATA_COMMAND) RETURN STD_LOGIC;
	FUNCTION to_sata_ata_device_flags(slv : T_SLV_8) RETURN T_SATA_ATA_DEVICE_FLAGS;
	FUNCTION to_sata_ata_device_register_status(slv : T_SLV_8) RETURN T_SATA_ATA_DEVICE_REGISTER_STATUS;
	FUNCTION to_sata_ata_device_register_error(slv : T_SLV_8) RETURN T_SATA_ATA_DEVICE_REGISTER_ERROR;

END;

PACKAGE BODY sata IS
	-- to_slv
	-- ===========================================================================
	function to_slv(SATAGen : T_SATA_GENERATION) return STD_LOGIC_VECTOR is
	begin
		return std_logic_vector(to_unsigned(SATAGen, 2));
	end function;

	FUNCTION to_slv(Primitive : T_SATA_PRIMITIVE) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN to_slv(T_SATA_PRIMITIVE'pos(Primitive), log2ceilnz(T_SATA_PRIMITIVE'pos(T_SATA_PRIMITIVE'high)));
	END FUNCTION;
	
	FUNCTION to_sata_word(Primitive : T_SATA_PRIMITIVE) RETURN T_SLV_32 IS	--																							K symbol
	BEGIN																															-- primitive name				Byte 3	Byte 2	Byte 1	Byte 0
		CASE Primitive IS																								-- =======================================================
			WHEN SATA_PRIMITIVE_NONE =>				RETURN x"00000000";					-- no primitive					
			WHEN SATA_PRIMITIVE_ALIGN =>			RETURN x"7B4A4ABC";					-- ALIGN								D27.3,	D10.2,	D10.2,	K28.5
			WHEN SATA_PRIMITIVE_SYNC =>				RETURN x"B5B5957C";					-- SYNC									D21.5,	D21.5,	D21.4,	K28.3
			WHEN SATA_PRIMITIVE_SOF =>				RETURN x"3737B57C";					-- SOF									D23.1,	D23.1,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_EOF =>				RETURN x"D5D5B57C";					-- EOF									D21.6,	D21.6,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_HOLD =>				RETURN x"D5D5AA7C";					-- HOLD									D21.6,	D21.6,	D10.5,	K28.3
			WHEN SATA_PRIMITIVE_HOLD_ACK =>		RETURN x"9595AA7C";					-- HOLDA								D21.4,	D21.4,	D10.5,	K28.3
			WHEN SATA_PRIMITIVE_CONT =>				RETURN x"9999AA7C";					-- CONT									D25.4,	D25.4,	D10.5,	K28.3
			WHEN SATA_PRIMITIVE_R_OK =>				RETURN x"3535B57C";					-- R_OK									D21.1,	D21.1,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_R_ERROR =>		RETURN x"5656B57C";					-- R_ERR								D22.2,	D22.2,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_R_IP =>				RETURN x"5555B57C";					-- R_IP									D21.2,	D21.2,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_RX_RDY =>			RETURN x"4A4A957C";					-- R_RDY								D10.2,	D10.2,	D21.4,	K28.3
			WHEN SATA_PRIMITIVE_TX_RDY =>			RETURN x"5757B57C";					-- X_RDY								D23.2,	D23.2,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_DMA_TERM =>		RETURN x"3636B57C";					-- DMAT									D22.1,	D22.1,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_WAIT_TERM =>	RETURN x"5858B57C";					-- WTRM									D24.2,	D24.2,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_PM_ACK =>			RETURN x"9595957C";					-- PMACK								D21.4,	D21.4,	D21.4,	K28.3
			WHEN SATA_PRIMITIVE_PM_NACK =>		RETURN x"F5F5957C";					-- PMNAK								D21.7,	D21.7,	D21.4,	K28.3
			WHEN SATA_PRIMITIVE_PM_REQ_P =>		RETURN x"1717B57C";					-- PMREQ_P							D23.0,	D23.0,	D21.5,	K28.3
			WHEN SATA_PRIMITIVE_PM_REQ_S =>		RETURN x"7575957C";					-- PMREQ_S							D21.3,	D21.3,	D21.4,	K28.3
			WHEN SATA_PRIMITIVE_DIAL_TONE =>	RETURN x"4A4A4A4A";					-- 											D10.2,	D10.2,	D10.2,	D10.2
			WHEN SATA_PRIMITIVE_ILLEGAL =>		RETURN (OTHERS => 'X');			-- "ERROR"
		END CASE;
	END;
	
	function to_sata_primitive(Data : T_SLV_32; CharIsK : T_SLV_4; DetectDialTone : BOOLEAN := FALSE) return T_SATA_PRIMITIVE is
	begin
		if (CharIsK = "0000") then
			if (DetectDialTone AND (Data = to_sata_word(SATA_PRIMITIVE_DIAL_TONE))) then
				return SATA_PRIMITIVE_DIAL_TONE;
			else
				return SATA_PRIMITIVE_NONE;
			end if;
		elsif (CharIsK = "0001") then
			for i in T_SATA_PRIMITIVE loop
				if (Data = to_sata_word(i)) then
					return i;
				end if;
			end loop;
		end if;

		return SATA_PRIMITIVE_ILLEGAL;
	end function;
	
	function to_sata_generation(slv : STD_LOGIC_VECTOR) return T_SATA_GENERATION is
	begin
		return to_integer(unsigned(slv));
	end function;

	FUNCTION to_slv(FISType : T_SATA_FISTYPE) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		CASE FISType IS
			WHEN SATA_FISTYPE_REG_HOST_DEV		=> RETURN	x"27";
			WHEN SATA_FISTYPE_REG_DEV_HOST		=> RETURN	x"34";
			WHEN SATA_FISTYPE_SET_DEV_BITS		=> RETURN	x"A1";
			WHEN SATA_FISTYPE_DMA_ACTIVATE		=> RETURN	x"39";
			WHEN SATA_FISTYPE_DMA_SETUP				=> RETURN	x"41";
			WHEN SATA_FISTYPE_BIST						=> RETURN	x"58";
			WHEN SATA_FISTYPE_PIO_SETUP				=> RETURN	x"5F";
			WHEN SATA_FISTYPE_DATA						=> RETURN	x"46";
			WHEN SATA_FISTYPE_UNKNOWN					=> RETURN x"00";
		END CASE;
	END;

	FUNCTION to_slv(Command : T_SATA_ATA_COMMAND) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		CASE Command IS
			WHEN SATA_ATA_CMD_NONE =>							RETURN x"00";
			WHEN SATA_ATA_CMD_IDENTIFY_DEVICE =>	RETURN x"EC";
			WHEN SATA_ATA_CMD_DMA_READ_EXT =>			RETURN x"25";
			WHEN SATA_ATA_CMD_DMA_WRITE_EXT =>		RETURN x"35";
			WHEN SATA_ATA_CMD_FLUSH_CACHE_EXT =>	RETURN x"EA";
			WHEN OTHERS =>												RETURN x"00";
		END CASE;
	END;

	-- to_*
	-- ===========================================================================
	FUNCTION to_sata_fistype(slv : T_SLV_8; valid : STD_LOGIC := '1') RETURN T_SATA_FISTYPE IS
	BEGIN
		IF (valid = '1') THEN
			FOR I IN T_SATA_FISTYPE LOOP
				IF (slv = to_slv(I)) THEN
					RETURN I;
				END IF;
			END LOOP;
		END IF;
		RETURN SATA_FISTYPE_UNKNOWN;
	END;
	
	FUNCTION to_sata_ata_command(slv : T_SLV_8) RETURN T_SATA_ATA_COMMAND IS
	BEGIN
		FOR I IN T_SATA_ATA_COMMAND LOOP
			IF (slv = to_slv(I)) THEN
				RETURN I;
			END IF;
		END LOOP;
		RETURN SATA_ATA_CMD_NONE;
	END;
	
	FUNCTION to_sata_cmdcat(cmd : T_SATA_ATA_COMMAND) RETURN T_SATA_COMMAND_CATEGORY IS
	BEGIN
		CASE cmd IS
			-- non-data commands
			WHEN SATA_ATA_CMD_FLUSH_CACHE_EXT =>		RETURN SATA_CMDCAT_NON_DATA;
			
			-- PIO data-in commands
			WHEN SATA_ATA_CMD_IDENTIFY_DEVICE =>		RETURN SATA_CMDCAT_PIO_IN;
			
			-- PIO data-out commands
			
			-- DMA data-in commands
			WHEN SATA_ATA_CMD_DMA_READ_EXT =>				RETURN SATA_CMDCAT_DMA_IN;
			
			-- DMA data-out commands
			WHEN SATA_ATA_CMD_DMA_WRITE_EXT =>			RETURN SATA_CMDCAT_DMA_OUT;
			
			-- other enum members
			WHEN SATA_ATA_CMD_NONE =>								RETURN SATA_CMDCAT_UNKNOWN;
			WHEN SATA_ATA_CMD_UNKNOWN =>						RETURN SATA_CMDCAT_UNKNOWN;
			WHEN OTHERS =>													RETURN SATA_CMDCAT_UNKNOWN;
		END CASE;
	END;
	
	FUNCTION is_lba48_command(cmd : T_SATA_ATA_COMMAND) RETURN STD_LOGIC IS
	BEGIN
		CASE cmd IS
			-- non-data commands
			WHEN SATA_ATA_CMD_FLUSH_CACHE_EXT =>	RETURN '0';
			
			-- PIO data-in commands
			WHEN SATA_ATA_CMD_IDENTIFY_DEVICE =>	RETURN '0';
			
			-- PIO data-out commands
			
			-- DMA data-in commands
			WHEN SATA_ATA_CMD_DMA_READ_EXT =>			RETURN '1';
			
			-- DMA data-out commands
			WHEN SATA_ATA_CMD_DMA_WRITE_EXT =>		RETURN '1';
			
			-- other enum members
			WHEN SATA_ATA_CMD_NONE =>							RETURN '0';
			WHEN SATA_ATA_CMD_UNKNOWN =>					RETURN '0';
			WHEN OTHERS =>												RETURN '0';
		END CASE;
	END;
	
	FUNCTION to_sata_ata_device_register_status(slv : T_SLV_8) RETURN T_SATA_ATA_DEVICE_REGISTER_STATUS IS
		VARIABLE Result				: T_SATA_ATA_DEVICE_REGISTER_STATUS;
	BEGIN
		Result.Error					:= slv(0);
		Result.DataRequest		:= slv(3);
		Result.DeviceFault		:= slv(5);
		Result.DataReady			:= slv(6);
		Result.Busy						:= slv(7);
		
		Return Result;
	END;
	
	FUNCTION to_slv(reg : T_SATA_ATA_DEVICE_REGISTER_STATUS) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result				: T_SLV_8		:= (OTHERS => '0');
	BEGIN
		Result(0)							:= reg.Error;
		Result(3)							:= reg.DataRequest;
		Result(5)							:= reg.DeviceFault;
		Result(6)							:= reg.DataReady;
		Result(7)							:= reg.Busy;
		
		Return Result;
	END;
	
	FUNCTION to_sata_ata_device_register_error(slv : T_SLV_8) RETURN T_SATA_ATA_DEVICE_REGISTER_ERROR IS
		VARIABLE Result							: T_SATA_ATA_DEVICE_REGISTER_ERROR;
	BEGIN
		Result.NoMediaPresent				:= slv(1);
		Result.CommandAborted				:= slv(2);
		Result.MediaChangeRequest		:= slv(3);
		Result.IDNotFound						:= slv(4);
		Result.MediaChange					:= slv(5);
		Result.UncorrectableError		:= slv(6);
		Result.InterfaceCRCError		:= slv(7);
		
		Return Result;
	END;
	
	FUNCTION to_slv(reg	: T_SATA_ATA_DEVICE_REGISTER_ERROR) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result							: T_SLV_8			:= (OTHERS => '0');
	BEGIN
		Result(1)										:= reg.NoMediaPresent;
		Result(2)										:= reg.CommandAborted;
		Result(3)										:= reg.MediaChangeRequest;
		Result(4)										:= reg.IDNotFound;
		Result(5)										:= reg.MediaChange;
		Result(6)										:= reg.UncorrectableError;
		Result(7)										:= reg.InterfaceCRCError;
		
		Return Result;
	END;
	
	FUNCTION to_sata_ata_device_flags(slv : T_SLV_8) RETURN T_SATA_ATA_DEVICE_FLAGS IS
		VARIABLE Result							: T_SATA_ATA_DEVICE_FLAGS;
	BEGIN
		Result.Direction						:= slv(5);
		Result.Interrupt						:= slv(6);
		Result.C										:= slv(7);
		
		Return Result;
	END;
	
	FUNCTION to_slv(reg	: T_SATA_ATA_DEVICE_FLAGS) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result							: T_SLV_8			:= (OTHERS => '0');
	BEGIN
		Result(5)										:= reg.Direction;
		Result(6)										:= reg.Interrupt;
		Result(7)										:= reg.C;
		
		Return Result;
	END;

END PACKAGE BODY;
