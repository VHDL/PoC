-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
-- 									Martin Zabel
--
-- Entity:					SATA Link Layer
--
-- Description:
-- -------------------------------------
-- Represents the Link Layer of the SATA stack and provides a logical link for
-- transmitting frames. The frames are transmitted across the physical link
-- provided by the Physical Layer (sata_PhysicalLayer).
--
-- The SATA Transport Layer and Link layer are connected via the TX_* path for
-- sending frames and RX_* path for receiving frames. Success or failure of a
-- transmission is indicated via the frame state FIFOs TX_FS_* and RX_FS_* for
-- each direction, respectivly.
--
-- As defined in Serial ATA Revision 3.0, section 9.4.4:
-- - Receiving DMAT is handled as R_IP.
-- - DMAT is not send.
--
-- Does not support dummy scrambling of TX primitives.
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
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.physical.all;
use			PoC.debug.all;
use			PoC.components.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_LinkLayer is
	generic (
		DEBUG												: boolean																:= FALSE;
		ENABLE_DEBUGPORT						: boolean																:= FALSE;
		CONTROLLER_TYPE							: T_SATA_DEVICE_TYPE										:= SATA_DEVICE_TYPE_HOST;
		MAX_FRAME_SIZE							: MEMORY																:= 8196 Byte;
		AHEAD_CYCLES_FOR_INSERT_EOF	: natural																:= 1
--		RETRYBUFFER									: BOOLEAN																:= TRUE		-- it's recommended by spec
	);
	port (
		Clock										: in	std_logic;
		ClockEnable							: in	std_logic;
		Reset										: in	std_logic;

		Command									: in	T_SATA_LINK_COMMAND;
		Status									: out	T_SATA_LINK_STATUS;
		Error										: out	T_SATA_LINK_ERROR;

		-- Debug ports
		DebugPortIn						 	: in  T_SATADBG_LINK_IN;
		DebugPortOut					 	: out T_SATADBG_LINK_OUT;

		-- TX port
		TX_SOF									: in	std_logic;
		TX_EOF									: in	std_logic;
		TX_Valid								: in	std_logic;
		TX_Data									: in	T_SLV_32;
		TX_Ack									: out	std_logic;
		TX_InsertEOF						: out	std_logic;

		TX_FS_Ack								: in	std_logic;
		TX_FS_Valid							:	out	std_logic;
		TX_FS_SendOK						: out	std_logic;
		TX_FS_SyncEsc						: out	std_logic;

		-- RX port
		RX_SOF									: out	std_logic;
		RX_EOF									: out	std_logic;
		RX_Valid								: out	std_logic;
		RX_Data									: out	T_SLV_32;
		RX_Ack									: in	std_logic;

		RX_FS_Ack								: in	std_logic;
		RX_FS_Valid							:	out	std_logic;
		RX_FS_CRCOK							: out	std_logic;
		RX_FS_SyncEsc						: out	std_logic;

		-- physical layer interface
		Phy_ResetDone 					: in  std_logic;
		Phy_Status							: in	T_SATA_PHY_STATUS;

		Phy_RX_Data							: in	T_SLV_32;
		Phy_RX_CharIsK					: in	T_SLV_4;

		Phy_TX_Data							: out	T_SLV_32;
		Phy_TX_CharIsK					: out	T_SLV_4

	);
end entity;


architecture rtl of sata_LinkLayer is
	attribute KEEP										: boolean;
-- ==================================================================
-- LinkLayer configuration
-- ==================================================================
-- TX path
	constant INSERT_ALIGN_INTERVAL			: positive				:= 256;

	constant TX_SOF_BIT									: natural					:= 32;
	constant TX_EOF_BIT									: natural					:= 33;
	constant TX_FIFO_BITS								: positive				:= 34;
	constant TX_FIFO_DEPTH							: positive				:= 16;  -- 16 = minimum, short FIFO required by SyncEsc in FISEncoder
	constant TX_SENDOK_BIT							: natural					:= 0;
	constant TX_SYNCESC_BIT							: natural					:= 1;
	constant TX_FSFIFO_BITS							: positive				:= 2;
	constant TX_FSFIFO_DEPTH						: positive				:= 4;
	constant TX_FSFIFO_EMPTYSTATE_BITS	: positive				:= log2ceilnz(TX_FSFIFO_DEPTH);

-- RX path
	constant RX_SOF_BIT									: natural					:= 32;
	constant RX_EOF_BIT									: natural					:= 33;
	constant RX_FIFO_BITS								: positive				:= 34;
	constant RX_FIFO_MIN_FREE_SPACE			: positive				:= 64;	-- unit: SATA words
	constant RX_FIFO_DEPTH							: positive				:= div_ceil(to_int(MAX_FRAME_SIZE, 1 Byte), 4) + RX_FIFO_MIN_FREE_SPACE;
	constant RX_FIFO_EMPTYSTATE_BITS		: positive				:= log2ceilnz(RX_FIFO_DEPTH / RX_FIFO_MIN_FREE_SPACE);

	constant RX_CRCOK_BIT								: natural					:= 0;
	constant RX_SYNCESC_BIT							: natural					:= 1;
	constant RX_FSFIFO_BITS							: natural					:= 2;
	constant RX_FSFIFO_DEPTH						: positive				:= 8;
	constant RX_FSFIFO_EMPTYSTATE_BITS	: positive				:= log2ceilnz(RX_FSFIFO_DEPTH);

-- CRC
	constant CRC32_POLYNOMIAL		: bit_vector(35 downto 0) := x"104C11DB7";
	constant CRC32_INIT					: T_SLV_32								:= x"52325032";

-- ==================================================================
-- signals
-- ==================================================================
	-- my reset
	signal MyReset 											: std_logic;

	-- internal version of transport layer outputs
	signal TX_InsertEOF_i 							: std_logic;

	-- transport layer interface below FIFO
	signal Trans_TX_SOF									: std_logic;
	signal Trans_TX_EOF									: std_logic;

	signal Trans_TXFS_SendOK						: std_logic;
	signal Trans_TXFS_SyncEsc						: std_logic;

	signal Trans_RX_SOF									: std_logic;
	signal Trans_RX_EOF									: std_logic;

	signal Trans_RXFS_CRCOK							: std_logic;
	signal Trans_RXFS_SyncEsc						: std_logic;

	-- TX FSM section
	signal CRCMux_ctrl									: std_logic;
--	signal ScramblerMux_ctrl						: STD_LOGIC;

	-- FIFO section
	signal TX_FIFO_rst								: std_logic;
	signal TX_FIFO_put								: std_logic;
--	signal TX_FIFO_EmptyState					: UNSIGNED(1 downto 0);
	signal TX_FIFO_Full								: std_logic;
	signal TX_FIFO_got								: std_logic;
	signal TX_FIFO_Valid							: std_logic;
	signal TX_FIFO_DataIn							: std_logic_vector(TX_FIFO_BITS - 1 downto 0);
	signal TX_FIFO_DataOut						: std_logic_vector(TX_FIFO_BITS - 1 downto 0);
	signal TX_FIFO_Commit							: std_logic;
	signal TX_FIFO_Rollback						: std_logic;

	signal TX_FSFIFO_rst							: std_logic;
	signal TX_FSFIFO_put							: std_logic;
	signal TX_FSFIFO_EmptyState				: std_logic_vector(TX_FSFIFO_EMPTYSTATE_BITS - 1 downto 0);
	signal TX_FSFIFO_Full							: std_logic;
	signal TX_FSFIFO_got							: std_logic;
	signal TX_FSFIFO_Valid						: std_logic;
	signal TX_FSFIFO_DataIn						: std_logic_vector(TX_FSFIFO_BITS - 1 downto 0);
	signal TX_FSFIFO_DataOut					: std_logic_vector(TX_FSFIFO_BITS - 1 downto 0);

	signal RX_FIFO_rst								: std_logic;
	signal RX_FIFO_put								: std_logic;
	signal RX_FIFO_commit							: std_logic;
	signal RX_FIFO_rollback						: std_logic;
	signal RX_FIFO_EmptyState					: std_logic_vector(RX_FIFO_EMPTYSTATE_BITS - 1 downto 0);
	signal RX_FIFO_SpaceAvailable			: std_logic;
	signal RX_FIFO_Full								: std_logic;
	signal RX_FIFO_got								: std_logic;
	signal RX_FIFO_Valid							: std_logic;
	signal RX_FIFO_DataIn							: std_logic_vector(RX_FIFO_BITS - 1 downto 0);
	signal RX_FIFO_DataOut						: std_logic_vector(RX_FIFO_BITS - 1 downto 0);

	signal RX_FSFIFO_rst							: std_logic;
	signal RX_FSFIFO_put							: std_logic;
	signal RX_FSFIFO_EmptyState				: std_logic_vector(RX_FSFIFO_EMPTYSTATE_BITS - 1 downto 0);
	signal RX_FSFIFO_Full							: std_logic;
	signal RX_FSFIFO_got							: std_logic;
	signal RX_FSFIFO_Valid						: std_logic;
	signal RX_FSFIFO_DataIn						: std_logic_vector(RX_FSFIFO_BITS - 1 downto 0);
	signal RX_FSFIFO_DataOut					: std_logic_vector(RX_FSFIFO_BITS - 1 downto 0);

	-- RX FIFO input/hold registers
	signal RX_DataReg_shift						: std_logic;
	signal RX_DataReg_DataIn					: T_SLV_32;
	signal RX_DataReg_d								: T_SLV_32													:= (others => '0');
	signal RX_DataReg_d2							: T_SLV_32													:= (others => '0');
	signal RX_DataReg_DataOut					: T_SLV_32;

	-- CRC section
	signal TX_CRC_rst									: std_logic;
	signal TX_CRC_Valid								: std_logic;
	signal TX_CRC_DataIn							: T_SLV_32;
	signal TX_CRC_DataOut							: T_SLV_32;

	signal RX_CRC_rst									: std_logic;
	signal RX_CRC_Valid								: std_logic;
	signal RX_CRC_DataOut							: T_SLV_32;

	signal RX_CRC_OK									: std_logic;

	-- scrambler section
	signal DataScrambler_en						: std_logic;
	signal DataScrambler_rst					: std_logic;
	signal DataScrambler_DataIn				: T_SLV_32;
	signal DataScrambler_DataOut			: T_SLV_32;

	-- TODO Feature Request: To be implemeted to reduce EMI.
--	signal DummyScrambler_en					: STD_LOGIC;
--	signal DummyScrambler_rst					: STD_LOGIC;
--	signal DummyScrambler_DataIn			: T_SLV_32;
--	signal DummyScrambler_DataOut			: T_SLV_32;

	signal DataUnscrambler_en					: std_logic;
	signal DataUnscrambler_rst				: std_logic;
	signal DataUnscrambler_DataIn			: T_SLV_32;
	signal DataUnscrambler_DataOut		: T_SLV_32;


	-- primitive section
	signal PM_DataIn									: T_SLV_32;
	signal PM_DataOut									: T_SLV_32;
	signal PM_CharIsK									: T_SLV_4;
	signal TX_Primitive								: T_SATA_PRIMITIVE;

	signal PD_DataIn									: T_SLV_32;
	signal PD_CharIsK									: T_SLV_4;
	signal RX_Primitive								: T_SATA_PRIMITIVE;
	signal RX_Primitive_d							: T_SATA_PRIMITIVE		:= SATA_PRIMITIVE_NONE;

	-- signal hold_counter : UNSIGNED(31 downto 0) := (others => '0') ;
	signal RX_Hold : std_logic;

	-- DebugPort
	signal LLFSM_DebugPortOut					: T_SATADBG_LINK_LLFSM_OUT;

begin
	-- Reset this unit until initial reset of lower layer has been completed.
	-- Allow synchronous 'Reset' only when ClockEnable = '1'.
	MyReset <= (not Phy_ResetDone) or (Reset and ClockEnable);


  -- ================================================================
	-- link layer control FSM
	-- ================================================================
	LLFSM : entity PoC.sata_LinkLayerFSM
		generic map (
			DEBUG										=> DEBUG,
			ENABLE_DEBUGPORT				=> ENABLE_DEBUGPORT,
			CONTROLLER_TYPE					=> CONTROLLER_TYPE,
			INSERT_ALIGN_INTERVAL		=> INSERT_ALIGN_INTERVAL
		)
		port map (
			Clock										=> Clock,
			MyReset									=> MyReset,

			Status									=> Status,
			Error										=> Error,
			-- normal vs. dma modus

			-- DebugPort
			DebugPortOut						=> LLFSM_DebugPortOut,

			-- transport layer interface
			Trans_TX_SOF						=> Trans_TX_SOF,
			Trans_TX_EOF						=> Trans_TX_EOF,

			Trans_TXFS_SendOK				=> Trans_TXFS_SendOK,
			Trans_TXFS_SyncEsc			=> Trans_TXFS_SyncEsc,

			Trans_RX_SOF						=> Trans_RX_SOF,
			Trans_RX_EOF						=> Trans_RX_EOF,

			Trans_RXFS_CRCOK				=> Trans_RXFS_CRCOK,
			Trans_RXFS_SyncEsc			=> Trans_RXFS_SyncEsc,

			-- physical layer interface
			Phy_Status							=> Phy_Status,

			-- primitive interface
			TX_Primitive						=> TX_Primitive,
			RX_Primitive						=> RX_Primitive_d,

			-- TX FIFO interface
			TX_FIFO_rst							=> TX_FIFO_rst,
			TX_FIFO_Valid						=> TX_FIFO_Valid,
			TX_FIFO_got							=> TX_FIFO_got,
			TX_FIFO_Commit					=> TX_FIFO_Commit,
			TX_FIFO_Rollback				=> TX_FIFO_Rollback,

			-- RX_FSFIFO interface
			TX_FSFIFO_rst						=> TX_FSFIFO_rst,
			TX_FSFIFO_put						=> TX_FSFIFO_put,
			TX_FSFIFO_Full					=> TX_FSFIFO_Full,

			-- RX_FIFO interface
			RX_FIFO_rst							=> RX_FIFO_rst,
			RX_FIFO_put							=> RX_FIFO_put,
			RX_FIFO_commit					=> RX_FIFO_commit,
			RX_FIFO_rollback				=> RX_FIFO_rollback,
			RX_FIFO_Full						=> RX_FIFO_Full,
			RX_FIFO_SpaceAvailable	=> RX_FIFO_SpaceAvailable,		-- lack of space

			-- RX FIFO input/hold register interface
			RX_DataReg_shift				=> RX_DataReg_shift,

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
	TX_Ack											<= not TX_FIFO_Full;

	Trans_TX_SOF								<= TX_FIFO_DataOut(TX_SOF_BIT);
	Trans_TX_EOF								<= TX_FIFO_DataOut(TX_EOF_BIT);

	-- TX frame status FIFO
	TX_FSFIFO_got								<= TX_FS_Ack;
	TX_FS_Valid									<= TX_FSFIFO_Valid;

	TX_FSFIFO_DataIn						<= (TX_SENDOK_BIT =>	Trans_TXFS_SendOK,
																	TX_SYNCESC_BIT =>	Trans_TXFS_SyncEsc);
	TX_FS_SendOK								<= TX_FSFIFO_DataOut(TX_SENDOK_BIT);
	TX_FS_SyncEsc								<= TX_FSFIFO_DataOut(TX_SYNCESC_BIT);

	-- RX path
	RX_Data											<= RX_FIFO_DataOut(RX_Data'range);
	RX_SOF											<= RX_FIFO_DataOut(RX_SOF_BIT);
	RX_EOF											<= RX_FIFO_DataOut(RX_EOF_BIT);
	RX_Valid										<= RX_FIFO_Valid;
	RX_FIFO_got									<= RX_Ack;

	RX_FIFO_DataIn							<= Trans_RX_EOF & Trans_RX_SOF & RX_DataReg_DataOut;

	-- RX frame status FIFO
	RX_FSFIFO_got								<= RX_FS_Ack;
	RX_FS_Valid									<= RX_FSFIFO_Valid;

	RX_FSFIFO_DataIn						<= (RX_CRCOK_BIT 		=> Trans_RXFS_CRCOK,
																	RX_SYNCESC_BIT 	=> Trans_RXFS_SyncEsc);
	RX_FS_CRCOK									<= RX_FSFIFO_DataOut(RX_CRCOK_BIT);
	RX_FS_SyncEsc								<= RX_FSFIFO_DataOut(RX_SYNCESC_BIT);

	-- ==========================================================================
	-- TX path input pre-processing
	-- ==========================================================================
	FrameCutter : block
		signal FC_TX_DataFlow								: std_logic;

		signal IEOFC_Load										: std_logic;
		signal IEOFC_inc										: std_logic;
		signal IEOFC_uf											: std_logic;
	begin
		FC_TX_DataFlow			<= TX_Valid and not TX_FIFO_Full;

		IEOFC_Load					<= TX_SOF;
		IEOFC_inc						<= FC_TX_DataFlow and not IEOFC_uf;

		IEOFC : block	-- InsertEOFCounter
			constant IEOF_COUNTER_START				: positive															:= (to_int(MAX_FRAME_SIZE, 1 Byte) / 4) - AHEAD_CYCLES_FOR_INSERT_EOF - 3;
			constant IEOF_COUNTER_BITS				: positive															:= log2ceilnz(IEOF_COUNTER_START);

			signal Counter_s									: signed(IEOF_COUNTER_BITS downto 0)		:= to_signed(IEOF_COUNTER_START, IEOF_COUNTER_BITS + 1);
		begin
			process(Clock)
			begin
				if rising_edge(Clock) then
					if ((MyReset = '1') or (IEOFC_Load = '1')) then
						Counter_s			<=  to_signed(IEOF_COUNTER_START, IEOF_COUNTER_BITS + 1);
					elsif (IEOFC_inc = '1') then
						Counter_s			<= Counter_s - 1;
					end if;
				end if;
			end process;

			IEOFC_uf			<= Counter_s(Counter_s'high);
		end block;	-- InsertEOFCounter

		TX_InsertEOF_i		<= IEOFC_uf;
		TX_InsertEOF 			<= TX_InsertEOF_i;
	end block;	-- FrameCutter

	-- ==========================================================================
	-- fifo section
	-- ================================================================
	-- TX path
	TX_FIFO : entity PoC.fifo_cc_got_tempgot
		generic map (
			D_BITS					=> TX_FIFO_BITS,				-- data width
			MIN_DEPTH				=> TX_FIFO_DEPTH,				-- minimum FIFO depth
			ESTATE_WR_BITS	=> 0,										-- empty state bits
			FSTATE_RD_BITS	=> 0,										-- full state bits
			DATA_REG				=> FALSE,								-- store data content in registers
			STATE_REG				=> TRUE,								-- registered Full/Empty indicators
			OUTPUT_REG			=> TRUE									 -- registered FIFO output
		)
		port map (
			clk							=> Clock,
			rst							=> TX_FIFO_rst,
			-- Write Interface
			put							=> TX_FIFO_put,
			din							=> TX_FIFO_DataIn,
			estate_wr				=> open,
			full						=> TX_FIFO_Full,
			-- Read Interface
			got							=> TX_FIFO_got,
			valid						=> TX_FIFO_Valid,
			dout						=> TX_FIFO_DataOut,
			fstate_rd				=> open,

			commit					=> TX_FIFO_Commit,
			rollback				=> TX_FIFO_Rollback
		);

	-- TX frame status path
	TX_FSFIFO : entity PoC.fifo_cc_got
		generic map (
			D_BITS					=> TX_FSFIFO_BITS,							-- data width
			MIN_DEPTH				=> TX_FSFIFO_DEPTH,							-- minimum FIFO depth
			ESTATE_WR_BITS	=> TX_FSFIFO_EMPTYSTATE_BITS,		-- empty state bits
			FSTATE_RD_BITS	=> 0,														-- full state bits
			DATA_REG				=> TRUE,												-- store data content in registers
			STATE_REG				=> TRUE,												-- registered Full/Empty indicators
			OUTPUT_REG			=> FALSE	  										-- registered FIFO output
		)
		port map (
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
			fstate_rd				=> open
		);

	-- RX path
	RX_FIFO : entity PoC.fifo_cc_got_tempput
		generic map (
			D_BITS					=> RX_FIFO_BITS,								-- data width
			MIN_DEPTH				=> RX_FIFO_DEPTH,								-- minimum FIFO depth
			ESTATE_WR_BITS	=> RX_FIFO_EMPTYSTATE_BITS,			-- empty state bits
			FSTATE_RD_BITS	=> 0,														-- full state bits
			DATA_REG				=> FALSE,												-- store data content in registers
			STATE_REG				=> TRUE,												-- registered Full/Empty indicators
			OUTPUT_REG			=> TRUE													-- registered FIFO output
		)
		port map (
			clk							=> Clock,
			rst							=> RX_FIFO_rst,
			-- Write Interface
			put							=> RX_FIFO_put,
			din							=> RX_FIFO_DataIn,
			estate_wr				=> RX_FIFO_EmptyState,
			full						=> RX_FIFO_Full,
			commit 					=> RX_FIFO_commit,
			rollback 				=> RX_FIFO_rollback,

			-- Read Interface
			got							=> RX_FIFO_got,
			valid						=> RX_FIFO_Valid,
			dout						=> RX_FIFO_DataOut,
			fstate_rd				=> open
		);

	RX_FIFO_SpaceAvailable <= to_sl(RX_FIFO_EmptyState /= (RX_FIFO_EmptyState'range => '0'));

	RX_DataReg_DataIn		<= DataUnscrambler_DataOut;
	RX_DataReg_d				<= RX_DataReg_DataIn	when (rising_edge(Clock) and (RX_DataReg_shift = '1'));
	RX_DataReg_d2				<= RX_DataReg_d				when (rising_edge(Clock) and (RX_DataReg_shift = '1'));
	RX_DataReg_DataOut	<= RX_DataReg_d2;

	-- RX frame status path
	RX_FSFIFO : entity PoC.fifo_cc_got
		generic map (
			D_BITS					=> RX_FSFIFO_BITS,								-- data width
			MIN_DEPTH				=> RX_FSFIFO_DEPTH,								-- minimum FIFO depth
			ESTATE_WR_BITS	=> RX_FSFIFO_EMPTYSTATE_BITS,			-- empty state bits
			FSTATE_RD_BITS	=> 0,															-- full state bits
			DATA_REG				=> TRUE,													-- store data content in registers
			STATE_REG				=> TRUE,													-- registered Full/Empty indicators
			OUTPUT_REG			=> FALSE													-- registered FIFO output
		)
		port map (
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
			fstate_rd				=> open
		);

	-- CRC section
	-- ================================================================
	-- TX path
	TX_CRC_DataIn			<= TX_FIFO_DataOut(TX_CRC_DataIn'range);

	TX_CRC : entity PoC.comm_crc
		generic map (
			GEN							=> CRC32_POLYNOMIAL(32 downto 0),		-- Generator Polynom
			BITS						=> 32																-- Number of Bits to be processed in parallel
		)
		port map (
			clk							=> Clock,														-- Clock

			set							=> TX_CRC_rst,											-- Parallel Preload of Remainder
			init						=> CRC32_INIT,
			step						=> TX_CRC_Valid,										-- Process Input Data (MSB first)
			din							=> TX_CRC_DataIn,

			rmd							=> TX_CRC_DataOut,									-- Remainder
			zero						=> open															-- Remainder is Zero
		);

	DataScrambler_DataIn <= mux(CRCMux_ctrl, TX_CRC_DataIn, TX_CRC_DataOut);


	-- RX path
	RX_CRC : entity PoC.comm_crc
		generic map (
			GEN							=> CRC32_POLYNOMIAL(32 downto 0),		-- Generator Polynom
			BITS						=> 32																-- Number of Bits to be processed in parallel
		)
		port map (
			clk							=> Clock,														-- Clock

			set							=> RX_CRC_rst,											-- Parallel Preload of Remainder
			init						=> CRC32_INIT,
			step						=> RX_CRC_Valid,										-- Process Input Data (MSB first)
			din							=> DataUnscrambler_DataOut,

			rmd							=> RX_CRC_DataOut,									-- Remainder
			zero						=> open															-- Remainder is Zero
		);

	RX_CRC_OK <= to_sl(RX_CRC_DataOut = DataUnscrambler_DataOut);


	-- scrambler section
	-- ================================================================
	-- TX path
	DataScrambler : entity PoC.sata_Scrambler
		generic map (
			POLYNOMIAL							=> x"1A011",					-- "1A011" = "1 1010 0000 0001 0001" = x^16 + x^15 + x^13 + x^4 + 1,
			SEED										=> x"FFFF",
			WIDTH										=> 32
		)
		port map (
			Clock										=> Clock,
			Enable									=> DataScrambler_en,
			Reset										=> DataScrambler_rst,

			DataIn									=> DataScrambler_DataIn,
			DataOut									=> DataScrambler_DataOut
		);

  --TODO Feature Request: To be implemented to reduce EMI.
--  DummyScrambler_DataIn <= (others => '0');

--	DummyScrambler : entity PoC.sata_Scrambler
--		generic map (
--			POLYNOMIAL							=> x"1A011",
--			SEED										=> x"FFFF",
--			WIDTH										=> 32
--		)
--		port map (
--			Clock										=> Clock,
--			Enable									=> DummyScrambler_en,
--			Reset										=> DummyScrambler_rst,
--
--			DataIn									=> DummyScrambler_DataIn,
--			DataOut									=> DummyScrambler_DataOut
--		);

	genBitError : if (ENABLE_DEBUGPORT = TRUE) generate
		signal data : std_logic_vector(31 downto 0);
	begin
		data <= DataScrambler_DataOut;-- when (ScramblerMux_ctrl = '0') else DummyScrambler_DataOut;
		PM_DataIn(31 downto 1) 	<= data(31 downto 1);
		PM_DataIn(0) 						<= mux(DebugPortIn.InsertBitErrorHeaderTX and Trans_TX_SOF, -- only for FIS Header
																	 data(0), not data(0));
	end generate;

	genNoBitError : if not(ENABLE_DEBUGPORT = TRUE) generate
		PM_DataIn <= DataScrambler_DataOut;-- when (ScramblerMux_ctrl = '0') else DummyScrambler_DataOut;
	end generate;

	-- RX path
	DataUnscrambler : entity PoC.sata_Scrambler
		generic map (
			POLYNOMIAL							=> x"1A011",
			SEED										=> x"FFFF",
			WIDTH										=> 32
		)
		port map (
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
	process(TX_Primitive, PM_DataIn)
	begin
		if (TX_Primitive = SATA_PRIMITIVE_NONE) then		-- no primitive
			PM_DataOut		<= PM_DataIn;										-- passthrough data word
			PM_CharIsK		<= "0000";
		else																						-- Send Primitive
			PM_DataOut		<= to_sata_word(TX_Primitive);	-- access ROM
			PM_CharIsK		<= "0001";											-- mark primitive with K-symbols
		end if;
	end process;

	-- RX path
	PD : entity PoC.sata_PrimitiveDetector
		port map (
			Clock									=> Clock,

			RX_DataIn							=> PD_DataIn,
			RX_CharIsK						=> PD_CharIsK,

			Primitive							=> RX_Primitive
		);

	RX_Primitive_d	<= 	RX_Primitive when rising_edge(Clock);

	-- ================================================================
	-- physical layer interface
	-- ================================================================
	-- TX path
	Phy_TX_Data								<= PM_DataOut;
	Phy_TX_CharIsK						<= PM_CharIsK;


	-- RX path
	PD_DataIn									<= Phy_RX_Data;
	PD_CharIsK								<= Phy_RX_CharIsK;

	DataUnscrambler_DataIn		<= Phy_RX_Data when rising_edge(Clock);

	-- ================================================================
	-- debug ports
	-- ================================================================
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
	begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_generateCommandEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_LINK_COMMAND loop
					STD.TextIO.write(l, str_replace(T_SATA_LINK_COMMAND'image(i), "sata_link_cmd", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			function dbg_generateStatusEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_LINK_STATUS loop
					STD.TextIO.write(l, str_replace(T_SATA_LINK_STATUS'image(i), "sata_link_status_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			function dbg_generateErrorEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_LINK_ERROR loop
					STD.TextIO.write(l, str_replace(T_SATA_LINK_ERROR'image(i), "sata_link_error_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;

			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Link Layer - Command Enum",	dbg_generateCommandEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Link_Command.tok"),
				1 => dbg_ExportEncoding("Link Layer - Status Enum",		dbg_generateStatusEncodings,	PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Link_Status.tok"),
				2 => dbg_ExportEncoding("Link Layer - Error Enum",		dbg_generateErrorEncodings,		PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Link_Error.tok")
			);
		begin
		end generate;

		DebugPortOut.LLFSM											<= LLFSM_DebugPortOut;

		-- from physical layer
		DebugPortOut.Phy_Ready									<= to_sl(Phy_Status = SATA_PHY_STATUS_COMMUNICATING);
		-- RX: from physical layer
		DebugPortOut.RX_Phy_Data								<= Phy_RX_Data;
		DebugPortOut.RX_Phy_CiK									<= Phy_RX_CharIsK;
		-- RX: after primitive detector
		DebugPortOut.RX_Primitive								<= RX_Primitive_d;
		-- RX: after unscrambling
		DebugPortOut.RX_DataUnscrambler_rst			<= DataUnscrambler_rst;
		DebugPortOut.RX_DataUnscrambler_en			<= DataUnscrambler_en;
		DebugPortOut.RX_DataUnscrambler_DataOut	<= DataUnscrambler_DataOut;
		-- RX: CRC control
		DebugPortOut.RX_CRC_rst									<= RX_CRC_rst;
		DebugPortOut.RX_CRC_en									<= RX_CRC_Valid;
		-- RX: DataRegisters
		DebugPortOut.RX_DataReg_shift						<= RX_DataReg_shift;
		-- RX: before RX_FIFO
		DebugPortOut.RX_FIFO_SpaceAvailable			<= RX_FIFO_SpaceAvailable;
		DebugPortOut.RX_FIFO_rst								<= RX_FIFO_rst;
		DebugPortOut.RX_FIFO_put								<= RX_FIFO_put;
		DebugPortOut.RX_FIFO_commit							<= RX_FIFO_commit;
		DebugPortOut.RX_FIFO_rollback						<= RX_FIFO_rollback;
		DebugPortOut.RX_FSFIFO_rst							<= RX_FSFIFO_rst;
		DebugPortOut.RX_FSFIFO_put							<= RX_FSFIFO_put;
		-- RX: after RX_FIFO
		DebugPortOut.RX_Data										<= RX_FIFO_DataOut(RX_Data'range);
		DebugPortOut.RX_Valid										<= RX_FIFO_Valid;
		DebugPortOut.RX_Ack											<= RX_Ack;
		DebugPortOut.RX_SOF											<= RX_FIFO_DataOut(RX_SOF_BIT);
		DebugPortOut.RX_EOF											<= RX_FIFO_DataOut(RX_EOF_BIT);
		DebugPortOut.RX_FS_Valid								<= RX_FSFIFO_Valid;
		DebugPortOut.RX_FS_Ack									<= RX_FS_Ack;
		DebugPortOut.RX_FS_CRCOK								<= RX_FSFIFO_DataOut(RX_CRCOK_BIT);
		DebugPortOut.RX_FS_SyncEsc							<= RX_FSFIFO_DataOut(RX_SYNCESC_BIT);
		--
		-- TX: from Link Layer
		DebugPortOut.TX_Data										<= TX_Data;
		DebugPortOut.TX_Valid										<= TX_Valid;
		DebugPortOut.TX_Ack											<= not TX_FIFO_Full;
		DebugPortOut.TX_SOF											<= TX_SOF;
		DebugPortOut.TX_EOF											<= TX_EOF;
		DebugPortOut.TX_InsertEOF								<= TX_InsertEOF_i;
		DebugPortOut.TX_FS_Valid								<= TX_FSFIFO_Valid;
		DebugPortOut.TX_FS_Ack									<= not TX_FSFIFO_Full;
		DebugPortOut.TX_FS_SendOK								<= TX_FSFIFO_DataOut(TX_SENDOK_BIT);
		DebugPortOut.TX_FS_SyncEsc							<= TX_FSFIFO_DataOut(TX_SYNCESC_BIT);
		-- TX: TXFIFO
		DebugPortOut.TX_FIFO_got								<= TX_FIFO_got;
		DebugPortOut.TX_FSFIFO_got							<= TX_FSFIFO_got;
		-- TX: CRC control
		DebugPortOut.TX_CRC_rst									<= TX_CRC_rst;
		DebugPortOut.TX_CRC_en									<= TX_CRC_Valid;
		DebugPortOut.TX_CRC_mux									<= CRCMux_ctrl;
		-- TX: after scrambling
		DebugPortOut.TX_DataScrambler_rst				<= DataScrambler_rst;
		DebugPortOut.TX_DataScrambler_en				<= DataScrambler_en;
		DebugPortOut.TX_DataScrambler_DataOut		<= DataScrambler_DataOut;
		-- TX: PrimitiveMux
		DebugPortOut.TX_Primitive								<= TX_Primitive;
		-- TX: to Physical Layer
		DebugPortOut.TX_Phy_Data								<= PM_DataOut;
		DebugPortOut.TX_Phy_CiK									<= PM_CharIsK;
	end generate;
end;
