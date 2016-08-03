-- EMACS settings: -*-	tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Entity:					TODO
--
-- Description:
-- -------------------------------------
--		This is a vendor, device and protocol specific instanziation of a 7-Series
--		GTPE2 transceiver. This GTP is configured for Serial-ATA from Gen1 to Gen3
--		with linerates from 1.5 GHz to 6.0 GHz. It has a 'RP_SATAGeneration' dependant
--		user interface frequency of 37.5 MHz up to 150 MHz at Gen3. The data interface
--		has a constant width of 32 bit per data word and 4 CharIsK marker bits.
--
-- License:
-- -----------------------------------------------------------------------------
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library UNISIM;
use			UNISIM.VcomponentS.all;

library PoC;
use			PoC.config.all;
use			PoC.components.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;
use			PoC.sata_TransceiverTypes.all;
use			PoC.xil.all;


entity sata_Transceiver_Series7_GTPE2 is
	generic (
		DEBUG											: boolean											:= FALSE;																		-- generate additional debug signals and preserve them (attribute keep)
		ENABLE_DEBUGPORT					: boolean											:= FALSE;																		-- enables the assignment of signals to the debugport
		REFCLOCK_FREQ							: FREQ												:= 150 MHz;																	-- 150 MHz
		PORTS											: positive										:= 2;																				-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR		:= (0 to 3	=> C_SATA_GENERATION_MAX)				-- intial SATA Generation
	);
	port (
		ClockNetwork_Reset				: in	std_logic_vector(PORTS - 1 downto 0);
		ClockNetwork_ResetDone		: out	std_logic_vector(PORTS - 1 downto 0);
		Reset											: in	std_logic_vector(PORTS - 1 downto 0);
		ResetDone									: out	std_logic_vector(PORTS - 1 downto 0);

		PowerDown									: in	std_logic_vector(PORTS - 1 downto 0);
		Command										: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
		Status										: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
		Error											: out	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 downto 0);

		-- debug ports
		DebugPortIn								: in	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 downto 0);
		DebugPortOut							: out	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 downto 0);

		SATA_Clock								: out	std_logic_vector(PORTS - 1 downto 0);
		SATA_Clock_Stable					: out	std_logic_vector(PORTS - 1 downto 0);

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
		OOB_AlignDetected					: in	std_logic_vector(PORTS - 1 downto 0);

		TX_Data										: in	T_SLVV_32(PORTS - 1 downto 0);
		TX_CharIsK								: in	T_SLVV_4(PORTS - 1 downto 0);

		RX_Data										: out	T_SLVV_32(PORTS - 1 downto 0);
		RX_CharIsK								: out	T_SLVV_4(PORTS - 1 downto 0);
		RX_Valid									: out std_logic_vector(PORTS - 1 downto 0);

		-- vendor specific signals
		VSS_Common_In							: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In						: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS	- 1 downto 0);
		VSS_Private_Out						: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS	- 1 downto 0)
	);
end;


architecture rtl of sata_Transceiver_Series7_GTPE2 is
	attribute KEEP 										: boolean;
	attribute MAXSKEW : string;

	-- ===========================================================================
	-- SATATransceiver configuration
	-- ===========================================================================
	constant INITIAL_SATA_GENERATIONS_I	: T_SATA_GENERATION_VECTOR(0 to PORTS - 1)	:= INITIAL_SATA_GENERATIONS;

	constant NO_DEVICE_TIMEOUT				: time																			:= 50 ms;
	constant NEW_DEVICE_TIMEOUT				: time																			:= 1 us;

--	constant C_DEVICE_INFO						: T_DEVICE_INFO		:= DEVICE_INFO;

	signal RefClockIn_150_MHz_BUFR		: std_logic;

	function to_ClockDividerSelection(gen : T_SATA_GENERATION) return std_logic_vector is
	begin
		case gen is
			when SATA_GENERATION_1 =>			return "011";				-- **PLL Divider (D) = 4
			when SATA_GENERATION_2 =>			return "010";				-- **PLL Divider (D) = 2
			when SATA_GENERATION_3 =>			return "001";				-- **PLL Divider (D) = 1
			when others =>								return "000";				-- **PLL DIVIDER (D) = RXOUT_DIV
		end case;
	end function;

	function get_FeedbackClockDivider(RefClock_Freq : FREQ) return positive is
	begin
		if		(RefClock_Freq = 100 MHz) then	return 3;
		elsif (RefClock_Freq = 150 MHz) then	return 4;
		elsif (RefClock_Freq = 200 MHz) then	return 3;
		else																	return 0;
		end if;
	end function;
	
	function get_ReferenceClockDivider(RefClock_Freq : FREQ) return positive is
	begin
		if		(RefClock_Freq = 100 MHz) then	return 1;
		elsif (RefClock_Freq = 150 MHz) then	return 1;
		elsif (RefClock_Freq = 200 MHz) then	return 2;
		else																	return 0;
		end if;
	end function;
	
	constant PLL0_FEEDBACK_CLOCK_DIVIDER	: positive := get_FeedbackClockDivider(REFCLOCK_FREQ);
	constant PLL0_REFERENCE_CLOCK_DIVIDER	: positive := get_ReferenceClockDivider(REFCLOCK_FREQ);
	
	signal QuadPLL_PowerDown			: std_logic_vector(0 downto 0);
	signal QuadPLL_Reset					: std_logic_vector(0 downto 0);
	signal QuadPLL_Locked_async		: std_logic_vector(0 downto 0);
	signal QuadPLL_HFClock				: std_logic_vector(0 downto 0);
	signal QuadPLL_RefClock				: std_logic_vector(0 downto 0);
	
	signal QuadPLL_DRP_Clock			: std_logic;
	signal QuadPLL_DRP_Enable			: std_logic;
	signal QuadPLL_DRP_ReadWrite	: std_logic;
	signal QuadPLL_DRP_Address		: T_XIL_DRP_ADDRESS;
	signal QuadPLL_DRP_DataIn			: T_XIL_DRP_DATA;
	signal QuadPLL_DRP_DataOut		: T_XIL_DRP_DATA;
	signal QuadPLL_DRP_Ack				: std_logic;
	
begin

-- ==================================================================
-- Assert statements
-- ==================================================================
--	assert (C_DEVICE_INFO.Vendor = Vendor_XILINX)								report "This is a vendor dependent component. Vendor must be Xilinx!"						severity FAILURE;
--	assert (C_DEVICE_INFO.TRANSCEIVERTYPE = TRANSCEIVER_GTPE2)	report "This is a GTPE2 wrapper component."																			severity FAILURE;
--	assert (C_DEVICE_INFO.DEVICE = DEVICE_KINTEX7)							report "Device " & T_DEVICE'image(C_DEVICE_INFO.DEVICE) & " not yet supported."	severity FAILURE;
	assert (PORTS <= 4)																					report "To many ports per transceiver."																					severity FAILURE;

	-- =========================================================================
	-- GTP Power and Clock control
	-- =========================================================================
	QuadPLL_PowerDown(0)		<= slv_and(PowerDown);
	QuadPLL_Reset(0)				<= QuadPLL_PowerDown(0) or slv_and(ClockNetwork_Reset);
	
	QuadPLL_DRP_Clock				<= '0';
	QuadPLL_DRP_Enable			<= '0';
	QuadPLL_DRP_ReadWrite		<= '0';
	QuadPLL_DRP_Address			<= x"0000";
	QuadPLL_DRP_DataIn			<= x"0000";
	--	<float>							<= QuadPLL_DRP_DataOut;
	--	<float>							<= QuadPLL_DRP_Ack;
	
	QuadPLL : GTPE2_COMMON
		generic map (
			-- Simulation attributes
			SIM_RESET_SPEEDUP		=> "TRUE",
			SIM_PLL0REFCLK_SEL	=> "111",									-- select GTGREFCLK0 (from fabric)
			SIM_PLL1REFCLK_SEL	=> "001",									-- select GTREFCLK0 (from IBUFDS_GTE2)
			SIM_VERSION					=> ("2.0"),

			PLL0_FBDIV					=> PLL0_FEEDBACK_CLOCK_DIVIDER,
			PLL0_FBDIV_45				=> 5,
			PLL0_REFCLK_DIV			=> PLL0_REFERENCE_CLOCK_DIVIDER,
			PLL1_FBDIV					=> 4,
			PLL1_FBDIV_45				=> 5,
			PLL1_REFCLK_DIV			=> 1,

			-- COMMON BLOCK Attributes
			BIAS_CFG						=> x"0000000000050001",
			COMMON_CFG					=> x"00000000",
			PLL_CLKOUT_CFG			=> x"00",
			-- Reserved Attributes
			RSVD_ATTR0					=> x"0000",
			RSVD_ATTR1					=> x"0000",
			-- PLL Attributes
			PLL0_CFG						=> x"01F03DC",
			PLL0_DMON_CFG				=> '0',
			PLL0_INIT_CFG				=> x"00001E",
			PLL0_LOCK_CFG				=> x"1E8",
			PLL1_CFG						=> x"01F03DC",
			PLL1_DMON_CFG				=> '0',
			PLL1_INIT_CFG				=> x"00001E",
			PLL1_LOCK_CFG				=> x"1E8"
		)
		port map (
			-- Clock inputs
			GTGREFCLK0					=> VSS_Common_In.RefClockIn_150_MHz,	-- from fabric
			GTGREFCLK1					=> VSS_Common_In.RefClockIn_150_MHz,	-- from fabric
			GTREFCLK0						=> '0',																-- from IBUFDS_GTE2
			GTREFCLK1						=> '0',																-- from IBUFDS_GTE2
			GTEASTREFCLK0				=> '0',																-- from previous GTPE2
			GTEASTREFCLK1				=> '0',																-- from previous GTPE2
			GTWESTREFCLK0				=> '0',																-- from next GTPE2
			GTWESTREFCLK1				=> '0',																-- from next GTPE2

			-- PLL 0 - power-down and resets
			PLL0PD							=> QuadPLL_PowerDown(0),
			PLL0RESET						=> QuadPLL_Reset(0),
			-- PLL 0 - 
			PLL0REFCLKSEL				=> "111",									-- select GTGREFCLK0 (from fabric)
			PLL0REFCLKLOST			=> open,
			PLL0FBCLKLOST				=> open,
			PLL0LOCKDETCLK			=> '0',
			PLL0LOCKEN					=> '1',
			PLL0LOCK						=> QuadPLL_Locked_async(0),
			-- PLL 0 - clock output
			PLL0OUTCLK					=> QuadPLL_HFClock(0),
			PLL0OUTREFCLK				=> QuadPLL_RefClock(0),
			REFCLKOUTMONITOR0		=> open,
			
			-- PLL 1 - power-down and resets
			PLL1PD							=> '1',
			PLL1RESET						=> '0',
			-- PLL 0 - 
			PLL1REFCLKSEL				=> "001",									-- select GTREFCLK0 (from IBUFDS_GTE2)
			PLL1REFCLKLOST			=> open,
			PLL1FBCLKLOST				=> open,
			PLL1LOCKDETCLK			=> '0',
			PLL1LOCKEN					=> '1',
			PLL1LOCK						=> open,
			-- PLL 0 - clock output
			PLL1OUTCLK					=> open,
			PLL1OUTREFCLK				=> open,
			REFCLKOUTMONITOR1		=> open,
			
			-- unknown ports
			BGRCALOVRDENB				=> '1',
			PLLRSVD1						=> "0000000000000000",
			PLLRSVD2						=> "00000",
			-- RX AFE Ports
			PMARSVDOUT					=> open,
			BGBYPASSB						=> '1',
			BGMONITORENB				=> '1',
			BGPDB								=> '1',
			BGRCALOVRD					=> "11111",
			PMARSVD							=> "00000000",
			RCALENB							=> '1',
			-- Digital monitor output
			DMONITOROUT					=> open,	
			-- Dynamic Reconfiguration Port (DRP)
			DRPCLK							=> QuadPLL_DRP_Clock,									-- @DRP_Clock:
			DRPEN								=> QuadPLL_DRP_Enable,								-- @DRP_Clock:
			DRPWE								=> QuadPLL_DRP_ReadWrite,							-- @DRP_Clock:
			DRPADDR							=> QuadPLL_DRP_Address(7 downto 0),		-- @DRP_Clock:
			DRPDI								=> QuadPLL_DRP_DataIn,								-- @DRP_Clock:
			DRPDO								=> QuadPLL_DRP_DataOut,								-- @DRP_Clock:
			DRPRDY							=> QuadPLL_DRP_Ack										-- @DRP_Clock:
		);
	
	-- ===========================================================================
	-- Port instance
	-- ===========================================================================
	genGTPE2 : for i in 0 to (PORTS	- 1) generate
		constant CLOCK_DIVIDER_SELECTION		:	std_logic_vector(2 downto 0)	:= to_ClockDividerSelection(INITIAL_SATA_GENERATIONS_I(i));

		constant QUADPLL_PORTID							: positive	:= 0;
		
		constant GTP_PCS_RSVD_ATTR					: bit_vector(47 downto 0)				:= x"000000000100";	-- GTXE2 (
-- GTXE2 			3 =>			'0',							-- select alternative OOB circuit clock source; 0 => sysclk; 1 => CLKRSVD(0)
-- GTXE2 			6 =>			'1',							-- reserved; set to '1'
-- GTXE2 			8 =>			'1',							-- power up OOB circuit
-- GTXE2 			others =>	'0'								-- not documented; set to "0..0" ?
-- GTXE2 		);

		constant GTP_RXCDR_CFG							: bit_vector(83 downto 0)				:=
			ite((INITIAL_SATA_GENERATIONS_I(i) = SATA_GENERATION_1), x"0000047FE106024481010",				-- 1.5 GHz line rate		- from wizard generated code
			ite((INITIAL_SATA_GENERATIONS_I(i) = SATA_GENERATION_2), x"0000047FE206024481010",				-- 3.0 GHz line rate
			ite((INITIAL_SATA_GENERATIONS_I(i) = SATA_GENERATION_3), x"0000087FE206024441010",				-- 6.0 GHz line rate
																															 x"0000087FE206024441010")));			-- default value from wizard


		-- Control FSM @SATA_Clock
		type T_STATE is (ST_RESET, ST_READY, ST_COMMUNICATION, ST_RECONFIGURATION, ST_RESET_BY_FSM, ST_CLEAR_RX_BUF);

		signal State												: T_STATE				:= ST_RESET;
		signal NextState										: T_STATE;

		signal Kill_SATA_Clock_Stable 			: std_logic;
		signal GTP_Reset_by_FSM							: std_logic;
		signal GTP_Reset_by_FSM_d						: std_logic;

		-- Input/Outputs of ClockNetwork module/block
		signal ClkNet_Reset									: std_logic;
		signal ClkNet_ResetDone							: std_logic;

		attribute MAXSKEW of ClkNet_Reset : signal is "1 ns"; -- required by sata_Transceiver_ClockStable

		signal QuadPLL_Locked								: std_logic;
		
		-- internal version of output signals
		signal ResetDone_i									: std_logic							:= '0';
		signal ClockNetwork_ResetDone_i 		: std_logic;
		signal GTP_UserClock 						 		: std_logic;
		signal GTP_UserClock2 					 		: std_logic;
		signal SATA_Clock_i 						 		: std_logic;
		signal SATA_Clock_Stable_i					: std_logic 						:= '0';

		signal GTP_TX_RefClockOut						: std_logic;
		signal GTP_RX_RefClockOut_float			: std_logic;

		-- PowerDown signals
		signal Trans_PowerDown							: std_logic;
		signal GTP_TX_PowerDown							: T_SLV_2;
		signal GTP_RX_PowerDown							: T_SLV_2;

		-- Reset both TX & RX
		signal GTP_Reset										: std_logic;

		-- TX resets
		signal GTP_TX_Reset									: std_logic;
		signal GTP_TX_PCSReset							: std_logic;
		signal GTP_TX_PMAReset							: std_logic;
		signal GTP_TX_PMAResetDone					: std_logic;
		-- RX resets
		signal GTP_RX_Reset									: std_logic;
		signal GTP_RX_PCSReset							: std_logic;
		signal GTP_RX_PMAReset							: std_logic;
		signal GTP_RX_PMAResetDone					: std_logic;
		signal GTP_RX_BufferReset						: std_logic;

		signal GTP_TX_ResetDone							: std_logic;
		signal GTP_RX_ResetDone							: std_logic;

		-- linerate clock divider selection
		-- =====================================================================
		signal RP_Reconfig_d								: std_logic						:= '0';

		signal GTP_TX_LineRateSelect				: std_logic_vector(2 downto 0)		:= CLOCK_DIVIDER_SELECTION;
		signal GTP_RX_LineRateSelect				: std_logic_vector(2 downto 0)		:= CLOCK_DIVIDER_SELECTION;

		signal GTP_TX_LineRateSelectDone		: std_logic;
		signal GTP_RX_LineRateSelectDone		: std_logic;

		signal GTPConfig_Enable							: std_logic;
		signal GTPConfig_Address						: T_XIL_DRP_ADDRESS;
		signal GTPConfig_ReadWrite					: std_logic;
		signal GTPConfig_DataOut						: T_XIL_DRP_DATA;

		signal DRPSync_Enable								: std_logic;
		signal DRPSync_Address							: T_XIL_DRP_ADDRESS;
		signal DRPSync_ReadWrite						: std_logic;
		signal DRPSync_DataOut							: T_XIL_DRP_DATA;

		signal DRPMux_In_DataOut						: T_XIL_DRP_DATA_VECTOR(1 downto 0);
		signal DRPMux_Ack										: std_logic_vector(1 downto 0);

		signal GTP_DRP_Clock								: std_logic;
		signal GTP_DRP_Enable								: std_logic;
		signal GTP_DRP_ReadWrite						: std_logic;
		signal GTP_DRP_Address							: T_XIL_DRP_ADDRESS;
		signal GTP_DRP_DataIn								: T_XIL_DRP_DATA;
		signal GTP_DRP_DataOut							: T_XIL_DRP_DATA;
		signal GTP_DRP_Ack									: std_logic;

		signal GTP_DigitalMonitor						: T_SLV_16;
		signal GTP_RX_Monitor_sel						: T_SLV_2;
		signal GTP_RX_Monitor_Data					: std_logic_vector(6 downto 0);

		signal GTP_PhyStatus								: std_logic;
		signal GTP_TX_BufferStatus					: std_logic_vector(1 downto 0);
		signal GTP_RX_BufferStatus					: std_logic_vector(2 downto 0);
		signal GTP_RX_Status								: std_logic_vector(2 downto 0);
		signal GTP_RX_ClockCorrectionStatus	: std_logic_vector(1 downto 0);

		signal GTP_TX_ElectricalIDLE				: std_logic;
		signal GTP_RX_ElectricalIDLE				: std_logic;
		signal GTP_RX_ElectricalIDLE_Mode		: T_SLV_2						:= "00";
		signal GTP_RX_ElectricalIDLE_async	: std_logic;
		signal RX_ElectricalIDLE						: std_logic;

		signal GTP_TX_ComInit								: std_logic;
		signal GTP_TX_ComWake								: std_logic;
		signal GTP_TX_ComSAS								: std_logic;
		signal GTP_TX_ComFinish							: std_logic;

		signal GTP_TX_ComInit_set						: std_logic;
		signal GTP_TX_ComInit_r							: std_logic					:= '0';
		signal GTP_TX_ComWake_set						: std_logic;
		signal GTP_TX_ComWake_r							: std_logic					:= '0';
		signal GTP_TX_ComSAS_set						: std_logic;
		signal GTP_TX_ComSAS_r							: std_logic					:= '0';

		signal GTP_RX_ComInitDetected				: std_logic;
		signal GTP_RX_ComWakeDetected				: std_logic;
		signal GTP_RX_ComSASDetected				: std_logic;

		signal OOB_TX_Command_d							: T_SATA_OOB				:= SATA_OOB_NONE;
		signal OOB_RX_Received_i						: T_SATA_OOB;

		-- timings
		constant CLOCK_GEN1_FREQ						: FREQ						:= REFCLOCK_FREQ / 4.0;
		constant CLOCK_GEN2_FREQ						: FREQ						:= REFCLOCK_FREQ / 2.0;
		constant CLOCK_GEN3_FREQ						: FREQ						:= REFCLOCK_FREQ / 1.0;
		constant CLOCK_DD_FREQ							: FREQ						:= REFCLOCK_FREQ / 1.0;

		constant COMRESET_TIMEOUT						: time						:= 2600 ns;
		constant COMWAKE_TIMEOUT						: time						:= 1300 ns;
		constant COMSAS_TIMEOUT							: time						:= 6450 ns;

		-- Timing table ID
		constant TTID_COMRESET_TIMEOUT_GEN1	: natural					:= 0;
		constant TTID_COMRESET_TIMEOUT_GEN2	: natural					:= 1;
		constant TTID_COMRESET_TIMEOUT_GEN3	: natural					:= 2;
		constant TTID_COMWAKE_TIMEOUT_GEN1	: natural					:= 3;
		constant TTID_COMWAKE_TIMEOUT_GEN2	: natural					:= 4;
		constant TTID_COMWAKE_TIMEOUT_GEN3	: natural					:= 5;
		constant TTID_COMSAS_TIMEOUT_GEN1		: natural					:= 6;
		constant TTID_COMSAS_TIMEOUT_GEN2		: natural					:= 7;
		constant TTID_COMSAS_TIMEOUT_GEN3		: natural					:= 8;

		-- Timing table
		constant TIMING_TABLE								: T_NATVEC				:= (
			TTID_COMRESET_TIMEOUT_GEN1	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN1_FREQ),		-- slot 0
			TTID_COMRESET_TIMEOUT_GEN2	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN2_FREQ),		-- slot 1
			TTID_COMRESET_TIMEOUT_GEN3	=> TimingToCycles(COMRESET_TIMEOUT,	CLOCK_GEN3_FREQ),		-- slot 2
			TTID_COMWAKE_TIMEOUT_GEN1		=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN1_FREQ),		-- slot 3
			TTID_COMWAKE_TIMEOUT_GEN2		=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN2_FREQ),		-- slot 4
			TTID_COMWAKE_TIMEOUT_GEN3		=> TimingToCycles(COMWAKE_TIMEOUT,	CLOCK_GEN3_FREQ),		-- slot 5
			TTID_COMSAS_TIMEOUT_GEN1		=> TimingToCycles(COMSAS_TIMEOUT,		CLOCK_GEN1_FREQ),		-- slot 6
			TTID_COMSAS_TIMEOUT_GEN2		=> TimingToCycles(COMSAS_TIMEOUT,		CLOCK_GEN2_FREQ),		-- slot 7
			TTID_COMSAS_TIMEOUT_GEN3		=> TimingToCycles(COMSAS_TIMEOUT,		CLOCK_GEN3_FREQ)		-- slot 8
		);

		signal OOBTO_Load										: std_logic;
		signal OOBTO_Slot										: natural;
		signal OOBTO_en											: std_logic;
		signal OOBTO_Timeout								: std_logic;
		signal OOBTO_Timeout_d							: std_logic					:= '0';
		signal TX_ComFinish									: std_logic;

		signal TX_RateChangeDone						: std_logic					:= '0';
		signal RX_RateChangeDone						: std_logic					:= '0';
		signal RateChangeDone								: std_logic;
		signal RateChangeDone_d							: std_logic					:= '0';
		signal RateChangeDone_re						: std_logic;

		signal GTP_TX_Data									: T_SLV_32;
		signal GTP_TX_CharIsK								: T_SLV_4;

		signal RX_CDR_Locked								: std_logic;															-- unused
		signal GTP_RX_CDR_Hold							: std_logic 				:= '1';

		signal GTP_RX_Data									: T_SLV_32;
		signal GTP_RX_CommaDetected					: std_logic;															-- unused
		signal GTP_RX_CharIsComma						: T_SLV_4;																-- unused
		signal GTP_RX_CharIsK								: T_SLV_4;
		signal GTP_RX_DisparityError				: T_SLV_4;																-- unused
		signal GTP_RX_NotInTableError				: T_SLV_4;																-- unused
		signal GTP_RX_ByteIsAligned					: std_logic;
		signal GTP_RX_ByteRealign						: std_logic;															-- unused

		signal GTP_TX_n											: std_logic;
		signal GTP_TX_p											: std_logic;
		signal GTP_RX_n											: std_logic;
		signal GTP_RX_p											: std_logic;

		signal Status_i											: T_SATA_TRANSCEIVER_STATUS;
		signal Error_i											: T_SATA_TRANSCEIVER_ERROR;

		-- keep internal clock nets, so timing constrains from UCF can find them
		attribute KEEP of GTP_TX_RefClockOut	: signal is TRUE;

	begin
		assert FALSE report "Port: " & integer'image(i)																											severity NOTE;
--		assert FALSE report "	Init. SATA Generation:	Gen" & integer'image(INITIAL_SATA_GENERATIONS_I(i) + 1)	severity NOTE;
		assert ((RP_SATAGeneration(i) = SATA_GENERATION_1) or
						(RP_SATAGeneration(i) = SATA_GENERATION_2) or
						(RP_SATAGeneration(i) = SATA_GENERATION_3))		report "Unsupported SATA generation."							severity FAILURE;

		-- ======================================================================
		-- ClockNetwork
		--
		-- TODO Implement module which generates the appropiate
		-- SATA_Clock according to the selected generation.
		-- Use 150 MHz input clock for SATA Gen3 at the moment.
		--
		-- The transceiver must be brought up with PowerDown = '1'.
		-- The ClockNetwork is reset (signal ClkNet_Reset) when PowerDown = '1' or
		-- ClockNetwork_Reset = '1'.
		-- ======================================================================
		ClkNet_Reset <= PowerDown(i) or ClockNetwork_Reset(i);
		
		ClkNet : entity PoC.sata_Transceiver_Series7_GTPE2_ClockNetwork
			generic map (
				DEBUG											=> DEBUG,
				CLOCK_IN_FREQ							=> REFCLOCK_FREQ,										-- 150 MHz
				INITIAL_SATA_GENERATION		=> INITIAL_SATA_GENERATIONS(i)			-- intial SATA Generation
			)
			port map (
				ClockIn_150MHz						=> VSS_Common_In.RefClockIn_150_MHz,
		
				ClockNetwork_Reset				=> ClkNet_Reset,
				ClockNetwork_ResetDone		=> ClkNet_ResetDone,
		
				SATAGeneration						=> RP_SATAGeneration(i),
		
				GTP_Clock_2X							=> GTP_UserClock,
				GTP_Clock_4X							=> GTP_UserClock2
			);

		SATA_Clock_i			<= GTP_UserClock2;
		SATA_Clock(i)			<= SATA_Clock_i;

		-- ======================================================================
		-- Use generic module to generate SATA_Clock_Stable and ResetDone
		-- requires a MAXSKEW constraint of the signal driving Async_Reset
		-- ======================================================================
		ClockStable: entity work.sata_Transceiver_ClockStable
			port map (
				Async_Reset				=> ClkNet_Reset,
				PLL_Locked				=> ClkNet_ResetDone,
				SATA_Clock				=> SATA_Clock_i,
				Kill_Stable				=> Kill_SATA_Clock_Stable,
				ResetDone					=> ResetDone_i,
				SATA_Clock_Stable => SATA_Clock_Stable_i
			);

		SATA_Clock_Stable(i) 	<= SATA_Clock_Stable_i;
		ResetDone(i)					<= ResetDone_i;

		-- =========================================================================
		-- Control FSM for Transceiver Status
		-- =========================================================================
		process(SATA_Clock_i)
		begin
			if rising_edge(SATA_Clock_i) then
				if SATA_Clock_Stable_i = '1' then
					if (ResetDone_i = '0') then
						State <= ST_RESET;
					else
						State		<= NextState;
					end if;

					GTP_Reset_by_FSM_d <= GTP_Reset_by_FSM;
				end if;
			end if;
		end process;

		process(State, Command, Reset,
						OOB_HandshakeComplete, OOB_TX_Command,
						SATA_Clock_Stable_i, GTP_TX_ResetDone, GTP_RX_ResetDone)
		begin
			NextState				<= State;

			Status_i				<= SATA_TRANSCEIVER_STATUS_INIT;
			Error_i.Common	<= SATA_TRANSCEIVER_ERROR_NONE;

			Kill_SATA_Clock_Stable <= '0';
			GTP_Reset_by_FSM	<= '0'; -- if asserted, then NextState must be ST_RESET_BY_FSM
			case State is
				when ST_RESET =>
					Status_i			<= SATA_TRANSCEIVER_STATUS_INIT;

					if (Reset(i) = '1') then
						GTP_Reset_by_FSM <= '1';
						NextState <= ST_RESET_BY_FSM;

					elsif (GTP_RX_ResetDone = '1') then
						-- Normally, TX will be ready after ~316 clock cycles and RX after
						-- ~2516 clock cycles.
						if (GTP_TX_ResetDone = '0') then
							-- TX seems not to get ready. Try Again.
							GTP_Reset_by_FSM <= '1';
							NextState	 <= ST_RESET_BY_FSM;
						else
							NextState			<= ST_READY;
						end if;
					end if;

				when ST_RESET_BY_FSM =>
					-- GTP_Reset_by_FSM_d is asserted in this cycle. This signal drives
					-- the asynchronous GTTXRESET and GTRXRESET inputs of the
					-- transceiver. Thus, glitches due to binary encoding of the FSM state
					-- must be avoided. This is achieved by asserting GTP_Reset_by_FSM
					-- and switching to this state.
					Status_i			<= SATA_TRANSCEIVER_STATUS_INIT;

					if Reset(i) = '1' then
							-- stay here as long as reset is asserted and hold GTP reset
							GTP_Reset_by_FSM <= '1';
					else
						NextState <= ST_RESET;
					end if;

				when ST_READY =>
					Status_i			<= SATA_TRANSCEIVER_STATUS_READY;

					if (Reset(i) = '1') then
						NextState		<= ST_RESET_BY_FSM;
						GTP_Reset_by_FSM <= '1';

					elsif (OOB_HandshakeComplete(i) = '1') then
						-- GTP_RX_Reset is asserted below
						NextState		<= ST_CLEAR_RX_BUF;

					else
						null;		-- TODO: reconfig?

					end if;


				when ST_CLEAR_RX_BUF =>
					-- RX buffer must be cleared after OOB handshake. Do not report errors.
					Status_i			<= SATA_TRANSCEIVER_STATUS_READY;

					if (Reset(i) = '1') then
						NextState		<= ST_RESET_BY_FSM;
						GTP_Reset_by_FSM <= '1';

					elsif GTP_RX_ResetDone = '1' then
						NextState		<= ST_COMMUNICATION;
					end if;


				when ST_COMMUNICATION =>
					Status_i			<= SATA_TRANSCEIVER_STATUS_READY;

					if (Reset(i) = '1') then
						NextState		<= ST_RESET_BY_FSM;
						GTP_Reset_by_FSM <= '1';

					elsif (OOB_TX_Command(i) /= SATA_OOB_NONE) then
						NextState			<= ST_READY;
					end if;

					-- Note: Do not signal TX / RX errors by STATUS_ERROR, because they
					-- are only informative! Only common errors (e.g. due to reconfiguration)
					-- are signaled this way.

				when ST_RECONFIGURATION =>
					-- Assert Kill_SATA_Clock_Stable before ClkNet_Reset is asserted
					-- Assert only if ClkNet_ResetDone will really go low!
					Status_i			<= SATA_TRANSCEIVER_STATUS_RECONFIGURING;

					null;
			end case;
		end process;

		-- Encode RX/TX Errors
		-- TODO: Also report via RX Datapath to LinkLayer (RX_DecErr)
		process(SATA_Clock_i)
		begin
			if rising_edge(SATA_Clock_i) then
				Error_i.TX			<= SATA_TRANSCEIVER_TX_ERROR_NONE;
				Error_i.RX			<= SATA_TRANSCEIVER_RX_ERROR_NONE;

				if (GTP_TX_BufferStatus(1)	= '1') then
					Error_i.TX	<= SATA_TRANSCEIVER_TX_ERROR_BUFFER;
				end if;

				-- RX errors
				if (GTP_RX_ByteIsAligned	= '0') then
					Error_i.RX	<= SATA_TRANSCEIVER_RX_ERROR_ALIGNEMENT;
				elsif (slv_or(GTP_RX_DisparityError)	= '1') then
					Error_i.RX	<= SATA_TRANSCEIVER_RX_ERROR_DISPARITY;
				elsif (slv_or(GTP_RX_NotInTableError)	= '1') then
					Error_i.RX	<= SATA_TRANSCEIVER_RX_ERROR_DECODER;
				elsif (GTP_RX_BufferStatus(2)	= '1') then
					Error_i.RX	<= SATA_TRANSCEIVER_RX_ERROR_BUFFER;
				end if;
			end if;
		end process;

		Status(i)		<= Status_i;
		Error(i)		<= Error_i;

		-- =========================================================================
		-- GTP Power and Clock control
		-- =========================================================================
		GTP_TX_PowerDown									<= PowerDown(i) & PowerDown(i);
		GTP_RX_PowerDown									<= PowerDown(i) & PowerDown(i);

		ClockNetwork_ResetDone_i					<= QuadPLL_Locked_async(QUADPLL_PORTID) and ClkNet_ResetDone;	-- @async
		ClockNetwork_ResetDone(i)					<= ClockNetwork_ResetDone_i;


		-- =========================================================================
		-- Reset control
		-- =========================================================================
		-- Transceiver resets
		--	 QuadPLL_Locked will be asserted some clock cycles after QuadPLL_Locked_async
		--	 Thus GTP_Reset will be deasserted some time after the QuadPLL gets locked.
		GTP_Reset											<= (not QuadPLL_Locked_async(QUADPLL_PORTID)) or (not QuadPLL_Locked) or GTP_Reset_by_FSM_d; -- or GTP_ReloadConfig;
		-- TX resets
		GTP_TX_Reset									<= GTP_Reset;
		GTP_TX_PMAReset								<= '0';
		GTP_TX_PCSReset								<= '0';
		-- RX resets
		GTP_RX_Reset									<= GTP_Reset or OOB_HandshakeComplete(i);
		GTP_RX_PMAReset								<= '0';
		GTP_RX_PCSReset								<= '0';
		GTP_RX_BufferReset						<= '0';

		-- =========================================================================
		-- LineRate control / linerate clock divider selection / reconfiguration port
		-- =========================================================================
--		GTP_DRP_Enable								<= '0';
--		GTP_DRP_ReadWrite							<= '0';
--		GTP_DRP_Address								<= "000000000";
--		GTP_DRP_DataIn								<= x"0000";
		--	<float>										<= GTP_DRP_DataOut;
		--	<float>										<= GTP_DRP_Ack;

		process(SATA_Clock_i)
		begin
			if rising_edge(SATA_Clock_i) then
				if (Reset(i) = '1') then
					GTP_TX_LineRateSelect			<= to_ClockDividerSelection(INITIAL_SATA_GENERATIONS_I(i));
					GTP_RX_LineRateSelect			<= to_ClockDividerSelection(INITIAL_SATA_GENERATIONS_I(i));
				elsif (RP_Reconfig(i)	= '1') then
					GTP_TX_LineRateSelect		<= to_ClockDividerSelection(RP_SATAGeneration(i));
					GTP_RX_LineRateSelect		<= to_ClockDividerSelection(RP_SATAGeneration(i));
				end if;
			end if;
		end process;

		-- RS-FF															Q											rst															set																	clk
		TX_RateChangeDone <= ffrs(q => TX_RateChangeDone, rst => RP_Reconfig(i), set => GTP_TX_LineRateSelectDone) when rising_edge(SATA_Clock_i);
		RX_RateChangeDone <= ffrs(q => RX_RateChangeDone, rst => RP_Reconfig(i), set => GTP_RX_LineRateSelectDone) when rising_edge(SATA_Clock_i);

		RateChangeDone		<= TX_RateChangeDone and RX_RateChangeDone;
		RateChangeDone_d	<= RateChangeDone when rising_edge(SATA_Clock_i);
		RateChangeDone_re	<= not RateChangeDone_d and RateChangeDone;

		-- reconfiguration port
		RP_Locked(i)						<= '0';																							-- all ports are independant	=> never set a lock
		RP_Reconfig_d						<= RP_Reconfig(i) when rising_edge(SATA_Clock_i);	-- delay reconfiguration command
		RP_ReconfigComplete(i)	<= RP_Reconfig_d;																		-- acknoledge reconfiguration with 1 cycle latency
		RP_ConfigReloaded(i)		<= RateChangeDone_re;																-- acknoledge reload

		-- ==================================================================
		-- DRP - dynamic reconfiguration port
		-- ==================================================================
--		GTPConfig : entity PoC.sata_Transceiver_Series7_GTPE2_Configurator
--			generic map (
--				DEBUG											=> DEBUG,
--				DRPCLOCK_FREQ							=> REFCLOCK_FREQ,
--				INITIAL_SATA_GENERATION		=> INITIAL_SATA_GENERATIONS(i)
--			)
--			port map (
--				DRP_Clock									=> GTP_DRP_Clock,
--				DRP_Reset									=> '0',														-- @DRP_Clock
--				SATA_Clock								=> SATA_Clock_i,
--
--				Reconfig									=> RP_Reconfig(i),								-- @SATA_Clock
--				SATAGeneration						=> RP_SATAGeneration(i),					-- @SATA_Clock
--				ReconfigComplete					=> RP_ReconfigComplete(i),				-- @SATA_Clock
--				ConfigReloaded						=> RP_ConfigReloaded(i),					-- @SATA_Clock
--
--				GTP_DRP_Enable						=> GTPConfig_Enable,							-- @DRP_Clock
--				GTP_DRP_Address						=> GTPConfig_Address,							-- @DRP_Clock
--				GTP_DRP_ReadWrite					=> GTPConfig_ReadWrite,						-- @DRP_Clock
--				GTP_DRP_DataIn						=> DRPMux_In_DataOut(0),					-- @DRP_Clock
--				GTP_DRP_DataOut						=> GTPConfig_DataOut,							-- @DRP_Clock
--				GTP_DRP_Ack								=> DRPMux_Ack(0),								-- @DRP_Clock
--
--				GTP_ReloadConfig					=> open,								--GTP_ReloadConfig,							-- @DRP_Clock
--				GTP_ReloadConfigDone			=> ResetDone_r					-- @DRP_Clock
--			);
--
--		DRPSync : entity PoC.xil_DRP_BusSync
--			port map (
--				In_Clock			=> DebugPortIn(i).DRP.Clock,
--				In_Reset			=> '0',
--				In_Enable			=> DebugPortIn(i).DRP.Enable,
--				In_Address		=> DebugPortIn(i).DRP.Address,
--				In_ReadWrite	=> DebugPortIn(i).DRP.ReadWrite,
--				In_DataIn			=> DebugPortIn(i).DRP.Data,
--				In_DataOut		=> DebugPortOut(i).DRP.Data,
--				In_Ack				=> DebugPortOut(i).DRP.Ack,
--
--				Out_Clock			=> GTP_DRP_Clock,
--				Out_Reset			=> '0',
--				Out_Enable		=> DRPSync_Enable,
--				Out_Address		=> DRPSync_Address,
--				Out_ReadWrite	=> DRPSync_ReadWrite,
--				Out_DataIn		=> DRPMux_In_DataOut(1),
--				Out_DataOut		=> DRPSync_DataOut,
--				Out_Ack				=> DRPMux_Ack(1)
--			);
--
--		DRPMux : entity PoC.xil_DRP_BusMux
--			generic map (
--				DEBUG							=> DEBUG,
--				PORTS							=> 2
--			)
--			port map (
--				Clock							=> GTP_DRP_Clock,
--				Reset							=> '0',
--
--				In_Enable(0)			=> GTPConfig_Enable,
--				In_Enable(1)			=> DRPSync_Enable,
--				In_Address(0)			=> GTPConfig_Address,
--				In_Address(1)			=> DRPSync_Address,
--				In_ReadWrite(0)		=> GTPConfig_ReadWrite,
--				In_ReadWrite(1)		=> DRPSync_ReadWrite,
--				In_DataIn(0)			=> GTPConfig_DataOut,
--				In_DataIn(1)			=> DRPSync_DataOut,
--				In_DataOut				=> DRPMux_In_DataOut,
--				In_Ack						=> DRPMux_Ack,
--
--				Out_Enable				=> GTP_DRP_Enable,
--				Out_Address				=> GTP_DRP_Address,
--				Out_ReadWrite			=> GTP_DRP_ReadWrite,
--				Out_DataIn				=> GTP_DRP_DataOut,
--				Out_DataOut				=> GTP_DRP_DataIn,
--				Out_Ack						=> GTP_DRP_Ack
--			);

		-- ==================================================================
		-- Data path / status / error detection
		-- ==================================================================
		-- TX path
		GTP_TX_Data							<= TX_Data(i)			when rising_edge(SATA_Clock_i);
		GTP_TX_CharIsK					<= TX_CharIsK(i)	when rising_edge(SATA_Clock_i);

		-- RX path
		RX_Data(i)							<= GTP_RX_Data		when rising_edge(SATA_Clock_i);
		RX_CharIsK(i)						<= GTP_RX_CharIsK	when rising_edge(SATA_Clock_i);
		RX_Valid(i)							<= '1'; -- do not use undocumented RXVALID output of transceiver

--		GTP_PhyStatus
--		GTP_TX_BufferStatus
--		GTP_RX_BufferStatus
--		GTP_RX_Status
--		GTP_RX_ClockCorrectionStatus

		sync1_RXUserClock : entity PoC.sync_Bits_Xilinx
			generic map (
				BITS			=> 2																			-- number of BITS to synchronize
			)
			port map (
				Clock			=> SATA_Clock_i,													-- Clock to be synchronized to
				Input(0)	=> QuadPLL_Locked_async(QUADPLL_PORTID),	-- Data to be synchronized
				Input(1)	=> GTP_RX_ElectricalIDLE_async,						--
				Output(0)	=> QuadPLL_Locked,												-- synchronised data
				Output(1)	=> GTP_RX_ElectricalIDLE									--
			);

		filter1 : entity PoC.filter_and
			generic map (
				TAPS			=> 3
			)
			port map (
				Clock			=> SATA_Clock_i,
				DataIn		=> GTP_RX_ElectricalIDLE,
				DataOut		=> RX_ElectricalIDLE
			);

		--	==================================================================
		-- OOB signaling
		--	==================================================================
		OOB_TX_Command_d						<= OOB_TX_Command(i) when DebugPortIn(i).ForceOOBCommand = SATA_OOB_NONE else DebugPortIn(i).ForceOOBCommand;	-- when rising_edge(GTP_ClockTX_2X(i));

		-- TX OOB signals (generate GTP specific OOB signals)
		process(OOB_TX_Command_d, PowerDown(i), RP_SATAGeneration(i), GTP_TX_ComInit_r, GTP_TX_ComWake_r, GTP_TX_ComSAS_r)
		begin
			OOBTO_Load						<= '0';
			OOBTO_Slot						<= 0;
			OOBTO_en							<= GTP_TX_ComInit_r or GTP_TX_ComWake_r or GTP_TX_ComSAS_r;

			GTP_TX_ElectricalIDLE	<= PowerDown(i);

			GTP_TX_ComInit_set		<= '0';
			GTP_TX_ComWake_set		<= '0';
			GTP_TX_ComSAS_set			<= '0';

			case OOB_TX_Command_d is
				when SATA_OOB_NONE =>
					null;

				when SATA_OOB_COMRESET =>
					GTP_TX_ComInit_set	<= '1';
					OOBTO_Load					<= '1';
					case RP_SATAGeneration(i) is
						when SATA_GENERATION_1 =>		OOBTO_Slot	<= TTID_COMRESET_TIMEOUT_GEN1;
						when SATA_GENERATION_2 =>		OOBTO_Slot	<= TTID_COMRESET_TIMEOUT_GEN2;
						when SATA_GENERATION_3 =>		OOBTO_Slot	<= TTID_COMRESET_TIMEOUT_GEN3;
						when others =>							OOBTO_Slot	<= TTID_COMRESET_TIMEOUT_GEN3;
					end case;

				when SATA_OOB_COMWAKE	=>
					GTP_TX_ComWake_set	<= '1';
					OOBTO_Load					<= '1';
					case RP_SATAGeneration(i) is
						when SATA_GENERATION_1 =>		OOBTO_Slot	<= TTID_COMWAKE_TIMEOUT_GEN1;
						when SATA_GENERATION_2 =>		OOBTO_Slot	<= TTID_COMWAKE_TIMEOUT_GEN2;
						when SATA_GENERATION_3 =>		OOBTO_Slot	<= TTID_COMWAKE_TIMEOUT_GEN3;
						when others =>							OOBTO_Slot	<= TTID_COMWAKE_TIMEOUT_GEN3;
					end case;

				when SATA_OOB_COMSAS =>
					GTP_TX_ComSAS_set		<= '1';
					OOBTO_Load					<= '1';
					case RP_SATAGeneration(i) is
						when SATA_GENERATION_1 =>		OOBTO_Slot	<= TTID_COMSAS_TIMEOUT_GEN1;
						when SATA_GENERATION_2 =>		OOBTO_Slot	<= TTID_COMSAS_TIMEOUT_GEN2;
						when SATA_GENERATION_3 =>		OOBTO_Slot	<= TTID_COMSAS_TIMEOUT_GEN3;
						when others =>							OOBTO_Slot	<= TTID_COMSAS_TIMEOUT_GEN3;
					end case;

				when others =>
					null;

			end case;
		end process;

		OOBTO : entity PoC.io_TimingCounter
			generic map (
				TIMING_TABLE	=> TIMING_TABLE				-- timing table
			)
			port map (
				Clock					=> SATA_Clock_i,
				Enable				=> OOBTO_en,
				Load					=> OOBTO_Load,
				Slot					=> OOBTO_Slot,
				Timeout				=> OOBTO_Timeout
			);

		GTP_RX_ElectricalIDLE_Mode	<= ffdre(q => GTP_RX_ElectricalIDLE_Mode, d => "11", rst => to_sl(OOB_TX_Command_d /= SATA_OOB_NONE), en => OOB_HandshakeComplete(i)) when rising_edge(SATA_Clock_i);

		-- TX OOB sequence is complete
		OOBTO_Timeout_d			<= OOBTO_Timeout when rising_edge(SATA_Clock_i);
		TX_ComFinish				<= not OOBTO_Timeout_d and OOBTO_Timeout;		-- GTP_TX_ComFinish is not always generated -> replaced by a timer workaround
		OOB_TX_Complete(i)	<= TX_ComFinish;

		-- hold registers; hold GTP_TX_Com* signal until sequence is complete
		GTP_TX_ComInit_r	<= ffsr(q => GTP_TX_ComInit_r,	rst => TX_ComFinish, set => GTP_TX_ComInit_set)	when rising_edge(SATA_Clock_i);
		GTP_TX_ComWake_r	<= ffsr(q => GTP_TX_ComWake_r,	rst => TX_ComFinish, set => GTP_TX_ComWake_set)	when rising_edge(SATA_Clock_i);
		GTP_TX_ComSAS_r		<= ffsr(q => GTP_TX_ComSAS_r,		rst => TX_ComFinish, set => GTP_TX_ComSAS_set)	when rising_edge(SATA_Clock_i);

		GTP_TX_ComInit		<= GTP_TX_ComInit_r;
		GTP_TX_ComWake		<= GTP_TX_ComWake_r;
		GTP_TX_ComSAS			<= GTP_TX_ComSAS_r;

		-- RX OOB signals (generate generic RX OOB status signals)
		process(RX_ElectricalIDLE, GTP_RX_ComInitDetected, GTP_RX_ComWakeDetected, GTP_RX_ComSASDetected)
		begin
			if (GTP_RX_ComInitDetected	= '1') then
				OOB_RX_Received_i			<= SATA_OOB_COMRESET;
			elsif (GTP_RX_ComWakeDetected	= '1') then
				OOB_RX_Received_i			<= SATA_OOB_COMWAKE;
			elsif (GTP_RX_ComSASDetected	= '1') then
				OOB_RX_Received_i			<= SATA_OOB_COMSAS;
			elsif (RX_ElectricalIDLE	= '1') then
				OOB_RX_Received_i			<= SATA_OOB_READY;
			else
				OOB_RX_Received_i		 	<= SATA_OOB_NONE;
			end if;
		end process;

		OOB_RX_Received(i)		<= OOB_RX_Received_i;

		GTP_RX_CDR_Hold <= ffrs(q => GTP_RX_CDR_Hold, rst => OOB_AlignDetected(i), set => to_sl(OOB_TX_Command_d /= SATA_OOB_NONE)) when rising_edge(SATA_Clock_i);

		-- ==================================================================
		-- GTPE2_CHANNEL instance for Port I
		-- ==================================================================
		GTP : GTPE2_CHANNEL
			generic map (
				-- Simulation-Only attributes
				SIM_RECEIVER_DETECT_PASS								=> "TRUE",
				SIM_RESET_SPEEDUP												=> "TRUE",										-- set to "TRUE" to speed up simulation reset
				SIM_TX_EIDLE_DRIVE_LEVEL								=> "X",
				SIM_VERSION															=> "2.0",		-- GTXE2 "4.0"

				-- PLL clock attributes																								-- A reference input clock of 150 MHz,
 				SATA_PLL_CFG														=> "VCO_3000MHZ",							--
				RXOUT_DIV																=> 4,													--
				TXOUT_DIV																=> 4,													--

				TX_XCLK_SEL															=> "TXOUT",
				RX_XCLK_SEL															=> "RXREC",

				TX_CLK25_DIV														=> 8,	-- GTXE2 6,													-- Clock divider for TX internal working clock?
				RX_CLK25_DIV														=> 8,	-- GTXE2 6,													-- Clock divider for RX internal working clock?
				OUTREFCLK_SEL_INV												=> "11",											-- Select signal for GTREFCLKMONITOR output. 0 => Non-inverted GTREFCLKMONITOR output; 1 => Inverted GTREFCLKMONITOR output

				-- Power-Down attributes
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
				RXBUFRESET_TIME													=> "00001",										-- reserved; represents the time duration to apply the RX BUFFER reset

				-- TX buffer attributes
				TX_DATA_WIDTH														=> 40,
				TXBUF_EN																=> "TRUE",
				TXBUF_RESET_ON_RATE_CHANGE							=> "TRUE",
				TXPH_CFG																=> x"0780",
				TXPHDLY_CFG															=> x"084020",
				TXPH_MONITOR_SEL												=> "00000",
				TXDLY_CFG																=> x"001F",
				TXDLY_LCFG															=> x"030",
				TXDLY_TAP_CFG														=> x"0000",

				RX_DATA_WIDTH														=> 40,
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
				ALIGN_COMMA_WORD												=> 1,-- GTXE2 4,													-- Align comma-byte => [byte3][byte2][byte1][comma0]
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
				CLK_COR_KEEP_IDLE												=> "FALSE",										-- see UG476, p. 261
				CLK_COR_MIN_LAT													=> 12,	-- GTPE2	11	-- GTXE2 24,												-- GTXE2 3..60, divisible by 4
				CLK_COR_MAX_LAT													=> 19,	-- GTPE2	16	-- GTXE2 31,												-- GTXE2 3..60
				CLK_COR_PRECEDENCE											=> "TRUE",
				CLK_COR_REPEAT_WAIT											=> 0,													-- 0 => ClockCorrection can occur at any time (see UG476, p. 261)
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
				ES_EYE_SCAN_EN													=> "FALSE",	-- GTXE2 "TRUE",
				ES_ERRDET_EN														=> "FALSE",
				ES_CONTROL															=> "000000",
				ES_HORZ_OFFSET													=> x"000",
				ES_PMA_CFG															=> "0000000000",
				ES_PRESCALE															=> "00000",
				ES_QUALifIER														=> x"00000000000000000000",
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
				SAS_MIN_COM															=> 36,
				SAS_MAX_COM															=> 64,

				-- PMA attributes
				PMA_RSV																	=> x"00000333",	-- GTXE2	x"00018480",						-- GTXE2: reserved; These bits relate to RXPI and are line rate dependent:
																																					-- GTXE2: 	0x00018480 => Lower line rates: CPLL full range and 6 GHz = QPLL VCO rate < 6.6 GHz
																																					-- GTXE2: 	0x001E7080 => Higher line rates: QPLL > 6.6 GHz
				PMA_RSV2																=> x"00002040",						-- GTXE2: PMA_RSV2(5) = 0; set to '1' if eye-scan circuit should be powered-up
				PMA_RSV3																=> "00",
				PMA_RSV4																=> x"00000000",
				PMA_RSV5																=> '0',	-- GTPE2
				PMA_RSV6																=> '0',	-- GTPE2
				PMA_RSV7																=> '0',	-- GTPE2
				RX_BIAS_CFG															=> "0000111100110011",	-- GTXE2	"000000000100",
				DMONITOR_CFG														=> x"000A00",	-- GTXE2	x"000A01",							-- GTXE2: DMONITOR_CFG(0) enable digital monitor
				RX_CM_SEL																=> "11",									-- RX termination voltage: 00 => AVTT; 01 => GND; 10 => Floating; 11 => programmable (PMA_RSV(4) & RX_CM_TRIM)
				RX_CM_TRIM															=> "1010",-- GTXE2	"1011",										-- RX termination voltage: 1010 => 800 mV; 1011 => 850 mV
				RX_DEBUG_CFG														=> "000000001000",				-- connect LPM HF to DMONITOROUT [6:0]
				RX_OS_CFG																=> "0000010000000",
				TERM_RCAL_CFG														=> "100001000010000",	-- GTXE2	"10000",								-- Controls the internal termination calibration circuit. This feature is intended for internal testing purposes only.
				TERM_RCAL_OVRD													=> "000",	--GTXE2	'0',										-- Selects whether the external 100?? precision resistor is connected to the MGTRREF pin or a value defined by TERM_RCAL_CFG [4:0]. This feature is intended for internal testing purposes only.
				TST_RSV																	=> x"00000000",
				UCODEER_CLR															=> '0',

				-- PCS attributes
				PCS_PCIE_EN															=> "FALSE",


				PCS_RSVD_ATTR														=> GTP_PCS_RSVD_ATTR,			--

				-- CDR attributes
				RXCDR_CFG																=> GTP_RXCDR_CFG,					--
				RXCDR_FR_RESET_ON_EIDLE									=> '0',										-- feature not used due to spurious RX_ElectricalIdle
				RXCDR_HOLD_DURING_EIDLE									=> '0',										-- feature not used due to spurious RX_ElectricalIdle
				RXCDR_PH_RESET_ON_EIDLE									=> '0',										-- feature not used due to spurious RX_ElectricalIdle
				RXCDR_LOCK_CFG													=> "001001",	-- GTXE2	"010101",							-- [5:3] Window Size, [2:1] Delta Code, [0] Enable Detection (https://github.com/ShepardSiegel/ocpi/blob/master/coregen/pcie_4243_axi_k7_x4_125/source/pcie_7x_v1_3_gt_wrapper.v)

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
				RXLPM_HF_CFG														=> "00000011110000",			-- GTXE2: long channel; >2.5 dB loss
-- GTXE2				RXLPM_HF_CFG														=> "00000000000000",				-- GTXE2: short channel; <2.5 dB loss
				RXLPM_LF_CFG														=> "000000001111110000",			-- GTXE2: long channel; >2.5 dB loss
-- GTXE2				RXLPM_LF_CFG														=> "00000000000000",				-- GTXE2: short channel; <2.5 dB loss

				-- TX configurable driver attributes
				TX_PREDRIVER_MODE												=> '0',
				
				-- new attributes for the GTPE2 transceiver compared to GTXE2
				------------------ JTAG Attributes ---------------
				ACJTAG_DEBUG_MODE												=> '0',
				ACJTAG_MODE															=> '0',
				ACJTAG_RESET														=> '0',
				------------------ CDR Attributes ---------------
				CFOK_CFG																=> x"49000040E80",
				CFOK_CFG2																=> "0100000",
				CFOK_CFG3																=> "0100000",
				CFOK_CFG4																=> '0',
				CFOK_CFG5																=> x"0",
				CFOK_CFG6																=> "0000",
				RXOSCALRESET_TIME												=> "00011",
				RXOSCALRESET_TIMEOUT										=> "00000",
				------------------ PMA Attributes ---------------
				CLK_COMMON_SWING												=> '0',
				RX_CLKMUX_EN														=> '1',
				TX_CLKMUX_EN														=> '1',
				ES_CLK_PHASE_SEL												=> '0',
				USE_PCS_CLK_PHASE_SEL										=> '0',
				------------------ RX Phase Interpolator Attributes---------------
				RXPI_CFG0																=> "000",
				RXPI_CFG1																=> '1',
				RXPI_CFG2																=> '1',
				--------------RX Equalizer Attributes-------------
				ADAPT_CFG0															=> x"00000",
				RXLPMRESET_TIME													=> "0001111",
				RXLPM_BIAS_STARTUP_DISABLE							=> '0',
				RXLPM_CFG																=> "0110",
				RXLPM_CFG1															=> '0',
				RXLPM_CM_CFG														=> '0',
				RXLPM_GC_CFG														=> "111100010",
				RXLPM_GC_CFG2														=> "001",
				RXLPM_HF_CFG2														=> "01010",
				RXLPM_HF_CFG3														=> "0000",
				RXLPM_HOLD_DURING_EIDLE									=> '0',
				RXLPM_INCM_CFG													=> '1',
				RXLPM_IPCM_CFG													=> '0',
				RXLPM_LF_CFG2														=> "01010",
				RXLPM_OSINT_CFG													=> "100",
				------------------ TX Phase Interpolator PPM Controller Attributes---------------
				TXPI_CFG0																=> "00",
				TXPI_CFG1																=> "00",
				TXPI_CFG2																=> "00",
				TXPI_CFG3																=> '0',
				TXPI_CFG4																=> '0',
				TXPI_CFG5																=> "000",
				TXPI_GREY_SEL														=> '0',
				TXPI_INVSTROBE_SEL											=> '0',
				TXPI_PPMCLK_SEL													=> "TXUSRCLK2",
				TXPI_PPM_CFG														=> x"00",
				TXPI_SYNFREQ_PPM												=> "001",
				------------------ LOOPBACK Attributes---------------
				LOOPBACK_CFG														=> '0',
				PMA_LOOPBACK_CFG												=> '0',
				------------------RX OOB Signalling Attributes---------------
				RXOOB_CLK_CFG														=> "PMA",
				------------------TX OOB Signalling Attributes---------------
				TXOOB_CFG																=> '0',
				------------------RX Buffer Attributes---------------
				RXSYNC_MULTILANE												=> '0',
				RXSYNC_OVRD															=> '0',
				RXSYNC_SKIP_DA													=> '0',
				------------------TX Buffer Attributes---------------
				TXSYNC_MULTILANE												=> '0',
				TXSYNC_OVRD															=> '1',
				TXSYNC_SKIP_DA													=> '0'
			)
			port map (
				-- clock selects and clock inputs
				PLL0CLK													=> QuadPLL_HFClock(0),
				PLL0REFCLK											=> QuadPLL_RefClock(0),
				PLL1CLK													=> '0',
				PLL1REFCLK											=> '0',

				-- internal clock selects and clock outputs
				TXSYSCLKSEL											=> "00",													-- @async:		00 => use QuadPLL PLL0 for HF clock and GTPE2_CHANNEL refclock; 11 => use QuadPLL PLL1
				TXOUTCLKSEL											=> "011",													-- @async:		011 => select TXPLLREFCLK_DIV1
				TXOUTCLKFABRIC									=> open,													-- @clock:		internal clock after TXSYSCLKSEL-mux
				TXOUTCLKPCS											=> open,													-- @clock:		internal clock from PCS sublayer
				TXOUTCLK												=> GTP_TX_RefClockOut,						-- @clock:		TX output clock

				RXSYSCLKSEL											=> "00",													-- @async:		00 => use QuadPLL PLL0 for HF clock and GTPE2_CHANNEL refclock; 11 => use QuadPLL PLL1
				RXOUTCLKSEL											=> "010",													-- @async:		010 => select RXOUTCLKPMA
				RXOUTCLKFABRIC									=> open,													-- @clock:		internal clock after RXSYSCLKSEL-mux
				RXOUTCLKPCS											=> open,													-- @clock:		internal clock from PCS sublayer
				RXOUTCLK												=> GTP_RX_RefClockOut_float,			-- @clock:		RX output clock; phase aligned

				-- Power-Down ports
				TXPD														=> GTP_TX_PowerDown,							-- @TX_Clock2:	powers TX side down (S0, S0s, S1, S2)
				RXPD														=> GTP_RX_PowerDown,							-- @async:			powers RX side down (S0, S0s, S1, S2)

				-- GTP reset ports
				-- =====================================================================
				-- GTP reset mode
				CFGRESET												=> '0',														-- @async:			reserved;
				GTRESETSEL											=> '0',														-- @async:			0 => sequential mode (recommended)
				RESETOVRD												=> '0',														-- @async:			reserved; tie to ground
				-- TX resets
				GTTXRESET												=> GTP_TX_Reset,
				TXPCSRESET											=> GTP_TX_PCSReset,
				TXPMARESET											=> GTP_TX_PMAReset,
				TXPMARESETDONE									=> GTP_TX_PMAResetDone,		-- GTPE2
				-- RX resets
				GTRXRESET												=> GTP_RX_Reset,
				RXPCSRESET											=> GTP_RX_PCSReset,
				RXPMARESET											=> GTP_RX_PMAReset,
				RXPMARESETDONE									=> GTP_RX_PMAResetDone,	-- GTPE2
				RXBUFRESET											=> GTP_RX_BufferReset,						-- @async:
				RXOOBRESET											=> '0',														-- @async:			reserved; tie to ground
				EYESCANRESET										=> '0',
				RXCDRFREQRESET									=> '0',														-- @async:			CDR frequency detector reset
				RXCDRRESET											=> '0',														-- @async:			CDR phase detector reset
				RXPRBSCNTRESET									=> '0',														-- @RX_Clock2:	reset PRBS error counter
				-- reset done ports
				TXRESETDONE											=> GTP_TX_ResetDone,							-- @TX_Clock2:
				RXRESETDONE											=> GTP_RX_ResetDone,							-- @RX_Clock2:

				-- FPGA-Fabric interface clocks
				-- =====================================================================
				-- TX
				TXUSERRDY												=> SATA_Clock_Stable_i,						-- @async:			@TX_Clock2 is stable/locked
				TXUSRCLK												=> GTP_UserClock,									-- @clock:
				TXUSRCLK2												=> GTP_UserClock2,								-- @clock:
				-- RX
				RXUSERRDY												=> SATA_Clock_Stable_i,						-- @async:			@TX_Clock2 is stable/locked
				RXUSRCLK												=> GTP_UserClock,									-- @clock:
				RXUSRCLK2												=> GTP_UserClock2,								-- @clock:

				-- linerate clock divider selection
				-- =====================================================================
				-- TX
				TXRATE													=> GTP_TX_LineRateSelect,					-- @TX_Clock2:
				TXRATEDONE											=> GTP_TX_LineRateSelectDone,			-- @TX_Clock2:
				-- RX
				RXRATE													=> GTP_RX_LineRateSelect,					-- @RX_Clock2:
				RXRATEDONE											=> GTP_RX_LineRateSelectDone,			-- @RX_Clock2:

				-- Dynamic Reconfiguration Port (DRP)
				-- =====================================================================
				DRPCLK													=> GTP_DRP_Clock,									-- @DRP_Clock:
				DRPEN														=> GTP_DRP_Enable,								-- @DRP_Clock:
				DRPWE														=> GTP_DRP_ReadWrite,							-- @DRP_Clock:
				DRPADDR													=> GTP_DRP_Address(8 downto 0),		-- @DRP_Clock:
				DRPDI														=> GTP_DRP_DataIn,								-- @DRP_Clock:
				DRPDO														=> GTP_DRP_DataOut,								-- @DRP_Clock:
				DRPRDY													=> GTP_DRP_Ack,										-- @DRP_Clock:

				-- datapath configuration
				TX8B10BEN												=> '1',														-- @TX_Clock2:	enable 8B/10B encoder
				TX8B10BBYPASS										=> x"0",													-- @TX_Clock2:	per-byte 8B/10B encoder bypass enables; 0 => use encoder
				RX8B10BEN												=> '1',														-- @RX_Clock2:	enable 8B710B decoder

				-- FPGA-Fabric - TX interface ports
				TXDATA(31 downto 0)							=> GTP_TX_Data,										-- @TX_Clock2:
				TXCHARISK(3 downto 0)						=> GTP_TX_CharIsK,								-- @TX_Clock2:
				TXCHARDISPMODE									=> x"0",													-- @TX_Clock2:	per-byte set running disparity to TXCHARDISPVAL(i); TXCHARDISPMODE(0) is also called TXCOMPLIANCE in a PIPE interface
				TXCHARDISPVAL										=> x"0",													-- @TX_Clock2:	per-byte set running disparity

				-- FPGA-Fabric - RX interface ports
				RXDATA(31 downto 0)							=> GTP_RX_Data,										-- @RX_Clock2:
				RXVALID													=> open,													-- @RX_Clock2:

				RXCHARISCOMMA(3 downto 0)				=> GTP_RX_CharIsComma,						-- @RX_Clock2:
				RXCHARISK(3 downto 0)						=> GTP_RX_CharIsK,								-- @RX_Clock2:
				RXDISPERR(3 downto 0)						=> GTP_RX_DisparityError,					-- @RX_Clock2:
				RXNOTINTABLE(3 downto 0)				=> GTP_RX_NotInTableError,				-- @RX_Clock2:

				-- RX Byte and Word Alignment
				RXBYTEISALIGNED									=> GTP_RX_ByteIsAligned,
				RXBYTEREALIGN										=> GTP_RX_ByteRealign,
				RXCOMMADETEN										=> '1',
				RXMCOMMAALIGNEN									=> '1',
				RXPCOMMAALIGNEN									=> '1',
				RXCOMMADET											=> GTP_RX_CommaDetected,

				-- ElectricalIDLE and OOB ports
				TXELECIDLE											=> GTP_TX_ElectricalIDLE,					-- @TX_Clock2:
				RXELECIDLE											=> GTP_RX_ElectricalIDLE_async,		-- @async:
				TXPDELECIDLEMODE								=> '0',														-- @TX_Clock2:	treat TXPD and TXELECIDLE as asynchronous inputs
				RXELECIDLEMODE									=> GTP_RX_ElectricalIDLE_Mode,		-- @async:			indicate ElectricalIDLE on RXELECIDLE

				TXCOMINIT												=> GTP_TX_ComInit,								-- @TX_Clock2:
				TXCOMWAKE												=> GTP_TX_ComWake,								-- @TX_Clock2:
				TXCOMSAS												=> GTP_TX_ComSAS,									-- @TX_Clock2:
				TXCOMFINISH											=> GTP_TX_ComFinish,							-- @TX_Clock2:

				RXCOMINITDET										=> GTP_RX_ComInitDetected,				-- @RX_Clock2:
				RXCOMWAKEDET										=> GTP_RX_ComWakeDetected,				-- @RX_Clock2:
				RXCOMSASDET											=> GTP_RX_ComSASDetected,					-- @RX_Clock2:

				-- RX	LPM equalizer ports (LPM - low-power mode)
				RXLPMRESET											=> '0',
				RXLPMLFHOLD											=> '0',														-- @RX_Clock2:
				RXLPMLFOVRDEN										=> '0',	-- GTXE2: '1' (RXLPMLFKLOVRDEN ??)
				RXLPMHFHOLD											=> '0',														-- @RX_Clock2:
				RXLPMHFOVRDEN										=> '1',														-- @RX_Clock2:
				RXLPMOSINTNTRLEN								=> '0',

				-- RX	DFE equalizer ports (discrete-time filter equalizer)
				RXDFEXYDEN											=> '0',	-- GTXE2	'1',														-- @RX_Clock2:	reserved; tie to vcc

-- GTXE2				RXMONITORSEL										=> GTP_RX_Monitor_sel,
-- GTXE2				RXMONITOROUT										=> GTP_RX_Monitor_Data,
				RXOSHOLD												=> '0',
				RXOSOVRDEN											=> '0',	-- GTXE2	'1',

				-- Clock Data Recovery (CDR)
				RXCDRHOLD												=> GTP_RX_CDR_Hold,								-- @async:			hold the CDR control loop frozen
				RXCDRLOCK												=> RX_CDR_Locked,									-- @async:			reserved; CDR locked

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
				RXCHBONDI												=> "0000",												-- @RX_Clock:		Channel bond control port - data in
				RXCHANBONDSEQ										=> open,													-- @RX_Clock2:	RXDATA contains the start of a channel bonding sequence
				RXCHANISALIGNED									=> open,													-- @RX_Clock2:	RX elastic buffer is channel aligned
				RXCHANREALIGN										=> open,													-- @RX_Clock2:	RX elastic buffer changed channel alignment

				-- TX buffer bypass ports
				TXPHDLYTSTCLK										=> '0',														-- @clock:			TX phase and delay alignment test clock; used with TXDLYHOLD and TXDLYUPDOWN
				TXPHDLYPD												=> '0',	-- GTPE2	'1',														-- @async:
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
				PHYSTATUS												=> GTP_PhyStatus,									-- @RX_Clock2:
				TXBUFSTATUS											=> GTP_TX_BufferStatus,						-- @TX_Clock2:
				RXBUFSTATUS											=> GTP_RX_BufferStatus,						-- @RX_Clock2:	"1--" indicates buffer under/overflow
				RXSTATUS												=> GTP_RX_Status,									-- @RX_Clock2:
				RXCLKCORCNT											=> GTP_RX_ClockCorrectionStatus,	-- @RX_Clock2:	number of added or deleted ClockCorrection Words

				-- loopback port
				LOOPBACK												=> "000",													-- @async:			000 => normal operation

				-- Pseudo Random Bit Sequence (PRBS) test pattern generator/checker ports
				TXPRBSSEL												=> "000",													-- @TX_Clock2:	000 => normal operation; PRBS generator is off
				TXPRBSFORCEERR									=> '0',														-- @TX_Clock2:	1 => force errors in the PRBS transmitter

				RXPRBSSEL												=> "000",													-- @RX_Clock2:	000 => normal operation; PRBS checker is off
				RXPRBSERR												=> open,													-- @RX_Clock2:	PRBS error have occurred; error counter 'RX_PRBS_ERR_CNT' can only be accessed by DRP at address 0x15C

				-- Digital Monitor Ports
				DMONITOROUT											=> GTP_DigitalMonitor(14 downto 0),
				DMONFIFORESET										=> '0',	-- GTPE2
				DMONITORCLK											=> '0',	-- GTPE2

				EYESCANMODE											=> '0',														-- @async:
				EYESCANTRIGGER									=> '0',														-- @async:
				EYESCANDATAERROR								=> open,													-- @async:

				-- reserved ports
				GTRSVD													=> "0000000000000000",						-- @async:
				PCSRSVDIN												=> "0000000000000000",						-- @async:
-- GTXE2				PCSRSVDIN2											=> "00000",												-- @async:
-- GTXE2				PMARSVDIN												=> "00000",												-- @async:
				PMARSVDIN0											=> '0',														-- @async:
				PMARSVDIN1											=> '0',														-- @async:
				PMARSVDIN2											=> '0',	--GTXE2	"00000",												-- @async:
				PMARSVDIN3											=> '0',														-- @async:
				PMARSVDIN4											=> '0',														-- @async:
				TSTIN														=> "11111111111111111111",				-- @async:
-- GTXE2				TSTOUT													=> open,													-- @async:
-- GTXE2				CLKRSVD(0)											=> '0',														-- @clock:			alternative OOB clock; selectable by PCS_RSVD_ATTR(3) = '1'
-- GTXE2				CLKRSVD(3 downto 1)							=> "000",
				CLKRSVD0												=> '0',	-- GTPE2
				CLKRSVD1												=> '0',	-- GTPE2
				SETERRSTATUS										=> '0',														-- @async:			reserved; RX 8B/10B decoder port
				RXCDROVRDEN											=> '0',														-- @async:			reserved; CDR port
				RXCDRRESETRSV										=> '0',														-- @async:			reserved; CDR port
				PCSRSVDOUT											=> open,													-- @async:			reserved; PCS

				-- polarity control
				TXPOLARITY											=> '0',														-- @TX_Clock2:	invert the polarity of outgoing data
				RXPOLARITY											=> '0',														-- @RX_Clock2:	invert the polarity of incoming data (done after SIPO on bytes)

				-- TX configurable driver ports
				TXPISOPD												=> '0',														-- @async:			reserved; ParallelIn/SerialOut (PISO) power-down
				TXINHIBIT												=> '0',														-- @TX_Clock2:	forces GTPTXP to 0 and GTPTXN to 1
				TXDIFFPD												=> '0',														-- @async:			reserved; TX driver power-down
				TXDIFFCTRL											=> "1000",	-- GTPE2	"0101",												-- GTXE2: @TX_Clock2:	TX driver swing control [mV_PPD]; 0101 => 609 mV peak-peak-differential voltage
				TXBUFDIFFCTRL										=> "100",													-- @TX_Clock2:	TX pre-driver swing control; default is 100; do not modify
				TXDEEMPH												=> '0',														-- @TX_Clock2:	TX de-emphasis control
				TXMARGIN												=> "000",													-- @async:			TX margin control
				TXSWING													=> '0',														-- @async:			TX swing control; 0 => full swing; 1 => half-swing
				TXPRECURSOR											=> "00000",												-- @async:			TX pre-cursor pre-emphasis control
				TXPRECURSORINV									=> '0',														-- @async:			TX pre-cursor
				TXMAINCURSOR										=> "0000000",											-- @async:			TX main-cursur
				TXPOSTCURSOR										=> "00000",												-- @async:			TX post-cursor pre-emphasis control
				TXPOSTCURSORINV									=> '0',

				-- TX receiver detection ports
				TXDETECTRX											=> '0',														-- @TX_Clock2:	begin a receiver detection operation; 0 => normal operation; 1 => receiver detection

				-- new ports for the GTPE2 transceiver compared to GTXE2
				------------------------------- Receive Ports ------------------------------
				SIGVALIDCLK											=> '0',
				------------------------- Receive Ports - CDR Ports ------------------------
				RXOSCALRESET										=> '0',
				RXOSINTCFG											=> "0010",
				RXOSINTDONE											=> open,
				RXOSINTHOLD											=> '0',
				RXOSINTOVRDEN										=> '0',
				RXOSINTPD												=> '0',
				RXOSINTSTARTED									=> open,
				RXOSINTSTROBE										=> '0',
				RXOSINTSTROBESTARTED						=> open,
				RXOSINTTESTOVRDEN								=> '0',
				------------------------ Receive Ports - RX AFE Ports ----------------------
				PMARSVDOUT0											=> open,
				PMARSVDOUT1											=> open,
				------------------- Receive Ports - RX Buffer Bypass Ports -----------------
				RXSYNCALLIN											=> '0',
				RXSYNCDONE											=> open,
				RXSYNCIN												=> '0',
				RXSYNCMODE											=> '0',
				RXSYNCOUT												=> open,
				------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
				RXADAPTSELTEST									=> "00000000000000",
				RXOSINTEN												=> '1',
				RXOSINTID0											=> "0000",
				RXOSINTNTRLEN										=> '0',
				RXOSINTSTROBEDONE								=> open,
				----------- Receive Ports - RX Fabric Clock Output Control Ports	----------
				RXRATEMODE											=> '0',
				-------------------- TX Fabric Clock Output Control Ports ------------------
				TXRATEMODE											=> '0',
				----------------- TX Phase Interpolator PPM Controller Ports ---------------
				TXPIPPMEN												=> '0',
				TXPIPPMOVRDEN										=> '0',
				TXPIPPMPD												=> '0',
				TXPIPPMSEL											=> '1',
				TXPIPPMSTEPSIZE									=> "00000",
				------------ Transmit Ports - TX Buffer and Phase Alignment Ports ----------
				TXSYNCALLIN											=> '0',
				TXSYNCDONE											=> open,
				TXSYNCIN												=> '0',
				TXSYNCMODE											=> '0',
				TXSYNCOUT												=> open,

				-- Tranceiver physical ports
				GTPTXN													=> GTP_TX_n,											-- @analog:
				GTPTXP													=> GTP_TX_p,											-- @analog:
				GTPRXN													=> GTP_RX_n,											-- @analog:
				GTPRXP													=> GTP_RX_p												-- @analog:
			);

		GTP_RX_n									<= VSS_Private_In(i).RX_n;
		GTP_RX_p									<= VSS_Private_In(i).RX_p;
		VSS_Private_Out(i).TX_n		<= GTP_TX_n;
		VSS_Private_Out(i).TX_p		<= GTP_TX_p;

		GTP_DigitalMonitor(15 downto 15)	<= "0";

		genCSP0 : if (ENABLE_DEBUGPORT = FALSE) generate
			GTP_DRP_Clock									<= '0';
			GTP_DRP_Enable								<= '0';
			GTP_DRP_ReadWrite							<= '0';
			GTP_DRP_Address								<= (others => '0');
			GTP_DRP_DataIn								<= x"0000";
			--	<float>										<= GTP_DRP_DataOut;
			--	<float>										<= GTP_DRP_Ack;
		end generate;
		genCSP1 : if (ENABLE_DEBUGPORT = TRUE) generate
			function to_slv(Status : T_STATE) return std_logic_vector is
			begin
				return to_slv(T_STATE'pos(Status), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
			end function;

			function dbg_EncodeState(st : T_STATE) return std_logic_vector is
			begin
				return to_slv(T_STATE'pos(st), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
			end function;

			function dbg_GenerateStateEncodings return string is
				variable	l : STD.TextIO.line;
			begin
				for i in T_STATE loop
					STD.TextIO.write(l, str_replace(T_STATE'image(i), "st_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return	l.all;
			end function;

			function dbg_GenerateStatusEncodings return string is
				variable	l : STD.TextIO.line;
			begin
				for i in T_SATA_TRANSCEIVER_STATUS loop
					STD.TextIO.write(l, str_replace(T_SATA_TRANSCEIVER_STATUS'image(i), "sata_transceiver_status_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return	l.all;
			end function;

--			constant dummy : T_BOOLVEC := (
--				0 => dbg_ExportEncoding("Transceiver (7-Series, GTPE2)",		dbg_GenerateStateEncodings,		ite(SIMULATION, "", (PROJECT_DIR & "ChipScope/TokenFiles/")) & "FSM_Transceiver_Series7_GTPE2.tok"),
--				1 => dbg_ExportEncoding("Transceiver Layer - Status Enum",	dbg_GenerateStatusEncodings,	ite(SIMULATION, "", (PROJECT_DIR & "ChipScope/TokenFiles/")) & "ENUM_Transceiver_Status.tok")
--			);

		begin
			GTP_DRP_Clock			<= DebugPortIn(i).DRP.Clock;
			GTP_DRP_Enable		<= DebugPortIn(i).DRP.Enable;
			GTP_DRP_ReadWrite	<= DebugPortIn(i).DRP.ReadWrite;
			GTP_DRP_Address		<= DebugPortIn(i).DRP.Address;
			GTP_DRP_DataIn		<= DebugPortIn(i).DRP.Data;

			DebugPortOut(i).PowerDown									<= PowerDown(i);
			DebugPortOut(i).ClockNetwork_Reset				<= ClockNetwork_Reset(i);
			DebugPortOut(i).ClockNetwork_ResetDone		<= ClockNetwork_ResetDone_i;
			DebugPortOut(i).Reset											<= Reset(i);
			DebugPortOut(i).ResetDone									<= ResetDone_i;

			DebugPortOut(i).UserClock									<= SATA_Clock_i;
			DebugPortOut(i).UserClock_Stable					<= SATA_Clock_Stable_i;

			DebugPortOut(i).GTX_CPLL_PowerDown				<= QuadPLL_PowerDown(QUADPLL_PORTID);
			DebugPortOut(i).GTX_TX_PowerDown					<= GTP_TX_PowerDown(0);
			DebugPortOut(i).GTX_RX_PowerDown					<= GTP_RX_PowerDown(0);

			DebugPortOut(i).GTX_CPLL_Reset						<= QuadPLL_Reset(QUADPLL_PORTID);
			DebugPortOut(i).GTX_CPLL_Locked						<= QuadPLL_Locked_async(QUADPLL_PORTID);

			DebugPortOut(i).GTX_TX_Reset							<= GTP_TX_Reset;
			DebugPortOut(i).GTX_RX_Reset							<= GTP_RX_Reset;
			DebugPortOut(i).GTX_TX_ResetDone					<= GTP_TX_ResetDone;
			DebugPortOut(i).GTX_RX_ResetDone					<= GTP_RX_ResetDone;
			DebugPortOut(i).FSM												<= '0' & to_slv(State);

			DebugPortOut(i).OOB_Clock									<= '0';
			DebugPortOut(i).RP_SATAGeneration					<= RP_SATAGeneration(i);
			DebugPortOut(i).RP_Reconfig								<= RP_Reconfig(i);
			DebugPortOut(i).RP_ReconfigComplete				<= RP_Reconfig_d;
			DebugPortOut(i).RP_ConfigRealoaded				<= RateChangeDone_re;
			DebugPortOut(i).DD_NoDevice								<= '0';
			DebugPortOut(i).DD_NewDevice							<= '0';
			DebugPortOut(i).TX_RateSelection					<= GTP_TX_LineRateSelect;
			DebugPortOut(i).RX_RateSelection					<= GTP_RX_LineRateSelect;
			DebugPortOut(i).TX_RateSelectionDone			<= GTP_TX_LineRateSelectDone;
			DebugPortOut(i).RX_RateSelectionDone			<= GTP_RX_LineRateSelectDone;
			DebugPortOut(i).RX_CDR_Locked							<= RX_CDR_Locked;
			DebugPortOut(i).RX_CDR_Hold								<= GTP_RX_CDR_Hold;

			DebugPortOut(i).TX_Data										<= GTP_TX_Data;
			DebugPortOut(i).TX_CharIsK								<= GTP_TX_CharIsK;
			DebugPortOut(i).TX_BufferStatus						<= GTP_TX_BufferStatus;
			DebugPortOut(i).TX_ComInit								<= GTP_TX_ComInit_set;
			DebugPortOut(i).TX_ComWake								<= GTP_TX_ComWake_set;
			DebugPortOut(i).TX_ComFinish							<= TX_ComFinish;
			DebugPortOut(i).TX_ElectricalIDLE					<= GTP_TX_ElectricalIDLE;

			DebugPortOut(i).RX_Data										<= GTP_RX_Data;
			DebugPortOut(i).RX_CharIsK								<= GTP_RX_CharIsK;
			DebugPortOut(i).RX_CharIsComma						<= GTP_RX_CharIsComma;
			DebugPortOut(i).RX_CommaDetected					<= GTP_RX_CommaDetected;
			DebugPortOut(i).RX_DisparityError					<= GTP_RX_DisparityError;
			DebugPortOut(i).RX_NotInTableError				<= GTP_RX_NotInTableError;
			DebugPortOut(i).RX_ByteIsAligned					<= GTP_RX_ByteIsAligned;
			DebugPortOut(i).RX_ElectricalIDLE					<= GTP_RX_ElectricalIDLE;
			DebugPortOut(i).RX_ComInitDetected				<= GTP_RX_ComInitDetected;
			DebugPortOut(i).RX_ComWakeDetected				<= GTP_RX_ComWakeDetected;
			DebugPortOut(i).RX_Valid									<= '1';
			DebugPortOut(i).RX_BufferStatus						<= GTP_RX_BufferStatus;
			DebugPortOut(i).RX_ClockCorrectionStatus	<= GTP_RX_ClockCorrectionStatus;

			DebugPortOut(i).DRP.Data									<= DRPMux_In_DataOut(1);
			DebugPortOut(i).DRP.Ack										<= DRPMux_Ack(1);

			DebugPortOut(i).DigitalMonitor						<= GTP_DigitalMonitor;
			GTP_RX_Monitor_sel												<= DebugPortIn(i).RX_Monitor_sel;
			DebugPortOut(i).RX_Monitor_Data						<= '0' & GTP_RX_Monitor_Data;
		end generate;
	end generate;
end;
