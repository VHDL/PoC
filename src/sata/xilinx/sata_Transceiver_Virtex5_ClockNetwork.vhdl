LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;

ENTITY SATATransceiver_Virtex5_ClockNetwork IS
	GENERIC (
		CHIPSCOPE_KEEP						: BOOLEAN												:= TRUE;
		CLOCK_IN_FREQ_MHZ					: REAL													:= 150.0;																									-- 150 MHz
		PORTS											: POSITIVE											:= 1;																											-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR			:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_2, SATA_GENERATION_2)			-- intial SATA Generation
	);
	PORT (
		ClockIn_150MHz						: IN	STD_LOGIC;

		ClockNetwork_Reset				: IN	STD_LOGIC;
		ClockNetwork_ResetDone		:	OUT	STD_LOGIC;
		
		SATA_Generation						: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
		
		GTP_Clock_1X							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		GTP_Clock_4X							: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF SATATransceiver_Virtex5_ClockNetwork IS
	ATTRIBUTE KEEP											: BOOLEAN;

	SIGNAL ClkNet_Reset									: STD_LOGIC;
	SIGNAL ClkNet_Reset_i								: STD_LOGIC;
	SIGNAL ClkNet_Reset_r1							: STD_LOGIC		:= '0';
	SIGNAL ClkNet_Reset_r2							: STD_LOGIC		:= '0';
	SIGNAL ClkNet_Reset_r3							: STD_LOGIC		:= '0';

	SIGNAL DCM_Reset										: STD_LOGIC;
--	SIGNAL DCM_Locked										: STD_LOGIC;
--	SIGNAL DCM_Locked_d1								: STD_LOGIC		:= '0';
--	SIGNAL DCM_Locked_d2								: STD_LOGIC		:= '0';
	SIGNAL DCM_Locked_i									: STD_LOGIC;
	
	SIGNAL DCM_Clock_37_5MHz						: STD_LOGIC;
	SIGNAL DCM_Clock_75MHz							: STD_LOGIC;
	SIGNAL DCM_Clock_150MHz							: STD_LOGIC;
	SIGNAL DCM_Clock_300MHz							: STD_LOGIC;
	
	SIGNAL GTP_Clock_1X_i								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL GTP_Clock_4X_i								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	
	FUNCTION IsSupportedGeneration(SATAGen : T_SATA_GENERATION) RETURN BOOLEAN IS
	BEGIN
		CASE SATAGen IS
			WHEN SATA_GENERATION_1 =>			RETURN TRUE;
			WHEN SATA_GENERATION_2 =>			RETURN TRUE;
			WHEN OTHERS =>					RETURN FALSE;
		END CASE;
	END;
	
BEGIN
	ASSERT (PORTS <= 2)	REPORT "to many ports per transceiver"	SEVERITY FAILURE;
	
	gen0 : FOR I IN 0 TO PORTS - 1 GENERATE
		ASSERT IsSupportedGeneration(SATA_Generation(I))	REPORT "Member of T_SATA_GENERATION not supported"	SEVERITY FAILURE;
	END GENERATE;
	
	-- reset generation
	-- ======================================================================
	-- clock network resets
	ClkNet_Reset_i							<= ClockNetwork_Reset;																					-- @async: 
	
	-- D-FF @ClockIn_150MHz with async reset
	PROCESS(ClockIn_150MHz)
	BEGIN
		IF rising_edge(ClockIn_150MHz) THEN
			IF (ClkNet_Reset_i = '1') THEN
				ClkNet_Reset_r1		<= '1';
				ClkNet_Reset_r2		<= '1';
				ClkNet_Reset_r3		<= '1';
			ELSE
				ClkNet_Reset_r1		<= ClkNet_Reset_i;
				ClkNet_Reset_r2		<= ClkNet_Reset_r1;
				ClkNet_Reset_r3		<= ClkNet_Reset_r2;
			END IF;
		END IF;
	END PROCESS;
	
	ClkNet_Reset								<= ClkNet_Reset_r3;																							-- @ClockIn_150MHz: 
	DCM_Reset										<= ClkNet_Reset;																								-- @ClockIn_150MHz: 
	
	-- calculate when all clocknetwork components are stable
--	DCM_Locked_d1						<= DCM_Locked_i		WHEN rising_edge(ClockIn_150MHz);
--	DCM_Locked_d2						<= DCM_Locked_d1	WHEN rising_edge(ClockIn_150MHz);
--	DCM_Locked							<= DCM_Locked_d2;
	
	ClockNetwork_ResetDone	<= DCM_Locked_i;

-- ==================================================================
-- ClockMultiplexers
-- ==================================================================
	gen1 : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL SATA_Generation_d1				: T_SATA_GENERATION		:= INITIAL_SATA_GENERATIONS(INITIAL_SATA_GENERATIONS'low + I);
		SIGNAL SATA_Generation_d2				: T_SATA_GENERATION		:= INITIAL_SATA_GENERATIONS(INITIAL_SATA_GENERATIONS'low + I);
		SIGNAL MuxControl								: STD_LOGIC;
		
		ATTRIBUTE KEEP OF MuxControl		: SIGNAL IS CHIPSCOPE_KEEP;
	BEGIN
		SATA_Generation_d1		<= SATA_Generation(I) WHEN rising_edge(ClockIn_150MHz);
		SATA_Generation_d2		<= SATA_Generation_d1 WHEN rising_edge(ClockIn_150MHz);
		MuxControl						<= to_sl(SATA_Generation_d2 = SATA_GENERATION_2);

		MUX_Clock_1X : BUFGMUX
			PORT MAP (
				S		=> MuxControl,
				I0	=> DCM_Clock_150MHz,
				I1	=> DCM_Clock_300MHz,
				O		=> GTP_Clock_1X_i(I)
			);

		MUX_Clock_4X : BUFGMUX
			PORT MAP (
				S		=> MuxControl,
				I0	=> DCM_Clock_37_5MHz,
				I1	=> DCM_Clock_75MHz,
				O		=> GTP_Clock_4X_i(I)
			);
	END GENERATE;
-- ==================================================================
-- DigitalClockManager (DCM)
-- ==================================================================
	GTP_DCM : DCM_BASE
		GENERIC MAP (
			-- configure CLKIN input
			CLKIN_PERIOD						=> Freq_MHz2Real_ns(CLOCK_IN_FREQ_MHZ),
			DLL_FREQUENCY_MODE			=> "HIGH",
			DUTY_CYCLE_CORRECTION		=> TRUE,
			FACTORY_JF							=> x"F0F0",
			-- configure CLKFB feedback
			CLK_FEEDBACK						=> "NONE",
			-- configure CLKDV output
			CLKDV_DIVIDE						=> 2.0,
			-- configure CLKFX output
			CLKFX_MULTIPLY					=> 2,
			CLKFX_DIVIDE						=> 8
		)
		PORT MAP (
			RST											=> DCM_Reset,

			CLKIN										=> ClockIn_150MHz,
			CLKFB										=> '0',
			
			CLKFX										=> DCM_Clock_37_5MHz,
			CLKFX180								=> OPEN,			
			CLKDV										=> DCM_Clock_75MHz,		-- OPEN,
			CLK0										=> DCM_Clock_150MHz,
			CLK90										=> OPEN,
			CLK180									=> OPEN,
			CLK270									=> OPEN,
			CLK2X										=> DCM_Clock_300MHz,
			CLK2X180								=> OPEN,
			
			LOCKED									=> DCM_Locked_i
		);

	GTP_Clock_1X			<= GTP_Clock_1X_i;
	GTP_Clock_4X			<= GTP_Clock_4X_i;

	genCSP : IF (CHIPSCOPE_KEEP = TRUE) GENERATE
		SIGNAL DBG_Clock_300MHz								: STD_LOGIC;
		
		ATTRIBUTE KEEP OF DBG_Clock_300MHz		: SIGNAL IS TRUE;
	BEGIN
		BUFG_Clock_300MHz : BUFG
			PORT MAP (
				I		=> DCM_Clock_300MHz,
				O		=> DBG_Clock_300MHz
			);
	END GENERATE;

END;
