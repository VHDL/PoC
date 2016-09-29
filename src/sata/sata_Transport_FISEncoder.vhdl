-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Martin Zabel
--
-- Entity:					FIS Encoder for SATA Transport Layer
--
-- Description:
-- -------------------------------------
-- See notes on module 'sata_TransportLayer'.
--
-- Status:
-- -------
-- *_RESET: 								Link_Status is not yet IDLE.
-- *_IDLE:									Ready to send new FIS.
-- *_SENDING: 							Sending FIS.
-- *_SEND_OK:								FIS transmitted and acknowledged with R_OK  by other end.
-- *_SEND_ERROR:						FIS transmitted and acknowledged with R_ERR by other end.
-- *_SYNC_ESC:							Sending aborted by SYNC.
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


entity sata_FISEncoder is
	generic (
		DEBUG												: boolean						:= FALSE;
		ENABLE_DEBUGPORT						: boolean						:= FALSE
	);
	port (
		Clock												: in	std_logic;
		Reset												: in	std_logic;

		FISType											: in	T_SATA_FISTYPE;
		Status											: out	T_SATA_FISENCODER_STATUS;
		ATARegisters								: in	T_SATA_ATA_HOST_REGISTERS;

		-- debugPort
		DebugPortOut								: out	T_SATADBG_TRANS_FISE_OUT;

		-- writer interface
		TX_Ack											: out	std_logic;
		TX_SOP											: in	std_logic;
		TX_EOP											: in	std_logic;
		TX_Data											: in	T_SLV_32;
		TX_Valid										: in	std_logic;
		TX_InsertEOP								: out	std_logic;

		-- LinkLayer CSE
		Link_Status									: in	T_SATA_LINK_STATUS;

		-- LinkLayer FIFO interface
		Link_TX_Ack									: in	std_logic;
		Link_TX_Data								: out	T_SLV_32;
		Link_TX_SOF									: out std_logic;
		Link_TX_EOF									: out std_logic;
		Link_TX_Valid								: out	std_logic;
		Link_TX_InsertEOF						: in	std_logic;

		Link_TX_FS_Ack							: out	std_logic;
		Link_TX_FS_SendOK						: in	std_logic;
		Link_TX_FS_SyncEsc					: in	std_logic;
		Link_TX_FS_Valid						: in	std_logic
	);
end entity;


architecture rtl of sata_FISEncoder is
	attribute KEEP									: boolean;
	attribute FSM_ENCODING					: string;

	type T_STATE is (
		ST_RESET, ST_IDLE,
		ST_FIS_REG_HOST_DEV_WORD_0, ST_FIS_REG_HOST_DEV_WORD_1,	ST_FIS_REG_HOST_DEV_WORD_2,	ST_FIS_REG_HOST_DEV_WORD_3,	ST_FIS_REG_HOST_DEV_WORD_4,
		ST_DATA_0, ST_DATA_N, ST_ABORT_FRAME,
		ST_EVALUATE_FRAMESTATE,
		ST_STATUS_SEND_OK, ST_STATUS_SEND_ERROR, ST_STATUS_SYNC_ESC
	);

	-- Alias-Definitions for FISType Register Transfer Host => Device (27h)
	-- ====================================================================================
	-- Word 0
	alias Alias_FISType										: T_SLV_8													is Link_TX_Data(7 downto 0);
	alias Alias_FlagC											: std_logic												is Link_TX_Data(15);
	alias Alias_CommandReg								: T_SLV_8													is Link_TX_Data(23 downto 16);			-- Command register
	alias Alias_FeatureReg								: T_SLV_8													is Link_TX_Data(31 downto 24);			-- Feature register

	-- Word 1
	alias Alias_LBA0											: T_SLV_8													is Link_TX_Data(7 downto 0);				-- Sector Number
	alias Alias_LBA8											: T_SLV_8													is Link_TX_Data(15 downto 8);				-- Sector Number expanded
	alias Alias_LBA16											: T_SLV_8													is Link_TX_Data(23 downto 16);			-- Cylinder Low
	alias Alias_Head											: T_SLV_4													is Link_TX_Data(27 downto 24);			-- Head number
	alias Alias_Device										: std_logic_vector(0 downto 0)		is Link_TX_Data(28 downto 28);			-- Device number
	alias Alias_FlagLBA48									: std_logic												is Link_TX_Data(30);								-- is LBA-48 address

	-- Word 2
	alias Alias_LBA24											: T_SLV_8													is Link_TX_Data(7 downto 0);				-- Cylinder Low expanded
	alias Alias_LBA32											: T_SLV_8													is Link_TX_Data(15 downto 8);				-- Cylinder High
	alias Alias_LBA40											: T_SLV_8													is Link_TX_Data(23 downto 16);			-- Cylinder High expanded

	-- Word 3
	alias Alias_SecCount0									: T_SLV_8													is Link_TX_Data(7 downto 0);				-- Sector Count
	alias Alias_SecCount8									: T_SLV_8													is Link_TX_Data(15 downto 8);				-- Sector Count expanded
	alias Alias_ControlReg								: T_SLV_8													is Link_TX_Data(31 downto 24);			-- Control register

	-- Word 4
--	ALIAS Alias_TransferCount							: T_SLV_16												IS Link_TX_Data(15 downto 0);				-- Transfer Count

	signal State													: T_STATE													:= ST_RESET;
	signal NextState											: T_STATE;
	attribute FSM_ENCODING	of State			: signal is getFSMEncoding_gray(DEBUG);

begin

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

	process(State, Link_Status, FISType, ATARegisters, TX_Valid, TX_Data, TX_SOP, TX_EOP, Link_TX_Ack, Link_TX_FS_Valid, Link_TX_FS_SendOK, Link_TX_FS_SyncEsc, Link_TX_InsertEOF)
	begin
		NextState										<= State;

		Status											<= SATA_FISE_STATUS_SENDING;

		TX_Ack											<= '0';
    TX_InsertEOP                <= '0';

		Link_TX_Valid								<= '0';
		Link_TX_EOF									<= '0';
		Link_TX_SOF									<= '0';
		Link_TX_Data								<= (others => '0');

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

		case State is
			when ST_RESET =>
				-- Clock might be unstable is this state. In this case either
				-- a) Reset is asserted because inital reset of the SATAController is
				--    not finished yet.
				-- b) Link_Status is constant and not equal to SATA_LINK_STATUS_IDLE
				--    This may happen during reconfiguration due to speed negotiation.
        Status										<= SATA_FISE_STATUS_RESET;

        if (Link_Status = SATA_LINK_STATUS_IDLE) then
					NextState <= ST_IDLE;
        end if;

			when ST_IDLE =>
				Status										<= SATA_FISE_STATUS_IDLE;

				case FISType is
					when SATA_FISTYPE_REG_HOST_DEV =>
						-- send "Register-FIS - Host to Device"
						Link_TX_Valid					<= '1';
						Link_TX_SOF						<= '1';

						Alias_FISType					<= to_slv(SATA_FISTYPE_REG_HOST_DEV);
						Alias_FlagC						<= ATARegisters.Flag_C;
						Alias_CommandReg			<= ATARegisters.Command;
						Alias_FeatureReg			<= x"00";

						if (Link_TX_Ack = '1') then
							NextState						<= ST_FIS_REG_HOST_DEV_WORD_1;
						else
							NextState						<= ST_FIS_REG_HOST_DEV_WORD_0;
						end if;

					when SATA_FISTYPE_DATA =>
						-- send "Data-FIS - Host to Device"
						Link_TX_Valid					<= '1';
						Link_TX_SOF						<= '1';

						Alias_FISType					<= to_slv(SATA_FISTYPE_DATA);

						if (Link_TX_Ack = '1') then
							NextState						<= ST_DATA_N;
						else
							NextState						<= ST_DATA_0;
						end if;

					when others =>
						null;

				end case;

			when ST_FIS_REG_HOST_DEV_WORD_0 =>
				-- send "Register-FIS - Host to Device"
				Link_TX_Valid							<= '1';
				Link_TX_SOF								<= '1';

				Alias_FISType							<= to_slv(SATA_FISTYPE_REG_HOST_DEV);
				Alias_FlagC								<= ATARegisters.Flag_C;
				Alias_CommandReg					<= ATARegisters.Command;
				Alias_FeatureReg					<= x"00";

				if (Link_TX_Ack = '1') then
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_1;
				end if;

			when ST_FIS_REG_HOST_DEV_WORD_1 =>
				Link_TX_Valid							<= '1';

				Alias_LBA0								<= ATARegisters.LBlockAddress(7 downto 0);
				Alias_LBA8								<= ATARegisters.LBlockAddress(15 downto 8);
				Alias_LBA16								<= ATARegisters.LBlockAddress(23 downto 16);
				Alias_Head								<= x"0";																								-- Head number
				Alias_Device							<=  "0";																								-- Device number
				Alias_FlagLBA48						<= is_LBA48_Command(to_sata_ata_command(ATARegisters.Command));	-- LBA-48 adressing mode

				if (Link_TX_Ack = '1') then
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_2;
				end if;

			when ST_FIS_REG_HOST_DEV_WORD_2 =>
				Link_TX_Valid							<= '1';

				Alias_LBA24								<= ATARegisters.LBlockAddress(31 downto 24);
				Alias_LBA32								<= ATARegisters.LBlockAddress(39 downto 32);
				Alias_LBA40								<= ATARegisters.LBlockAddress(47 downto 40);

				if (Link_TX_Ack = '1') then
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_3;
				end if;

			when ST_FIS_REG_HOST_DEV_WORD_3 =>
				Link_TX_Valid							<= '1';

				Alias_SecCount0						<= ATARegisters.SectorCount(7 downto 0);					-- Sector Count
				Alias_SecCount8						<= ATARegisters.SectorCount(15 downto 8);					-- Sector Count expanded
				Alias_ControlReg					<= ATARegisters.Control;													-- Control register

				if (Link_TX_Ack = '1') then
					NextState								<= ST_FIS_REG_HOST_DEV_WORD_4;
				end if;

			when ST_FIS_REG_HOST_DEV_WORD_4 =>
				Link_TX_Valid							<= '1';
				Link_TX_EOF								<= '1';

				if (Link_TX_Ack = '1') then
					NextState								<= ST_EVALUATE_FRAMESTATE;
				end if;

			when ST_DATA_0 =>
				-- Send Data FIS Header until Link_TX_Ack.
				Link_TX_Valid					<= '1';
				Link_TX_SOF						<= '1';

				Alias_FISType					<= to_slv(SATA_FISTYPE_DATA);

				if (Link_TX_Ack = '1') then
					NextState 					<= ST_DATA_N;
				end if;

			when ST_DATA_N =>
				Link_TX_Data							<= TX_Data;

				TX_Ack										<= Link_TX_Ack;
				TX_InsertEOP							<= Link_TX_InsertEOF;
				Link_TX_EOF								<= TX_EOP;
				Link_TX_Valid							<= TX_Valid;

				if (TX_Valid and Link_TX_Ack and TX_EOP) = '1' then
					-- Frame transmission complete.
					NextState 							<= ST_EVALUATE_FRAMESTATE;
				elsif (Link_TX_FS_Valid and Link_TX_FS_SyncEsc) = '1' then
					-- LinkLayer requests a SyncEsc.
					NextState 							<= ST_ABORT_FRAME;
				end if;

			when ST_ABORT_FRAME =>
				-- Abort frame now. Remaining data is discarded by TransportFSM later.
				Link_TX_EOF 							<= '1';
				Link_TX_Valid 						<= '1';

				if (Link_TX_Ack = '1') then
					-- accepted by LinkLayer
					NextState						<= ST_EVALUATE_FRAMESTATE;
				end if;

			when ST_EVALUATE_FRAMESTATE =>
				if (Link_TX_FS_Valid = '1') then
					if (Link_TX_FS_SendOK = '1') then
						Link_TX_FS_Ack				<= '1';
						NextState							<= ST_STATUS_SEND_OK;
					elsif (Link_TX_FS_SyncEsc = '1') then
						-- SyncEscape requested by device
						Link_TX_FS_Ack				<= '1';
						NextState							<= ST_STATUS_SYNC_ESC;
					else
						-- R_ERR signaled by other end
						Link_TX_FS_Ack				<= '1';
						NextState							<= ST_STATUS_SEND_ERROR;
					end if;
				end if;

			when ST_STATUS_SEND_OK =>
				Status								<= SATA_FISE_STATUS_SEND_OK;
				NextState							<= ST_IDLE;

			when ST_STATUS_SEND_ERROR =>
				Status								<= SATA_FISE_STATUS_SEND_ERROR;
				NextState							<= ST_IDLE;

			when ST_STATUS_SYNC_ESC =>
				Status								<= SATA_FISE_STATUS_SYNC_ESC;
				NextState							<= ST_IDLE;

		end case;
	end process;


	-- debug ports
	-- ===========================================================================
	genNoDebugPort: if not ENABLE_DEBUGPORT generate
		DebugPortOut <= C_SATADBG_TRANS_FISE_OUT_EMPTY;
	end generate genNoDebugPort;

	genDebug : if (ENABLE_DEBUGPORT = TRUE) generate
		function dbg_EncodeState(st : T_STATE) return std_logic_vector is
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

			function dbg_GenerateStatusEncodings return string is
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
