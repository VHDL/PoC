LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
--USE			PoC.vectors.ALL;
USE			PoC.physical.ALL;
USE			PoC.sata.ALL;
USE			PoC.xil.ALL;


-- ==================================================================
-- Notice
-- ==================================================================
--	modifies FPGA configuration bits via Dynamic Reconfiguration Port (DRP)
--	changes via DRP require a full GTP_DUAL reset

--	used configuration words
--	address		bits		|	GTP_DUAL generic name				GEN_1			GEN_2		Note GEN_1			Note GEN_2
-- ============================================================================================================================================================
--	0x05			[3]			|	PLL_TXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x05			[4]			|	PLL_TXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x09			[15]		|	PLL_RXDIVSEL_OUT_1 [1]				 0				 0		divide by 2			divide by 1
--	0x0A			[0]			|	PLL_RXDIVSEL_OUT_1 [0]				 1				 0		divide by 2			divide by 1
--	0x45			[15]		|	PLL_TXDIVSEL_OUT_0 [0]				 1				 0		divide by 2			divide by 1
--	0x46			[0]			|	PLL_TXDIVSEL_OUT_0 [1]				 0				 0		divide by 2			divide by 1
--	0x46			[3..2]	|	PLL_RXDIVSEL_OUT_0 [1:0]			01				00		divide by 2			divide by 1


ENTITY sata_Transceiver_Virtex5_GTP_Configurator IS
	GENERIC (
		DEBUG											: BOOLEAN											:= FALSE;																-- 
		DRPCLOCK_FREQ					: FREQ												:= 0.0 MHz;																	-- 
		PORTS											: POSITIVE										:= 1;																		-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 1 => C_SATA_GENERATION_MAX)		-- intial SATA Generation
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
			
		GTP_DRP_en							: OUT	STD_LOGIC;																				-- @DRP_Clock
		GTP_DRP_Address					: OUT	T_XIL_DRP_ADDRESS;																-- @DRP_Clock
		GTP_DRP_we							: OUT	STD_LOGIC;																				-- @DRP_Clock
		GTP_DRP_DataIn					: IN	T_XIL_DRP_DATA;																		-- @DRP_Clock
		GTP_DRP_DataOut					: OUT	T_XIL_DRP_DATA;																		-- @DRP_Clock
		GTP_DRP_Ready						: IN	STD_LOGIC;																				-- @DRP_Clock
		
		GTP_ReloadConfig				: OUT	STD_LOGIC;																				-- @DRP_Clock
		GTP_ReloadConfigDone		: IN	STD_LOGIC																					-- @DRP_Clock
	);
END;

ARCHITECTURE rtl OF sata_Transceiver_Virtex5_GTP_Configurator IS
	ATTRIBUTE KEEP								: BOOLEAN;
	ATTRIBUTE FSM_ENCODING				: STRING;

	FUNCTION vec(value : STD_LOGIC) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result : STD_LOGIC_VECTOR(0 DOWNTO 0) := (OTHERS => value);
	BEGIN
		RETURN Result;
	END FUNCTION;

	FUNCTION mv(value : STD_LOGIC_VECTOR; move : INTEGER) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result : STD_LOGIC_VECTOR(value'left + move DOWNTO value'right + move) := value;
	BEGIN
		RETURN Result;
	END FUNCTION;
	
	FUNCTION ins(value: STD_LOGIC_VECTOR; Length : NATURAL) RETURN STD_LOGIC_VECTOR IS
		VARIABLE Result		: STD_LOGIC_VECTOR(Length - 1 DOWNTO 0)		:= (OTHERS => '0');
	BEGIN
		Result(value'range)	:= value;
		RETURN Result;
	END FUNCTION;

	FUNCTION slv(value : UNSIGNED) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		RETURN std_logic_vector(value);
	END FUNCTION;

	-- 1. descibe all used GENERICs
	TYPE GTP_GENERICS IS RECORD
		PLL_TXDIVSEL_OUT_0		: UNSIGNED(1 DOWNTO 0);			-- Port 0: PLL TX ClockDivider
		PLL_RXDIVSEL_OUT_0		: UNSIGNED(1 DOWNTO 0);			-- Port 0: PLL RX ClockDivider
		PLL_TXDIVSEL_OUT_1		: UNSIGNED(1 DOWNTO 0);			-- Port 1: PLL TX ClockDivider
		PLL_RXDIVSEL_OUT_1		: UNSIGNED(1 DOWNTO 0);			-- Port 1: PLL RX ClockDivider
	END RECORD;
	TYPE GTP_GENERICS_VECTOR IS ARRAY(NATURAL RANGE <>) OF GTP_GENERICS;
	
	-- 2. assign each GENERIC for each speed configuration
	-- *DIVSEL_OUT_*:		0 -> divide by 1,		1 -> divide by 2
	--
	-- index -> speed configuration
	CONSTANT GTP_CONFIGS									: GTP_GENERICS_VECTOR := (
		-- SATA Generation 1: set dividers to "01" for divide by 2
		0 => (PLL_TXDIVSEL_OUT_0 => to_unsigned(1, 2),
					PLL_RXDIVSEL_OUT_0 => to_unsigned(1, 2),
					PLL_TXDIVSEL_OUT_1 => to_unsigned(1, 2),
					PLL_RXDIVSEL_OUT_1 => to_unsigned(1, 2)),
		-- SATA Generation 2 set dividers to "00" for divide by 1
		1 => (PLL_TXDIVSEL_OUT_0 => to_unsigned(0, 2),
					PLL_RXDIVSEL_OUT_0 => to_unsigned(0, 2),
					PLL_TXDIVSEL_OUT_1 => to_unsigned(0, 2),
					PLL_RXDIVSEL_OUT_1 => to_unsigned(0, 2))
		);
		
	-- 3. convert GENERICs into ConfigROM enties for each config set and each speed configuration
	CONSTANT XILDRP_CONFIG_ROM								: T_XIL_DRP_CONFIG_ROM := (
		-- Port 0, SATA Generation 1
		0 => (Configs =>																				--		insert, move, convert			GENERIC							position, length
							(0 => (Address => x"0045", Mask => x"8000", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_TXDIVSEL_OUT_0(0)), 15), 16)),				-- 0x45,	[15]				x___ ____ ____ ____
							 1 => (Address => x"0046", Mask => x"0001", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_TXDIVSEL_OUT_0(1)),	 0), 16)),				-- 0x46,	[0]					____ ____ ____ ___x
							 2 => (Address => x"0046", Mask => x"000C", Data => ins(mv(slv(GTP_CONFIGS(0).PLL_RXDIVSEL_OUT_0),		 2), 16)),				-- 0x46,	[3..2]			____ ____ ____ xx__
							 OTHERS => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 2),
		-- Port 0, SATA Generation 2
		1 => (Configs =>																				--		insert, move, convert			GENERIC							position, length
							(0 => (Address => x"0045", Mask => x"8000", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_TXDIVSEL_OUT_0(0)), 15), 16)),				-- 0x45,	[15]				x___ ____ ____ ____
							 1 => (Address => x"0046", Mask => x"0001", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_TXDIVSEL_OUT_0(1)),	 0), 16)),				-- 0x46,	[0]					____ ____ ____ ___x
							 2 => (Address => x"0046", Mask => x"000C", Data => ins(mv(slv(GTP_CONFIGS(1).PLL_RXDIVSEL_OUT_0),		 2), 16)),				-- 0x46,	[3..2]			____ ____ ____ xx__
							 OTHERS => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 2),
		-- Port 1, SATA Generation 1
		2 => (Configs =>																				--		insert, move, convert			GENERIC							position, length
							(0 => (Address => x"0005", Mask => x"0008", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_TXDIVSEL_OUT_1(1)),	 3), 16)),				-- 0x05,	[3]					____ ____ ____ x___
							 1 => (Address => x"0005", Mask => x"0010", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_TXDIVSEL_OUT_1(0)),	 4), 16)),				-- 0x05,	[4]					____ ____ ___x ____
							 2 => (Address => x"0009", Mask => x"8000", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_RXDIVSEL_OUT_1(1)), 15), 16)),				-- 0x09,	[15]				x___ ____ ____ ____
							 3 => (Address => x"000A", Mask => x"0001", Data => ins(mv(vec(GTP_CONFIGS(0).PLL_RXDIVSEL_OUT_1(0)),	 0), 16)),				-- 0x0A,	[0]					____ ____ ____ ___x
							 OTHERS => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 3),
		-- Port 1, SATA Generation 2
		3 => (Configs =>																				--		insert, move, convert			GENERIC							position, length
							(0 => (Address => x"0005", Mask => x"0008", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_TXDIVSEL_OUT_1(1)),	 3), 16)),				-- 0x05,	[3]					____ ____ ____ x___
							 1 => (Address => x"0005", Mask => x"0010", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_TXDIVSEL_OUT_1(0)),	 4), 16)),				-- 0x05,	[4]					____ ____ ___x ____
							 2 => (Address => x"0009", Mask => x"8000", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_RXDIVSEL_OUT_1(1)), 15), 16)),				-- 0x09,	[15]				x___ ____ ____ ____
							 3 => (Address => x"000A", Mask => x"0001", Data => ins(mv(vec(GTP_CONFIGS(1).PLL_RXDIVSEL_OUT_1(0)),	 0), 16)),				-- 0x0A,	[0]					____ ____ ____ ___x
							 OTHERS => C_XIL_DRP_CONFIG_EMPTY),
					LastIndex => 3)
		);
	
	CONSTANT XILDRP_CONFIGSELECT_BITS	: POSITIVE										:= log2ceilnz(XILDRP_CONFIG_ROM'length);
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_LOCKED,
		ST_LOCKED_RECONFIG,
		
		ST_RECONFIG_PORT0,	ST_RECONFIG_PORT0_WAIT,
		ST_RECONFIG_PORT1,	ST_RECONFIG_PORT1_WAIT,
		ST_RELOAD,					ST_RELOAD_WAIT
	);
	
	-- GTP_DualConfiguration - Statemachine
	SIGNAL State											: T_STATE											:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State	: SIGNAL IS getFSMEncoding_gray(DEBUG);
	
	SIGNAL Reconfig_DRP								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL ReconfigComplete_i					: STD_LOGIC;
	SIGNAL ConfigReloaded_i						: STD_LOGIC;
	SIGNAL SATAGeneration_DRP					: T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0)	:= INITIAL_SATA_GENERATIONS;
	
	SIGNAL Lock_DRP										: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL Locked_i										: STD_LOGIC;
	
	SIGNAL doReconfig									: STD_LOGIC;
	SIGNAL doLock											: STD_LOGIC;
	
	SIGNAL ReloadConfig_i							: STD_LOGIC;
	
	SIGNAL XilDRP_Reconfig						: STD_LOGIC;
	SIGNAL XilDRP_ReconfigDone				: STD_LOGIC;
	SIGNAL XilDRP_ConfigSelect				: STD_LOGIC_VECTOR(XILDRP_CONFIGSELECT_BITS - 1 DOWNTO 0);

BEGIN
	ASSERT (PORTS <= 2)	REPORT "to many ports per transceiver"	SEVERITY FAILURE;
	
	-- cross clock domain bit synchronisation
	genSyncSATA_DRP : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL Lock_i								: STD_LOGIC;
		SIGNAL SATAGeneration_SATA	: T_SATA_GENERATION			:= INITIAL_SATA_GENERATIONS(I);
	BEGIN
		-- synchronize Reconfig(I), Lock(I), SATA_Generation(I) from SATA_Clock to DRP_Clock
		sync1 : ENTITY PoC.sync_Flag
			PORT MAP (
				Clock				=> DRP_Clock,
				Input(0)		=> Lock(I),
				Output(0)		=> Lock_i
			);

		sync2 : ENTITY PoC.sync_Strobe
			PORT MAP (
				Clock1			=> SATA_Clock(I),
				Clock2			=> DRP_Clock,
				Input(0)		=> Reconfig(I),
				Output(0)		=> Reconfig_DRP(I)
			);

		-- only connected ports can request locks
		Lock_DRP(I)					<= Lock_i	AND (NOT NoDevice(I));

		-- register SATAGeneration in old clock domain
		SATAGeneration_SATA	<= SATA_Generation(I) WHEN rising_edge(SATA_Clock(I));
		
		-- sample SATAGeneration in new clock domain if Reconfig occurs (SATAGeneration was stable for several cycles)
		PROCESS(DRP_Clock)
		BEGIN
			IF rising_edge(DRP_Clock) THEN
				IF (Reconfig_DRP(I) = '1') THEN
					SATAGeneration_DRP(I)	<= SATAGeneration_SATA;
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;

	-- calculate shared control signals
	doReconfig				<= slv_or(Reconfig_DRP);
	doLock						<= slv_or(Lock_DRP);

	genSyncDRP_SATA : FOR I IN 0 TO PORTS - 1 GENERATE
		-- synchronize Locked_i from DRP_Clock to SATA_Clock(I)
		sync1 : ENTITY PoC.sync_Flag
			PORT MAP (
				Clock				=> DRP_Clock,
				Input(0)		=> Locked_i,
				Output(0)		=> Locked(I)
			);
		
		-- synchronize ReconfigComplete, ConfigReloaded, Locked from DRP_Clock to SATA_Clock		
		sync2 : ENTITY PoC.sync_Strobe
			GENERIC MAP (
				BITS				=> 2
			)
			PORT MAP (
				Clock1			=> DRP_Clock,
				Clock2			=> SATA_Clock(I),
				Input(0)		=> ReconfigComplete_i,
				Input(1)		=> ConfigReloaded_i,
				Output(0)		=> ReconfigComplete(I),
				Output(1)		=> ConfigReloaded(I)
			);
	END GENERATE;

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


	PROCESS(State, doReconfig, doLock, XilDRP_ReconfigDone, GTP_ReloadConfigDone, SATAGeneration_DRP)
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
		XilDRP_ConfigSelect			<= to_slv(0, XILDRP_CONFIGSELECT_BITS);
		
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
						NextState						<= ST_RECONFIG_PORT0;		-- do reconfig
					END IF;
				END IF;

			WHEN ST_LOCKED =>
				Locked_i								<= '1';									-- expose lock-state
			
				IF (doReconfig = '1') THEN
					IF (doLock = '1') THEN												-- do reconfig, but lock is set
						NextState						<= ST_LOCKED_RECONFIG;
					ELSE
						NextState						<= ST_RECONFIG_PORT0;		-- do reconfig only for port 0
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
					NextState							<= ST_RECONFIG_PORT0;		-- do reconfig only for port 0
				END IF;

-- activate XilinxReconfigurator
-- ------------------------------------------------------------------
			WHEN ST_RECONFIG_PORT0 =>
				XilDRP_Reconfig				<= '1';
				XilDRP_ConfigSelect		<= ite((SATAGeneration_DRP(0) = SATA_GENERATION_1), to_slv(0, XILDRP_CONFIGSELECT_BITS), to_slv(1, XILDRP_CONFIGSELECT_BITS));

				NextState							<= ST_RECONFIG_PORT0_WAIT;
			
			WHEN ST_RECONFIG_PORT0_WAIT =>
				XilDRP_ConfigSelect		<= ite((SATAGeneration_DRP(0) = SATA_GENERATION_1), to_slv(0, XILDRP_CONFIGSELECT_BITS), to_slv(1, XILDRP_CONFIGSELECT_BITS));
				
				IF (XilDRP_ReconfigDone = '1') THEN
					IF (PORTS = 2) THEN
						NextState						<= ST_RECONFIG_PORT1;
					ELSE
						ReconfigComplete_i	<= '1';
						NextState						<= ST_RELOAD;
					END IF;
				END IF;
				
			WHEN ST_RECONFIG_PORT1 =>
				XilDRP_Reconfig				<= '1';
				XilDRP_ConfigSelect		<= ite((SATAGeneration_DRP(imin(1, PORTS - 1)) = SATA_GENERATION_1), to_slv(2, XILDRP_CONFIGSELECT_BITS), to_slv(3, XILDRP_CONFIGSELECT_BITS));

				NextState							<= ST_RECONFIG_PORT1_WAIT;
			
			WHEN ST_RECONFIG_PORT1_WAIT =>
				XilDRP_ConfigSelect		<= ite((SATAGeneration_DRP(imin(1, PORTS - 1)) = SATA_GENERATION_1), to_slv(2, XILDRP_CONFIGSELECT_BITS), to_slv(3, XILDRP_CONFIGSELECT_BITS));
				
				IF (XilDRP_ReconfigDone = '1') THEN
					ReconfigComplete_i	<= '1';
					NextState						<= ST_RELOAD;
				END IF;
-- reload GTP_DUAL configuration
-- ------------------------------------------------------------------
			-- assign ReloadConfig until ReloadConfigDone goes to '0'
			WHEN ST_RELOAD =>
				ReloadConfig_i				<= '1';
				
				IF (GTP_ReloadConfigDone = '0') THEN
					NextState						<= ST_RELOAD_WAIT;
				END IF;
			
			-- wait for ReloadConfigDone
			WHEN ST_RELOAD_WAIT =>
				IF (GTP_ReloadConfigDone = '1') THEN
					ConfigReloaded_i		<= '1';
				
					NextState						<= ST_IDLE;
				END IF;
			
		END CASE;
	END PROCESS;

	XilDRP : ENTITY PoC.xil_Reconfigurator
		GENERIC MAP (
			DEBUG					=> DEBUG,
			CLOCK_FREQ					=> DRPCLOCK_FREQ,
			CONFIG_ROM							=> XILDRP_CONFIG_ROM
		)
		PORT MAP (
			Clock										=> DRP_Clock,
			Reset										=> DRP_Reset,
			
			Reconfig								=> XilDRP_Reconfig,
			ReconfigDone						=> XilDRP_ReconfigDone,
			ConfigSelect						=> XilDRP_ConfigSelect,
			
			DRP_en									=> GTP_DRP_en,
			DRP_Address							=> GTP_DRP_Address,
			DRP_we									=> GTP_DRP_we,
			DRP_DataIn							=> GTP_DRP_DataIn,
			DRP_DataOut							=> GTP_DRP_DataOut,
			DRP_Ready								=> GTP_DRP_Ready
		);
		
	-- GTP_ReloadConfig**** interface
	GTP_ReloadConfig	<= ReloadConfig_i;
	
END;
