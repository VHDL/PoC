LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.functions.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;
USE			L_Global.XilinxReconfiguratorTypes.ALL;
USE			L_Global.XilConstMMCM_Virtex6.ALL;

LIBRARY L_SATAController;
USE			L_SATAController.SATATypes.ALL;

-- ==================================================================
-- Notice
-- ==================================================================
--	modifies FPGA configuration bits via Dynamic Reconfiguration Port (DRP)
--
--	changes via DRP require a reset while reprogramming the mmcm

--	used configuration words
--	address		bits		|	MMCM generic name						GEN_1			GEN_2		Note
-- =============================================================================
--	0x05			[4..3]	|	PLL_TXDIVSEL_OUT_1 [0:1]			10				00		divide by 2			divide by 1
--	0x09			[15]		|	PLL_RXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x0A			[0]			|	PLL_RXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x45			[15]		|	PLL_TXDIVSEL_OUT_0 [0]				 1				 0		divide by 2			divide by 1
--	0x46			[0]			|	PLL_TXDIVSEL_OUT_0 [1]				 0				 0		divide by 2			divide by 1
--	0x46			[3..2]	|	PLL_RXDIVSEL_OUT_0 [1:0]			01				00		divide by 2			divide by 1


ENTITY MMCMConfigurator_Virtex6 IS
	GENERIC (
		CHIPSCOPE_KEEP					: BOOLEAN											:= TRUE;		--
		DRPCLOCK_FREQ_MHZ				: REAL												:= 0.0;			--
		PORTS										: POSITIVE										:= 1				-- Number of Ports per Transceiver
	);
	PORT (
		DRP_Clock								: IN	STD_LOGIC;
		DRP_Reset								: IN	STD_LOGIC;

		SATA_Clock							: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		Reconfig								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);							-- @SATA_Clock
		ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);							-- @SATA_Clock
		ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);							-- @SATA_Clock
		Lock										: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);							-- @SATA_Clock
		Locked									: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);							-- @SATA_Clock

		SATA_Generation					: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);			-- @SATA_Clock
		NoDevice								: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);							-- @DRP_Clock

		MMCM_DRP_en							: OUT	STD_LOGIC;																				-- @DRP_Clock
		MMCM_DRP_Address				: OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);											-- @DRP_Clock
		MMCM_DRP_we							: OUT	STD_LOGIC;																				-- @DRP_Clock
		MMCM_DRP_DataIn					: IN	T_SLV_16;																					-- @DRP_Clock
		MMCM_DRP_DataOut				: OUT	T_SLV_16;																					-- @DRP_Clock
		MMCM_DRP_Ack						: IN	STD_LOGIC;																				-- @DRP_Clock

		MMCM_ReloadConfig				: OUT	STD_LOGIC;																				-- @DRP_Clock
		MMCM_ReloadConfigDone		: IN	STD_LOGIC																					-- @DRP_Clock
	);
END;

ARCHITECTURE rtl OF MMCMConfigurator_Virtex6 IS
	ATTRIBUTE KEEP								: BOOLEAN;
	ATTRIBUTE FSM_ENCODING				: STRING;

	CONSTANT XilDRP_ConfigROM			: T_XILDRP_CONFIG_ROM(3 DOWNTO 0)		:=
		(0 => (Configs =>																		-- Port 0, GEN_1
							(0 => ("1000101", x"8000", x"8000"),			-- 0x45,	[15]				1___ ____ ____ ____
							 1 => ("1000110", x"000D", x"0004"),			-- 0x46,	[3..2, 0]		____ ____ ____ 01_0
							 OTHERS => (XILDRP_CONFIG_EMPTY)),
					 Count => 2),
		 1 => (Configs =>																		-- Port 0, GEN_2
							(0 => ("1000101", x"8000", x"0000"),			-- 0x45,	[15]				0___ ____ ____ ____
							 1 => ("1000110", x"000D", x"0000"),			-- 0x46,	[3..2, 0]		____ ____ ____ 00_0
							 OTHERS => (XILDRP_CONFIG_EMPTY)),
					 Count => 2),
		 2 => (Configs =>																		-- Port 0/1, GEN_1
							(0 => ("0000101", x"0018", x"0010"),			-- 0x05,	[4..3]			____ ____ ___1 0___
							 1 => ("0001001", x"8000", x"0000"),			-- 0x09,	[15]				0___ ____ ____ ____
							 2 => ("0001010", x"0001", x"0001"),			-- 0x0A,	[0]					____ ____ ____ ___1
							 3 => ("1000101", x"8000", x"8000"),			-- 0x45,	[15]				1___ ____ ____ ____
							 4 => ("1000110", x"000D", x"0004"),			-- 0x46,	[3..2, 0]		____ ____ ____ 01_0
							 OTHERS => (XILDRP_CONFIG_EMPTY)),
					 Count => 5),
		 3 => (Configs =>																		-- Port 0/1, GEN_2
							(0 => ("0000101", x"0018", x"0000"),			-- 0x05,	[4..3]			____ ____ ___0 0___
							 1 => ("0001001", x"8000", x"0000"),			-- 0x09,	[15]				0___ ____ ____ ____
							 2 => ("0001010", x"0001", x"0000"),			-- 0x0A,	[0]					____ ____ ____ ___0
							 3 => ("1000101", x"8000", x"0000"),			-- 0x45,	[15]				0___ ____ ____ ____
							 4 => ("1000110", x"000D", x"0000"),			-- 0x46,	[3..2, 0]		____ ____ ____ 00_0
							 OTHERS => (XILDRP_CONFIG_EMPTY)),
					 Count => 5)
		);

	TYPE T_STATE IS (
		ST_IDLE,
		ST_LOCKED,
		ST_LOCKED_RECONFIG,

		ST_RECONFIG,	ST_RECONFIG_WAIT,
		ST_RELOAD,		ST_RELOAD_WAIT
	);

	-- MMCM_DualConfiguration - Statemachine
	SIGNAL State											: T_STATE											:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State	: SIGNAL IS "gray";


	SIGNAL Reconfig_i									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL ReconfigComplete_i					: STD_LOGIC;
	SIGNAL ConfigReloaded_i						: STD_LOGIC;

	SIGNAL Sync1_Lock									: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Sync1_SATAGeneration				: T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL SATA_Generation_i					: T_SATA_GENERATION_VECTOR(1 DOWNTO 0)						:= (OTHERS => SATA_GENERATION_1);

	SIGNAL Lock_i											: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Locked_i										: STD_LOGIC;

	SIGNAL doReconfig									: STD_LOGIC;
	SIGNAL doLock											: STD_LOGIC;

	SIGNAL ReloadConfigDone						: STD_LOGIC;
	SIGNAL ReloadConfigDone_d					: STD_LOGIC																	:= '0';
	SIGNAL ReloadConfigDone_re				: STD_LOGIC;

	SIGNAL ReloadConfig_i							: STD_LOGIC;
	SIGNAL ReloadConfigDone_i					: STD_LOGIC;

	SIGNAL XilDRP_Reconfig						: STD_LOGIC;
	SIGNAL XilDRP_ReconfigDone				: STD_LOGIC;
	SIGNAL XilDRP_ConfigSelect				: STD_LOGIC_VECTOR(log2ceilnz(XilDRP_ConfigROM'length) - 1 DOWNTO 0);

	FUNCTION IsSupportedGeneration(SATAGen : T_SATA_GENERATION) RETURN BOOLEAN IS
	BEGIN
		CASE SATAGen IS
			WHEN SATA_GENERATION_1 =>			RETURN TRUE;
			WHEN SATA_GENERATION_2 =>			RETURN TRUE;
			WHEN OTHERS =>								RETURN FALSE;
		END CASE;
	END;

BEGIN
	ASSERT (PORTS <= 2)	REPORT "to many ports per transceiver"	SEVERITY FAILURE;

	-- cross clock domain bit synchronisation
	genSync1 : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL Sync1_Lock_sy						: STD_LOGIC;
		SIGNAL Sync1_Lock_sy1						: STD_LOGIC														:= '0';
		SIGNAL Sync1_Lock_sy2						: STD_LOGIC														:= '0';

		SIGNAL Sync1_SATAGeneration_sy	: T_SATA_GENERATION;
		SIGNAL Sync1_SATAGeneration_sy1	: T_SATA_GENERATION										:= SATA_GENERATION_1;
		SIGNAL Sync1_SATAGeneration_sy2	: T_SATA_GENERATION										:= SATA_GENERATION_1;

	BEGIN
		ASSERT IsSupportedGeneration(SATA_Generation(I))	REPORT "Member of T_SATA_GENERATION not supported"	SEVERITY FAILURE;

		-- synchronize Reconfig(I), Lock(I), SATA_Generation(I) from SATA_Clock to DRP_Clock
		Sync1_Lock_sy							<= Lock(I);
		Sync1_Lock_sy1						<= Sync1_Lock_sy							WHEN rising_edge(DRP_Clock);
		Sync1_Lock_sy2						<= Sync1_Lock_sy1							WHEN rising_edge(DRP_Clock);
		Sync1_Lock(I)							<= Sync1_Lock_sy2;

		Sync1_SATAGeneration_sy		<= SATA_Generation(I);
		Sync1_SATAGeneration_sy1	<= Sync1_SATAGeneration_sy		WHEN rising_edge(DRP_Clock);
		Sync1_SATAGeneration_sy2	<= Sync1_SATAGeneration_sy1		WHEN rising_edge(DRP_Clock);
		Sync1_SATAGeneration(I)		<= Sync1_SATAGeneration_sy2;

		SATA_Generation_i(I)			<= Sync1_SATAGeneration(I);

		Sync1 : ENTITY L_Global.Synchronizer
			GENERIC MAP (
				BW										=> 1,
				GATED_INPUT_BY_BUSY		=> TRUE
			)
			PORT MAP (
				Clock1								=> SATA_Clock(I),
				Clock2								=> DRP_Clock,
				I(0)									=> Reconfig(I),
				O(0)									=> Reconfig_i(I),
				B											=> OPEN
			);

		Lock_i(I)			<= Sync1_Lock(I) AND (NOT NoDevice(I));
	END GENERATE;

	-- calculate shared control signals
	doReconfig				<= slv_or(Reconfig_i);
	doLock						<= slv_or(Lock_i);			-- only connected ports can request locks

	genSync2 : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL Sync2_Locked_sy			: STD_LOGIC;
		SIGNAL Sync2_Locked_sy1			: STD_LOGIC														:= '0';
		SIGNAL Sync2_Locked_sy2			: STD_LOGIC														:= '0';

		SIGNAL Sync2_in							: STD_LOGIC_VECTOR(1 DOWNTO 0);
		SIGNAL Sync2_out						: STD_LOGIC_VECTOR(1 DOWNTO 0);

	BEGIN
		-- synchronize ReconfigComplete, ConfigReloaded, Locked from DRP_Clock to SATA_Clock
		Sync2_Locked_sy			<= Locked_i;
		Sync2_Locked_sy1		<= Sync2_Locked_sy		WHEN rising_edge(SATA_Clock(I));
		Sync2_Locked_sy2		<= Sync2_Locked_sy1		WHEN rising_edge(SATA_Clock(I));
		Locked(I)						<= Sync2_Locked_sy2;

		Sync2_in						<= ConfigReloaded_i & ReconfigComplete_i;

		Sync2 : ENTITY L_Global.Synchronizer
			GENERIC MAP (
				BW										=> 2,
				GATED_INPUT_BY_BUSY		=> TRUE
			)
			PORT MAP (
				Clock1								=> DRP_Clock,
				Clock2								=> SATA_Clock(I),
				I											=> Sync2_in,
				O											=> Sync2_out,
				B											=> OPEN
			);

		ReconfigComplete(I)		<= Sync2_out(0);
		ConfigReloaded(I)			<= Sync2_out(1);
	END GENERATE;

	-- rising_edge(MMCM_ReloadConfigDone)
	ReloadConfigDone		<= MMCM_ReloadConfigDone;
	ReloadConfigDone_d	<= ReloadConfigDone WHEN rising_edge(DRP_Clock);
	ReloadConfigDone_re	<= NOT ReloadConfigDone_d AND ReloadConfigDone;

	PROCESS(DRP_Clock)
	BEGIN
		IF rising_edge(DRP_Clock) THEN
			IF (DRP_Reset = '1') THEN
				State				<= ST_IDLE;
			ELSE
				State				<= NextState;
			END IF;
		END IF;
	END PROCESS;


	PROCESS(State, doReconfig, doLock, XilDRP_ReconfigDone, ReloadConfigDone_re, SATA_Generation_i)
	BEGIN
		NextState				<= State;

		-- default assignments
		-- ==============================================================
		Locked_i								<= '0';
		ReconfigComplete_i			<= '0';
		ConfigReloaded_i				<= '0';

		-- GTP shared port
		ReloadConfig_i					<= '0';

		-- internal modules
		XilDRP_Reconfig					<= '0';
		XilDRP_ConfigSelect			<= to_slv(0, 2);

		CASE State IS
			WHEN ST_IDLE =>
				IF (doLock = '1') THEN
					IF (doReconfig = '1') THEN
						NextState						<= ST_LOCKED_RECONFIG;	-- do reconfig, but lock is set
					ELSE
						NextState						<= ST_LOCKED;						-- lock is set
					END IF;
				ELSE																						-- no lock is requested
					IF (doReconfig = '1') THEN
						NextState						<= ST_RECONFIG;					-- do reconfig
					END IF;
				END IF;

			WHEN ST_LOCKED =>
				Locked_i								<= '1';									-- expose lock-state

				IF (doReconfig = '1') THEN
					IF (doLock = '1') THEN												-- do reconfig, but lock is set
						NextState						<= ST_LOCKED_RECONFIG;
					ELSE
						NextState						<= ST_RECONFIG;					-- do reconfig only for port 0
					END IF;
				ELSE	-- doReconfig
					IF (doLock = '0') THEN
						NextState						<= ST_IDLE;
					ELSE
						NULL;
					END IF;
				END IF;

			WHEN ST_LOCKED_RECONFIG =>
				Locked_i								<= '1';									-- expose lock-state

				IF (doLock = '0') THEN													-- no lock is set, start reconfig
					NextState							<= ST_RECONFIG;					-- do reconfig only for port 0
				END IF;

-- activate XilinxReconfigurator
-- ------------------------------------------------------------------
			WHEN ST_RECONFIG =>
				XilDRP_Reconfig				<= '1';

				IF (PORTS = 1) THEN
					XilDRP_ConfigSelect	<= ite((SATA_Generation_i = SATA_GENERATION_1), to_slv(0, 2), to_slv(1, 2));
				ELSIF (PORTS = 2) THEN
					XilDRP_ConfigSelect	<= ite((SATA_Generation_i = SATA_GENERATION_1), to_slv(2, 2), to_slv(3, 2));
				ELSE
					NULL;
				END IF;

				NextState							<= ST_RECONFIG_WAIT;

			WHEN ST_RECONFIG_WAIT =>
				IF (XilDRP_ReconfigDone = '1') THEN
					ReconfigComplete_i	<= '1';

					NextState						<= ST_RELOAD;
				END IF;

-- reload MMCM_DUAL configuration
-- ------------------------------------------------------------------
			WHEN ST_RELOAD =>
				ReloadConfig_i				<= '1';

				NextState							<= ST_RELOAD_WAIT;					-- send full reset after reconfiguration

			WHEN ST_RELOAD_WAIT =>
				IF (ReloadConfigDone_re = '1') THEN
					ConfigReloaded_i		<= '1';

					NextState						<= ST_IDLE;
				END IF;

		END CASE;
	END PROCESS;

	XilDRP : ENTITY L_Global.XilinxReconfigurator
		GENERIC MAP (
			CHIPSCOPE_KEEP					=> CHIPSCOPE_KEEP,
			CLOCK_FREQ_MHZ					=> DRPCLOCK_FREQ_MHZ,
			CONFIG_COUNT						=> XilDRP_ConfigROM'length
		)
		PORT MAP (
			Clock										=> DRP_Clock,
			Reset										=> DRP_Reset,

			Reconfig								=> XilDRP_Reconfig,
			ReconfigDone						=> XilDRP_ReconfigDone,
			ConfigSelect						=> XilDRP_ConfigSelect,
			ConfigROM								=> XilDRP_ConfigROM,

			DRP_en									=> MMCM_DRP_en,
			DRP_Address							=> MMCM_DRP_Address,
			DRP_we									=> MMCM_DRP_we,
			DRP_DataIn							=> MMCM_DRP_DataIn,
			DRP_DataOut							=> MMCM_DRP_DataOut,
			DRP_Ack									=> MMCM_DRP_Ack
		);


	-- MMCM_ReloadConfig**** interface
	MMCM_ReloadConfig	<= ReloadConfig_i;

END;
