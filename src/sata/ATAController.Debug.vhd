LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_ATAController;
USE			L_ATAController.ATATypes.ALL;

LIBRARY L_SATAController;
USE 		L_SATAController.SATADebug.ALL;

-- Usage
-- ====================================
-- LIBRARY L_ATAController;
-- USE L_ATAController.ATADebug.ALL;

PACKAGE ATADebug IS
	TYPE T_DBG_COMMAND_OUT IS RECORD
		Command											: T_ATA_CMD_COMMAND;
		Status											: T_ATA_CMD_STATUS;
		Error												: T_ATA_CMD_ERROR;
		
		SOR													: STD_LOGIC;
		EOR													: STD_LOGIC;
		
		DriveInformation						: T_DRIVE_INFORMATION;
	END RECORD;
	
	TYPE T_DBG_TRANSPORT_OUT IS RECORD
		Command											: T_SATA_TRANS_COMMAND;
		Status											: T_SATA_TRANS_STATUS;
		Error												: T_SATA_TRANS_ERROR;
		
		UpdateATAHostRegisters			: STD_LOGIC;
		ATAHostRegisters						: T_ATA_HOST_REGISTERS;
		UpdateATADeviceRegisters		: STD_LOGIC;
		ATADeviceRegisters					: T_ATA_DEVICE_REGISTERS;
		
		FISE_FISType								: T_SATA_FISTYPE;
		FISE_Status									: T_FISENCODER_STATUS;
		FISD_FISType								: T_SATA_FISTYPE;
		FISD_Status									: T_FISDECODER_STATUS;
		
		SOF													: STD_LOGIC;
		EOF													: STD_LOGIC;
		SOT													: STD_LOGIC;
		EOT													: STD_LOGIC;
	END RECORD;

	TYPE T_DBG_ATASC_OUT IS RECORD
		CommandLayer								: T_DBG_COMMAND_OUT;
		TransportLayer							: T_DBG_TRANSPORT_OUT;
	END RECORD;
	
	TYPE T_DBG_ATASCM_OUT IS RECORD
		RunAC_Address : STD_LOGIC_VECTOR(4 DOWNTO 0);
		Run_Complete  : STD_LOGIC;
		Error         : STD_LOGIC;
		Idle          : STD_LOGIC;
		DataOut       : T_SLV_32;
	END RECORD;

	TYPE T_DBG_ATASCM_IN IS RECORD
		SATAC_DebugPortOut	: T_DBG_SATAOUT;
		ATASC_DebugPortOut	: T_DBG_ATASC_OUT;
	END RECORD;

--	FUNCTION to_slv(oob : T_OOB) RETURN STD_LOGIC_VECTOR;
END ATADebug;


PACKAGE BODY ATADebug IS
-- ==================================================================
-- debug functions
-- ==================================================================
--	FUNCTION to_slv(oob : T_OOB) RETURN STD_LOGIC_VECTOR IS
--	BEGIN
--		CASE oob IS
--			WHEN OOB_NONE							=> RETURN "00";
--			WHEN OOB_READY						=> RETURN "01";
--			WHEN OOB_COMRESET					=> RETURN "10";
--			WHEN OOB_COMINIT					=> RETURN "10";
--			WHEN OOB_COMWAKE					=> RETURN "11";
--		END CASE;
--	END;

END PACKAGE BODY;