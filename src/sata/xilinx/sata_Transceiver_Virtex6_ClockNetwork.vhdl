LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;

ENTITY SATATransceiver_Virtex6_ClockNetwork IS
	GENERIC (
		CLOCK_IN_FREQ_MHZ					: REAL													:= 150.0;							-- 150 MHz
		PORTS											: POSITIVE											:= 1
	);
	PORT (
		ClockIn_150MHz						: IN	STD_LOGIC;																			--

		ClockNetwork_Reset				: IN	STD_LOGIC;																			-- @async:
		ClockNetwork_ResetDone		:	OUT	STD_LOGIC;																			-- @ClockIn_150MHz:

		SATA_Generation						: IN	T_SATA_GENERATION;		-- _VECTOR(PORTS - 1 DOWNTO 0);

		GTX_Clock_2X							: OUT	STD_LOGIC;		-- _VECTOR(PORTS - 1 DOWNTO 0);
		GTX_Clock_4X							: OUT	STD_LOGIC		-- _VECTOR(PORTS - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF SATATransceiver_Virtex6_ClockNetwork IS
	ATTRIBUTE KEEP											: BOOLEAN;

	SIGNAL ClkNet_Reset_i								: STD_LOGIC;
	SIGNAL ClkNet_Reset_r1							: STD_LOGIC													:= '0';
	SIGNAL ClkNet_Reset_r2							: STD_LOGIC													:= '0';
	SIGNAL ClkNet_Reset									: STD_LOGIC;

	SIGNAL MMCM_Reset										: STD_LOGIC;
	SIGNAL MMCM_Locked_i								: STD_LOGIC;
	SIGNAL MMCM_Locked_d1								: STD_LOGIC													:= '0';
	SIGNAL MMCM_Locked_d2								: STD_LOGIC													:= '0';
	SIGNAL MMCM_Locked									: STD_LOGIC;

	SIGNAL MMCM_ClockFB									: STD_LOGIC;
	SIGNAL MMCM_Clock_150MHz						: STD_LOGIC;
	SIGNAL MMCM_Clock_75MHz							: STD_LOGIC;
	SIGNAL MMCM_Clock_37_5MHz						: STD_LOGIC;

	SIGNAL MMCM_ClockFB_BUFG						: STD_LOGIC;
	SIGNAL MMCM_Clock_150MHz_BUFG				: STD_LOGIC;
	SIGNAL MMCM_Clock_75MHz_BUFG				: STD_LOGIC;
	SIGNAL MMCM_Clock_37_5MHz_BUFG			: STD_LOGIC;

	ATTRIBUTE KEEP OF MMCM_Clock_150MHz_BUFG		: SIGNAL IS CHIPSCOPE_KEEP;
	ATTRIBUTE KEEP OF MMCM_Clock_75MHz_BUFG			: SIGNAL IS CHIPSCOPE_KEEP;
	ATTRIBUTE KEEP OF MMCM_Clock_37_5MHz_BUFG		: SIGNAL IS CHIPSCOPE_KEEP;

	ATTRIBUTE KEEP OF ClockIn_150MHz						: SIGNAL IS CHIPSCOPE_KEEP;

	FUNCTION IsSupportedGeneration(SATAGen : T_SATA_GENERATION) RETURN BOOLEAN IS
	BEGIN
		CASE SATAGen IS
			WHEN SATA_GENERATION_1 =>			RETURN TRUE;
			WHEN SATA_GENERATION_2 =>			RETURN TRUE;
			WHEN OTHERS =>								RETURN FALSE;
		END CASE;
	END;

BEGIN
	-- reset generation
	-- ======================================================================
	-- clock network resets
	ClkNet_Reset_i							<= ClockNetwork_Reset;																					-- @async:

	-- D-FF @ClockIn_150MHz with async reset
	PROCESS(ClockIn_150MHz)
	BEGIN
		IF ((ClkNet_Reset_r2 = '1') AND (MMCM_Locked = '0')) THEN
			ClkNet_Reset_r1			<= '0';
			ClkNet_Reset_r2			<= '0';
		ELSE
			IF rising_edge(ClockIn_150MHz) THEN
				ClkNet_Reset_r1		<= ClkNet_Reset_i;
				ClkNet_Reset_r2		<= ClkNet_Reset_r1;
			END IF;
		END IF;
	END PROCESS;

	ClkNet_Reset								<= ClkNet_Reset_r2;																							-- @ClockIn_150MHz:
	MMCM_Reset									<= ClkNet_Reset;																								-- @ClockIn_150MHz:

	-- resetdone evaluation
	-- ======================================================================
	MMCM_Locked_d1							<= MMCM_Locked_i		WHEN rising_edge(ClockIn_150MHz);
	MMCM_Locked_d2							<= MMCM_Locked_d1		WHEN rising_edge(ClockIn_150MHz);
	MMCM_Locked									<= MMCM_Locked_d2;																							-- @ClockIn_150MHz:

	ClockNetwork_ResetDone			<= MMCM_Locked;																									-- @ClockIn_150MHz:

	-- ==================================================================
	-- ClockBuffers
	-- ==================================================================
	-- Feedback BUFG
	BUFG_ClockFB : BUFG
		PORT MAP (
			I		=> MMCM_ClockFB,
			O		=> MMCM_ClockFB_BUFG
		);

	gen1 : FOR I IN 0 TO 0 GENERATE
		SIGNAL SATA_Generation_d	: T_SATA_GENERATION			:= SATA_GENERATION_2;		-- FIXME: use INITIAL_SATA_GENERATION !!!!
		SIGNAL MuxControl					: STD_LOGIC;
	BEGIN
--		SATA_Generation_d(I)	<= SATA_Generation(I) WHEN rising_edge(ClockIn_150MHz);
--		MuxControl						<= to_sl(SATA_Generation_d(I) = SATA_GENERATION_2);
		SATA_Generation_d	<= SATA_Generation WHEN rising_edge(ClockIn_150MHz);
		MuxControl						<= to_sl(SATA_Generation_d = SATA_GENERATION_2);

		-- half SATA-Word-Clock (GTX 16/20 bit internal interfaces)
		MUX_Clock_2X : BUFGMUX
			PORT MAP (
				S		=> MuxControl,
				I0	=> MMCM_Clock_75MHz,
				I1	=> MMCM_Clock_150MHz,
				O		=> GTX_Clock_2X
			);

		-- SATA-Word-Clock (GTX 32 bit interface)
		MUX_Clock_4X : BUFGMUX
			PORT MAP (
				S		=> MuxControl,
				I0	=> MMCM_Clock_37_5MHz,
				I1	=> MMCM_Clock_75MHz,
				O		=> GTX_Clock_4X
			);
	END GENERATE;

	-- ==================================================================
	-- Mixed-Mode Clock Manager (MMCM)
	-- ==================================================================
	GTX_MMCM : MMCM_ADV
		GENERIC MAP (
			BANDWIDTH								=> "LOW",																	-- LOW = Jitter Filter
			COMPENSATION						=> "ZHOLD",
			CLOCK_HOLD							=> TRUE,
			STARTUP_WAIT						=> FALSE,

			CLKIN1_PERIOD						=> Freq_MHz2Real_ns(CLOCK_IN_FREQ_MHZ),
			CLKIN2_PERIOD						=> Freq_MHz2Real_ns(100.0),								-- Not used

			CLKFBOUT_MULT_F					=> 8.0,
			CLKFBOUT_PHASE					=> 0.0,
			CLKFBOUT_USE_FINE_PS		=> FALSE,

			DIVCLK_DIVIDE						=> 1,

			CLKOUT0_DIVIDE_F				=> 8.0,
			CLKOUT0_PHASE						=> 0.0,
			CLKOUT0_DUTY_CYCLE			=> 0.500,
			CLKOUT0_USE_FINE_PS			=> FALSE,

			CLKOUT1_DIVIDE					=> 16,
			CLKOUT1_PHASE						=> 0.0,
			CLKOUT1_DUTY_CYCLE			=> 0.500,
			CLKOUT1_USE_FINE_PS			=> FALSE,

			CLKOUT2_DIVIDE					=> 32,
			CLKOUT2_PHASE						=> 0.0,
			CLKOUT2_DUTY_CYCLE			=> 0.500,
			CLKOUT2_USE_FINE_PS			=> FALSE,

			CLKOUT3_DIVIDE					=> 1,
			CLKOUT3_PHASE						=> 0.0
		)
		PORT MAP (
			RST									=> MMCM_Reset,

			CLKIN1							=> ClockIn_150MHz,
			CLKIN2							=> ClockIn_150MHz,
			CLKINSEL						=> '1',
			CLKINSTOPPED				=> OPEN,

			CLKFBOUT						=> MMCM_ClockFB,
			CLKFBOUTB						=> OPEN,
			CLKFBIN							=> MMCM_ClockFB_BUFG,
			CLKFBSTOPPED				=> OPEN,

			CLKOUT0							=> MMCM_Clock_150MHz,
			CLKOUT0B						=> OPEN,
			CLKOUT1							=> MMCM_Clock_75MHz,
			CLKOUT1B						=> OPEN,
			CLKOUT2							=> MMCM_Clock_37_5MHz,
			CLKOUT2B						=> OPEN,
			CLKOUT3							=> OPEN,
			CLKOUT3B						=> OPEN,
			CLKOUT4							=> OPEN,
			CLKOUT5							=> OPEN,
			CLKOUT6							=> OPEN,

			-- Dynamic Reconfiguration Port
			DO									=>	OPEN,
			DRDY								=>	OPEN,
			DADDR								=>	"0000000",
			DCLK								=>	'0',
			DEN									=>	'0',
			DI									=>	x"0000",
			DWE									=>	'0',

			PWRDWN							=>	'0',
			LOCKED							=>	MMCM_Locked_i,

			PSCLK								=>	'0',
			PSEN								=>	'0',
			PSINCDEC						=>	'0',
			PSDONE							=>	OPEN
		);

END;
