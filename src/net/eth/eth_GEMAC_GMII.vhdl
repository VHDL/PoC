-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
--use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.net.all;


entity eth_GEMAC_GMII is
	generic (
		DEBUG														: boolean									:= TRUE;
		CLOCK_FREQ_MHZ									: REAL										:= 125.0;					-- 125 MHz

		TX_FIFO_DEPTH										: positive								:= 2048;					-- 2 KiB TX Buffer
		TX_INSERT_CROSSCLOCK_FIFO				: boolean									:= TRUE;					-- true = crossclock fifo; false = fifo_glue
		TX_SUPPORT_JUMBO_FRAMES					: boolean									:= FALSE;					-- TODO:
		TX_DISABLE_UNDERRUN_PROTECTION	: boolean									:= FALSE;					-- TODO: 							true: no protection; false: store complete frame in buffer befor transmitting it

		RX_FIFO_DEPTH										: positive								:= 4096;					-- 4 KiB TX Buffer
		RX_INSERT_CROSSCLOCK_FIFO				: boolean									:= TRUE;					-- true = crossclock fifo; false = fifo_glue
		RX_SUPPORT_JUMBO_FRAMES					: boolean									:= FALSE					-- TODO:
	);
	port (
		-- clock interface
		TX_Clock									: in	std_logic;
		RX_Clock									: in	std_logic;
		Eth_TX_Clock							: in	std_logic;
		Eth_RX_Clock							: in	std_logic;
		RS_TX_Clock								: in	std_logic;
		RS_RX_Clock								: in	std_logic;

		-- reset interface
		TX_Reset									: in	std_logic;
		RX_Reset									: in	std_logic;
		RS_TX_Reset								: in	std_logic;
		RS_RX_Reset								: in	std_logic;

		-- Command-Status-Error interface
		TX_BufferUnderrun					: out	std_logic;
		RX_FrameDrop							: out	std_logic;
		RX_FrameCorrupt						: out	std_logic;

		-- MAC LocalLink interface
		TX_Valid									: in	std_logic;
		TX_Data										: in	T_SLV_8;
		TX_SOF										: in	std_logic;
		TX_EOF										: in	std_logic;
		TX_Ack										: out	std_logic;

		RX_Valid									: out	std_logic;
		RX_Data										: out	T_SLV_8;
		RX_SOF										: out	std_logic;
		RX_EOF										: out	std_logic;
		RX_Ack										: in	std_logic;

		-- MAC-GMII interface
		RS_TX_Valid								: out	std_logic;
		RS_TX_Data								: out	T_SLV_8;
		RS_TX_Error								: out	std_logic;

		RS_RX_Valid								: in	std_logic;
		RS_RX_Data								: in	T_SLV_8;
		RS_RX_Error								: in	std_logic--;

		-- Management Data Input/Output
--		MDIO											: inout T_ETHERNET_PHY_INTERFACE_MDIO
	);
end entity;


architecture rtl of eth_GEMAC_GMII is
	attribute KEEP							: boolean;

	constant SOF_BIT						: natural			:= 8;
	constant EOF_BIT						: natural			:= 9;


	signal TX_FIFO_Valid				: std_logic;
	signal TX_FIFO_Data					: T_SLV_8;
	signal TX_FIFO_SOF					: std_logic;
	signal TX_FIFO_EOF					: std_logic;
	signal TX_FIFO_Commit				: std_logic;

	signal TX_MAC_Ack						: std_logic;


	signal RX_MAC_Valid					: std_logic;
	signal RX_MAC_Data					: T_SLV_8;
	signal RX_MAC_SOF						: std_logic;
	signal RX_MAC_EOF						: std_logic;
	signal RX_MAC_GoodFrame			: std_logic;

	signal RX_FIFO_put					: std_logic;
	signal RX_FIFO_Full					: std_logic;

	signal RX_FIFO_Commit				: std_logic;
	signal RX_FIFO_Rollback			: std_logic;

begin
	-- ==========================================================================================================================================================
	-- assert statements
	-- ==========================================================================================================================================================
	assert TX_FIFO_DEPTH > ite(TX_DISABLE_UNDERRUN_PROTECTION, 0, ite(TX_SUPPORT_JUMBO_FRAMES, 10*1000, 1600))	report "TX-FIFO is to small" severity ERROR;
	assert RX_FIFO_DEPTH > ite(TX_SUPPORT_JUMBO_FRAMES, 10*1000, 1600)																					report "RX-FIFO is to small" severity ERROR;

	-- ==========================================================================================================================================================
	-- TX path
	-- ==========================================================================================================================================================
	blkTXFIFO : block
		signal XClk_TX_FIFO_DataIn				: std_logic_vector(9 downto 0);
		signal XClk_TX_FIFO_Full					: std_logic;

		signal XClk_TX_FIFO_Valid					: std_logic;
		signal XClk_TX_FIFO_DataOut				: std_logic_vector(XClk_TX_FIFO_DataIn'range);

		signal XClk_TX_FIFO_got						: std_logic;
		signal TX_FIFO_DataOut						: std_logic_vector(XClk_TX_FIFO_DataIn'range);
		signal TX_FIFO_Full								: std_logic;

	begin
		XClk_TX_FIFO_DataIn(TX_Data'range)		<= TX_Data;
		XClk_TX_FIFO_DataIn(SOF_BIT)					<= TX_SOF;
		XClk_TX_FIFO_DataIn(EOF_BIT)					<= TX_EOF;

		genTX_XClk_0 : if (TX_INSERT_CROSSCLOCK_FIFO = TRUE) generate
			XClk_TX_FIFO : entity PoC.fifo_ic_got
				generic map (
					D_BITS							=> XClk_TX_FIFO_DataIn'length,
					MIN_DEPTH						=> 16,
					DATA_REG						=> TRUE,
					OUTPUT_REG					=> FALSE,
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0
				)
				port map (
					-- Write Interface
					clk_wr							=> TX_Clock,
					rst_wr							=> TX_Reset,
					put									=> TX_Valid,
					din									=> XClk_TX_FIFO_DataIn,
					full								=> XClk_TX_FIFO_Full,
					estate_wr						=> open,

					-- Read Interface
					clk_rd							=> RS_TX_Clock,
					rst_rd							=> RS_TX_Reset,
					got									=> XClk_TX_FIFO_got,
					valid								=> XClk_TX_FIFO_Valid,
					dout								=> XClk_TX_FIFO_DataOut,
					fstate_rd						=> open
				);

			TX_Ack		<= not XClk_TX_FIFO_Full;
		end generate;
		genTX_XClk_1 : if (TX_INSERT_CROSSCLOCK_FIFO = FALSE) generate
			Glue_TX_FIFO : entity PoC.fifo_glue
				generic map (
					D_BITS							=> XClk_TX_FIFO_DataIn'length
				)
				port map (
					-- Control
					clk									=> TX_Clock,
					rst									=> TX_Reset,
					-- Input
					put									=> TX_Valid,
					di									=> XClk_TX_FIFO_DataIn,
					ful									=> XClk_TX_FIFO_Full,
					-- Output
					got									=> XClk_TX_FIFO_got,
					vld									=> XClk_TX_FIFO_Valid,
					do									=> XClk_TX_FIFO_DataOut
				);
		end generate;


		-- TX-Buffer Underrun Protection (configured by: TX_DISABLE_UNDERRUN_PROTECTION)
		-- ========================================================================================================================================================
		--	transactional behavior:
		--	-	enabled:	each frame is commited when EOF is set (*_FIFO_Out(EOF_BIT))
		--	-	disabled:	each word is immediatly commited, so incomplete frames can be consumed by the TX-MAC-statemachine
		--
		--	impect an FIFO_DEPTH:
		--	-	enabled:	FIFO_DEPTH must be greater than max. frame size (normal frames: ca. 1550 bytes; JumboFrames: ca. 9100 bytes)
		--	-	disabled:	TX-FIFO becomes optional; set FIFO_DEPTH to 0 to disable TX-FIFO
		-- ========================================================================================================================================================
		TX_FIFO_Commit		<= ite(TX_DISABLE_UNDERRUN_PROTECTION, '1', XClk_TX_FIFO_DataOut(EOF_BIT));

		TX_FIFO : entity PoC.fifo_cc_got_tempput
			generic map (
				D_BITS							=> XClk_TX_FIFO_DataOut'length,
				MIN_DEPTH						=> TX_FIFO_DEPTH,
				ESTATE_WR_BITS			=> 0,
				FSTATE_RD_BITS			=> 0,
				DATA_REG						=> FALSE,
				STATE_REG						=> TRUE,
				OUTPUT_REG					=> FALSE
			)
			port map (
				clk									=> RS_TX_Clock,
				rst									=> RS_TX_Reset,

				-- Write Interface
				put									=> XClk_TX_FIFO_Valid,
				din									=> XClk_TX_FIFO_DataOut,
				full								=> TX_FIFO_Full,
				estate_wr						=> open,

				-- Temporary put control
				commit							=> TX_FIFO_Commit,
				rollback						=> '0',

				-- Read Interface
				got									=> TX_MAC_Ack,
				valid								=> TX_FIFO_Valid,
				dout								=> TX_FIFO_DataOut,
				fstate_rd						=> open
			);

		XClk_TX_FIFO_got		<= not TX_FIFO_Full;

		TX_FIFO_Data		<= TX_FIFO_DataOut(TX_FIFO_Data'range);
		TX_FIFO_SOF			<= TX_FIFO_DataOut(SOF_BIT);
		TX_FIFO_EOF			<= TX_FIFO_DataOut(EOF_BIT);
	end block;

	TX_MAC : entity PoC.Eth_GEMAC_TX
		port map (
			RS_TX_Clock								=> RS_TX_Clock,
			RS_TX_Reset								=> RS_TX_Reset,

			-- status interface
			BufferUnderrun						=> TX_BufferUnderrun,

			-- LocalLink interface
			TX_Valid									=> TX_FIFO_Valid,
			TX_Data										=> TX_FIFO_Data,
			TX_SOF										=> TX_FIFO_SOF,
			TX_EOF										=> TX_FIFO_EOF,
			TX_Ack										=> TX_MAC_Ack,

			-- Reconcilation Sublayer interface
			RS_TX_Valid								=> RS_TX_Valid,
			RS_TX_Data								=> RS_TX_Data,
			RS_TX_Error								=> RS_TX_Error
		);

	-- ==========================================================================================================================================================
	-- RX path
	-- ==========================================================================================================================================================
	RX_MAC : entity PoC.Eth_GEMAC_RX
		port map (
			RS_RX_Clock								=> RS_RX_Clock,
			RS_RX_Reset								=> RS_RX_Reset,

			-- status interface
			RX_GoodFrame							=> RX_MAC_GoodFrame,				-- valid contemporaneously with (RX_Valid AND RX_EOF)

			-- MAC interface
			RX_Valid									=> RX_MAC_Valid,
			RX_Data										=> RX_MAC_Data,
			RX_SOF										=> RX_MAC_SOF,
			RX_EOF										=> RX_MAC_EOF,

			-- Reconcilation Sublayer interface
			RS_RX_Valid								=> RS_RX_Valid,
			RS_RX_Data								=> RS_RX_Data,
			RS_RX_Error								=> RS_RX_Error
		);

	blkRXFSM : block
		type T_STATE is (ST_IDLE, ST_DATA);

		signal State					: T_STATE					:= ST_IDLE;
		signal NextState			: T_STATE;

		signal RX_Is_SOF			: std_logic;
		signal RX_Is_EOF			: std_logic;

	begin
		RX_Is_SOF							<= RX_MAC_Valid and RX_MAC_SOF;
		RX_Is_EOF							<= RX_MAC_Valid and RX_MAC_EOF;

		process(RS_RX_Clock)
		begin
			if rising_edge(RS_RX_Clock) then
				if (RS_RX_Reset = '1') then
					State						<= ST_IDLE;
				else
					State						<= NextState;
				end if;
			end if;
		end process;

		process(State, RX_MAC_Valid, RX_Is_SOF, RX_Is_EOF, RX_MAC_GoodFrame, RX_FIFO_Full)
		begin
			NextState								<= State;

			RX_FIFO_put							<= '0';
			RX_FIFO_Commit					<= '0';
			RX_FIFO_Rollback				<= '0';

			RX_FrameDrop						<= '0';
			RX_FrameCorrupt					<= '0';

			case State is
				when ST_IDLE =>
					if (RX_FIFO_Full = '1') then
						if (RX_Is_SOF = '1') then
							RX_FrameDrop				<= '1';
						end if;
					else
						if (RX_Is_SOF = '1') then
							RX_FIFO_put					<= '1';

							NextState						<= ST_DATA;
						end if;
					end if;

				when ST_DATA =>
					RX_FIFO_put							<= RX_MAC_Valid;

					if (RX_FIFO_Full = '1') then
						RX_FIFO_put						<= '0';
						RX_FIFO_Rollback			<= '1';
						RX_FrameDrop					<= '1';

						NextState							<= ST_IDLE;
					else
						if (RX_Is_EOF = '1') then
							if (RX_MAC_GoodFrame = '1') then
								RX_FIFO_Commit		<= '1';
							else
								RX_FIFO_Rollback	<= '1';
								RX_FrameCorrupt		<= '1';
							end if;

							NextState						<= ST_IDLE;
						end if;
					end if;

			end case;
		end process;
	end block;

	blkRXFIFO : block
		signal RX_FIFO_DataIn				: std_logic_vector(9 downto 0);
--		signal RX_FIFO_Full					: STD_LOGIC;

		signal RX_FIFO_got					: std_logic;
		signal RX_FIFO_Valid				: std_logic;
		signal RX_FIFO_DataOut			: std_logic_vector(RX_FIFO_DataIn'range);

		signal XClk_RX_FIFO_Full		: std_logic;
		signal XClk_RX_FIFO_DataOut	: std_logic_vector(RX_FIFO_DataIn'range);

	begin
		RX_FIFO_DataIn(RX_MAC_Data'range)		<= RX_MAC_Data;
		RX_FIFO_DataIn(SOF_BIT)							<= RX_MAC_SOF;
		RX_FIFO_DataIn(EOF_BIT)							<= RX_MAC_EOF;

		RX_FIFO : entity PoC.fifo_cc_got_tempput
			generic map (
				D_BITS							=> RX_FIFO_DataIn'length,
				MIN_DEPTH						=> RX_FIFO_DEPTH,
				ESTATE_WR_BITS			=> 0,
				FSTATE_RD_BITS			=> 0,
				DATA_REG						=> FALSE,
				STATE_REG						=> TRUE,
				OUTPUT_REG					=> FALSE
			)
			port map (
				clk									=> RS_RX_Clock,
				rst									=> RS_RX_Reset,

				-- Write Interface
				put									=> RX_FIFO_put,
				din									=> RX_FIFO_DataIn,
				full								=> RX_FIFO_Full,
				estate_wr						=> open,

				-- Temporary put control
				commit							=> RX_FIFO_Commit,
				rollback						=> RX_FIFO_Rollback,

				-- Read Interface
				got									=> RX_FIFO_got,
				valid								=> RX_FIFO_Valid,
				dout								=> RX_FIFO_DataOut,
				fstate_rd						=> open
			);

		RX_FIFO_got			<= not XClk_RX_FIFO_Full;


		genRX_XClk_0 : if (RX_INSERT_CROSSCLOCK_FIFO = FALSE) generate
			Glue_RX_FIFO : entity PoC.fifo_glue
					generic map (
						D_BITS							=> RX_FIFO_DataOut'length
					)
					port map (
						-- Control
						clk									=> RX_Clock,
						rst									=> RX_Reset,
						-- Input
						put									=> RX_FIFO_Valid,
						di									=> RX_FIFO_DataOut,
						ful									=> XClk_RX_FIFO_Full,
						-- Output
						got									=> RX_Ack,
						vld									=> RX_Valid,
						do									=> XClk_RX_FIFO_DataOut
					);
		end generate;
		genRX_XClk_1 : if (RX_INSERT_CROSSCLOCK_FIFO = TRUE) generate
			XClk_RX_FIFO : entity PoC.fifo_ic_got
				generic map (
					D_BITS							=> RX_FIFO_DataOut'length,
					MIN_DEPTH						=> 16,
					DATA_REG						=> TRUE,
					OUTPUT_REG					=> FALSE,
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0
				)
				port map (
					-- Write Interface
					clk_wr							=> RS_RX_Clock,
					rst_wr							=> RS_RX_Reset,
					put									=> RX_FIFO_Valid,
					din									=> RX_FIFO_DataOut,
					full								=> XClk_RX_FIFO_Full,
					estate_wr						=> open,

					-- Read Interface
					clk_rd							=> RX_Clock,
					rst_rd							=> RX_Reset,
					got									=> RX_Ack,
					valid								=> RX_Valid,
					dout								=> XClk_RX_FIFO_DataOut,
					fstate_rd						=> open
				);

			RX_Data			<= XClk_RX_FIFO_DataOut(RX_Data'range);
			RX_SOF			<= XClk_RX_FIFO_DataOut(SOF_BIT);
			RX_EOF			<= XClk_RX_FIFO_DataOut(EOF_BIT);
		end generate;
	end block;
end architecture;
