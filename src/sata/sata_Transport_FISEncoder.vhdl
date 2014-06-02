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
--USE			PoC.sata.ALL;


ENTITY sata_FISEncoder IS
	GENERIC (
		DEBUG												: BOOLEAN						:= FALSE
	);
	PORT (
		Clock												: IN	STD_LOGIC;
		Reset												: IN	STD_LOGIC;
		
		FISType											: IN	T_SATA_FISTYPE;
		Status											: OUT	T_FISENCODER_STATUS;
		ATARegisters								: IN	T_ATA_HOST_REGISTERS;
		
		-- writer interface
		TX_Ready										: OUT	STD_LOGIC;
		TX_SOP											: IN	STD_LOGIC;
		TX_EOP											: IN	STD_LOGIC;
		TX_Data											: IN	T_SLV_32;
		TX_Valid										: IN	STD_LOGIC;
		TX_InsertEOP								: OUT	STD_LOGIC;
		
		-- SATAController interface (LinkLayer)
		Link_TX_Ready								: IN	STD_LOGIC;
		Link_TX_Data								: OUT	T_SLV_32;
		Link_TX_SOF									: OUT STD_LOGIC;
		Link_TX_EOF									: OUT STD_LOGIC;
		Link_TX_Valid								: OUT	STD_LOGIC;
		Link_TX_InsertEOF						: IN	STD_LOGIC;
		
		Link_TX_FS_Ready						: OUT	STD_LOGIC;
		Link_TX_FS_SendOK						: IN	STD_LOGIC;
		Link_TX_FS_Abort						: IN	STD_LOGIC;
		Link_TX_FS_Valid						: IN	STD_LOGIC
	);
END;

ARCHITECTURE rtl OF sata_FISEncoder IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;

	TYPE T_STATE IS (
		ST_IDLE,
		ST_FIS_REG_HOST_DEV_WORD_0, ST_FIS_REG_HOST_DEV_WORD_1,	ST_FIS_REG_HOST_DEV_WORD_2,	ST_FIS_REG_HOST_DEV_WORD_3,	ST_FIS_REG_HOST_DEV_WORD_4,
		ST_DATA_0, ST_DATA_N,
		ST_EVALUATE_FRAMESTATE
	);
	
	-- Alias-Definitions for FISType Register Transfer Host => Device (27h)
	-- ====================================================================================
	-- Word 0
	ALIAS Alias_FISType										: T_SLV_8													IS Link_TX_Data(7 DOWNTO 0);
	ALIAS Alias_FlagC											: STD_LOGIC												IS Link_TX_Data(15);
	ALIAS Alias_CommandReg								: T_SLV_8													IS Link_TX_Data(23 DOWNTO 16);			-- Command register
	ALIAS Alias_FeatureReg								: T_SLV_8													IS Link_TX_Data(31 DOWNTO 24);			-- Feature register
	
	-- Word 1
	ALIAS Alias_LBA0											: T_SLV_8													IS Link_TX_Data(7 DOWNTO 0);				-- Sector Number
	ALIAS Alias_LBA8											: T_SLV_8													IS Link_TX_Data(15 DOWNTO 8);				-- Sector Number expanded
	ALIAS Alias_LBA16											: T_SLV_8													IS Link_TX_Data(23 DOWNTO 16);			-- Cylinder Low
	ALIAS Alias_Head											: T_SLV_4													IS Link_TX_Data(27 DOWNTO 24);			-- Head number
	ALIAS Alias_Device										: STD_LOGIC_VECTOR(0 DOWNTO 0)		IS Link_TX_Data(28 DOWNTO 28);			-- Device number
	ALIAS Alias_FlagLBA48									: STD_LOGIC												IS Link_TX_Data(30);								-- is LBA-48 address
	
	-- Word 2
	ALIAS Alias_LBA24											: T_SLV_8													IS Link_TX_Data(7 DOWNTO 0);				-- Cylinder Low expanded
	ALIAS Alias_LBA32											: T_SLV_8													IS Link_TX_Data(15 DOWNTO 8);				-- Cylinder High
	ALIAS Alias_LBA40											: T_SLV_8													IS Link_TX_Data(23 DOWNTO 16);			-- Cylinder High expanded
	
	-- Word 3
	ALIAS Alias_SecCount0									: T_SLV_8													IS Link_TX_Data(7 DOWNTO 0);				-- Sector Count
	ALIAS Alias_SecCount8									: T_SLV_8													IS Link_TX_Data(15 DOWNTO 8);				-- Sector Count expanded
	ALIAS Alias_ControlReg								: T_SLV_8													IS Link_TX_Data(31 DOWNTO 24);			-- Control register

	-- Word 4
--	ALIAS Alias_TransferCount							: T_SLV_16												IS Link_TX_Data(15 DOWNTO 0);				-- Transfer Count
	
	SIGNAL State													: T_STATE													:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS ite(DEBUG					, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(State, FISType, ATARegisters, TX_Valid, TX_Data, TX_SOP, TX_EOP, Link_TX_Ready, Link_TX_FS_Valid, Link_TX_FS_SendOK, Link_TX_FS_Abort, Link_TX_InsertEOF)
	BEGIN
		NextState										<= State;
		
		Status											<= FISE_STATUS_SENDING;
		
		TX_Ready										<= '0';
    TX_InsertEOP                <= '0';
		
		Link_TX_Valid								<= '0';
		Link_TX_EOF									<= '0';
		Link_TX_SOF									<= '0';
		Link_TX_Data								<= (OTHERS => '0');

		Link_TX_FS_Ready						<= '0';

		-- FIS Word 0
		Alias_FISType								<= x"00";
		Alias_FlagC									<= '0';														-- set C flag => access Command register on device
		Alias_CommandReg						<= x"00";													-- Command register
		Alias_FeatureReg						<= x"00";													-- Feature register

		-- Word 1
		Alias_LBA0									<= x"00";													-- Sector Number
		Alias_LBA16									<= x"00";													-- Cylinder Low
		Alias_LBA32									<= x"00";													-- Cylinder High
		Alias_Head									<= x"0";													-- Head number
		Alias_Device								<=  "0";													-- Device number
		Alias_FlagLBA48							<=	'0';													-- LBA-48 adressing mode
	
		-- Word 2
		Alias_LBA8									<= x"00";													-- Sector Number expanded
		Alias_LBA24									<= x"00";													-- Cylinder Low expanded
		Alias_LBA40									<= x"00";													-- Cylinder High expanded
	
		-- Word 3
		Alias_SecCount0							<= x"00";													-- Sector Count
		Alias_SecCount8							<= x"00";													-- Sector Count expanded
		Alias_ControlReg						<= x"00";													-- Control register		

		CASE State IS
			WHEN ST_IDLE =>
				Status										<= FISE_STATUS_IDLE;
			
				CASE FISType IS
					WHEN SATA_FISTYPE_REG_HOST_DEV =>
						-- send "Register-FIS - Host to Device"
						Status								<= FISE_STATUS_SENDING;
						
						Link_TX_Valid					<= '1';
						Link_TX_SOF						<= '1';
						
						Alias_FISType					<= to_slv(SATA_FISTYPE_REG_HOST_DEV);
						Alias_FlagC						<= ATARegisters.Flag_C;
						Alias_CommandReg			<= ATARegisters.Command;
						Alias_FeatureReg			<= x"00";

						IF (Link_TX_Ready = '1') THEN							
							NextState						<= ST_FIS_REG_HOST_DEV_WORD_1;
						ELSE
							NextState						<= ST_FIS_REG_HOST_DEV_WORD_0;
						END IF;
					
					WHEN SATA_FISTYPE_DATA =>
						Status								<= FISE_STATUS_SENDING;
					
						-- send "Data-FIS - Host to Device"
						Link_TX_Valid					<= '1';
						Link_TX_SOF						<= '1';
						
						Alias_FISType					<= to_slv(SATA_FISTYPE_DATA);
					
						NextState							<= ST_DATA_0;
					
					WHEN OTHERS =>
						NULL;
						
				END CASE;

			WHEN ST_FIS_REG_HOST_DEV_WORD_0 =>
				-- send "Register-FIS - Host to Device"
				Link_TX_Valid							<= '1';
				Link_TX_SOF								<= '1';
				
				Alias_FISType							<= to_slv(SATA_FISTYPE_REG_HOST_DEV);
				Alias_FlagC								<= ATARegisters.Flag_C;
				Alias_CommandReg					<= ATARegisters.Command;
				Alias_FeatureReg					<= x"00";

				IF (Link_TX_Ready = '1') THEN					
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_1;
				END IF;

			WHEN ST_FIS_REG_HOST_DEV_WORD_1 =>
				Link_TX_Valid							<= '1';
				
				Alias_LBA0								<= ATARegisters.LBlockAddress(7 DOWNTO 0);
				Alias_LBA8								<= ATARegisters.LBlockAddress(15 DOWNTO 8);
				Alias_LBA16								<= ATARegisters.LBlockAddress(23 DOWNTO 16);
				Alias_Head								<= x"0";																								-- Head number
				Alias_Device							<=  "0";																								-- Device number
				Alias_FlagLBA48						<= is_LBA48_Command(to_ata_cmd(ATARegisters.Command));	-- LBA-48 adressing mode

				IF (Link_TX_Ready = '1') THEN					
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_2;
				END IF;
					
			WHEN ST_FIS_REG_HOST_DEV_WORD_2 =>
				Link_TX_Valid							<= '1';

				Alias_LBA24								<= ATARegisters.LBlockAddress(31 DOWNTO 24);
				Alias_LBA32								<= ATARegisters.LBlockAddress(39 DOWNTO 32);
				Alias_LBA40								<= ATARegisters.LBlockAddress(47 DOWNTO 40);

				IF (Link_TX_Ready = '1') THEN					
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_3;
				END IF;
				
			WHEN ST_FIS_REG_HOST_DEV_WORD_3 =>
				Link_TX_Valid							<= '1';
				
				Alias_SecCount0						<= ATARegisters.SectorCount(7 DOWNTO 0);					-- Sector Count
				Alias_SecCount8						<= ATARegisters.SectorCount(15 DOWNTO 8);					-- Sector Count expanded
				Alias_ControlReg					<= ATARegisters.Control;													-- Control register		

				IF (Link_TX_Ready = '1') THEN					
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_4;
				END IF;
					
			WHEN ST_FIS_REG_HOST_DEV_WORD_4 =>
				Link_TX_Valid							<= '1';
				Link_TX_EOF								<= '1';

				IF (Link_TX_Ready = '1') THEN
					NextState								<= ST_EVALUATE_FRAMESTATE;
				END IF;
				
			WHEN ST_DATA_0 =>
				Link_TX_Data							<= TX_Data;

				TX_Ready									<= Link_TX_Ready;
				TX_InsertEOP							<= Link_TX_InsertEOF;
				Link_TX_EOF								<= TX_EOP;
				Link_TX_Valid							<= TX_Valid;
				
				IF (TX_Valid = '1') THEN
					IF (TX_SOP = '1') THEN
						IF (Link_TX_Ready = '1') THEN
							NextState						<= ST_DATA_N;
						
							IF (TX_EOP = '1') THEN
								NextState					<= ST_EVALUATE_FRAMESTATE;
							END IF;
						END IF;
					ELSE
						Status								<= FISE_STATUS_ERROR;
						NextState							<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_DATA_N =>
				Link_TX_Data							<= TX_Data;

				TX_Ready									<= Link_TX_Ready;
				TX_InsertEOP							<= Link_TX_InsertEOF;
				Link_TX_EOF								<= TX_EOP;
				Link_TX_Valid							<= TX_Valid;
				
				IF (TX_Valid = '1') THEN
					IF (Link_TX_Ready = '1') THEN
						IF (TX_EOP = '1') THEN
							NextState						<= ST_EVALUATE_FRAMESTATE;
						END IF;
					END IF;
				END IF;

			WHEN ST_EVALUATE_FRAMESTATE =>
				IF (Link_TX_FS_Valid = '1') THEN
					IF (Link_TX_FS_SendOK = '1') THEN
						Link_TX_FS_Ready			<= '1';
						Status								<= FISE_STATUS_SEND_OK;
						
						NextState							<= ST_IDLE;
					ELSE
						Link_TX_FS_Ready			<= '1';
						Status								<= FISE_STATUS_ERROR;
						
						NextState							<= ST_IDLE;
					END IF;
				END IF;
			
		END CASE;
	END PROCESS;
	
END;
