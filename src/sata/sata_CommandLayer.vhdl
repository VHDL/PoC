-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Module:					SATA Command Layer
--
-- Description:
-- ------------------------------------
-- Executes ATA commands.
--
-- Automatically issues an "identify device" when the transport layer is
-- idle after power-up or reset.
-- To initiate a new connection (later on), synchronously reset this layer, the
-- transport layer and the underlying SATAController at the same time.
--
-- Clock might be instable in two conditions:
-- a) Reset is asserted, e.g., wenn ResetDone of SATAController is not asserted
-- 	  yet.
-- b) After power-up or reset: Trans_Status is constant equal to
-- 	  SATA_TRANS_STATUS_RESET. After SATA_TRANS_STATUS_IDLE was signaled,
-- 	  reset must be asserted before the clock might be instable again.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
use 		PoC.config.all;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
use			PoC.strings.all;
use			PoC.components.all;
use 		PoC.debug.all;
USE			PoC.sata.ALL;
USE			PoC.satadbg.ALL;


ENTITY sata_CommandLayer IS
	GENERIC (
		ENABLE_DEBUGPORT							: BOOLEAN									:= FALSE;			-- export internal signals to upper layers for debug purposes
		DEBUG													: BOOLEAN									:= FALSE;
		SIM_EXECUTE_IDENTIFY_DEVICE		: BOOLEAN									:= TRUE;			-- required by CommandLayer: load device parameters
		LOGICAL_BLOCK_SIZE_ldB				: POSITIVE
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;

		-- CommandLayer interface
		-- ========================================================================
		Command												: IN	T_SATA_CMD_COMMAND;
		Status												: OUT	T_SATA_CMD_STATUS;
		Error													: OUT	T_SATA_CMD_ERROR;

		DebugPortOut									: OUT T_SATADBG_CMD_OUT;

		-- for measurement purposes only
		Config_BurstSize							: IN	T_SLV_16;
		
		-- address interface (valid on Command /= *_NONE)
		Address_AppLB									: IN	T_SLV_48;
		BlockCount_AppLB							: IN	T_SLV_48;
		
		-- 
		DriveInformation							: OUT T_SATA_DRIVE_INFORMATION;

		-- TX path
		TX_Valid											: IN	STD_LOGIC;
		TX_Data												: IN	T_SLV_32;
		TX_SOR												: IN	STD_LOGIC;
		TX_EOR												: IN	STD_LOGIC;
		TX_Ack												: OUT	STD_LOGIC;

		-- RX path
		RX_Valid											: OUT	STD_LOGIC;
		RX_Data												: OUT	T_SLV_32;
		RX_SOR												: OUT	STD_LOGIC;
		RX_EOR												: OUT	STD_LOGIC;
		RX_Ack												: IN	STD_LOGIC;

		-- TransportLayer interface
		-- ========================================================================
		Trans_Command									: OUT	T_SATA_TRANS_COMMAND;
		Trans_Status									: IN	T_SATA_TRANS_STATUS;
		Trans_Error										: IN	T_SATA_TRANS_ERROR;
	
		-- ATA registers
		Trans_UpdateATAHostRegisters	: OUT	STD_LOGIC;
		Trans_ATAHostRegisters				: OUT	T_SATA_ATA_HOST_REGISTERS;
		Trans_ATADeviceRegisters			: IN	T_SATA_ATA_DEVICE_REGISTERS;
	
		-- TX path
		Trans_TX_Valid								: OUT	STD_LOGIC;
		Trans_TX_Data									: OUT	T_SLV_32;
		Trans_TX_SOT									: OUT	STD_LOGIC;
		Trans_TX_EOT									: OUT	STD_LOGIC;
		Trans_TX_Ack									: IN	STD_LOGIC;

		-- RX path
		Trans_RX_Valid								: IN	STD_LOGIC;
		Trans_RX_Data									: IN	T_SLV_32;
		Trans_RX_SOT									: IN	STD_LOGIC;
		Trans_RX_EOT									: IN	STD_LOGIC;
		Trans_RX_Ack									: OUT	STD_LOGIC
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
	SIGNAL Status_i													: T_SATA_CMD_STATUS;
	SIGNAL Error_i													: T_SATA_CMD_ERROR;

	--SIGNAL CFSM_ATA_Command									: T_SATA_ATA_COMMAND;
	--SIGNAL CFSM_ATA_Address_LB							: T_SLV_48;
	--SIGNAL CFSM_ATA_BlockCount_LB						: T_SLV_16;
	
	SIGNAL CFSM_TX_en												: STD_LOGIC;
	
	SIGNAL CFSM_RX_SOR											: STD_LOGIC;
	SIGNAL CFSM_RX_EOR											: STD_LOGIC;
	signal CFSM_RX_ForcePut									: STD_LOGIC;

	SIGNAL CFSM_DebugPortOut								: T_SATADBG_CMD_CFSM_OUT;

	SIGNAL ATA_CommandCategory							: T_SATA_COMMAND_CATEGORY;
	
	-- AddressCalculation
	-- ==========================================================================
	SIGNAL AdrCalc_Address_DevLB						: T_SLV_48;
	SIGNAL AdrCalc_BlockCount_DevLB					: T_SLV_48;

	-- TX_FIFO
	-- ==========================================================================
	SIGNAL TX_FIFO_Full											: STD_LOGIC;
	SIGNAL TX_FIFO_put											: STD_LOGIC;
	SIGNAL TX_FIFO_got											: STD_LOGIC;
	SIGNAL TX_FIFO_DataIn										: STD_LOGIC_VECTOR(33 DOWNTO 0);
	SIGNAL TX_FIFO_DataOut									: STD_LOGIC_VECTOR(33 DOWNTO 0);
	
	-- TX path data interface after TX_FIFO
	SIGNAL TX_FIFO_Data											: T_SLV_32;
	SIGNAL TX_FIFO_SOR											: STD_LOGIC;
	SIGNAL TX_FIFO_EOR											: STD_LOGIC;
	SIGNAL TX_FIFO_Valid										: STD_LOGIC;		
	
	-- TX path
	-- ==========================================================================
	SIGNAL TC_TX_Ack												: STD_LOGIC;
	SIGNAL TC_TX_Valid											: STD_LOGIC;
	SIGNAL TC_TX_Data												: T_SLV_32;
	SIGNAL TC_TX_SOT												: STD_LOGIC;
	SIGNAL TC_TX_EOT												: STD_LOGIC;
	SIGNAL TC_TX_LastWord										: STD_LOGIC;
	SIGNAL TC_TX_InsertEOT									: STD_LOGIC;
	
	-- RX_FIFO
	-- ==========================================================================
	SIGNAL RX_FIFO_put											: STD_LOGIC;
	SIGNAL RX_FIFO_got											: STD_LOGIC;
	SIGNAL RX_FIFO_DataIn										: STD_LOGIC_VECTOR(33 DOWNTO 0);
	SIGNAL RX_FIFO_DataOut									: STD_LOGIC_VECTOR(33 DOWNTO 0);
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
	SIGNAL IDF_DriveInformation							: T_SATA_DRIVE_INFORMATION;

	-- Internal version of output signals
	-- ========================================================================
	signal Trans_RX_Ack_i : std_logic;
	
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
		
		AdrCalc_Address_DevLB 						<= Address_AppLB_Shifted(to_index(Shift_us, Address_AppLB_Shifted'length));
		AdrCalc_BlockCount_DevLB					<= BlockCount_AppLB_Shifted(to_index(Shift_us, BlockCount_AppLB_Shifted'length));
	END BLOCK;
	

	-- ================================================================
	-- CommandLayer FSM
	-- ================================================================
	CFSM : ENTITY PoC.sata_CommandFSM
		GENERIC MAP (
			ENABLE_DEBUGPORT 							=> ENABLE_DEBUGPORT,
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

			DebugPortOut                  => CFSM_DebugPortOut,
			
			Address_LB										=> AdrCalc_Address_DevLB,
			BlockCount_LB									=> AdrCalc_BlockCount_DevLB,
			
			TX_en													=> CFSM_TX_en,
			
			RX_SOR												=> CFSM_RX_SOR,
			RX_EOR												=> CFSM_RX_EOR,
			RX_ForcePut										=> CFSM_RX_ForcePut,
			
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

	TX_FIFO_put																<= TX_Valid;
	TX_FIFO_got																<= TC_TX_Ack;
		
	TX_FIFO_DataIn(TX_Data'range)							<= TX_Data;
	TX_FIFO_DataIn(TX_Data'length	+ 0)				<= TX_SOR;
	TX_FIFO_DataIn(TX_Data'length	+ 1)				<= TX_EOR;
		
	TX_FIFO_Data															<= TX_FIFO_DataOut(TX_FIFO_Data'range);
	TX_FIFO_SOR																<= TX_FIFO_DataOut(TX_Data'length	+ 0);
	TX_FIFO_EOR																<= TX_FIFO_DataOut(TX_Data'length	+ 1);
		
	-- Commandlayer TX_FIFO
	TX_FIFO : ENTITY PoC.fifo_glue
		GENERIC MAP (
			D_BITS					=> TX_FIFO_DataIn'length
		)
		PORT MAP (
			clk							=> Clock,
			rst							=> Reset,
			
			-- write interface
			put							=> TX_FIFO_put,
			di							=> TX_FIFO_DataIn,
			ful							=> TX_FIFO_Full,

			-- read interface
			got							=> TX_FIFO_got,
			vld							=> TX_FIFO_Valid,
			do							=> TX_FIFO_DataOut
		);

	TX_Ack					<= NOT TX_FIFO_Full;

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
		SIGNAl IEOTC_uf											: STD_LOGIC;
	BEGIN
		-- enable TX data path
		TC_TX_Valid					<= TX_FIFO_Valid		AND CFSM_TX_en;
		TC_TX_Ack						<= Trans_TX_Ack			AND CFSM_TX_en;

		TC_TX_DataFlow			<= TC_TX_Valid			AND TC_TX_Ack;

		InsertEOT_d					<= ffdre(q => InsertEOT_d,     rst => Reset, en => TC_TX_DataFlow, d => TC_TX_InsertEOT) 	when rising_edge(Clock);
		InsertEOT_re				<= TC_TX_InsertEOT	AND NOT InsertEOT_d;
		InsertEOT_re_d			<= ffdre(q => InsertEOT_re_d,  rst => Reset, en => TC_TX_DataFlow, d => InsertEOT_re) 		when rising_edge(Clock);
		InsertEOT_re_d2			<= ffdre(q => InsertEOT_re_d2, rst => Reset, en => TC_TX_DataFlow, d => InsertEOT_re_d) 	when rising_edge(Clock);

		TC_TX_Data					<= TX_FIFO_Data;
		TC_TX_SOT						<= TX_FIFO_SOR			OR InsertEOT_re_d2;
		TC_TX_EOT						<= TX_FIFO_EOR			OR InsertEOT_re_d;

		IEOTC_Load					<= TC_TX_SOT				AND TC_TX_Valid;
		IEOTC_inc						<= TC_TX_DataFlow		AND NOT IEOTC_uf;
		
		IEOTC : BLOCK	-- InsertEOTCounter
			CONSTANT MAX_BLOCKCOUNT						: POSITIVE															:= ite(SIMULATION, C_SIM_MAX_BLOCKCOUNT, C_SATA_ATA_MAX_BLOCKCOUNT);
			CONSTANT MIN_TRANSFER_SIZE_ldB  	: POSITIVE															:= log2ceilnz(MAX_BLOCKCOUNT)+9;
			CONSTANT MIN_TRANSFER_SIZE_B			: POSITIVE															:= 2**MIN_TRANSFER_SIZE_ldB;
			CONSTANT MAX_TRANSFER_SIZE_ldB		: POSITIVE															:= MIN_TRANSFER_SIZE_ldB + (SHIFT_WIDTH - 1);
			CONSTANT IEOT_COUNTER_START				: POSITIVE															:= (MIN_TRANSFER_SIZE_B / 4) - AHEAD_CYCLES_FOR_INSERT_EOT - 3;		-- FIXME: replace with dynamic calculation
			CONSTANT IEOT_COUNTER_BITS				: POSITIVE															:= MAX_TRANSFER_SIZE_ldB - 2;
			
			SIGNAL Counter_s									: SIGNED(IEOT_COUNTER_BITS DOWNTO 0)			:= to_signed(IEOT_COUNTER_START, IEOT_COUNTER_BITS + 1);
		BEGIN
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF ((Reset = '1') OR (IEOTC_Load = '1')) THEN
						Counter_s				<=  to_signed(IEOT_COUNTER_START, IEOT_COUNTER_BITS + 1);		-- FIXME: replace with dynamic calculation
					ELSE
						IF (IEOTC_inc = '1') THEN
							Counter_s			<= Counter_s - 1;
						END IF;
					END IF;
				END IF;
			END PROCESS;
			
			IEOTC_uf					<= Counter_s(Counter_s'high);
		END BLOCK;	-- InsertEOTCounter

		TC_TX_InsertEOT			<= IEOTC_uf;
		
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
	END BLOCK;	-- TransferCutter

	-- CommandLayer RX_FIFO
	RX_FIFO_put																<= (Trans_RX_Valid and not IDF_Enable) or CFSM_RX_ForcePut;
	RX_FIFO_DataIn(Trans_RX_Data'range)				<= Trans_RX_Data;
	RX_FIFO_DataIn(Trans_RX_Data'length	+ 0)	<= CFSM_RX_SOR;
	RX_FIFO_DataIn(Trans_RX_Data'length	+ 1)	<= CFSM_RX_EOR;


	RX_FIFO_got																<= RX_Ack;
	RX_Data																		<= RX_FIFO_DataOut(RX_Data'range);
	RX_SOR																		<= RX_FIFO_DataOut(RX_Data'length	+ 0);
	RX_EOR																		<= RX_FIFO_DataOut(RX_Data'length	+ 1);
	
	RX_FIFO : ENTITY PoC.fifo_glue
		GENERIC MAP (
			D_BITS						=> 34
		)
		PORT MAP (
			clk						=> Clock,
			rst						=> Reset,

			-- write interface
			put						=> RX_FIFO_put,
			di						=> RX_FIFO_DataIn,
			ful						=> RX_FIFO_Full,

			-- read interface
			got						=> RX_FIFO_got,
			vld						=> RX_FIFO_Valid,
			do						=> RX_FIFO_DataOut
		);
	
	Trans_RX_Ack_i	 	<= (NOT RX_FIFO_Full) WHEN (IDF_Enable = '0') ELSE '1';					-- RX_Ack	 multiplexer
	Trans_RX_Ack      <= Trans_RX_Ack_i;
	RX_Valid					<= RX_FIFO_Valid;

	
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
	IDF_Reset		<= Reset;
	IDF_Valid		<= Trans_RX_Valid;
	IDF_Data		<= Trans_RX_Data;
	IDF_SOT			<= Trans_RX_SOT;
	IDF_EOT			<= Trans_RX_EOT;
	
	IDF : ENTITY PoC.sata_IdentifyDeviceFilter
		GENERIC MAP (
			DEBUG										=> DEBUG					
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
			
			DriveInformation				=> IDF_DriveInformation
		);

  -- debug ports
  -- ==========================================================================================================================================================
  genDebugPort : IF (ENABLE_DEBUGPORT = TRUE) GENERATE
  begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_generateCommandEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_CMD_COMMAND loop
					STD.TextIO.write(l, str_replace(T_SATA_CMD_COMMAND'image(i), "sata_cmd_cmd", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_generateStatusEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_CMD_STATUS loop
					STD.TextIO.write(l, str_replace(T_SATA_CMD_STATUS'image(i), "sata_cmd_status_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_generateErrorEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_CMD_ERROR loop
					STD.TextIO.write(l, str_replace(T_SATA_CMD_ERROR'image(i), "sata_cmd_error_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
		
			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Command Layer - Command Enum",	dbg_generateCommandEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Cmd_Command.tok"),
				1 => dbg_ExportEncoding("Command Layer - Status Enum",		dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Cmd_Status.tok"),
				2 => dbg_ExportEncoding("Command Layer - Error Enum",		dbg_generateErrorEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Cmd_Error.tok")
			);
		begin
		end generate;
	
    DebugPortOut.Command         		 <= Command;
    DebugPortOut.Status          		 <= Status_i;
    DebugPortOut.Error           		 <= Error_i;

    DebugPortOut.Address_AppLB    		<= Address_AppLB;
    DebugPortOut.BlockCount_AppLB 		<= BlockCount_AppLB;
    DebugPortOut.Address_DevLB    		<= AdrCalc_Address_DevLB;
    DebugPortOut.BlockCount_DevLB 		<= AdrCalc_BlockCount_DevLB;

    -- identify device filter
    DebugPortOut.IDF_Reset            <= IDF_Reset;
    DebugPortOut.IDF_Enable           <= IDF_Enable;
    DebugPortOut.IDF_Error            <= IDF_Error;
    DebugPortOut.IDF_Finished         <= IDF_Finished;
    DebugPortOut.IDF_DriveInformation <= IDF_DriveInformation;

    -- debug port of command fsm, for RX datapath see below
    DebugPortOut.CFSM <= CFSM_DebugPortOut;

		-- RX ----------------------------------------------------------------
    -- RX datapath to upper layer
    DebugPortOut.RX_Valid 			<= RX_FIFO_Valid;
    DebugPortOut.RX_Data  			<= RX_FIFO_DataOut(RX_Data'range);
    DebugPortOut.RX_SOR   			<= RX_FIFO_DataOut(RX_Data'length + 0);
    DebugPortOut.RX_EOR   			<= RX_FIFO_DataOut(RX_Data'length + 1);
    DebugPortOut.RX_Ack   			<= RX_Ack;

		-- RX datapath between demultiplexer, RX_FIFO and CFSM
    DebugPortOut.CFSM_RX_Valid	<= RX_FIFO_put;
    --see below DebugPortOut.CFSM_RX_Data  <= Trans_RX_Data;
    DebugPortOut.CFSM_RX_SOR		<= CFSM_RX_SOR;
    DebugPortOut.CFSM_RX_EOR		<= CFSM_RX_EOR;
    DebugPortOut.CFSM_RX_Ack		<= not RX_FIFO_FULL;
		
		-- RX datapath between demultiplexer and IDF
		-- is same as input from transport layer

		-- RX datapath from transport layer
    DebugPortOut.Trans_RX_Valid <= Trans_RX_Valid;
    DebugPortOut.Trans_RX_Data  <= Trans_RX_Data;
    DebugPortOut.Trans_RX_SOT   <= Trans_RX_SOT;
    DebugPortOut.Trans_RX_EOT   <= Trans_RX_EOT;
    DebugPortOut.Trans_RX_Ack   <= Trans_RX_Ack_i;

		-- TX ----------------------------------------------------------------
    -- TX datapath to upper layer
		DebugPortOut.TX_Valid 			<= TX_Valid;
    DebugPortOut.TX_Data  			<= TX_Data;
		DebugPortOut.TX_SOR 				<= TX_SOR;
		DebugPortOut.TX_EOR 				<= TX_EOR;
		DebugPortOut.TX_Ack 				<= not TX_FIFO_Full;

		-- TX datapath of transport cutter
		DebugPortOut.TC_TX_Valid			<= TC_TX_Valid;
		DebugPortOut.TC_TX_Data				<= TC_TX_Data;
		DebugPortOut.TC_TX_SOT				<= TC_TX_SOT;
		DebugPortOut.TC_TX_EOT				<= TC_TX_EOT;
		DebugPortOut.TC_TX_Ack				<= TC_TX_Ack;	
		DebugPortOut.TC_TX_LastWord		<= TC_TX_LastWord;
		DebugPortOut.TC_TX_InsertEOT	<= TC_TX_InsertEOT;

	end generate;

end;
