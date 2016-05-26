-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:					Patrick Lehmann
--
-- Module:					Parallel Input/Output
--
-- Description:
-- ------------------------------------
--
-- License:
-- ============================================================================
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
-- ============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library	PoC;
use			PoC.io.all;


entity pio_fifo_in is
	generic (
		DATARATE		: T_IO_DATARATE	:= IO_DATARATE_SDR;
		BITS				: POSITIVE			:= 8
	);
	port (
		Clock				: in	STD_LOGIC;
		Reset				: in	STD_LOGIC;

		got					: in	STD_LOGIC;
		DataOut			: out	STD_LOGIC_VECTOR(BITS - 1 downto 0);
		Valid				: out	STD_LOGIC;

		Pad_Clock		: in	STD_LOGIC;
		Pad_DataIn	: in	STD_LOGIC_VECTOR(BITS downto 0);
		Pad_DataOut	: out	STD_LOGIC_VECTOR(0 downto 0)
	);
end entity;


architecture rtl of pio_fifo_in is
	signal Clock_i				: STD_LOGIC;
	signal Reset_i				: STD_LOGIC;

	signal PIO_DataOut		: STD_LOGIC_VECTOR(BITS downto 0);
	signal FIFO_Full			: STD_LOGIC;
	signal FIFO_Ack				: STD_LOGIC;
begin
	Reset_i		<= '0';

	FIFO : entity PoC.fifo_ic_got
		generic map (
			D_BITS			=> BITS,
			MIN_DEPTH		=> 16,
			DATA_REG		=> TRUE,
			OUTPUT_REG	=> FALSE
		)
		port map (
			-- Write port
			clk_wr			=> Clock_i,
			rst_wr			=> Reset_i,
			put					=> PIO_DataOut(BITS),
			din					=> PIO_DataOut(BITS - 1 downto 0),
			full				=> FIFO_Full,
			-- Read port
			clk_rd			=> Clock,
			rst_rd			=> Reset,
			got					=> got,
			dout				=> DataOut,
			valid				=> Valid
		);

	FIFO_Ack	<= not FIFO_Full;

	PIOIn : entity PoC.pio_in
		generic map (
			DATARATE		=> DATARATE,
			DATA_BITS		=> BITS + 1,
			REV_BITS		=> 1
		)
		port map (
			Clock				=> Clock_i,
			DataOut			=> PIO_DataOut,
			DataIn(0)		=> FIFO_Ack,

			Pad_Clock		=> Pad_Clock,
			Pad_DataIn	=> Pad_DataIn,
			Pad_DataOut	=> Pad_DataOut
		);

end architecture;
