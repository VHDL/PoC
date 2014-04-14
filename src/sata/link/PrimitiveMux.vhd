LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;

ENTITY PrimitiveMux IS
	GENERIC (
		CHIPSCOPE_KEEP				: BOOLEAN					:= FALSE
	);
	PORT (
		Primitive							: IN	T_SATA_PRIMITIVE;
		
		TX_DataIn							: IN	T_SLV_32;
		TX_DataOut						: OUT	T_SLV_32;
		TX_CharIsK						: OUT T_SATA_CIK
	);
END;

ARCHITECTURE rtl OF PrimitiveMux IS
	ATTRIBUTE KEEP						: BOOLEAN;
	ATTRIBUTE FSM_ENCODING		: STRING;
	
BEGIN
	-- PrimitiveROM
	PROCESS(Primitive, TX_DataIn)
	BEGIN
		TX_DataOut		<= TX_DataIn;
		TX_CharIsK		<= "0000";

		CASE Primitive IS
			WHEN SATA_PRIMITIVE_NONE =>							-- no primitive					passthrough data word
				TX_DataOut		<= TX_DataIn;
				TX_CharIsK		<= "0000";

			WHEN SATA_PRIMITIVE_ILLEGAL =>
				ASSERT FALSE REPORT "illegal PRIMTIVE" SEVERITY FAILURE;

			WHEN OTHERS =>													-- Send Primitive
				TX_DataOut		<= to_slv(Primitive);		-- access ROM
				TX_CharIsK		<= "0001";							-- mark primitive with K-symbols
		
		END CASE;
	END PROCESS;


	-- ================================================================
	-- ChipScope
	-- ================================================================
	genCSP : IF (CHIPSCOPE_KEEP = TRUE) GENERATE
		SIGNAL CSP_Primitive_NONE			: STD_LOGIC;
		
		ATTRIBUTE KEEP OF CSP_Primitive_NONE				: SIGNAL IS TRUE;
	BEGIN
		CSP_Primitive_NONE		<= to_sl(Primitive = SATA_PRIMITIVE_NONE);
	END GENERATE;
END;
