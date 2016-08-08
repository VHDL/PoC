library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library UNISIM;
use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.sata.all;
use			PoC.satadbg.all;
use			PoC.sata_TransceiverTypes.all;
use			PoC.xil.all;


entity sata_Transceiver_Virtex5_GTP is
	generic (
		DEBUG											: boolean											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: boolean											:= FALSE;																		-- enables the assignment of signals to the debugport
		CLOCK_IN_FREQ							: FREQ												:= 150 MHz;																	-- 150 MHz
		PORTS											: positive										:= 2;																				-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 1	=> C_SATA_GENERATION_MAX)				-- intial SATA Generation
	);
	port (
		Reset											: in	std_logic_vector(PORTS - 1 downto 0);
		ResetDone									: out	std_logic_vector(PORTS - 1 downto 0);
		ClockNetwork_Reset				: in	std_logic_vector(PORTS - 1 downto 0);
		ClockNetwork_ResetDone		: out	std_logic_vector(PORTS - 1 downto 0);

		PowerDown									: in	std_logic_vector(PORTS - 1 downto 0);
		Command										: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
		Status										: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
		RX_Error									: out	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 downto 0);
		TX_Error									: out	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 downto 0);
		-- debug ports
		DebugPortIn								: in	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 downto 0);
		DebugPortOut							: out	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 downto 0);

		SATA_Clock								: out	std_logic_vector(PORTS - 1 downto 0);

		RP_Reconfig								: in	std_logic_vector(PORTS - 1 downto 0);
		RP_SATAGeneration					: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
		RP_ReconfigComplete				: out	std_logic_vector(PORTS - 1 downto 0);
		RP_ConfigReloaded					: out	std_logic_vector(PORTS - 1 downto 0);
		RP_Lock										:	in	std_logic_vector(PORTS - 1 downto 0);
		RP_Locked									: out	std_logic_vector(PORTS - 1 downto 0);

		OOB_TX_Command						: in	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
		OOB_TX_Complete						: out	std_logic_vector(PORTS - 1 downto 0);
		OOB_RX_Received						: out	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
		OOB_HandshakeComplete			: in	std_logic_vector(PORTS - 1 downto 0);

		TX_Data										: in	T_SLVV_32(PORTS - 1 downto 0);
		TX_CharIsK								: in	T_SLVV_4(PORTS - 1 downto 0);

		RX_Data										: out	T_SLVV_32(PORTS - 1 downto 0);
		RX_CharIsK								: out	T_SLVV_4(PORTS - 1 downto 0);
		RX_IsAligned							: out std_logic_vector(PORTS - 1 downto 0);

		-- vendor specific signals
		VSS_Common_In							: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In						: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 downto 0);
		VSS_Private_Out						: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
	);
end;


architecture rtl of sata_Transceiver_Virtex5_GTP is
	attribute KEEP 														: boolean;
	attribute TNM 														: string;

-- ==================================================================
-- SATATransceiver configuration
-- ==================================================================
	constant NO_DEVICE_TIMEOUT								: T_TIME					:= ite(SIMULATION, 20.0e-6, 50.0e-3);	-- simulation: 20 us, synthesis: 50 ms
	constant NEW_DEVICE_TIMEOUT								: T_TIME					:= ite(SIMULATION, 50.0e-6, 1.0);

	constant C_DEVICE_INFO										: T_DEVICE_INFO		:= DEVICE_INFO;

-- ==================================================================
-- calculate generic values for GTP transceiver
-- ==================================================================
	function SATAGeneration2ClockDivider(SGEN : T_SATA_GENERATION_VECTOR) return T_INTVEC is
		variable ClkDiv : T_INTVEC(SGEN'range)	:= (others => 0);
	begin
		for i in 0 to SGEN'length - 1 loop											-- GTP_DUAL PLL output = 1,5 GHz
			case SGEN(I) is
				when SATA_GENERATION_1 =>			ClkDiv(I) := 2;				-- Generation 1: 1,5 GHz line clock => 750 MHz TX/RX clock (DDR sampler)	=> devider = 2
				when SATA_GENERATION_2 =>			ClkDiv(I) := 1;				-- Generation 2: 3,0 GHz line clock => 1,5 GHz TX/RX clock (DDR sampler)	=> devider = 1
				when others =>								ClkDiv(I) := 1;
			end case;
		end loop;

		return ClkDiv;
	end;

	constant CLOCK_DIVIDERS										: T_INTVEC(INITIAL_SATA_GENERATIONS'range)		:= SATAGeneration2ClockDivider(INITIAL_SATA_GENERATIONS);

	signal ClockIn_150MHz											: std_logic;
	signal ResetDone_i												: std_logic_vector(PORTS - 1 downto 0);

	signal GTP_Reset													: std_logic;
	signal GTP_ResetDone											: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_ResetDone_i										: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_PLL_Reset											: std_logic;
	signal GTP_PLL_ResetDone									:	std_logic_vector(PORTS - 1 downto 0);
	signal GTP_PLL_ResetDone_i								:	std_logic;

	signal GTP_RefClockIn											: std_logic;
	signal GTP_RefClockOut										: std_logic;
	signal GTP_RefClockOut_i									: std_logic;
	signal GTP_TX_RefClockOut									: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_RX_RefClockOut									: std_logic_vector(PORTS - 1 downto 0);
	signal Control_Clock											: std_logic;
	signal GTP_DRP_Clock											: std_logic;
	signal GTP_Clock_1X												: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_Clock_4X												: std_logic_vector(PORTS - 1 downto 0);
	signal SATA_Clock_i												: std_logic_vector(PORTS - 1 downto 0);

	signal ClkNet_Reset												: std_logic;
	signal ClkNet_Reset_i											: std_logic;
	signal ClkNet_Reset_x											: std_logic;
	signal ClkNet_ResetDone										: std_logic_vector(PORTS - 1 downto 0);
	signal ClkNet_ResetDone_i									: std_logic;
	signal ClockNetwork_ResetDone_i						: std_logic_vector(PORTS - 1 downto 0);

	signal GTP_PortReset											: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_RX_Reset												: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_RX_CDR_Reset										: std_logic_vector(PORTS - 1 downto 0);		-- Clock Data Recovery
	signal GTP_RX_BufferReset									: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_TX_Reset												: std_logic_vector(PORTS - 1 downto 0);

	signal GTP_PLL_PowerDown									: std_logic;
	signal GTP_TX_PowerDown										: T_SLVV_2(PORTS - 1 downto 0);
	signal GTP_RX_PowerDown										: T_SLVV_2(PORTS - 1 downto 0);

	signal GTPConfig_Reset										: std_logic;
	signal GTPConfig_Reset_i									: std_logic;
	signal GTP_ReloadConfig										: std_logic;
	signal GTP_ReloadConfigDone								: std_logic;
	signal GTP_ReloadConfigDone_i							: std_logic;

	signal GTP_DRP_en													: std_logic;
	signal GTP_DRP_Address										: T_XIL_DRP_ADDRESS;
	signal GTP_DRP_we													: std_logic;
	signal GTP_DRP_DataIn											: T_XIL_DRP_DATA;
	signal GTP_DRP_DataOut										: T_XIL_DRP_DATA;
	signal GTP_DRP_rdy												: std_logic;

	signal GTP_TX_ElectricalIDLE							: std_logic_vector(PORTS - 1 downto 0)													:= (others => '0');
	signal GTP_TX_ComStart										: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_TX_ComType											: std_logic_vector(PORTS - 1 downto 0)													:= (others => '0');
	signal GTP_TX_ComComplete									: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_TX_InvalidK										: T_SLVV_2(PORTS - 1 downto 0);
	signal GTP_TX_BufferStatus								: T_SLVV_2(PORTS - 1 downto 0);

	signal GTP_RX_ElectricalIDLE_Reset				: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_RX_EnableElectricalIDLEReset		: std_logic;
	signal GTP_RX_ElectricalIDLE							: std_logic_vector(PORTS - 1 downto 0);

	signal GTP_RX_Status											: T_SLVV_3(PORTS - 1 downto 0);
	signal GTP_RX_DisparityError							: T_SLVV_2(PORTS - 1 downto 0);
	signal GTP_RX_Illegal8B10BCode						: T_SLVV_2(PORTS - 1 downto 0);
	signal GTP_RX_LossOfSync									: T_SLVV_2(PORTS - 1 downto 0);																	-- unused
	signal GTP_RX_ClockCorrectionStatus				: T_SLVV_3(PORTS - 1 downto 0);
	signal GTP_RX_BufferStatus								: T_SLVV_3(PORTS - 1 downto 0);

	signal GTP_RX_Data												: T_SLVV_16(PORTS - 1 downto 0);
	signal GTP_RX_Data_d											: T_SLVV_8(PORTS - 1 downto 0)																	:= (others => (others => '0'));
	signal GTP_RX_CommaDetected								: std_logic_vector(PORTS - 1 downto 0);													-- unused
	signal GTP_RX_CharIsComma									: T_SLVV_2(PORTS - 1 downto 0);																	-- unused
	signal GTP_RX_CharIsK											: T_SLVV_2(PORTS - 1 downto 0);
	signal GTP_RX_CharIsK_d										: T_SLVV_2(PORTS - 1 downto 0)																	:= (others => (others => '0'));
	signal GTP_RX_ByteIsAligned								: std_logic_vector(PORTS - 1 downto 0);
	signal GTP_RX_ByteRealign									: std_logic_vector(PORTS - 1 downto 0);													-- unused
	signal GTP_RX_Valid												: std_logic_vector(PORTS - 1 downto 0);													-- unused

	signal GTP_TX_Data												: T_SLVV_16(PORTS - 1 downto 0);
	signal GTP_TX_CharIsK											: T_SLVV_2(PORTS - 1 downto 0);

	signal BWC_RX_Align												: std_logic_vector(PORTS - 1 downto 0);

	signal OOB_TX_Command_d										: T_SATA_OOB_VECTOR(PORTS - 1 downto 0)													:= (others => SATA_OOB_NONE);
	signal OOB_TX_Complete_i										: std_logic_vector(PORTS - 1 downto 0);
	signal TX_InvalidK												: std_logic_vector(PORTS - 1 downto 0);
	signal TX_BufferStatus										: std_logic_vector(PORTS - 1 downto 0);

	signal RX_ElectricalIDLE									: std_logic_vector(PORTS - 1 downto 0);
	signal RX_DisparityError									: std_logic_vector(PORTS - 1 downto 0);
	signal RX_Illegal8B10BCode								: std_logic_vector(PORTS - 1 downto 0);
	signal RX_BufferStatus										: std_logic_vector(PORTS - 1 downto 0);
	signal DD_NoDevice												: std_logic_vector(PORTS - 1 downto 0);

	signal RX_Error_i													: T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 downto 0);
	signal TX_Error_i													: T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 downto 0);

	signal OOB_RX_Received_i									: T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
	signal OOB_RX_Received_d									: T_SATA_OOB_VECTOR(PORTS - 1 downto 0)													:= (others => SATA_OOB_NONE);

	attribute KEEP of OOB_TX_Complete									: signal is DEBUG;
	attribute KEEP of BWC_RX_Align										: signal is DEBUG;
	attribute KEEP of GTP_RX_ClockCorrectionStatus		: signal is DEBUG;
	attribute KEEP of GTP_RX_BufferStatus							: signal is DEBUG;

	-- keep internal clock nets, so timing constrains from UCF can find them
	attribute KEEP of GTP_RefClockOut 								: signal is DEBUG;
	attribute KEEP of GTP_Clock_1X										: signal is DEBUG;
--	attribute KEEP OF GTP_Clock_4X										: signal IS DEBUG;
	attribute KEEP of SATA_Clock_i										: signal is TRUE;
	attribute TNM of SATA_Clock_i											: signal is "TGRP_SATA_Clock0";
	attribute KEEP of GTP_TX_RefClockOut							: signal is DEBUG;
	attribute KEEP of GTP_RX_RefClockOut							: signal is DEBUG;

begin
	genReport : for i in 0 to PORTS - 1 generate
		assert FALSE report "Port:    " & integer'image(I)																								severity NOTE;
		assert FALSE report "  Init. SATA Generation:  Gen" & integer'image(INITIAL_SATA_GENERATIONS(I))	severity NOTE;
		assert FALSE report "  ClockDivider:           " & integer'image(I)																severity NOTE;
	end generate;

-- ==================================================================
-- Assert statements
-- ==================================================================
	assert (C_DEVICE_INFO.VENDOR = VENDOR_XILINX)						report "Vendor not yet supported."				severity FAILURE;
	assert (C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_VIRTEX)	report "Device family not yet supported."	severity FAILURE;
	assert (C_DEVICE_INFO.DEVICE = DEVICE_VIRTEX5)					report "Device not yet supported."				severity FAILURE;
	assert (PORTS <= 2)																			report "To many ports per transceiver."		severity FAILURE;

	genAssert : for i in 0 to PORTS - 1 generate
		assert (CLOCK_DIVIDERS(I) > 0)												report "illegal clock devider - unsupported initial SATA generation?" severity FAILURE;
		assert ((RP_SATAGeneration(I) = SATA_GENERATION_1) or
						(RP_SATAGeneration(I) = SATA_GENERATION_2))			report "unsupported SATA generation"			severity FAILURE;
	end generate;

-- =============================================================================
-- mapping of vendor specific ports
-- =============================================================================
	ClockIn_150MHz										<= VSS_Common_In.RefClockIn_150_MHz;

-- ==================================================================
-- ResetControl
-- ==================================================================
	ClkNet_Reset_i										<= slv_or(ClockNetwork_Reset);

	blkSync1 : block
		signal ClkNet_Reset_shift				: std_logic_vector(15 downto 0)				:= (others => '0');
	begin
		process(Control_Clock)
		begin
			if rising_edge(Control_Clock) then
				ClkNet_Reset_shift		<= ClkNet_Reset_shift(ClkNet_Reset_shift'high - 1 downto 0) & ClkNet_Reset_i;
			end if;
		end process;

		ClkNet_Reset		<= ClkNet_Reset_shift(2);
		ClkNet_Reset_x	<= ClkNet_Reset_shift(ClkNet_Reset_shift'high);
	end block;

	GTP_PLL_Reset											<= ClkNet_Reset;
	GTPConfig_Reset										<= ClkNet_Reset;
	-- PLL reset must be mapped to global GTP reset
	-- reload configuration must be mapped to global GTP reset
	GTP_Reset													<= GTP_PLL_Reset or GTP_ReloadConfig;

	genSync0 : for i in 0 to PORTS - 1 generate
		signal GTP_Reset_meta						: std_logic				:= '0';
		signal GTP_Reset_d							: std_logic				:= '0';

		-- ------------------------------------------
		signal ClkNet_ResetDone_meta		: std_logic				:= '0';
		signal ClkNet_ResetDone_d				: std_logic				:= '0';

		signal GTP_PLL_ResetDone_meta		: std_logic				:= '0';
		signal GTP_PLL_ResetDone_d			: std_logic				:= '0';

		signal GTP_ResetDone_meta				: std_logic				:= '0';
		signal GTP_ResetDone_d					: std_logic				:= '0';

	begin
		GTP_Reset_meta									<= GTP_Reset				when rising_edge(SATA_Clock_i(I));
		GTP_Reset_d											<= GTP_Reset_meta		when rising_edge(SATA_Clock_i(I));

		GTP_PortReset(I)								<= to_sl(Command(I) = SATA_TRANSCEIVER_CMD_RESET);
		GTP_TX_PowerDown(I)							<= PowerDown(I) & PowerDown(I);														-- PowerDown => PowerDownState = P2
		GTP_RX_PowerDown(I)							<= PowerDown(I) & PowerDown(I);														-- PowerDown => PowerDownState = P2

		GTP_TX_Reset(I)									<= GTP_Reset_d	or GTP_PortReset(I);
		GTP_RX_Reset(I)									<= GTP_Reset_d	or GTP_PortReset(I) or	OOB_HandshakeComplete(I);
		GTP_RX_ElectricalIDLE_Reset(I)	<= GTP_RX_ElectricalIDLE(I)				and GTP_ResetDone(I);				-- generate reset for CDR-unit (Clock-Data-Recovery) after OOB signaling

		-- ------------------------------------------
--		ClkNet_ResetDone_meta						<= ClkNet_ResetDone_i			when rising_edge(SATA_Clock_i(I));
--		ClkNet_ResetDone_d							<= ClkNet_ResetDone_meta	when rising_edge(SATA_Clock_i(I));
		ClkNet_ResetDone(I)							<= ClkNet_ResetDone_i;

		GTP_PLL_ResetDone_meta					<= GTP_PLL_ResetDone_i		when rising_edge(SATA_Clock_i(I));
		GTP_PLL_ResetDone_d							<= GTP_PLL_ResetDone_meta	when rising_edge(SATA_Clock_i(I));
		GTP_PLL_ResetDone(I)						<= GTP_PLL_ResetDone_d;

		GTP_ResetDone_meta							<= GTP_ResetDone_i(I)			when rising_edge(SATA_Clock_i(I));
		GTP_ResetDone_d									<= GTP_ResetDone_meta			when rising_edge(SATA_Clock_i(I));
		GTP_ResetDone(I)								<= GTP_ResetDone_d;
	end generate;

	ClockNetwork_ResetDone						<= ClkNet_ResetDone;

	ClockNetwork_ResetDone_i					<= GTP_PLL_ResetDone				and ClkNet_ResetDone;
	ResetDone													<= ClockNetwork_ResetDone_i and GTP_ResetDone;

	-- reload completion is recongnized by asserting GTP_ResetDone
	GTP_ReloadConfigDone_i						<= slv_and(GTP_ResetDone_i);

	blkSync2 : block
		signal GTP_ReloadConfigDone_meta	: std_logic				:= '0';
		signal GTP_ReloadConfigDone_d			: std_logic				:= '0';
	begin
		GTP_ReloadConfigDone_meta					<= GTP_ReloadConfigDone_i			when rising_edge(Control_Clock);
		GTP_ReloadConfigDone_d						<= GTP_ReloadConfigDone_meta	when rising_edge(Control_Clock);
		GTP_ReloadConfigDone							<= GTP_ReloadConfigDone_d;
	end block;


  GTP_RX_CDR_Reset                  <= (others => '0');
  GTP_RX_BufferReset                <= (others => '0');
	GTP_PLL_PowerDown									<= '0';

	GTP_RX_EnableElectricalIDLEReset	<= slv_or(GTP_RX_ElectricalIDLE_Reset);

-- ==================================================================
-- ClockNetwork (37.5, 75, 150, 300 MHz)
-- ==================================================================
	GTP_RefClockIn		<= ClockIn_150MHz;

	BUFG_GTP_RefClockOut : BUFG
		port map (
			I		=> GTP_RefClockOut_i,
			O		=> GTP_RefClockOut
		);

	Control_Clock										<= GTP_RefClockOut;							-- use stable clock after GTP_DUAL / before DCM for reset control and so on
	GTP_DRP_Clock										<= GTP_RefClockOut;							-- use stable clock after GTP_DUAL / before DCM for Dynamic-Reconfiguration-Port

	SATA_Clock_i										<= GTP_Clock_4X;							-- SATAClock is a 4 Byte (Word) clock
	SATA_Clock											<= SATA_Clock_i;

	ClkNet : entity PoC.sata_Transceiver_Virtex5_GTP_ClockNetwork
		generic map (
			DEBUG												=> DEBUG,
			CLOCK_IN_FREQ								=> CLOCK_IN_FREQ,
			PORTS												=> PORTS,
			INITIAL_SATA_GENERATIONS		=> INITIAL_SATA_GENERATIONS
		)
		port map (
			ClockIn_150MHz							=> GTP_RefClockOut,							-- use stable clock after GTP_DUAL - not from CDR-Unit !! => enable elastic buffers

			ClockNetwork_Reset					=> ClkNet_Reset_x,
			ClockNetwork_ResetDone			=> ClkNet_ResetDone_i,

			SATAGeneration							=> RP_SATAGeneration,

			GTP_Clock_1X								=> GTP_Clock_1X,
			GTP_Clock_4X								=> GTP_Clock_4X
		);


-- ==================================================================
-- async signal handling
-- ==================================================================
	genSync : for i in 0 to (PORTS - 1) generate
		sync1 : entity PoC.sync_Flag
			port map (
				Clock				=> GTP_Clock_4X(I),
				Input(0)		=> GTP_RX_ElectricalIDLE(I),
				Output(0)		=> RX_ElectricalIDLE(I)
			);
	end generate;

-- ==================================================================
-- transceiver layer FSM
-- ==================================================================
--	FSM : entity L_SATAController.SATATransceiverFSM
--		generic map (
--			DEBUG						=> DEBUG,
--			PORTS											=> PORTS
--		)
--		port map (
--			SATAClock									=> GTP_Clock_4X,
--			ControlClock							=> Control_Clock,
--
--			Command										=> Command,							-- @SATAClock:
--			Status										=> Status,							-- @SATAClock:
--			Error											=> Error,								-- @SATAClock:
--
--			PortReset									=> GTP_PortReset,				-- @ControlClock:
--			ResetDone									=> GTP_ResetDone,				-- @ControlClock:
--
--			NoDevice									=> DD_NoDevice,					-- @ControlClock:
--			NewDevice									=> DD_NewDevice,				-- @ControlClock:
--
--			TX_InvalidK								=> TX_InvalidK,					--
--			TX_BufferStatus						=> TX_BufferStatus,			--
--
--			RX_DisparityError					=> RX_DisparityError,		--
--			RX_Illegal8B10BCode				=> RX_Illegal8B10BCode,	--
--			RX_BufferStatus						=> RX_BufferStatus,			--
--
--			Reconfig									=> Reconfig,						-- @ControlClock:
--			ReconfigDone							=> ReconfigDone,				-- @ControlClock:
--			Reload										=> Reload,							-- @ControlClock:
--			ReloadDone								=> ReloadDone						-- @ControlClock:
--		);

-- ==================================================================
-- data path buffers
-- ==================================================================
	genDataPath : for i in 0 to PORTS - 1 generate
	begin
		-- TX path
		BWC_TX_Data : entity PoC.misc_BitwidthConverter
			generic map (
				REGISTERED					=> TRUE,
				BITS1								=> 32,
				BITS2								=> 8
			)
			port map (
				Clock1							=> GTP_Clock_4X(I),
				Clock2							=> GTP_Clock_1X(I),
				Align								=> '0',
				I										=> TX_Data(I),
				O										=> GTP_TX_Data(I)(7 downto 0)
			);

		BWC_TX_CharIsK : entity PoC.misc_BitwidthConverter
			generic map (
				REGISTERED					=> TRUE,
				BITS1								=> 4,
				BITS2								=> 1
			)
			port map (
				Clock1							=> GTP_Clock_4X(I),
				Clock2							=> GTP_Clock_1X(I),
				Align								=> '0',
				I										=> TX_CharIsK(I),
				O										=> GTP_TX_CharIsK(I)(0 downto 0)
			);

		-- RX path
		-- ==============================================================
		-- insert register stage, so timing constrains can be solved
		GTP_RX_CharIsK_d(I)	<= GTP_RX_CharIsK(I)					when rising_edge(GTP_Clock_1X(I));
		GTP_RX_Data_d(I)		<= GTP_RX_Data(I)(7 downto 0) when rising_edge(GTP_Clock_1X(I));

		-- use K-characters for word alignment
		BWC_RX_Align(I) 		<= GTP_RX_CharIsK_d(I)(0);

		BWC_RX_Data : entity PoC.misc_BitwidthConverter
			generic map (
				REGISTERED					=> TRUE,
				BITS1								=> 8,
				BITS2								=> 32
			)
			port map (
				Clock1							=> GTP_Clock_1X(I),
				Clock2							=> GTP_Clock_4X(I),
				Align								=> BWC_RX_Align(I),
				I										=> GTP_RX_Data_d(I),
				O										=> RX_Data(I)
			);

		BWC_RX_CharIsK : entity PoC.misc_BitwidthConverter
			generic map (
				REGISTERED					=> TRUE,
				BITS1								=> 1,
				BITS2								=> 4
			)
			port map (
				Clock1							=> GTP_Clock_1X(I),
				Clock2							=> GTP_Clock_4X(I),
				Align								=> BWC_RX_Align(I),
				I										=> GTP_RX_CharIsK_d(I)(0 downto 0),
				O										=> RX_CharIsK(I)
			);

		RX_IsAligned(I)					<= GTP_RX_ByteIsAligned(I);
	end generate;

-- ==================================================================
-- OOB signaling
-- ==================================================================
	genOOBControl : for i in 0 to PORTS - 1 generate
		signal ForceElectricalIDLE		: std_logic;
		signal ForceElectricalIDLE_d	: std_logic													:= '0';
		signal ForceElectricalIDLE_re	: std_logic;
		signal ForceElectricalIDLE_fe	: std_logic;
	begin
		OOB_TX_Command_d(I)	<= OOB_TX_Command(I) when rising_edge(GTP_Clock_4X(I));

		-- TX OOB signals (generate GTP specific OOB signals)
		process(OOB_TX_Command_d(I))
		begin
			GTP_TX_ComStart(I)			<= '0';
			ForceElectricalIDLE			<= '0';

			if (OOB_TX_Command_d(I) = SATA_OOB_READY) then
				ForceElectricalIDLE		<= '1';
			elsif (OOB_TX_Command_d(I) = SATA_OOB_COMRESET) then
				GTP_TX_ComStart(I) 		<= '1';
			elsif (OOB_TX_Command_d(I) = SATA_OOB_COMWAKE) then
				GTP_TX_ComStart(I) 		<= '1';
			end if;
		end process;

		ForceElectricalIDLE_d		<= ForceElectricalIDLE 		when rising_edge(GTP_Clock_4X(I));
		ForceElectricalIDLE_re	<= ForceElectricalIDLE		and not ForceElectricalIDLE_d;
		ForceElectricalIDLE_fe	<= ForceElectricalIDLE_d	and not ForceElectricalIDLE;

		-- SR-FF for ElectricalIDLE:
		--		.set	= ComStart
		--		.rst	= OOBComplete || Reset
		process(GTP_Clock_4X(I))
		begin
			if rising_edge(GTP_Clock_4X(I)) then
				if (GTP_PortReset(I) = '1') then
					GTP_TX_ElectricalIDLE(I)	<= '0';
				else
					if ((GTP_TX_ComStart(I) = '1') or (ForceElectricalIDLE_re = '1')) then
						GTP_TX_ElectricalIDLE(I)	<= '1';
					elsif ((OOB_TX_Complete_i(I) = '1') or (ForceElectricalIDLE_fe = '1')) then
						GTP_TX_ElectricalIDLE(I)	<= '0';
					end if;
				end if;
			end if;
		end process;

		-- SR-FF for ComType:
		--		.en		= ComStart
		--		.set	= OOBCommand = COMRESET | COMINIT
		--		.rst	= OOBCommand = COMWAKE
		process(GTP_Clock_4X(I))
		begin
			if rising_edge(GTP_Clock_4X(I)) then
				if (GTP_TX_ComStart(I) = '1') then
					case OOB_TX_Command_d(I) is
						when SATA_OOB_COMRESET =>		GTP_TX_ComType(I)				<= '0';
						when SATA_OOB_COMWAKE =>		GTP_TX_ComType(I)				<= '1';
						when others =>							GTP_TX_ComType(I)				<= '0';
					end case;
				end if;
			end if;
		end process;

		-- OOB sequence is complete
		GTP_TX_ComComplete(I) <= to_sl(GTP_RX_Status(I)(0) = '1');

		sync2 : entity PoC.sync_Strobe
			port map (
				Clock1		=> GTP_Clock_1X(I),						-- input clock domain
				Clock2		=> GTP_Clock_4X(I),						-- output clock domain
				Input(0)	=> GTP_TX_ComComplete(I),			-- input bits
				Output(0)	=> OOB_TX_Complete_i(I)				-- output bits
			);

		OOB_TX_Complete		<= OOB_TX_Complete_i;

		-- RX OOB signals (generate generic RX OOB status signals)
		process(GTP_RX_Status(I)(2 downto 1), RX_ElectricalIDLE(I))
		begin
			OOB_RX_Received_i(I) 				<= SATA_OOB_NONE;

			if (RX_ElectricalIDLE(I) = '1') then
				OOB_RX_Received_i(I)				<= SATA_OOB_READY;

				case GTP_RX_Status(I)(2 downto 1) is
					when "10" =>					OOB_RX_Received_i(I)		<= SATA_OOB_COMRESET;
					when "01" =>					OOB_RX_Received_i(I)		<= SATA_OOB_COMWAKE;
					when others =>				null;
				end case;
			end if;
		end process;

		-- convert to Word-Clock
		OOB_RX_Received_d(I) <= OOB_RX_Received_i(I) when rising_edge(GTP_Clock_4X(I));
		OOB_RX_Received(I)		<= OOB_RX_Received_d(I);
	end generate;

-- ==================================================================
-- error handling
-- ==================================================================
	genError : for i in 0 to PORTS - 1 generate
		sync3 : entity PoC.sync_Strobe
			generic map (
				BITS				=> 5															-- number of bit to be synchronized
			)
			port map (
				Clock1			=> GTP_Clock_1X(I),								-- input clock domain
				Clock2			=> GTP_Clock_4X(I),								-- output clock domain
				Input(0)		=> GTP_TX_InvalidK(I)(0),					-- input bits
				Input(1)		=> GTP_TX_BufferStatus(I)(1),			--
				Input(2)		=> GTP_RX_DisparityError(I)(0),		--
				Input(3)		=> GTP_RX_Illegal8B10BCode(I)(0),	--
				Input(4)		=> GTP_RX_BufferStatus(I)(2),			--
				Output(0)		=> TX_InvalidK(I),								-- output bits
				Output(1)		=> TX_BufferStatus(I),						--
				Output(2)		=> RX_DisparityError(I),					--
				Output(3)		=> RX_Illegal8B10BCode(I),				--
				Output(4)		=> RX_BufferStatus(I)							--
			);

		-- RX errors
		process(GTP_RX_ByteIsAligned(I), RX_DisparityError, RX_Illegal8B10BCode, RX_BufferStatus)
		begin
			RX_Error_i(I)		<= SATA_TRANSCEIVER_RX_ERROR_NONE;

			if (GTP_RX_ByteIsAligned(I) = '0') then
				RX_Error_i(I)	<= SATA_TRANSCEIVER_RX_ERROR_ALIGNEMENT;
			elsif (RX_DisparityError(I) = '1') then
				RX_Error_i(I)	<= SATA_TRANSCEIVER_RX_ERROR_DISPARITY;
			elsif (RX_Illegal8B10BCode(I) = '1') then
				RX_Error_i(I)	<= SATA_TRANSCEIVER_RX_ERROR_DECODER;
			elsif (RX_BufferStatus(I) = '1') then
				RX_Error_i(I)	<= SATA_TRANSCEIVER_RX_ERROR_BUFFER;
			end if;
		end process;

		-- TX errors
		process(TX_InvalidK, TX_BufferStatus)
		begin
			TX_Error_i(I)		<= SATA_TRANSCEIVER_TX_ERROR_NONE;

			if (TX_InvalidK(I) = '1') then
				TX_Error_i(I)	<= SATA_TRANSCEIVER_TX_ERROR_ENCODER;
			elsif (TX_BufferStatus(I) = '1') then
				TX_Error_i(I)	<= SATA_TRANSCEIVER_TX_ERROR_BUFFER;
			end if;
		end process;
	end generate;

	TX_Error			<= TX_Error_i;
	RX_Error			<= RX_Error_i;

-- ==================================================================
-- Transceiver status / DeviceDetection
-- ==================================================================
	genDeviceDetector : for i in 0 to PORTS - 1 generate
		signal DD_NoDevice_i					: std_logic;
		signal DD_NewDevice						: std_logic;
		signal DD_NewDevice_i					: std_logic;
		signal RX_ComReset						: std_logic;
		signal RX_ComReset_CC					: std_logic;

	begin
		RX_ComReset <= to_sl(GTP_RX_Status(I)(2 downto 1) = "10");		-- received COMRESET

		syncCC : entity PoC.sync_Flag
			port map (
				Clock				=> Control_Clock,
				Input(0)		=> RX_ComReset,
				Output(0)		=> RX_ComReset_CC
			);

		-- device detection
		DD : entity PoC.sata_DeviceDetector
			generic map (
				DEBUG								=> DEBUG,
				CLOCK_FREQ					=> CLOCK_IN_FREQ,					-- 150 MHz
				NO_DEVICE_TIMEOUT		=> NO_DEVICE_TIMEOUT,
				NEW_DEVICE_TIMEOUT	=> NEW_DEVICE_TIMEOUT
			)
			port map (
				Clock								=> Control_Clock,
				ElectricalIDLE			=> GTP_RX_ElectricalIDLE(I),	-- async
				RxComReset					=> RX_ComReset_CC,
				NoDevice						=> DD_NoDevice(I),						-- @DRP_Clock
				NewDevice						=> DD_NewDevice								-- @DRP_Clock
			);

		sync4 : entity PoC.sync_Flag
			port map (
				Clock				=> GTP_Clock_4X(I),
				Input(0)		=> DD_NoDevice(I),
				Output(0)		=> DD_NoDevice_i
			);

		sync5 : entity PoC.sync_Strobe
			port map (
				Clock1			=> Control_Clock,								-- input clock domain
				Clock2			=> GTP_Clock_4X(I),							-- output clock domain
				Input(0)		=> DD_NewDevice,								-- input bits
				Output(0)		=> DD_NewDevice_i								-- output bits
			);

		process(GTP_ResetDone_i, DD_NoDevice_i, DD_NewDevice_i, TX_Error_i, RX_Error_i, Command)
		begin
			Status(I) 							<= SATA_TRANSCEIVER_STATUS_READY;

			if (GTP_ResetDone_i(I) = '0') then
				Status(I)							<= SATA_TRANSCEIVER_STATUS_RESETING;
			elsif (DD_NewDevice_i = '1') then
				Status(I)							<= SATA_TRANSCEIVER_STATUS_NEW_DEVICE;
			elsif (DD_NoDevice_i = '1') then
				Status(I)							<= SATA_TRANSCEIVER_STATUS_NO_DEVICE;
			elsif ((TX_Error_i(I) /= SATA_TRANSCEIVER_TX_ERROR_NONE) or (RX_Error_i(I) /= SATA_TRANSCEIVER_RX_ERROR_NONE)) then
				Status(I)							<= SATA_TRANSCEIVER_STATUS_ERROR;

-- TODO: add TRANS_STATUS_***
--	-	TRANS_STATUS_CONFIGURATION,
			end if;
		end process;
	end generate;


-- ==================================================================
-- DRP - dynamic reconfiguration port
-- ==================================================================
	GTPConfig : entity PoC.sata_Transceiver_Virtex5_GTP_Configurator
		generic map (
			DEBUG											=> DEBUG,
			DRPCLOCK_FREQ							=> CLOCK_IN_FREQ,
			PORTS											=> PORTS,
			INITIAL_SATA_GENERATIONS	=> INITIAL_SATA_GENERATIONS
		)
		port map (
			DRP_Clock									=> GTP_DRP_Clock,
			DRP_Reset									=> GTPConfig_Reset,								-- @DRP_Clock
			SATA_Clock								=> GTP_Clock_4X,

			Reconfig									=> RP_Reconfig,										-- @SATA_Clock
			SATAGeneration						=> RP_SATAGeneration,							-- @SATA_Clock
			ReconfigComplete					=> RP_ReconfigComplete,						-- @SATA_Clock
			ConfigReloaded						=> RP_ConfigReloaded,							-- @SATA_Clock
			Lock											=> RP_Lock,												-- @SATA_Clock
			Locked										=> RP_Locked,											-- @SATA_Clock

			NoDevice									=> DD_NoDevice,										-- @DRP_Clock

			GTP_DRP_en								=> GTP_DRP_en,										-- @DRP_Clock
			GTP_DRP_Address						=> GTP_DRP_Address,								-- @DRP_Clock
			GTP_DRP_we								=> GTP_DRP_we,										-- @DRP_Clock
			GTP_DRP_DataIn						=> GTP_DRP_DataOut,								-- @DRP_Clock
			GTP_DRP_DataOut						=> GTP_DRP_DataIn,								-- @DRP_Clock
			GTP_DRP_Ack								=> GTP_DRP_rdy,										-- @DRP_Clock

			GTP_ReloadConfig					=> GTP_ReloadConfig,							-- @DRP_Clock
			GTP_ReloadConfigDone			=> GTP_ReloadConfigDone						-- @DRP_Clock
		);


-- ==================================================================
-- GTP_DUAL - 1 used port
-- ==================================================================
	SinglePort : if (PORTS = 1) generate
	 signal GTP_RX_DisableElectricalIDLEReset : std_logic;

	begin
		GTP_RX_DisableElectricalIDLEReset		<= not GTP_RX_EnableElectricalIDLEReset;

		GTP : GTP_DUAL
			generic map (
				-- ===================== Simulation-Only Attributes ====================
	--			SIM_RECEIVER_DETECT_PASS0	 		=>			 TRUE,
	--			SIM_RECEIVER_DETECT_PASS1	 		=>			 TRUE,
				SIM_MODE											=>			 "FAST",
				SIM_GTPRESET_SPEEDUP					=>			 0,
	--			SIM_PLL_PERDIV2								=>			 TILE_SIM_PLL_PERDIV2,

				-- ========================== Shared Attributes ========================
				-------------------------- Tile and PLL Attributes ---------------------
				CLK25_DIVIDER									=>			 6,
				CLKINDC_B											=>			 TRUE,
				OOB_CLK_DIVIDER								=>			 6,							-- divide 150 MHz to 25 MHz => DIVIDER = 6
				OVERSAMPLE_MODE								=>			 FALSE,
				PLL_DIVSEL_FB									=>			 2,							-- PLL clock feedback devider
				PLL_DIVSEL_REF								=>			 1,							-- PLL input clock devider
				PLL_TXDIVSEL_COMM_OUT					=>			 1,							-- don't devide common TX clock, use private TXDIVSEL_OUT clock deviders
				TX_SYNC_FILTERB								=>			 1,

				-- ================== Transmit Interface Attributes ====================
				------------------- TX Buffering and Phase Alignment -------------------
				TX_BUFFER_USE_0								=>			 TRUE,
				TX_XCLK_SEL_0									=>			 "TXOUT",
				TXRX_INVERT_0									=>			 "00000",

				TX_BUFFER_USE_1								=>			 TRUE,
				TX_XCLK_SEL_1									=>			 "TXOUT",
				TXRX_INVERT_1									=>			 "00000",

				--------------------- TX Serial Line Rate settings ---------------------
				PLL_TXDIVSEL_OUT_0						=>			 CLOCK_DIVIDERS(0),												-- 1 => GENERATION_2, 2 => GENERATION_1
				PLL_TXDIVSEL_OUT_1						=>			 CLOCK_DIVIDERS(0),												-- 1 => GENERATION_2, 2 => GENERATION_1

				--------------------- TX Driver and OOB signalling --------------------
				TX_DIFF_BOOST_0								=>			 TRUE,
				TX_DIFF_BOOST_1								=>			 TRUE,

				------------------ TX Pipe Control for PCI Express/SATA ---------------
				COM_BURST_VAL_0								=>			 "0110",																	-- TX OOB burst counter
				COM_BURST_VAL_1								=>			 "0110",																	-- TX OOB burst counter

				-- =================== Receive Interface Attributes ===================
				------------ RX Driver,OOB signalling,Coupling and Eq,CDR -------------
				AC_CAP_DIS_0									=>			 FALSE,
				OOBDETECT_THRESHOLD_0					=>			 "100",																		-- Threshold between RXN and RXP is 105 mV
				PMA_CDR_SCAN_0								=>			 x"6C08040",
				PMA_RX_CFG_0									=>			 x"0DCE111",
				RCV_TERM_GND_0								=>			 FALSE,
				RCV_TERM_MID_0								=>			 TRUE,
				RCV_TERM_VTTRX_0							=>			 TRUE,
				TERMINATION_IMP_0							=>			 50,																			-- 50 Ohm Terminierung

				AC_CAP_DIS_1									=>			 FALSE,
				OOBDETECT_THRESHOLD_1					=>			 "100",																		-- Threshold between RXN and RXP is 105 mV
				PMA_CDR_SCAN_1								=>			 x"6C08040",
				PMA_RX_CFG_1									=>			 x"0DCE111",
				RCV_TERM_GND_1								=>			 FALSE,
				RCV_TERM_MID_1								=>			 TRUE,
				RCV_TERM_VTTRX_1							=>			 TRUE,
				TERMINATION_IMP_1							=>			 50,																			-- 50 Ohm Terminierung

	--			PCS_COM_CFG										=>			 x"1680a0e",
				TERMINATION_CTRL							=>			 "10100",
				TERMINATION_OVRD							=>			 FALSE,

				--------------------- RX Serial Line Rate Attributes ------------------
				PLL_RXDIVSEL_OUT_0						=>			 CLOCK_DIVIDERS(0),												-- 1 => GENERATION_2, 2 => GENERATION_1
				PLL_RXDIVSEL_OUT_1						=>			 CLOCK_DIVIDERS(0),

				PLL_SATA_0										=>			 FALSE,
				PLL_SATA_1										=>			 FALSE,

				----------------------- PRBS Detection Attributes ---------------------
				PRBS_ERR_THRESHOLD_0					=>			 x"00000008",
				PRBS_ERR_THRESHOLD_1					=>			 x"00000008",

				---------------- Comma Detection and Alignment Attributes -------------
				ALIGN_COMMA_WORD_0						=>			 1,
				COMMA_10B_ENABLE_0						=>			 "1111111111",
				COMMA_DOUBLE_0								=>			 FALSE,
				DEC_MCOMMA_DETECT_0						=>			 TRUE,
				DEC_PCOMMA_DETECT_0						=>			 TRUE,
				DEC_VALID_COMMA_ONLY_0				=>			 FALSE,
				MCOMMA_10B_VALUE_0						=>			 "1010000011",														-- K28.5
				MCOMMA_DETECT_0								=>			 TRUE,
				PCOMMA_10B_VALUE_0						=>			 "0101111100",														-- K28.5
				PCOMMA_DETECT_0								=>			 TRUE,
				RX_SLIDE_MODE_0								=>			 "PCS",

				ALIGN_COMMA_WORD_1						=>			 1,
				COMMA_10B_ENABLE_1						=>			 "1111111111",
				COMMA_DOUBLE_1								=>			 FALSE,
				DEC_MCOMMA_DETECT_1						=>			 TRUE,
				DEC_PCOMMA_DETECT_1						=>			 TRUE,
				DEC_VALID_COMMA_ONLY_1				=>			 FALSE,
				MCOMMA_10B_VALUE_1						=>			 "1010000011",														-- K28.5
				MCOMMA_DETECT_1								=>			 TRUE,
				PCOMMA_10B_VALUE_1						=>			 "0101111100",														-- K28.5
				PCOMMA_DETECT_1								=>			 TRUE,
				RX_SLIDE_MODE_1								=>			 "PCS",

				------------------ RX Loss-of-sync State Machine Attributes -----------
				RX_LOSS_OF_SYNC_FSM_0					=>			 FALSE,
				RX_LOS_INVALID_INCR_0					=>			 8,
				RX_LOS_THRESHOLD_0						=>			 128,

				RX_LOSS_OF_SYNC_FSM_1					=>			 FALSE,
				RX_LOS_INVALID_INCR_1					=>			 8,
				RX_LOS_THRESHOLD_1						=>			 128,

				-------------- RX Elastic Buffer and Phase alignment Attributes -------
				RX_BUFFER_USE_0								=>			 TRUE,
				RX_XCLK_SEL_0									=>			 "RXREC",

				RX_BUFFER_USE_1								=>			 TRUE,
				RX_XCLK_SEL_1									=>			 "RXREC",

				------------------------ Clock Correction Attributes ------------------
				CLK_CORRECT_USE_0							=>			 TRUE,
				CLK_COR_ADJ_LEN_0							=>			 4,
				CLK_COR_DET_LEN_0							=>			 4,
				CLK_COR_INSERT_IDLE_FLAG_0		=>			 FALSE,
				CLK_COR_KEEP_IDLE_0						=>			 FALSE,
				CLK_COR_MIN_LAT_0							=>			 16,
				CLK_COR_MAX_LAT_0							=>			 22,
				CLK_COR_PRECEDENCE_0					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_0					=>			 0,
				CLK_COR_SEQ_1_1_0							=>			 "0110111100",
				CLK_COR_SEQ_1_2_0							=>			 "0001001010",
				CLK_COR_SEQ_1_3_0							=>			 "0001001010",
				CLK_COR_SEQ_1_4_0							=>			 "0001111011",
				CLK_COR_SEQ_1_ENABLE_0				=>			 "1111",
				CLK_COR_SEQ_2_1_0							=>			 "0000000000",
				CLK_COR_SEQ_2_2_0							=>			 "0000000000",
				CLK_COR_SEQ_2_3_0							=>			 "0000000000",
				CLK_COR_SEQ_2_4_0							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_0				=>			 "0000",
				CLK_COR_SEQ_2_USE_0						=>			 FALSE,
				RX_DECODE_SEQ_MATCH_0					=>			 TRUE,

				CLK_CORRECT_USE_1							=>			 TRUE,
				CLK_COR_ADJ_LEN_1							=>			 4,
				CLK_COR_DET_LEN_1							=>			 4,
				CLK_COR_INSERT_IDLE_FLAG_1		=>			 FALSE,
				CLK_COR_KEEP_IDLE_1						=>			 FALSE,
				CLK_COR_MIN_LAT_1							=>			 16,
				CLK_COR_MAX_LAT_1							=>			 22,
				CLK_COR_PRECEDENCE_1					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_1					=>			 0,
				CLK_COR_SEQ_1_ENABLE_1				=>			 "1111",
				CLK_COR_SEQ_1_1_1							=>			 "0110111100",
				CLK_COR_SEQ_1_2_1							=>			 "0001001010",
				CLK_COR_SEQ_1_3_1							=>			 "0001001010",
				CLK_COR_SEQ_1_4_1							=>			 "0001111011",
				CLK_COR_SEQ_2_USE_1						=>			 FALSE,
				CLK_COR_SEQ_2_ENABLE_1				=>			 "0000",
				CLK_COR_SEQ_2_1_1							=>			 "0000000000",
				CLK_COR_SEQ_2_2_1							=>			 "0000000000",
				CLK_COR_SEQ_2_3_1							=>			 "0000000000",
				CLK_COR_SEQ_2_4_1							=>			 "0000000000",
				RX_DECODE_SEQ_MATCH_1					=>			 TRUE,

				------------------------ Channel Bonding Attributes -------------------
				CHAN_BOND_1_MAX_SKEW_0				=>			 7,
				CHAN_BOND_2_MAX_SKEW_0				=>			 7,
				CHAN_BOND_LEVEL_0							=>			 0,
				CHAN_BOND_MODE_0							=>			 "OFF",
				CHAN_BOND_SEQ_LEN_0						=>			 1,
				CHAN_BOND_SEQ_1_ENABLE_0			=>			 "0000",
				CHAN_BOND_SEQ_1_1_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_2_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_3_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_4_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_USE_0					=>			 FALSE,
				CHAN_BOND_SEQ_2_ENABLE_0			=>			 "0000",
				CHAN_BOND_SEQ_2_1_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_2_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_3_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_4_0						=>			 "0000000000",
				PCI_EXPRESS_MODE_0						=>			 FALSE,

				CHAN_BOND_1_MAX_SKEW_1				=>			 7,
				CHAN_BOND_2_MAX_SKEW_1				=>			 7,
				CHAN_BOND_LEVEL_1							=>			 0,
				CHAN_BOND_MODE_1							=>			 "OFF",
				CHAN_BOND_SEQ_LEN_1						=>			 1,
				CHAN_BOND_SEQ_1_ENABLE_1			=>			 "0000",
				CHAN_BOND_SEQ_1_1_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_2_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_3_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_4_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_USE_1					=>			 FALSE,
				CHAN_BOND_SEQ_2_ENABLE_1			=>			 "0000",
				CHAN_BOND_SEQ_2_1_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_2_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_3_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_4_1						=>			 "0000000000",
				PCI_EXPRESS_MODE_1						=>			 FALSE,

				------------------ RX Attributes for PCI Express/SATA ---------------
				-- OOB COM*** signal detector @ 25 MHz with DDR (20 ns)
				RX_STATUS_FMT_0								=>			 "SATA",
				SATA_BURST_VAL_0							=>			 "100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL_0								=>			 "011",							-- IDLE count between bursts in OOB COM*** signals
				SATA_MIN_BURST_0							=>			 4,									-- 80 ns				SATA Spec Rev 1.1		55 ns
				SATA_MAX_BURST_0							=>			 7,									-- 140 ns				SATA Spec Rev 1.1		175 ns
				SATA_MIN_INIT_0								=>			 12,								-- 240 ns				SATA Spec Rev 1.1		175 ns
				SATA_MAX_INIT_0								=>			 22,								-- 440 ns				SATA Spec Rev 1.1		525 ns
				SATA_MIN_WAKE_0								=>			 4,									-- 80 ns				SATA Spec Rev 1.1		55 ns
				SATA_MAX_WAKE_0								=>			 7,									-- 140 ns				SATA Spec Rev 1.1		175 ns
				TRANS_TIME_FROM_P2_0					=>			 x"0060",
				TRANS_TIME_NON_P2_0						=>			 x"0025",
				TRANS_TIME_TO_P2_0						=>			 x"0100",

				RX_STATUS_FMT_1								=>			"SATA",
				SATA_BURST_VAL_1							=>			"100",							-- Burst count to detect OOB COM*** signals
				SATA_IDLE_VAL_1								=>			"100",							-- IDLE count between bursts in OOB COM*** signals
				SATA_MAX_BURST_1							=>			7,
				SATA_MAX_INIT_1								=>			22,
				SATA_MAX_WAKE_1								=>			7,
				SATA_MIN_BURST_1							=>			4,
				SATA_MIN_INIT_1								=>			12,
				SATA_MIN_WAKE_1								=>			4,
				TRANS_TIME_FROM_P2_1					=>			x"0060",
				TRANS_TIME_NON_P2_1						=>			x"0025",
				TRANS_TIME_TO_P2_1						=>			x"0100"
			)
			port map (
				------------------------ Loopback and Powerdown Ports ----------------------
				LOOPBACK0											=>			"000",
				LOOPBACK1											=>			"000",
				RXPOWERDOWN0									=>			GTP_RX_PowerDown(0),
				RXPOWERDOWN1									=>			"11",
				TXPOWERDOWN0									=>			GTP_TX_PowerDown(0),
				TXPOWERDOWN1									=>			"11",
				----------------------- Receive Ports - 8b10b Decoder ----------------------
				RXCHARISCOMMA0								=>			GTP_RX_CharIsComma(0),				-- @ GTP_ClockRX_2X,
				RXCHARISCOMMA1								=>			open,
				RXCHARISK0										=>			GTP_RX_CharIsK(0),						-- @ GTP_ClockRX_2X,
				RXCHARISK1										=>			open,
				RXDEC8B10BUSE0								=>			'1',
				RXDEC8B10BUSE1								=>			'0',
				RXDISPERR0										=>			GTP_RX_DisparityError(0),			-- @ GTP_ClockRX_2X,
				RXDISPERR1										=>			open,
				RXNOTINTABLE0									=>			GTP_RX_Illegal8B10BCode(0),		-- @ GTP_ClockRX_2X,
				RXNOTINTABLE1									=>			open,
				RXRUNDISP0										=>			open,
				RXRUNDISP1										=>			open,
				------------------- Receive Ports - Channel Bonding Ports ------------------
				RXCHANBONDSEQ0								=>			open,
				RXCHANBONDSEQ1								=>			open,
				RXCHBONDI0										=>			"000",
				RXCHBONDI1										=>			"000",
				RXCHBONDO0										=>			open,
				RXCHBONDO1										=>			open,
				RXENCHANSYNC0									=>			'0',
				RXENCHANSYNC1									=>			'0',
				------------------- Receive Ports - Clock Correction Ports -----------------
				RXCLKCORCNT0									=>			GTP_RX_ClockCorrectionStatus(0),
				RXCLKCORCNT1									=>			open,
				--------------- Receive Ports - Comma Detection and Alignment --------------
				RXBYTEISALIGNED0							=>			GTP_RX_ByteIsAligned(0),									-- @ GTP_ClockRX_2X,	high-active, long signal			bytes are aligned
				RXBYTEISALIGNED1							=>			open,
				RXBYTEREALIGN0								=>			GTP_RX_ByteRealign(0),										-- @ GTP_ClockRX_2X,	hight-active, short pulse			alignment has changed
				RXBYTEREALIGN1								=>			open,
				RXCOMMADET0										=>			GTP_RX_CommaDetected(0),
				RXCOMMADET1										=>			open,
				RXCOMMADETUSE0								=>			'1',
				RXCOMMADETUSE1								=>			'0',
				RXENMCOMMAALIGN0							=>			'1',
				RXENMCOMMAALIGN1							=>			'1',
				RXENPCOMMAALIGN0							=>			'1',
				RXENPCOMMAALIGN1							=>			'1',
				RXSLIDE0											=>			'0',
				RXSLIDE1											=>			'0',
				----------------------- Receive Ports - PRBS Detection ---------------------
				PRBSCNTRESET0									=>			'0',
				PRBSCNTRESET1									=>			'0',
				RXENPRBSTST0									=>			"00",
				RXENPRBSTST1									=>			"00",
				RXPRBSERR0										=>			open,
				RXPRBSERR1										=>			open,
				------------------- Receive Ports - RX Data Path interface -----------------
				RXDATA0												=>			GTP_RX_Data(0),
				RXDATA1												=>			open,
				RXDATAWIDTH0									=>			'0',																			-- 8 Bit data interface
				RXDATAWIDTH1									=>			'0',																			-- 8 Bit data interface
				RXRECCLK0											=>			GTP_RX_RefClockOut(0),										-- recovered clock from CDR
				RXRECCLK1											=>			open,
				RXRESET0											=>			GTP_RX_Reset(0),
				RXRESET1											=>			'0',
				RXUSRCLK0											=>			GTP_Clock_1X(0),
				RXUSRCLK1											=>			'0',
				RXUSRCLK20										=>			GTP_Clock_1X(0),
				RXUSRCLK21										=>			'0',
				------- Receive Ports - RX Driver,OOB signaling,Coupling and Eq.,CDR ------
				RXCDRRESET0										=>			GTP_RX_CDR_Reset(0),											-- CDR => Clock Data Recovery
				RXCDRRESET1										=>			'0',
				RXELECIDLE0										=>			GTP_RX_ElectricalIDLE(0),
				RXELECIDLE1										=>			open,
				RXELECIDLERESET0							=>			GTP_RX_ElectricalIDLE_Reset(0),
				RXELECIDLERESET1							=>			'0',
				RXENEQB0											=>			'1',
				RXENEQB1											=>			'1',
				RXEQMIX0											=>			"00",
				RXEQMIX1											=>			"00",
				RXEQPOLE0											=>			"0000",
				RXEQPOLE1											=>			"0000",
				RXN0													=>			VSS_Private_In(0).RX_n,
				RXP0													=>			VSS_Private_In(0).RX_p,
				RXN1													=>			'0',
				RXP1													=>			'1',
				-------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
				RXBUFRESET0										=>			GTP_RX_BufferReset(0),
				RXBUFRESET1										=>			'0',
				RXBUFSTATUS0									=>			GTP_RX_BufferStatus(0),										-- GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS1									=>			open,
				RXCHANISALIGNED0							=>			open,
				RXCHANISALIGNED1							=>			open,
				RXCHANREALIGN0								=>			open,
				RXCHANREALIGN1								=>			open,
				RXPMASETPHASE0								=>			'0',
				RXPMASETPHASE1								=>			'0',
				RXSTATUS0											=>			GTP_RX_Status(0),
				RXSTATUS1											=>			open,
				--------------- Receive Ports - RX Loss-of-sync State Machine --------------
				RXLOSSOFSYNC0									=>			GTP_RX_LossOfSync(0),											-- Xilinx example has connected signal
				RXLOSSOFSYNC1									=>			open,
				---------------------- Receive Ports - RX Oversampling ---------------------
				RXENSAMPLEALIGN0							=>			'0',
				RXENSAMPLEALIGN1							=>			'0',
				RXOVERSAMPLEERR0							=>			open,
				RXOVERSAMPLEERR1							=>			open,
				-------------- Receive Ports - RX Pipe Control for PCI Express -------------
				PHYSTATUS0										=>			open,
				PHYSTATUS1										=>			open,
				RXVALID0											=>			GTP_RX_Valid(0),
				RXVALID1											=>			open,
				----------------- Receive Ports - RX Polarity Control Ports ----------------
				RXPOLARITY0										=>			'0',
				RXPOLARITY1										=>			'0',
				------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
				DCLK													=>			GTP_DRP_Clock,
				DEN														=>			GTP_DRP_en,
				DADDR													=>			GTP_DRP_Address(6 downto 0),							-- resize vector to GTP_DUAL specific address bits
				DWE														=>			GTP_DRP_we,
				DI														=>			GTP_DRP_DataIn,
				DO														=>			GTP_DRP_DataOut,
				DRDY													=>			GTP_DRP_rdy,
				--------------------- Shared Ports - Tile and PLL Ports --------------------
				CLKIN													=>			GTP_RefClockIn,
				GTPRESET											=>			GTP_Reset,
				GTPTEST												=>			"0000",
				INTDATAWIDTH									=>			'1',																									-- 10 Bit internal datawidth
				PLLLKDET											=>			GTP_PLL_ResetDone_i,																		-- GTP PLL lock detected
				PLLLKDETEN										=>			'1',
				PLLPOWERDOWN									=>			GTP_PLL_PowerDown,
				REFCLKOUT											=>			GTP_RefClockOut_i,
				REFCLKPWRDNB									=>			'1',
				RESETDONE0										=>			GTP_ResetDone_i(0),
				RESETDONE1										=>			open,
				RXENELECIDLERESETB						=>			GTP_RX_DisableElectricalIDLEReset,									-- low-active => disable
				TXENPMAPHASEALIGN							=>			'0',
				TXPMASETPHASE									=>			'0',
					---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
				TXBYPASS8B10B0								=>			"00",																									-- encode both bytes with 8B10B
				TXBYPASS8B10B1								=>			"00",
				TXCHARDISPMODE0								=>			"00",
				TXCHARDISPMODE1								=>			"00",
				TXCHARDISPVAL0								=>			"00",
				TXCHARDISPVAL1								=>			"00",
				TXCHARISK0										=>			GTP_TX_CharIsK(0),
				TXCHARISK1										=>			"00",
				TXENC8B10BUSE0								=>			'1',																									-- use internal 8B10B encoder
				TXENC8B10BUSE1								=>			'0',
				TXKERR0												=>			GTP_TX_InvalidK(0),																		-- invalid K charakter
				TXKERR1												=>			open,
				TXRUNDISP0										=>			open,																									-- running disparity
				TXRUNDISP1										=>			open,
				------------- Transmit Ports - TX Buffering and Phase Alignment ------------
				TXBUFSTATUS0									=>			GTP_TX_BufferStatus(0),
				TXBUFSTATUS1									=>			open,
				------------------ Transmit Ports - TX Data Path interface -----------------
				TXDATA0												=>			GTP_TX_Data(0),
				TXDATA1												=>			(others => '0'),
				TXDATAWIDTH0									=>			'0',																									-- 8 Bit interface
				TXDATAWIDTH1									=>			'0',
				TXOUTCLK0											=>			GTP_TX_RefClockOut(0),
				TXOUTCLK1											=>			open,
				TXRESET0											=>			GTP_TX_Reset(0),
				TXRESET1											=>			'0',								-- GTP_TX_Reset
				TXUSRCLK0											=>			GTP_Clock_1X(0),
				TXUSRCLK1											=>			'0',								-- GTP_Clock_1X
				TXUSRCLK20										=>			GTP_Clock_1X(0),	--GTP_ClockTX_2X(0),
				TXUSRCLK21										=>			'0',								-- GTP_ClockTX_2X
				--------------- Transmit Ports - TX Driver and OOB signaling --------------
				TXBUFDIFFCTRL0								=>			"001",
				TXBUFDIFFCTRL1								=>			"001",
				TXDIFFCTRL0										=>			"100",
				TXDIFFCTRL1										=>			"100",
				TXINHIBIT0										=>			'0',
				TXINHIBIT1										=>			'0',
				TXN0													=>			VSS_Private_Out(0).TX_n,
				TXP0													=>			VSS_Private_Out(0).TX_p,
				TXN1													=>			open,
				TXP1													=>			open,
				TXPREEMPHASIS0								=>			"011",
				TXPREEMPHASIS1								=>			"011",
				--------------------- Transmit Ports - TX PRBS Generator -------------------
				TXENPRBSTST0									=>			"00",
				TXENPRBSTST1									=>			"00",
				-------------------- Transmit Ports - TX Polarity Control ------------------
				TXPOLARITY0										=>			'0',
				TXPOLARITY1										=>			'0',
					----------------- Transmit Ports - TX Ports for PCI Express ----------------
				TXDETECTRX0										=>			'0',
				TXDETECTRX1										=>			'0',
				TXELECIDLE0										=>			GTP_TX_ElectricalIDLE(0),
				TXELECIDLE1										=>			'1',
					--------------------- Transmit Ports - TX Ports for SATA -------------------
				TXCOMSTART0										=>			GTP_TX_ComStart(0),
				TXCOMSTART1										=>			'0',
				TXCOMTYPE0										=>			GTP_TX_ComType(0),
				TXCOMTYPE1										=>			'0'
			);
	end generate;


-- ==================================================================
-- GTP_DUAL - 2 used ports
-- ==================================================================
	DualPort : if (PORTS = 2) generate
		signal GTP_RX_DisableElectricalIDLEReset : std_logic;
	begin
		GTP_RX_DisableElectricalIDLEReset		<= not GTP_RX_EnableElectricalIDLEReset;

		GTP : GTP_DUAL
			generic map (
				-- ===================== Simulation-Only Attributes ====================
	--			SIM_RECEIVER_DETECT_PASS0	 		=>			 TRUE,
	--			SIM_RECEIVER_DETECT_PASS1	 		=>			 TRUE,
				SIM_MODE											=>			 "FAST",
				SIM_GTPRESET_SPEEDUP					=>			 1,
	--			SIM_PLL_PERDIV2								=>			 TILE_SIM_PLL_PERDIV2,

				-- ========================== Shared Attributes ========================
				-------------------------- Tile and PLL Attributes ---------------------
				CLK25_DIVIDER									=>			 6,
				CLKINDC_B											=>			 TRUE,
				OOB_CLK_DIVIDER								=>			 6,
				OVERSAMPLE_MODE								=>			 FALSE,
				PLL_DIVSEL_FB									=>			 2,
				PLL_DIVSEL_REF								=>			 1,
				PLL_TXDIVSEL_COMM_OUT					=>			 1,
				TX_SYNC_FILTERB								=>			 1,

				-- ================== Transmit Interface Attributes ====================
				------------------- TX Buffering and Phase Alignment -------------------
				TX_BUFFER_USE_0								=>			 TRUE,
				TX_XCLK_SEL_0									=>			 "TXOUT",
				TXRX_INVERT_0									=>			 "00000",

				TX_BUFFER_USE_1								=>			 TRUE,
				TX_XCLK_SEL_1									=>			 "TXOUT",
				TXRX_INVERT_1									=>			 "00000",

				--------------------- TX Serial Line Rate settings ---------------------
				PLL_TXDIVSEL_OUT_0						=>			 CLOCK_DIVIDERS(0),							-- 1 => GENERATION_2, 2 => GENERATION_1
				PLL_TXDIVSEL_OUT_1						=>			 CLOCK_DIVIDERS(1),

				--------------------- TX Driver and OOB signalling --------------------
				TX_DIFF_BOOST_0								=>			 TRUE,
				TX_DIFF_BOOST_1								=>			 TRUE,

				------------------ TX Pipe Control for PCI Express/SATA ---------------
				COM_BURST_VAL_0								=>			 "0110",
				COM_BURST_VAL_1								=>			 "0110",

				-- =================== Receive Interface Attributes ===================
				------------ RX Driver,OOB signalling,Coupling and Eq,CDR -------------
				AC_CAP_DIS_0									=>			 FALSE,
				OOBDETECT_THRESHOLD_0					=>			 "100",					-- treshold voltage = 105 mV
				PMA_CDR_SCAN_0								=>			 x"6C08040",
				PMA_RX_CFG_0									=>			 x"0DCE111",
				RCV_TERM_GND_0								=>			 FALSE,
				RCV_TERM_MID_0								=>			 TRUE,
				RCV_TERM_VTTRX_0							=>			 TRUE,
				TERMINATION_IMP_0							=>			 50,						-- 50 Ohm termination

				AC_CAP_DIS_1									=>			 FALSE,
				OOBDETECT_THRESHOLD_1					=>			 "100",					-- treshold voltage = 105 mV
				PMA_CDR_SCAN_1								=>			 x"6C08040",
				PMA_RX_CFG_1									=>			 x"0DCE111",
				RCV_TERM_GND_1								=>			 FALSE,
				RCV_TERM_MID_1								=>			 TRUE,
				RCV_TERM_VTTRX_1							=>			 TRUE,
				TERMINATION_IMP_1							=>			 50,						-- 50 Ohm termination

	--			PCS_COM_CFG										=>			 x"1680a0e",
				TERMINATION_CTRL							=>			 "10100",
				TERMINATION_OVRD							=>			 FALSE,

				--------------------- RX Serial Line Rate Attributes ------------------
				PLL_RXDIVSEL_OUT_0						=>			 CLOCK_DIVIDERS(0),							-- 1 => GENERATION_2, 2 => GENERATION_1
				PLL_RXDIVSEL_OUT_1						=>			 CLOCK_DIVIDERS(1),							-- 1 => GENERATION_2, 2 => GENERATION_1

				PLL_SATA_0										=>			 FALSE,
				PLL_SATA_1										=>			 FALSE,

				----------------------- PRBS Detection Attributes ---------------------
				PRBS_ERR_THRESHOLD_0					=>			 x"00000008",
				PRBS_ERR_THRESHOLD_1					=>			 x"00000008",

				---------------- Comma Detection and Alignment Attributes -------------
				ALIGN_COMMA_WORD_0						=>			 1,
				COMMA_10B_ENABLE_0						=>			 "1111111111",
				COMMA_DOUBLE_0								=>			 FALSE,
				DEC_MCOMMA_DETECT_0						=>			 TRUE,
				DEC_PCOMMA_DETECT_0						=>			 TRUE,
				DEC_VALID_COMMA_ONLY_0				=>			 FALSE,
				MCOMMA_10B_VALUE_0						=>			 "1010000011",
				MCOMMA_DETECT_0								=>			 TRUE,
				PCOMMA_10B_VALUE_0						=>			 "0101111100",
				PCOMMA_DETECT_0								=>			 TRUE,
				RX_SLIDE_MODE_0								=>			 "PCS",

				ALIGN_COMMA_WORD_1						=>			 1,
				COMMA_10B_ENABLE_1						=>			 "1111111111",
				COMMA_DOUBLE_1								=>			 FALSE,
				DEC_MCOMMA_DETECT_1						=>			 TRUE,
				DEC_PCOMMA_DETECT_1						=>			 TRUE,
				DEC_VALID_COMMA_ONLY_1				=>			 FALSE,
				MCOMMA_10B_VALUE_1						=>			 "1010000011",
				MCOMMA_DETECT_1								=>			 TRUE,
				PCOMMA_10B_VALUE_1						=>			 "0101111100",
				PCOMMA_DETECT_1								=>			 TRUE,
				RX_SLIDE_MODE_1								=>			 "PCS",

				------------------ RX Loss-of-sync State Machine Attributes -----------
				RX_LOSS_OF_SYNC_FSM_0					=>			 FALSE,
				RX_LOS_INVALID_INCR_0					=>			 8,
				RX_LOS_THRESHOLD_0						=>			 128,

				RX_LOSS_OF_SYNC_FSM_1					=>			 FALSE,
				RX_LOS_INVALID_INCR_1					=>			 8,
				RX_LOS_THRESHOLD_1						=>			 128,

				-------------- RX Elastic Buffer and Phase alignment Attributes -------
				RX_BUFFER_USE_0								=>			 TRUE,
				RX_XCLK_SEL_0									=>			 "RXREC",

				RX_BUFFER_USE_1								=>			 TRUE,
				RX_XCLK_SEL_1									=>			 "RXREC",

				------------------------ Clock Correction Attributes ------------------
				CLK_CORRECT_USE_0							=>			 TRUE,
				CLK_COR_ADJ_LEN_0							=>			 4,
				CLK_COR_DET_LEN_0							=>			 4,
				CLK_COR_INSERT_IDLE_FLAG_0		=>			 FALSE,
				CLK_COR_KEEP_IDLE_0						=>			 FALSE,
				CLK_COR_MIN_LAT_0							=>			 16,
				CLK_COR_MAX_LAT_0							=>			 18,
				CLK_COR_PRECEDENCE_0					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_0					=>			 0,
				CLK_COR_SEQ_1_1_0							=>			 "0110111100",
				CLK_COR_SEQ_1_2_0							=>			 "0001001010",
				CLK_COR_SEQ_1_3_0							=>			 "0001001010",
				CLK_COR_SEQ_1_4_0							=>			 "0001111011",
				CLK_COR_SEQ_1_ENABLE_0				=>			 "1111",
				CLK_COR_SEQ_2_1_0							=>			 "0000000000",
				CLK_COR_SEQ_2_2_0							=>			 "0000000000",
				CLK_COR_SEQ_2_3_0							=>			 "0000000000",
				CLK_COR_SEQ_2_4_0							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_0				=>			 "0000",
				CLK_COR_SEQ_2_USE_0						=>			 FALSE,
				RX_DECODE_SEQ_MATCH_0					=>			 TRUE,

				CLK_CORRECT_USE_1							=>			 TRUE,
				CLK_COR_ADJ_LEN_1							=>			 4,
				CLK_COR_DET_LEN_1							=>			 4,
				CLK_COR_INSERT_IDLE_FLAG_1		=>			 FALSE,
				CLK_COR_KEEP_IDLE_1						=>			 FALSE,
				CLK_COR_MIN_LAT_1							=>			 16,
				CLK_COR_MAX_LAT_1							=>			 18,
				CLK_COR_PRECEDENCE_1					=>			 TRUE,
				CLK_COR_REPEAT_WAIT_1					=>			 0,
				CLK_COR_SEQ_1_1_1							=>			 "0110111100",
				CLK_COR_SEQ_1_2_1							=>			 "0001001010",
				CLK_COR_SEQ_1_3_1							=>			 "0001001010",
				CLK_COR_SEQ_1_4_1							=>			 "0001111011",
				CLK_COR_SEQ_1_ENABLE_1				=>			 "1111",
				CLK_COR_SEQ_2_1_1							=>			 "0000000000",
				CLK_COR_SEQ_2_2_1							=>			 "0000000000",
				CLK_COR_SEQ_2_3_1							=>			 "0000000000",
				CLK_COR_SEQ_2_4_1							=>			 "0000000000",
				CLK_COR_SEQ_2_ENABLE_1				=>			 "0000",
				CLK_COR_SEQ_2_USE_1						=>			 FALSE,
				RX_DECODE_SEQ_MATCH_1					=>			 TRUE,

				------------------------ Channel Bonding Attributes -------------------
				CHAN_BOND_1_MAX_SKEW_0				=>			 7,
				CHAN_BOND_2_MAX_SKEW_0				=>			 7,
				CHAN_BOND_LEVEL_0							=>			 0,
				CHAN_BOND_MODE_0							=>			 "OFF",
				CHAN_BOND_SEQ_1_1_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_2_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_3_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_4_0						=>			 "0000000000",
				CHAN_BOND_SEQ_1_ENABLE_0			=>			 "0000",
				CHAN_BOND_SEQ_2_1_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_2_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_3_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_4_0						=>			 "0000000000",
				CHAN_BOND_SEQ_2_ENABLE_0			=>			 "0000",
				CHAN_BOND_SEQ_2_USE_0					=>			 FALSE,
				CHAN_BOND_SEQ_LEN_0						=>			 1,
				PCI_EXPRESS_MODE_0						=>			 FALSE,

				CHAN_BOND_1_MAX_SKEW_1				=>			 7,
				CHAN_BOND_2_MAX_SKEW_1				=>			 7,
				CHAN_BOND_LEVEL_1							=>			 0,
				CHAN_BOND_MODE_1							=>			 "OFF",
				CHAN_BOND_SEQ_1_1_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_2_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_3_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_4_1						=>			 "0000000000",
				CHAN_BOND_SEQ_1_ENABLE_1			=>			 "0000",
				CHAN_BOND_SEQ_2_1_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_2_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_3_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_4_1						=>			 "0000000000",
				CHAN_BOND_SEQ_2_ENABLE_1			=>			 "0000",
				CHAN_BOND_SEQ_2_USE_1					=>			 FALSE,
				CHAN_BOND_SEQ_LEN_1						=>			 1,
				PCI_EXPRESS_MODE_1						=>			 FALSE,

				------------------ RX Attributes for PCI Express/SATA ---------------
				RX_STATUS_FMT_0								=>			 "SATA",
				SATA_BURST_VAL_0							=>			 "100",
				SATA_IDLE_VAL_0								=>			 "011",
				SATA_MIN_BURST_0							=>			 4,
				SATA_MAX_BURST_0							=>			 7,
				SATA_MIN_INIT_0								=>			 12,
				SATA_MAX_INIT_0								=>			 22,
				SATA_MIN_WAKE_0								=>			 4,
				SATA_MAX_WAKE_0								=>			 7,
				TRANS_TIME_FROM_P2_0					=>			 x"0060",
				TRANS_TIME_NON_P2_0						=>			 x"0025",
				TRANS_TIME_TO_P2_0						=>			 x"0100",

				RX_STATUS_FMT_1								=>			"SATA",
				SATA_BURST_VAL_1							=>			"100",
				SATA_IDLE_VAL_1								=>			"011",
				SATA_MIN_BURST_1							=>			4,
				SATA_MAX_BURST_1							=>			7,
				SATA_MIN_INIT_1								=>			12,
				SATA_MAX_INIT_1								=>			22,
				SATA_MIN_WAKE_1								=>			4,
				SATA_MAX_WAKE_1								=>			7,
				TRANS_TIME_FROM_P2_1					=>			x"0060",
				TRANS_TIME_NON_P2_1						=>			x"0025",
				TRANS_TIME_TO_P2_1						=>			x"0100"
			)
			port map (
				------------------------ Loopback and Powerdown Ports ----------------------
				LOOPBACK0											=>			"000",
				LOOPBACK1											=>			"000",
				RXPOWERDOWN0									=>			GTP_RX_PowerDown(0),
				RXPOWERDOWN1									=>			GTP_RX_PowerDown(1),
				TXPOWERDOWN0									=>			GTP_TX_PowerDown(0),
				TXPOWERDOWN1									=>			GTP_TX_PowerDown(1),
				----------------------- Receive Ports - 8b10b Decoder ----------------------
				RXCHARISCOMMA0								=>			GTP_RX_CharIsComma(0),				-- @ GTP_ClockRX_2X,
				RXCHARISCOMMA1								=>			GTP_RX_CharIsComma(1),
				RXCHARISK0										=>			GTP_RX_CharIsK(0),						-- @ GTP_ClockRX_2X,
				RXCHARISK1										=>			GTP_RX_CharIsK(1),
				RXDEC8B10BUSE0								=>			'1',
				RXDEC8B10BUSE1								=>			'1',
				RXDISPERR0										=>			GTP_RX_DisparityError(0),			-- @ GTP_ClockRX_2X,
				RXDISPERR1										=>			GTP_RX_DisparityError(1),
				RXNOTINTABLE0									=>			GTP_RX_Illegal8B10BCode(0),		-- @ GTP_ClockRX_2X,
				RXNOTINTABLE1									=>			GTP_RX_Illegal8B10BCode(1),
				RXRUNDISP0										=>			open,
				RXRUNDISP1										=>			open,
				------------------- Receive Ports - Channel Bonding Ports ------------------
				RXCHANBONDSEQ0								=>			open,
				RXCHANBONDSEQ1								=>			open,
				RXCHBONDI0										=>			"000",
				RXCHBONDI1										=>			"000",
				RXCHBONDO0										=>			open,
				RXCHBONDO1										=>			open,
				RXENCHANSYNC0									=>			'0',
				RXENCHANSYNC1									=>			'0',
				------------------- Receive Ports - Clock Correction Ports -----------------
				RXCLKCORCNT0									=>			GTP_RX_ClockCorrectionStatus(0),
				RXCLKCORCNT1									=>			GTP_RX_ClockCorrectionStatus(1),
				--------------- Receive Ports - Comma Detection and Alignment --------------
				RXBYTEISALIGNED0							=>			GTP_RX_ByteIsAligned(0),									-- @ GTP_ClockRX_2X,	high-active, long signal			bytes are aligned
				RXBYTEISALIGNED1							=>			GTP_RX_ByteIsAligned(1),
				RXBYTEREALIGN0								=>			GTP_RX_ByteRealign(0),										-- @ GTP_ClockRX_2X,	hight-active, short pulse			alignment has changed
				RXBYTEREALIGN1								=>			GTP_RX_ByteRealign(1),
				RXCOMMADET0										=>			GTP_RX_CommaDetected(0),
				RXCOMMADET1										=>			GTP_RX_CommaDetected(1),
				RXCOMMADETUSE0								=>			'1',
				RXCOMMADETUSE1								=>			'1',
				RXENMCOMMAALIGN0							=>			'1',
				RXENMCOMMAALIGN1							=>			'1',
				RXENPCOMMAALIGN0							=>			'1',
				RXENPCOMMAALIGN1							=>			'1',
				RXSLIDE0											=>			'0',
				RXSLIDE1											=>			'0',
				----------------------- Receive Ports - PRBS Detection ---------------------
				PRBSCNTRESET0									=>			'0',
				PRBSCNTRESET1									=>			'0',
				RXENPRBSTST0									=>			"00",
				RXENPRBSTST1									=>			"00",
				RXPRBSERR0										=>			open,
				RXPRBSERR1										=>			open,
				------------------- Receive Ports - RX Data Path interface -----------------
				RXDATA0												=>			GTP_RX_Data(0),
				RXDATA1												=>			GTP_RX_Data(1),
				RXDATAWIDTH0									=>			'0',																			-- 8 Bit data interface
				RXDATAWIDTH1									=>			'0',																			-- 8 Bit data interface
				RXRECCLK0											=>			GTP_RX_RefClockOut(0),										-- recovered clock from CDR
				RXRECCLK1											=>			GTP_RX_RefClockOut(1),										-- recovered clock from CDR
				RXRESET0											=>			GTP_RX_Reset(0),
				RXRESET1											=>			GTP_RX_Reset(1),
				RXUSRCLK0											=>			GTP_Clock_1X(0),
				RXUSRCLK1											=>			GTP_Clock_1X(1),
				RXUSRCLK20										=>			GTP_Clock_1X(0),
				RXUSRCLK21										=>			GTP_Clock_1X(1),
				------- Receive Ports - RX Driver,OOB signaling,Coupling and Eq.,CDR ------
				RXCDRRESET0										=>			GTP_RX_CDR_Reset(0),											-- CDR => Clock Data Recovery
				RXCDRRESET1										=>			GTP_RX_CDR_Reset(1),
				RXELECIDLE0										=>			GTP_RX_ElectricalIDLE(0),
				RXELECIDLE1										=>			GTP_RX_ElectricalIDLE(1),
				RXELECIDLERESET0							=>			GTP_RX_ElectricalIDLE_Reset(0),
				RXELECIDLERESET1							=>			GTP_RX_ElectricalIDLE_Reset(1),
				RXENEQB0											=>			'1',
				RXENEQB1											=>			'1',
				RXEQMIX0											=>			"00",
				RXEQMIX1											=>			"00",
				RXEQPOLE0											=>			"0000",
				RXEQPOLE1											=>			"0000",
				RXN0													=>			VSS_Private_In(0).RX_n,
				RXP0													=>			VSS_Private_In(0).RX_p,
				RXN1													=>			VSS_Private_In(1).RX_n,
				RXP1													=>			VSS_Private_In(1).RX_p,
				-------- Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
				RXBUFRESET0										=>			GTP_RX_BufferReset(0),
				RXBUFRESET1										=>			GTP_RX_BufferReset(1),
				RXBUFSTATUS0									=>			GTP_RX_BufferStatus(0),													-- @GTP_ClockRX_2X,	RX buffer status (over/underflow)
				RXBUFSTATUS1									=>			GTP_RX_BufferStatus(1),
				RXCHANISALIGNED0							=>			open,
				RXCHANISALIGNED1							=>			open,
				RXCHANREALIGN0								=>			open,
				RXCHANREALIGN1								=>			open,
				RXPMASETPHASE0								=>			'0',
				RXPMASETPHASE1								=>			'0',
				RXSTATUS0											=>			GTP_RX_Status(0),
				RXSTATUS1											=>			GTP_RX_Status(1),
				--------------- Receive Ports - RX Loss-of-sync State Machine --------------
				RXLOSSOFSYNC0									=>			GTP_RX_LossOfSync(0),														-- Xilinx example has connected signal
				RXLOSSOFSYNC1									=>			GTP_RX_LossOfSync(1),
				---------------------- Receive Ports - RX Oversampling ---------------------
				RXENSAMPLEALIGN0							=>			'0',
				RXENSAMPLEALIGN1							=>			'0',
				RXOVERSAMPLEERR0							=>			open,
				RXOVERSAMPLEERR1							=>			open,
				-------------- Receive Ports - RX Pipe Control for PCI Express -------------
				PHYSTATUS0										=>			open,
				PHYSTATUS1										=>			open,
				RXVALID0											=>			GTP_RX_Valid(0),
				RXVALID1											=>			GTP_RX_Valid(1),
				----------------- Receive Ports - RX Polarity Control Ports ----------------
				RXPOLARITY0										=>			'0',
				RXPOLARITY1										=>			'0',
				------------- Shared Ports - Dynamic Reconfiguration Port (DRP) ------------
				DCLK													=>			GTP_DRP_Clock,
				DEN														=>			GTP_DRP_en,
				DADDR													=>			GTP_DRP_Address(6 downto 0),
				DWE														=>			GTP_DRP_we,
				DI														=>			GTP_DRP_DataIn,
				DO														=>			GTP_DRP_DataOut,
				DRDY													=>			GTP_DRP_rdy,
				--------------------- Shared Ports - Tile and PLL Ports --------------------
				CLKIN													=>			GTP_RefClockIn,
				GTPRESET											=>			GTP_Reset,
				GTPTEST												=>			"0000",
				INTDATAWIDTH									=>			'1',																			-- 10 Bit internal datawidth
				PLLLKDET											=>			GTP_PLL_ResetDone_i,												-- GTP PLL lock detected
				PLLLKDETEN										=>			'1',
				PLLPOWERDOWN									=>			GTP_PLL_PowerDown,
				REFCLKOUT											=>			GTP_RefClockOut_i,
				REFCLKPWRDNB									=>			'1',
				RESETDONE0										=>			GTP_ResetDone_i(0),
				RESETDONE1										=>			GTP_ResetDone_i(1),
				RXENELECIDLERESETB						=>			GTP_RX_DisableElectricalIDLEReset,				-- low-active
				TXENPMAPHASEALIGN							=>			'0',
				TXPMASETPHASE									=>			'0',
					---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
				TXBYPASS8B10B0								=>			"00",																			-- encode both bytes with 8B10B
				TXBYPASS8B10B1								=>			"00",
				TXCHARDISPMODE0								=>			"00",
				TXCHARDISPMODE1								=>			"00",
				TXCHARDISPVAL0								=>			"00",
				TXCHARDISPVAL1								=>			"00",
				TXCHARISK0										=>			GTP_TX_CharIsK(0),
				TXCHARISK1										=>			GTP_TX_CharIsK(1),
				TXENC8B10BUSE0								=>			'1',																			-- use internal 8B10B encoder
				TXENC8B10BUSE1								=>			'1',
				TXKERR0												=>			GTP_TX_InvalidK(0),												-- invalid K charakter
				TXKERR1												=>			GTP_TX_InvalidK(1),
				TXRUNDISP0										=>			open,																			-- running disparity
				TXRUNDISP1										=>			open,
				------------- Transmit Ports - TX Buffering and Phase Alignment ------------
				TXBUFSTATUS0									=>			GTP_TX_BufferStatus(0),
				TXBUFSTATUS1									=>			GTP_TX_BufferStatus(1),
				------------------ Transmit Ports - TX Data Path interface -----------------
				TXDATA0												=>			GTP_TX_Data(0),
				TXDATA1												=>			GTP_TX_Data(1),
				TXDATAWIDTH0									=>			'0',																			-- 8 Bit data interface
				TXDATAWIDTH1									=>			'0',																			-- 8 Bit data interface
				TXOUTCLK0											=>			GTP_TX_RefClockOut(0),
				TXOUTCLK1											=>			GTP_TX_RefClockOut(1),
				TXRESET0											=>			GTP_TX_Reset(0),
				TXRESET1											=>			GTP_TX_Reset(1),													-- GTP_TX_Reset
				TXUSRCLK0											=>			GTP_Clock_1X(0),
				TXUSRCLK1											=>			GTP_Clock_1X(1),												-- GTP_Clock_1X
				TXUSRCLK20										=>			GTP_Clock_1X(0),
				TXUSRCLK21										=>			GTP_Clock_1X(1),												-- GTP_ClockTX_2X
				--------------- Transmit Ports - TX Driver and OOB signaling --------------
				TXBUFDIFFCTRL0								=>			"001",
				TXBUFDIFFCTRL1								=>			"001",
				TXDIFFCTRL0										=>			"100",
				TXDIFFCTRL1										=>			"100",
				TXINHIBIT0										=>			'0',
				TXINHIBIT1										=>			'0',
				TXN0													=>			VSS_Private_Out(0).TX_n,
				TXP0													=>			VSS_Private_Out(0).TX_p,
				TXN1													=>			VSS_Private_Out(1).TX_n,
				TXP1													=>			VSS_Private_Out(1).TX_p,
				TXPREEMPHASIS0								=>			"011",
				TXPREEMPHASIS1								=>			"011",
				--------------------- Transmit Ports - TX PRBS Generator -------------------
				TXENPRBSTST0									=>			"00",
				TXENPRBSTST1									=>			"00",
				-------------------- Transmit Ports - TX Polarity Control ------------------
				TXPOLARITY0										=>			'0',
				TXPOLARITY1										=>			'0',
					----------------- Transmit Ports - TX Ports for PCI Express ----------------
				TXDETECTRX0										=>			'0',
				TXDETECTRX1										=>			'0',
				TXELECIDLE0										=>			GTP_TX_ElectricalIDLE(0),
				TXELECIDLE1										=>			GTP_TX_ElectricalIDLE(1),
					--------------------- Transmit Ports - TX Ports for SATA -------------------
				TXCOMSTART0										=>			GTP_TX_ComStart(0),
				TXCOMSTART1										=>			GTP_TX_ComStart(1),
				TXCOMTYPE0										=>			GTP_TX_ComType(0),
				TXCOMTYPE1										=>			GTP_TX_ComType(1)
			);
	end generate;

-- ==================================================================
-- ChipScope debugging signals
-- ==================================================================
	genCSP : if (DEBUG = TRUE) generate
		signal DBG_ClockTX_1X												: std_logic_vector(PORTS - 1 downto 0);
		signal DBG_ClockTX_4X												: std_logic_vector(PORTS - 1 downto 0);

		signal DBG_GTP_RX_ByteIsAligned							: std_logic_vector(PORTS - 1 downto 0);
		signal DBG_GTP_RX_CharIsComma								: std_logic_vector(PORTS - 1 downto 0);
		signal DBG_GTP_RX_CharIsK										: std_logic_vector(PORTS - 1 downto 0);
		signal DBG_GTP_RX_Data											: T_SLVV_8(PORTS - 1 downto 0);
		signal DBG_GTP_TX_CharIsK										: std_logic_vector(PORTS - 1 downto 0);
		signal DBG_GTP_TX_Data											: T_SLVV_8(PORTS - 1 downto 0);

		signal DBG_RX_CharIsK												: T_SLVV_4(PORTS - 1 downto 0);
		signal DBG_RX_Data													: T_SLVV_32(PORTS - 1 downto 0);
		signal DBG_TX_CharIsK												: T_SLVV_4(PORTS - 1 downto 0);
		signal DBG_TX_Data													: T_SLVV_32(PORTS - 1 downto 0);

		signal DBG_OOBStatus_COMRESET								: std_logic_vector(PORTS - 1 downto 0);
		signal DBG_OOBStatus_COMWAKE								: std_logic_vector(PORTS - 1 downto 0);

		attribute KEEP of DBG_ClockTX_1X						: signal is TRUE;
		attribute KEEP of DBG_ClockTX_4X						: signal is TRUE;

		attribute KEEP of DBG_GTP_RX_ByteIsAligned	: signal is TRUE;
		attribute KEEP of DBG_GTP_RX_CharIsComma		: signal is TRUE;
		attribute KEEP of DBG_GTP_RX_CharIsK				: signal is TRUE;
		attribute KEEP of DBG_GTP_RX_Data						: signal is TRUE;
		attribute KEEP of DBG_GTP_TX_CharIsK				: signal is TRUE;
		attribute KEEP of DBG_GTP_TX_Data						: signal is TRUE;

		attribute KEEP of DBG_RX_CharIsK						: signal is TRUE;
		attribute KEEP of DBG_RX_Data								: signal is TRUE;
		attribute KEEP of DBG_TX_CharIsK						: signal is TRUE;
		attribute KEEP of DBG_TX_Data								: signal is TRUE;

		attribute KEEP of DBG_OOBStatus_COMRESET		: signal is TRUE;
		attribute KEEP of DBG_OOBStatus_COMWAKE			: signal is TRUE;
	begin
			loop0: for i in 0 to PORTS - 1 generate
				DBG_ClockTX_1X(I)						<= GTP_Clock_1X(I);
				DBG_ClockTX_4X(I)						<= GTP_Clock_4X(I);

				DBG_GTP_RX_ByteIsAligned(I)	<= GTP_RX_ByteIsAligned(I);
--				DBG_GTP_RX_CharIsComma(I)		<= GTP_RX_CharIsComma(I);
--				DBG_GTP_RX_CharIsK(I)				<= GTP_RX_CharIsK(I);
				DBG_GTP_RX_Data(I)					<= GTP_RX_Data(I)(DBG_GTP_RX_Data(I)'range);
--				DBG_GTP_TX_CharIsK(I)				<= GTP_TX_CharIsK(I);
				DBG_GTP_TX_Data(I)					<= GTP_TX_Data(I)(DBG_GTP_TX_Data(I)'range);

--				DBG_RX_CharIsK(I)						<= RX_CharIsK(I);
--				DBG_RX_Data(I)							<= RX_Data(I);
				DBG_TX_CharIsK(I)						<= TX_CharIsK(I);
				DBG_TX_Data(I)							<= TX_Data(I);

				DBG_OOBStatus_COMRESET(I)		<= to_sl(OOB_RX_Received_i(I) = SATA_OOB_COMRESET);
				DBG_OOBStatus_COMWAKE(I)		<= to_sl(OOB_RX_Received_i(I) = SATA_OOB_COMWAKE);
			end generate;
	end generate;


	-- debug port
	-- ==========================================================================================================================================================
--	DebugPortOut(0).RefClock		<= GTP_RefClockOut;
--	DebugPortOut(0).TXOutClock	<= GTP_TX_RefClockOut(0);
--	DebugPortOut(0).RXRecClock	<= GTP_RX_RefClockOut(0);
end;
