LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;

ENTITY Eth_PHYController IS
	GENERIC (
		DEBUG						: BOOLEAN																	:= FALSE;																			-- 
		CLOCK_FREQ_MHZ						: REAL																		:= 125.0;																			-- 125 MHz
		PCSCORE										: T_NET_ETH_PCSCORE												:= NET_ETH_PCSCORE_GENERIC_GMII;							-- 
		PHY_DEVICE								: T_NET_ETH_PHY_DEVICE										:= NET_ETH_PHY_DEVICE_MARVEL_88E1111;					-- 
		PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS						:= x"00";																			-- 
		PHY_MANAGEMENT_INTERFACE	: T_NET_ETH_PHY_MANAGEMENT_INTERFACE			:= NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO;			-- 
		BAUDRATE_BAUD							: REAL																		:= 1.0 * 1000.0 * 1000.0											-- 1.0 MBit/s
	);
	PORT (
		Clock											: IN		STD_LOGIC;
		Reset											: IN		STD_LOGIC;
		
		-- PHYController interface
		Command										: IN		T_NET_ETH_PHYCONTROLLER_COMMAND;
		Status										: OUT		T_NET_ETH_PHYCONTROLLER_STATUS;
		Error											: OUT		T_NET_ETH_PHYCONTROLLER_ERROR;

		PHY_Reset									: OUT		STD_LOGIC;															-- 
		PHY_Interrupt							: IN		STD_LOGIC;															-- 
		PHY_MDIO									: INOUT T_NET_ETH_PHY_INTERFACE_MDIO						-- Management Data Input/Output
	);
END;


ARCHITECTURE rtl OF Eth_PHYController IS
	ATTRIBUTE KEEP											: BOOLEAN;
	ATTRIBUTE FSM_ENCODING							: STRING;

	SIGNAL PHYC_MDIO_Command						: T_NET_ETH_MDIOCONTROLLER_COMMAND;
	SIGNAL MDIO_Status									: T_NET_ETH_MDIOCONTROLLER_STATUS;
	SIGNAL MDIO_Error										: T_NET_ETH_MDIOCONTROLLER_ERROR;
	
--	SIGNAL Strobe												: STD_LOGIC;
	SIGNAL PHYC_MDIO_Physical_Address		: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL PHYC_MDIO_Register_Address		: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL MDIOC_Register_DataIn				: T_SLV_16;
	SIGNAL PHYC_MDIO_Register_DataOut		: T_SLV_16;

	-- PCS_ADDRESS								: T_SLV_8																	:= x"00";
BEGIN

	ASSERT FALSE REPORT "BAUDRATE_BAUD =          " & REAL'image(BAUDRATE_BAUD)						& " Baud" SEVERITY NOTE;
--	ASSERT FALSE REPORT "MD_CLOCK_FREQUENCY_KHZ = " & REAL'image(MD_CLOCK_FREQUENCY_KHZ)	& " kHz" SEVERITY NOTE;

	genMarvel88E1111 : IF (PHY_DEVICE = NET_ETH_PHY_DEVICE_MARVEL_88E1111) GENERATE
	
	BEGIN
		PHYC : ENTITY L_Ethernet.Eth_PHYController_Marvell_88E1111
			GENERIC MAP (
				DEBUG										=> DEBUG,
				CLOCK_FREQ_MHZ					=> CLOCK_FREQ_MHZ,
				PHY_DEVICE_ADDRESS			=> PHY_DEVICE_ADDRESS
			)
			PORT MAP (
				Clock										=> Clock,
				Reset										=> Reset,
				
				-- PHYController interface
				Command									=> Command,
				Status									=> Status,
				Error										=> Error,
				
				PHY_Reset								=> PHY_Reset,
				PHY_Interrupt						=> PHY_Interrupt,
				
				MDIO_Command						=> PHYC_MDIO_Command,
				MDIO_Status							=> MDIO_Status,
				MDIO_Error							=> MDIO_Error,
		
				MDIO_Physical_Address		=> PHYC_MDIO_Physical_Address,
				MDIO_Register_Address		=> PHYC_MDIO_Register_Address,
				MDIO_Register_DataIn		=> MDIOC_Register_DataIn,
				MDIO_Register_DataOut		=> PHYC_MDIO_Register_DataOut
			);
	END GENERATE;
	
	genMDIOC0 : IF (PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO) GENERATE
		-- Management Data Input/Output Controller
		MDIOC : ENTITY L_Ethernet.Eth_MDIOController
			GENERIC MAP (
				DEBUG						=> DEBUG,
				CLOCK_FREQ_MHZ						=> CLOCK_FREQ_MHZ
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> Reset,
				
				-- MDIO interface
				Command										=> PHYC_MDIO_Command,
				Status										=> MDIO_Status,
				Error											=> MDIO_Error,
				
				Physical_Address					=> PHYC_MDIO_Physical_Address(4 DOWNTO 0),
				Register_Address					=> PHYC_MDIO_Register_Address,
				DataIn										=> PHYC_MDIO_Register_DataOut,
				DataOut										=> MDIOC_Register_DataIn,
				
				-- tristate interface
				MD_Clock_i								=> PHY_MDIO.Clock_i,		-- IEEE 802.3: MDC		-> Managament Clock I
				MD_Clock_o								=> PHY_MDIO.Clock_o,		-- IEEE 802.3: MDC		-> Managament Clock O
				MD_Clock_t								=> PHY_MDIO.Clock_t,		-- IEEE 802.3: MDC		-> Managament Clock tri-state
				MD_Data_i									=> PHY_MDIO.Data_i,			-- IEEE 802.3: MDIO		-> Managament Data I
				MD_Data_o									=> PHY_MDIO.Data_o,			-- IEEE 802.3: MDIO		-> Managament Data O
				MD_Data_t									=> PHY_MDIO.Data_t			-- IEEE 802.3: MDIO		-> Managament Data tri-state
			);
	END GENERATE;

	genMDIOC1 : IF (PHY_MANAGEMENT_INTERFACE = NET_ETH_PHY_MANAGEMENT_INTERFACE_MDIO_OVER_IIC) GENERATE
		SIGNAL Ad_Command									: T_IO_IIC_SFF8431_COMMAND;
		SIGNAL Ad_Status									: T_NET_ETH_MDIOCONTROLLER_STATUS;
		SIGNAL Ad_PhysicalAddress					: STD_LOGIC_VECTOR(6 DOWNTO 0);
		SIGNAL Ad_RegisterAddress					: T_SLV_8;
		SIGNAL Ad_MoreBytes								: STD_LOGIC;
		SIGNAL Ad_Data										: T_SLV_8;
		SIGNAL Ad_LastByte								: STD_LOGIC;
		
		SIGNAL IICC_Status								: T_IO_IIC_SFF8431_STATUS;
		SIGNAL IICC_Error									: T_IO_IIC_SFF8431_ERROR;
		SIGNAL IICC_NextByte							: STD_LOGIC;
		SIGNAL IICC_Data									: T_SLV_8;
		SIGNAL IICC_Valid									: STD_LOGIC;
		
	BEGIN
		Adapter : ENTITY L_Ethernet.MDIO_SFF8431_Adapter
			GENERIC MAP (
				DEBUG						=> DEBUG
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> Reset,
				
				-- MDIO interface
				Command										=> PHYC_MDIO_Command,
				Status										=> MDIO_Status,
				Error											=> MDIO_Error,
				
				Physical_Address					=> PHYC_MDIO_Physical_Address,
				Register_Address					=> PHYC_MDIO_Register_Address,
				Register_DataIn						=> PHYC_MDIO_Register_DataOut,
				Register_DataOut					=> MDIOC_Register_DataIn,
				
				-- IICController_SFF8431 interface
				SFF8431_Command						=> Ad_Command,
				SFF8431_Status						=> IICC_Status,
				SFF8431_Error							=> IICC_Error,
				
				SFF8431_PhysicalAddress		=> Ad_PhysicalAddress,
				SFF8431_RegisterAddress		=> Ad_RegisterAddress,
				
				SFF8431_LastByte					=> Ad_LastByte,
				SFF8431_DataIn						=> IICC_Data,
				SFF8431_Valid							=> IICC_Valid,
				
				SFF8431_MoreBytes					=> Ad_MoreBytes,
				SFF8431_DataOut						=> Ad_Data,
				SFF8431_NextByte					=> IICC_NextByte
			);
		
		IICC : ENTITY L_IO.IICController_SFF8431
			GENERIC MAP (
				DEBUG						=> DEBUG,				-- 
				CLOCK_FREQ_MHZ						=> CLOCK_FREQ_MHZ,			-- 
				IIC_FREQ_KHZ							=> 100.0									-- 100 kHz
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> Reset,
				
				-- IICController interface
				Command										=> Ad_Command,
				Status										=> IICC_Status,
				Error											=> IICC_Error,
				
				PhysicalAddress						=> Ad_PhysicalAddress,
				RegisterAddress						=> Ad_RegisterAddress,
				
				In_MoreBytes							=> Ad_MoreBytes,
				In_Data										=> Ad_Data,
				In_NextByte								=> IICC_NextByte,
				
				Out_LastByte							=> Ad_LastByte,
				Out_Data									=> IICC_Data,
				Out_Valid									=> IICC_Valid,
				
				-- tristate interface
				SerialClock_i							=> PHY_MDIO.Clock_i,
				SerialClock_o							=> PHY_MDIO.Clock_o,
				SerialClock_t							=> PHY_MDIO.Clock_t,
				SerialData_i							=> PHY_MDIO.Data_i,
				SerialData_o							=> PHY_MDIO.Data_o,
				SerialData_t							=> PHY_MDIO.Data_t
			);
	END GENERATE;
--	END BLOCK;
END;
