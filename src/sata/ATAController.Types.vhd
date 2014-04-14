LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY	L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;

-- Usage
-- ====================================
-- LIBRARY L_ATAController;
-- USE L_ATAController.ATATypes.ALL;

PACKAGE ATATypes IS
	-- declare attributes
	ATTRIBUTE ENUM_ENCODING	: STRING;
	
	-- ==================================================================
	-- ATA command layer types
	-- ==================================================================
	TYPE T_ATA_CMD_COMMAND IS (
		ATA_CMD_CMD_NONE,
		ATA_CMD_CMD_RESET,
		ATA_CMD_CMD_READ,
		ATA_CMD_CMD_WRITE,
		ATA_CMD_CMD_FLUSH_CACHE,
		ATA_CMD_CMD_IDENTIFY_DEVICE,
		ATA_CMD_CMD_ABORT
	);

	TYPE T_ATA_CMD_STATUS IS (
		ATA_CMD_STATUS_RESET,
		ATA_CMD_STATUS_INITIALIZING,
		ATA_CMD_STATUS_IDLE,
		ATA_CMD_STATUS_SENDING,
		ATA_CMD_STATUS_RECEIVING,
		ATA_CMD_STATUS_EXECUTING,
		ATA_CMD_STATUS_ABORTING,
		ATA_CMD_STATUS_ERROR
	);
	
	TYPE T_ATA_CMD_ERROR IS (
		ATA_CMD_ERROR_NONE,
		ATA_CMD_ERROR_IDENTIFY_DEVICE_ERROR,
		ATA_CMD_ERROR_DEVICE_NOT_SUPPORTED,
		ATA_CMD_ERROR_TRANSPORT_ERROR,
		ATA_CMD_ERROR_REQUEST_INCOMPLETE,
		ATA_CMD_ERROR_FSM												-- ILLEGAL_TRANSITION
	);
	
	TYPE T_ATA_COMMAND IS (
		ATA_CMD_NONE,
		ATA_CMD_IDENTIFY_DEVICE,
		ATA_CMD_DMA_READ_EXT,
		ATA_CMD_DMA_WRITE_EXT,
		ATA_CMD_FLUSH_CACHE_EXT,
		ATA_CMD_UNKNOWN
	);
	
	TYPE T_ATA_COMMAND_CATEGORY IS (
		ATA_CMDCAT_NON_DATA,
		ATA_CMDCAT_PIO_IN,
		ATA_CMDCAT_PIO_OUT,
		ATA_CMDCAT_DMA_IN,
		ATA_CMDCAT_DMA_OUT,
		ATA_CMDCAT_DMA_IN_QUEUED,
		ATA_CMDCAT_DMA_OUT_QUEUED,
		ATA_CMDCAT_PACKET,
		ATA_CMDCAT_SERVICE,
		ATA_CMDCAT_DEVICE_RESET,
		ATA_CMDCAT_DEVICE_DIAGNOSTICS,
		ATA_CMDCAT_UNKNOWN
	);
	

	-- ==================================================================
	-- SATA transport layer types
	-- ==================================================================
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

	TYPE T_FISENCODER_STATUS IS (
		FISE_STATUS_IDLE,
		FISE_STATUS_SENDING,
		FISE_STATUS_SENDING_DISCONTINUED,
		FISE_STATUS_SEND_OK,
		FISE_STATUS_ERROR
	);
	
	TYPE T_FISDECODER_STATUS IS (
		FISD_STATUS_IDLE,
		FISD_STATUS_RECEIVING,
		FISD_STATUS_CHECKING_CRC,
		FISD_STATUS_DISCARD_FRAME,
		FISD_STATUS_RECEIVE_OK,
		FISD_STATUS_ERROR,
		FISD_STATUS_CRC_ERROR
	);
	
	TYPE T_ATA_HOST_REGISTERS IS RECORD
		Flag_C						: STD_LOGIC;
		Command						: T_SLV_8;
		Control						: T_SLV_8;
		Feature						: T_SLV_8;
		LBlockAddress			: T_SLV_48;
		SectorCount				: T_SLV_16;
	END RECORD;
	
	TYPE T_ATA_DEVICE_FLAGS IS RECORD
		Interrupt					: STD_LOGIC;
		Direction					: STD_LOGIC;
		C									: STD_LOGIC;
	END RECORD;
	
	TYPE T_ATA_DEVICE_REGISTER_STATUS IS RECORD
		Error							: STD_LOGIC;
		DataRequest				: STD_LOGIC;
		DeviceFault				: STD_LOGIC;
		DataReady					: STD_LOGIC;
		Busy							: STD_LOGIC;
	END RECORD;
	
	TYPE T_ATA_DEVICE_REGISTER_ERROR IS RECORD
		NoMediaPresent				: STD_LOGIC;
		CommandAborted				: STD_LOGIC;
		MediaChangeRequest		: STD_LOGIC;
		IDNotFound						: STD_LOGIC;
		MediaChange						: STD_LOGIC;
		UncorrectableError		: STD_LOGIC;
		InterfaceCRCError			: STD_LOGIC;
	END RECORD;
	
	TYPE T_ATA_DEVICE_REGISTERS IS RECORD
		Flags							: T_ATA_DEVICE_FLAGS;
		Status						: T_ATA_DEVICE_REGISTER_STATUS;
		EndStatus					: T_ATA_DEVICE_REGISTER_STATUS;
		Error							: T_ATA_DEVICE_REGISTER_ERROR;
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
	
	CONSTANT ATA_MAX_BLOCKCOUNT			: POSITIVE				:= 2**16; 			--	= 32 MiB at 512 Bytes logical blocks
	CONSTANT SIM_MAX_BLOCKCOUNT			: POSITIVE				:= 64; 					--	= 32 KiB at 512 Bytes logical blocks
	
	-- ==================================================================
	-- ATAStreamingController types
	-- ==================================================================
	TYPE T_ATASC_COMMAND IS (
		ATASC_CMD_NONE,
		ATASC_CMD_RESET,
		ATASC_CMD_READ,
		ATASC_CMD_WRITE,
		ATASC_CMD_FLUSH_CACHE,
		ATASC_CMD_ABORT
	);

	TYPE T_ATASC_STATUS IS RECORD
		CommandLayer			: T_ATA_CMD_STATUS;
		TransportLayer		: T_SATA_TRANS_STATUS;
	END RECORD;
	
	TYPE T_ATASC_ERROR IS RECORD
		CommandLayer			: T_ATA_CMD_ERROR;
		TransportLayer		: T_SATA_TRANS_ERROR;
	END RECORD;
	
	-- ==================================================================
	-- ATA Drive Information
	-- ==================================================================
	TYPE T_ATA_CAPABILITY IS RECORD
		SupportsDMA								: STD_LOGIC;
		SupportsLBA								: STD_LOGIC;
		Supports48BitLBA					: STD_LOGIC;
		SupportsSMART							: STD_LOGIC;
		SupportsFLUSH_CACHE				: STD_LOGIC;
		SupportsFLUSH_CACHE_EXT		: STD_LOGIC;
	END RECORD;
	
	TYPE T_SATA_CAPABILITY IS RECORD
		SupportsNCQ								: STD_LOGIC;
		SATAGenerationMin					: T_SATA_GENERATION;
		SATAGenerationMax					: T_SATA_GENERATION;
	END RECORD;
	
	TYPE T_DRIVE_INFORMATION IS RECORD
		DriveName									: T_RAWSTRING(0 TO 39);
		DriveSize_LB							: UNSIGNED(63 DOWNTO 0); -- unit is Drive Logical Blocks (DevLB)
		PhysicalBlockSize_ldB			: UNSIGNED(7 DOWNTO 0);  -- log_2(size_in_bytes)
		LogicalBlockSize_ldB			: UNSIGNED(7 DOWNTO 0);  -- log_2(DevLB_size_in_bytes)
		ATACapabilityFlags				: T_ATA_CAPABILITY;
		SATACapabilityFlags				: T_SATA_CAPABILITY;
		
		Valid											: STD_LOGIC;
	END RECORD;
	
	
	-- to_slv
	-- ================================================================
	FUNCTION to_slv(Command : T_ATA_COMMAND) RETURN STD_LOGIC_VECTOR;
	FUNCTION to_slv(FISType : T_SATA_FISTYPE) RETURN STD_LOGIC_VECTOR;
	FUNCTION to_slv(reg : T_ATA_DEVICE_FLAGS) RETURN STD_LOGIC_VECTOR;
	FUNCTION to_slv(reg : T_ATA_DEVICE_REGISTER_STATUS) RETURN STD_LOGIC_VECTOR;
	FUNCTION to_slv(reg	: T_ATA_DEVICE_REGISTER_ERROR) RETURN STD_LOGIC_VECTOR;
	
	FUNCTION to_fistype(slv : T_SLV_8; valid : STD_LOGIC := '1') RETURN T_SATA_FISTYPE;
	FUNCTION to_ata_cmd(slv : T_SLV_8) RETURN T_ATA_COMMAND;
	FUNCTION to_ata_cmdcat(cmd : T_ATA_COMMAND) RETURN T_ATA_COMMAND_CATEGORY;
	FUNCTION is_LBA48_Command(cmd : T_ATA_COMMAND) RETURN STD_LOGIC;
	FUNCTION to_ata_device_flags(slv : T_SLV_8) RETURN T_ATA_DEVICE_FLAGS;
	FUNCTION to_ata_device_register_status(slv : T_SLV_8) RETURN T_ATA_DEVICE_REGISTER_STATUS;
	FUNCTION to_ata_device_register_error(slv : T_SLV_8) RETURN T_ATA_DEVICE_REGISTER_ERROR;

END ATATypes;

PACKAGE BODY ATATypes IS
	-- to_slv
	-- ================================================================
	FUNCTION to_slv(Command : T_ATA_COMMAND) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		CASE Command IS
			WHEN ATA_CMD_NONE =>							RETURN x"00";
			WHEN ATA_CMD_IDENTIFY_DEVICE =>		RETURN x"EC";
			WHEN ATA_CMD_DMA_READ_EXT =>			RETURN x"25";
			WHEN ATA_CMD_DMA_WRITE_EXT =>			RETURN x"35";
			WHEN ATA_CMD_FLUSH_CACHE_EXT =>		RETURN x"EA";
			WHEN OTHERS =>										RETURN x"00";
		END CASE;
	END;

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
	
	-- to_*
	-- ================================================================
	FUNCTION to_fistype(slv : T_SLV_8; valid : STD_LOGIC := '1') RETURN T_SATA_FISTYPE IS
	BEGIN
		IF (valid = '1') THEN
			CASE slv IS
				WHEN x"27" =>		RETURN SATA_FISTYPE_REG_HOST_DEV;
				WHEN x"34" =>		RETURN SATA_FISTYPE_REG_DEV_HOST;
				WHEN x"A1" =>		RETURN SATA_FISTYPE_SET_DEV_BITS;
				WHEN x"39" =>		RETURN SATA_FISTYPE_DMA_ACTIVATE;
				WHEN x"41" =>		RETURN SATA_FISTYPE_DMA_SETUP;
				WHEN x"58" =>		RETURN SATA_FISTYPE_BIST;
				WHEN x"5F" =>		RETURN SATA_FISTYPE_PIO_SETUP;
				WHEN x"46" =>		RETURN SATA_FISTYPE_DATA;
				WHEN OTHERS =>	RETURN SATA_FISTYPE_UNKNOWN;
			END CASE;
		ELSE
			RETURN SATA_FISTYPE_UNKNOWN;
		END IF;
	END;
	
	FUNCTION to_ata_cmd(slv : T_SLV_8) RETURN T_ATA_COMMAND IS
	BEGIN
		CASE slv IS
			WHEN to_slv(ATA_CMD_NONE) =>							RETURN ATA_CMD_NONE;
			WHEN to_slv(ATA_CMD_IDENTIFY_DEVICE) =>		RETURN ATA_CMD_IDENTIFY_DEVICE;
			WHEN to_slv(ATA_CMD_DMA_READ_EXT) =>			RETURN ATA_CMD_DMA_READ_EXT;
			WHEN to_slv(ATA_CMD_DMA_WRITE_EXT) =>			RETURN ATA_CMD_DMA_WRITE_EXT;
			WHEN to_slv(ATA_CMD_FLUSH_CACHE_EXT) =>		RETURN ATA_CMD_FLUSH_CACHE_EXT;
			WHEN OTHERS =>														RETURN ATA_CMD_NONE;
		END CASE;
	END;
	
	FUNCTION to_ata_cmdcat(cmd : T_ATA_COMMAND) RETURN T_ATA_COMMAND_CATEGORY IS
	BEGIN
		CASE cmd IS
			-- non-data commands
			WHEN ATA_CMD_FLUSH_CACHE_EXT =>			RETURN ATA_CMDCAT_NON_DATA;
			
			-- PIO data-in commands
			WHEN ATA_CMD_IDENTIFY_DEVICE =>			RETURN ATA_CMDCAT_PIO_IN;
			
			-- PIO data-out commands
			
			-- DMA data-in commands
			WHEN ATA_CMD_DMA_READ_EXT =>				RETURN ATA_CMDCAT_DMA_IN;
			
			-- DMA data-out commands
			WHEN ATA_CMD_DMA_WRITE_EXT =>				RETURN ATA_CMDCAT_DMA_OUT;
			
			-- other enum members
			WHEN ATA_CMD_NONE =>								RETURN ATA_CMDCAT_UNKNOWN;
			WHEN ATA_CMD_UNKNOWN =>							RETURN ATA_CMDCAT_UNKNOWN;
			WHEN OTHERS =>											RETURN ATA_CMDCAT_UNKNOWN;
		END CASE;
		
		-- posible return codes:
		--		ATA_CMDCAT_NON_DATA,
		--		ATA_CMDCAT_PIO_IN,
		--		ATA_CMDCAT_PIO_OUT,
		--		ATA_CMDCAT_DMA_IN,
		--		ATA_CMDCAT_DMA_OUT,
		--		ATA_CMDCAT_DMA_IN_QUEUED,
		--		ATA_CMDCAT_DMA_OUT_QUEUED,
		--		ATA_CMDCAT_PACKET,
		--		ATA_CMDCAT_SERVICE,
		--		ATA_CMDCAT_DEVICE_RESET,
		--		ATA_CMDCAT_DEVICE_DIAGNOSTICS
	END;
	
	FUNCTION is_LBA48_Command(cmd : T_ATA_COMMAND) RETURN STd_LOGIC IS
	BEGIN
		CASE cmd IS
			-- non-data commands
			WHEN ATA_CMD_FLUSH_CACHE_EXT =>			RETURN '0';
			
			-- PIO data-in commands
			WHEN ATA_CMD_IDENTIFY_DEVICE =>			RETURN '0';
			
			-- PIO data-out commands
			
			-- DMA data-in commands
			WHEN ATA_CMD_DMA_READ_EXT =>				RETURN '1';
			
			-- DMA data-out commands
			WHEN ATA_CMD_DMA_WRITE_EXT =>				RETURN '1';
			
			-- other enum members
			WHEN ATA_CMD_NONE =>								RETURN '0';
			WHEN ATA_CMD_UNKNOWN =>							RETURN '0';
			WHEN OTHERS =>											RETURN '0';
		END CASE;
	END;
	
	FUNCTION to_ata_device_register_status(slv : T_SLV_8) RETURN T_ATA_DEVICE_REGISTER_STATUS IS
		VARIABLE Result				: T_ATA_DEVICE_REGISTER_STATUS;
	BEGIN
		Result.Error					:= slv(0);
		Result.DataRequest		:= slv(3);
		Result.DeviceFault		:= slv(5);
		Result.DataReady			:= slv(6);
		Result.Busy						:= slv(7);
		
		Return Result;
	END;
	
	FUNCTION to_slv(reg : T_ATA_DEVICE_REGISTER_STATUS) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result				: T_SLV_8		:= Z8;
	BEGIN
		Result(0)							:= reg.Error;
		Result(3)							:= reg.DataRequest;
		Result(5)							:= reg.DeviceFault;
		Result(6)							:= reg.DataReady;
		Result(7)							:= reg.Busy;
		
		Return Result;
	END;
	
	FUNCTION to_ata_device_register_error(slv : T_SLV_8) RETURN T_ATA_DEVICE_REGISTER_ERROR IS
		VARIABLE Result							: T_ATA_DEVICE_REGISTER_ERROR;
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
	
	FUNCTION to_slv(reg	: T_ATA_DEVICE_REGISTER_ERROR) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result							: T_SLV_8			:= Z8;
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
	
	FUNCTION to_ata_device_flags(slv : T_SLV_8) RETURN T_ATA_DEVICE_FLAGS IS
		VARIABLE Result							: T_ATA_DEVICE_FLAGS;
	BEGIN
		Result.Direction						:= slv(5);
		Result.Interrupt						:= slv(6);
		Result.C										:= slv(7);
		
		Return Result;
	END;
	
	FUNCTION to_slv(reg	: T_ATA_DEVICE_FLAGS) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result							: T_SLV_8			:= Z8;
	BEGIN
		Result(5)										:= reg.Direction;
		Result(6)										:= reg.Interrupt;
		Result(7)										:= reg.C;
		
		Return Result;
	END;

END PACKAGE BODY;
