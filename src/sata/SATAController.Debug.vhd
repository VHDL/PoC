LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;

-- Usage
-- ====================================
-- LIBRARY L_SATAController;
-- USE L_SATAController.SATADebug.ALL;

PACKAGE SATADebug IS
	TYPE T_DBG_PHYOUT IS RECORD
		GenerationChanges		: UNSIGNED(3 DOWNTO 0);
		TrysPerGeneration		: UNSIGNED(3 DOWNTO 0);
		SATAGeneration			: T_SATA_GENERATION;
		SATAStatus					: T_SATA_STATUS;
		SATAError						: T_SATA_ERROR;
	END RECORD;

	TYPE T_DBG_LINKOUT IS RECORD
		RX_Primitive				: T_SATA_PRIMITIVE;
	END RECORD;

-- 	TYPE T_DBG_TRANSIN IS RECORD
-- -- 		ClkMux							: STD_LOGIC;
-- 		
-- 	END RECORD;

	TYPE T_DBG_TRANSOUT IS RECORD
-- 		PLL_Reset						: STD_LOGIC;
-- 		TXPLL_Locked				: STD_LOGIC;
-- 		RXPLL_Locked				: STD_LOGIC;
-- 
-- 		MMCM_Reset					: STD_LOGIC;
-- 		MMCM_Locked					: STD_LOGIC;
-- 
-- 		RefClock						: STD_LOGIC;
-- 		TXOutClock					: STD_LOGIC;
-- 		RXRecClock					: STD_LOGIC;
-- 		SATAClock						: STD_LOGIC;
		leds 		: std_logic_vector(7 downto 0);
		seg7		: std_logic_vector(15 downto 0);
	END RECORD;

-- 	TYPE T_DBG_SATAIN IS RECORD
-- 		LinkLayer						: T_DBG_LINKIN;
-- 		PhysicalLayer				: T_DBG_PHYIN;
-- 		Transceiverlayer		: T_DBG_TRANSIN;
-- 	END RECORD;

	TYPE T_DBG_SATAOUT IS RECORD
		LinkLayer						: T_DBG_LINKOUT;
		PhysicalLayer				: T_DBG_PHYOUT;
		TransceiverLayer		: T_DBG_TRANSOUT;
	END RECORD;

--	TYPE T_DBG_PHYIN_VECTOR			IS ARRAY(NATURAL RANGE <>) OF T_DBG_PHYIN;
	TYPE T_DBG_PHYOUT_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_DBG_PHYOUT;

--	TYPE T_DBG_TRANSIN_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_DBG_TRANSIN;
	TYPE T_DBG_TRANSOUT_VECTOR	IS ARRAY(NATURAL RANGE <>) OF T_DBG_TRANSOUT;

	TYPE T_DBG_LINKOUT_VECTOR	IS ARRAY(NATURAL RANGE <>) OF T_DBG_LINKOUT;
	
--	TYPE T_DBG_SATAIN_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_DBG_SATAIN;
	TYPE T_DBG_SATAOUT_VECTOR		IS ARRAY(NATURAL RANGE <>) OF T_DBG_SATAOUT;

--	FUNCTION to_slv(oob : T_OOB) RETURN STD_LOGIC_VECTOR;
END SATADebug;


PACKAGE BODY SATADebug IS
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