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
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
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

-- list_expire_fixed
--		expire	= list of expireable items
--		fixed		= insert_time := current_time + fixed interval

entity list_expire is
	generic (
		CLOCK_CYCLE_TICKS					: positive												:= 1024;
		EXPIRATION_TIME_TICKS			: natural													:= 10;
		ELEMENTS									: positive												:= 32;
		KEY_BITS									: positive												:= 4
	);
	port (
		Clock											: in	std_logic;
		Reset											: in	std_logic;

		Tick											: in	std_logic;

		Insert										: in	std_logic;
		KeyIn											: in	std_logic_vector(KEY_BITS - 1 downto 0);

		Expired										: out	std_logic;
		KeyOut										: out	std_logic_vector(KEY_BITS - 1 downto 0)
	);
end entity;


architecture rtl of list_expire is
	constant CLOCK_BITS								: positive																								:= log2ceilnz(CLOCK_CYCLE_TICKS);

	signal CurrentTime_us							: unsigned(CLOCK_BITS - 1 downto 0)												:= (others => '0');
	signal KeyTime_us									: unsigned(CLOCK_BITS + KEY_BITS - 1 downto KEY_BITS);

	signal FIFO_put										: std_logic;
	signal FIFO_DataIn								: std_logic_vector(CLOCK_BITS + KEY_BITS - 1 downto 0);
	signal FIFO_Full									: std_logic;
	signal FIFO_got										: std_logic;
	signal FIFO_DataOut								: std_logic_vector(CLOCK_BITS + KEY_BITS - 1 downto 0);
	signal FIFO_Valid									: std_logic;

	signal Expired_i									: std_logic;

begin
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				CurrentTime_us	<= (others => '0');
			elsif (Tick = '1') then
				CurrentTime_us	<= CurrentTime_us + 1;
			end if;
		end if;
	end process;

	KeyTime_us											<= CurrentTime_us + EXPIRATION_TIME_TICKS;

	FIFO_put												<= Insert;
	FIFO_DataIn(KeyIn'range)				<= KeyIn;
	FIFO_DataIn(KeyTime_us'range)		<= std_logic_vector(KeyTime_us);

	FIFO : entity PoC.fifo_cc_got
		generic map (
			D_BITS							=> CLOCK_BITS + KEY_BITS,		-- Data Width
			MIN_DEPTH						=> ELEMENTS,								-- Minimum FIFO Depth
			DATA_REG						=> TRUE,										-- Store Data Content in Registers
			STATE_REG						=> TRUE,										-- Registered Full/Empty Indicators
			OUTPUT_REG					=> FALSE,										-- Registered FIFO Output
			ESTATE_WR_BITS			=> 0,												-- Empty State Bits
			FSTATE_RD_BITS			=> 0												-- Full State Bits
		)
		port map (
			-- Global Reset and Clock
			clk									=> Clock,
			rst									=> Reset,
			-- Writing Interface
			put									=> FIFO_put,
			din									=> FIFO_DataIn,
			full								=> open,--FIFO_Full,
			-- Reading Interface
			got									=> FIFO_got,
			dout								=> FIFO_DataOut,
			valid								=> FIFO_Valid
		);

	FIFO_got			<= Expired_i;

	Expired_i			<= to_sl(FIFO_DataOut(KeyTime_us'range) = std_logic_vector(CurrentTime_us)) and FIFO_Valid;

	Expired				<= Expired_i;
	KeyOut				<= FIFO_DataOut(KeyIn'range);
end architecture;
