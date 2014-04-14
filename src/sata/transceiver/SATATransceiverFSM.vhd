LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;
--USE			L_SATAController.SATADebug.ALL;

ENTITY SATATransceiverFSM IS
	GENERIC (
		CHIPSCOPE_KEEP						: BOOLEAN											:= TRUE;
		PORTS											: POSITIVE										:= 2
	);
	PORT (
		SATAClock									: IN	STD_LOGIC;
		ControlClock							: IN	STD_LOGIC;

		Command										: IN	T_SATA_TRANSCEIVER_COMMAND;				-- @SATAClock: 
		Status										: OUT	T_SATA_TRANSCEIVER_STATUS;				-- @SATAClock: 
		Error											: OUT	T_SATA_TRANSCEIVER_ERROR;					-- @SATAClock: 

		PowerDown									: OUT	STD_LOGIC;												-- @ControlClock: 
		Reset											: OUT	STD_LOGIC;												-- @ControlClock: 
		ResetDone									: IN	STD_LOGIC;												-- @ControlClock: 

		NoDevice									: IN	STD_LOGIC;												-- @ControlClock: 
		NewDevice									: IN	STD_LOGIC;												-- @ControlClock: 
		
		TX_BufferStatus						: IN	STD_LOGIC;												-- @ControlClock: 
		RX_BufferStatus						: IN	STD_LOGIC;												-- @ControlClock: 
		
		Reconfig									: OUT	STD_LOGIC;												-- @ControlClock: 
		ReconfigDone							: IN	STD_LOGIC;												-- @ControlClock: 
		Reload										: OUT	STD_LOGIC;												-- @ControlClock: 
		ReloadDone								: IN	STD_LOGIC													-- @ControlClock: 
	);
END;


ARCHITECTURE rtl OF SATATransceiverFSM IS
	ATTRIBUTE KEEP 								: BOOLEAN;
	ATTRIBUTE FSM_ENCODING				: STRING;

	TYPE T_STATE IS (
		ST_POWER_DOWN, ST_POWERED_DOWN, ST_POWER_UP,
		ST_RESET,			ST_RESET_WAIT,
		ST_READY,			ST_READY_LOCKED,
		ST_RECONFIG,	ST_RECONFIG_WAIT,
		ST_RELOAD,		ST_RELOAD_WAIT,
		ST_NO_DEVICE,
		ST_NEW_DEVICE
	);
	
	SIGNAL State											: T_STATE							:= ST_RESET_WAIT;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	SIGNAL FSM_Reset									: STD_LOGIC;
	
BEGIN

	FSM_Reset			<= '1';

	PROCESS(SATAClock)
	BEGIN
		IF rising_edge(SATAClock) THEN
			IF (FSM_Reset = '1') THEN
				State				<= ST_RESET_WAIT;
			ELSE
				State				<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Command, NoDevice, NewDevice, ReconfigDone, ReloadDone)
	BEGIN
		NextState								<= State;
		
		Status									<= SATA_TRANSCEIVER_STATUS_RESETING;
		Error										<= SATA_TRANSCEIVER_ERROR_NONE;
	
		Reset										<= '0';
		Reconfig								<= '0';
		Reload									<= '0';
	
		CASE State IS
			-- TODO: please review this operation
			WHEN ST_POWER_DOWN => 
				Status							<= SATA_TRANSCEIVER_STATUS_POWERED_DOWN;
				NextState						<= ST_POWERED_DOWN;
		
			-- TODO: please review this operation
			WHEN ST_POWERED_DOWN =>
				Status							<= SATA_TRANSCEIVER_STATUS_POWERED_DOWN;
				
				IF (Command = SATA_TRANSCEIVER_CMD_POWERUP) THEN
					NextState					<= ST_POWER_UP;
				END IF;
			
			-- TODO: please review this operation
			WHEN ST_POWER_UP =>
				Status							<= SATA_TRANSCEIVER_STATUS_POWERED_DOWN;
				NextState						<= ST_READY;
			
			-- ======================================================================
			WHEN ST_RESET =>
				Status							<= SATA_TRANSCEIVER_STATUS_RESETING;
				Reset								<= '1';
				NextState						<= ST_RESET_WAIT;
				
			WHEN ST_RESET_WAIT =>
				Status							<= SATA_TRANSCEIVER_STATUS_RESETING;
				
				IF (ResetDone = '1') THEN
					NextState					<= ST_READY;
				END IF;
			
			-- ======================================================================
			WHEN ST_READY =>
				Status							<= SATA_TRANSCEIVER_STATUS_READY;
				
				IF (NoDevice = '1') THEN
					NextState					<= ST_NO_DEVICE;
				ELSE
					CASE Command IS
						WHEN SATA_TRANSCEIVER_CMD_POWERDOWN =>
							NextState			<= ST_POWER_DOWN;
					
						WHEN SATA_TRANSCEIVER_CMD_RESET =>
							NextState			<= ST_RESET;
					
						WHEN SATA_TRANSCEIVER_CMD_RECONFIG =>
							NextState			<= ST_RECONFIG;
						
						WHEN SATA_TRANSCEIVER_CMD_NONE =>
							NULL;				
						WHEN OTHERS =>
							Error					<= SATA_TRANSCEIVER_ERROR_FSM;
					END CASE;
				END IF;

			-- FIXME: not yet implemented
			WHEN ST_READY_LOCKED =>
				Status							<= SATA_TRANSCEIVER_STATUS_READY_LOCKED;

			-- ======================================================================
			WHEN ST_RECONFIG =>
				Status							<= SATA_TRANSCEIVER_STATUS_RECONFIGURING;
				Reconfig						<= '1';
				NextState						<= ST_RECONFIG_WAIT;
			
			WHEN ST_RECONFIG_WAIT =>
				Status							<= SATA_TRANSCEIVER_STATUS_RECONFIGURING;
				
				IF (ReconfigDone = '1') THEN
					NextState					<= ST_RELOAD;
				END IF;

			-- ======================================================================
			WHEN ST_RELOAD =>
				Status							<= SATA_TRANSCEIVER_STATUS_RELOADING;
				Reload							<= '1';
				NextState						<= ST_RELOAD;
			
			WHEN ST_RELOAD_WAIT =>
				Status							<= SATA_TRANSCEIVER_STATUS_RELOADING;

				IF (ReloadDone = '1') THEN
					NextState					<= ST_RELOAD;
				END IF;
			
			-- ======================================================================
			WHEN ST_NO_DEVICE =>
				Status							<= SATA_TRANSCEIVER_STATUS_NO_DEVICE;
				
				IF (NewDevice = '1') THEN
					NextState					<= ST_NEW_DEVICE;
				END IF;
				
			WHEN ST_NEW_DEVICE =>
				NextState						<= ST_READY;
				
		END CASE;
		
--	SATA_TRANSCEIVER_CMD_NONE,
--		SATA_TRANSCEIVER_CMD_POWERDOWN,
--		SATA_TRANSCEIVER_CMD_POWERUP,
--		SATA_TRANSCEIVER_CMD_RESET,
--		SATA_TRANSCEIVER_CMD_RECONFIG
--		UNLOCK
		
--		SATA_TRANSCEIVER_STATUS_NEW_DEVICE,
--		SATA_TRANSCEIVER_STATUS_ERROR
	
	END PROCESS;
END;
