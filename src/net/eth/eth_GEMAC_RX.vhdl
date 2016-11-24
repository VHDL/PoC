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
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.net.all;


entity Eth_GEMAC_RX is
	generic (
		DEBUG						: boolean						:= FALSE
	);
	port (
		RS_RX_Clock								: in	std_logic;
		RS_RX_Reset								: in	std_logic;

		-- MAC interface
		RX_Valid									: out	std_logic;
		RX_Data										: out	T_SLV_8;
		RX_SOF										: out	std_logic;
		RX_EOF										: out	std_logic;
		RX_GoodFrame							: out	std_logic;

		-- Reconcilation Sublayer interface
		RS_RX_Valid								: in	std_logic;
		RS_RX_Data								: in	T_SLV_8;
		RS_RX_Error								: in	std_logic
	);
end entity;

architecture rtl of Eth_GEMAC_RX is
	attribute KEEP										: boolean;
	attribute FSM_ENCODING						: string;

	type T_STATE is (
		ST_IDLE,
		ST_RECEIVE_PREAMBLE,
		ST_RECEIVED_START_OF_FRAME_DELIMITER,
		ST_RECEIVE_DATA,
		ST_DISCARD_FRAME
	);

	signal State											: T_STATE									:= ST_IDLE;
	signal NextState									: T_STATE;
	attribute FSM_ENCODING of State		: signal is ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	constant PREAMBLE_COUNTER_BW			: positive																			:= log2ceilnz(C_NET_ETH_PREMABLE_LENGTH);
	signal PreambleCounter_rst				: std_logic;
	signal PreambleCounter_en					: std_logic;
	signal PreambleCounter_eq					: std_logic;
	signal PreambleCounter_us					: unsigned(PREAMBLE_COUNTER_BW - 1 downto 0)		:= (others => '0');

	signal Register_en								: std_logic;
	signal DataRegister_d							: T_SLVV_8(4 downto 0)													:= (others => (others => '0'));
	signal SOFRegister_en							: std_logic;
	signal SOFRegister_d							: std_logic_vector(4 downto 0)									:= (others => '0');
	signal Valid_rst									: std_logic;
	signal Valid_set									: std_logic;
	signal Valid_r										: std_logic;

	signal CRC_rst										: std_logic;
	signal CRC_en											: std_logic;
	signal CRC_OK											: std_logic;

	signal FSM_SOF										: std_logic;
	signal FSM_EOF										: std_logic;

begin
	process(RS_RX_Clock)
	begin
		if rising_edge(RS_RX_Clock) then
			if (RS_RX_Reset = '1') then
				State			<= ST_IDLE;
			else
				State			<= NextState;
			end if;
		end if;
	end process;

	process(State, RS_RX_Data, RS_RX_Valid, RS_RX_Error, PreambleCounter_eq)
	begin
		NextState										<= State;

		FSM_SOF											<= '0';
		FSM_EOF											<= '0';

		Register_en									<= '0';

		PreambleCounter_rst					<= '0';
		PreambleCounter_en					<= '0';

		CRC_rst											<= '0';
		CRC_en											<= '0';

		case State is
			when ST_IDLE =>
				PreambleCounter_rst			<= '1';
				CRC_rst									<= '1';

				if (RS_RX_Valid = '1') then
					if (RS_RX_Data = x"55") then
						NextState						<= ST_RECEIVE_PREAMBLE;
					else
						NextState						<= ST_DISCARD_FRAME;
					end if;
				end if;

			when ST_RECEIVE_PREAMBLE =>
				if (RS_RX_Valid = '1') then
					if (RS_RX_Data = x"55") then
						PreambleCounter_en	<= '1';
					elsif (RS_RX_Data = x"D5") then
						NextState						<= ST_RECEIVED_START_OF_FRAME_DELIMITER;
					else
						NextState						<= ST_DISCARD_FRAME;
					end if;
				else
					NextState							<= ST_IDLE;
				end if;

				if (PreambleCounter_eq = '1') then
					if (RS_RX_Valid = '1') then
						NextState							<= ST_DISCARD_FRAME;
					else
						NextState							<= ST_IDLE;
					end if;
				end if;

			when ST_RECEIVED_START_OF_FRAME_DELIMITER =>
				Register_en								<= '1';
				CRC_en										<= '1';

				FSM_SOF										<= '1';

				if (RS_RX_Valid = '1') then
					NextState								<= ST_RECEIVE_DATA;
				else
					NextState								<= ST_IDLE;
				end if;

			when ST_RECEIVE_DATA =>
				Register_en								<= '1';
				CRC_en										<= '1';

				if (RS_RX_Valid = '0') then
					Register_en							<= '0';
					CRC_en									<= '0';

					FSM_EOF									<= '1';

					NextState								<= ST_IDLE;
				end if;

			when ST_DISCARD_FRAME =>
				if (RS_RX_Valid = '0') then
					NextState								<= ST_IDLE;
				end if;

		end case;
	end process;

	process(RS_RX_Clock)
	begin
		if rising_edge(RS_RX_Clock) then
			if (PreambleCounter_rst = '1') then
				PreambleCounter_us			<= (others => '0');
			else
				if (PreambleCounter_en = '1') then
					PreambleCounter_us		<= PreambleCounter_us + 1;
				end if;
			end if;
		end if;
	end process;

	PreambleCounter_eq		<= to_sl(PreambleCounter_us = C_NET_ETH_PREMABLE_LENGTH);

	process(RS_RX_Clock)
	begin
		if rising_edge(RS_RX_Clock) then
			if (Register_en = '1') then
				SOFRegister_d				<= SOFRegister_d(SOFRegister_d'high - 1 downto 0)		& FSM_SOF;
				DataRegister_d			<= DataRegister_d(DataRegister_d'high - 1 downto 0) & RS_RX_Data;
			end if;
		end if;
	end process;

	Valid_rst				<= FSM_EOF;
	Valid_set				<= SOFRegister_d(SOFRegister_d'high - 1);

	process(RS_RX_Clock)
	begin
		if rising_edge(RS_RX_Clock) then
			if ((RS_RX_Reset or Valid_rst) = '1') then
				Valid_r				<= '0';
			elsif (Valid_set = '1') then
				Valid_r				<= '1';
			end if;
		end if;
	end process;

	blkCRC : block
		constant CRC32_POLYNOMIAL					: bit_vector(35 downto 0) := x"104C11DB7";
		constant CRC32_INIT								: T_SLV_32								:=  x"FFFFFFFF";

		signal CRC_DataIn									: T_SLV_8;
		signal CRC_DataOut								: T_SLV_32;
		signal CRC_Value									: T_SLV_32;

		signal CRC_Byte0_d								: T_SLVV_8(0 downto 0);
		signal CRC_Byte1_d								: T_SLVV_8(1 downto 0);
		signal CRC_Byte2_d								: T_SLVV_8(2 downto 0);
		signal CRC_Byte3_d								: T_SLVV_8(3 downto 0);

		signal CRC_ByteMatched_d					: std_logic_vector(3 downto 0);

		attribute KEEP of CRC_Value						: signal is TRUE;

-- for debugging
--		attribute KEEP OF CRC_Byte0_d					: signal IS TRUE;
--		attribute KEEP OF CRC_Byte1_d					: signal IS TRUE;
--		attribute KEEP OF CRC_Byte2_d					: signal IS TRUE;
--		attribute KEEP OF CRC_Byte3_d					: signal IS TRUE;

--		attribute KEEP OF CRC_ByteMatched_d		: signal IS TRUE;

	begin

		CRC_DataIn		<= reverse(RS_RX_Data);

		CRC : entity PoC.comm_crc
			generic map (
				GEN							=> CRC32_POLYNOMIAL(32 downto 0),		-- Generator Polynom
				BITS						=> CRC_DataIn'length								-- Number of Bits to be processed in parallel
			)
			port map (
				clk							=> RS_RX_Clock,											-- Clock

				set							=> CRC_rst,													-- Parallel Preload of Remainder
				init						=> CRC32_INIT,
				step						=> CRC_en,													-- Process Input Data (MSB first)
				din							=> CRC_DataIn,

				rmd							=> CRC_DataOut,											-- Remainder
				zero						=> open															-- Remainder is Zero
			);

		-- manipulate CRC value
		CRC_Value			<= not reverse(CRC_DataOut);

		CRC_Byte0_d(0)	<= CRC_Value(7	downto	0);
		CRC_Byte1_d(0)	<= CRC_Value(15 downto	8);
		CRC_Byte2_d(0)	<= CRC_Value(23 downto 16);
		CRC_Byte3_d(0)	<= CRC_Value(31 downto 24);

		-- delay some CRC bytes
		process(RS_RX_Clock)
		begin
			if rising_edge(RS_RX_Clock) then
				CRC_Byte1_d(CRC_Byte1_d'high downto 1)	<= CRC_Byte1_d(CRC_Byte1_d'high - 1 downto 0);
				CRC_Byte2_d(CRC_Byte2_d'high downto 1)	<= CRC_Byte2_d(CRC_Byte2_d'high - 1 downto 0);
				CRC_Byte3_d(CRC_Byte3_d'high downto 1)	<= CRC_Byte3_d(CRC_Byte3_d'high - 1 downto 0);
			end if;
		end process;

		-- calculate byte matches and delay it
		CRC_ByteMatched_d(0)		<=  to_sl(CRC_Byte0_d(CRC_Byte0_d'high) = RS_RX_Data)															when rising_edge(RS_RX_Clock);
		CRC_ByteMatched_d(1)		<= (to_sl(CRC_Byte1_d(CRC_Byte1_d'high) = RS_RX_Data) and CRC_ByteMatched_d(0))		when rising_edge(RS_RX_Clock);
		CRC_ByteMatched_d(2)		<= (to_sl(CRC_Byte2_d(CRC_Byte2_d'high) = RS_RX_Data) and CRC_ByteMatched_d(1))		when rising_edge(RS_RX_Clock);
		CRC_ByteMatched_d(3)		<= (to_sl(CRC_Byte3_d(CRC_Byte3_d'high) = RS_RX_Data) and CRC_ByteMatched_d(2))		when rising_edge(RS_RX_Clock);

		-- now a possible CRC_OK was delayed 4 times, so it should occur along with EOF
		CRC_OK <= CRC_ByteMatched_d(3);
	end block;

	RX_Valid			<= Valid_r;
	RX_Data				<= DataRegister_d(DataRegister_d'high);
	RX_SOF				<= SOFRegister_d(SOFRegister_d'high);
	RX_EOF				<= FSM_EOF;
	RX_GoodFrame	<= FSM_EOF and CRC_OK;
end;
