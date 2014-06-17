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
USE			PoC.sata.ALL;


ENTITY sata_LinkLayer IS
	GENERIC (
		DEBUG												: BOOLEAN																:= FALSE;
		CONTROLLER_TYPE							: T_SATA_DEVICE_TYPE										:= SATA_DEVICE_TYPE_HOST;
		MAX_FRAME_SIZE_B						: POSITIVE															:= 2048;
		AHEAD_CYCLES_FOR_INSERT_EOF	: NATURAL																:= 1;
		RETRYBUFFER									: BOOLEAN																:= TRUE
	);
	PORT (
		Clock										: IN	STD_LOGIC;
		Reset										: IN	STD_LOGIC;
		
		Command									: IN	T_SATA_LINK_COMMAND;
		Status									: OUT	T_SATA_LINK_STATUS;
		Error										: OUT	T_SATA_LINK_ERROR;

		-- Debug ports
--		DebugPort_Out					 	: OUT T_DBG_LINKOUT;
		
		-- TX port
		TX_SOF									: IN	STD_LOGIC;
		TX_EOF									: IN	STD_LOGIC;
		TX_Valid								: IN	STD_LOGIC;
		TX_Data									: IN	T_SLV_32;
		TX_Ready								: OUT	STD_LOGIC;
		TX_InsertEOF						: OUT	STD_LOGIC;
		
		TX_FS_Ready							: IN	STD_LOGIC;
		TX_FS_Valid							:	OUT	STD_LOGIC;
		TX_FS_SendOK						: OUT	STD_LOGIC;
		TX_FS_Abort							: OUT	STD_LOGIC;
		
		-- RX port
		RX_SOF									: OUT	STD_LOGIC;
		RX_EOF									: OUT	STD_LOGIC;
		RX_Valid								: OUT	STD_LOGIC;
		RX_Data									: OUT	T_SLV_32;
		RX_Ready								: IN	STD_LOGIC;
		
		RX_FS_Ready							: IN	STD_LOGIC;
		RX_FS_Valid							:	OUT	STD_LOGIC;
		RX_FS_CRC_OK						: OUT	STD_LOGIC;
		RX_FS_Abort							: OUT	STD_LOGIC;

		-- physical layer interface
		Phy_Status							: IN	T_SATA_PHY_STATUS;
		
		Phy_RX_Data							: IN	T_SLV_32;
		Phy_RX_CharIsK					: IN	T_SATA_CIK;
		
		Phy_TX_Data							: OUT	T_SLV_32;
		Phy_TX_CharIsK					: OUT	T_SATA_CIK

	);
END;

ARCHITECTURE rtl OF sata_LinkLayer IS
	ATTRIBUTE KEEP										: BOOLEAN;
-- ==================================================================
-- LinkLayer configuration
-- ==================================================================
-- TX path																							current value																	test value			default value
	CONSTANT INSERT_ALIGN_INTERVAL			: POSITIVE				:= 256;																	--				16							 256
	CONSTANT TX_FIFO_DEPTH							: POSITIVE				:= ite(SIMULATION, 16, 32);							--				16								32
	CONSTANT TX_RPFIFO_DEPTH						: POSITIVE				:= 16;																	--				16								16
	CONSTANT TX_FSFIFO_DEPTH						: POSITIVE				:= 4;																		-- 				 4								 4								max frames in TX_FIFO
	CONSTANT TX_FSFIFO_EMPTYSTATE_BITS	: POSITIVE				:= log2ceilnz(TX_FSFIFO_DEPTH);
	
-- RX path
	CONSTANT RX_FIFO_DEPTH							: POSITIVE				:= ite(SIMULATION, 64, 4096);						--				64							4096								max frame payload length between SOF end EOF is 2064 Bytes
	CONSTANT RX_FIFO_MIN_FREE_SPACE			: POSITIVE				:= ite(SIMULATION, 32, 	64);						-- 				32								64								min. free space in RX FIFO, min. 32 32-Bit words
	CONSTANT RX_FIFO_EMPTYSTATE_BITS		: POSITIVE				:= log2ceilnz(RX_FIFO_DEPTH / RX_FIFO_MIN_FREE_SPACE);

	CONSTANT RX_FSFIFO_DEPTH						: POSITIVE				:= 8;																		--				 8								 8								max frames in RX_FIFO
	CONSTANT RX_FSFIFO_EMPTYSTATE_BITS	: POSITIVE				:= log2ceilnz(RX_FSFIFO_DEPTH);

	-- 
	SIGNAL Reset_i											: STD_LOGIC;

	-- transport layer interface
	SIGNAL Trans_TX_SOF									: STD_LOGIC;
	SIGNAL Trans_TX_EOF									: STD_LOGIC;
	SIGNAL Trans_TX_Abort								: STD_LOGIC;

	SIGNAL Trans_TXFS_SendOK						: STD_LOGIC;
	SIGNAL Trans_TXFS_Abort							: STD_LOGIC;

	SIGNAL Trans_RX_SOF									: STD_LOGIC;
	SIGNAL Trans_RX_EOF									: STD_LOGIC;
	SIGNAL Trans_RX_Abort								: STD_LOGIC;

	SIGNAL Trans_RXFS_CRC_OK						: STD_LOGIC;
	SIGNAL Trans_RXFS_Abort							: STD_LOGIC;
	
	-- physical layer interface
	SIGNAL Phy_Ready										: STD_LOGIC;
	
	-- link layer control FSM


	-- TX FSM section
	SIGNAL CRCMux_ctrl									: STD_LOGIC;
--	SIGNAL ScramblerMux_ctrl						: STD_LOGIC;
	
	-- RX FSM section

	
	-- FIFO section
	SIGNAL TX_FIFO_rst								: STD_LOGIC;
	SIGNAL TX_FIFO_put								: STD_LOGIC;
--	SIGNAL TX_FIFO_EmptyState					: UNSIGNED(1 DOWNTO 0);
	SIGNAL TX_FIFO_Full								: STD_LOGIC;
	SIGNAL TX_FIFO_got								: STD_LOGIC;
	SIGNAL TX_FIFO_Valid							: STD_LOGIC;
	SIGNAL TX_FIFO_DataIn							: STD_LOGIC_VECTOR(33 DOWNTO 0);
	SIGNAL TX_FIFO_DataOut						: STD_LOGIC_VECTOR(33 DOWNTO 0);
	
	SIGNAL TX_FSFIFO_rst							: STD_LOGIC;
	SIGNAL TX_FSFIFO_put							: STD_LOGIC;
	SIGNAL TX_FSFIFO_EmptyState				: STD_LOGIC_VECTOR(TX_FSFIFO_EMPTYSTATE_BITS - 1 DOWNTO 0);
	SIGNAL TX_FSFIFO_Full							: STD_LOGIC;
	SIGNAL TX_FSFIFO_got							: STD_LOGIC;
	SIGNAL TX_FSFIFO_Valid						: STD_LOGIC;
	SIGNAL TX_FSFIFO_DataIn						: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL TX_FSFIFO_DataOut					: STD_LOGIC_VECTOR(1 DOWNTO 0);
	
	SIGNAL RX_FIFO_rst								: STD_LOGIC;
	SIGNAL RX_FIFO_put								: STD_LOGIC;
	SIGNAL RX_FIFO_EmptyState					: STD_LOGIC_VECTOR(RX_FIFO_EMPTYSTATE_BITS - 1 DOWNTO 0);
	SIGNAL RX_FIFO_SpaceAvailable			: STD_LOGIC;
	SIGNAL RX_FIFO_Full								: STD_LOGIC;
	SIGNAL RX_FIFO_got								: STD_LOGIC;
	SIGNAL RX_FIFO_Valid							: STD_LOGIC;
	SIGNAL RX_FIFO_DataIn							: STD_LOGIC_VECTOR(33 DOWNTO 0);
	SIGNAL RX_FIFO_DataOut						: STD_LOGIC_VECTOR(33 DOWNTO 0);

	SIGNAL RX_FSFIFO_rst							: STD_LOGIC;
	SIGNAL RX_FSFIFO_put							: STD_LOGIC;
	SIGNAL RX_FSFIFO_EmptyState				: STD_LOGIC_VECTOR(RX_FSFIFO_EMPTYSTATE_BITS - 1 DOWNTO 0);
	SIGNAL RX_FSFIFO_Full							: STD_LOGIC;
	SIGNAL RX_FSFIFO_got							: STD_LOGIC;
	SIGNAL RX_FSFIFO_Valid						: STD_LOGIC;
	SIGNAL RX_FSFIFO_DataIn						: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL RX_FSFIFO_DataOut					: STD_LOGIC_VECTOR(1 DOWNTO 0);

	-- RX FIFO input/hold registers
	SIGNAL RX_DataReg_en1							: STD_LOGIC;
	SIGNAL RX_DataReg_en2							: STD_LOGIC;
	SIGNAL RX_DataReg_DataIn					: T_SLV_32;
	SIGNAL RX_DataReg_d								: T_SLV_32													:= (OTHERS => '0');
	SIGNAL RX_DataReg_d2							: T_SLV_32													:= (OTHERS => '0');
	SIGNAL RX_DataReg_DataOut					: T_SLV_32;

	-- CRC section
	SIGNAL TX_CRC_rst									: STD_LOGIC;
	SIGNAL TX_CRC_Valid								: STD_LOGIC;
	SIGNAL TX_CRC_DataIn							: T_SLV_32;
	SIGNAL TX_CRC_DataOut							: T_SLV_32;

	SIGNAL RX_CRC_rst									: STD_LOGIC;
	SIGNAL RX_CRC_Valid								: STD_LOGIC;
	SIGNAL RX_CRC_DataOut							: T_SLV_32;

	SIGNAL RX_CRC_OK									: STD_LOGIC;
	
	-- scrambler section
	SIGNAL DataScrambler_en						: STD_LOGIC;
	SIGNAL DataScrambler_rst					: STD_LOGIC;
	SIGNAL DataScrambler_DataIn				: T_SLV_32;
	SIGNAL DataScrambler_DataOut			: T_SLV_32;
	
	-- TODO: 
--	SIGNAL DummyScrambler_en					: STD_LOGIC;
--	SIGNAL DummyScrambler_rst					: STD_LOGIC;
--	SIGNAL DummyScrambler_DataIn			: T_SLV_32;
--	SIGNAL DummyScrambler_DataOut			: T_SLV_32;
	
	SIGNAL DataUnscrambler_en					: STD_LOGIC;
	SIGNAL DataUnscrambler_rst				: STD_LOGIC;
	SIGNAL DataUnscrambler_DataIn			: T_SLV_32;
	SIGNAL DataUnscrambler_DataOut		: T_SLV_32;
	

	-- primitive section
	SIGNAL PM_DataIn									: T_SLV_32;
	SIGNAL PM_DataOut									: T_SLV_32;
	SIGNAL PM_CharIsK									: T_SATA_CIK;
	SIGNAL TX_Primitive								: T_SATA_PRIMITIVE;

	SIGNAL PD_DataIn									: T_SLV_32;
	SIGNAL PD_CharIsK									: T_SATA_CIK;
	SIGNAL RX_Primitive								: T_SATA_PRIMITIVE;
	SIGNAL RX_Primitive_d							: T_SATA_PRIMITIVE		:= SATA_PRIMITIVE_NONE;

	-- signal hold_counter : UNSIGNED(31 downto 0) := (OTHERS => '0') ;
	signal RX_Hold : STD_LOGIC;

BEGIN
	-- ================================================================
	-- link layer control FSM
	-- ================================================================
	Phy_Ready	<= to_sl(Phy_Status = SATA_PHY_STATUS_LINK_OK);
	Reset_i		<= Reset OR to_sl(Command = SATA_LINK_CMD_RESET);
	
	LLFSM : ENTITY PoC.sata_LinkLayerFSM
		GENERIC MAP (
			DEBUG										=> DEBUG					,
			CONTROLLER_TYPE					=> CONTROLLER_TYPE,
			INSERT_ALIGN_INTERVAL		=> INSERT_ALIGN_INTERVAL
		)
		PORT MAP (
			Clock										=> Clock,
			Reset										=> Reset_i,

			Status									=> Status,
			Error										=> Error,
			-- normal vs. dma modus

			-- transport layer interface
			Trans_TX_SOF						=> Trans_TX_SOF,
			Trans_TX_EOF						=> Trans_TX_EOF,
			--TODO: Trans_TX_Abort					=> Trans_TX_Abort,

			Trans_TXFS_SendOK				=> Trans_TXFS_SendOK,
			Trans_TXFS_Abort				=> Trans_TXFS_Abort,

			Trans_RX_SOF						=> Trans_RX_SOF,
			Trans_RX_EOF						=> Trans_RX_EOF,
			--TODO: Trans_RX_Abort					=> Trans_RX_Abort,

			Trans_RXFS_CRC_OK				=> Trans_RXFS_CRC_OK,
			Trans_RXFS_Abort				=> Trans_RXFS_Abort,

			-- physical layer interface
			Phy_Ready								=> Phy_Ready,
			
			-- primitive interface
			TX_Primitive						=> TX_Primitive,
			RX_Primitive						=> RX_Primitive,

			-- TX FIFO interface
			TX_FIFO_rst							=> TX_FIFO_rst,
			TX_FIFO_Valid						=> TX_FIFO_Valid,
			TX_FIFO_got							=> TX_FIFO_got,

			-- RX_FSFIFO interface
			TX_FSFIFO_rst						=> TX_FSFIFO_rst,
			TX_FSFIFO_put						=> TX_FSFIFO_put,
			TX_FSFIFO_Full					=> TX_FSFIFO_Full,

			-- RX_FIFO interface
			RX_FIFO_rst							=> RX_FIFO_rst,
			RX_FIFO_put							=> RX_FIFO_put,
			RX_FIFO_Full						=> RX_FIFO_Full,
			RX_FIFO_SpaceAvailable	=> RX_FIFO_SpaceAvailable,		-- lack of space 

			-- RX FIFO input/hold register interface
			RX_DataReg_en1					=> RX_DataReg_en1,
			RX_DataReg_en2					=> RX_DataReg_en2,

			-- RX_FSFIFO interface
			RX_FSFIFO_rst						=> RX_FSFIFO_rst,
			RX_FSFIFO_put						=> RX_FSFIFO_put,
			RX_FSFIFO_Full					=> RX_FSFIFO_Full,

			-- TX_CRC interface
			TX_CRC_rst							=> TX_CRC_rst,
			TX_CRC_Valid						=> TX_CRC_Valid,

			-- RX_CRC interface
			RX_CRC_rst							=> RX_CRC_rst,
			RX_CRC_Valid						=> RX_CRC_Valid,
			RX_CRC_OK								=> RX_CRC_OK,
			
			-- TX scrambler interface
			DataScrambler_en				=> DataScrambler_en,
			DataScrambler_rst				=> DataScrambler_rst,
--			DummyScrambler_en				=> DummyScrambler_en,
--			DummyScrambler_rst			=> DummyScrambler_rst,
			
			-- RX scrambler interface
			DataUnscrambler_en			=> DataUnscrambler_en,
			DataUnscrambler_rst			=> DataUnscrambler_rst,
			
			-- TX MUX interface
			CRCMux_ctrl							=> CRCMux_ctrl--,
--			ScramblerMux_ctrl				=> ScramblerMux_ctrl
		);


	-- ================================================================
	-- LocalLink interface
	-- ================================================================
	-- TX path
	TX_FIFO_DataIn							<= TX_EOF & TX_SOF & TX_Data;
	TX_FIFO_put									<= TX_Valid;
	TX_Ready										<= NOT TX_FIFO_Full;
	
	Trans_TX_SOF								<= TX_FIFO_DataOut(32);
	Trans_TX_EOF								<= TX_FIFO_DataOut(33);

	-- TX frame status FIFO
	TX_FSFIFO_got								<= TX_FS_Ready;
	TX_FS_Valid									<= TX_FSFIFO_Valid;
	
	TX_FSFIFO_DataIn						<= (0 => Trans_TXFS_SendOK, 1 => Trans_TXFS_Abort);
	TX_FS_SendOK								<= TX_FSFIFO_DataOut(0);
	TX_FS_Abort									<= TX_FSFIFO_DataOut(1);
	
	-- RX path
	RX_Data											<= RX_FIFO_DataOut(RX_Data'range);
	RX_SOF											<= RX_FIFO_DataOut(32);
	RX_EOF											<= RX_FIFO_DataOut(33);
	RX_Valid										<= RX_FIFO_Valid;
	RX_FIFO_got									<= RX_Ready;
	
	RX_FIFO_DataIn							<= Trans_RX_EOF & Trans_RX_SOF & RX_DataReg_DataOut;
	
	-- RX frame status FIFO
	RX_FSFIFO_got								<= RX_FS_Ready;
	RX_FS_Valid									<= RX_FSFIFO_Valid;
	
	RX_FSFIFO_DataIn						<= (0 => Trans_RXFS_CRC_OK, 1 => Trans_RXFS_Abort);
	RX_FS_CRC_OK								<= RX_FSFIFO_DataOut(0);
	RX_FS_Abort									<= RX_FSFIFO_DataOut(1);

	-- ==========================================================================	
	-- TX path input pre-processing
	-- ==========================================================================	
	FrameCutter : BLOCK
		SIGNAL FC_TX_DataFlow								: STD_LOGIC;
		
		SIGNAL IEOFC_Load										: STD_LOGIC;
		SIGNAL IEOFC_inc										: STD_LOGIC;
		SIGNAl IEOFC_ov											: STD_LOGIC;
	BEGIN
		FC_TX_DataFlow			<= TX_Valid AND NOT TX_FIFO_Full;

		IEOFC_Load					<= TX_SOF;
		IEOFC_inc						<= FC_TX_DataFlow AND NOT IEOFC_ov;
		
		IEOFC : BLOCK	-- InsertEOFCounter
			CONSTANT IEOF_COUNTER_START				: POSITIVE															:= (MAX_FRAME_SIZE_B / 4) - AHEAD_CYCLES_FOR_INSERT_EOF - 3;
			CONSTANT IEOF_COUNTER_BITS					: POSITIVE															:= log2ceilnz(IEOF_COUNTER_START);
			
			SIGNAL Counter_us									: SIGNED(IEOF_COUNTER_BITS DOWNTO 0)			:= to_signed(IEOF_COUNTER_START, IEOF_COUNTER_BITS + 1);
		BEGIN
			PROCESS(Clock)
			BEGIN
				IF rising_edge(Clock) THEN
					IF ((Reset = '1') OR (Command = SATA_LINK_CMD_RESET) OR (IEOFC_Load = '1')) THEN
						Counter_us				<=  to_signed(IEOF_COUNTER_START, IEOF_COUNTER_BITS + 1);
					ELSE
						IF (IEOFC_inc = '1') THEN
							Counter_us			<= Counter_us - 1;
						END IF;
					END IF;
				END IF;
			END PROCESS;
			
			IEOFC_ov			<= Counter_us(Counter_us'high);
		END BLOCK;	-- InsertEOFCounter

		TX_InsertEOF		<= IEOFC_ov;
	END BLOCK;	-- FrameCutter
	
	-- ==========================================================================
	-- fifo section
	-- ================================================================
	-- TX path
	TX_FIFO : ENTITY PoC.fifo_cc_got
		GENERIC MAP (
			D_BITS					=> TX_FIFO_DataIn'length,				-- data width
			MIN_DEPTH				=> TX_FIFO_DEPTH,								-- minimum FIFO depth
			ESTATE_WR_BITS	=> 0,														-- empty state bits
			FSTATE_RD_BITS	=> 0,														-- full state bits
			DATA_REG				=> FALSE,												-- store data content in registers
			STATE_REG			=> TRUE,												-- registered Full/Empty indicators
			OUTPUT_REG			=> TRUE												  -- registered FIFO output
		)
		PORT MAP (
			clk							=> Clock,
			rst							=> TX_FIFO_rst,
			-- Write Interface
			put							=> TX_FIFO_put,
			din							=> TX_FIFO_DataIn,
			estate_wr				=> OPEN,
			full						=> TX_FIFO_Full,
			-- Read Interface
			got							=> TX_FIFO_got,
			valid						=> TX_FIFO_Valid,
			dout						=> TX_FIFO_DataOut,
			fstate_rd				=> OPEN
		);
	
	-- TX frame status path
	TX_FSFIFO : ENTITY PoC.fifo_cc_got
		GENERIC MAP (
			D_BITS					=> TX_FSFIFO_DataIn'length,			-- data width
			MIN_DEPTH				=> TX_FSFIFO_DEPTH,							-- minimum FIFO depth
			ESTATE_WR_BITS	=> TX_FSFIFO_EMPTYSTATE_BITS,			-- empty state bits
			FSTATE_RD_BITS	=> 0,														-- full state bits
			DATA_REG				=> TRUE,												-- store data content in registers
			STATE_REG			=> TRUE,												-- registered Full/Empty indicators
			OUTPUT_REG			=> FALSE	  										-- registered FIFO output
		)
		PORT MAP (
			clk							=> Clock,
			rst							=> TX_FSFIFO_rst,
			
			-- Write Interface
			put							=> TX_FSFIFO_put,
			din							=> TX_FSFIFO_DataIn,
			full						=> TX_FSFIFO_Full,
			estate_wr				=> TX_FSFIFO_EmptyState,
			
			-- Read Interface
			got							=> TX_FSFIFO_got,
			valid						=> TX_FSFIFO_Valid,
			dout						=> TX_FSFIFO_DataOut,
			fstate_rd				=> OPEN
		);
	
	-- RX path
	RX_FIFO : ENTITY PoC.fifo_cc_got
		GENERIC MAP (
			D_BITS					=> RX_FIFO_DataIn'length,				-- data width
			MIN_DEPTH				=> RX_FIFO_DEPTH,								-- minimum FIFO depth
			ESTATE_WR_BITS	=> RX_FIFO_EMPTYSTATE_BITS,				-- empty state bits
			FSTATE_RD_BITS	=> 0,														-- full state bits
			DATA_REG				=> FALSE,												-- store data content in registers
			STATE_REG			=> TRUE,												-- registered Full/Empty indicators
			OUTPUT_REG			=> TRUE													-- registered FIFO output
		)
		PORT MAP (
			clk							=> Clock,
			rst							=> RX_FIFO_rst,
			-- Write Interface
			put							=> RX_FIFO_put,
			din							=> RX_FIFO_DataIn,
			estate_wr				=> RX_FIFO_EmptyState,
			full						=> RX_FIFO_Full,
			
			-- Read Interface
			got							=> RX_FIFO_got,
			valid						=> RX_FIFO_Valid,
			dout						=> RX_FIFO_DataOut,
			fstate_rd				=> OPEN
		);
	
	RX_FIFO_SpaceAvailable <= to_sl(RX_FIFO_EmptyState /= (RX_FIFO_EmptyState'range => '0'));
	
	RX_DataReg_DataIn		<= DataUnscrambler_DataOut;
	RX_DataReg_d				<= RX_DataReg_DataIn	WHEN (rising_edge(Clock) AND (RX_DataReg_en1 = '1'));
	RX_DataReg_d2				<= RX_DataReg_d				WHEN (rising_edge(Clock) AND (RX_DataReg_en2 = '1'));
	RX_DataReg_DataOut	<= RX_DataReg_d2;

	-- RX frame status path
	RX_FSFIFO : ENTITY PoC.fifo_cc_got
		GENERIC MAP (
			D_BITS					=> RX_FSFIFO_DataIn'length,				-- data width
			MIN_DEPTH				=> RX_FSFIFO_DEPTH,								-- minimum FIFO depth
			ESTATE_WR_BITS	=> RX_FSFIFO_EMPTYSTATE_BITS,				-- empty state bits
			FSTATE_RD_BITS	=> 0,														-- full state bits
			DATA_REG				=> TRUE,												-- store data content in registers
			STATE_REG			=> TRUE,												-- registered Full/Empty indicators
			OUTPUT_REG			=> FALSE												-- registered FIFO output
		)
		PORT MAP (
			clk							=> Clock,
			rst							=> RX_FSFIFO_rst,
			
			-- Write Interface
			put							=> RX_FSFIFO_put,
			din							=> RX_FSFIFO_DataIn,
			full						=> RX_FSFIFO_Full,
			estate_wr				=> RX_FSFIFO_EmptyState,
			
			-- Read Interface
			got							=> RX_FSFIFO_got,
			valid						=> RX_FSFIFO_Valid,
			dout						=> RX_FSFIFO_DataOut,
			fstate_rd				=> OPEN
		);

	-- CRC section
	-- ================================================================
	-- TX path
	TX_CRC_DataIn			<= TX_FIFO_DataOut(TX_CRC_DataIn'range);
	
	TX_CRC : ENTITY PoC.sata_TX_CRC32
		PORT MAP (
			Clock					=> Clock,
			Reset					=> TX_CRC_rst,

			Valid					=> TX_CRC_Valid,
			DataIn				=> TX_CRC_DataIn,
			DataOut				=> TX_CRC_DataOut
		);

	DataScrambler_DataIn <= TX_CRC_DataIn WHEN (CRCMux_ctrl = '0') ELSE TX_CRC_DataOut;
	
	
	-- RX path
	RX_CRC : ENTITY PoC.sata_RX_CRC32
		PORT MAP (
			Clock					=> Clock,
			Reset					=> RX_CRC_rst,

			Valid					=> RX_CRC_Valid,
			DataIn				=> DataUnscrambler_DataOut,
			DataOut				=> RX_CRC_DataOut
		);
	
	-- TODO: calculate signal
	RX_CRC_OK <= to_sl(RX_CRC_DataOut = DataUnscrambler_DataOut);
	
	
	-- scrambler section
	-- ================================================================
	-- TX path
	DataScrambler : ENTITY PoC.sata_Scrambler
		GENERIC MAP (
			POLYNOMIAL							=> x"1A011",					-- "1A011" = "1 1010 0000 0001 0001" = x^16 + x^15 + x^13 + x^4 + 1,
			SEED										=> x"FFFF",
			WIDTH										=> 32
		)
		PORT MAP (
			Clock										=> Clock,
			Enable									=> DataScrambler_en,
			Reset										=> DataScrambler_rst,
			
			DataIn									=> DataScrambler_DataIn,
			DataOut									=> DataScrambler_DataOut
		);

  --TODO:
--  DummyScrambler_DataIn <= (others => '0');
	
--	DummyScrambler : ENTITY PoC.sata_Scrambler
--		GENERIC MAP (
--			POLYNOMIAL							=> x"1A011",
--			SEED										=> x"FFFF",
--			WIDTH										=> 32
--		)
--		PORT MAP (
--			Clock										=> Clock,
--			Enable									=> DummyScrambler_en,
--			Reset										=> DummyScrambler_rst,
--
--			DataIn									=> DummyScrambler_DataIn,
--			DataOut									=> DummyScrambler_DataOut
--		);
	
	PM_DataIn <= DataScrambler_DataOut;-- WHEN (ScramblerMux_ctrl = '0') ELSE DummyScrambler_DataOut;

	-- RX path
	DataUnscrambler : ENTITY PoC.sata_Scrambler
		GENERIC MAP (
			POLYNOMIAL							=> x"1A011",
			SEED										=> x"FFFF",
			WIDTH										=> 32
		)
		PORT MAP (
			Clock										=> Clock,
			Enable									=> DataUnscrambler_en,
			Reset										=> DataUnscrambler_rst,
		
			DataIn									=> DataUnscrambler_DataIn,
			DataOut									=> DataUnscrambler_DataOut
		);


	-- ================================================================
	-- primitive section
	-- ================================================================
	-- TX path
	PM : ENTITY PoC.sata_PrimitiveMux
		PORT MAP (
			Primitive							=> TX_Primitive,
			
			TX_DataIn							=> PM_DataIn,
			TX_DataOut						=> PM_DataOut,
			TX_CharIsK						=> PM_CharIsK
		);


	-- RX path
	PD : ENTITY PoC.sata_PrimitiveDetector
		PORT MAP (
			Clock									=> Clock,
			
			RX_DataIn							=> PD_DataIn,
			RX_CharIsK						=> PD_CharIsK,
			
			Primitive							=> RX_Primitive_d
		);
	
	RX_Primitive	<= 	RX_Primitive_d WHEN rising_edge(Clock);

	-- ================================================================
	-- physical layer interface
	-- ================================================================
	-- TX path
	Phy_TX_Data								<= PM_DataOut;
	Phy_TX_CharIsK						<= PM_CharIsK;
	
	
	-- RX path
	PD_DataIn									<= Phy_RX_Data;
	PD_CharIsK								<= Phy_RX_CharIsK;
	
	DataUnscrambler_DataIn		<= Phy_RX_Data WHEN rising_edge(Clock);

	-- ================================================================
	-- debug ports
	-- ================================================================
--	DebugPort_Out.RX_Primitive	<= RX_Primitive;
	

	genCSP : IF (DEBUG = TRUE) GENERATE
		SIGNAL DBG_TX_SOF				: STD_LOGIC;
		SIGNAL DBG_TX_EOF				: STD_LOGIC;
		
		SIGNAL DBG_TXFS_SendOK	: STD_LOGIC;
		SIGNAL DBG_TXFS_SendOKn	: STD_LOGIC;
		
		SIGNAL DBG_RX_SOF				: STD_LOGIC;
		SIGNAL DBG_RX_EOF				: STD_LOGIC;
		
		SIGNAL DBG_RXFS_CRCOK		: STD_LOGIC;
		SIGNAL DBG_RXFS_CRCOKn	: STD_LOGIC;
		
		ATTRIBUTE KEEP OF DBG_TX_SOF				: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_TX_EOF				: SIGNAL IS TRUE;
		
		ATTRIBUTE KEEP OF DBG_TXFS_SendOK		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_TXFS_SendOKn	: SIGNAL IS TRUE;
		
		ATTRIBUTE KEEP OF DBG_RX_SOF				: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_RX_EOF				: SIGNAL IS TRUE;
		
		ATTRIBUTE KEEP OF DBG_RXFS_CRCOK		: SIGNAL IS TRUE;
		ATTRIBUTE KEEP OF DBG_RXFS_CRCOKn		: SIGNAL IS TRUE;
	BEGIN
	
	
		DBG_TX_SOF				<= TX_Valid AND TX_SOF;
		DBG_TX_EOF				<= TX_Valid AND TX_EOF;
		
		DBG_TXFS_SendOK		<= TX_FSFIFO_Valid AND			TX_FSFIFO_DataOut(0);
		DBG_TXFS_SendOKn	<= TX_FSFIFO_Valid AND NOT	TX_FSFIFO_DataOut(0);
		
		DBG_RX_SOF				<= RX_FIFO_Valid AND RX_FIFO_DataOut(32);
		DBG_RX_EOF				<= RX_FIFO_Valid AND RX_FIFO_DataOut(33);
		
		DBG_RXFS_CRCOK		<= RX_FSFIFO_Valid AND			RX_FSFIFO_DataOut(0);
		DBG_RXFS_CRCOKn		<= RX_FSFIFO_Valid AND NOT	RX_FSFIFO_DataOut(0);
	END GENERATE;
END;
