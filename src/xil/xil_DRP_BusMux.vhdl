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
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.components.all;
use			PoC.xil.all;


entity xil_DRP_BusMux is
	generic (
		DEBUG						: boolean										:= FALSE;										--
		PORTS						: positive									:= 2												--
	);
	port (
		Clock						: in	std_logic;
		Reset						: in	std_logic;

		In_Enable				: in	std_logic_vector(PORTS - 1 downto 0);							--
		In_Address			: in	T_XIL_DRP_ADDRESS_VECTOR(PORTS - 1 downto 0);			--
		In_ReadWrite		: in	std_logic_vector(PORTS - 1 downto 0);							--
		In_DataIn				: in	T_XIL_DRP_DATA_VECTOR(PORTS - 1 downto 0);				--
		In_DataOut			: out	T_XIL_DRP_DATA_VECTOR(PORTS - 1 downto 0);				--
		In_Ack					: out	std_logic_vector(PORTS - 1 downto 0);							--

		Out_Enable			: out	std_logic;																				--
		Out_Address			: out	T_XIL_DRP_ADDRESS;																--
		Out_ReadWrite		: out	std_logic;																				--
		Out_DataIn			: in	T_XIL_DRP_DATA;																		--
		Out_DataOut			: out	T_XIL_DRP_DATA;																		--
		Out_Ack					: in	std_logic																					--
	);
end entity;


architecture rtl of xil_DRP_BusMux is
	type T_STATE is (
		ST_IDLE,
		ST_BUS_TRANSACTION_START, ST_BUS_TRANSACTION_WAIT,
		ST_BUS_LOCKED
	);

	signal Reg_Request				: std_logic_vector(PORTS - 1 downto 0)					:= (others => '0');
	signal Reg_ReadWrite			: std_logic_vector(PORTS - 1 downto 0)					:= (others => '0');
	signal Reg_Address				: T_XIL_DRP_ADDRESS_VECTOR(PORTS - 1 downto 0)	:= (others => (others => '0'));
	signal Reg_Data						: T_XIL_DRP_DATA_VECTOR(PORTS - 1 downto 0)			:= (others => (others => '0'));

	signal State							: T_STATE																				:= ST_IDLE;
	signal NextState					: T_STATE;

	signal FSM_Arbitrate			: std_logic;
	signal FSM_Ack						: std_logic;

	constant LOCKCOUNTER_MAX	: positive																									:= 15;

	signal LockCounter_rst		: std_logic;
	signal LockCounter_us			: unsigned(log2ceilnz(LOCKCOUNTER_MAX + 1) - 1 downto 0)		:= (others => '0');

	signal Request_or					: std_logic;
	signal Arb_Grant					: std_logic_vector(PORTS - 1 downto 0);
	signal Arb_Grant_bin			: std_logic_vector(log2ceilnz(PORTS) - 1 downto 0);

begin
	-- capture new bus transactions on every port
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Reg_Request				<= (others => '0');
				Reg_ReadWrite			<= (others => '0');
				Reg_Address				<= (others => (others => '0'));
				Reg_Data					<= (others => (others => '0'));
			else
				for i in 0 to PORTS - 1 loop
					if ((Arb_Grant(i) and FSM_Ack	) = '1') then
						Reg_Request(i)		<= '0';
					elsif (In_Enable(i) = '1') then
						Reg_Request(i)		<= '1';
						Reg_ReadWrite(i)	<= In_ReadWrite(i);
						Reg_Address(i)		<= In_Address(i);
						Reg_Data(i)				<= In_DataIn(i);
					end if;
				end loop;
			end if;
		end if;
	end process;

	Request_or		<= slv_or(Reg_Request);

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State		<= ST_IDLE;
			else
				State		<= NextState;
			end if;
		end if;
	end process;

	process(State, Request_or, Arb_Grant, Arb_Grant_bin, Reg_Request, Reg_ReadWrite, Reg_Address, Reg_Data, Out_Ack, LockCounter_us)
	begin
		NextState						<= State;

		FSM_Arbitrate				<= '0';
		FSM_Ack							<= '1';
		LockCounter_rst			<= '1';

		Out_Enable					<= '0';
		Out_ReadWrite				<= Reg_ReadWrite(to_index(Arb_Grant_bin));
		Out_Address					<= Reg_Address(to_index(Arb_Grant_bin));
		Out_DataOut					<= Reg_Data(to_index(Arb_Grant_bin));

		case State is
			when ST_IDLE =>
				if (Request_or = '1') then
					FSM_Arbitrate			<= '1';
					NextState					<= ST_BUS_TRANSACTION_START;
				end if;

			when ST_BUS_TRANSACTION_START =>
				Out_Enable					<= '1';
				NextState						<= ST_BUS_TRANSACTION_WAIT;

			when ST_BUS_TRANSACTION_WAIT =>
				if (Out_Ack = '1') then
					FSM_Ack						<= '1';
					NextState					<= ST_BUS_LOCKED;
				end if;

			when ST_BUS_LOCKED =>
				LockCounter_rst			<= '0';

				if (Reg_Request and Arb_Grant) = Arb_Grant then
					NextState					<= ST_BUS_TRANSACTION_START;
				elsif LockCounter_us = LOCKCOUNTER_MAX then
					NextState					<= ST_IDLE;
				end if;

		end case;
	end process;

	In_DataOut	<= (In_DataOut'range => Out_DataIn);
	In_Ack			<= (In_Ack'range => FSM_Ack	) and Arb_Grant;

	LockCounter_us	<= upcounter_next(cnt => LockCounter_us, rst => LockCounter_rst, en => '1') when rising_edge(Clock);

	Arb : entity PoC.bus_Arbiter
		generic map (
			STRATEGY				=> "RR",			-- RR, LOT
			PORTS						=> PORTS,
			OUTPUT_REG			=> FALSE
		)
		port map (
			Clock						=> Clock,
			Reset						=> Reset,

			Arbitrate				=> FSM_Arbitrate,
			Request_Vector	=> Reg_Request,

			Arbitrated			=> open,	--Arb_Arbitrated,
			Grant_Vector		=> Arb_Grant,
			Grant_Index			=> Arb_Grant_bin
		);
end architecture;
