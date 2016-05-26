-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Package:					SATA Types, Constants and Functions
--
-- Description:
-- ------------------------------------
-- Declares types and functions required for the whole SATA stack.
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
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.sata_TransceiverTypes.all;


package sata is
	-- ===========================================================================
	-- SATA Transceiver Types
	-- ===========================================================================
	-- OOB signals (Out-Of-Band)
	type T_SATA_OOB is (
		SATA_OOB_NONE,
		SATA_OOB_READY,
		SATA_OOB_COMRESET,
		SATA_OOB_COMWAKE,
		SATA_OOB_COMSAS
	);

	-- transceiver commands
	type T_SATA_TRANSCEIVER_COMMAND is (
		SATA_TRANSCEIVER_CMD_NONE,
		SATA_TRANSCEIVER_CMD_RECONFIG,
		SATA_TRANSCEIVER_CMD_UNLOCK
	);

	-- transceiver status
	-- Only common errors are signaled via STATUS_ERROR, not TX/RX encoder errors.
	type T_SATA_TRANSCEIVER_STATUS is (
		SATA_TRANSCEIVER_STATUS_INIT,
		SATA_TRANSCEIVER_STATUS_RECONFIGURING,
		SATA_TRANSCEIVER_STATUS_RELOADING,
		SATA_TRANSCEIVER_STATUS_READY,
		SATA_TRANSCEIVER_STATUS_READY_LOCKED,
		SATA_TRANSCEIVER_STATUS_ERROR
	);

	-- transceiver error
	type T_SATA_TRANSCEIVER_COMMON_ERROR is (
		SATA_TRANSCEIVER_ERROR_NONE,
		SATA_TRANSCEIVER_ERROR_FSM
	);

	-- transmitter errors
	type T_SATA_TRANSCEIVER_TX_ERROR is (
		SATA_TRANSCEIVER_TX_ERROR_NONE,
		SATA_TRANSCEIVER_TX_ERROR_ENCODER,
		SATA_TRANSCEIVER_TX_ERROR_BUFFER
	);

	-- receiver errors
	type T_SATA_TRANSCEIVER_RX_ERROR is (
		SATA_TRANSCEIVER_RX_ERROR_NONE,
		SATA_TRANSCEIVER_RX_ERROR_ALIGNEMENT,
		SATA_TRANSCEIVER_RX_ERROR_DISPARITY,
		SATA_TRANSCEIVER_RX_ERROR_DECODER,
		SATA_TRANSCEIVER_RX_ERROR_BUFFER
	);

	type T_SATA_TRANSCEIVER_ERROR is record
		Common	: T_SATA_TRANSCEIVER_COMMON_ERROR;
		TX			: T_SATA_TRANSCEIVER_TX_ERROR;
		RX			: T_SATA_TRANSCEIVER_RX_ERROR;
	end record;

	type T_SATA_OOB_VECTOR										is array (NATURAL range <>) of T_SATA_OOB;
	type T_SATA_TRANSCEIVER_COMMAND_VECTOR		is array (NATURAL range <>) of T_SATA_TRANSCEIVER_COMMAND;
	type T_SATA_TRANSCEIVER_STATUS_VECTOR			is array (NATURAL range <>) of T_SATA_TRANSCEIVER_STATUS;
	type T_SATA_TRANSCEIVER_ERROR_VECTOR			is array (NATURAL range <>) of T_SATA_TRANSCEIVER_ERROR;
	type T_SATA_TRANSCEIVER_TX_ERROR_VECTOR		is array (NATURAL range <>) of T_SATA_TRANSCEIVER_TX_ERROR;
	type T_SATA_TRANSCEIVER_RX_ERROR_VECTOR		is array (NATURAL range <>) of T_SATA_TRANSCEIVER_RX_ERROR;

	function to_slv(Command : T_SATA_TRANSCEIVER_COMMAND)			return STD_LOGIC_VECTOR;
	function to_slv(Status : T_SATA_TRANSCEIVER_STATUS)				return STD_LOGIC_VECTOR;
	function to_slv(Error : T_SATA_TRANSCEIVER_COMMON_ERROR)	return STD_LOGIC_VECTOR;

	-- ===========================================================================
	-- SATA Physical Layer Types
	-- ===========================================================================
	subtype T_SATA_GENERATION				is INTEGER range 0 TO 5;

	constant SATA_GENERATION_1			: T_SATA_GENERATION		:= 0;
	constant SATA_GENERATION_2			: T_SATA_GENERATION		:= 1;
	constant SATA_GENERATION_3			: T_SATA_GENERATION		:= 2;
	constant SATA_GENERATION_AUTO		: T_SATA_GENERATION		:= 4;
	constant SATA_GENERATION_ERROR	: T_SATA_GENERATION		:= 5;

	constant C_SATA_GENERATION_MAX	: T_SATA_GENERATION		:= SATA_GENERATION_3;

	-- Described in module 'sata_PhysicalLayer'.
	type T_SATA_PHY_COMMAND is (
		SATA_PHY_CMD_NONE,
		SATA_PHY_CMD_INIT_CONNECTION,
		SATA_PHY_CMD_REINIT_CONNECTION
	);

	-- Described in module 'sata_PhysicalLayer'.
	type T_SATA_PHY_STATUS is (
		SATA_PHY_STATUS_RESET,
		SATA_PHY_STATUS_NODEVICE,
		SATA_PHY_STATUS_NOCOMMUNICATION,
		SATA_PHY_STATUS_COMMUNICATING,
		SATA_PHY_STATUS_ERROR
	);

	-- Described in module 'sata_PhysicalLayer'.
	type T_SATA_PHY_ERROR is (
		SATA_PHY_ERROR_NONE,
		SATA_PHY_ERROR_LINK_DEAD,
		SATA_PHY_ERROR_NEGOTIATION
	);

	type T_SATA_GENERATION_VECTOR		is array (NATURAL range <>) of T_SATA_GENERATION;
	type T_SATA_PHY_COMMAND_VECTOR	is array (NATURAL range <>) of T_SATA_PHY_COMMAND;
	type T_SATA_PHY_STATUS_VECTOR		is array (NATURAL range <>) of T_SATA_PHY_STATUS;
	type T_SATA_PHY_ERROR_VECTOR		is array (NATURAL range <>) of T_SATA_PHY_ERROR;

	function to_slv(Command : T_SATA_PHY_COMMAND)			return STD_LOGIC_VECTOR;
	function to_slv(Status : T_SATA_PHY_STATUS)				return STD_LOGIC_VECTOR;
	function to_slv(Error : T_SATA_PHY_ERROR)					return STD_LOGIC_VECTOR;

	-- ===========================================================================
	-- SATA Link Layer Types
	-- ===========================================================================
	type T_SATA_LINK_COMMAND is (
		SATA_LINK_CMD_NONE
	);

	type T_SATA_LINK_STATUS is (
		SATA_LINK_STATUS_NO_COMMUNICATION,
		SATA_LINK_STATUS_IDLE,
		SATA_LINK_STATUS_SENDING,
		SATA_LINK_STATUS_RECEIVING,
		SATA_LINK_STATUS_SYNC_ESCAPE,
		SATA_LINK_STATUS_ERROR
	);

	type T_SATA_LINK_ERROR is (
		SATA_LINK_ERROR_NONE,
		SATA_LINK_ERROR_PHY_ERROR
	);

	type T_SATA_PRIMITIVE is (					-- Primitive Name				Byte 3,	Byte 2,	Byte 1,	Byte 0
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
	constant T_SATA_PRIMITIVE_COUNT		: INTEGER										:= T_SATA_PRIMITIVE'pos(T_SATA_PRIMITIVE'high) + 1;

	constant C_SATA_MAX_FRAMESIZE			: MEMORY										:= 8196 Byte;
	constant C_SATA_WORD_BITS					: POSITIVE									:= 32;

	type T_SATA_LINK_COMMAND_VECTOR		is array (NATURAL range <>) of T_SATA_LINK_COMMAND;
	type T_SATA_LINK_STATUS_VECTOR		is array (NATURAL range <>) of T_SATA_LINK_STATUS;
	type T_SATA_LINK_ERROR_VECTOR			is array (NATURAL range <>) of T_SATA_LINK_ERROR;

	function to_slv(Command : T_SATA_LINK_COMMAND)	return STD_LOGIC_VECTOR;
	function to_slv(Primitive : T_SATA_PRIMITIVE)		return STD_LOGIC_VECTOR;
	function to_slv(Status : T_SATA_LINK_STATUS)		return STD_LOGIC_VECTOR;
	function to_slv(Error : T_SATA_LINK_ERROR)			return STD_LOGIC_VECTOR;

	function to_sata_word(Primitive : T_SATA_PRIMITIVE)	return T_SLV_32;
	function to_sata_primitive(Data : T_SLV_32; CharIsK : T_SLV_4; DetectDialTone : BOOLEAN := FALSE)	return T_SATA_PRIMITIVE;

	-- ===========================================================================
	-- SATA Transport Layer Types
	-- ===========================================================================
	type T_SATA_TRANS_COMMAND is (
		SATA_TRANS_CMD_NONE,
		SATA_TRANS_CMD_TRANSFER
	);

	type T_SATA_TRANS_STATUS is (
		SATA_TRANS_STATUS_RESET,
		SATA_TRANS_STATUS_INITIALIZING,
		SATA_TRANS_STATUS_IDLE,
		SATA_TRANS_STATUS_TRANSFERING,
		SATA_TRANS_STATUS_TRANSFER_OK,
		SATA_TRANS_STATUS_TRANSFER_ERROR,
		SATA_TRANS_STATUS_DISCARD_TXDATA,
		SATA_TRANS_STATUS_ERROR
	);

	type T_SATA_TRANS_ERROR is (
		SATA_TRANS_ERROR_NONE,
		SATA_TRANS_ERROR_FISDECODER,
		SATA_TRANS_ERROR_TRANSMIT_ERROR,
		SATA_TRANS_ERROR_RECEIVE_ERROR,
		SATA_TRANS_ERROR_DEVICE_ERROR,
		SATA_TRANS_ERROR_TIMEOUT,
		SATA_TRANS_ERROR_LINK_ERROR,
		SATA_TRANS_ERROR_FSM												-- ILLEGAL_TRANSITION
	);

	type T_SATA_TRANS_COMMAND_VECTOR	is array (NATURAL range <>) of  T_SATA_TRANS_COMMAND;
	type T_SATA_TRANS_STATUS_VECTOR		is array (NATURAL range <>) of  T_SATA_TRANS_STATUS;
	type T_SATA_TRANS_ERROR_VECTOR		is array (NATURAL range <>) of  T_SATA_TRANS_ERROR;

	-- ATA Commands and Categories
	-- ===========================================================================
	type T_SATA_ATA_COMMAND is (
		SATA_ATA_CMD_NONE,
		SATA_ATA_CMD_IDENTIFY_DEVICE,
		SATA_ATA_CMD_DMA_READ_EXT,
		SATA_ATA_CMD_DMA_WRITE_EXT,
		SATA_ATA_CMD_FLUSH_CACHE_EXT,
		SATA_ATA_CMD_DEVICE_RESET,
		SATA_ATA_CMD_UNKNOWN
	);

	type T_SATA_COMMAND_CATEGORY is (
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
		SATA_CMDCAT_UNKNOWN,
		SATA_CMDCAT_CONTROL
	);

	-- FIS Types
	-- ===========================================================================
	type T_SATA_FISTYPE is (
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

	type T_SATA_FISENCODER_STATUS is (
		SATA_FISE_STATUS_RESET,
		SATA_FISE_STATUS_IDLE,
		SATA_FISE_STATUS_SENDING,
		SATA_FISE_STATUS_SEND_OK,
		SATA_FISE_STATUS_SEND_ERROR,
		SATA_FISE_STATUS_SYNC_ESC
	);

	type T_SATA_FISDECODER_STATUS is (
		SATA_FISD_STATUS_RESET,
		SATA_FISD_STATUS_IDLE,
		SATA_FISD_STATUS_RECEIVING,
		SATA_FISD_STATUS_CHECKING_CRC,
		SATA_FISD_STATUS_DISCARD_FRAME,
		SATA_FISD_STATUS_RECEIVE_OK,
		SATA_FISD_STATUS_ERROR,
		SATA_FISD_STATUS_CRC_ERROR
	);

	-- ATA Registers
	-- ===========================================================================
	type T_SATA_ATA_HOST_REGISTERS is record
		Flag_C						: STD_LOGIC;
		Command						: T_SLV_8;
		Control						: T_SLV_8;
		Feature						: T_SLV_8;
		LBlockAddress			: T_SLV_48;
		SectorCount				: T_SLV_16;
	end record;

	type T_SATA_ATA_DEVICE_FLAGS is record
		Interrupt					: STD_LOGIC;
		Direction					: STD_LOGIC;
		C									: STD_LOGIC;
	end record;

	type T_SATA_ATA_DEVICE_REGISTER_STATUS is record
		Error							: STD_LOGIC;
		DataRequest				: STD_LOGIC;
		DeviceFault				: STD_LOGIC;
		DataReady					: STD_LOGIC;
		Busy							: STD_LOGIC;
	end record;

	type T_SATA_ATA_DEVICE_REGISTER_ERROR is record
		NoMediaPresent				: STD_LOGIC;
		CommandAborted				: STD_LOGIC;
		MediaChangeRequest		: STD_LOGIC;
		IDNotFound						: STD_LOGIC;
		MediaChange						: STD_LOGIC;
		UncorrectableError		: STD_LOGIC;
		InterfaceCRCError			: STD_LOGIC;
	end record;

	type T_SATA_ATA_DEVICE_REGISTERS is record
		Flags							: T_SATA_ATA_DEVICE_FLAGS;
		Status						: T_SATA_ATA_DEVICE_REGISTER_STATUS;
		EndStatus					: T_SATA_ATA_DEVICE_REGISTER_STATUS;
		Error							: T_SATA_ATA_DEVICE_REGISTER_ERROR;
		LBlockAddress			: T_SLV_48;
		SectorCount				: T_SLV_16;
		TransferCount			: T_SLV_16;
	end record;

	type T_SATA_HOST_REGISTER_STATUS is record
		Detect						: T_SLV_4;
		Speed							: T_SLV_4;
		PowerManagement		: T_SLV_4;
		-- reserved				: T_SLV_20
	end record;

	type T_SATA_HOST_REGISTER_ERROR is record
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
	end record;

	type T_SATA_HOST_REGISTERS is record
		Status				: T_SATA_HOST_REGISTER_STATUS;
		Error					: T_SATA_HOST_REGISTER_ERROR;
	end record;

	type T_SATA_ATA_HOST_REGISTERS_VECTOR			is array (NATURAL range <>) of  T_SATA_ATA_HOST_REGISTERS;
	type T_SATA_ATA_DEVICE_REGISTERS_VECTOR		is array (NATURAL range <>) of  T_SATA_ATA_DEVICE_REGISTERS;

	constant C_SATA_ATA_MAX_BLOCKCOUNT			: POSITIVE				:= 2**16; 			--	= 32 MiB at 512 Bytes logical blocks

	function to_sata_Trans_Command(slv : STD_LOGIC_VECTOR)	return T_SATA_TRANS_COMMAND;
	function to_sata_Trans_Status(slv : STD_LOGIC_VECTOR)		return T_SATA_TRANS_STATUS;

	function to_slv(Command : T_SATA_TRANS_COMMAND)			return STD_LOGIC_VECTOR;
	function to_slv(Status : T_SATA_TRANS_STATUS)				return STD_LOGIC_VECTOR;
	function to_slv(Error : T_SATA_TRANS_ERROR)					return STD_LOGIC_VECTOR;
	function to_slv(Status : T_SATA_FISENCODER_STATUS)	return STD_LOGIC_VECTOR;
	function to_slv(Status : T_SATA_FISDECODER_STATUS)	return STD_LOGIC_VECTOR;

	-- ===========================================================================
	-- Common SATA Types
	-- ===========================================================================
	type T_SATA_DEVICE_TYPE is (
		SATA_DEVICE_TYPE_HOST,
		SATA_DEVICE_TYPE_DEVICE
	);

	type T_SATA_DEVICE_TYPE_VECTOR		is array (NATURAL range <>) of  T_SATA_DEVICE_TYPE;

	-- ===========================================================================
	-- SATA Controller Types
	-- ===========================================================================
	-- Adapted version of topmost layer in module 'sata_SATAController'
	type T_SATA_SATACONTROLLER_STATUS is record
		TransportLayer				: T_SATA_TRANS_STATUS;
		LinkLayer							: T_SATA_LINK_STATUS;
		PhysicalLayer					: T_SATA_PHY_STATUS;
		TransceiverLayer			: T_SATA_TRANSCEIVER_STATUS;
	end record;

	type T_SATA_SATACONTROLLER_ERROR is record
		TransportLayer				: T_SATA_TRANS_ERROR;
		LinkLayer							: T_SATA_LINK_ERROR;
		PhysicalLayer					: T_SATA_PHY_ERROR;
		TransceiverLayer			: T_SATA_TRANSCEIVER_ERROR;
	end record;

	type T_SATA_SATACONTROLLER_STATUS_VECTOR		is array (NATURAL range <>) of  T_SATA_SATACONTROLLER_STATUS;
	type T_SATA_SATACONTROLLER_ERROR_VECTOR			is array (NATURAL range <>) of  T_SATA_SATACONTROLLER_ERROR;

	-- ===========================================================================
	-- SATA StreamingLayer Types
	-- ===========================================================================
	type T_SATA_STREAMING_COMMAND is (
		SATA_STREAM_CMD_NONE,
		SATA_STREAM_CMD_READ,
		SATA_STREAM_CMD_WRITE,
		SATA_STREAM_CMD_FLUSH_CACHE,
		SATA_STREAM_CMD_IDENTIFY_DEVICE,
		SATA_STREAM_CMD_DEVICE_RESET
	);

	type T_SATA_STREAMING_STATUS is (
		SATA_STREAM_STATUS_RESET,
		SATA_STREAM_STATUS_INITIALIZING,
		SATA_STREAM_STATUS_IDLE,
		SATA_STREAM_STATUS_SENDING,
		SATA_STREAM_STATUS_RECEIVING,
		SATA_STREAM_STATUS_EXECUTING,
		SATA_STREAM_STATUS_DISCARD_TXDATA,
		SATA_STREAM_STATUS_ERROR
	);

	type T_SATA_STREAMING_ERROR is (
		SATA_STREAM_ERROR_NONE,
		SATA_STREAM_ERROR_IDENTIFY_DEVICE_ERROR,
		SATA_STREAM_ERROR_DEVICE_NOT_SUPPORTED,
		SATA_STREAM_ERROR_TRANSPORT_ERROR,
		SATA_STREAM_ERROR_ATA_ERROR,
		SATA_STREAM_ERROR_FSM												-- ILLEGAL_TRANSITION
	);

	function to_sata_Streaming_Command(slv : STD_LOGIC_VECTOR) return T_SATA_STREAMING_COMMAND;

	function to_slv(Command : T_SATA_STREAMING_COMMAND)	return STD_LOGIC_VECTOR;
	function to_slv(Status  : T_SATA_STREAMING_STATUS)	return STD_LOGIC_VECTOR;
	function to_slv(Error 	: T_SATA_STREAMING_ERROR)	return STD_LOGIC_VECTOR;

	-- ===========================================================================
	-- SATA Streaming Stack types
	-- ===========================================================================
	type T_SATA_STREAMINGSTACK_STATUS is record
		StreamingLayer			: T_SATA_STREAMING_STATUS;
		TransportLayer			: T_SATA_TRANS_STATUS;
		LinkLayer						: T_SATA_LINK_STATUS;
		PhysicalLayer				: T_SATA_PHY_STATUS;
		TransceiverLayer		: T_SATA_TRANSCEIVER_STATUS;
	end record;

	type T_SATA_STREAMINGSTACK_ERROR is record
		StreamingLayer			: T_SATA_STREAMING_ERROR;
		TransportLayer			: T_SATA_TRANS_ERROR;
		LinkLayer						: T_SATA_LINK_ERROR;
		PhysicalLayer				: T_SATA_PHY_ERROR;
		TransceiverLayer		: T_SATA_TRANSCEIVER_ERROR;
	end record;


	-- ===========================================================================
	-- ATA Drive Information
	-- ===========================================================================
	type T_SATA_ATA_CAPABILITY is record
		SupportsDMA								: STD_LOGIC;
		SupportsLBA								: STD_LOGIC;
		Supports48BitLBA					: STD_LOGIC;
		SupportsSMART							: STD_LOGIC;
		SupportsFLUSH_CACHE				: STD_LOGIC;
		SupportsFLUSH_CACHE_EXT		: STD_LOGIC;
	end record;

	type T_SATA_SATA_CAPABILITY is record
		SATAGenerationMin					: T_SATA_GENERATION;
		SATAGenerationMax					: T_SATA_GENERATION;
		SupportsNCQ								: STD_LOGIC;
	end record;

	type T_SATA_DRIVE_INFORMATION is record
		DriveSize_LB							: UNSIGNED(63 DOWNTO 0); -- unit is Drive Logical Blocks (DevLB)
		PhysicalBlockSize_ldB			: UNSIGNED(7 DOWNTO 0);  -- log_2(size_in_bytes)
		LogicalBlockSize_ldB			: UNSIGNED(7 DOWNTO 0);  -- log_2(DevLB_size_in_bytes)
		ATACapabilityFlags				: T_SATA_ATA_CAPABILITY;
		SATACapabilityFlags				: T_SATA_SATA_CAPABILITY;

		Valid											: STD_LOGIC;
	end record;

	type T_SATA_IDF_BUS is record
		Clock											: STD_LOGIC;
		Address										: STD_LOGIC_VECTOR(8 downto 2);
		WriteEnable								: STD_LOGIC;
		Data											: T_SLV_32;
		Valid											: STD_LOGIC;
	end record;

	-- to_slv
	-- ===========================================================================
	function to_slv(FIStype : T_SATA_FISTYPE)									return STD_LOGIC_VECTOR;
	function to_slv(Command : T_SATA_ATA_COMMAND)							return STD_LOGIC_VECTOR;
	function to_slv(reg : T_SATA_ATA_DEVICE_FLAGS)						return STD_LOGIC_VECTOR;
	function to_slv(reg : T_SATA_ATA_DEVICE_REGISTER_STATUS)	return STD_LOGIC_VECTOR;
	function to_slv(reg	: T_SATA_ATA_DEVICE_REGISTER_ERROR)		return STD_LOGIC_VECTOR;
	function to_slv(reg	: T_SATA_ATA_CAPABILITY)							return STD_LOGIC_VECTOR;
	function to_slv(reg	: T_SATA_SATA_CAPABILITY)							return STD_LOGIC_VECTOR;

	function to_sata_generation(slv : STD_LOGIC_VECTOR)	return T_SATA_GENERATION;
	function to_sata_fistype(slv : T_SLV_8; valid : STD_LOGIC := '1') return T_SATA_FISTYPE;
	function to_sata_ata_command(slv : T_SLV_8) return T_SATA_ATA_COMMAND;
	function to_sata_cmdcat(cmd : T_SATA_ATA_COMMAND) return T_SATA_COMMAND_CATEGORY;
	function is_LBA48_Command(cmd : T_SATA_ATA_COMMAND) return STD_LOGIC;
	function to_sata_ata_device_flags(slv : T_SLV_8) return T_SATA_ATA_DEVICE_FLAGS;
	function to_sata_ata_device_register_status(slv : T_SLV_8) return T_SATA_ATA_DEVICE_REGISTER_STATUS;
	function to_sata_ata_device_register_error(slv : T_SLV_8) return T_SATA_ATA_DEVICE_REGISTER_ERROR;
end package;


package body sata is
	-- ===========================================================================
	-- to_sata_*_command
	-- ===========================================================================
	function to_sata_Trans_Command(slv : STD_LOGIC_VECTOR) return T_SATA_TRANS_COMMAND is
	begin
		if (to_integer(unsigned(slv)) <= T_SATA_TRANS_COMMAND'pos(T_SATA_TRANS_COMMAND'high)) then
			return T_SATA_TRANS_COMMAND'val(to_integer(unsigned(slv)));
		else
			return SATA_TRANS_CMD_NONE;
		end if;
	end function;

	function to_sata_Trans_Status(slv : STD_LOGIC_VECTOR) return T_SATA_TRANS_STATUS is
	begin
		if (to_integer(unsigned(slv)) <= T_SATA_TRANS_STATUS'pos(T_SATA_TRANS_STATUS'high)) then
			return T_SATA_TRANS_STATUS'val(to_integer(unsigned(slv)));
		else
			return SATA_TRANS_STATUS_ERROR;
		end if;
	end function;

	function to_sata_Streaming_Command(slv : STD_LOGIC_VECTOR) return T_SATA_STREAMING_COMMAND is
	begin
		if (to_integer(unsigned(slv)) <= T_SATA_STREAMING_COMMAND'pos(T_SATA_STREAMING_COMMAND'high)) then
			return T_SATA_STREAMING_COMMAND'val(to_integer(unsigned(slv)));
		else
			return SATA_STREAM_CMD_NONE;
		end if;
	end function;

	-- to_slv
	-- ===========================================================================
	-- to_slv(Command : ***)
	-- -----------------------------------
	function to_slv(Command : T_SATA_TRANSCEIVER_COMMAND)	return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_TRANSCEIVER_COMMAND'pos(Command), log2ceilnz(T_SATA_TRANSCEIVER_COMMAND'pos(T_SATA_TRANSCEIVER_COMMAND'high) + 1));
	end function;

	function to_slv(Command : T_SATA_PHY_COMMAND)	return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_PHY_COMMAND'pos(Command), log2ceilnz(T_SATA_PHY_COMMAND'pos(T_SATA_PHY_COMMAND'high) + 1));
	end function;

	function to_slv(Command : T_SATA_TRANS_COMMAND) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_TRANS_COMMAND'pos(Command), log2ceilnz(T_SATA_TRANS_COMMAND'pos(T_SATA_TRANS_COMMAND'high) + 1));
	end function;

	function to_slv(Command : T_SATA_LINK_COMMAND) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_LINK_COMMAND'pos(Command), log2ceilnz(T_SATA_LINK_COMMAND'pos(T_SATA_LINK_COMMAND'high) + 1));
	end function;

	function to_slv(Command : T_SATA_STREAMING_COMMAND) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_STREAMING_COMMAND'pos(Command), log2ceilnz(T_SATA_STREAMING_COMMAND'pos(T_SATA_STREAMING_COMMAND'high) + 1));
	end function;

	-- to_slv(Status : ***)
	-- -----------------------------------
	function to_slv(Status : T_SATA_TRANSCEIVER_STATUS)		return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_TRANSCEIVER_STATUS'pos(Status), log2ceilnz(T_SATA_TRANSCEIVER_STATUS'pos(T_SATA_TRANSCEIVER_STATUS'high) + 1));
	end function;

	function to_slv(Status : T_SATA_PHY_STATUS) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_PHY_STATUS'pos(Status), log2ceilnz(T_SATA_PHY_STATUS'pos(T_SATA_PHY_STATUS'high) + 1));
	end function;

	function to_slv(Status : T_SATA_LINK_STATUS) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_LINK_STATUS'pos(Status), log2ceilnz(T_SATA_LINK_STATUS'pos(T_SATA_LINK_STATUS'high) + 1));
	end function;

	function to_slv(Status : T_SATA_TRANS_STATUS) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_TRANS_STATUS'pos(Status), log2ceilnz(T_SATA_TRANS_STATUS'pos(T_SATA_TRANS_STATUS'high) + 1));
	end function;

	function to_slv(Status : T_SATA_STREAMING_STATUS) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_STREAMING_STATUS'pos(Status), log2ceilnz(T_SATA_STREAMING_STATUS'pos(T_SATA_STREAMING_STATUS'high) + 1));
	end function;

	function to_slv(Status : T_SATA_FISENCODER_STATUS) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_FISENCODER_STATUS'pos(Status), log2ceilnz(T_SATA_FISENCODER_STATUS'pos(T_SATA_FISENCODER_STATUS'high) + 1));
	end function;

	function to_slv(Status : T_SATA_FISDECODER_STATUS) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_FISDECODER_STATUS'pos(Status), log2ceilnz(T_SATA_FISDECODER_STATUS'pos(T_SATA_FISDECODER_STATUS'high) + 1));
	end function;

	-- to_slv(Error : ***)
	-- -----------------------------------
	function to_slv(Error : T_SATA_TRANSCEIVER_COMMON_ERROR) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_TRANSCEIVER_COMMON_ERROR'pos(Error), log2ceilnz(T_SATA_TRANSCEIVER_COMMON_ERROR'pos(T_SATA_TRANSCEIVER_COMMON_ERROR'high) + 1));
	end function;

	function to_slv(Error : T_SATA_PHY_ERROR) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_PHY_ERROR'pos(Error), log2ceilnz(T_SATA_PHY_ERROR'pos(T_SATA_PHY_ERROR'high) + 1));
	end function;

	function to_slv(Error : T_SATA_LINK_ERROR) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_LINK_ERROR'pos(Error), log2ceilnz(T_SATA_LINK_ERROR'pos(T_SATA_LINK_ERROR'high) + 1));
	end function;

	function to_slv(Error : T_SATA_TRANS_ERROR) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_TRANS_ERROR'pos(Error), log2ceilnz(T_SATA_TRANS_ERROR'pos(T_SATA_TRANS_ERROR'high) + 1));
	end function;

	function to_slv(Error : T_SATA_STREAMING_ERROR) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_STREAMING_ERROR'pos(Error), log2ceilnz(T_SATA_STREAMING_ERROR'pos(T_SATA_STREAMING_ERROR'high) + 1));
	end function;

	-- to_slv(***)
	-- -----------------------------------
	function to_slv(Primitive : T_SATA_PRIMITIVE) return STD_LOGIC_VECTOR is
	begin
		return to_slv(T_SATA_PRIMITIVE'pos(Primitive), log2ceilnz(T_SATA_PRIMITIVE'pos(T_SATA_PRIMITIVE'high) + 1));
	end function;

	function to_sata_word(Primitive : T_SATA_PRIMITIVE) return T_SLV_32 is	--																				K symbol
	begin																															-- primitive name				Byte 3	Byte 2	Byte 1	Byte 0
		case Primitive is																								-- =======================================================
			when SATA_PRIMITIVE_NONE =>				return x"00000000";					-- no primitive
			when SATA_PRIMITIVE_ALIGN =>			return x"7B4A4ABC";					-- ALIGN								D27.3,	D10.2,	D10.2,	K28.5
			when SATA_PRIMITIVE_SYNC =>				return x"B5B5957C";					-- SYNC									D21.5,	D21.5,	D21.4,	K28.3
			when SATA_PRIMITIVE_SOF =>				return x"3737B57C";					-- SOF									D23.1,	D23.1,	D21.5,	K28.3
			when SATA_PRIMITIVE_EOF =>				return x"D5D5B57C";					-- EOF									D21.6,	D21.6,	D21.5,	K28.3
			when SATA_PRIMITIVE_HOLD =>				return x"D5D5AA7C";					-- HOLD									D21.6,	D21.6,	D10.5,	K28.3
			when SATA_PRIMITIVE_HOLD_ACK =>		return x"9595AA7C";					-- HOLDA								D21.4,	D21.4,	D10.5,	K28.3
			when SATA_PRIMITIVE_CONT =>				return x"9999AA7C";					-- CONT									D25.4,	D25.4,	D10.5,	K28.3
			when SATA_PRIMITIVE_R_OK =>				return x"3535B57C";					-- R_OK									D21.1,	D21.1,	D21.5,	K28.3
			when SATA_PRIMITIVE_R_ERROR =>		return x"5656B57C";					-- R_ERR								D22.2,	D22.2,	D21.5,	K28.3
			when SATA_PRIMITIVE_R_IP =>				return x"5555B57C";					-- R_IP									D21.2,	D21.2,	D21.5,	K28.3
			when SATA_PRIMITIVE_RX_RDY =>			return x"4A4A957C";					-- R_RDY								D10.2,	D10.2,	D21.4,	K28.3
			when SATA_PRIMITIVE_TX_RDY =>			return x"5757B57C";					-- X_RDY								D23.2,	D23.2,	D21.5,	K28.3
			when SATA_PRIMITIVE_DMA_TERM =>		return x"3636B57C";					-- DMAT									D22.1,	D22.1,	D21.5,	K28.3
			when SATA_PRIMITIVE_WAIT_TERM =>	return x"5858B57C";					-- WTRM									D24.2,	D24.2,	D21.5,	K28.3
			when SATA_PRIMITIVE_PM_ACK =>			return x"9595957C";					-- PMACK								D21.4,	D21.4,	D21.4,	K28.3
			when SATA_PRIMITIVE_PM_NACK =>		return x"F5F5957C";					-- PMNAK								D21.7,	D21.7,	D21.4,	K28.3
			when SATA_PRIMITIVE_PM_REQ_P =>		return x"1717B57C";					-- PMREQ_P							D23.0,	D23.0,	D21.5,	K28.3
			when SATA_PRIMITIVE_PM_REQ_S =>		return x"7575957C";					-- PMREQ_S							D21.3,	D21.3,	D21.4,	K28.3
			when SATA_PRIMITIVE_DIAL_TONE =>	return x"4A4A4A4A";					-- 											D10.2,	D10.2,	D10.2,	D10.2
			when SATA_PRIMITIVE_ILLEGAL =>		return (others => 'X');			-- "ERROR"
		end case;
	end function;

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

	function to_slv(FISType : T_SATA_FISTYPE) return STD_LOGIC_VECTOR is
	begin
		case FISType is
			when SATA_FISTYPE_REG_HOST_DEV		=> return	x"27";
			when SATA_FISTYPE_REG_DEV_HOST		=> return	x"34";
			when SATA_FISTYPE_SET_DEV_BITS		=> return	x"A1";
			when SATA_FISTYPE_DMA_ACTIVATE		=> return	x"39";
			when SATA_FISTYPE_DMA_SETUP				=> return	x"41";
			when SATA_FISTYPE_BIST						=> return	x"58";
			when SATA_FISTYPE_PIO_SETUP				=> return	x"5F";
			when SATA_FISTYPE_DATA						=> return	x"46";
			when SATA_FISTYPE_UNKNOWN					=> return x"00";
		end case;
	end function;

	function to_slv(Command : T_SATA_ATA_COMMAND) return STD_LOGIC_VECTOR is
	begin
		case Command is
			when SATA_ATA_CMD_NONE =>							return x"00";
			when SATA_ATA_CMD_IDENTIFY_DEVICE =>	return x"EC";
			when SATA_ATA_CMD_DMA_READ_EXT =>			return x"25";
			when SATA_ATA_CMD_DMA_WRITE_EXT =>		return x"35";
			when SATA_ATA_CMD_FLUSH_CACHE_EXT =>	return x"EA";
			when SATA_ATA_CMD_DEVICE_RESET =>			return x"08";
			when others =>												return x"00";
		end case;
	end function;

	-- to_*
	-- ===========================================================================
	function to_sata_fistype(slv : T_SLV_8; valid : STD_LOGIC := '1') return T_SATA_FISTYPE is
	begin
		if (valid = '1') then
			for i in T_SATA_FISTYPE loop
				if (slv = to_slv(i)) then
					return i;
				end if;
			end loop;
		end if;
		return SATA_FISTYPE_UNKNOWN;
	end function;

	function to_sata_ata_command(slv : T_SLV_8) return T_SATA_ATA_COMMAND is
	begin
		for i in T_SATA_ATA_COMMAND loop
			if (slv = to_slv(i)) then
				return i;
			end if;
		end loop;
		return SATA_ATA_CMD_NONE;
	end function;

	function to_sata_cmdcat(cmd : T_SATA_ATA_COMMAND) return T_SATA_COMMAND_CATEGORY is
	begin
		case cmd is
			-- non-data commands
			when SATA_ATA_CMD_FLUSH_CACHE_EXT =>		return SATA_CMDCAT_NON_DATA;
			when SATA_ATA_CMD_DEVICE_RESET =>				return SATA_CMDCAT_NON_DATA;

			-- PIO data-in commands
			when SATA_ATA_CMD_IDENTIFY_DEVICE =>		return SATA_CMDCAT_PIO_IN;

			-- PIO data-out commands

			-- DMA data-in commands
			when SATA_ATA_CMD_DMA_READ_EXT =>				return SATA_CMDCAT_DMA_IN;

			-- DMA data-out commands
			when SATA_ATA_CMD_DMA_WRITE_EXT =>			return SATA_CMDCAT_DMA_OUT;

			-- other enum members
			when SATA_ATA_CMD_NONE =>								return SATA_CMDCAT_CONTROL;
			when SATA_ATA_CMD_UNKNOWN =>						return SATA_CMDCAT_UNKNOWN;
			when others =>													return SATA_CMDCAT_UNKNOWN;
		end case;
	end function;

	function is_lba48_command(cmd : T_SATA_ATA_COMMAND) return STD_LOGIC is
	begin
		case cmd is
			-- non-data commands
			when SATA_ATA_CMD_FLUSH_CACHE_EXT =>	return '0';
			when SATA_ATA_CMD_DEVICE_RESET =>			return '0';

			-- PIO data-in commands
			when SATA_ATA_CMD_IDENTIFY_DEVICE =>	return '0';

			-- PIO data-out commands

			-- DMA data-in commands
			when SATA_ATA_CMD_DMA_READ_EXT =>			return '1';

			-- DMA data-out commands
			when SATA_ATA_CMD_DMA_WRITE_EXT =>		return '1';

			-- other enum members
			when SATA_ATA_CMD_NONE =>							return '0';
			when SATA_ATA_CMD_UNKNOWN =>					return '0';
			when others =>												return '0';
		end case;
	end function;

	function to_sata_ata_device_register_status(slv : T_SLV_8) return T_SATA_ATA_DEVICE_REGISTER_STATUS is
		variable Result				: T_SATA_ATA_DEVICE_REGISTER_STATUS;
	begin
		Result.Error					:= slv(0);
		Result.DataRequest		:= slv(3);
		Result.DeviceFault		:= slv(5);
		Result.DataReady			:= slv(6);
		Result.Busy						:= slv(7);
		return Result;
	end function;

	function to_slv(reg : T_SATA_ATA_DEVICE_REGISTER_STATUS) return STD_LOGIC_VECTOR is
		variable Result				: T_SLV_8		:= (others => '0');
	begin
		Result(0)							:= reg.Error;
		Result(3)							:= reg.DataRequest;
		Result(5)							:= reg.DeviceFault;
		Result(6)							:= reg.DataReady;
		Result(7)							:= reg.Busy;
		return Result;
	end function;

	function to_sata_ata_device_register_error(slv : T_SLV_8) return T_SATA_ATA_DEVICE_REGISTER_ERROR is
		variable Result							: T_SATA_ATA_DEVICE_REGISTER_ERROR;
	begin
		Result.NoMediaPresent				:= slv(1);
		Result.CommandAborted				:= slv(2);
		Result.MediaChangeRequest		:= slv(3);
		Result.IDNotFound						:= slv(4);
		Result.MediaChange					:= slv(5);
		Result.UncorrectableError		:= slv(6);
		Result.InterfaceCRCError		:= slv(7);
		return Result;
	end function;

	function to_slv(reg	: T_SATA_ATA_DEVICE_REGISTER_ERROR) return STD_LOGIC_VECTOR is
		variable Result							: T_SLV_8			:= (others => '0');
	begin
		Result(1)										:= reg.NoMediaPresent;
		Result(2)										:= reg.CommandAborted;
		Result(3)										:= reg.MediaChangeRequest;
		Result(4)										:= reg.IDNotFound;
		Result(5)										:= reg.MediaChange;
		Result(6)										:= reg.UncorrectableError;
		Result(7)										:= reg.InterfaceCRCError;
		return Result;
	end function;

	function to_slv(reg	: T_SATA_ATA_CAPABILITY) return STD_LOGIC_VECTOR is
		variable Result							: T_SLV_8			:= (others => '0');
	begin
		Result(0)										:= reg.SupportsDMA;
		Result(1)										:= reg.SupportsLBA;
		Result(2)										:= reg.Supports48BitLBA;
		Result(3)										:= reg.SupportsSMART;
		Result(4)										:= reg.SupportsFLUSH_CACHE;
		Result(5)										:= reg.SupportsFLUSH_CACHE_EXT;
		return Result;
	end function;

	function to_slv(reg	: T_SATA_SATA_CAPABILITY) return STD_LOGIC_VECTOR is
		variable Result							: T_SLV_8			:= (others => '0');
	begin
		Result(1 downto 0)					:= to_slv(reg.SATAGenerationMin, 2);
		Result(3 downto 2)					:= to_slv(reg.SATAGenerationMax, 2);
		Result(4)										:= reg.SupportsNCQ;
		return Result;
	end function;

	function to_sata_ata_device_flags(slv : T_SLV_8) return T_SATA_ATA_DEVICE_FLAGS is
		variable Result							: T_SATA_ATA_DEVICE_FLAGS;
	begin
		Result.Direction						:= slv(5);
		Result.Interrupt						:= slv(6);
		Result.C										:= slv(7);
		return Result;
	end function;

	function to_slv(reg	: T_SATA_ATA_DEVICE_FLAGS) return STD_LOGIC_VECTOR is
		variable Result							: T_SLV_8			:= (others => '0');
	begin
		Result(5)										:= reg.Direction;
		Result(6)										:= reg.Interrupt;
		Result(7)										:= reg.C;
		return Result;
	end function;
end package body;
