LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_ATAController;
USE			L_ATAController.ATATypes.ALL;


ENTITY AddressCalculation IS
	GENERIC (
		LOGICAL_BLOCK_SIZE_ldB						: NATURAL
	);
	PORT (
		Clock															: IN	STD_LOGIC;
		Reset															: IN	STD_LOGIC;

		Address_AppLB											: IN	T_SLV_48;
		BlockCount_AppLB									: IN	T_SLV_48;

		IDF_DriveInformation							: IN T_DRIVE_INFORMATION;

		Address_DevLB											: OUT	T_SLV_48;
		BlockCount_DevLB									: OUT	T_SLV_48
	);
END;

ARCHITECTURE rtl OF AddressCalculation IS
	CONSTANT SHIFT_WIDTH								: POSITIVE				:= 16;

	SIGNAL Shift_us											: UNSIGNED(log2ceil(SHIFT_WIDTH) DOWNTO 0);
	
	TYPE T_SHIFTED											IS ARRAY(NATURAL RANGE <>) OF T_SLV_48;
	SIGNAL Address_AppLB_Shifted				: T_SHIFTED(SHIFT_WIDTH - 1 DOWNTO 0);
	SIGNAL BlockCount_AppLB_Shifted			: T_SHIFTED(SHIFT_WIDTH - 1 DOWNTO 0);
BEGIN
	Shift_us											<= to_unsigned(LOGICAL_BLOCK_SIZE_ldB - to_integer(to_01(IDF_DriveInformation.LogicalBlockSize_ldB)), Shift_us'length);

	Address_AppLB_Shifted(0)			<= Address_AppLB;
	BlockCount_AppLB_Shifted(0)		<= BlockCount_AppLB;
	
	genShifted : FOR I IN 1 TO SHIFT_WIDTH - 1 GENERATE
		Address_AppLB_Shifted(I)		<= Address_AppLB(Address_AppLB'high - I DOWNTO 0)			& (I - 1 DOWNTO 0 => '0');
		BlockCount_AppLB_Shifted(I)	<= BlockCount_AppLB(Address_AppLB'high - I DOWNTO 0)	& (I - 1 DOWNTO 0 => '0');
	END GENERATE;
	
	Address_DevLB 		<= Address_AppLB_Shifted(to_integer(to_01(Shift_us, '0')));
	BlockCount_DevLB	<= BlockCount_AppLB_Shifted(to_integer(to_01(Shift_us, '0')));
END;
