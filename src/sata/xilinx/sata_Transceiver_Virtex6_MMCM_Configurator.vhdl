library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.functions.all;

library L_Global;
use			PoC.GlobalTypes.all;
use			PoC.XilinxReconfiguratorTypes.all;
use			PoC.XilConstMMCM_Virtex6.all;

library L_SATAController;
use			L_SATAController.SATATypes.all;

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


entity MMCMConfigurator_Virtex6 is
	generic (
		CHIPSCOPE_KEEP					: BOOLEAN											:= TRUE;		--
		DRPCLOCK_FREQ_MHZ				: REAL												:= 0.0;			--
		PORTS										: POSITIVE										:= 1				-- Number of Ports per Transceiver
	);
	port (
		DRP_Clock								: in	STD_LOGIC;
		DRP_Reset								: in	STD_LOGIC;

		SATA_Clock							: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		Reconfig								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);							-- @SATA_Clock
		ReconfigComplete				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);							-- @SATA_Clock
		ConfigReloaded					: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);							-- @SATA_Clock
		Lock										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);							-- @SATA_Clock
		Locked									: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);							-- @SATA_Clock

		SATA_Generation					: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);			-- @SATA_Clock
		NoDevice								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);							-- @DRP_Clock

		MMCM_DRP_en							: out	STD_LOGIC;																				-- @DRP_Clock
		MMCM_DRP_Address				: out	STD_LOGIC_VECTOR(6 downto 0);											-- @DRP_Clock
		MMCM_DRP_we							: out	STD_LOGIC;																				-- @DRP_Clock
		MMCM_DRP_DataIn					: in	T_SLV_16;																					-- @DRP_Clock
		MMCM_DRP_DataOut				: out	T_SLV_16;																					-- @DRP_Clock
		MMCM_DRP_Ack						: in	STD_LOGIC;																				-- @DRP_Clock

		MMCM_ReloadConfig				: out	STD_LOGIC;																				-- @DRP_Clock
		MMCM_ReloadConfigDone		: in	STD_LOGIC																					-- @DRP_Clock
	);
end;

architecture rtl of MMCMConfigurator_Virtex6 is
	attribute KEEP								: BOOLEAN;
	attribute FSM_ENCODING				: STRING;

	constant XilDRP_ConfigROM			: T_XILDRP_CONFIG_ROM(3 downto 0)		:=
		(0 => (Configs =>																		-- Port 0, GEN_1
							(0 => ("1000101", x"8000", x"8000"),			-- 0x45,	[15]				1___ ____ ____ ____
							 1 => ("1000110", x"000D", x"0004"),			-- 0x46,	[3..2, 0]		____ ____ ____ 01_0
							 others => (XILDRP_CONFIG_EMPTY)),
					 Count => 2),
		 1 => (Configs =>																		-- Port 0, GEN_2
							(0 => ("1000101", x"8000", x"0000"),			-- 0x45,	[15]				0___ ____ ____ ____
							 1 => ("1000110", x"000D", x"0000"),			-- 0x46,	[3..2, 0]		____ ____ ____ 00_0
							 others => (XILDRP_CONFIG_EMPTY)),
					 Count => 2),
		 2 => (Configs =>																		-- Port 0/1, GEN_1
							(0 => ("0000101", x"0018", x"0010"),			-- 0x05,	[4..3]			____ ____ ___1 0___
							 1 => ("0001001", x"8000", x"0000"),			-- 0x09,	[15]				0___ ____ ____ ____
							 2 => ("0001010", x"0001", x"0001"),			-- 0x0A,	[0]					____ ____ ____ ___1
							 3 => ("1000101", x"8000", x"8000"),			-- 0x45,	[15]				1___ ____ ____ ____
							 4 => ("1000110", x"000D", x"0004"),			-- 0x46,	[3..2, 0]		____ ____ ____ 01_0
							 others => (XILDRP_CONFIG_EMPTY)),
					 Count => 5),
		 3 => (Configs =>																		-- Port 0/1, GEN_2
							(0 => ("0000101", x"0018", x"0000"),			-- 0x05,	[4..3]			____ ____ ___0 0___
							 1 => ("0001001", x"8000", x"0000"),			-- 0x09,	[15]				0___ ____ ____ ____
							 2 => ("0001010", x"0001", x"0000"),			-- 0x0A,	[0]					____ ____ ____ ___0
							 3 => ("1000101", x"8000", x"0000"),			-- 0x45,	[15]				0___ ____ ____ ____
							 4 => ("1000110", x"000D", x"0000"),			-- 0x46,	[3..2, 0]		____ ____ ____ 00_0
							 others => (XILDRP_CONFIG_EMPTY)),
					 Count => 5)
		);

	type T_STATE is (
		ST_IDLE,
		ST_LOCKED,
		ST_LOCKED_RECONFIG,

		ST_RECONFIG,	ST_RECONFIG_WAIT,
		ST_RELOAD,		ST_RELOAD_WAIT
	);

	-- MMCM_DualConfiguration - Statemachine
	signal State											: T_STATE											:= ST_IDLE;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING	OF State	: signal IS "gray";


	signal Reconfig_i									: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal ReconfigComplete_i					: STD_LOGIC;
	signal ConfigReloaded_i						: STD_LOGIC;

	signal Sync1_Lock									: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal Sync1_SATAGeneration				: T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);

	signal SATA_Generation_i					: T_SATA_GENERATION_VECTOR(1 downto 0)						:= (others => SATA_GENERATION_1);

	signal Lock_i											: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal Locked_i										: STD_LOGIC;

	signal doReconfig									: STD_LOGIC;
	signal doLock											: STD_LOGIC;

	signal ReloadConfigDone						: STD_LOGIC;
	signal ReloadConfigDone_d					: STD_LOGIC																	:= '0';
	signal ReloadConfigDone_re				: STD_LOGIC;

	signal ReloadConfig_i							: STD_LOGIC;
	signal ReloadConfigDone_i					: STD_LOGIC;

	signal XilDRP_Reconfig						: STD_LOGIC;
	signal XilDRP_ReconfigDone				: STD_LOGIC;
	signal XilDRP_ConfigSelect				: STD_LOGIC_VECTOR(log2ceilnz(XilDRP_ConfigROM'length) - 1 downto 0);

	function IsSupportedGeneration(SATAGen : T_SATA_GENERATION) return BOOLEAN is
	begin
		case SATAGen is
			when SATA_GENERATION_1 =>			return TRUE;
			when SATA_GENERATION_2 =>			return TRUE;
			when others =>								return FALSE;
		end case;
	end;

begin
	assert (PORTS <= 2)	report "to many ports per transceiver"	severity FAILURE;

	-- cross clock domain bit synchronisation
	genSync1 : for i in 0 to PORTS - 1 generate
		signal Sync1_Lock_sy						: STD_LOGIC;
		signal Sync1_Lock_sy1						: STD_LOGIC														:= '0';
		signal Sync1_Lock_sy2						: STD_LOGIC														:= '0';

		signal Sync1_SATAGeneration_sy	: T_SATA_GENERATION;
		signal Sync1_SATAGeneration_sy1	: T_SATA_GENERATION										:= SATA_GENERATION_1;
		signal Sync1_SATAGeneration_sy2	: T_SATA_GENERATION										:= SATA_GENERATION_1;

	begin
		assert IsSupportedGeneration(SATA_Generation(I))	report "Member of T_SATA_GENERATION not supported"	severity FAILURE;

		-- synchronize Reconfig(I), Lock(I), SATA_Generation(I) from SATA_Clock to DRP_Clock
		Sync1_Lock_sy							<= Lock(I);
		Sync1_Lock_sy1						<= Sync1_Lock_sy							when rising_edge(DRP_Clock);
		Sync1_Lock_sy2						<= Sync1_Lock_sy1							when rising_edge(DRP_Clock);
		Sync1_Lock(I)							<= Sync1_Lock_sy2;

		Sync1_SATAGeneration_sy		<= SATA_Generation(I);
		Sync1_SATAGeneration_sy1	<= Sync1_SATAGeneration_sy		when rising_edge(DRP_Clock);
		Sync1_SATAGeneration_sy2	<= Sync1_SATAGeneration_sy1		when rising_edge(DRP_Clock);
		Sync1_SATAGeneration(I)		<= Sync1_SATAGeneration_sy2;

		SATA_Generation_i(I)			<= Sync1_SATAGeneration(I);

		Sync1 : entity PoC.Synchronizer
			generic map (
				BW										=> 1,
				GATED_INPUT_BY_BUSY		=> TRUE
			)
			port map (
				Clock1								=> SATA_Clock(I),
				Clock2								=> DRP_Clock,
				I(0)									=> Reconfig(I),
				O(0)									=> Reconfig_i(I),
				B											=> open
			);

		Lock_i(I)			<= Sync1_Lock(I) AND (NOT NoDevice(I));
	end generate;

	-- calculate shared control signals
	doReconfig				<= slv_or(Reconfig_i);
	doLock						<= slv_or(Lock_i);			-- only connected ports can request locks

	genSync2 : for i in 0 to PORTS - 1 generate
		signal Sync2_Locked_sy			: STD_LOGIC;
		signal Sync2_Locked_sy1			: STD_LOGIC														:= '0';
		signal Sync2_Locked_sy2			: STD_LOGIC														:= '0';

		signal Sync2_in							: STD_LOGIC_VECTOR(1 downto 0);
		signal Sync2_out						: STD_LOGIC_VECTOR(1 downto 0);

	begin
		-- synchronize ReconfigComplete, ConfigReloaded, Locked from DRP_Clock to SATA_Clock
		Sync2_Locked_sy			<= Locked_i;
		Sync2_Locked_sy1		<= Sync2_Locked_sy		when rising_edge(SATA_Clock(I));
		Sync2_Locked_sy2		<= Sync2_Locked_sy1		when rising_edge(SATA_Clock(I));
		Locked(I)						<= Sync2_Locked_sy2;

		Sync2_in						<= ConfigReloaded_i & ReconfigComplete_i;

		Sync2 : entity PoC.Synchronizer
			generic map (
				BW										=> 2,
				GATED_INPUT_BY_BUSY		=> TRUE
			)
			port map (
				Clock1								=> DRP_Clock,
				Clock2								=> SATA_Clock(I),
				I											=> Sync2_in,
				O											=> Sync2_out,
				B											=> open
			);

		ReconfigComplete(I)		<= Sync2_out(0);
		ConfigReloaded(I)			<= Sync2_out(1);
	end generate;

	-- rising_edge(MMCM_ReloadConfigDone)
	ReloadConfigDone		<= MMCM_ReloadConfigDone;
	ReloadConfigDone_d	<= ReloadConfigDone when rising_edge(DRP_Clock);
	ReloadConfigDone_re	<= NOT ReloadConfigDone_d AND ReloadConfigDone;

	process(DRP_Clock)
	begin
		if rising_edge(DRP_Clock) then
			if (DRP_Reset = '1') then
				State				<= ST_IDLE;
			else
				State				<= NextState;
			end if;
		end if;
	end process;


	process(State, doReconfig, doLock, XilDRP_ReconfigDone, ReloadConfigDone_re, SATA_Generation_i)
	begin
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

		case State is
			when ST_IDLE =>
				if (doLock = '1') then
					if (doReconfig = '1') then
						NextState						<= ST_LOCKED_RECONFIG;	-- do reconfig, but lock is set
					else
						NextState						<= ST_LOCKED;						-- lock is set
					end if;
				else																						-- no lock is requested
					if (doReconfig = '1') then
						NextState						<= ST_RECONFIG;					-- do reconfig
					end if;
				end if;

			when ST_LOCKED =>
				Locked_i								<= '1';									-- expose lock-state

				if (doReconfig = '1') then
					if (doLock = '1') then												-- do reconfig, but lock is set
						NextState						<= ST_LOCKED_RECONFIG;
					else
						NextState						<= ST_RECONFIG;					-- do reconfig only for port 0
					end if;
				else	-- doReconfig
					if (doLock = '0') then
						NextState						<= ST_IDLE;
					else
						NULL;
					end if;
				end if;

			when ST_LOCKED_RECONFIG =>
				Locked_i								<= '1';									-- expose lock-state

				if (doLock = '0') then													-- no lock is set, start reconfig
					NextState							<= ST_RECONFIG;					-- do reconfig only for port 0
				end if;

-- activate XilinxReconfigurator
-- ------------------------------------------------------------------
			when ST_RECONFIG =>
				XilDRP_Reconfig				<= '1';

				if (PORTS = 1) then
					XilDRP_ConfigSelect	<= ite((SATA_Generation_i = SATA_GENERATION_1), to_slv(0, 2), to_slv(1, 2));
				ELSif (PORTS = 2) then
					XilDRP_ConfigSelect	<= ite((SATA_Generation_i = SATA_GENERATION_1), to_slv(2, 2), to_slv(3, 2));
				else
					NULL;
				end if;

				NextState							<= ST_RECONFIG_WAIT;

			when ST_RECONFIG_WAIT =>
				if (XilDRP_ReconfigDone = '1') then
					ReconfigComplete_i	<= '1';

					NextState						<= ST_RELOAD;
				end if;

-- reload MMCM_DUAL configuration
-- ------------------------------------------------------------------
			when ST_RELOAD =>
				ReloadConfig_i				<= '1';

				NextState							<= ST_RELOAD_WAIT;					-- send full reset after reconfiguration

			when ST_RELOAD_WAIT =>
				if (ReloadConfigDone_re = '1') then
					ConfigReloaded_i		<= '1';

					NextState						<= ST_IDLE;
				end if;

		end case;
	end process;

	XilDRP : entity PoC.XilinxReconfigurator
		generic map (
			CHIPSCOPE_KEEP					=> CHIPSCOPE_KEEP,
			CLOCK_FREQ_MHZ					=> DRPCLOCK_FREQ_MHZ,
			CONFIG_COUNT						=> XilDRP_ConfigROM'length
		)
		port map (
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

end;
