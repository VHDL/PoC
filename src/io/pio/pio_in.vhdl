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

library PoC;
use			PoC.utils.all;
use			PoC.io.all;
use			PoC.ddrio.all;


entity pio_in is
	generic (
		DATARATE		: T_IO_DATARATE	:= IO_DATARATE_SDR;
		DATA_BITS		: natural				:= 8;
		REV_BITS		: natural				:= 0
	);
	port (
		Clock				: out	std_logic;
		DataOut			: out	std_logic_vector(ite((DATARATE = IO_DATARATE_DDR), 2*DATA_BITS, DATA_BITS) - 1 downto 0);
		DataIn			: in	std_logic_vector(ite((DATARATE = IO_DATARATE_DDR), 2*REV_BITS, REV_BITS) - 1 downto 0);

		Pad_Clock		: in	std_logic;
		Pad_DataIn	: in	std_logic_vector(DATA_BITS - 1 downto 0);
		Pad_DataOut	: out	std_logic_vector(REV_BITS - 1 downto 0)
	);
end entity;


architecture rtl of pio_in is
	signal Clock_i		: std_logic;
begin
	-- clock recovery
	Clock_i		<= Pad_Clock;
	Clock			<= Clock_i;

	genSDR : if (DATARATE = IO_DATARATE_SDR) generate
		signal DataIn_iob			: std_logic_vector(DATA_BITS - 1 downto 0)		:= (others => '0');
		signal DataOut_iob		: std_logic_vector(REV_BITS - 1 downto 0)	:= (others => '0');
	begin

		DataIn_iob		<= Pad_DataIn	when rising_edge(Clock_i);
		DataOut				<= DataIn_iob;
		DataOut_iob		<= DataIn			when rising_edge(Clock_i);
		Pad_DataOut		<= DataOut_iob;
	end generate;
	genDDR : if (DATARATE = IO_DATARATE_DDR) generate
		signal Clock_i		: std_logic;
	begin
		DataInFF : entity PoC.ddrio_in
			generic map (
				BITS							=> DATA_BITS,
				INIT_VALUE				=> (DATA_BITS -1 downto 0 => '0')
			)
			port map (
				Clock							=> Clock_i,
				ClockEnable				=> '1',
				DataIn_high				=> DataOut(2*DATA_BITS - 1 downto DATA_BITS),
				DataIn_low				=> DataOut(DATA_BITS - 1 downto 0),
				Pad								=> Pad_DataIn
			);
		DataOutFF : entity PoC.ddrio_out
			generic map (
				NO_OUTPUT_ENABLE	=> TRUE,
				BITS							=> REV_BITS,
				INIT_VALUE				=> (REV_BITS -1 downto 0 => '0')
			)
			port map (
				Clock							=> Clock_i,
				ClockEnable				=> '1',
				OutputEnable			=> '1',
				DataOut_high			=> DataIn(2*REV_BITS - 1 downto REV_BITS),
				DataOut_low				=> DataIn(REV_BITS - 1 downto 0),
				Pad								=> Pad_DataOut
			);
	end generate;
end architecture;
