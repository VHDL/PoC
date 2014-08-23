-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Package:					TODO
--
-- Authors:					Patrick Lehmann
--
-- Description:
-- ------------------------------------
--		TODO
-- 
-- License:
-- =============================================================================
-- Copyright 2007-2014 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY UNISIM;
USE			UNISIM.VCOMPONENTS.ALL;

LIBRARY PoC;
--USE			PoC.config.ALL;
USE			PoC.components.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;
USE			PoC.sata_TransceiverTypes.ALL;
USE			PoC.xil.ALL;


ENTITY sata_Transceiver_Series7_GTXE2 IS
	GENERIC (
		DEBUG											: BOOLEAN											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: BOOLEAN											:= FALSE;																		-- enables the assignment of signals to the debugport
		CLOCK_IN_FREQ_MHZ					: REAL												:= 150.0;																		-- 150 MHz
		PORTS											: POSITIVE										:= 2;																				-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> C_SATA_GENERATION_MAX)				-- intial SATA Generation
	);
	PORT (
		Reset											: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		ResetDone									: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		ClockNetwork_Reset				: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		ClockNetwork_ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

		SATA_Clock								: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

		RP_Reconfig								: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		RP_SATAGeneration					: IN	T_SATA_GENERATION_VECTOR(PORTS	- 1 DOWNTO 0);
		RP_ReconfigComplete				: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		RP_ConfigReloaded					: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		RP_Lock										:	IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		RP_Locked									: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);

		OOB_HandshakingComplete		: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		
		PowerDown									: IN	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		Command										: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS	- 1 DOWNTO 0);
		Status										: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_Error									: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_Error									: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS	- 1 DOWNTO 0);

		DebugPortIn								: IN	T_SATADBG_TRANSCEIVERIN_VECTOR(PORTS	- 1 DOWNTO 0);
		DebugPortOut							: OUT	T_SATADBG_TRANSCEIVEROUT_VECTOR(PORTS	- 1 DOWNTO 0);

		TX_OOBCommand							: IN	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_OOBComplete						: OUT	STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		TX_Data										: IN	T_SLVV_32(PORTS	- 1 DOWNTO 0);
		TX_CharIsK								: IN	T_SLVV_4(PORTS	- 1 DOWNTO 0);

		RX_OOBStatus							: OUT	T_SATA_OOB_VECTOR(PORTS	- 1 DOWNTO 0);
		RX_Data										: OUT	T_SLVV_32(PORTS	- 1 DOWNTO 0);
		RX_CharIsK								: OUT	T_SLVV_4(PORTS	- 1 DOWNTO 0);
		RX_IsAligned							: OUT STD_LOGIC_VECTOR(PORTS	- 1 DOWNTO 0);
		
		-- vendor specific signals (Xilinx)
		VSS_Common_In							: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In						: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 DOWNTO 0);
		VSS_Private_Out						: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF sata_Transceiver_Series7_GTXE2 IS
	ATTRIBUTE KEEP 										: BOOLEAN;
	ATTRIBUTE ASYNC_REG								: STRING;
	ATTRIBUTE SHREG_EXTRACT						: STRING;

	-- ===========================================================================
	-- SATATransceiver configuration
	-- ===========================================================================
	CONSTANT INITIAL_SATA_GENERATIONS_I	: T_SATA_GENERATION_VECTOR(0 TO PORTS - 1)	:= INITIAL_SATA_GENERATIONS;
	
	CONSTANT NO_DEVICE_TIMEOUT_MS				: REAL																			:= 50.0;				-- 50 ms
	CONSTANT NEW_DEVICE_TIMEOUT_MS			: REAL																			:= 0.001;				-- FIXME: not used -> remove ???

--	CONSTANT C_DEVICE_INFO						: T_DEVICE_INFO		:= DEVICE_INFO;
	
	SIGNAL ClockIn_150MHz_BUFR				: STD_LOGIC;
	SIGNAL DD_Clock										: STD_LOGIC;
	SIGNAL Control_Clock							: STD_LOGIC;
	
	SIGNAL OOBClockGen_Value					: STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL OOB_Clock									: STD_LOGIC;
	
	FUNCTION to_ClockDividerSelection(gen : T_SATA_GENERATION) RETURN STD_LOGIC_VECTOR IS
	BEGIN
		CASE gen IS
			WHEN SATA_GENERATION_1 =>			RETURN "011";				-- **PLL Divider (D) = 4
			WHEN SATA_GENERATION_2 =>			RETURN "100";	--"010";				-- **PLL Divider (D) = 2
			WHEN SATA_GENERATION_3 =>			RETURN "001";				-- **PLL Divider (D) = 1
			WHEN OTHERS =>								RETURN "000";				-- **PLL Divider (D) = RXOUT_DIV
		END CASE;
	END FUNCTION;
	
BEGIN

-- ==================================================================
-- Assert statements
-- ==================================================================
--	ASSERT (C_DEVICE_INFO.VENDOR = VENDOR_XILINX)								REPORT "This is a vendor dependent component. Vendor must be Xilinx!"						SEVERITY FAILURE;
--	ASSERT (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTXE2)	REPORT "This is a GTXE2 wrapper component."																			SEVERITY FAILURE;
--	ASSERT (C_DEVICE_INFO.DEVICE = DEVICE_KINTEX7)							REPORT "Device " & DEVICE_T'image(C_DEVICE_INFO.DEVICE) & " not yet supported."	SEVERITY FAILURE;
	ASSERT (PORTS <= 4)																					REPORT "To many ports per transceiver."																					SEVERITY FAILURE;
	
	-- stable clock for device detection logics
	DD_Clock												<= VSS_Common_In.RefClockIn_150_MHz;
	Control_Clock										<= VSS_Common_In.RefClockIn_150_MHz;
	
	OOBClockGen : ENTITY PoC.arith_counter_ring
		GENERIC MAP (
			BITS							=> OOBClockGen_Value'length,
			INVERT_FEEDBACK		=> TRUE				-- TRUE -> johnson counter
		)
		PORT MAP (
			Clock							=> Control_Clock,
			Reset							=> '0',
			inc								=> '1',
			value							=> OOBClockGen_Value
		);
		
	OOB_Clock			<= '0';	--OOBClockGen_Value(OOBClockGen_Value'high);
		
	
--	==================================================================
-- data path buffers
--	==================================================================
	genGTXE2 : FOR I IN 0 TO (PORTS	- 1) GENERATE
		CONSTANT CLOCK_DIVIDER_SELECTION		:	STD_LOGIC_VECTOR(2 DOWNTO 0)		:= to_ClockDividerSelection(INITIAL_SATA_GENERATIONS_I(I));
		
		CONSTANT PCS_RSVD_ATTR							: BIT_VECTOR(47 DOWNTO 0)		:= (	--x"000000000140";	--(
			3 =>			'0',							-- select alternative OOB circuit clock source; 0 => sysclk; 1 => CLKRSVD(0)
			6 =>			'1',							-- reserved; set to '1'
			8 =>			'1',							-- power up OOB circuit
			OTHERS =>	'0'								-- not documented; set to "0..0" ?
		);
	
		-- ClockNetwork resets
		SIGNAL ClkNet_Reset									: STD_LOGIC;
		SIGNAL ClkNet_ResetDone							: STD_LOGIC;
		
		SIGNAL ResetDone_r									: STD_LOGIC							:= '0';
		
		-- Clock signals
		SIGNAL GTX_RefClockGlobal						: STD_LOGIC;
		SIGNAL GTX_RefClockNorth						: T_SLV_2;
		SIGNAL GTX_RefClock									: T_SLV_2;
		SIGNAL GTX_RefClockSouth						: T_SLV_2;
		SIGNAL GTX_QPLLClock								: STD_LOGIC;
		SIGNAL GTX_QPLLRefClock							: STD_LOGIC;
		
		SIGNAL GTX_CPLL_Locked_async				: STD_LOGIC;
		SIGNAL GTX_CPLL_Locked							: STD_LOGIC;
		SIGNAL GTX_TX_RefClockOut						: STD_LOGIC;
		SIGNAL GTX_RX_RefClockOut_float			: STD_LOGIC;
		SIGNAL GTX_RefClockOut							: STD_LOGIC;
		
		SIGNAL GTX_UserClock_Locked					: STD_LOGIC;
		SIGNAL GTX_UserClock								: STD_LOGIC;
		
		-- PowerDown signals
		SIGNAL GTX_CPLL_PowerDown						: STD_LOGIC;
		SIGNAL GTX_TX_PowerDown							: T_SLV_2;
		SIGNAL GTX_RX_PowerDown							: T_SLV_2;
		
		SIGNAL GTX_Reset										: STD_LOGIC;
		SIGNAL GTX_ResetDone								: STD_LOGIC;
		SIGNAL GTX_ResetDone_d							: STD_LOGIC							:= '0';
		SIGNAL GTX_ResetDone_re							: STD_LOGIC;
	
		-- CPLL resets
		SIGNAL GTX_CPLL_Reset								: STD_LOGIC;
		-- TX resets
		SIGNAL GTX_TX_Reset									: STD_LOGIC;
		SIGNAL GTX_TX_PCSReset							: STD_LOGIC;
		SIGNAL GTX_TX_PMAReset							: STD_LOGIC;
		-- RX resets
		SIGNAL GTX_RX_Reset									: STD_LOGIC;
		SIGNAL GTX_RX_PCSReset							: STD_LOGIC;
		SIGNAL GTX_RX_PMAReset							: STD_LOGIC;
		SIGNAL GTX_RX_BufferReset						: STD_LOGIC;
		
		SIGNAL GTX_TX_ResetDone							: STD_LOGIC;
		SIGNAL GTX_RX_ResetDone							: STD_LOGIC;
		
		-- linerate clock divider selection
		-- =====================================================================
		SIGNAL RP_Reconfig_d								: STD_LOGIC						:= '0';
		
		SIGNAL GTX_TX_LineRateSelect				: STD_LOGIC_VECTOR(2 DOWNTO 0)		:= CLOCK_DIVIDER_SELECTION;
		SIGNAL GTX_RX_LineRateSelect				: STD_LOGIC_VECTOR(2 DOWNTO 0)		:= CLOCK_DIVIDER_SELECTION;
		
		SIGNAL GTX_TX_LineRateSelectDone		: STD_LOGIC;
		SIGNAL GTX_RX_LineRateSelectDone		: STD_LOGIC;
		
		SIGNAL GTX_DRP_Clock								: STD_LOGIC;
		SIGNAL GTX_DRP_en										: STD_LOGIC;
		SIGNAL GTX_DRP_we										: STD_LOGIC;
		SIGNAL GTX_DRP_Address							: STD_LOGIC_VECTOR(8 DOWNTO 0);
		SIGNAL GTX_DRP_DataIn								: T_XIL_DRP_DATA;
		SIGNAL GTX_DRP_DataOut							: T_XIL_DRP_DATA;
		SIGNAL GTX_DRP_Ready								: STD_LOGIC;
		
		SIGNAL GTX_PhyStatus								: STD_LOGIC;
		SIGNAL GTX_TX_BufferStatus					: STD_LOGIC_VECTOR(1 DOWNTO 0);
		SIGNAL GTX_RX_BufferStatus					: STD_LOGIC_VECTOR(2 DOWNTO 0);
		SIGNAL GTX_RX_Status								: STD_LOGIC_VECTOR(2 DOWNTO 0);
		SIGNAL GTX_RX_ClockCorrectionStatus	: STD_LOGIC_VECTOR(1 DOWNTO 0);
		
		SIGNAL GTX_TX_ElectricalIDLE				: STD_LOGIC;
		SIGNAL GTX_RX_ElectricalIDLE				: STD_LOGIC;
		SIGNAL GTX_RX_ElectricalIDLE_a	: STD_LOGIC;
		
		SIGNAL GTX_TX_ComInit								: STD_LOGIC;
		SIGNAL GTX_TX_ComWake								: STD_LOGIC;
		SIGNAL GTX_TX_ComSAS								: STD_LOGIC;
		SIGNAL GTX_TX_ComFinish							: STD_LOGIC;
		
		SIGNAL GTX_TX_ComInit_r							: STD_LOGIC					:= '0';
		SIGNAL GTX_TX_ComInit_d							: STD_LOGIC_VECTOR(11 DOWNTO 0)	:= (OTHERS => '0');
		SIGNAL GTX_TX_ComWake_r							: STD_LOGIC					:= '0';
		SIGNAL GTX_TX_ComSAS_r							: STD_LOGIC					:= '0';
		
		SIGNAL GTX_RX_ComInitDetected				: STD_LOGIC;
		SIGNAL GTX_RX_ComWakeDetected				: STD_LOGIC;
		SIGNAL GTX_RX_ComSASDetected_float	: STD_LOGIC;
		
		SIGNAL TX_OOBCommand_d							: T_SATA_OOB;
		SIGNAL RX_OOBStatus_i								: T_SATA_OOB;
		
		SIGNAL TX_RateChangeDone						: STD_LOGIC;
		SIGNAL RX_RateChangeDone						: STD_LOGIC;
		SIGNAL RateChangeDone								: STD_LOGIC;
		SIGNAL RateChangeDone_d							: STD_LOGIC					:= '0';
		SIGNAL RateChangeDone_re						: STD_LOGIC;
		
		SIGNAL GTX_TX_Data									: T_SLV_32;
		SIGNAL GTX_TX_CharIsK								: T_SLV_4;
		
		SIGNAL GTX_RX_Data									: T_SLV_32;
		SIGNAL GTX_RX_Data_float						: T_SLV_32;																-- open
		SIGNAL GTX_RX_CommaDetected					: STD_LOGIC;															-- unused
		SIGNAL GTX_RX_CharIsComma						: T_SLV_4;																-- unused
		SIGNAL GTX_RX_CharIsComma_float			: T_SLV_4;																-- open
		SIGNAL GTX_RX_CharIsK								: T_SLV_4;
		SIGNAL GTX_RX_CharIsK_float					: T_SLV_4;																-- open
		SIGNAL GTX_RX_DisparityError				: T_SLV_4;																-- unused
		SIGNAL GTX_RX_DisparityError_float	: T_SLV_4;																-- open
		SIGNAL GTX_RX_NotInTableError				: T_SLV_4;																-- unused
		SIGNAL GTX_RX_NotInTableError_float	: T_SLV_4;																-- open
		SIGNAL GTX_RX_ByteIsAligned					: STD_LOGIC;
		SIGNAL GTX_RX_ByteRealign						: STD_LOGIC;															-- unused
		SIGNAL GTX_RX_Valid									: STD_LOGIC;															-- unused
		
		SIGNAL GTX_TX_n											: STD_LOGIC;
		SIGNAL GTX_TX_p											: STD_LOGIC;
		SIGNAL GTX_RX_n											: STD_LOGIC;
		SIGNAL GTX_RX_p											: STD_LOGIC;
		
		SIGNAL DD_NoDevice_i								: STD_LOGIC;
		SIGNAL DD_NoDevice									: STD_LOGIC;
		SIGNAL DD_NewDevice									: STD_LOGIC;
		
		SIGNAL Status_i											: T_SATA_TRANSCEIVER_STATUS;
		SIGNAL TX_Error_i										: T_SATA_TRANSCEIVER_TX_ERROR;
		SIGNAL RX_Error_i										: T_SATA_TRANSCEIVER_RX_ERROR;
		
		-- keep internal clock nets, so timing constrains from UCF can find them
--		ATTRIBUTE KEEP OF GTX_Clock_2X						: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF GTX_Clock_4X						: SIGNAL IS TRUE;
		
--		ATTRIBUTE KEEP OF GTX_RX_ByteIsAligned		: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF GTX_RX_CharIsComma			: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF GTX_RX_CharIsK					: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF GTX_RX_Data							: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF GTX_RX_BufferStatus			: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF GTX_TX_CharIsK					: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF GTX_TX_Data							: SIGNAL IS TRUE;
--		ATTRIBUTE KEEP OF GTX_TX_OOBComplete			: SIGNAL IS TRUE;
		
		SIGNAL TestReset							: STD_LOGIC;
		SIGNAL TestRateSelection			: STD_LOGIC;
		SIGNAL DelayChain							: T_SLV_16			:= (OTHERS => '0');
		SIGNAL DelayChain2						: T_SLV_16			:= (OTHERS => '0');
		
	BEGIN
		ASSERT FALSE REPORT "Port:    " & INTEGER'image(I)																											SEVERITY NOTE;
		ASSERT FALSE REPORT "  Init. SATA Generation:  Gen" & INTEGER'image(INITIAL_SATA_GENERATIONS_I(I) + 1)	SEVERITY NOTE;
		ASSERT FALSE REPORT "  ClockDivider:           " & to_string(CLOCK_DIVIDER_SELECTION, 'b')							SEVERITY NOTE;
	
		ASSERT ((RP_SATAGeneration(I) = SATA_GENERATION_1) OR
						(RP_SATAGeneration(I) = SATA_GENERATION_2) OR
						(RP_SATAGeneration(I) = SATA_GENERATION_3))		REPORT "unsupported SATA generation"							SEVERITY FAILURE;
	
		-- clock signals
		GTX_QPLLRefClock							<= '0';
		GTX_QPLLClock									<= '0';
		GTX_RefClockGlobal						<= VSS_Common_In.RefClockIn_150_MHz;
		GTX_RefClockNorth							<= "00";
		GTX_RefClockSouth							<= "00";
		GTX_RefClock									<= "00";
		
		
		BUFG_RefClockOut : BUFG
			PORT MAP (
				I						=> GTX_TX_RefClockOut,
				O						=> GTX_RefClockOut
			);

		GTX_DRP_Clock									<= '0';

		GTX_UserClock_Locked					<= GTX_CPLL_Locked;
		GTX_UserClock									<= GTX_RefClockOut;
		SATA_Clock(I)									<= GTX_RefClockOut;

		-- =========================================================================
		-- PowerDown control
		-- =========================================================================
		GTX_CPLL_PowerDown						<= PowerDown(I);
		GTX_TX_PowerDown							<= PowerDown(I) & PowerDown(I);
		GTX_RX_PowerDown							<= PowerDown(I) & PowerDown(I);

		-- =========================================================================
		-- Reset control
		-- =========================================================================
		ClkNet_Reset									<= ClockNetwork_Reset(I);
		ClkNet_ResetDone							<= GTX_CPLL_Locked_async AND GTX_TX_ResetDone;				-- @
		ClockNetwork_ResetDone(I)			<= ClkNet_ResetDone;																	-- @
		
		-- ResetDone calculations
		GTX_Reset											<= to_sl(Command(I)	= SATA_TRANSCEIVER_CMD_RESET) OR Reset(I) OR TestReset;
		GTX_ResetDone									<= GTX_TX_ResetDone AND GTX_RX_ResetDone;
		GTX_ResetDone_d								<= GTX_ResetDone WHEN rising_edge(GTX_UserClock);
		GTX_ResetDone_re							<= NOT GTX_ResetDone_d AND GTX_ResetDone;
		ResetDone_r										<= ffrs(q => ResetDone_r, rst => (GTX_Reset OR NOT GTX_CPLL_Locked), set => GTX_ResetDone_re) WHEN rising_edge(GTX_UserClock);
		ResetDone(I)									<= ResetDone_r;
		
		-- CPLL resets
		GTX_CPLL_Reset								<= ClkNet_Reset;
		-- TX resets					
		GTX_TX_Reset									<= (NOT GTX_CPLL_Locked_async) OR GTX_Reset;
		GTX_TX_PCSReset								<= '0';
		GTX_TX_PMAReset								<= '0';
		-- RX resets					
		GTX_RX_Reset									<= (NOT GTX_CPLL_Locked_async) OR GTX_Reset;
		GTX_RX_PCSReset								<= '0';
		GTX_RX_PMAReset								<= '0';
		GTX_RX_BufferReset						<= '0';

		DelayChain	<= DelayChain(DelayChain'high - 1 DOWNTO 0)			& GTX_ResetDone		WHEN rising_edge(GTX_UserClock);
		DelayChain2	<= DelayChain2(DelayChain2'high - 1 DOWNTO 0)		& RateChangeDone	WHEN rising_edge(GTX_UserClock);
		
		TestRateSelection	<= '0';	--NOT DelayChain(DelayChain'high - 1)		AND DelayChain(DelayChain'high);
		TestReset					<= '0';	--NOT DelayChain2(DelayChain2'high - 1)	AND DelayChain2(DelayChain2'high);
		
		-- =========================================================================
		-- LineRate control / linerate clock divider selection / reconfiguration port
		-- =========================================================================
		GTX_DRP_en										<= '0';
		GTX_DRP_we										<= '0';
		GTX_DRP_Address								<= "000000000";
		GTX_DRP_DataIn								<= x"0000";
		--	<float>										<= GTX_DRP_DataOut;
		--	<float>										<= GTX_DRP_Ready;

--		PROCESS(GTX_UserClock)
--		BEGIN
--			IF rising_edge(GTX_UserClock) THEN
--				IF (Reset(I) ...
--					to_ClockDividerSelection(INITIAL_SATA_GENERATIONS_I(I));
--				IF (RP_Reconfig(I)	= '1') THEN	-- OR (TestRateSelection = '1') THEN
--					GTX_TX_LineRateSelect		<= to_ClockDividerSelection(RP_SATAGeneration(I));
--					GTX_RX_LineRateSelect		<= to_ClockDividerSelection(RP_SATAGeneration(I));
--				END IF;
--			END IF;
--		END PROCESS;
		
		GTX_TX_LineRateSelect	<= "000";
		GTX_RX_LineRateSelect	<= "000";
		
		-- RS-FF															Q											rst															set																	clk
		TX_RateChangeDone <= ffrs(q => TX_RateChangeDone, rst => RP_Reconfig(I), set => GTX_TX_LineRateSelectDone) WHEN rising_edge(GTX_UserClock);
		RX_RateChangeDone <= ffrs(q => RX_RateChangeDone, rst => RP_Reconfig(I), set => GTX_RX_LineRateSelectDone) WHEN rising_edge(GTX_UserClock);
		
		RateChangeDone		<= TX_RateChangeDone AND RX_RateChangeDone;
		RateChangeDone_d	<= RateChangeDone WHEN rising_edge(GTX_UserClock);
		RateChangeDone_re	<= NOT RateChangeDone_d AND RateChangeDone;
		
		-- reconfiguration port
		RP_Locked(I)									<= '0';																							-- all ports are independant	=> never set a lock
		RP_Reconfig_d									<= RP_Reconfig(I) WHEN rising_edge(GTX_UserClock);	-- delay reconfiguration command
		RP_ReconfigComplete(I)				<= RP_Reconfig_d;																		-- acknoledge reconfiguration with 1 cycle latency
		RP_ConfigReloaded(I)					<= RateChangeDone_re;																-- acknoledge reload

		-- ==================================================================
		-- Data path / status / error detection
		-- ==================================================================
		-- TX path
		GTX_TX_Data							<= TX_Data(I);
		GTX_TX_CharIsK					<= TX_CharIsK(I);

		-- RX path
		RX_Data(I)							<= GTX_RX_Data;
		RX_CharIsK(I)						<= GTX_RX_CharIsK;
		RX_IsAligned(I)					<= GTX_RX_ByteIsAligned;

--		GTX_PhyStatus
--		GTX_TX_BufferStatus
--		GTX_RX_BufferStatus
--		GTX_RX_Status
--		GTX_RX_ClockCorrectionStatus

		sync1_RXUserClock : ENTITY PoC.xil_SyncBlock
			GENERIC MAP (
				BITS					=> 3															-- number of BITS to synchronize
			)
			PORT MAP (
				Clock					=> GTX_UserClock,									-- Clock to be synchronized to
				DataIn(0)			=> GTX_CPLL_Locked_async,					-- Data to be synchronized
				DataIn(1)			=> GTX_RX_ElectricalIDLE_a,		-- 
				DataIn(2)			=> DD_NoDevice_i,									-- 
				
				DataOut(0)		=> GTX_CPLL_Locked,								-- synchronised data
				DataOut(1)		=> GTX_RX_ElectricalIDLE,					-- 
				DataOut(2)		=> DD_NoDevice										-- 
			);

		--	==================================================================
		-- OOB signaling
		--	==================================================================
--		TX_OOBCommand_d						<= TX_OOBCommand(I) WHEN DebugPortIn(I).ForceOOBCommand = SATA_OOB_NONE ELSE DebugPortIn(I).ForceOOBCommand;	-- WHEN rising_edge(GTX_ClockTX_2X(I));
		TX_OOBCommand_d						<= DebugPortIn(I).ForceOOBCommand;	-- WHEN TestRateSelection = '0' ELSE SATA_OOB_COMRESET;


		GTX_TX_ElectricalIDLE			<= DebugPortIn(I).ForceTXElectricalIdle;

		-- TX OOB signals (generate GTX specific OOB signals)
--		PROCESS(TX_OOBCommand_d, PowerDown(I))
--		BEGIN
--			GTX_TX_ElectricalIDLE		<= PowerDown(I);
--			GTX_TX_ComInit					<= '0';
--			GTX_TX_ComWake					<= '0';
--			GTX_TX_ComSAS						<= '0';
		
--			CASE TX_OOBCommand_d IS
--				WHEN SATA_OOB_NONE =>				NULL;
--				WHEN SATA_OOB_COMRESET =>		GTX_TX_ComInit	<= '1';
--				WHEN SATA_OOB_COMWAKE	=>		GTX_TX_ComWake	<= '1';
--				WHEN SATA_OOB_COMSAS =>			GTX_TX_ComSAS		<= '1';
--				WHEN OTHERS =>							NULL;
--			END CASE;
--		END PROCESS;
	
		GTX_TX_ComInit_r	<= ffrs(q => GTX_TX_ComInit_r,	rst => GTX_TX_ComFinish, set => to_sl(TX_OOBCommand_d = SATA_OOB_COMRESET))	WHEN rising_edge(GTX_UserClock);
		GTX_TX_ComWake_r	<= ffrs(q => GTX_TX_ComWake_r,	rst => GTX_TX_ComFinish, set => to_sl(TX_OOBCommand_d = SATA_OOB_COMWAKE))	WHEN rising_edge(GTX_UserClock);
		GTX_TX_ComSAS_r		<= '0';	--ffrs(q => GTX_TX_ComSAS_r,		rst => GTX_TX_ComFinish, set => to_sl(TX_OOBCommand_d = SATA_OOB_COMSAS))		WHEN rising_edge(GTX_UserClock);
	
		PROCESS(GTX_UserClock)
		BEGIN
			IF rising_edge(GTX_UserClock) then
				if (TX_OOBCommand_d = SATA_OOB_COMRESET) then
					GTX_TX_ComInit_d		<= (others => '1');
				else
					GTX_TX_ComInit_d		<= GTX_TX_ComInit_d(GTX_TX_ComInit_d'high - 1 downto 0) & '0';
				end if;
			end if;
		END PROCESS;
	
		GTX_TX_ComInit		<= to_sl(TX_OOBCommand_d = SATA_OOB_COMRESET);	--GTX_TX_ComInit_d(GTX_TX_ComInit_d'high);	-- GTX_TX_ComInit_r;
		GTX_TX_ComWake		<= to_sl(TX_OOBCommand_d = SATA_OOB_COMWAKE);	--GTX_TX_ComWake_r;
		GTX_TX_ComSAS			<= GTX_TX_ComSAS_r;
	
	
		-- TX OOB sequence is complete
		TX_OOBComplete(I)						<= GTX_TX_ComFinish;

		-- RX OOB signals (generate generic RX OOB status signals)
		PROCESS(GTX_RX_ComInitDetected, GTX_RX_ComWakeDetected, GTX_RX_ElectricalIDLE)
		BEGIN
			RX_OOBStatus_i		 				<= SATA_OOB_NONE;
		
			IF (GTX_RX_ElectricalIDLE	= '1') THEN
				RX_OOBStatus_i					<= SATA_OOB_READY;
			
				IF (GTX_RX_ComInitDetected	= '1') THEN
					RX_OOBStatus_i				<= SATA_OOB_COMRESET;
				ELSIF (GTX_RX_ComWakeDetected	= '1') THEN
					RX_OOBStatus_i				<= SATA_OOB_COMWAKE;
				END IF;
			END IF;
		END PROCESS;

		--RX_OOBStatus_d		<= RX_OOBStatus_i;		-- WHEN rising_edge(SATA_Clock_i(I));
		RX_OOBStatus(I)		<= RX_OOBStatus_i;

		--	==================================================================
		-- error handling
		--	==================================================================
		-- TX errors
		PROCESS(GTX_TX_BufferStatus(1))
		BEGIN
			TX_Error_i		<= SATA_TRANSCEIVER_TX_ERROR_NONE;
		
--			IF (slv_or(GTX_TX_InvalidK)	= '1') THEN
--				TX_Error_i	<= SATA_TRANSCEIVER_TX_ERROR_ENCODER;
--			ELS
			IF (GTX_TX_BufferStatus(1)	= '1') THEN
				TX_Error_i	<= SATA_TRANSCEIVER_TX_ERROR_BUFFER;
			END IF;
		END PROCESS;
		
		-- RX errors
		PROCESS(GTX_RX_ByteIsAligned, GTX_RX_DisparityError, GTX_RX_NotInTableError, GTX_RX_BufferStatus(2))
		BEGIN
			RX_Error_i		<= SATA_TRANSCEIVER_RX_ERROR_NONE;
		
			IF (GTX_RX_ByteIsAligned	= '0') THEN
				RX_Error_i	<= SATA_TRANSCEIVER_RX_ERROR_ALIGNEMENT;
			ELSIF (slv_or(GTX_RX_DisparityError)	= '1') THEN
				RX_Error_i	<= SATA_TRANSCEIVER_RX_ERROR_DISPARITY;
			ELSIF (slv_or(GTX_RX_NotInTableError)	= '1') THEN
				RX_Error_i	<= SATA_TRANSCEIVER_RX_ERROR_DECODER;
			ELSIF (GTX_RX_BufferStatus(2)	= '1') THEN
				RX_Error_i	<= SATA_TRANSCEIVER_RX_ERROR_BUFFER;
			END IF;
		END PROCESS;

		--	==================================================================
		-- Transceiver status
		--	==================================================================
		-- device detection
		blkDeviceDetector : BLOCK
			SIGNAL ElectricalIDLE_async				: STD_LOGIC									:= '0';	
			SIGNAL ElectricalIDLE_sync				: STD_LOGIC									:= '0';	
			
			-- Mark register "Serial***_async" as asynchronous
			ATTRIBUTE ASYNC_REG OF ElectricalIDLE_async			: SIGNAL IS "TRUE";
			
			-- Prevent XST from translating two FFs into SRL plus FF
			ATTRIBUTE SHREG_EXTRACT OF ElectricalIDLE_async	: SIGNAL IS "NO";
			ATTRIBUTE SHREG_EXTRACT OF ElectricalIDLE_sync	: SIGNAL IS "NO";

			SIGNAL NoDevice_d									: STD_LOGIC		:= '0';
			SIGNAL NoDevice_fe								: STD_LOGIC;
		BEGIN
			-- synchronize ElectricalIDLE to working clock domain
			ElectricalIDLE_async	<= GTX_RX_ElectricalIDLE_a		WHEN rising_edge(DD_Clock);
			ElectricalIDLE_sync		<= ElectricalIDLE_async				WHEN rising_edge(DD_Clock);
			
			GF : ENTITY PoC.io_GlitchFilter
				GENERIC MAP (
					CLOCK_FREQ_MHZ										=> CLOCK_IN_FREQ_MHZ,
					HIGH_SPIKE_SUPPRESSION_TIME_NS		=> NEW_DEVICE_TIMEOUT_MS * 1000.0 * 1000.0,
					LOW_SPIKE_SUPPRESSION_TIME_NS			=> NO_DEVICE_TIMEOUT_MS * 1000.0 * 1000.0
				)
				PORT MAP (
					Clock		=> DD_Clock,
					I				=> ElectricalIDLE_sync,
					O				=> DD_NoDevice_i
				);
			
			NoDevice_d		<= DD_NoDevice WHEN rising_edge(GTX_UserClock);
			NoDevice_fe		<= NoDevice_d AND NOT DD_NoDevice;
			DD_NewDevice	<= NoDevice_fe;
		END BLOCK;

		PROCESS(DD_NoDevice, DD_NewDevice, TX_Error_i, RX_Error_i)	-- GTX_ResetDone, 
		BEGIN
			Status_i	 							<= SATA_TRANSCEIVER_STATUS_READY;
			
--			IF (GTX_ResetDone	= '0') THEN
--				Status_i							<= SATA_TRANSCEIVER_STATUS_RESET;
--			ELS
			IF (DD_NoDevice	= '1') THEN
				Status_i							<= SATA_TRANSCEIVER_STATUS_NO_DEVICE;
			ELSIF ((TX_Error_i /= SATA_TRANSCEIVER_TX_ERROR_NONE) OR (RX_Error_i /= SATA_TRANSCEIVER_RX_ERROR_NONE)) THEN
				Status_i							<= SATA_TRANSCEIVER_STATUS_ERROR;
			ELSIF (DD_NewDevice	= '1') THEN
				Status_i							<= SATA_TRANSCEIVER_STATUS_NEW_DEVICE;
				
-- TODO:
-- TRANS_STATUS_POWERED_DOWN,
-- TRANS_STATUS_CONFIGURATION,

			END IF;
		END PROCESS;
	
		Status(I)				<= Status_i;
		TX_Error(I)			<= TX_Error_i;
		RX_Error(I)			<= RX_Error_i;

		-- ==================================================================
		-- GTXE2_CHANNEL instance for Port I
		-- ==================================================================
		GTX : GTXE2_CHANNEL
			GENERIC MAP (
				-- Simulation-Only attributes
				SIM_RECEIVER_DETECT_PASS								=> "TRUE",
				SIM_RESET_SPEEDUP												=> "TRUE",										-- set to "TRUE" to speed up simulation reset
				SIM_TX_EIDLE_DRIVE_LEVEL								=> "X",                     
				SIM_VERSION															=> "4.0",                   
				SIM_CPLLREFCLK_SEL											=> "111",											-- GTGREFCLK (GTX_RefClockGlobal) is used
                                                                            
				-- Channel PLL clock attributes																				-- A reference input clock of 150 MHz,
				CPLL_REFCLK_DIV													=> 1,													--	divided by 1,
				CPLL_FBDIV															=> 4,													--	multiplied by 20
				CPLL_FBDIV_45														=> 5,													--	=> f_VCO = 3,000 MHz, which is in range of 1,600..3,300 MHz
				CPLL_CFG																=> x"BC07DC",									-- 
				CPLL_INIT_CFG														=> x"00001E",									-- reserved; CPLLRESET_TIME: 0x01E; Represents the time duration to apply internal CPLL reset.
				CPLL_LOCK_CFG														=> x"01E8",										-- 
				SATA_CPLL_CFG														=> "VCO_750MHZ",							-- 
				RXOUT_DIV																=> 4,													-- 
				TXOUT_DIV																=> 4,													-- 
                                                                            
				TX_XCLK_SEL															=> "TXOUT",                 
				RX_XCLK_SEL															=> "RXREC",                 
                                                                            
				TX_CLK25_DIV														=> 6,													-- Clock divider for TX internal working clock?
				RX_CLK25_DIV														=> 6,													-- Clock divider for RX internal working clock?
				OUTREFCLK_SEL_INV												=> "11",											-- Select signal for GTREFCLKMONITOR output. 0 => Non-inverted GTREFCLKMONITOR output; 1 => Inverted GTREFCLKMONITOR output

				-- Power-Down attributes
				RX_CLKMUX_PD														=> '1',												-- TODO: is this low-active?
				TX_CLKMUX_PD														=> '1',												-- TODO: is this low-active?
				PD_TRANS_TIME_FROM_P2										=> x"03c",
				PD_TRANS_TIME_NONE_P2										=> x"3c",
				PD_TRANS_TIME_TO_P2											=> x"64",
				
				-- RX initialization and reset attributes
				TXPCSRESET_TIME													=> "00001",										-- reserved; represents the time duration to apply a TX PCS reset
				TXPMARESET_TIME													=> "00001",										-- reserved; represents the time duration to apply a TX PMA reset
	
				RXCDRFREQRESET_TIME											=> "00001",										-- reserved; represents the time duration to apply the RX CDRFREQ reset
				RXCDRPHRESET_TIME												=> "00001",										-- reserved; represents the time duration to apply RX CDR Phase reset
				RXISCANRESET_TIME												=> "00001",										-- reserved; represents the time duration to apply the RX EYESCAN reset
				RXPMARESET_TIME													=> "00011",										-- reserved; represents the time duration to apply a RX PMA reset
				RXPCSRESET_TIME													=> "00001",										-- reserved; represents the time duration to apply a RX PCS reset
				RXDFELPMRESET_TIME											=> "0001111",									-- reserved; represents the time duration to apply the RX DFE reset
				RXBUFRESET_TIME													=> "00001",										-- reserved; represents the time duration to apply the RX BUFFER reset
				
				-- TX buffer attributes
				TX_DATA_WIDTH														=> 40,
				TX_INT_DATAWIDTH												=> 1,
				TXBUF_EN																=> "TRUE",
				TXBUF_RESET_ON_RATE_CHANGE							=> "TRUE",
				TXPH_CFG																=> x"0780",
				TXPHDLY_CFG															=> x"084020",
				TXPH_MONITOR_SEL												=> "00000",
				TXDLY_CFG																=> x"001F",
				TXDLY_LCFG															=> x"030",
				TXDLY_TAP_CFG														=> x"0000",

				RX_DATA_WIDTH														=> 40,
				RX_INT_DATAWIDTH												=> 1,
				RXBUF_EN																=> "TRUE",
				RX_BUFFER_CFG														=> "000000",
				RXBUF_RESET_ON_CB_CHANGE								=> "TRUE",
				RXBUF_RESET_ON_COMMAALIGN								=> "FALSE",
				RXBUF_RESET_ON_EIDLE										=> "FALSE",
				RXBUF_RESET_ON_RATE_CHANGE							=> "TRUE",
				RXBUF_THRESH_OVFLW											=> 61,
				RXBUF_THRESH_OVRD												=> "FALSE",
				RXBUF_THRESH_UNDFLW											=> 4,
				RXBUF_ADDR_MODE													=> "FULL",
				RXBUF_EIDLE_LO_CNT											=> "0000",
				RXBUF_EIDLE_HI_CNT											=> "1000",
				RXPHDLY_CFG															=> x"084020",
				RXPH_CFG																=> x"000000",
				RXPH_MONITOR_SEL												=> "00000",
				RXDLY_CFG																=> x"001F",
				RXDLY_LCFG															=> x"030",
				RXDLY_TAP_CFG														=> x"0000",
				RX_DDI_SEL															=> "000000",
				RX_DEFER_RESET_BUF_EN										=> "TRUE",
				
				-- RX byte and word alignment attributes
				ALIGN_COMMA_DOUBLE											=> "FALSE",
				ALIGN_COMMA_ENABLE											=> "1111111111",
				ALIGN_COMMA_WORD												=> 4,													-- Align comma-byte => [byte3][byte2][byte1][comma0]
				ALIGN_MCOMMA_DET												=> "TRUE",
				ALIGN_MCOMMA_VALUE											=> "1010000011",
				ALIGN_PCOMMA_DET												=> "TRUE",
				ALIGN_PCOMMA_VALUE											=> "0101111100",
				SHOW_REALIGN_COMMA											=> "TRUE",										-- pass commas to RX Buffer - needed by SATA protocol
				RXSLIDE_AUTO_WAIT												=> 7,
				RXSLIDE_MODE														=> "OFF",
				RX_SIG_VALID_DLY												=> 10,

				-- RX 8B/10B decoder attributes
				RX_DISPERR_SEQ_MATCH										=> "TRUE",
				DEC_MCOMMA_DETECT												=> "TRUE",
				DEC_PCOMMA_DETECT												=> "TRUE",
				DEC_VALID_COMMA_ONLY										=> "FALSE",

				-- RX clock correction attributes
				CLK_CORRECT_USE													=> "TRUE",
				CBCC_DATA_SOURCE_SEL										=> "DECODED",									-- search clock correction sequence in decoded data stream (data + k-indicator, independent of disparity)
				CLK_COR_KEEP_IDLE												=> "FALSE",
				CLK_COR_MIN_LAT													=> 24,												-- 3..60, divisible by 4
				CLK_COR_MAX_LAT													=> 31,												-- 3..60
				CLK_COR_PRECEDENCE											=> "TRUE",
				CLK_COR_REPEAT_WAIT											=> 0,
				CLK_COR_SEQ_LEN													=> 4,
				CLK_COR_SEQ_1_ENABLE										=> "1111",
				CLK_COR_SEQ_1_1													=> "0110111100",
				CLK_COR_SEQ_1_2													=> "0001001010",
				CLK_COR_SEQ_1_3													=> "0001001010",
				CLK_COR_SEQ_1_4													=> "0001111011",
				CLK_COR_SEQ_2_USE												=> "FALSE",
				CLK_COR_SEQ_2_ENABLE										=> "1111",
				CLK_COR_SEQ_2_1													=> "0000000000",
				CLK_COR_SEQ_2_2													=> "0000000000",
				CLK_COR_SEQ_2_3													=> "0000000000",
				CLK_COR_SEQ_2_4													=> "0000000000",

				-- RX channel bonding attributes
				CHAN_BOND_KEEP_ALIGN										=> "FALSE",
				CHAN_BOND_MAX_SKEW											=> 1,
				CHAN_BOND_SEQ_LEN												=> 1,
				CHAN_BOND_SEQ_1_ENABLE									=> "0000",
				CHAN_BOND_SEQ_1_1												=> "0000000000",
				CHAN_BOND_SEQ_1_2												=> "0000000000",
				CHAN_BOND_SEQ_1_3												=> "0000000000",
				CHAN_BOND_SEQ_1_4												=> "0000000000",
				CHAN_BOND_SEQ_2_USE											=> "FALSE",
				CHAN_BOND_SEQ_2_ENABLE									=> "0000",
				CHAN_BOND_SEQ_2_1												=> "0000000000",
				CHAN_BOND_SEQ_2_2												=> "0000000000",
				CHAN_BOND_SEQ_2_3												=> "0000000000",
				CHAN_BOND_SEQ_2_4												=> "0000000000",
				FTS_DESKEW_SEQ_ENABLE										=> "1111",
				FTS_LANE_DESKEW_CFG											=> "1111",
				FTS_LANE_DESKEW_EN											=> "FALSE",

				-- RX margin analysis attributes
				ES_EYE_SCAN_EN													=> "FALSE",
				ES_ERRDET_EN														=> "FALSE",
				ES_CONTROL															=> "000000",
				ES_HORZ_OFFSET													=> x"000",
				ES_PMA_CFG															=> "0000000000",
				ES_PRESCALE															=> "00000",
				ES_QUALIFIER														=> x"00000000000000000000",
				ES_QUAL_MASK														=> x"00000000000000000000",
				ES_SDATA_MASK														=> x"00000000000000000000",
				ES_VERT_OFFSET													=> "000000000",

				-- RX OOB signaling attributes
				RXOOB_CFG																=> "0000110",							-- OOB block configuration. The default value is "0000110" - maybe this is the former OOB_CLKDIV -> 150 MHz / 6 => 25 MHz OOB_Clock
				SATA_BURST_SEQ_LEN											=> "0110",

				SATA_BURST_VAL													=> "011",	--"100",
				SATA_EIDLE_VAL													=> "011",	--"100",
				SATA_MIN_BURST													=> 4,
				SATA_MAX_BURST													=> 7,
				SATA_MIN_INIT														=> 12,
				SATA_MAX_INIT														=> 22,
				SATA_MIN_WAKE														=> 4,
				SATA_MAX_WAKE														=> 7,
				SAS_MAX_COM															=> 64,
				SAS_MIN_COM															=> 36,
				
				-- PMA attributes
				PMA_RSV																	=> x"00018480",						-- reserved; These bits relate to RXPI and are line rate dependent:
																																					--	0x00018480 => Lower line rates: CPLL full range and 6 GHz = QPLL VCO rate < 6.6 GHz
																																					--	0x001E7080 => Higher line rates: QPLL > 6.6 GHz
				PMA_RSV2																=> x"2050",								-- PMA_RSV2(5) = 0; set to '1' if eye-scan circuit should be powered-up
				PMA_RSV3																=> "00",
				PMA_RSV4																=> x"00000000",
				RX_BIAS_CFG															=> "000000000100",
				DMONITOR_CFG														=> x"000A00",
				RX_CM_SEL																=> "11",	--"01",									-- RX termination voltage: 00 => AVTT; 01 => GND; 10 => Floating; 11 => programmable (PMA_RSV(4) & RX_CM_TRIM)
				RX_CM_TRIM															=> "011",	--"010",								-- RX termination voltage: 1010 => 800 mV; 1011 => 850 mV; bit 3 is encoded in PMA_RSV2(4)
				RX_DEBUG_CFG														=> "000000000000",
				RX_OS_CFG																=> "0000010000000",
				TERM_RCAL_CFG														=> "10000",								-- Controls the internal termination calibration circuit. This feature is intended for internal testing purposes only.
				TERM_RCAL_OVRD													=> '0',										-- Selects whether the external 100Ω precision resistor is connected to the MGTRREF pin or a value defined by TERM_RCAL_CFG [4:0]. This feature is intended for internal testing purposes only.
				TST_RSV																	=> x"00000000",
				UCODEER_CLR															=> '0',

				-- PCS attributes
				PCS_PCIE_EN															=> "FALSE",


				PCS_RSVD_ATTR														=> PCS_RSVD_ATTR,					-- 

				-- CDR attributes
				--For GTX only: Display Port, HBR/RBR- set RXCDR_CFG=72'h0380008bff40200008
				--For GTX only: Display Port, HBR2 -	 set RXCDR_CFG=72'h038C008bff20200010
--				RXCDR_CFG																=> x"03000023ff20400020",				-- default from wizard
				RXCDR_CFG																=> x"0380008BFF40100008",			-- 1.5 GHz line rate		- Xilinx AR# 53364 - CDR settings for SSC (spread spectrum clocking)
				RXCDR_FR_RESET_ON_EIDLE									=> '0',
				RXCDR_HOLD_DURING_EIDLE									=> '0',
				RXCDR_PH_RESET_ON_EIDLE									=> '0',
				RXCDR_LOCK_CFG													=> "010101",

				-- gearbox attributes
				TXGEARBOX_EN														=> "FALSE",
				RXGEARBOX_EN														=> "FALSE",
				GEARBOX_MODE														=> "000",

				-- PRBS detection attribute
				RXPRBS_ERR_LOOPBACK											=> '0',

				-- RX fabric clock output control attributes
				TRANS_TIME_RATE													=> x"0E",

				-- TX configurable driver attributes
				TX_DEEMPH0															=> "00000",
				TX_DEEMPH1															=> "00000",
				TX_EIDLE_ASSERT_DELAY										=> "110",							-- Programmable delay between TXELECIDLE assertion to TXP/N exiting electrical idle.
				TX_EIDLE_DEASSERT_DELAY									=> "100",							-- Programmable delay between TXELECIDLE de-assertion to TXP/N exiting electrical idle.
				TX_LOOPBACK_DRIVE_HIZ										=> "FALSE",
				TX_MAINCURSOR_SEL												=> '0',
				TX_DRIVE_MODE														=> "DIRECT",
				TX_MARGIN_FULL_0												=> "1001110",
				TX_MARGIN_FULL_1												=> "1001001",
				TX_MARGIN_FULL_2												=> "1000101",
				TX_MARGIN_FULL_3												=> "1000010",
				TX_MARGIN_FULL_4												=> "1000000",
				TX_MARGIN_LOW_0													=> "1000110",
				TX_MARGIN_LOW_1													=> "1000100",
				TX_MARGIN_LOW_2													=> "1000010",
				TX_MARGIN_LOW_3													=> "1000000",
				TX_MARGIN_LOW_4													=> "1000000",

				-- TX receiver detection attributes
				TX_RXDETECT_CFG													=> x"1832",
				TX_RXDETECT_REF													=> "100",

				-- RX equalizer attributes
				RXLPM_HF_CFG														=> "00000011110000",
				RXLPM_LF_CFG														=> "00000011110000",
				RX_DFE_GAIN_CFG													=> x"020FEA",
				RX_DFE_H2_CFG														=> "000000000000",
				RX_DFE_H3_CFG														=> "000001000000",
				RX_DFE_H4_CFG														=> "00011110000",
				RX_DFE_H5_CFG														=> "00011100000",
				RX_DFE_KL_CFG														=> "0000011111110",
				RX_DFE_KL_CFG2													=> x"3010D90C",
				RX_DFE_XYD_CFG													=> "0000000000000",
				RX_DFE_LPM_CFG													=> x"0954",
				RX_DFE_LPM_HOLD_DURING_EIDLE						=> '0',
				RX_DFE_UT_CFG														=> "10001111000000000",
				RX_DFE_VP_CFG														=> "00011111100000011",

				-- TX configurable driver attributes
				TX_QPI_STATUS_EN												=> '0',

				-- TX configurable driver attributes
				TX_PREDRIVER_MODE												=> '0'
			)
			PORT MAP (
				-- clock selects and clock inputs
				CPLLREFCLKSEL										=> "111",													-- @async:		111 => use GTGREFCLK
				
				GTREFCLK0												=> GTX_RefClock(0),								-- @clock:		selectable by CPLLREFCLKSEL = 001
				GTREFCLK1												=> GTX_RefClock(1),								-- @clock:		selectable by CPLLREFCLKSEL = 010
				GTNORTHREFCLK0									=> GTX_RefClockNorth(0),					-- @clock:		selectable by CPLLREFCLKSEL = 011
				GTNORTHREFCLK1									=> GTX_RefClockNorth(1),					-- @clock:		selectable by CPLLREFCLKSEL = 100
				GTSOUTHREFCLK0									=> GTX_RefClockSouth(0),					-- @clock:		selectable by CPLLREFCLKSEL = 101
				GTSOUTHREFCLK1									=> GTX_RefClockSouth(1),					-- @clock:		selectable by CPLLREFCLKSEL = 110
				GTGREFCLK												=> GTX_RefClockGlobal,						-- @clock:		selectable by CPLLREFCLKSEL = 111
				QPLLCLK													=> GTX_QPLLClock,									-- @clock:		high-performance clock from QPLL (GHz)
				QPLLREFCLK											=> GTX_QPLLRefClock,							-- @clock:		reference clock for QPLL bypassed (MHz)
				GTREFCLKMONITOR									=> open,													-- @clock:		CPLL refclock-mux output
				
				CPLLLOCKDETCLK									=> '0',														-- @clock:		CPLL LockDetector clock (@LockDetClock)- only required if RefClock_Lost and FBClock_Lost are used
				CPLLLOCKEN											=> '1',														-- @async:		CPLL enable LockDetector
				CPLLLOCK												=> GTX_CPLL_Locked_async,					-- @async:		CPLL locked
				CPLLFBCLKLOST										=> open,													-- @LockDetClock:	
				CPLLREFCLKLOST									=> open,													-- @LockDetClock:	

				-- internal clock selects and clock outputs
				TXSYSCLKSEL											=> "00",													-- @async:		00 => use CPLL und gtxe2_channel refclock; 11 => use QPLL and gtxe2_common refclock
				TXOUTCLKSEL											=> "010",													-- @async:		010 => select TXOUTCLKPMA
				TXOUTCLKFABRIC									=> open,													-- @clock:		internal clock after TXSYSCLKSEL-mux
				TXOUTCLKPCS											=> open,													-- @clock:		internal clock from PCS sublayer
				TXOUTCLK												=> GTX_TX_RefClockOut,						-- @clock:		TX output clock
				
				RXSYSCLKSEL											=> "00",													-- @async:		00 => use CPLL und gtxe2_channel refclock; 11 => use QPLL and gtxe2_common refclock
				RXOUTCLKSEL											=> "010",													-- @async:		010 => select RXOUTCLKPMA
				RXOUTCLKFABRIC									=> open,													-- @clock:		internal clock after RXSYSCLKSEL-mux
				RXOUTCLKPCS											=> open,													-- @clock:		internal clock from PCS sublayer
				RXOUTCLK												=> GTX_RX_RefClockOut_float,						-- @clock:		RX output clock; phase aligned
				
				-- Power-Down ports
				CPLLPD													=> GTX_CPLL_PowerDown,						-- @async:			powers ChannelPLL down
				TXPD														=> GTX_TX_PowerDown,							-- @TX_Clock2:	powers TX side down (S0, S0s, S1, S2)
				RXPD														=> GTX_RX_PowerDown,							-- @async:			powers RX side down (S0, S0s, S1, S2)

				-- GTX reset ports
				-- =====================================================================
				-- GTX reset mode
				CFGRESET												=> '0',														-- @async:			reserved;
				GTRESETSEL											=> '0',														-- @async:			0 => sequential mode (recommended)
				RESETOVRD												=> '0',														-- @async:			reserved; tie to ground
				-- CPLL resets
				CPLLRESET												=> GTX_CPLL_Reset,
				-- TX resets
				GTTXRESET												=> GTX_TX_Reset,
				TXPCSRESET											=> GTX_TX_PCSReset,
				TXPMARESET											=> GTX_TX_PMAReset,
				-- RX resets
				GTRXRESET												=> GTX_RX_Reset,
				RXPCSRESET											=> GTX_RX_PCSReset,
				RXPMARESET											=> GTX_RX_PMAReset,
				RXBUFRESET											=> GTX_RX_BufferReset,						-- @async:			
				RXOOBRESET											=> '0',														-- @async:			reserved; tie to ground
				EYESCANRESET										=> '0',														
				RXCDRFREQRESET									=> '0',														-- @async:			CDR frquency detector reset
				RXCDRRESET											=> '0',														-- @async:			CDR phase detector reset
				RXPRBSCNTRESET									=> '0',														-- @RX_Clock2:	reset PRBS error counter
				-- reset done ports
				TXRESETDONE											=> GTX_TX_ResetDone,							-- @TX_Clock2:	
				RXRESETDONE											=> GTX_RX_ResetDone,							-- @RX_Clock2:	
				
				-- FPGA-Fabric interface clocks
				-- =====================================================================
				-- TX
				TXUSERRDY												=> GTX_UserClock_Locked,					-- @async:			@TX_Clock2 is stable/locked
				TXUSRCLK												=> GTX_UserClock,									-- @clock:			
				TXUSRCLK2												=> GTX_UserClock,									-- @clock:			
				-- RX
				RXUSERRDY												=> GTX_UserClock_Locked,					-- @async:			@TX_Clock2 is stable/locked
				RXUSRCLK												=> GTX_UserClock,									-- @clock:			
				RXUSRCLK2												=> GTX_UserClock,									-- @clock:			

				-- linerate clock divider selection
				-- =====================================================================
				-- TX
				TXRATE													=> GTX_TX_LineRateSelect,					-- @TX_Clock2:	
				TXRATEDONE											=> GTX_TX_LineRateSelectDone,			-- @TX_Clock2:	
				-- RX
				RXRATE													=> GTX_RX_LineRateSelect,					-- @RX_Clock2:	
				RXRATEDONE											=> GTX_RX_LineRateSelectDone,			-- @RX_Clock2:	
				
				-- Dynamic Reconfiguration Port (DRP)
				-- =====================================================================
				DRPCLK													=> GTX_DRP_Clock,									-- @DRP_Clock:	
				DRPEN														=> GTX_DRP_en,										-- @DRP_Clock:	
				DRPWE														=> GTX_DRP_we,										-- @DRP_Clock:	
				DRPADDR													=> GTX_DRP_Address,								-- @DRP_Clock:	
				DRPDI														=> GTX_DRP_DataIn,								-- @DRP_Clock:	
				DRPDO														=> GTX_DRP_DataOut,								-- @DRP_Clock:	
				DRPRDY													=> GTX_DRP_Ready,									-- @DRP_Clock:	
				
				-- datapath configuration
				TX8B10BEN												=> '1',														-- @TX_Clock2:	enable 8B/10B encoder
				TX8B10BBYPASS										=> x"00",													-- @TX_Clock2:	per-byte 8B/10B encoder bypass enables; 0 => use encoder
				RX8B10BEN												=> '1',														-- @RX_Clock2:	enable 8B710B decoder

				-- FPGA-Fabric - TX interface ports
				TXDATA(63 downto 32)						=> (63 downto 32 => '0'),					-- @TX_Clock2:	
				TXDATA(31 downto 0)							=> GTX_TX_Data,										-- @TX_Clock2:	
				
				TXCHARISK(7 downto 4)						=> (7 downto 4 => '0'),						-- @TX_Clock2:	
				TXCHARISK(3 downto 0)						=> GTX_TX_CharIsK,								-- @TX_Clock2:	
				TXCHARDISPMODE									=> x"00",													-- @TX_Clock2:	per-byte set running disparity to TXCHARDISPVAL(i); TXCHARDISPMODE(0) is also called TXCOMPLIANCE in a PIPE interface
				TXCHARDISPVAL										=> x"00",													-- @TX_Clock2:	per-byte set running disparity
				
				-- FPGA-Fabric - RX interface ports
				RXDATA(63 downto 32)						=> GTX_RX_Data_float,							-- @RX_Clock2:	
				RXDATA(31 downto 0)							=> GTX_RX_Data,										-- @RX_Clock2:	
				RXVALID													=> GTX_RX_Valid,									-- @RX_Clock2:	
				
				RXCHARISCOMMA(7 downto 4)				=> GTX_RX_CharIsComma_float,			-- @RX_Clock2:	
				RXCHARISCOMMA(3 downto 0)				=> GTX_RX_CharIsComma,						-- @RX_Clock2:	
				RXCHARISK(7 downto 4)						=> GTX_RX_CharIsK_float,					-- @RX_Clock2:	
				RXCHARISK(3 downto 0)						=> GTX_RX_CharIsK,								-- @RX_Clock2:	
				RXDISPERR(7 downto 4)						=> GTX_RX_DisparityError_float,		-- @RX_Clock2:	
				RXDISPERR(3 downto 0)						=> GTX_RX_DisparityError,					-- @RX_Clock2:	
				RXNOTINTABLE(7 downto 4)				=> GTX_RX_NotInTableError_float,	-- @RX_Clock2:	
				RXNOTINTABLE(3 downto 0)				=> GTX_RX_NotInTableError,				-- @RX_Clock2:	
				
				-- RX Byte and Word Alignment
				RXBYTEISALIGNED									=> GTX_RX_ByteIsAligned,
				RXBYTEREALIGN										=> GTX_RX_ByteRealign,
				RXCOMMADETEN										=> '1',
				RXMCOMMAALIGNEN									=> '1',
				RXPCOMMAALIGNEN									=> '1',
				RXCOMMADET											=> GTX_RX_CommaDetected,
				
				-- ElectricalIDLE and OOB ports
				TXELECIDLE											=> GTX_TX_ElectricalIDLE,					-- @TX_Clock2:	
				RXELECIDLE											=> GTX_RX_ElectricalIDLE_a,				-- @async:	
				TXPDELECIDLEMODE								=> '0',														-- @TX_Clock2:	treat TXPD and TXELECIDLE as asynchronous inputs
				RXELECIDLEMODE									=> "00",													-- @async:			indicate ElectricalIDLE on RXELECIDLE
				
				TXCOMINIT												=> GTX_TX_ComInit,
				TXCOMWAKE												=> GTX_TX_ComWake,
				TXCOMSAS												=> GTX_TX_ComSAS,
				TXCOMFINISH											=> GTX_TX_ComFinish,
				
				RXCOMINITDET										=> GTX_RX_ComInitDetected,				-- @RX_Clock2:	
				RXCOMWAKEDET										=> GTX_RX_ComWakeDetected,				-- @RX_Clock2:	
				RXCOMSASDET											=> GTX_RX_ComSASDetected_float,		-- @RX_Clock2:	

				-- RX	LPM equalizer ports (LPM - low-power mode)
				RXLPMEN													=> '0',														-- @RX_Clock2:	0 => use DFE; 1 => use LPM
				RXLPMLFHOLD											=> '0',														-- @RX_Clock2:	
				RXLPMLFKLOVRDEN									=> '0',														-- @RX_Clock2:	
				RXLPMHFHOLD											=> '0',														-- @RX_Clock2:	
				RXLPMHFOVRDEN										=> '0',														-- @RX_Clock2:	
				
				-- RX	DFE equalizer ports (discrete-time filter equalizer)
				RXDFEAGCHOLD										=> '0',														-- @RX_Clock2:	DFE Automatic Gain Control - don't care if RXDFEAGCOVRDEN is '1'
				RXDFEAGCOVRDEN									=> '0',														-- @RX_Clock2:	DFE Automatic Gain Control
				RXDFECM1EN											=> '0',
				RXDFELFHOLD											=> '0',														-- @RX_Clock2:	DFE KL Low Frequency - don't care if RXDFELFOVRDEN is '1'
				RXDFELFOVRDEN										=> '1',														-- @RX_Clock2:	DFE KL Low Frequency - Override KL value according to attribute RX_DFE_KL_CFG
				RXDFELPMRESET										=> '0',
				RXDFETAP2HOLD										=> '0',
				RXDFETAP2OVRDEN									=> '0',
				RXDFETAP3HOLD										=> '0',
				RXDFETAP3OVRDEN									=> '0',
				RXDFETAP4HOLD										=> '0',
				RXDFETAP4OVRDEN									=> '0',
				RXDFETAP5HOLD										=> '0',
				RXDFETAP5OVRDEN									=> '0',
				RXDFEUTHOLD											=> '0',
				RXDFEUTOVRDEN										=> '0',
				RXDFEVPHOLD											=> '0',
				RXDFEVPOVRDEN										=> '0',
				RXDFEVSEN												=> '0',
				RXDFEXYDEN											=> '1',														-- @RX_Clock2:	reserved; tie to vcc
				RXDFEXYDHOLD										=> '0',														-- @RX_Clock2:	reserved; 
				RXDFEXYDOVRDEN									=> '0',														-- @RX_Clock2:	reserved; 

				RXMONITORSEL										=> "00",
				RXMONITOROUT										=> open,
				RXOSHOLD												=> '0',
				RXOSOVRDEN											=> '0',

				-- Clock Data Recovery (CDR)
				RXCDRHOLD												=> '0',														-- @async:			hold the CDR control loop frozen
				RXCDRLOCK												=> open,													-- @async:			reserved; CDR locked
				
				-- TX gearbox ports
				TXGEARBOXREADY									=> open,													-- @TX_Clock2:	indicates that data can be applied to the 64B/66B or 64B/67B gearbox
				TXHEADER												=> "000",													-- @TX_Clock2:	gearbox header input for 64B/66B or 64B/67B
				TXSEQUENCE											=> "0000000",											-- @TX_Clock2:	FPGA fabric sequence counter
				TXSTARTSEQ											=> '0',														-- @TX_Clock2:	indicates the first word after reset for the 64B/66B or 64B/67B gearbox
				
				-- RX gearbox ports
				RXDATAVALID											=> open,													-- @RX_Clock2:	if gearbox is used, it indicates RXDATA is valid
				RXHEADERVALID										=> open,													-- @RX_Clock2:	if gearbox is used, it indicates RXHEADER is valid
				RXHEADER												=> open,													-- @RX_Clock2:	gearbox header output for 64B/66B or 64B/67B
				RXSTARTOFSEQ										=> open,													-- @RX_Clock2:	indicates that the sequence counter is 0 for the present RXDATA outputs
				RXGEARBOXSLIP										=> '0',														-- @RX_Clock2:	causes the gearbox contents to slip to the next possible alignment
				RXSLIDE													=> '0',														-- @RX_Clock2:	this port exists only in GTH transceivers !?!
				
				-- Channel bonding ports
				RXCHBONDEN											=> '0',														-- @RX_Clock2:	This port enables channel bonding
				RXCHBONDLEVEL										=> "000",													-- @RX_Clock:		Indicates the amount of internal pipelining used for the RX elastic buffer control signals
				RXCHBONDMASTER									=> '0',														-- @RX_Clock:		Indicates that the transceiver is the master for channel bonding
				RXCHBONDSLAVE										=> '0',														-- @RX_Clock:		Indicates that this transceiver is a slave for channel bonding
				RXCHBONDO												=> open,													-- @RX_Clock:		Channel bond control port - data out
				RXCHBONDI												=> "00000",												-- @RX_Clock:		Channel bond control port - data in
				RXCHANBONDSEQ										=> open,													-- @RX_Clock2:	RXDATA contains the start of a channel bonding sequence
				RXCHANISALIGNED									=> open,													-- @RX_Clock2:	RX elastic buffer is channel aligned
				RXCHANREALIGN										=> open,													-- @RX_Clock2:	RX elastic buffer changed channel alignment

				-- TX buffer bypass ports
				TXPHDLYTSTCLK										=> '0',														-- @clock:			TX phase and delay alignment test clock; used with TXDLYHOLD and TXDLYUPDOWN
				TXPHDLYPD												=> '1',														-- @async:			
				TXPHDLYRESET										=> '0',														-- @async:			
				TXPHALIGNEN											=> '0',														-- @async:			
				TXPHALIGN												=> '0',														-- @async:			
				TXPHALIGNDONE										=> open,													-- @async:			
				TXPHINIT												=> '0',														-- @async:			
				TXPHINITDONE										=> open,													-- @async:			
				TXPHOVRDEN											=> '0',														-- @async:			
				TXDLYEN													=> '0',														-- @async:			enables TX delay alignment manual mode; 0 => auto mode
				TXDLYBYPASS											=> '1',														-- @async:			TX delay alignment bypass; 0 => use TX delay alignment circuit; 1 => bypass TX delay alignment circuit
				TXDLYSRESET											=> '0',														-- @async:			
				TXDLYSRESETDONE									=> open,													-- @async:			
				TXDLYOVRDEN											=> '0',														-- @async:			
				TXDLYHOLD												=> '0',														-- @TXPHDLYTSTCLK:			
				TXDLYUPDOWN											=> '0',														-- @TXPHDLYTSTCLK:			
				
				-- RX buffer bypass ports
				RXDDIEN													=> '0',														-- @async:			RX data delay insertion enable; set high if RX buffer is bypassed
				RXPHDLYRESET										=> '0',														-- @async:			RX phase alignment hard reset
				RXPHALIGNEN											=> '0',														-- @async:			RX phase alignment enable; 0 => auto alignment
				RXPHALIGN												=> '0',														-- @async:			Sets the RX phase alignment; 0 => auto alignment
				RXPHALIGNDONE										=> open,													-- @async:			RX phase alignment done
				RXPHDLYPD												=> '0',														-- @async:			RX phase and delay alignment circuit power down
				RXPHMONITOR											=> open,													-- @async:			RX phase alignment monitor
				RXPHOVRDEN											=> '0',														-- @async:			RX phase alignment counter override enable
				RXPHSLIPMONITOR									=> open,													-- @async:			RX phase alignment slip monitor
				RXDLYBYPASS											=> '1',														-- @async:			RX delay alignment bypass; 0 => use the RX delay alignment circuit; 1 => bypass the RX delay alignment circuit
				RXDLYEN													=> '0',														-- @async:			RX delay alignment enable
				RXDLYOVRDEN											=> '0',														-- @async:			RX delay alignment counter override enable
				RXDLYSRESET											=> '0',														-- @async:			RX delay alignment soft reset
				RXDLYSRESETDONE									=> open,													-- @async:			RX delay alignment soft reset done
				
				-- status ports
				PHYSTATUS												=> GTX_PhyStatus,									-- @RX_Clock2:	
				TXBUFSTATUS											=> GTX_TX_BufferStatus,						-- @TX_Clock2:	
				RXBUFSTATUS											=> GTX_RX_BufferStatus,						-- @RX_Clock2:	
				RXSTATUS												=> GTX_RX_Status,									-- @RX_Clock2:	
				RXCLKCORCNT											=> GTX_RX_ClockCorrectionStatus,	-- @RX_Clock2:	"1--" indicates buffer under/overflow
				
				-- loopback port
				LOOPBACK												=> "000",													-- @async:			000 => normal operation
				
				-- Pseudo Random Bit Sequence (PRBS) test pattern generator/checker ports
				TXPRBSSEL												=> "000",													-- @TX_Clock2:	000 => normal operation; PRBS generator is off
				TXPRBSFORCEERR									=> '0',														-- @TX_Clock2:	1 => force errors in the PRBS transmitter

				RXPRBSSEL												=> "000",													-- @RX_Clock2:	000 => normal operation; PRBS checker is off
				RXPRBSERR												=> open,													-- @RX_Clock2:	PRBS error have occurred; error counter 'RX_PRBS_ERR_CNT' can only be accessed by DRP at address 0x15C
				
				-- Digital Monitor Ports
				DMONITOROUT											=> open,
				
				EYESCANMODE											=> '0',														-- @async:			
				EYESCANTRIGGER									=> '0',														-- @async:			
				EYESCANDATAERROR								=> open,													-- @async:			
				
				-- reserved ports
				GTRSVD													=> "0000000000000000",						-- @async:			
				PCSRSVDIN												=> "0000000000000000",						-- @async:			
				PCSRSVDIN2											=> "00000",												-- @async:			
				PMARSVDIN												=> "00000",												-- @async:			
				PMARSVDIN2											=> "00000",												-- @async:			
				TSTIN														=> "11111111111111111111",				-- @async:			
				TSTOUT													=> open,													-- @async:			
				CLKRSVD(0)											=> OOB_Clock,											-- @clock:			alternative OOB clock; selectable by PCS_RSVD_ATTR(3) = '1'
				CLKRSVD(3 downto 1)							=> "000",
				SETERRSTATUS										=> '0',														-- @async:			reserved; RX 8B/10B decoder port
				RXCDROVRDEN											=> '0',														-- @async:			reserved; CDR port
				RXCDRRESETRSV										=> '0',														-- @async:			reserved; CDR port
				PCSRSVDOUT											=> open,													-- @async:			reserved; PCS

				-- polarity control
				TXPOLARITY											=> '0',														-- @TX_Clock2:	invert the polarity of outgoing data
				RXPOLARITY											=> '0',														-- @RX_Clock2:	invert the polarity of incoming data (done after SIPO on bytes)
				
				-- TX configurable driver ports
				TXPISOPD												=> '0',														-- @async:			reserved; ParallelIn/SerialOut (PISO) power-down
				TXINHIBIT												=> '0',														-- @TX_Clock2:	forces GTXTXP to 0 and GTXTXN to 1
				TXDIFFPD												=> '0',														-- @async:			reserved; TX driver power-down
				TXDIFFCTRL											=> "0101",												-- @TX_Clock2:	TX driver swing control [mV_PPD]; 0101 => 609 mV peak-peak-differential voltage
				TXBUFDIFFCTRL										=> "100",													-- @TX_Clock2:	TX pre-driver swing control; default is 100; do not modify
				TXDEEMPH												=> '0',														-- @TX_Clock2:	TX de-emphasis control
				TXMARGIN												=> "000",													-- @async:			TX margin control
				TXSWING													=> '0',														-- @async:			TX swing control; 0 => full swing; 1 => half-swing
				TXPRECURSOR											=> "00000",												-- @async:			TX pre-cursor pre-emphasis control
				TXPRECURSORINV									=> '0',														-- @async:			TX pre-cursor 
				TXMAINCURSOR										=> "0000000",											-- @async:			TX main-cursur
				TXPOSTCURSOR										=> "00000",												-- @async:			TX post-cursor pre-emphasis control
				TXPOSTCURSORINV									=> '0',
				
				-- TX driver ports for QuickPathInterconnect (QPI)
				TXQPIBIASEN											=> '0',														-- @async:			enables the GND bias on TX output as required by the QPI specification
				TXQPISTRONGPDOWN								=> '0',														-- @async:			pulls the TX output strongly to GND to enable handshaking as required by the QPI protocol
				TXQPIWEAKPUP										=> '0',														-- @async:			pulls the TX output weakly to MGTAVTT to enable handshaking as required by the QPI protocol
				TXQPISENN												=> open,													-- @async:			sense output for GTXTXN
				TXQPISENP												=> open,													-- @async:			sense output for GTXTXP
				
				-- RX Analog FrontEnd (AFE) ports
				RXQPIEN													=> '0',														-- @async:			disables RX termination for the QPI protocol
				RXQPISENN												=> open,													-- @async:			Sense output on GTXRXN
				RXQPISENP												=> open,													-- @async:			Sense output on GTXRXP
				
				-- TX receiver detection ports
				TXDETECTRX											=> '0',														-- @TX_Clock2:	begin a receiver detection operation; 0 => normal operation; 1 => receiver detection
				
				-- Tranceiver physical ports
				GTXTXN													=> GTX_TX_n,											-- @analog:			
				GTXTXP													=> GTX_TX_p,											-- @analog:			
				GTXRXN													=> GTX_RX_n,											-- @analog:			
				GTXRXP													=> GTX_RX_p												-- @analog:			
			);
		
		GTX_RX_n									<= VSS_Private_In(I).RX_n;
		GTX_RX_p									<= VSS_Private_In(I).RX_p;
		VSS_Private_Out(I).TX_n		<= GTX_TX_n;
		VSS_Private_Out(I).TX_p		<= GTX_TX_p;
		
		genCSP : IF (ENABLE_DEBUGPORT = TRUE) GENERATE
		
		BEGIN
			DebugPortOut(I).ClockNetwork_Reset				<= ClkNet_Reset;
			DebugPortOut(I).ClockNetwork_ResetDone		<= ClkNet_ResetDone;
			DebugPortOut(I).Reset											<= GTX_Reset;
			DebugPortOut(I).ResetDone									<= ResetDone_r;
			DebugPortOut(I).PowerDown									<= PowerDown(I);
			DebugPortOut(I).CPLL_Reset								<= GTX_CPLL_Reset;
			DebugPortOut(I).CPLL_Locked								<= GTX_CPLL_Locked_async;
			DebugPortOut(I).OOB_Clock									<= OOB_Clock;
			DebugPortOut(I).RP_SATAGeneration					<= RP_SATAGeneration(I);
			DebugPortOut(I).RP_Reconfig								<= RP_Reconfig(I);
			DebugPortOut(I).RP_ReconfigComplete				<= RP_Reconfig_d;
			DebugPortOut(I).RP_ConfigRealoaded				<= RateChangeDone_re;
			DebugPortOut(I).DD_NoDevice								<= DD_NoDevice;
			DebugPortOut(I).DD_NewDevice							<= DD_NewDevice;
			DebugPortOut(I).TX_RateSelection					<= GTX_TX_LineRateSelect;
			DebugPortOut(I).RX_RateSelection					<= GTX_RX_LineRateSelect;
			DebugPortOut(I).TX_RateSelectionDone			<= GTX_TX_LineRateSelectDone;
			DebugPortOut(I).RX_RateSelectionDone			<= GTX_RX_LineRateSelectDone;
			DebugPortOut(I).TX_Reset									<= GTX_TX_Reset;
			DebugPortOut(I).RX_Reset									<= GTX_RX_Reset;
			DebugPortOut(I).TX_ResetDone							<= GTX_TX_ResetDone;
			DebugPortOut(I).RX_ResetDone							<= GTX_RX_ResetDone;
		
			DebugPortOut(I).TX_Data										<= GTX_TX_Data;
			DebugPortOut(I).TX_CharIsK								<= GTX_TX_CharIsK;
			DebugPortOut(I).TX_ComInit								<= GTX_TX_ComInit;
			DebugPortOut(I).TX_ComWake								<= GTX_TX_ComWake;
			DebugPortOut(I).TX_ComFinish							<= GTX_TX_ComFinish;
			DebugPortOut(I).TX_ElectricalIDLE					<= GTX_TX_ElectricalIDLE;

			DebugPortOut(I).RX_Data										<= GTX_RX_Data;
			DebugPortOut(I).RX_CharIsK								<= GTX_RX_CharIsK;
			DebugPortOut(I).RX_CharIsComma						<= GTX_RX_CharIsComma;
			DebugPortOut(I).RX_CommaDetected					<= GTX_RX_CommaDetected;
			DebugPortOut(I).RX_ByteIsAligned					<= GTX_RX_ByteIsAligned;
			DebugPortOut(I).RX_ElectricalIDLE					<= GTX_RX_ElectricalIDLE;
			DebugPortOut(I).RX_ComInitDetected				<= GTX_RX_ComInitDetected;
			DebugPortOut(I).RX_ComWakeDetected				<= GTX_RX_ComWakeDetected;
			DebugPortOut(I).RX_Valid									<= GTX_RX_Valid;
			DebugPortOut(I).RX_Status									<= GTX_RX_Status;
			DebugPortOut(I).RX_ClockCorrectionStatus	<= GTX_RX_ClockCorrectionStatus;
		END GENERATE;
	END GENERATE;
END;
