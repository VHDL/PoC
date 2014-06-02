LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;


ENTITY OOBControl_Device IS
	GENERIC (
		CHIPSCOPE_KEEP						: BOOLEAN														:= FALSE;
		CLOCK_IN_FREQ_MHZ					: REAL															:= 150.0;												-- 
		CLOCK_GEN1_FREQ_MHZ				: REAL															:= 37.5;												-- SATAClock frequency in MHz for SATA generation 1
		CLOCK_GEN2_FREQ_MHZ				: REAL															:= 75.0;												-- SATAClock frequency in MHz for SATA generation 2
		ALLOW_STANDARD_VIOLATION	: BOOLEAN														:= FALSE;
		OOB_TIMEOUT_US						: INTEGER														:= 0
	);
	PORT (
		Clock											: IN	STD_LOGIC;
		Reset											: IN	STD_LOGIC;
		ComReset									: OUT	STD_LOGIC;

		SATA_Generation						: IN	T_SATA_GENERATION;
		Trans_ResetDone						: IN	STD_LOGIC;
		
		OOB_TX_Command						: OUT	T_SATA_OOB;
		OOB_TX_Complete						: IN	STD_LOGIC;
		OOB_RX_Status							: IN	T_SATA_OOB;
		OOB_HandshakingComplete		:	OUT	STD_LOGIC;
		OOB_ReceivedReset					: OUT	STD_LOGIC;
		
		OOB_Retry									: IN	STD_LOGIC;
		OOB_LinkReady							: OUT	STD_LOGIC;
		OOB_LinkDead							: OUT	STD_LOGIC;
		OOB_Timeout								: OUT	STD_LOGIC;
		
		RX_IsAligned							: IN	STD_LOGIC;
		RX_Primitive							: IN	T_SATA_PRIMITIVE;
		TX_Primitive							: OUT	T_SATA_PRIMITIVE
	);
END;

ARCHITECTURE rtl OF OOBControl_Device IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;

	CONSTANT DEFAULT_OOB_TIMEOUT_US		: POSITIVE				:= 880;
	
	CONSTANT OOB_TIMEOUT_NS						: INTEGER					:= ite((OOB_TIMEOUT_US = 0), DEFAULT_OOB_TIMEOUT_US, OOB_TIMEOUT_US) * 1000;
	CONSTANT COMRESET_TIMEOUT_NS			: INTEGER					:= 450;
	CONSTANT COMWAKE_TIMEOUT_NS				: INTEGER					:= 250;
	

	TYPE T_OOBCONTROL_STATE IS (
		ST_DEV_RESET,
		ST_DEV_WAIT_HOST_COMRESET,
		ST_DEV_WAIT_AFTER_HOST_COMRESET,
		ST_DEV_SEND_COMINIT,
		ST_DEV_WAIT_HOST_COMWAKE,
		ST_DEV_WAIT_AFTER_COMWAKE,
		ST_DEV_SEND_COMWAKE,
		ST_DEV_SEND_ALIGN,
		ST_DEV_TIMEOUT,
		ST_DEV_LINK_READY,
		ST_DEV_LINK_BROKEN,
		ST_DEV_LINK_DEAD
	);

	-- OOB-Statemachine
	SIGNAL OOBControl_State					: T_OOBCONTROL_STATE											:= ST_DEV_RESET;
	SIGNAL OOBControl_NextState			: T_OOBCONTROL_STATE;
	ATTRIBUTE FSM_ENCODING OF OOBControl_State		: SIGNAL IS ite(CHIPSCOPE_KEEP, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	-- Timing-Counter
	-- ================================================================
	-- general timeouts
	SIGNAL TC1_en										: STD_LOGIC;
	SIGNAL TC1_Load									: STD_LOGIC;
	SIGNAL TC1_Slot									: INTEGER;
	SIGNAL TC1_Timeout							: STD_LOGIC;
	
	-- OOB state specific timeouts
	SIGNAL TC2_en										: STD_LOGIC;
	SIGNAL TC2_Load									: STD_LOGIC;
	SIGNAL TC2_Slot									: INTEGER;
	SIGNAL TC2_Timeout							: STD_LOGIC;	
	
	FUNCTION IsSupportedGeneration(SATAGen : T_SATA_GENERATION) RETURN BOOLEAN IS
	BEGIN
		CASE SATAGen IS
			WHEN SATA_GENERATION_1 =>			RETURN TRUE;
			WHEN SATA_GENERATION_2 =>			RETURN TRUE;
			WHEN OTHERS =>								RETURN FALSE;
		END CASE;
	END;
	
BEGIN
--	ASSERT IsSupportedGeneration(SATA_Generation)	REPORT "Member of T_SATA_GENERATION not supported" SEVERITY FAILURE;
	ASSERT ((SATA_Generation = SATA_GENERATION_1) OR (SATA_Generation = SATA_GENERATION_2)) REPORT "Member of T_SATA_GENERATION not supported" SEVERITY FAILURE;

	-- OOBControl Statemachine
	-- ======================================================================================================================================
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				OOBControl_State			<= ST_DEV_RESET;
			ELSE
				OOBControl_State			<= OOBControl_NextState;
			END IF;
		END IF;
	END PROCESS;


	PROCESS(OOBControl_State, Trans_ResetDone, SATA_Generation, OOB_Retry, OOB_TX_Complete, OOB_RX_Status, RX_IsAligned, RX_Primitive, TC1_Timeout, TC2_Timeout)
	BEGIN
		OOBControl_NextState		<= OOBControl_State;

		TX_Primitive						<= SATA_PRIMITIVE_DIAL_TONE;		
		OOB_ReceivedReset				<= '0';
		
		-- general timeout
		TC1_en									<= '1';
		TC1_Load								<= '0';
		TC1_Slot								<= 0;
		
		-- OOB state specific timeouts
		TC2_en									<= '0';
		TC2_Load								<= '0';
		TC2_Slot								<= 0;
	
		OOB_LinkReady						<= '0';
		OOB_LinkDead						<= '0';
		OOB_Timeout							<= '0';
		
		OOB_TX_Command					<= SATA_OOB_NONE;
		OOB_HandshakingComplete	<= '0';

		-- handle timeout with highest priority
		IF (TC1_Timeout = '1') THEN
			OOB_Timeout													<= '1';		
		
			TC1_en															<= '0';
			TC1_Load														<= '1';
			TC1_Slot														<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
		
			OOBControl_NextState								<= ST_DEV_TIMEOUT;
			
		-- treat COMRESET as communication reset
		ELSIF ((OOB_RX_Status = SATA_OOB_COMRESET) AND
					 ((OOBControl_State /= ST_DEV_WAIT_HOST_COMRESET) OR
					  (OOBControl_State /= ST_DEV_WAIT_AFTER_HOST_COMRESET)))
		THEN
			OOB_ReceivedReset										<= '1';

			TC1_en															<= '0';
			TC1_Load														<= '1';
			TC1_Slot														<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
			
			TC2_Load														<= '1';
			TC2_Slot														<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
			
			OOBControl_NextState								<= ST_DEV_WAIT_AFTER_HOST_COMRESET;
		ELSE
			CASE OOBControl_State IS
				WHEN ST_DEV_RESET =>
					TC1_en													<= '0';																									-- disable timeout counter
				
					IF (Trans_ResetDone = '1') THEN
						TC1_Load											<= '1';
						TC1_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
						
						OOBControl_NextState					<= ST_DEV_WAIT_HOST_COMRESET;
					END IF;

				WHEN ST_DEV_WAIT_HOST_COMRESET =>
					TC1_en													<= '0';
					
					IF (OOB_RX_Status = SATA_OOB_COMRESET) THEN																										-- host comreset detected
						TC1_Load											<= '1';
						TC2_Load											<= '1';
						
						TC1_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
						TC2_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
						
						OOBControl_NextState					<= ST_DEV_WAIT_AFTER_HOST_COMRESET;
					END IF;
		
				WHEN ST_DEV_WAIT_AFTER_HOST_COMRESET =>
					TC2_en													<= '1';

					IF (OOB_RX_Status = SATA_OOB_COMRESET) THEN																										-- host additional comreset detected
						TC2_Load											<= '1';
						TC2_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
					ELSIF (TC2_Timeout = '1') THEN
						OOB_TX_Command								<= SATA_OOB_COMRESET;
						
						OOBControl_NextState					<= ST_DEV_SEND_COMINIT;
					END IF;

				WHEN ST_DEV_SEND_COMINIT =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
					
					IF (OOB_TX_Complete = '1') THEN
						OOBControl_NextState					<= ST_DEV_WAIT_HOST_COMWAKE;
					ELSIF ((ALLOW_STANDARD_VIOLATION = TRUE) AND (OOB_RX_Status = SATA_OOB_COMWAKE)) THEN					-- allow premature OOB response
						OOBControl_NextState					<= ST_DEV_WAIT_AFTER_COMWAKE;
					END IF;

				WHEN ST_DEV_WAIT_HOST_COMWAKE =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
					
					IF (OOB_RX_Status = SATA_OOB_COMWAKE) THEN																											-- host comwake detected
						TC2_Load											<= '1';
						TC2_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 2,
																						 ite((SATA_Generation = SATA_GENERATION_2), 3, 0));
					
						OOBControl_NextState					<= ST_DEV_WAIT_AFTER_COMWAKE;
					END IF;
				
				WHEN ST_DEV_WAIT_AFTER_COMWAKE =>
					TC2_en													<= '1';

					IF (OOB_RX_Status = SATA_OOB_COMWAKE) THEN																											-- additional host cominit detected
						TC2_Load											<= '1';
						TC2_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 2,
																						 ite((SATA_Generation = SATA_GENERATION_2), 3, 0));
					ELSIF (TC2_Timeout = '1') THEN
						OOB_TX_Command								<= SATA_OOB_COMWAKE;
						
						OOBControl_NextState					<= ST_DEV_SEND_COMWAKE;
					END IF;

				WHEN ST_DEV_SEND_COMWAKE =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
				
					IF (OOB_TX_Complete = '1') THEN
						OOB_HandshakingComplete				<= '1';
					
						OOBControl_NextState					<= ST_DEV_SEND_ALIGN;
					END IF;

				WHEN ST_DEV_SEND_ALIGN =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
				
					IF ((RX_Primitive = SATA_PRIMITIVE_ALIGN) AND (RX_IsAligned = '1')) THEN												-- ALIGN detected
						TX_Primitive									<= SATA_PRIMITIVE_NONE;
						OOB_LinkReady									<= '1';
						
						OOBControl_NextState					<= ST_DEV_LINK_READY;
					END IF;
				
				WHEN ST_DEV_LINK_READY =>
					TX_Primitive										<= SATA_PRIMITIVE_NONE;
					TC1_en													<= '0';
					
					OOB_LinkReady										<= '1';
					
					IF (OOB_RX_Status /= SATA_OOB_NONE) THEN
						OOB_LinkDead									<= '1';
						
						OOBControl_NextState					<= ST_DEV_LINK_DEAD;
					ELSIF (RX_IsAligned = '0') THEN
						OOB_LinkReady									<= '0';
					
						OOBControl_NextState					<= ST_DEV_LINK_BROKEN;
					END IF;
				
				WHEN ST_DEV_LINK_BROKEN =>
					TX_Primitive										<= SATA_PRIMITIVE_ALIGN;
					TC1_en													<= '0';
					
					IF (RX_IsAligned = '1') THEN
						OOB_LinkReady									<= '1';
						
						OOBControl_NextState					<= ST_DEV_LINK_READY;
					END IF;
				
					IF (OOB_Retry = '1') THEN
						TC1_Load											<= '1';
						TC1_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
						
						OOBControl_NextState					<= ST_DEV_RESET;
					END IF;
				
				WHEN ST_DEV_LINK_DEAD =>
					OOB_LinkDead										<= '1';
					TC1_en													<= '0';
					
					IF (OOB_Retry = '1') THEN
						TC1_Load											<= '1';
						TC1_Slot											<= ite((SATA_Generation = SATA_GENERATION_1), 0,
																						 ite((SATA_Generation = SATA_GENERATION_2), 1, 0));
						
						OOBControl_NextState					<= ST_DEV_RESET;
					END IF;
				
				WHEN ST_DEV_TIMEOUT =>
					TC1_en													<= '0';
				
					IF (OOB_Retry = '1') THEN
						OOBControl_NextState					<= ST_DEV_RESET;
					END IF;
				
			END CASE;
		END IF;
	END PROCESS;
	
	TC1 : ENTITY L_IO.TimingCounter
		GENERIC MAP (							-- timing table
			TIMING_TABLE				=> T_NATVEC'(				--		 880 us
															0 => TimingToCycles_ns(OOB_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),					-- slot 0
															1 => TimingToCycles_ns(OOB_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)))					-- slot 1
		)
		PORT MAP (
			Clock								=> Clock,
			Enable							=> TC1_en,
			Load								=> TC1_load,
			Slot								=> TC1_Slot,
			Timeout							=> TC1_Timeout
		);
	
	TC2 : ENTITY L_IO.TimingCounter
		GENERIC MAP (							-- timing table
			TIMING_TABLE				=> T_NATVEC'(				--			ns
															0 => TimingToCycles_ns(COMRESET_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),			-- slot 0
															1 => TimingToCycles_ns(COMRESET_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)),			-- slot 1
															2 => TimingToCycles_ns(COMWAKE_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN1_FREQ_MHZ)),			-- slot 2
															3 => TimingToCycles_ns(COMWAKE_TIMEOUT_NS,	Freq_MHz2Real_ns(CLOCK_GEN2_FREQ_MHZ)))			-- slot 3
		)
		PORT MAP (
			Clock								=> Clock,
			Enable							=> TC2_en,
			Load								=> TC2_load,
			Slot								=> TC2_Slot,
			Timeout							=> TC2_Timeout
		);
		
END;
