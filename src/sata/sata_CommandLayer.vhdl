-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
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

LIBRARY PoC;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
--USE			PoC.strings.ALL;
--USE			PoC.sata.ALL;


ENTITY sata_CommandLayer IS
	GENERIC (
		SIM_EXECUTE_IDENTIFY_DEVICE		: BOOLEAN									:= TRUE;			-- required by CommandLayer: load device parameters
		DEBUG													: BOOLEAN									:= FALSE;			-- generate ChipScope CSP_* signals
		TX_FIFO_DEPTH									: NATURAL									:= 0;
		RX_FIFO_DEPTH									: POSITIVE;
		LOGICAL_BLOCK_SIZE_ldB				: POSITIVE
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;

		-- CommandLayer interface
		-- ========================================================================
		Command												: IN	T_ATA_CMD_COMMAND;
		Status												: OUT	T_ATA_CMD_STATUS;
		Error													: OUT	T_ATA_CMD_ERROR;

		DebugPort											: OUT T_DBG_COMMAND_OUT;

		-- for measurement purposes only
		Config_BurstSize							: IN	T_SLV_16;
		
		-- address interface (valid on Command /= *_NONE)
		Address_AppLB									: IN	T_SLV_48;
		BlockCount_AppLB							: IN	T_SLV_48;
		
		-- 
		DriveInformation							: OUT T_DRIVE_INFORMATION;

		-- TX path
		TX_Valid											: IN	STD_LOGIC;
		TX_Data												: IN	T_SLV_32;
		TX_SOR												: IN	STD_LOGIC;
		TX_EOR												: IN	STD_LOGIC;
		TX_Ready											: OUT	STD_LOGIC;

		-- RX path
		RX_Valid											: OUT	STD_LOGIC;
		RX_Data												: OUT	T_SLV_32;
		RX_SOR												: OUT	STD_LOGIC;
		RX_EOR												: OUT	STD_LOGIC;
		RX_Ready											: IN	STD_LOGIC;

		-- TransportLayer interface
		-- ========================================================================
		Trans_Command									: OUT	T_SATA_TRANS_COMMAND;
		Trans_Status									: IN	T_SATA_TRANS_STATUS;
		Trans_Error										: IN	T_SATA_TRANS_ERROR;
	
		-- ATA registers
		Trans_UpdateATAHostRegisters	: OUT	STD_LOGIC;
		Trans_ATAHostRegisters				: OUT	T_ATA_HOST_REGISTERS;
		Trans_ATADeviceRegisters			: IN	T_ATA_DEVICE_REGISTERS;
	
		-- TX path
		Trans_TX_Valid								: OUT	STD_LOGIC;
		Trans_TX_Data									: OUT	T_SLV_32;
		Trans_TX_SOT									: OUT	STD_LOGIC;
		Trans_TX_EOT									: OUT	STD_LOGIC;
		Trans_TX_Ready								: IN	STD_LOGIC;

		-- RX path
		Trans_RX_Valid								: IN	STD_LOGIC;
		Trans_RX_Data									: IN	T_SLV_32;
		Trans_RX_SOT									: IN	STD_LOGIC;
		Trans_RX_EOT									: IN	STD_LOGIC;
		Trans_RX_Commit								: IN	STD_LOGIC;
		Trans_RX_Rollback							: IN	STD_LOGIC;
		Trans_RX_Ready								: OUT	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF sata_CommandLayer IS
	ATTRIBUTE KEEP													: BOOLEAN;
	ATTRIBUTE FSM_ENCODING									: STRING;

	-- ==========================================================================================================================================================
	-- CommandLayer configurations
	-- ==========================================================================================================================================================
	CONSTANT SHIFT_WIDTH										: POSITIVE								:= 8;						-- supports logical block sizes from 512 B to 4 KiB
	CONSTANT AHEAD_CYCLES_FOR_INSERT_EOT		: NATURAL									:= 1;

	-- CommandFSM
	-- ==========================================================================
	SIGNAL Status_i													: T_ATA_CMD_STATUS;
	SIGNAL Error_i													: T_ATA_CMD_ERROR;

	SIGNAL CFSM_ATA_Command									: T_ATA_COMMAND;
	SIGNAL CFSM_ATA_Address_LB							: T_SLV_48;
	SIGNAL CFSM_ATA_BlockCount_LB						: T_SLV_16;
	
	SIGNAL CFSM_TX_en												: STD_LOGIC;
	
	SIGNAL CFSM_RX_SOR											: STD_LOGIC;
	SIGNAL CFSM_RX_EOR											: STD_LOGIC;

	SIGNAL ATA_CommandCategory							: T_ATA_COMMAND_CATEGORY;
	
	-- AddressCalculation
	-- ==========================================================================
	SIGNAL AdrCalc_Address_DevLB						: T_SLV_48;
	SIGNAL AdrCalc_BlockCount_DevLB					: T_SLV_48;

	-- TX_FIFO
	-- ==========================================================================
	SIGNAL TX_FIFO_Full											: STD_LOGIC;
	
	-- TX path data interface after TX_FIFO
	SIGNAL TX_FIFO_Data											: T_SLV_32;
	SIGNAL TX_FIFO_SOR											: STD_LOGIC;
	SIGNAL TX_FIFO_EOR											: STD_LOGIC;
	SIGNAL TX_FIFO_Valid										: STD_LOGIC;		
	SIGNAL TX_FIFO_Ready										: STD_LOGIC;
	
	-- TX path
	-- ==========================================================================
	SIGNAL TC_TX_Ready											: STD_LOGIC;
	SIGNAL TC_TX_Valid											: STD_LOGIC;
	SIGNAL TC_TX_Data												: T_SLV_32;
	SIGNAL TC_TX_SOT												: STD_LOGIC;
	SIGNAL TC_TX_EOT												: STD_LOGIC;
	SIGNAL TC_TX_LastWord										: STD_LOGIC;
	SIGNAL TC_TX_InsertEOT									: STD_LOGIC;
	
	-- RX_FIFO
	-- ==========================================================================
	SIGNAL RX_FIFO_rst											: STD_LOGIC;
	SIGNAL RX_FIFO_put											: STD_LOGIC;
	SIGNAL RX_FIFO_got											: STD_LOGIC;
	SIGNAL RX_FIFO_DataIn										: STD_LOGIC_VECTOR(33 DOWNTO 0);
	SIGNAL RX_FIFO_DataOut									: STD_LOGIC_VECTOR(33 DOWNTO 0);
	SIGNAL RX_FIFO_Commit										: STD_LOGIC;
	SIGNAL RX_FIFO_Rollback									: STD_LOGIC;
	SIGNAL RX_FIFO_Valid										: STD_LOGIC;
	SIGNAL RX_FIFO_Full											: STD_LOGIC;

	-- IdentifyDeviceFilter
	-- ==========================================================================
	SIGNAL IDF_Reset												: STD_LOGIC;
	SIGNAL IDF_Enable												: STD_LOGIC;
	SIGNAL IDF_Error												: STD_LOGIC;
	SIGNAL IDF_Finished											: STD_LOGIC;
	
	SIGNAL IDF_Valid												: STD_LOGIC;
	SIGNAL IDF_Data													: T_SLV_32;
	SIGNAL IDF_SOT													: STD_LOGIC;
	SIGNAL IDF_EOT													: STD_LOGIC;
	SIGNAL IDF_CRC_OK												: STD_LOGIC;
	SIGNAL IDF_DriveInformation							: T_DRIVE_INFORMATION;
	
BEGIN
	-- ================================================================
	-- logical block address calculations
	-- ================================================================
	AdrCalc : BLOCK
		SIGNAL Shift_us										: UNSIGNED(log2ceilnz(SHIFT_WIDTH) - 1 DOWNTO 0);
		TYPE T_SHIFTED										IS ARRAY(NATURAL RANGE <>) OF T_SLV_48;
		SIGNAL Address_AppLB_Shifted			: T_SHIFTED(SHIFT_WIDTH - 1 DOWNTO 0);
		SIGNAL BlockCount_AppLB_Shifted		: T_SHIFTED(SHIFT_WIDTH - 1 DOWNTO 0);
	BEGIN
		Shift_us													<= to_unsigned(LOGICAL_BLOCK_SIZE_ldB - to_integer(to_01(IDF_DriveInformation.LogicalBlockSize_ldB)), Shift_us'length);

		Address_AppLB_Shifted(0)					<= Address_AppLB;
		BlockCount_AppLB_Shifted(0)				<= BlockCount_AppLB;
		
		genShifted : FOR I IN 1 TO SHIFT_WIDTH - 1 GENERATE
			Address_AppLB_Shifted(I)				<= Address_AppLB(Address_AppLB'high - I DOWNTO 0)			& (I - 1 DOWNTO 0 => '0');
			BlockCount_AppLB_Shifted(I)			<= BlockCount_AppLB(Address_AppLB'high - I DOWNTO 0)	& (I - 1 DOWNTO 0 => '0');
		END GENERATE;
		
		AdrCalc_Address_DevLB 						<= Address_AppLB_Shifted(to_integer(to_01(Shift_us, '0')));
		AdrCalc_BlockCount_DevLB					<= BlockCount_AppLB_Shifted(to_integer(to_01(Shift_us, '0')));
	END BLOCK;
	

	-- ================================================================
	-- CommandLayer FSM
	-- ================================================================
	CFSM : ENTITY PoC.sata_CommandFSM
		GENERIC MAP (
			SIM_EXECUTE_IDENTIFY_DEVICE		=> SIM_EXECUTE_IDENTIFY_DEVICE,
			DEBUG													=> DEBUG					
		)
		PORT MAP (
			Clock													=> Clock,
			Reset													=> Reset,

			-- for measurement purposes only
			Config_BurstSize							=> Config_BurstSize,
			
			-- CommandLayer interface			
			Command												=> Command,
			Status												=> Status_i,
			Error													=> Error_i,
			
			Address_LB										=> AdrCalc_Address_DevLB,
			BlockCount_LB									=> AdrCalc_BlockCount_DevLB,
			
			TX_en													=> CFSM_TX_en,
			
			RX_SOR												=> CFSM_RX_SOR,
			RX_EOR												=> CFSM_RX_EOR,
			
			-- TransportLayer interface
			Trans_Command									=> Trans_Command,
			Trans_Status									=> Trans_Status,
			Trans_Error										=> Trans_Error,
			
			Trans_UpdateATAHostRegisters	=> Trans_UpdateATAHostRegisters,
			Trans_ATAHostRegisters				=> Trans_ATAHostRegisters,
			
			Trans_RX_SOT									=> Trans_RX_SOT,
			Trans_RX_EOT									=> Trans_RX_EOT,
			
			-- IdentifyDeviceFilter interface
			IDF_Enable										=> IDF_Enable,
			IDF_Error											=> IDF_Error,
			IDF_DriveInformation					=> IDF_DriveInformation
		);

	-- assign output signals
	Status									<= Status_i;
	Error										<= Error_i;
	DriveInformation				<= IDF_DriveInformation;

	-- TX_FIFO signals
	genTXFIFO0 : IF (TX_FIFO_DEPTH = 0) GENERATE
		TX_Ready					<= NOT TX_FIFO_Full;
		TX_FIFO_Data			<= TX_Data;
		TX_FIFO_SOR				<= TX_SOR;
		TX_FIFO_EOR				<= TX_EOR;
		TX_FIFO_Valid			<= TX_Valid;
		
		TX_FIFO_Full			<= NOT Trans_TX_Ready;
		Trans_TX_Data			<= TX_FIFO_Data;
		Trans_TX_Valid		<= TX_FIFO_Valid;
	END GENERATE;
	genTXFIFO1 : IF (TX_FIFO_DEPTH > 0) GENERATE
		SIGNAL TX_FIFO_rst											: STD_LOGIC;
		SIGNAL TX_FIFO_put											: STD_LOGIC;
		SIGNAL TX_FIFO_got											: STD_LOGIC;
		
		SIGNAL TX_FIFO_DataIn										: STD_LOGIC_VECTOR(33 DOWNTO 0);
		SIGNAL TX_FIFO_DataOut									: STD_LOGIC_VECTOR(33 DOWNTO 0);
	BEGIN
		TX_FIFO_rst																<= Reset OR to_sl(Command = ATA_CMD_CMD_RESET);
		TX_FIFO_put																<= TX_Valid;
		TX_FIFO_got																<= TC_TX_Ready;
		
		TX_FIFO_DataIn(TX_Data'range)							<= TX_Data;
		TX_FIFO_DataIn(TX_Data'length	+ 0)				<= TX_SOR;
		TX_FIFO_DataIn(TX_Data'length	+ 1)				<= TX_EOR;
		
		TX_FIFO_Data															<= TX_FIFO_DataOut(TX_FIFO_Data'range);
		TX_FIFO_SOR																<= TX_FIFO_DataOut(TX_Data'length	+ 0);
		TX_FIFO_EOR																<= TX_FIFO_DataOut(TX_Data'length	+ 1);
		
		-- Commandlayer TX_FIFO
		TX_FIFO : ENTITY PoC.fifo_cc_got
			GENERIC MAP (
				D_BITS					=> TX_FIFO_DataIn'length,				-- 
				MIN_DEPTH 			=> TX_FIFO_DEPTH,								-- 
				DATA_REG				=> FALSE,
				STATE_REG				=> FALSE,
				OUTPUT_REG			=> TRUE,
				ESTATE_WR_BITS	=> 0,
				FSTATE_RD_BITS	=> 0														-- 
			)
			PORT MAP (
				clk							=> Clock,
				rst							=> TX_FIFO_rst,

				-- write interface
				put							=> TX_FIFO_put,
				din							=> TX_FIFO_DataIn,
				estate_wr				=> OPEN,
				full						=> TX_FIFO_Full,

				-- read interface
				got							=> TX_FIFO_got,
				valid						=> TX_FIFO_Valid,
				dout						=> TX_FIFO_DataOut,
				fstate_rd				=> OPEN
			);

		TX_FIFO_Ready		<= NOT TX_FIFO_Full;
		TX_Ready				<= TX_FIFO_Ready;
	END GENERATE;

	-- TX TransportCutter
	-- ==========================================================================================================================================================
	TransportCutter : BLOCK
		SIGNAL TC_TX_DataFlow								: STD_LOGIC;
		SIGNAL TC_TX_LastWord_r							: STD_LOGIC						:= '0';
		
		SIGNAL InsertEOT_d									: STD_LOGIC						:= '0';
		SIGNAL InsertEOT_re									: STD_LOGIC;
		SIGNAL InsertEOT_re_d								: STD_LOGIC						:= '0';
		SIGNAL InsertEOT_re_d2							: STD_LOGIC						:= '0';
		
		SIGNAL IEOTC_Load										: STD_LOGIC;
		SIGNAL IEOTC_inc										: STD_LOGIC;
		SIGNAl IEOTC_ov											: STD_LOGIC;
	BEGIN
		-- enable TX data path
		TC_TX_Valid					<= TX_FIFO_Valid		AND CFSM_TX_en;
		TC_TX_Ready					<= Trans_TX_Ready		AND CFSM_TX_en;

		TC_TX_DataFlow			<= TC_TX_Valid			AND TC_TX_Ready;

		InsertEOT_d					<= TC_TX_InsertEOT	WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');
		InsertEOT_re				<= TC_TX_InsertEOT	AND NOT InsertEOT_d;
		InsertEOT_re_d			<= InsertEOT_re			WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');
		InsertEOT_re_d2			<= InsertEOT_re_d		WHEN rising_edge(Clock) AND (TC_TX_DataFlow = '1');

		TC_TX_Data					<= TX_FIFO_Data;
		TC_TX_SOT						<= TX_FIFO_SOR			OR InsertEOT_re_d2;
		TC_TX_EOT						<= TX_FIFO_EOR			OR InsertEOT_re_d;

		IEOTC_Load					<= TC_TX_SOT				AND TC_TX_Valid;
		IEOTC_inc						<= TC_TX_DataFlow		AND NOT IEOTC_ov;
		
		IEOTC : BLOCK	-- InsertEOTCounter
			CONSTANT MAX_BLOCKCOUNT						: POSITIVE															:= ite(SIMULATION, SIM_MAX_BLOCKCOUNT, ATA_MAX_BLOCKCOUNT);
			CONSTANT MIN_TRANSFER_SIZE_ldB  	: POSITIVE															:= log2ceilnz(MAX_BLOCKCOUNT)+9;
			CONSTANT MIN_TRANSFER_SIZE_B			: POSITIVE															:= 2**MIN_TRANSFER_SIZE_ldB;
			CONSTANT MAX_TRANSFER_SIZE_ldB		: POSITIVE															:= MIN_TRANSFER_SIZE_ldB + (SHIFT_WIDTH - 1);
			CONSTANT IEOT_COUNTER_START				: POSITIVE															:= (MIN_TRANSFER_SIZE_B / 4) - AHEAD_CYCLES_FOR_INSERT_EOT - 3;		-- FIXME: replace with dynamic calculation
			CONSTANT IEOT_COUNTER_BITS					: POSITIVE															:= MAX_TRANSFER_SIZE_ldB - 2;
			
			SIGNAL Counter_us									: SIGNED(IEOT_COUNTER_BITS DOWNTO 0)			:= to_signed(IEOT_COUNTER_START, IEOT_COUNTER_BITS + 1);
		BEGIN
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF ((Reset = '1') OR (Command = ATA_CMD_CMD_RESET) OR (IEOTC_Load = '1')) THEN
						Counter_us				<=  to_signed(IEOT_COUNTER_START, IEOT_COUNTER_BITS + 1);		-- FIXME: replace with dynamic calculation
					ELSE
						IF (IEOTC_inc = '1') THEN
							Counter_us			<= Counter_us - 1;
						END IF;
					END IF;
				END IF;
			END PROCESS;
			
			IEOTC_ov					<= Counter_us(Counter_us'high);
		END BLOCK;	-- InsertEOTCounter

		TC_TX_InsertEOT			<= IEOTC_ov;
		
		Trans_TX_Valid			<= TC_TX_Valid;
		Trans_TX_Data				<= TC_TX_Data;
		Trans_TX_SOT				<= TC_TX_SOT;
		Trans_TX_EOT				<= TC_TX_EOT;
		
		-- RS-FF for TC_TX_LastWord
		-- FF.set = TX_EOT
		-- FF.rst = TX_SOT
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (TC_TX_EOT = '1') THEN
					TC_TX_LastWord_r		<= '1';
				ELSIF (TC_TX_SOT = '1') THEN
					TC_TX_LastWord_r		<= '0';
				END IF;
			END IF;
		END PROCESS;
		
		TC_TX_LastWord	<= TC_TX_EOT OR TC_TX_LastWord_r;		-- LastWord in transfer
		
		genCSP : IF (DEBUG = TRUE) GENERATE
			SIGNAL CSP_TX_DataFlow							: STD_LOGIC;
			SIGNAL CSP_TX_LastWord							: STD_LOGIC;
			SIGNAL CSP_InsertEOT								: STD_LOGIC;
		
			ATTRIBUTE KEEP OF CSP_TX_DataFlow		: SIGNAL IS TRUE;
			ATTRIBUTE KEEP OF CSP_TX_LastWord		: SIGNAL IS TRUE;
			ATTRIBUTE KEEP OF CSP_InsertEOT			: SIGNAL IS TRUE;
			
		BEGIN
			CSP_TX_DataFlow		<= TC_TX_DataFlow;
			CSP_TX_LastWord		<= TC_TX_LastWord;
			CSP_InsertEOT			<= TC_TX_InsertEOT;
		END GENERATE;
	END BLOCK;	-- TransferCutter

	-- CommandLayer RX_FIFO
	RX_FIFO_rst																<= Reset OR to_sl(Command = ATA_CMD_CMD_RESET);
	RX_FIFO_put																<= Trans_RX_Valid			AND NOT IDF_Enable;
	RX_FIFO_Commit														<= (Trans_RX_Commit		AND NOT IDF_Enable);
	RX_FIFO_Rollback													<= Trans_RX_Rollback	AND NOT IDF_Enable;

	RX_FIFO_got																<= RX_Ready;

	RX_FIFO_DataIn(Trans_RX_Data'range)				<= Trans_RX_Data;
	RX_FIFO_DataIn(Trans_RX_Data'length	+ 0)	<= CFSM_RX_SOR;
	RX_FIFO_DataIn(Trans_RX_Data'length	+ 1)	<= CFSM_RX_EOR;

	RX_Data																		<= RX_FIFO_DataOut(RX_Data'range);
	RX_SOR																		<= RX_FIFO_DataOut(RX_Data'length	+ 0);
	RX_EOR																		<= RX_FIFO_DataOut(RX_Data'length	+ 1);
	
	RX_FIFO : ENTITY PoC.fifo_cc_got_tempput
		GENERIC MAP (
			D_BITS						=> 34,													 
			MIN_DEPTH 				=> RX_FIFO_DEPTH,								 
			ESTATE_WR_BITS		=> 0,														
			FSTATE_RD_BITS		=> 0,														
			OUTPUT_REG				=> TRUE,
			DATA_REG					=> FALSE,
			STATE_REG					=> FALSE
		)
		PORT MAP (
			clk						=> Clock,
			rst						=> RX_FIFO_rst,

			-- write interface
			put						=> RX_FIFO_put,
			din						=> RX_FIFO_DataIn,
			estate_wr			=> OPEN,
			full					=> RX_FIFO_Full,

			-- temporary put control
			commit				=> RX_FIFO_Commit,
			rollback			=> RX_FIFO_Rollback,

			-- read interface
			got						=> RX_FIFO_got,
			valid					=> RX_FIFO_Valid,
			dout					=> RX_FIFO_DataOut,
			fstate_rd 		=> OPEN
		);
	
	Trans_RX_Ready 	<= (NOT RX_FIFO_Full) WHEN (IDF_Enable = '0') ELSE '1';					-- RX_Ready multiplexer
	RX_Valid				<= RX_FIFO_Valid;

	
	-- ================================================================
	-- LoopControl
	-- ================================================================
	-- tests
	--		1. address <= max_drive_size
	--		2. address + blockcount <= max_drive_size
	-- calculatations
	--	a) pre calculation
	--		1. calculate loops an save value
	--		2. calculate remainer and save calue
	--		3. generate transfer
	--	b) remainer based calculatation
	--		1. calculate oustanding blocks
	--		2. generate transfer
	
	-- ================================================================
	-- IdentifyDeviceFilter
	-- ================================================================
	IDF_Reset		<= Reset OR to_sl(Command = ATA_CMD_CMD_RESET);
	IDF_Valid		<= Trans_RX_Valid;
	IDF_Data		<= Trans_RX_Data;
	IDF_SOT			<= Trans_RX_SOT;
	IDF_EOT			<= Trans_RX_EOT;
	IDF_CRC_OK	<= Trans_RX_Commit;
	
	IDF : ENTITY PoC.sata_IdentifyDeviceFilter
		GENERIC MAP (
			DEBUG												=> DEBUG					
		)
		PORT MAP (
			Clock										=> Clock,
			Reset										=> IDF_Reset,
			
			Enable									=> IDF_Enable,
			Error										=> IDF_Error,
			Finished								=> IDF_Finished,
		
			Valid										=> IDF_Valid,
			Data										=> IDF_Data,
			SOT											=> IDF_SOT,
			EOT											=> IDF_EOT,
			
			CRC_OK									=> IDF_CRC_OK,
			
			DriveInformation				=> IDF_DriveInformation
		);

	-- debug ports
	-- ==========================================================================================================================================================
	DebugPort.Command						<= Command;
	DebugPort.Status						<= Status_i;
	DebugPort.Error							<= Error_i;
	
	DebugPort.DriveInformation.Valid	<= '0';
--	DebugPort.DriveInformation	<= IDF_DriveInformation;

	-- ChipScope
	-- ==========================================================================================================================================================
	genCSP : IF (DEBUG = TRUE) GENERATE
		SIGNAL CSP_TXFIFO_SOR								: STD_LOGIC;
		SIGNAL CSP_TXFIFO_EOR								: STD_LOGIC;
	
		SIGNAL CSP_RXFIFO_SOR								: STD_LOGIC;
		SIGNAL CSP_RXFIFO_EOR								: STD_LOGIC;
	
		ATTRIBUTE KEEP OF CSP_TXFIFO_SOR		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_TXFIFO_EOR		: SIGNAL IS TRUE;
		
		ATTRIBUTE KEEP OF CSP_RXFIFO_SOR		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF CSP_RXFIFO_EOR		: SIGNAL IS TRUE;
	BEGIN
		CSP_TXFIFO_SOR		<= TX_FIFO_Valid	AND TX_FIFO_SOR;
		CSP_TXFIFO_EOR		<= TX_FIFO_Valid	AND TX_FIFO_EOR;
		
		CSP_RXFIFO_SOR		<= Trans_RX_Valid	AND CFSM_RX_SOR;
		CSP_RXFIFO_EOR		<= Trans_RX_Valid	AND CFSM_RX_EOR;
	END GENERATE;
END;
