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
		SATA_OOB_COMWAKE
	);
	
	-- CharIsK
	SUBTYPE T_SATA_CIK2		IS STD_LOGIC_VECTOR(1 DOWNTO 0);			-- REFACTOR: to v5 gtp
	SUBTYPE T_SATA_CIK		IS STD_LOGIC_VECTOR(3 DOWNTO 0);
	
	-- transceiver commands
	TYPE T_SATA_TRANSCEIVER_COMMAND IS (
		SATA_TRANSCEIVER_CMD_NONE,
		SATA_TRANSCEIVER_CMD_POWERDOWN,
		SATA_TRANSCEIVER_CMD_POWERUP,
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

	TYPE T_SATA_CIK2_VECTOR										IS ARRAY (NATURAL RANGE <>) OF T_SATA_CIK2;			-- REFACTOR: to v5 gtp
	TYPE T_SATA_CIK_VECTOR										IS ARRAY (NATURAL RANGE <>) OF T_SATA_CIK;
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
	FUNCTION to_sata_word(Primitive : T_SATA_PRIMITIVE) RETURN T_SLV_32;
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
		SATA_CMD_RESET_LINKLAYER,					-- reset LinkLayer => send SYNC-primitive
		SATA_CMD_POWERDOWN
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

	-- ===========================================================================
	-- Component Declarations
	-- ===========================================================================
	COMPONENT sata_StreamingController IS
		GENERIC (
			SIM_WAIT_FOR_INITIAL_REGDH_FIS		: BOOLEAN                     := TRUE;      -- required by ATA/SATA standard
			SIM_EXECUTE_IDENTIFY_DEVICE				: BOOLEAN											:= TRUE;			-- required by CommandLayer: load device parameters
			DEBUG															: BOOLEAN											:= FALSE;			-- generate ChipScope DBG_* signals
			LOGICAL_BLOCK_SIZE_ldB						: POSITIVE										:= 13					-- accessable logical block size: 8 kB (independant from device)
		);
		PORT (
			Clock											: IN	STD_LOGIC;
			Reset											: IN	STD_LOGIC;
			
			-- ATAStreamingController interface
			-- ========================================================================
			Command										: IN	T_SATA_STREAMC_COMMAND;
			Status										: OUT	T_SATA_STREAMC_STATUS;
			Error											: OUT	T_SATA_STREAMC_ERROR;

			-- debug ports
--			DebugPort									: OUT	T_DBG_SATA_STREAMC_OUT;

			-- for measurement purposes only
			Config_BurstSize					: IN	T_SLV_16;
			
			-- ATA Streaming interface
			Address_AppLB							: IN	T_SLV_48;
			BlockCount_AppLB					: IN	T_SLV_48;
			
			-- TX path
			TX_Valid									: IN	STD_LOGIC;
			TX_Data										: IN	T_SLV_32;
			TX_SOR										: IN	STD_LOGIC;
			TX_EOR										: IN	STD_LOGIC;
			TX_Ready									: OUT	STD_LOGIC;
			
			-- RX path
			RX_Valid									: OUT	STD_LOGIC;
			RX_Data										: OUT	T_SLV_32;
			RX_SOR										: OUT	STD_LOGIC;
			RX_EOR										: OUT	STD_LOGIC;
			RX_Ready									: IN	STD_LOGIC;
			
			-- SATAController interface
			-- ========================================================================
			SATA_Command							: OUT	T_SATA_COMMAND;
			SATA_Status								: IN	T_SATA_STATUS;
			SATA_Error								: IN	T_SATA_ERROR;
		
			-- TX port
			SATA_TX_SOF								: OUT	STD_LOGIC;
			SATA_TX_EOF								: OUT	STD_LOGIC;
			SATA_TX_Valid							: OUT	STD_LOGIC;
			SATA_TX_Data							: OUT	T_SLV_32;
			SATA_TX_Ready							: IN	STD_LOGIC;
			SATA_TX_InsertEOF					: IN	STD_LOGIC;															-- helper signal: insert EOF - max frame size reached
			
			SATA_TX_FS_Ready					: OUT	STD_LOGIC;
			SATA_TX_FS_Valid					: IN	STD_LOGIC;
			SATA_TX_FS_SendOK					: IN	STD_LOGIC;
			SATA_TX_FS_Abort					: IN	STD_LOGIC;
			
			-- RX port
			SATA_RX_SOF								: IN	STD_LOGIC;
			SATA_RX_EOF								: IN	STD_LOGIC;
			SATA_RX_Valid							: IN	STD_LOGIC;
			SATA_RX_Data							: IN	T_SLV_32;
			SATA_RX_Ready							: OUT	STD_LOGIC;
			
			SATA_RX_FS_Ready					: OUT	STD_LOGIC;
			SATA_RX_FS_Valid					: IN	STD_LOGIC;
			SATA_RX_FS_CRC_OK					: IN	STD_LOGIC;
			SATA_RX_FS_Abort					: IN	STD_LOGIC
		);
	END COMPONENT;
	
	COMPONENT sata_SATAController IS
		GENERIC (
			DEBUG												: BOOLEAN														:= TRUE;
			CLOCK_IN_FREQ_MHZ						: REAL															:= 150.0;
			PORTS												: POSITIVE													:= 1;												-- Port 0									Port 1
			CONTROLLER_TYPES						: T_SATA_DEVICE_TYPE_VECTOR					:= T_SATA_DEVICE_TYPE_VECTOR'(0 => SATA_DEVICE_TYPE_HOST,	1 => SATA_DEVICE_TYPE_DEVICE);
			INITIAL_SATA_GENERATIONS		: T_SATA_GENERATION_VECTOR					:= T_SATA_GENERATION_VECTOR'(	0 => SATA_GENERATION_1,			1 => SATA_GENERATION_1);
			ALLOW_SPEED_NEGOTIATION			: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			ALLOW_STANDARD_VIOLATION		: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			ALLOW_AUTO_RECONNECT				: T_BOOLVEC													:= T_BOOLVEC'(								0 => TRUE,							1 => TRUE);
			OOB_TIMEOUT_US							: T_INTVEC													:= T_INTVEC'(									0 => 0,									1 => 0);
			GENERATION_CHANGE_COUNT			: T_INTVEC													:= T_INTVEC'(									0 => 8,									1 => 8);
			TRYS_PER_GENERATION					: T_INTVEC													:= T_INTVEC'(									0 => 5,									1 => 3);
			AHEAD_CYCLES_FOR_INSERT_EOF	: T_INTVEC													:= T_INTVEC'(									0 => 1,									1 => 1);
			MAX_FRAME_SIZE_B						: T_INTVEC													:= T_INTVEC'(									0 => 4 * (2048 + 1),		1 => 4 * (2048 + 1))
		);
		PORT (
			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: initialisation done
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async: reset all / hard reset
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @async: all clocks are stable
			
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			SATA_Reset								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);						-- @SATA_Clock: clock is stable
			
--			DebugPortOut							: OUT T_DBG_SATAOUT_VECTOR(PORTS - 1 DOWNTO 0);
			
			Command										: IN	T_SATA_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT T_SATA_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			Error											: OUT	T_SATA_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
			SATAGeneration            : OUT T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- TX port
			TX_SOF										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_EOF										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Valid									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_Ready									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_InsertEOF							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_FS_Ready								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_Valid								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_SendOK							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_FS_Abort								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- RX port
			RX_SOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_EOF										: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Valid									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_Ready									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			RX_FS_Ready									: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_Valid								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_CRC_OK							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RX_FS_Abort								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT sata_Transceiver_Virtex5_GTP IS
		GENERIC (
			DEBUG											: BOOLEAN											:= TRUE;																																-- generate ChipScope debugging "pins"
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		PORT (
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

--			DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
			
			-- vendor specific signals (Xilinx)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT sata_Transceiver_Virtex6_GTXE1 IS
		GENERIC (
			DEBUG											: BOOLEAN											:= TRUE;
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																									-- 150 MHz
			PORTS											: POSITIVE										:= 2;																											-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		PORT (
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS	- 1 DOWNTO 0);
			OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS	- 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);

--			DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS	- 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS	- 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
			
			-- vendor specific signals (Xilinx)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
	
	COMPONENT sata_Transceiver_Series7_GTXE2 IS
		GENERIC (
			DEBUG											: BOOLEAN											:= TRUE;
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																									-- 150 MHz
			PORTS											: POSITIVE										:= 2;																											-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		PORT (
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

			SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS	- 1 DOWNTO 0);
			OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS	- 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);

--			DebugPortOut							: OUT T_DBG_TRANSOUT_VECTOR(PORTS	- 1 DOWNTO 0);

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS	- 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS	- 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS	- 1 DOWNTO 0);
			
			-- vendor specific signals (Xilinx)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
	
	COMPONENT sata_Transceiver_Stratix2GX_GXB IS
		GENERIC (
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		PORT (
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);

--			DebugPortOut	: OUT T_DBG_TRANSOUT_VECTOR(PORTS-1 DOWNTO 0);
			
			-- vendor specific signals (Altera GXB ports)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;
	
	COMPONENT sata_Transceiver_Stratix4GX_GXB IS
		GENERIC (
			CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																																-- 150 MHz
			PORTS											: POSITIVE										:= 2;																																		-- Number of Ports per Transceiver
			INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
		);
		PORT (
			SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

			SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
			OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
			Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

			RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			RX_Data										: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
			RX_CharIsK								: OUT	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
			RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			
			TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
			TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
			TX_Data										: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
			TX_CharIsK								: IN	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);

--			DebugPortOut	: OUT T_DBG_TRANSOUT_VECTOR(PORTS-1 DOWNTO 0);
			
			-- vendor specific signals (Altera GXB ports)
			VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
			VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0);
			VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
		);
	END COMPONENT;

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
