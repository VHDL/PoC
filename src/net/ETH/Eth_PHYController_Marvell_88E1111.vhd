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


ENTITY Eth_PHYController_Marvell_88E1111 IS
	GENERIC (
		DEBUG						: BOOLEAN													:= FALSE;
		CLOCK_FREQ_MHZ						: REAL														:= 125.0;										-- 125 MHz
		PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS		:= "XXXXX"
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		
		-- PHYController interface
		Command										: IN	T_NET_ETH_PHYCONTROLLER_COMMAND;
		Status										: OUT	T_NET_ETH_PHYCONTROLLER_STATUS;
		Error											: OUT	T_NET_ETH_PHYCONTROLLER_ERROR;

		PHY_Reset									: OUT		STD_LOGIC;
		PHY_Interrupt							: IN		STD_LOGIC;

		MDIO_Command							: OUT	T_IO_MDIO_MDIOCONTROLLER_COMMAND;
		MDIO_Status								: IN	T_IO_MDIO_MDIOCONTROLLER_STATUS;
		MDIO_Error								: IN	T_IO_MDIO_MDIOCONTROLLER_ERROR;

		MDIO_Physical_Address			: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		MDIO_Register_Address			: OUT	STD_LOGIC_VECTOR(4 DOWNTO 0);
		MDIO_Register_DataIn			: IN	T_SLV_16;
		MDIO_Register_DataOut			: OUT	T_SLV_16
	);
END;


ARCHITECTURE rtl OF Eth_PHYController_Marvell_88E1111 IS
	ATTRIBUTE KEEP																		: BOOLEAN;
	ATTRIBUTE FSM_ENCODING														: STRING;

	TYPE T_STATE IS (
		ST_RESET,											ST_RESET_WAIT,
		ST_SEARCH_DEVICE,							ST_SEARCH_DEVICE_WAIT,
		ST_READ_DEVICE_ID_1,					ST_READ_DEVICE_ID_WAIT_1,
		ST_READ_DEVICE_ID_2,					ST_READ_DEVICE_ID_WAIT_2,
		ST_WRITE_INTERRUPT,						ST_WRITE_INTERRUPT_WAIT,
		ST_READ_STATUS,								ST_READ_STATUS_WAIT,
		ST_READ_PHY_SPECIFIC_STATUS,	ST_READ_PHY_SPECIFIC_STATUS_WAIT,
		ST_ERROR
	);
	
	SIGNAL State																			: T_STATE													:= ST_RESET;
	SIGNAl NextState																	: T_STATE;
	
	ATTRIBUTE FSM_ENCODING OF State										: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	CONSTANT C_MDIO_REGADR_COMMAND										: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 0, 5);
	CONSTANT C_MDIO_REGADR_STATUS											: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 1, 5);
	CONSTANT C_MDIO_REGADR_EXT_STATUS									: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(15, 5);
	CONSTANT C_MDIO_REGADR_PHY_IDENTIFIER_1						: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 2, 5);
	CONSTANT C_MDIO_REGADR_PHY_IDENTIFIER_2						: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 3, 5);
	CONSTANT C_MDIO_REGADR_NEXTPAGE_TRANSMIT					: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 7, 5);
	CONSTANT C_MDIO_REGADR_AUTONEG_ADVERTISEMENT			: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 4, 5);
	CONSTANT C_MDIO_REGADR_AUTONEG_EXPANION						: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 6, 5);
	CONSTANT C_MDIO_REGADR_LINKPARTNER_ABILITY				: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 5, 5);
	CONSTANT C_MDIO_REGADR_LINKPARTNER_NEXTPAGE				: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 8, 5);
	CONSTANT C_MDIO_REGADR_1000BASET_CONTROL					: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv( 9, 5);
	CONSTANT C_MDIO_REGADR_1000BASET_STATUS						: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(10, 5);
	CONSTANT C_MDIO_REGADR_PHY_SPECIFIC_CONTROL				: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(16, 5);
	CONSTANT C_MDIO_REGADR_EXT_PHY_SPECIFIC_CONTROL		: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(20, 5);
	CONSTANT C_MDIO_REGADR_EXT_PHY_SPECIFIC_CONTROL2	: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(26, 5);
	CONSTANT C_MDIO_REGADR_PHY_SPECIFIC_STATUS				: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(17, 5);
	CONSTANT C_MDIO_REGADR_EXT_PHY_SPECIFIC_STATUS		: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(27, 5);
	CONSTANT C_MDIO_REGADR_INTERRUPT_ENABLE						: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(18, 5);
	CONSTANT C_MDIO_REGADR_INTERRUPT_STATUS						: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(19, 5);
	CONSTANT C_MDIO_REGADR_EXT_ADDRESS								: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(22, 5);
	CONSTANT C_MDIO_REGADR_GLOBAL_STATUS							: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(23, 5);
	CONSTANT C_MDIO_REGADR_LED_CONTROL								: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(24, 5);
	CONSTANT C_MDIO_REGADR_LED_OVERRIDE								: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(25, 5);
	CONSTANT C_MDIO_REGADR_RECEIVE_ERROR_COUNTER			: STD_LOGIC_VECTOR(4 DOWNTO 0)		:= to_slv(21, 5);	

	CONSTANT TTID_RESET_PULSE													: NATURAL		:= 0;
	CONSTANT TTID_WAITTIME_AFTER_LINK_UP							: NATURAL		:= 1;
	
	CONSTANT TIMING_TABLE															: T_NATVEC	:= (
		TTID_RESET_PULSE								=> TimingToCycles_ms(5000.0,		Freq_MHz2Real_ns(CLOCK_FREQ_MHZ)),
		TTID_WAITTIME_AFTER_LINK_UP			=> TimingToCycles_ms(1.0,			Freq_MHz2Real_ns(CLOCK_FREQ_MHZ))
	);

	SIGNAL TC_Enable																	: STD_LOGIC;
	SIGNAL TC_Load																		: STD_LOGIC;
	SIGNAL TC_Slot																		: INTEGER;
	SIGNAL TC_Timeout																	: STD_LOGIC;

	SIGNAL PHY_Interrupt_rst													: STD_LOGIC;
	SIGNAL PHY_Interrupt_meta													: STD_LOGIC												:= '0';
	SIGNAL PHY_Interrupt_d														: STD_LOGIC												:= '0';
	SIGNAL PHY_Interrupt_l														: STD_LOGIC												:= '0';

	SIGNAL Status_rst																	: STD_LOGIC;
	SIGNAL Status_set																	: STD_LOGIC;
	SIGNAL Status_r																		: STD_LOGIC												:= '0';

BEGIN


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			PHY_Interrupt_meta			<= PHY_Interrupt;
			PHY_Interrupt_d					<= PHY_Interrupt_meta;
		
			IF (PHY_Interrupt_rst = '1') THEN
				PHY_Interrupt_l				<= '0';
			ELSIF (PHY_Interrupt_d = '1') THEN
				PHY_Interrupt_l				<= '1';
			END IF;
		END IF;
	END PROCESS;

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

	PROCESS(State, Command, TC_Timeout, PHY_Interrupt_l, MDIO_Status, MDIO_Error, MDIO_Register_DataIn, Status_r)
	BEGIN
		NextState								<= State;
		
		Status									<= NET_ETH_PHYC_STATUS_RESETING;
		Error										<= NET_ETH_PHYC_ERROR_NONE;
		
		PHY_Reset								<= '0';
		
		MDIO_Command						<= IO_MDIO_MDIOC_CMD_NONE;
		MDIO_Physical_Address		<= "00" & PHY_DEVICE_ADDRESS;
		MDIO_Register_Address		<= C_MDIO_REGADR_COMMAND;
		MDIO_Register_DataOut		<= x"0000";
	
		TC_Enable								<= '0';
		TC_Load									<= '0';
		TC_Slot									<= TTID_RESET_PULSE;
	
		PHY_Interrupt_rst				<= '0';
		Status_rst							<= '0';
		Status_set							<= '0';
	
		CASE State IS
			WHEN ST_RESET =>
				Status							<= NET_ETH_PHYC_STATUS_RESETING;
				
				TC_Load							<= '1';
				TC_Slot							<= TTID_RESET_PULSE;
				PHY_Reset						<= '1';
				
				NextState						<= ST_RESET_WAIT;

			WHEN ST_RESET_WAIT =>
				Status							<= NET_ETH_PHYC_STATUS_RESETING;
				
				TC_Enable						<= '1';
				PHY_Reset						<= '1';
				
				IF (TC_Timeout = '1') THEN
					NextState					<= ST_SEARCH_DEVICE;
				END IF;
			
			WHEN ST_SEARCH_DEVICE =>
				Status							<= NET_ETH_PHYC_STATUS_RESETING;
				MDIO_Command				<= IO_MDIO_MDIOC_CMD_CHECK_ADDRESS;
				
				NextState						<= ST_SEARCH_DEVICE_WAIT;
			
			WHEN ST_SEARCH_DEVICE_WAIT =>
				Status							<= NET_ETH_PHYC_STATUS_RESETING;
			
				CASE MDIO_Status IS
					WHEN IO_MDIO_MDIOC_STATUS_CHECKING =>
						NULL;
					
					WHEN IO_MDIO_MDIOC_STATUS_CHECK_OK =>
						NextState				<= ST_READ_DEVICE_ID_1;
					
					WHEN IO_MDIO_MDIOC_STATUS_CHECK_FAILED =>
						NextState				<= ST_SEARCH_DEVICE;
					
					WHEN IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState				<= ST_ERROR;
						
					WHEN OTHERS =>
						NextState				<= ST_ERROR;
				END CASE;	-- MDIO_Status
				
			WHEN ST_READ_DEVICE_ID_1 =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;
			
				MDIO_Command						<= IO_MDIO_MDIOC_CMD_READ;
				MDIO_Register_Address		<= C_MDIO_REGADR_PHY_IDENTIFIER_1;
				
				NextState								<= ST_READ_DEVICE_ID_WAIT_1;
	
			WHEN ST_READ_DEVICE_ID_WAIT_1 =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;
			
				CASE MDIO_Status IS
					WHEN IO_MDIO_MDIOC_STATUS_READING =>
						NULL;
					
					WHEN IO_MDIO_MDIOC_STATUS_READ_COMPLETE =>
						IF (MDIO_Register_DataIn = x"0141") THEN									-- OUI
							NextState					<= ST_READ_DEVICE_ID_2;
						ELSE
							NextState					<= ST_ERROR;
						END IF;
					
					WHEN IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;
					
					WHEN OTHERS =>
						NextState					<= ST_ERROR;
					
				END CASE;	-- MDIO_Status
	
			WHEN ST_READ_DEVICE_ID_2 =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;
			
				MDIO_Command						<= IO_MDIO_MDIOC_CMD_READ;
				MDIO_Register_Address		<= C_MDIO_REGADR_PHY_IDENTIFIER_2;
				
				NextState								<= ST_READ_DEVICE_ID_WAIT_2;
	
			WHEN ST_READ_DEVICE_ID_WAIT_2 =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;
			
				CASE MDIO_Status IS
					WHEN IO_MDIO_MDIOC_STATUS_READING =>
						NULL;
					
					WHEN IO_MDIO_MDIOC_STATUS_READ_COMPLETE =>
						IF ((MDIO_Register_DataIn(15 DOWNTO 10) = "000011") AND		-- OUI LSB
								(MDIO_Register_DataIn( 9 DOWNTO	 4) = "001100"))			-- Model Number - 88E1111
						THEN
--							NextState					<= ST_WRITE_INTERRUPT;
							NextState					<= ST_READ_PHY_SPECIFIC_STATUS;
						ELSE
							NextState					<= ST_ERROR;
						END IF;
					
					WHEN IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;
					
					WHEN OTHERS =>
						NextState					<= ST_ERROR;
					
				END CASE;	-- MDIO_Status
	
			WHEN ST_WRITE_INTERRUPT =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;
			
				MDIO_Command						<= IO_MDIO_MDIOC_CMD_WRITE;
				MDIO_Register_Address		<= C_MDIO_REGADR_INTERRUPT_ENABLE;
				MDIO_Register_DataOut		<= x"CC14";
				
				NextState								<= ST_WRITE_INTERRUPT_WAIT;
	
			WHEN ST_WRITE_INTERRUPT_WAIT =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;
			
				CASE MDIO_Status IS
					WHEN IO_MDIO_MDIOC_STATUS_WRITING =>
						NULL;
					
					WHEN IO_MDIO_MDIOC_STATUS_WRITE_COMPLETE =>
--						NextState					<= ST_READ_STATUS;
						NextState					<= ST_READ_PHY_SPECIFIC_STATUS;
					
					WHEN IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;
					
					WHEN OTHERS =>
						NextState					<= ST_ERROR;
					
				END CASE;	-- MDIO_Status
	
			WHEN ST_READ_STATUS =>
				IF (Status_r = '0') THEN
					Status								<= NET_ETH_PHYC_STATUS_CONNECTING;
				ELSE
					Status								<= NET_ETH_PHYC_STATUS_CONNECTED;
				END IF;
			
				MDIO_Command						<= IO_MDIO_MDIOC_CMD_READ;
				MDIO_Register_Address		<= C_MDIO_REGADR_STATUS;
				
				NextState								<= ST_READ_STATUS_WAIT;
			
			WHEN ST_READ_STATUS_WAIT =>
				IF (Status_r = '0') THEN
					Status						<= NET_ETH_PHYC_STATUS_CONNECTING;
				ELSE
					Status						<= NET_ETH_PHYC_STATUS_CONNECTED;
				END IF;
			
				CASE MDIO_Status IS
					WHEN IO_MDIO_MDIOC_STATUS_READING =>
						NULL;
					
					WHEN IO_MDIO_MDIOC_STATUS_READ_COMPLETE =>
						IF ((MDIO_Register_DataIn(15)	= '0') AND
								(MDIO_Register_DataIn(10)	= '0') AND
								(MDIO_Register_DataIn(9)	= '0') AND
								(MDIO_Register_DataIn(8)	= '1') AND
								(MDIO_Register_DataIn(6)	= '1') AND
								(MDIO_Register_DataIn(5)	= '1') AND
								(MDIO_Register_DataIn(4)	= '0') AND
								(MDIO_Register_DataIn(3)	= '1') AND
								(MDIO_Register_DataIn(2)	= '1') AND
								(MDIO_Register_DataIn(0)	= '1'))
						THEN
							Status_set			<= '1';
						ELSE
							Status_rst			<= '1';
						END IF;
						
						NextState					<= ST_READ_STATUS;
					
					WHEN IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;
					
					WHEN OTHERS =>
						NextState					<= ST_ERROR;
					
				END CASE;	-- MDIO_Status
			
			WHEN ST_READ_PHY_SPECIFIC_STATUS =>
				IF (Status_r = '0') THEN
					Status								<= NET_ETH_PHYC_STATUS_CONNECTING;
				ELSE
					Status								<= NET_ETH_PHYC_STATUS_CONNECTED;
				END IF;
			
				MDIO_Command						<= IO_MDIO_MDIOC_CMD_READ;
				MDIO_Register_Address		<= C_MDIO_REGADR_PHY_SPECIFIC_STATUS;
				
				NextState								<= ST_READ_PHY_SPECIFIC_STATUS_WAIT;
			
			WHEN ST_READ_PHY_SPECIFIC_STATUS_WAIT =>
				IF (Status_r = '0') THEN
					Status						<= NET_ETH_PHYC_STATUS_CONNECTING;
				ELSE
					Status						<= NET_ETH_PHYC_STATUS_CONNECTED;
				END IF;
			
				CASE MDIO_Status IS
					WHEN IO_MDIO_MDIOC_STATUS_READING =>
						NULL;
					
					WHEN IO_MDIO_MDIOC_STATUS_READ_COMPLETE =>
						IF ((MDIO_Register_DataIn(15)	= '1') AND
								(MDIO_Register_DataIn(14)	= '0') AND
								(MDIO_Register_DataIn(13)	= '1') AND
								(MDIO_Register_DataIn(11)	= '1') AND
								(MDIO_Register_DataIn(10)	= '1') AND
								(MDIO_Register_DataIn(4)	= '0'))
						THEN
							Status_set			<= '1';
						ELSE
							Status_rst			<= '1';
						END IF;
						
						NextState					<= ST_READ_PHY_SPECIFIC_STATUS;
					
					WHEN IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;
					
					WHEN OTHERS =>
						NextState					<= ST_ERROR;
					
				END CASE;	-- MDIO_Status
			
			WHEN ST_ERROR =>
				Status								<= NET_ETH_PHYC_STATUS_ERROR;
				NULL;
			
		END CASE;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF ((Reset OR Status_rst) = '1') THEN
				Status_r			<= '0';
			ELSIF (Status_set = '1') THEN
				Status_r			<= '1';
			END IF;
		END IF;
	END PROCESS;
	
	TC : ENTITY L_IO.TimingCounter
		GENERIC MAP (
			TIMING_TABLE				=> TIMING_TABLE											-- timing table
		)
		PORT MAP (
			Clock								=> Clock,														-- clock
			Enable							=> TC_Enable,												-- enable counter
			Load								=> TC_Load,													-- load Timing Value from TIMING_TABLE selected by slot
			Slot								=> TC_Slot,													-- 
			Timeout							=> TC_Timeout												-- timing reached
		);
END;
