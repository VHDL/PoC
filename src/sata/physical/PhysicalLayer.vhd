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
USE			L_SATAController.SATADebug.ALL;


ENTITY PhysicalLayer IS
	GENERIC (
		CHIPSCOPE_KEEP									: BOOLEAN													:= FALSE;
		CLOCK_IN_FREQ_MHZ								: REAL														:= 150.0;
		CONTROLLER_TYPE									: T_SATA_DEVICE_TYPE							:= SATA_DEVICE_TYPE_HOST;
		ALLOW_SPEED_NEGOTIATION					: BOOLEAN													:= TRUE;
		INITIAL_SATA_GENERATION					: T_SATA_GENERATION								:= SATA_GENERATION_2;
		ALLOW_AUTO_RECONNECT						: BOOLEAN													:= TRUE;
		ALLOW_STANDARD_VIOLATION				: BOOLEAN													:= FALSE;
		OOB_TIMEOUT_US									: INTEGER													:= 0;
		GENERATION_CHANGE_COUNT					: INTEGER													:= 8;
		ATTEMPTS_PER_GENERATION					: INTEGER													:= 4
	);
	PORT (
		Clock														: IN	STD_LOGIC;
		Reset														: IN	STD_LOGIC;										-- general logic reset without some counter resets while Clock is unstable
																																				--   => preserve SATA_Generation between connection-cycles
		SATAGenerationMin								: IN	T_SATA_GENERATION;						-- 
		SATAGenerationMax								: IN	T_SATA_GENERATION;						-- 
		SATA_Generation									: OUT	T_SATA_GENERATION;

		-- PhysicalLayer interface
		Command													: IN	T_SATA_PHY_COMMAND;
		Status													: OUT	T_SATA_PHY_STATUS;
		Error														: OUT	T_SATA_PHY_ERROR;

		DebugPortOut										: OUT	T_DBG_PHYOUT;

		Link_RX_Data										: OUT	T_SLV_32;
		Link_RX_CharIsK									: OUT	T_SATA_CIK;
		
		Link_TX_Data										: IN	T_SLV_32;
		Link_TX_CharIsK									: IN	T_SATA_CIK;

		-- TransceiverLayer interface
		Trans_Reconfig									: OUT	STD_LOGIC;
--		Trans_ReconfigComplete					: IN	STD_LOGIC;
		Trans_ConfigReloaded						: IN	STD_LOGIC;
		Trans_Lock											: OUT	STD_LOGIC;
		Trans_Locked										: IN	STD_LOGIC;
		
		Trans_ResetDone									: IN	STD_LOGIC;
		Trans_OOB_HandshakingComplete		: OUT	STD_LOGIC;
		Trans_Status										: IN	T_SATA_TRANSCEIVER_STATUS;
		Trans_TX_Error									: IN	T_SATA_TRANSCEIVER_TX_ERROR;
		Trans_RX_Error									: IN	T_SATA_TRANSCEIVER_RX_ERROR;

		Trans_RX_OOBStatus							: IN	T_SATA_OOB;
		Trans_RX_Data										: IN	T_SLV_32;
		Trans_RX_CharIsK								: IN	T_SATA_CIK;
		Trans_RX_IsAligned							: IN	STD_LOGIC;

		Trans_TX_OOBCommand							: OUT	T_SATA_OOB;
		Trans_TX_OOBComplete						: IN	STD_LOGIC;
		Trans_TX_Data										: OUT	T_SLV_32;
		Trans_TX_CharIsK								: OUT T_SATA_CIK
	);
END;

ARCHITECTURE rtl OF PhysicalLayer IS
	ATTRIBUTE KEEP						: BOOLEAN;
	ATTRIBUTE FSM_ENCODING		: STRING;
	
	TYPE T_PHY_STATE IS (ST_RESET, ST_LINK_UP, ST_CHANGE_SPEED, ST_LINK_OK, ST_LINK_BROKEN, ST_ERROR);
	
	SIGNAL State											: T_PHY_STATE						:= ST_RESET;
	SIGNAL NextState									: T_PHY_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL SATA_Generation_i					: T_SATA_GENERATION;
	
	SIGNAL Reset_i										: STD_LOGIC;
	
	SIGNAL OOB_Reset									: STD_LOGIC;
	SIGNAL OOB_Retry									: STD_LOGIC;
	SIGNAL OOB_LinkOK									: STD_LOGIC;
	SIGNAL OOB_LinkDead								: STD_LOGIC;
	SIGNAL OOB_Timeout								: STD_LOGIC;
	SIGNAL OOBC_ReceivedReset					: STD_LOGIC;

	SIGNAL SC_Reset										: STD_LOGIC;
	SIGNAL SC_SATAGeneration_Reset		: STD_LOGIC;
	SIGNAL SC_AttemptCounter_Reset		: STD_LOGIC;

	SIGNAL ResetGeneration						: STD_LOGIC;
	SIGNAL ResetTrysPerGeneration_i		: STD_LOGIC;
	SIGNAL Trans_Reconfig_i						: STD_LOGIC;
	SIGNAL NegotiationError						: STD_LOGIC;

	SIGNAL RX_Primitive								: T_SATA_PRIMITIVE;
	SIGNAL TX_Primitive								: T_SATA_PRIMITIVE;
	
	SIGNAL DebugPortOut_i							: T_DBG_PHYOUT;
	SIGNAL Error_i										: T_SATA_PHY_ERROR;
	
BEGIN

	ASSERT FALSE REPORT "  ControllerType:         " & ite((CONTROLLER_TYPE						= SATA_DEVICE_TYPE_HOST), "HOST", "DEVICE") SEVERITY NOTE;
	ASSERT FALSE REPORT "  AllowSpeedNegotiation:  " & ite((ALLOW_SPEED_NEGOTIATION		= TRUE),									"YES",	"NO")			SEVERITY NOTE;
	ASSERT FALSE REPORT "  AllowAutoReconnect:     " & ite((ALLOW_AUTO_RECONNECT			= TRUE),									"YES",	"NO")			SEVERITY NOTE;
	ASSERT FALSE REPORT "  AllowStandardViolation: " & ite((ALLOW_STANDARD_VIOLATION	= TRUE),									"YES",	"NO")			SEVERITY NOTE;
	ASSERT FALSE REPORT "  Init. SATA Generation:  " & ite((INITIAL_SATA_GENERATION		= SATA_GENERATION_1),			"Gen1", "Gen2")		SEVERITY NOTE;

	PROCESS(Reset, Command)
	BEGIN
		Reset_i															<= Reset;
		OOB_Reset														<= Reset;
		SC_Reset														<= Reset;
		SC_SATAGeneration_Reset							<= '0';
		SC_AttemptCounter_Reset							<= '0';
		
		IF (Command = SATA_PHY_CMD_RESET) THEN																							-- full reset of all logic
			Reset_i														<= '1';
			OOB_Reset													<= '1';																					--	=> reset FSM
			SC_Reset													<= '1';																					--	=> reset FSM
			SC_SATAGeneration_Reset						<= '1';																					--	=> reset SATA_Generation, reset all attempt counters => if necessary reconfigure GTP
			SC_AttemptCounter_Reset						<= '1';
		ELSIF (Command = SATA_PHY_CMD_NEWLINK_UP) THEN																			-- reset retry counter, use same generation
			Reset_i														<= '1';
			OOB_Reset													<= '1';
			SC_Reset													<= '1';
		END IF;
	END PROCESS;

	-- ================================================================
	-- physical layer control
	-- ================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset_i = '1') THEN
				State			<= ST_RESET;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;
	
	Error <= Error_i when rising_edge(Clock);
	
	PROCESS(State, Command, Trans_ResetDone, Trans_Reconfig_i, Trans_ConfigReloaded, OOB_LinkOK, OOB_LinkDead, OOBC_ReceivedReset, NegotiationError)
	BEGIN
		NextState								<= State;
		
		Status									<= SATA_PHY_STATUS_RESET;
		Error_i										<= SATA_PHY_ERROR_NONE;
		
		CASE State IS
			WHEN ST_RESET =>
				Status							<= SATA_PHY_STATUS_RESET;
			
				IF (Trans_ResetDone = '1') THEN
					NextState					<= ST_LINK_UP;
				END IF;
	
			WHEN ST_LINK_UP =>
				Status							<= SATA_PHY_STATUS_LINK_UP;
			
				IF (Trans_Reconfig_i = '1') THEN
					NextState					<= ST_CHANGE_SPEED;
				ELSIF (OOB_LinkOK = '1') THEN
					NextState					<= ST_LINK_OK;
				ELSIF (NegotiationError = '1') THEN
					Error_i							<= SATA_PHY_ERROR_NEGOTIATION_ERROR;
					NextState					<= ST_ERROR;
				END IF;
				
			WHEN ST_LINK_OK =>
				Status							<= SATA_PHY_STATUS_LINK_OK;
			
				IF (OOB_LinkOK = '0') THEN
					NextState					<= ST_LINK_BROKEN;
				ELSIF (OOB_LinkDead = '1') THEN
					Error_i							<= SATA_PHY_ERROR_LINK_DEAD;
					NextState					<= ST_ERROR;
				ELSIF (OOBC_ReceivedReset = '1') THEN
					NextState					<= ST_LINK_UP;
				END IF;
			
			WHEN ST_LINK_BROKEN =>
				Status							<= SATA_PHY_STATUS_LINK_BROKEN;
			
				IF (OOB_LinkOK = '1') THEN
					NextState					<= ST_LINK_OK;
				ELSIF (OOB_LinkDead = '1') THEN
					Error_i							<= SATA_PHY_ERROR_LINK_DEAD;
					NextState					<= ST_ERROR;
				ELSIF (OOBC_ReceivedReset = '1') THEN
					NextState					<= ST_LINK_UP;
				END IF;
				
			WHEN ST_CHANGE_SPEED =>
				Status							<= SATA_PHY_STATUS_CHANGE_SPEED;

				IF (Trans_ConfigReloaded = '1') THEN
					NextState					<= ST_LINK_UP;
				END IF;
			
			WHEN ST_ERROR =>
				Status							<= SATA_PHY_STATUS_ERROR;
				IF (OOBC_ReceivedReset = '1') THEN
					NextState					<= ST_LINK_UP;
				END IF;
				
		END CASE;
	END PROCESS;
	
	
-- OOB (out of band) signaling
-- ==================================================================
	genHost : IF (CONTROLLER_TYPE = SATA_DEVICE_TYPE_HOST) GENERATE
		OOBC : ENTITY L_SATAController.OOBControl_Host
			GENERIC MAP (
				CHIPSCOPE_KEEP						=> CHIPSCOPE_KEEP,
				CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
				CLOCK_GEN1_FREQ_MHZ				=> 37.5,
				CLOCK_GEN2_FREQ_MHZ				=> 75.0,
				ALLOW_STANDARD_VIOLATION	=> ALLOW_STANDARD_VIOLATION,
				OOB_TIMEOUT_US						=> OOB_TIMEOUT_US
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> OOB_Reset,

				SATA_Generation						=> SATA_Generation_i,
				Trans_ResetDone						=> Trans_ResetDone,
				
				OOB_TX_Command						=> Trans_TX_OOBCommand,
				OOB_TX_Complete						=> Trans_TX_OOBComplete,
				OOB_RX_Status							=> Trans_RX_OOBStatus,
				OOB_HandshakingComplete		=> Trans_OOB_HandshakingComplete,
				OOB_ReceivedReset					=> OOBC_ReceivedReset,
				
				OOB_Retry									=> OOB_Retry,
				OOB_LinkOK								=> OOB_LinkOK,
				OOB_LinkDead							=> OOB_LinkDead,
				OOB_Timeout								=> OOB_Timeout,

				RX_IsAligned							=> Trans_RX_IsAligned,
				RX_Primitive							=> RX_Primitive,
				TX_Primitive							=> TX_Primitive
			);
	END GENERATE;
	genDev : IF (CONTROLLER_TYPE = SATA_DEVICE_TYPE_DEVICE) GENERATE
		OOBC : ENTITY L_SATAController.OOBControl_Device
			GENERIC MAP (
				CHIPSCOPE_KEEP						=> CHIPSCOPE_KEEP,
				CLOCK_IN_FREQ_MHZ					=> CLOCK_IN_FREQ_MHZ,
				CLOCK_GEN1_FREQ_MHZ				=> 37.5,
				CLOCK_GEN2_FREQ_MHZ				=> 75.0,
				ALLOW_STANDARD_VIOLATION	=> ALLOW_STANDARD_VIOLATION,
				OOB_TIMEOUT_US						=> OOB_TIMEOUT_US
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> OOB_Reset,

				SATA_Generation						=> SATA_Generation_i,
				Trans_ResetDone						=> Trans_ResetDone,
				
				OOB_TX_Command						=> Trans_TX_OOBCommand,
				OOB_TX_Complete						=> Trans_TX_OOBComplete,
				OOB_RX_Status							=> Trans_RX_OOBStatus,
				OOB_HandshakingComplete		=> Trans_OOB_HandshakingComplete,
				OOB_ReceivedReset					=> OOBC_ReceivedReset,
				
				OOB_Retry									=> OOB_Retry,
				OOB_LinkReady							=> OOB_LinkOK,
				OOB_LinkDead							=> OOB_LinkDead,
				OOB_Timeout								=> OOB_Timeout,

				RX_IsAligned							=> Trans_RX_IsAligned,
				RX_Primitive							=> RX_Primitive,
				TX_Primitive							=> TX_Primitive
			);
	END GENERATE;
	

-- speed control
-- ==================================================================
	genSC : IF (ALLOW_SPEED_NEGOTIATION = TRUE) GENERATE
	
	BEGIN
		SC : ENTITY L_SATAController.SpeedControl
			GENERIC MAP (
				CHIPSCOPE_KEEP						=> CHIPSCOPE_KEEP,
				INITIAL_SATA_GENERATION		=> INITIAL_SATA_GENERATION,
				GENERATION_CHANGE_COUNT		=> GENERATION_CHANGE_COUNT,
				ATTEMPTS_PER_GENERATION		=> ATTEMPTS_PER_GENERATION
			)
			PORT MAP (
				Clock											=> Clock,
				Reset											=> SC_Reset,

				SATAGeneration_Reset			=> SC_SATAGeneration_Reset,					--	=> reset SATA_Generation, reset all attempt counters => if necessary reconfigure GTP
				AttemptCounter_Reset			=> SC_AttemptCounter_Reset,

				DebugPortOut							=> DebugPortOut_i,

				-- OOBControl interface
				OOB_Timeout								=> OOB_Timeout,
				OOB_Retry									=> OOB_Retry,

				SATA_GenerationMin				=> SATAGenerationMin,								-- 
				SATA_GenerationMax				=> SATAGenerationMax,								-- 
				SATA_Generation						=> SATA_Generation_i,								-- 
				NegotiationError					=> NegotiationError,								-- speed negotiation unsuccessful
				
				-- reconfiguration interface
				Trans_Reconfig						=> Trans_Reconfig_i,
	--			Trans_ReconfigComplete		=> Trans_ReconfigComplete,
				Trans_ConfigReloaded			=> Trans_ConfigReloaded,
				Trans_Lock								=> Trans_Lock,
				Trans_Locked							=> Trans_Locked
			);
	END GENERATE;
	genNoSC : IF (ALLOW_SPEED_NEGOTIATION = FALSE) GENERATE
		SIGNAL TryCounter_rst			: STD_LOGIC;
		SIGNAL TryCounter_en			: STD_LOGIC;
		SIGNAL TryCounter_s				: SIGNED(log2ceilnz(ATTEMPTS_PER_GENERATION) DOWNTO 0)			:= (OTHERS => '0');
		SIGNAL TryCounter_uf			: STD_LOGIC;
		
		SIGNAL OOB_Timeout_d			: STD_LOGIC					:= '0';
		SIGNAl OOB_Timeout_re			: STD_LOGIC;
		
	BEGIN
		SATA_Generation_i			<= INITIAL_SATA_GENERATION;
		
		Trans_Reconfig_i			<= '0';
		Trans_Lock						<= NOT TryCounter_uf;
	
		OOB_Timeout_d					<= OOB_Timeout WHEN rising_edge(Clock);
		OOB_Timeout_re				<= NOT OOB_Timeout_d AND OOB_Timeout;
		OOB_Retry							<= OOB_Timeout_re AND NOT TryCounter_uf;
		NegotiationError			<= TryCounter_uf;

		TryCounter_rst				<= SC_SATAGeneration_Reset OR SC_AttemptCounter_Reset;
		TryCounter_en					<= OOB_Timeout_re;
	
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (TryCounter_rst = '1') THEN
					TryCounter_s		<= to_signed(ATTEMPTS_PER_GENERATION, TryCounter_s'length);
				ELSE
					IF (TryCounter_en = '1') THEN
						TryCounter_s	<= TryCounter_s - 1;
					END IF;
				END IF;
			END IF;
		END PROCESS;
	
		TryCounter_uf <= TryCounter_s(TryCounter_s'high);
	
	END GENERATE;

	Trans_Reconfig		<= Trans_Reconfig_i;
	SATA_Generation		<= SATA_Generation_i;

	-- physical layer PrimitiveMux
	PROCESS(TX_Primitive, Link_TX_Data, Link_TX_CharIsK)
	BEGIN
		CASE TX_Primitive IS
			WHEN SATA_PRIMITIVE_ALIGN =>																	-- ALIGN				D27.3 D10.2 D10.2 K28.5
				Trans_TX_Data			<= to_slv(SATA_PRIMITIVE_ALIGN);					-- x"7B4A4ABC";
				Trans_TX_CharIsK	<= "0001";
				
			WHEN SATA_PRIMITIVE_DIAL_TONE =>															-- Dial Tone		D10.2 D10.2 D10.2 D10.2
				Trans_TX_Data			<= to_slv(SATA_PRIMITIVE_DIAL_TONE);			-- x"4A4A4A4A";
				Trans_TX_CharIsK	<= "0000";

			WHEN SATA_PRIMITIVE_NONE =>																		-- passthrought data and k-symbols from linklayer
				Trans_TX_Data			<= Link_TX_Data;
				Trans_TX_CharIsK	<= Link_TX_CharIsK;

			WHEN OTHERS =>
				Trans_TX_Data			<= to_slv(SATA_PRIMITIVE_DIAL_TONE);
				Trans_TX_CharIsK	<= "0000";
				
				ASSERT FALSE REPORT "illegal PRIMTIVE" SEVERITY FAILURE;
				
		END CASE;
	END PROCESS;
	
	
	-- physical layer PrimtiveDetector
	PROCESS(Trans_RX_Data, Trans_RX_CharIsK)
	BEGIN
		RX_Primitive <= SATA_PRIMITIVE_NONE;
	
		IF (Trans_RX_CharIsK = "0001") THEN
			CASE Trans_RX_Data IS
				WHEN to_slv(SATA_PRIMITIVE_ALIGN) =>				RX_Primitive <= SATA_PRIMITIVE_ALIGN;
				WHEN to_slv(SATA_PRIMITIVE_SYNC) =>					RX_Primitive <= SATA_PRIMITIVE_SYNC;
				WHEN OTHERS =>															RX_Primitive <= SATA_PRIMITIVE_ILLEGAL;
			END CASE;
		END IF;
	END PROCESS;
	
	-- passthrought RX data
	Link_RX_Data			<= Trans_RX_Data;
	Link_RX_CharIsK		<= Trans_RX_CharIsK;
	
	-- ================================================================
	-- ChipScope
	-- ================================================================
	genCSP : IF (CHIPSCOPE_KEEP = TRUE) GENERATE
		SIGNAL CSP_OOB_Retry														: STD_LOGIC;
		SIGNAL CSP_OOB_LinkOK												: STD_LOGIC;
		SIGNAL CSP_OOB_LinkDead													: STD_LOGIC;
		SIGNAL CSP_OOB_Timeout													: STD_LOGIC;
		SIGNAL CSP_SATA_Generation											: T_SATA_GENERATION;
		SIGNAL CSP_NegotiationError											: STD_LOGIC;
		
		SIGNAL CSP_TX_Primitive_NONE										: STD_LOGIC;
		SIGNAL CSP_TX_Primitive_DIAL_TONE								: STD_LOGIC;
		
		ATTRIBUTE KEEP OF CSP_OOB_Retry									: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_OOB_LinkOK								: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_OOB_LinkDead							: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_OOB_Timeout								: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_SATA_Generation						: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_NegotiationError					: SIGNAL IS TRUE;
		
		ATTRIBUTE KEEP OF CSP_TX_Primitive_NONE					: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_TX_Primitive_DIAL_TONE		: SIGNAL IS TRUE;
		
	BEGIN
		CSP_OOB_Retry									<= OOB_Retry;
		CSP_OOB_LinkOK								<= OOB_LinkOK;
		CSP_OOB_LinkDead							<= OOB_LinkDead;
		CSP_OOB_Timeout								<= OOB_Timeout;
		CSP_SATA_Generation						<= SATA_Generation_i;
		CSP_NegotiationError					<= NegotiationError;

		CSP_TX_Primitive_NONE					<= to_sl(TX_Primitive = SATA_PRIMITIVE_NONE);
		CSP_TX_Primitive_DIAL_TONE		<= to_sl(TX_Primitive = SATA_PRIMITIVE_DIAL_TONE);
	END GENERATE;
	
	-- ================================================================
	-- debug port
	-- ================================================================
	DebugPortOut.GenerationChanges		<= DebugPortOut_i.GenerationChanges;
	DebugPortOut.TrysPerGeneration		<= DebugPortOut_i.TrysPerGeneration;
	DebugPortOut.SATAGeneration				<= DebugPortOut_i.SATAGeneration;
END;
