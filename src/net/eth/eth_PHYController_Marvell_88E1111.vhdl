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
use			PoC.physical.all;
use			PoC.io.all;
use			PoC.net.all;


entity Eth_PHYController_Marvell_88E1111 is
	generic (
		DEBUG											: boolean													:= FALSE;
		CLOCK_FREQ								: FREQ														:= 125 MHz;
		PHY_DEVICE_ADDRESS				: T_NET_ETH_PHY_DEVICE_ADDRESS		:= "XXXXXXXX"
	);
	port (
		Clock											: in	std_logic;
		Reset											: in	std_logic;

		-- PHYController interface
		Command										: in	T_NET_ETH_PHYCONTROLLER_COMMAND;
		Status										: out	T_NET_ETH_PHYCONTROLLER_STATUS;
		Error											: out	T_NET_ETH_PHYCONTROLLER_ERROR;

		PHY_Reset									: out		std_logic;
		PHY_Interrupt							: in		std_logic;

		MDIO_Command							: out	T_IO_MDIO_MDIOCONTROLLER_COMMAND;
		MDIO_Status								: in	T_IO_MDIO_MDIOCONTROLLER_STATUS;
		MDIO_Error								: in	T_IO_MDIO_MDIOCONTROLLER_ERROR;

		MDIO_Physical_Address			: out	std_logic_vector(6 downto 0);
		MDIO_Register_Address			: out	std_logic_vector(4 downto 0);
		MDIO_Register_DataIn			: in	T_SLV_16;
		MDIO_Register_DataOut			: out	T_SLV_16
	);
end entity;


architecture rtl of Eth_PHYController_Marvell_88E1111 is
	attribute KEEP																		: boolean;
	attribute FSM_ENCODING														: string;

	type T_STATE is (
		ST_RESET,											ST_RESET_WAIT,
		ST_SEARCH_DEVICE,							ST_SEARCH_DEVICE_WAIT,
		ST_READ_DEVICE_ID_1,					ST_READ_DEVICE_ID_WAIT_1,
		ST_READ_DEVICE_ID_2,					ST_READ_DEVICE_ID_WAIT_2,
		ST_WRITE_INTERRUPT,						ST_WRITE_INTERRUPT_WAIT,
		ST_READ_STATUS,								ST_READ_STATUS_WAIT,
		ST_READ_PHY_SPECIFIC_STATUS,	ST_READ_PHY_SPECIFIC_STATUS_WAIT,
		ST_ERROR
	);

	signal State																			: T_STATE													:= ST_RESET;
	signal NextState																	: T_STATE;

	attribute FSM_ENCODING of State										: signal is ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	constant C_MDIO_REGADR_COMMAND										: std_logic_vector(4 downto 0)		:= to_slv( 0, 5);
	constant C_MDIO_REGADR_STATUS											: std_logic_vector(4 downto 0)		:= to_slv( 1, 5);
	constant C_MDIO_REGADR_EXT_STATUS									: std_logic_vector(4 downto 0)		:= to_slv(15, 5);
	constant C_MDIO_REGADR_PHY_IDENTIFIER_1						: std_logic_vector(4 downto 0)		:= to_slv( 2, 5);
	constant C_MDIO_REGADR_PHY_IDENTIFIER_2						: std_logic_vector(4 downto 0)		:= to_slv( 3, 5);
	constant C_MDIO_REGADR_NEXTPAGE_TRANSMIT					: std_logic_vector(4 downto 0)		:= to_slv( 7, 5);
	constant C_MDIO_REGADR_AUTONEG_ADVERTISEMENT			: std_logic_vector(4 downto 0)		:= to_slv( 4, 5);
	constant C_MDIO_REGADR_AUTONEG_EXPANION						: std_logic_vector(4 downto 0)		:= to_slv( 6, 5);
	constant C_MDIO_REGADR_LINKPARTNER_ABILITY				: std_logic_vector(4 downto 0)		:= to_slv( 5, 5);
	constant C_MDIO_REGADR_LINKPARTNER_NEXTPAGE				: std_logic_vector(4 downto 0)		:= to_slv( 8, 5);
	constant C_MDIO_REGADR_1000BASET_CONTROL					: std_logic_vector(4 downto 0)		:= to_slv( 9, 5);
	constant C_MDIO_REGADR_1000BASET_STATUS						: std_logic_vector(4 downto 0)		:= to_slv(10, 5);
	constant C_MDIO_REGADR_PHY_SPECIFIC_CONTROL				: std_logic_vector(4 downto 0)		:= to_slv(16, 5);
	constant C_MDIO_REGADR_EXT_PHY_SPECIFIC_CONTROL		: std_logic_vector(4 downto 0)		:= to_slv(20, 5);
	constant C_MDIO_REGADR_EXT_PHY_SPECIFIC_CONTROL2	: std_logic_vector(4 downto 0)		:= to_slv(26, 5);
	constant C_MDIO_REGADR_PHY_SPECIFIC_STATUS				: std_logic_vector(4 downto 0)		:= to_slv(17, 5);
	constant C_MDIO_REGADR_EXT_PHY_SPECIFIC_STATUS		: std_logic_vector(4 downto 0)		:= to_slv(27, 5);
	constant C_MDIO_REGADR_INTERRUPT_ENABLE						: std_logic_vector(4 downto 0)		:= to_slv(18, 5);
	constant C_MDIO_REGADR_INTERRUPT_STATUS						: std_logic_vector(4 downto 0)		:= to_slv(19, 5);
	constant C_MDIO_REGADR_EXT_ADDRESS								: std_logic_vector(4 downto 0)		:= to_slv(22, 5);
	constant C_MDIO_REGADR_GLOBAL_STATUS							: std_logic_vector(4 downto 0)		:= to_slv(23, 5);
	constant C_MDIO_REGADR_LED_CONTROL								: std_logic_vector(4 downto 0)		:= to_slv(24, 5);
	constant C_MDIO_REGADR_LED_OVERRIDE								: std_logic_vector(4 downto 0)		:= to_slv(25, 5);
	constant C_MDIO_REGADR_RECEIVE_ERROR_COUNTER			: std_logic_vector(4 downto 0)		:= to_slv(21, 5);

	constant TTID_RESET_PULSE													: natural		:= 0;
	constant TTID_WAITTIME_AFTER_LINK_UP							: natural		:= 1;

	constant TIMING_TABLE															: T_NATVEC	:= (
		TTID_RESET_PULSE								=> TimingToCycles(5000 ms,	CLOCK_FREQ),
		TTID_WAITTIME_AFTER_LINK_UP			=> TimingToCycles(1 ms,			CLOCK_FREQ)
	);

	signal TC_Enable																	: std_logic;
	signal TC_Load																		: std_logic;
	signal TC_Slot																		: integer;
	signal TC_Timeout																	: std_logic;

	signal PHY_Interrupt_rst													: std_logic;
	signal PHY_Interrupt_meta													: std_logic												:= '0';
	signal PHY_Interrupt_d														: std_logic												:= '0';
	signal PHY_Interrupt_l														: std_logic												:= '0';

	signal Status_rst																	: std_logic;
	signal Status_set																	: std_logic;
	signal Status_r																		: std_logic												:= '0';

begin


	process(Clock)
	begin
		if rising_edge(Clock) then
			PHY_Interrupt_meta			<= PHY_Interrupt;
			PHY_Interrupt_d					<= PHY_Interrupt_meta;

			if (PHY_Interrupt_rst = '1') then
				PHY_Interrupt_l				<= '0';
			elsif (PHY_Interrupt_d = '1') then
				PHY_Interrupt_l				<= '1';
			end if;
		end if;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State			<= ST_RESET;
			else
				State			<= NextState;
			end if;
		end if;
	end process;

	process(State, Command, TC_Timeout, PHY_Interrupt_l, MDIO_Status, MDIO_Error, MDIO_Register_DataIn, Status_r)
	begin
		NextState								<= State;

		Status									<= NET_ETH_PHYC_STATUS_RESETING;
		Error										<= NET_ETH_PHYC_ERROR_NONE;

		PHY_Reset								<= '0';

		MDIO_Command						<= IO_MDIO_MDIOC_CMD_NONE;
		MDIO_Physical_Address		<= resize(PHY_DEVICE_ADDRESS, MDIO_Physical_Address'length);
		MDIO_Register_Address		<= C_MDIO_REGADR_COMMAND;
		MDIO_Register_DataOut		<= x"0000";

		TC_Enable								<= '0';
		TC_Load									<= '0';
		TC_Slot									<= TTID_RESET_PULSE;

		PHY_Interrupt_rst				<= '0';
		Status_rst							<= '0';
		Status_set							<= '0';

		case State is
			when ST_RESET =>
				Status							<= NET_ETH_PHYC_STATUS_RESETING;

				TC_Load							<= '1';
				TC_Slot							<= TTID_RESET_PULSE;
				PHY_Reset						<= '1';

				NextState						<= ST_RESET_WAIT;

			when ST_RESET_WAIT =>
				Status							<= NET_ETH_PHYC_STATUS_RESETING;

				TC_Enable						<= '1';
				PHY_Reset						<= '1';

				if (TC_Timeout = '1') then
					NextState					<= ST_SEARCH_DEVICE;
				end if;

			when ST_SEARCH_DEVICE =>
				Status							<= NET_ETH_PHYC_STATUS_RESETING;
				MDIO_Command				<= IO_MDIO_MDIOC_CMD_CHECK_ADDRESS;

				NextState						<= ST_SEARCH_DEVICE_WAIT;

			when ST_SEARCH_DEVICE_WAIT =>
				Status							<= NET_ETH_PHYC_STATUS_RESETING;

				case MDIO_Status is
					when IO_MDIO_MDIOC_STATUS_CHECKING =>
						null;

					when IO_MDIO_MDIOC_STATUS_CHECK_OK =>
						NextState				<= ST_READ_DEVICE_ID_1;

					when IO_MDIO_MDIOC_STATUS_CHECK_FAILED =>
						NextState				<= ST_SEARCH_DEVICE;

					when IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState				<= ST_ERROR;

					when others =>
						NextState				<= ST_ERROR;
				end case;	-- MDIO_Status

			when ST_READ_DEVICE_ID_1 =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;

				MDIO_Command						<= IO_MDIO_MDIOC_CMD_READ;
				MDIO_Register_Address		<= C_MDIO_REGADR_PHY_IDENTIFIER_1;

				NextState								<= ST_READ_DEVICE_ID_WAIT_1;

			when ST_READ_DEVICE_ID_WAIT_1 =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;

				case MDIO_Status is
					when IO_MDIO_MDIOC_STATUS_READING =>
						null;

					when IO_MDIO_MDIOC_STATUS_READ_COMPLETE =>
						if (MDIO_Register_DataIn = x"0141") then									-- OUI
							NextState					<= ST_READ_DEVICE_ID_2;
						else
							NextState					<= ST_ERROR;
						end if;

					when IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;

					when others =>
						NextState					<= ST_ERROR;

				end case;	-- MDIO_Status

			when ST_READ_DEVICE_ID_2 =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;

				MDIO_Command						<= IO_MDIO_MDIOC_CMD_READ;
				MDIO_Register_Address		<= C_MDIO_REGADR_PHY_IDENTIFIER_2;

				NextState								<= ST_READ_DEVICE_ID_WAIT_2;

			when ST_READ_DEVICE_ID_WAIT_2 =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;

				case MDIO_Status is
					when IO_MDIO_MDIOC_STATUS_READING =>
						null;

					when IO_MDIO_MDIOC_STATUS_READ_COMPLETE =>
						if ((MDIO_Register_DataIn(15 downto 10) = "000011") and		-- OUI LSB
								(MDIO_Register_DataIn( 9 downto	 4) = "001100"))			-- Model Number - 88E1111
						then
--							NextState					<= ST_WRITE_INTERRUPT;
							NextState					<= ST_READ_PHY_SPECIFIC_STATUS;
						else
							NextState					<= ST_ERROR;
						end if;

					when IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;

					when others =>
						NextState					<= ST_ERROR;

				end case;	-- MDIO_Status

			when ST_WRITE_INTERRUPT =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;

				MDIO_Command						<= IO_MDIO_MDIOC_CMD_WRITE;
				MDIO_Register_Address		<= C_MDIO_REGADR_INTERRUPT_ENABLE;
				MDIO_Register_DataOut		<= x"CC14";

				NextState								<= ST_WRITE_INTERRUPT_WAIT;

			when ST_WRITE_INTERRUPT_WAIT =>
				Status									<= NET_ETH_PHYC_STATUS_RESETING;

				case MDIO_Status is
					when IO_MDIO_MDIOC_STATUS_WRITING =>
						null;

					when IO_MDIO_MDIOC_STATUS_WRITE_COMPLETE =>
--						NextState					<= ST_READ_STATUS;
						NextState					<= ST_READ_PHY_SPECIFIC_STATUS;

					when IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;

					when others =>
						NextState					<= ST_ERROR;

				end case;	-- MDIO_Status

			when ST_READ_STATUS =>
				if (Status_r = '0') then
					Status								<= NET_ETH_PHYC_STATUS_CONNECTING;
				else
					Status								<= NET_ETH_PHYC_STATUS_CONNECTED;
				end if;

				MDIO_Command						<= IO_MDIO_MDIOC_CMD_READ;
				MDIO_Register_Address		<= C_MDIO_REGADR_STATUS;

				NextState								<= ST_READ_STATUS_WAIT;

			when ST_READ_STATUS_WAIT =>
				if (Status_r = '0') then
					Status						<= NET_ETH_PHYC_STATUS_CONNECTING;
				else
					Status						<= NET_ETH_PHYC_STATUS_CONNECTED;
				end if;

				case MDIO_Status is
					when IO_MDIO_MDIOC_STATUS_READING =>
						null;

					when IO_MDIO_MDIOC_STATUS_READ_COMPLETE =>
						if ((MDIO_Register_DataIn(15)	= '0') and
								(MDIO_Register_DataIn(10)	= '0') and
								(MDIO_Register_DataIn(9)	= '0') and
								(MDIO_Register_DataIn(8)	= '1') and
								(MDIO_Register_DataIn(6)	= '1') and
								(MDIO_Register_DataIn(5)	= '1') and
								(MDIO_Register_DataIn(4)	= '0') and
								(MDIO_Register_DataIn(3)	= '1') and
								(MDIO_Register_DataIn(2)	= '1') and
								(MDIO_Register_DataIn(0)	= '1'))
						then
							Status_set			<= '1';
						else
							Status_rst			<= '1';
						end if;

						NextState					<= ST_READ_STATUS;

					when IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;

					when others =>
						NextState					<= ST_ERROR;

				end case;	-- MDIO_Status

			when ST_READ_PHY_SPECIFIC_STATUS =>
				if (Status_r = '0') then
					Status								<= NET_ETH_PHYC_STATUS_CONNECTING;
				else
					Status								<= NET_ETH_PHYC_STATUS_CONNECTED;
				end if;

				MDIO_Command						<= IO_MDIO_MDIOC_CMD_READ;
				MDIO_Register_Address		<= C_MDIO_REGADR_PHY_SPECIFIC_STATUS;

				NextState								<= ST_READ_PHY_SPECIFIC_STATUS_WAIT;

			when ST_READ_PHY_SPECIFIC_STATUS_WAIT =>
				if (Status_r = '0') then
					Status						<= NET_ETH_PHYC_STATUS_CONNECTING;
				else
					Status						<= NET_ETH_PHYC_STATUS_CONNECTED;
				end if;

				case MDIO_Status is
					when IO_MDIO_MDIOC_STATUS_READING =>
						null;

					when IO_MDIO_MDIOC_STATUS_READ_COMPLETE =>
						if ((MDIO_Register_DataIn(15)	= '1') and
								(MDIO_Register_DataIn(14)	= '0') and
								(MDIO_Register_DataIn(13)	= '1') and
								(MDIO_Register_DataIn(11)	= '1') and
								(MDIO_Register_DataIn(10)	= '1') and
								(MDIO_Register_DataIn(4)	= '0'))
						then
							Status_set			<= '1';
						else
							Status_rst			<= '1';
						end if;

						NextState					<= ST_READ_PHY_SPECIFIC_STATUS;

					when IO_MDIO_MDIOC_STATUS_ERROR =>
						NextState					<= ST_ERROR;

					when others =>
						NextState					<= ST_ERROR;

				end case;	-- MDIO_Status

			when ST_ERROR =>
				Status								<= NET_ETH_PHYC_STATUS_ERROR;
				null;

		end case;
	end process;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if ((Reset or Status_rst) = '1') then
				Status_r			<= '0';
			elsif (Status_set = '1') then
				Status_r			<= '1';
			end if;
		end if;
	end process;

	TC : entity PoC.io_TimingCounter
		generic map (
			TIMING_TABLE				=> TIMING_TABLE											-- timing table
		)
		port map (
			Clock								=> Clock,														-- clock
			Enable							=> TC_Enable,												-- enable counter
			Load								=> TC_Load,													-- load Timing Value from TIMING_TABLE selected by slot
			Slot								=> TC_Slot,													--
			Timeout							=> TC_Timeout												-- timing reached
		);
end;
