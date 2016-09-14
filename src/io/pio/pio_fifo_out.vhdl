-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					Parallel Input/Output
--
-- Description:
-- -------------------------------------
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
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

library	PoC;
use			PoC.io.all;


entity pio_fifo_out is
	generic (
		DATARATE		: T_IO_DATARATE	:= IO_DATARATE_SDR;
		BITS				: positive			:= 8
	);
	port (
		Clock				: in	std_logic;
		Reset				: in	std_logic;

		put					: in	std_logic;
		DataIn			: in	std_logic_vector(BITS - 1 downto 0);
		Full				: out	std_logic;

		Pad_Clock		: out	std_logic;
		Pad_DataOut	: out	std_logic_vector(BITS downto 0);
		Pad_DataIn	: in	std_logic_vector(0 downto 0)
	);
end entity;


architecture rtl of pio_fifo_out is
	signal FIFO_Valid			: std_logic;
	signal FIFO_DataOut		: std_logic_vector(BITS - 1 downto 0);
	signal FIFO_Data			: std_logic_vector(BITS downto 0);
	signal PIO_Ack				: std_logic;
begin
	FIFO : entity PoC.fifo_cc_got
		generic map (
			D_BITS			=> BITS,
			MIN_DEPTH		=> 16,
			DATA_REG		=> TRUE,
			STATE_REG		=> FALSE,
			OUTPUT_REG	=> FALSE
		)
		port map (
			clk					=> Clock,
			rst					=> Reset,
			-- Write port
			put					=> put,
			din					=> DataIn,
			full				=> Full,
			-- Read port
			got					=> PIO_Ack,
			dout				=> FIFO_DataOut,
			valid				=> FIFO_Valid
		);

	FIFO_Data(BITS - 1 downto 0)	<= FIFO_DataOut;
	FIFO_Data(BITS)								<= FIFO_Valid;

	PIOOut : entity PoC.pio_out
		generic map (
			DATARATE		=> DATARATE,
			DATA_BITS		=> BITS + 1,
			REV_BITS		=> 1
		)
		port map (
			Clock				=> Clock,
			DataIn			=> FIFO_Data,
			DataOut(0)	=> PIO_Ack,

			Pad_Clock		=> Pad_Clock,
			Pad_DataOut	=> Pad_DataOut,
			Pad_DataIn	=> Pad_DataIn
		);
end architecture;
