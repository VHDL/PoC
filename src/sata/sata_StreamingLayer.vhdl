-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Module:					SATA Streaming Layer
--
-- Description:
-- ------------------------------------
-- Executes ATA commands.
--
-- Automatically issues an "identify device" when the SATA Controller is
-- idle after power-up or reset.
--
-- If initial or requested IDENTIFY DEVICE failed, then FSM stays in error state.
-- Either *_ERROR_IDENTIFY_DEVICE_ERROR or *_ERROR_DEVICE_NOT_SUPPORTED are
-- signaled. To leave this state, apply one of the following:
-- - assert synchronous reset for whole SATA stack, or
-- - issue *_CMD_IDENTIFY_DEVICE.
--
-- If the Transport Layer encounters a fatal error, then FSM stays in error
-- state and *_ERROR_TRANSPORT_ERROR is signaled. To leave this state assert
-- synchronous reset for whole SATA stack.
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

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use 		PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.components.all;
use 		PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_StreamingLayer is
	generic (
		ENABLE_DEBUGPORT							: BOOLEAN									:= FALSE;			-- export internal signals to upper layers for debug purposes
		DEBUG													: BOOLEAN									:= FALSE;
		SIM_EXECUTE_IDENTIFY_DEVICE		: BOOLEAN									:= TRUE;			-- required by CommandLayer: load device parameters
		LOGICAL_BLOCK_SIZE						: MEMORY 									:= 8 KiB			-- accessable logical block size: 8 KiB (independant from device)
	);																																			-- 8 KiB, maximum supported is 64 KiB, with 512 B device logical blocks
	port (
		Clock													: in	STD_LOGIC;
		ClockEnable										: in	STD_LOGIC;
		Reset													: in	STD_LOGIC;

		-- CommandLayer interface
		-- ========================================================================
		Command												: in	T_SATA_STREAMING_COMMAND;
		Status												: out	T_SATA_STREAMING_STATUS;
		Error													: out	T_SATA_STREAMING_ERROR;

		DebugPortOut									: out T_SATADBG_STREAMING_OUT;

		-- for measurement purposes only
		Config_BurstSize							: in	T_SLV_16;
		
		-- address interface (valid on Command /= *_NONE)
		Address_AppLB									: in	T_SLV_48;
		BlockCount_AppLB							: in	T_SLV_48;
		
		-- 
		DriveInformation							: out T_SATA_DRIVE_INFORMATION;
		IDF_Bus												: out	T_SATA_IDF_BUS;

		-- TX path
		TX_Valid											: in	STD_LOGIC;
		TX_Data												: in	T_SLV_32;
		TX_SOR												: in	STD_LOGIC;
		TX_EOR												: in	STD_LOGIC;
		TX_Ack												: out	STD_LOGIC;

		-- RX path
		RX_Valid											: out	STD_LOGIC;
		RX_Data												: out	T_SLV_32;
		RX_SOR												: out	STD_LOGIC;
		RX_EOR												: out	STD_LOGIC;
		RX_Ack												: in	STD_LOGIC;

		-- TransportLayer interface
		-- ========================================================================
		Trans_ResetDone 							: in  STD_LOGIC;
		Trans_Command									: out	T_SATA_TRANS_COMMAND;
		Trans_Status									: in	T_SATA_TRANS_STATUS;
		Trans_Error										: in	T_SATA_TRANS_ERROR;
	
		-- ATA registers
		Trans_ATAHostRegisters				: out	T_SATA_ATA_HOST_REGISTERS;
		Trans_ATADeviceRegisters			: in	T_SATA_ATA_DEVICE_REGISTERS;
	
		-- TX path
		Trans_TX_Valid								: out	STD_LOGIC;
		Trans_TX_Data									: out	T_SLV_32;
		Trans_TX_SOT									: out	STD_LOGIC;
		Trans_TX_EOT									: out	STD_LOGIC;
		Trans_TX_Ack									: in	STD_LOGIC;

		-- RX path
		Trans_RX_Valid								: in	STD_LOGIC;
		Trans_RX_Data									: in	T_SLV_32;
		Trans_RX_SOT									: in	STD_LOGIC;
		Trans_RX_EOT									: in	STD_LOGIC;
		Trans_RX_Ack									: out	STD_LOGIC
	);
end;


architecture rtl of sata_StreamingLayer is
	attribute KEEP													: BOOLEAN;
	attribute FSM_ENCODING									: STRING;

	-- my reset
	signal MyReset 													: STD_LOGIC;
	
	-- ===========================================================================
	-- CommandLayer configurations
	-- ===========================================================================
	constant SHIFT_WIDTH										: POSITIVE								:= 8;						-- supports logical block sizes from 512 B to 4 KiB
	constant AHEAD_CYCLES_FOR_INSERT_EOT		: NATURAL									:= 1;

	-- CommandFSM
	-- ==========================================================================
	signal Status_i													: T_SATA_STREAMING_STATUS;
	signal Error_i													: T_SATA_STREAMING_ERROR;

	signal SFSM_TX_en												: STD_LOGIC;
	SIGNAL SFSM_TX_ForceEOT									: STD_LOGIC;
	SIGNAL SFSM_TX_FIFO_ForceGot						: STD_LOGIC;
	
	signal SFSM_RX_SOR											: STD_LOGIC;
	signal SFSM_RX_EOR											: STD_LOGIC;
	signal SFSM_RX_ForcePut									: STD_LOGIC;

	signal SFSM_DebugPortOut								: T_SATADBG_STREAMING_SFSM_OUT;

	signal ATA_CommandCategory							: T_SATA_COMMAND_CATEGORY;
	
	-- AddressCalculation
	-- ==========================================================================
	signal AdrCalc_Address_DevLB						: T_SLV_48;
	signal AdrCalc_BlockCount_DevLB					: T_SLV_48;

	-- TX_FIFO
	-- ==========================================================================
	signal TX_FIFO_Full											: STD_LOGIC;
	signal TX_FIFO_put											: STD_LOGIC;
	signal TX_FIFO_got											: STD_LOGIC;
	signal TX_FIFO_DataIn										: STD_LOGIC_VECTOR(33 downto 0);
	signal TX_FIFO_DataOut									: STD_LOGIC_VECTOR(33 downto 0);
	
	-- TX path data interface after TX_FIFO
	signal TX_FIFO_Data											: T_SLV_32;
	signal TX_FIFO_SOR											: STD_LOGIC;
	signal TX_FIFO_EOR											: STD_LOGIC;
	signal TX_FIFO_Valid										: STD_LOGIC;		
	
	-- TX path
	-- ==========================================================================
	signal TC_TX_Ack												: STD_LOGIC;
	signal TC_TX_Valid											: STD_LOGIC;
	signal TC_TX_Data												: T_SLV_32;
	signal TC_TX_SOT												: STD_LOGIC;
	signal TC_TX_EOT												: STD_LOGIC;
	signal TC_TX_InsertEOT									: STD_LOGIC;
	
	-- RX_FIFO
	-- ==========================================================================
	signal RX_FIFO_put											: STD_LOGIC;
	signal RX_FIFO_got											: STD_LOGIC;
	signal RX_FIFO_DataIn										: STD_LOGIC_VECTOR(33 downto 0);
	signal RX_FIFO_DataOut									: STD_LOGIC_VECTOR(33 downto 0);
	signal RX_FIFO_Valid										: STD_LOGIC;
	signal RX_FIFO_Full											: STD_LOGIC;

	-- IdentifyDeviceFilter
	-- ==========================================================================
	signal IDF_Reset												: STD_LOGIC;
	signal IDF_Enable												: STD_LOGIC;
	signal IDF_Error												: STD_LOGIC;
	signal IDF_Finished											: STD_LOGIC;
	
	signal IDF_Valid												: STD_LOGIC;
	signal IDF_Data													: T_SLV_32;
	signal IDF_SOT													: STD_LOGIC;
	signal IDF_EOT													: STD_LOGIC;
	signal IDF_DriveInformation							: T_SATA_DRIVE_INFORMATION;

	-- Internal version of output signals
	-- ========================================================================
	signal Trans_RX_Ack_i										: STD_LOGIC;
	
begin
	-- Reset sub-components until initial reset of SATAController has been
	-- completed. Allow synchronous 'Reset' only when ClockEnable = '1'.
	-- ===========================================================================
	MyReset <= (not Trans_ResetDone) or (Reset and ClockEnable);

	
	-- ================================================================
	-- logical block address calculations
	-- ================================================================
	AdrCalc : block
		signal Shift_us										: UNSIGNED(log2ceilnz(SHIFT_WIDTH) - 1 downto 0);
		type T_SHIFTED										is array(NATURAL range <>) of T_SLV_48;
		signal Address_AppLB_Shifted			: T_SHIFTED(SHIFT_WIDTH - 1 downto 0);
		signal BlockCount_AppLB_Shifted		: T_SHIFTED(SHIFT_WIDTH - 1 downto 0);
	begin
		Shift_us													<= to_unsigned(log2ceil(to_int(LOGICAL_BLOCK_SIZE, 1 Byte)) - to_integer(to_01(IDF_DriveInformation.LogicalBlockSize_ldB)), Shift_us'length);

		Address_AppLB_Shifted(0)					<= Address_AppLB;
		BlockCount_AppLB_Shifted(0)				<= BlockCount_AppLB;
		
		genShifted : for i in 1 to SHIFT_WIDTH - 1 generate
			Address_AppLB_Shifted(i)				<= Address_AppLB(Address_AppLB'high - i downto 0)			& (i - 1 downto 0 => '0');
			BlockCount_AppLB_Shifted(i)			<= BlockCount_AppLB(Address_AppLB'high - i downto 0)	& (i - 1 downto 0 => '0');
		end generate;
		
		AdrCalc_Address_DevLB 						<= Address_AppLB_Shifted(to_index(Shift_us, Address_AppLB_Shifted'length));
		AdrCalc_BlockCount_DevLB					<= BlockCount_AppLB_Shifted(to_index(Shift_us, BlockCount_AppLB_Shifted'length));
	end block;
	

	-- ================================================================
	-- Streaming Controller FSM
	-- ================================================================
	SFSM : entity PoC.sata_StreamingLayerFSM
		generic map (
			ENABLE_DEBUGPORT 							=> ENABLE_DEBUGPORT,
			SIM_EXECUTE_IDENTIFY_DEVICE		=> SIM_EXECUTE_IDENTIFY_DEVICE,
			DEBUG													=> DEBUG					
		)
		port map (
			Clock													=> Clock,
			MyReset												=> MyReset,

			-- for measurement purposes only
			Config_BurstSize							=> Config_BurstSize,
			
			-- CommandLayer interface			
			Command												=> Command,
			Status												=> Status_i,
			Error													=> Error_i,

			DebugPortOut                  => SFSM_DebugPortOut,
			
			Address_LB										=> AdrCalc_Address_DevLB,
			BlockCount_LB									=> AdrCalc_BlockCount_DevLB,

			TX_FIFO_Valid 								=> TX_FIFO_Valid,
			TX_FIFO_EOR 									=> TX_FIFO_EOR,
			TX_FIFO_ForceGot							=> SFSM_TX_FIFO_ForceGot,

			Trans_TX_Ack 									=> Trans_TX_Ack,
			TX_en													=> SFSM_TX_en,
			TX_ForceEOT										=> SFSM_TX_ForceEOT,
			
			RX_SOR												=> SFSM_RX_SOR,
			RX_EOR												=> SFSM_RX_EOR,
			RX_ForcePut										=> SFSM_RX_ForcePut,
			
			-- TransportLayer interface
			Trans_Command									=> Trans_Command,
			Trans_Status									=> Trans_Status,
			
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
	TX_FIFO_got																<= TC_TX_Ack or SFSM_TX_FIFO_ForceGot;
		
	TX_FIFO_DataIn(TX_Data'range)							<= TX_Data;
	TX_FIFO_DataIn(TX_Data'length	+ 0)				<= TX_SOR;
	TX_FIFO_DataIn(TX_Data'length	+ 1)				<= TX_EOR;
		
	TX_FIFO_Data															<= TX_FIFO_DataOut(TX_FIFO_Data'range);
	TX_FIFO_SOR																<= TX_FIFO_DataOut(TX_Data'length	+ 0);
	TX_FIFO_EOR																<= TX_FIFO_DataOut(TX_Data'length	+ 1);
		
	-- Commandlayer TX_FIFO
	TX_FIFO : entity PoC.fifo_glue
		generic map (
			D_BITS					=> TX_FIFO_DataIn'length
		)
		port map (
			clk							=> Clock,
			rst							=> MyReset,
			
			-- write interface
			put							=> TX_FIFO_put,
			di							=> TX_FIFO_DataIn,
			ful							=> TX_FIFO_Full,

			-- read interface
			got							=> TX_FIFO_got,
			vld							=> TX_FIFO_Valid,
			do							=> TX_FIFO_DataOut
		);

	TX_Ack					<= not TX_FIFO_Full;

	-- TX TransportCutter
	-- ===========================================================================
	TransportCutter : block
		signal TC_TX_DataFlow								: STD_LOGIC;
		
		signal InsertEOT_d									: STD_LOGIC						:= '0';
		signal InsertEOT_re									: STD_LOGIC;
		signal InsertEOT_re_d								: STD_LOGIC						:= '0';
		signal InsertEOT_re_d2							: STD_LOGIC						:= '0';
		
		signal IEOTC_Load										: STD_LOGIC;
		signal IEOTC_inc										: STD_LOGIC;
		signal IEOTC_uf											: STD_LOGIC;
	begin
		-- enable TX data path
		TC_TX_Valid					<= TX_FIFO_Valid		and SFSM_TX_en;
		TC_TX_Ack						<= Trans_TX_Ack			and SFSM_TX_en;

		TC_TX_DataFlow			<= TC_TX_Valid			and TC_TX_Ack;

		InsertEOT_d					<= ffdre(q => InsertEOT_d,     rst => MyReset, en => TC_TX_DataFlow, d => TC_TX_InsertEOT) 	when rising_edge(Clock);
		InsertEOT_re				<= TC_TX_InsertEOT	and not InsertEOT_d;
		InsertEOT_re_d			<= ffdre(q => InsertEOT_re_d,  rst => MyReset, en => TC_TX_DataFlow, d => InsertEOT_re) 		when rising_edge(Clock);
		InsertEOT_re_d2			<= ffdre(q => InsertEOT_re_d2, rst => MyReset, en => TC_TX_DataFlow, d => InsertEOT_re_d) 	when rising_edge(Clock);

		TC_TX_Data					<= TX_FIFO_Data;
		TC_TX_SOT						<= TX_FIFO_SOR			or InsertEOT_re_d2;
		TC_TX_EOT						<= TX_FIFO_EOR			or InsertEOT_re_d;

		IEOTC_Load					<= TC_TX_SOT				and TC_TX_Valid;
		IEOTC_inc						<= TC_TX_DataFlow		and not IEOTC_uf;
		
		IEOTC : block	-- InsertEOTCounter
			constant MAX_BLOCKCOUNT						: POSITIVE															:= ite(SIMULATION, C_SIM_MAX_BLOCKCOUNT, C_SATA_ATA_MAX_BLOCKCOUNT);
			constant MIN_TRANSFER_SIZE_ldB  	: POSITIVE															:= log2ceilnz(MAX_BLOCKCOUNT)+9;
			constant MIN_TRANSFER_SIZE_B			: POSITIVE															:= 2**MIN_TRANSFER_SIZE_ldB;
			constant MAX_TRANSFER_SIZE_ldB		: POSITIVE															:= MIN_TRANSFER_SIZE_ldB + (SHIFT_WIDTH - 1);
			constant IEOT_COUNTER_START				: POSITIVE															:= (MIN_TRANSFER_SIZE_B / 4) - AHEAD_CYCLES_FOR_INSERT_EOT - 3;		-- FIXME: replace with dynamic calculation
			constant IEOT_COUNTER_BITS				: POSITIVE															:= MAX_TRANSFER_SIZE_ldB - 2;
			
			signal Counter_s									: SIGNED(IEOT_COUNTER_BITS downto 0)			:= to_signed(IEOT_COUNTER_START, IEOT_COUNTER_BITS + 1);
		begin
			process(Clock)
			begin
				IF rising_edge(Clock) then
					if ((MyReset = '1') or (IEOTC_Load = '1')) then
						Counter_s				<=  to_signed(IEOT_COUNTER_START, IEOT_COUNTER_BITS + 1);		-- FIXME: replace with dynamic calculation
					else
						if (IEOTC_inc = '1') then
							Counter_s			<= Counter_s - 1;
						end if;
					end if;
				end if;
			end process;
			
			IEOTC_uf					<= Counter_s(Counter_s'high);
		end block;	-- InsertEOTCounter

		TC_TX_InsertEOT			<= IEOTC_uf;
		
		Trans_TX_Valid			<= TC_TX_Valid or SFSM_TX_ForceEOT;
		Trans_TX_Data				<= TC_TX_Data;
		Trans_TX_SOT				<= TC_TX_SOT;
		Trans_TX_EOT				<= TC_TX_EOT   or SFSM_TX_ForceEOT;
		
	end block;	-- TransferCutter

	-- CommandLayer RX_FIFO
	RX_FIFO_put																<= (Trans_RX_Valid and not IDF_Enable) or SFSM_RX_ForcePut;
	RX_FIFO_DataIn(Trans_RX_Data'range)				<= Trans_RX_Data;
	RX_FIFO_DataIn(Trans_RX_Data'length	+ 0)	<= SFSM_RX_SOR;
	RX_FIFO_DataIn(Trans_RX_Data'length	+ 1)	<= SFSM_RX_EOR;


	RX_FIFO_got																<= RX_Ack;
	RX_Data																		<= RX_FIFO_DataOut(RX_Data'range);
	RX_SOR																		<= RX_FIFO_DataOut(RX_Data'length	+ 0);
	RX_EOR																		<= RX_FIFO_DataOut(RX_Data'length	+ 1);
	
	RX_FIFO : entity PoC.fifo_glue
		generic map (
			D_BITS						=> RX_FIFO_DataIn'length
		)
		port map (
			clk						=> Clock,
			rst						=> MyReset,

			-- write interface
			put						=> RX_FIFO_put,
			di						=> RX_FIFO_DataIn,
			ful						=> RX_FIFO_Full,

			-- read interface
			got						=> RX_FIFO_got,
			vld						=> RX_FIFO_Valid,
			do						=> RX_FIFO_DataOut
		);
	
	Trans_RX_Ack_i	 	<= (not RX_FIFO_Full) when (IDF_Enable = '0') else '1';					-- RX_Ack	 multiplexer
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
	IDF_Reset		<= MyReset;
	IDF_Valid		<= Trans_RX_Valid;
	IDF_Data		<= Trans_RX_Data;
	IDF_SOT			<= Trans_RX_SOT;
	IDF_EOT			<= Trans_RX_EOT;
	
	IDF : entity PoC.sata_ATA_IdentifyDeviceFilter
		generic map (
			DEBUG										=> DEBUG					
		)
		port map (
			Clock										=> Clock,
			Reset										=> IDF_Reset,
			
			Enable									=> IDF_Enable,
			Error										=> IDF_Error,
			Finished								=> IDF_Finished,
		
			Valid										=> IDF_Valid,
			Data										=> IDF_Data,
			SOT											=> IDF_SOT,
			EOT											=> IDF_EOT,
			
			DriveInformation				=> IDF_DriveInformation,
			IDF_Bus									=> IDF_Bus
		);

  -- debug ports
  -- ===========================================================================
  genDebugPort : IF (ENABLE_DEBUGPORT = TRUE) generate
  begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_generateCommandEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_STREAMING_COMMAND loop
					STD.TextIO.write(l, str_replace(T_SATA_STREAMING_COMMAND'image(i), "sata_stream_cmd_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_generateStatusEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_STREAMING_STATUS loop
					STD.TextIO.write(l, str_replace(T_SATA_STREAMING_STATUS'image(i), "sata_stream_status_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_generateErrorEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_STREAMING_ERROR loop
					STD.TextIO.write(l, str_replace(T_SATA_STREAMING_ERROR'image(i), "sata_stream_error_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
		
			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Streaming Layer - Command Enum",	dbg_generateCommandEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Stream_Command.tok"),
				1 => dbg_ExportEncoding("Streaming Layer - Status Enum",	dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Stream_Status.tok"),
				2 => dbg_ExportEncoding("Streaming Layer - Error Enum",		dbg_generateErrorEncodings,		PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Stream_Error.tok")
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
    DebugPortOut.SFSM <= SFSM_DebugPortOut;

		-- RX ----------------------------------------------------------------
    -- RX datapath to upper layer
    DebugPortOut.RX_Valid 			<= RX_FIFO_Valid;
    DebugPortOut.RX_Data  			<= RX_FIFO_DataOut(RX_Data'range);
    DebugPortOut.RX_SOR   			<= RX_FIFO_DataOut(RX_Data'length + 0);
    DebugPortOut.RX_EOR   			<= RX_FIFO_DataOut(RX_Data'length + 1);
    DebugPortOut.RX_Ack   			<= RX_Ack;

		-- RX datapath between demultiplexer, RX_FIFO and CFSM
    DebugPortOut.SFSM_RX_Valid	<= RX_FIFO_put;
    --see below DebugPortOut.SFSM_RX_Data  <= Trans_RX_Data;
    DebugPortOut.SFSM_RX_SOR		<= SFSM_RX_SOR;
    DebugPortOut.SFSM_RX_EOR		<= SFSM_RX_EOR;
    DebugPortOut.SFSM_RX_Ack		<= not RX_FIFO_FULL;
		
		-- RX datapath between demultiplexer and IDF
		-- is same as input from transport layer

		-- RX datapath from transport layer
    DebugPortOut.Trans_RX_Valid <= Trans_RX_Valid;
    DebugPortOut.Trans_RX_Data  <= Trans_RX_Data;
    DebugPortOut.Trans_RX_SOT   <= Trans_RX_SOT;
    DebugPortOut.Trans_RX_EOT   <= Trans_RX_EOT;
    DebugPortOut.Trans_RX_Ack   <= Trans_RX_Ack_i;

		-- TX ----------------------------------------------------------------
    DebugPortOut.SFSM_TX_ForceEOT	<= SFSM_TX_ForceEOT;
		
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
		DebugPortOut.TC_TX_InsertEOT	<= TC_TX_InsertEOT;

	end generate;
end;
