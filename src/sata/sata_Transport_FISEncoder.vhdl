-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Module:					FIS Encoder for SATA Transport Layer
--
-- Description:
-- ------------------------------------
-- See notes on module 'sata_TransportLayer'.
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
use			PoC.debug.all;
use			PoC.sata.all;
use			PoC.satadbg.all;


entity sata_FISEncoder IS
	generic (
		DEBUG												: BOOLEAN						:= FALSE;
		ENABLE_DEBUGPORT						: BOOLEAN						:= FALSE
	);
	port (
		Clock												: in	STD_LOGIC;
		Reset												: in	STD_LOGIC;
		
		FISType											: in	T_SATA_FISTYPE;
		Status											: out	T_SATA_FISENCODER_STATUS;
		ATARegisters								: in	T_SATA_ATA_HOST_REGISTERS;
		
		-- debugPort
		DebugPortOut								: out	T_SATADBG_TRANS_FISE_OUT;
		
		-- writer interface
		TX_Ack											: out	STD_LOGIC;
		TX_SOP											: in	STD_LOGIC;
		TX_EOP											: in	STD_LOGIC;
		TX_Data											: in	T_SLV_32;
		TX_Valid										: in	STD_LOGIC;
		TX_InsertEOP								: out	STD_LOGIC;
		
		-- SATAController Status
		Phy_Status										: IN	T_SATA_PHY_STATUS;
		
		-- LinkLayer FIFO interface
		Link_TX_Ack									: in	STD_LOGIC;
		Link_TX_Data								: out	T_SLV_32;
		Link_TX_SOF									: out STD_LOGIC;
		Link_TX_EOF									: out STD_LOGIC;
		Link_TX_Valid								: out	STD_LOGIC;
		Link_TX_InsertEOF						: in	STD_LOGIC;
		
		Link_TX_FS_Ack							: out	STD_LOGIC;
		Link_TX_FS_SendOK						: in	STD_LOGIC;
		Link_TX_FS_Abort						: in	STD_LOGIC;
		Link_TX_FS_Valid						: in	STD_LOGIC
	);
end;

ARCHITECTURE rtl OF sata_FISEncoder IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;

	TYPE T_STATE IS (
		ST_RESET, ST_IDLE,
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
	
	SIGNAL State													: T_STATE													:= ST_RESET;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State			: SIGNAL IS getFSMEncoding_gray(DEBUG);
	
BEGIN

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_RESET;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(State, Phy_Status, FISType, ATARegisters, TX_Valid, TX_Data, TX_SOP, TX_EOP, Link_TX_Ack, Link_TX_FS_Valid, Link_TX_FS_SendOK, Link_TX_FS_Abort, Link_TX_InsertEOF)
	BEGIN
		NextState										<= State;
		
		Status											<= SATA_FISE_STATUS_SENDING;
		
		TX_Ack											<= '0';
    TX_InsertEOP                <= '0';
		
		Link_TX_Valid								<= '0';
		Link_TX_EOF									<= '0';
		Link_TX_SOF									<= '0';
		Link_TX_Data								<= (OTHERS => '0');

		Link_TX_FS_Ack							<= '0';

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
			when ST_RESET =>
				-- Clock might be unstable is this state. In this case either
				-- a) Reset is asserted because inital reset of the SATAController is
				--    not finished yet.
				-- b) Phy_Status is constant and not equal to SATA_PHY_STATUS_LINK_OK.
				--    This may happen during reconfiguration due to speed negotiation.
        Status										<= SATA_FISE_STATUS_RESET;
        
        if (Phy_Status = SATA_PHY_STATUS_COMMUNICATING) then
					NextState <= ST_IDLE;
        end if;
				
			WHEN ST_IDLE =>
				Status										<= SATA_FISE_STATUS_IDLE;
			
				CASE FISType IS
					WHEN SATA_FISTYPE_REG_HOST_DEV =>
						-- send "Register-FIS - Host to Device"
						Status								<= SATA_FISE_STATUS_SENDING;
						
						Link_TX_Valid					<= '1';
						Link_TX_SOF						<= '1';
						
						Alias_FISType					<= to_slv(SATA_FISTYPE_REG_HOST_DEV);
						Alias_FlagC						<= ATARegisters.Flag_C;
						Alias_CommandReg			<= ATARegisters.Command;
						Alias_FeatureReg			<= x"00";

						IF (Link_TX_Ack = '1') THEN							
							NextState						<= ST_FIS_REG_HOST_DEV_WORD_1;
						ELSE
							NextState						<= ST_FIS_REG_HOST_DEV_WORD_0;
						END IF;
					
					WHEN SATA_FISTYPE_DATA =>
						Status								<= SATA_FISE_STATUS_SENDING;
					
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

				IF (Link_TX_Ack = '1') THEN					
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_1;
				END IF;

			WHEN ST_FIS_REG_HOST_DEV_WORD_1 =>
				Link_TX_Valid							<= '1';
				
				Alias_LBA0								<= ATARegisters.LBlockAddress(7 DOWNTO 0);
				Alias_LBA8								<= ATARegisters.LBlockAddress(15 DOWNTO 8);
				Alias_LBA16								<= ATARegisters.LBlockAddress(23 DOWNTO 16);
				Alias_Head								<= x"0";																								-- Head number
				Alias_Device							<=  "0";																								-- Device number
				Alias_FlagLBA48						<= is_LBA48_Command(to_sata_ata_command(ATARegisters.Command));	-- LBA-48 adressing mode

				IF (Link_TX_Ack = '1') THEN					
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_2;
				END IF;
					
			WHEN ST_FIS_REG_HOST_DEV_WORD_2 =>
				Link_TX_Valid							<= '1';

				Alias_LBA24								<= ATARegisters.LBlockAddress(31 DOWNTO 24);
				Alias_LBA32								<= ATARegisters.LBlockAddress(39 DOWNTO 32);
				Alias_LBA40								<= ATARegisters.LBlockAddress(47 DOWNTO 40);

				IF (Link_TX_Ack = '1') THEN					
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_3;
				END IF;
				
			WHEN ST_FIS_REG_HOST_DEV_WORD_3 =>
				Link_TX_Valid							<= '1';
				
				Alias_SecCount0						<= ATARegisters.SectorCount(7 DOWNTO 0);					-- Sector Count
				Alias_SecCount8						<= ATARegisters.SectorCount(15 DOWNTO 8);					-- Sector Count expanded
				Alias_ControlReg					<= ATARegisters.Control;													-- Control register		

				IF (Link_TX_Ack = '1') THEN					
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_4;
				END IF;
					
			WHEN ST_FIS_REG_HOST_DEV_WORD_4 =>
				Link_TX_Valid							<= '1';
				Link_TX_EOF								<= '1';

				IF (Link_TX_Ack = '1') THEN
					NextState								<= ST_EVALUATE_FRAMESTATE;
				END IF;
				
			WHEN ST_DATA_0 =>
				Link_TX_Data							<= TX_Data;

				TX_Ack										<= Link_TX_Ack;
				TX_InsertEOP							<= Link_TX_InsertEOF;
				Link_TX_EOF								<= TX_EOP;
				Link_TX_Valid							<= TX_Valid;
				
				IF (TX_Valid = '1') THEN
					IF (TX_SOP = '1') THEN
						IF (Link_TX_Ack = '1') THEN
							NextState						<= ST_DATA_N;
						
							IF (TX_EOP = '1') THEN
								NextState					<= ST_EVALUATE_FRAMESTATE;
							END IF;
						END IF;
					ELSE
						Status								<= SATA_FISE_STATUS_ERROR;
						NextState							<= ST_IDLE;
					END IF;
				END IF;

			WHEN ST_DATA_N =>
				Link_TX_Data							<= TX_Data;

				TX_Ack										<= Link_TX_Ack;
				TX_InsertEOP							<= Link_TX_InsertEOF;
				Link_TX_EOF								<= TX_EOP;
				Link_TX_Valid							<= TX_Valid;
				
				IF (TX_Valid = '1') THEN
					IF (Link_TX_Ack = '1') THEN
						IF (TX_EOP = '1') THEN
							NextState						<= ST_EVALUATE_FRAMESTATE;
						END IF;
					END IF;
				END IF;

			WHEN ST_EVALUATE_FRAMESTATE =>
				IF (Link_TX_FS_Valid = '1') THEN
					IF (Link_TX_FS_SendOK = '1') THEN
						Link_TX_FS_Ack				<= '1';
						Status								<= SATA_FISE_STATUS_SEND_OK;
						
						NextState							<= ST_IDLE;
					ELSE
						Link_TX_FS_Ack				<= '1';
						Status								<= SATA_FISE_STATUS_ERROR;
						
						NextState							<= ST_IDLE;
					end if;
				end if;
			
		end case;
	end process;


	-- debug ports
	-- ==========================================================================================================================================================
	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeState(st : T_STATE) return STD_LOGIC_VECTOR is
		begin
			return to_slv(T_STATE'pos(st), log2ceilnz(T_STATE'pos(T_STATE'high) + 1));
		end function;
		
	begin
		genXilinx : if (VENDOR = VENDOR_XILINX) generate
			function dbg_GenerateStateEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_STATE loop
					STD.TextIO.write(l, str_replace(T_STATE'image(i), "st_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			function dbg_generateStatusEncodings return string is
				variable  l : STD.TextIO.line;
			begin
				for i in T_SATA_FISENCODER_STATUS loop
					STD.TextIO.write(l, str_replace(T_SATA_FISENCODER_STATUS'image(i), "sata_fise_status_", ""));
					STD.TextIO.write(l, ';');
				end loop;
				return  l.all;
			end function;
			
			constant dummy : T_BOOLVEC := (
				0 => dbg_ExportEncoding("Transport Layer FIS-Encoder - FSM", dbg_GenerateStateEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/FSM_TransLayer_FISE.tok"),
				1 => dbg_ExportEncoding("Transport Layer FIS-Encoder - Status", dbg_GenerateStatusEncodings,  PROJECT_DIR & "ChipScope/TokenFiles/ENUM_Trans_FISE_Status.tok")
			);
		begin
		end generate;
		
		DebugPortOut.FSM		<= dbg_EncodeState(State);
	end generate;
end;
