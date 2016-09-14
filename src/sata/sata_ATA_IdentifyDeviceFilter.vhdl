-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Patrick Lehmann
--
-- Entity:					IDENTIFY DEVICE Response Handler
--
-- Description:
-- -------------------------------------
-- Extracts drive configuration from repsonse to ATA IDENTIFY command. For
-- example, delivers information about drive size and capability flags.
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
use			PoC.components.all;
use			PoC.sata.all;


entity sata_ATA_IdentifyDeviceFilter is
	generic (
		DEBUG												: boolean						:= FALSE
	);
	port (
		Clock												: in	std_logic;
		Reset												: in	std_logic;

		Enable											: in	std_logic;
		Error												: out	std_logic;
		Finished										: out	std_logic;

		Valid												: in	std_logic;
		Data												: in	T_SLV_32;
		SOT													: in	std_logic;
		EOT													: in	std_logic;

		DriveInformation						: out	T_SATA_DRIVE_INFORMATION;

		IDF_Bus											: out	T_SATA_IDF_BUS
	);
end entity;


architecture rtl of sata_ATA_IdentifyDeviceFilter is
	attribute KEEP									: boolean;
	attribute FSM_ENCODING					: string;

	type T_STATE is (
		ST_IDLE,
		ST_READ_WORDS,
		ST_COMPLETE,
		ST_FINISHED,
		ST_ERROR
	);

	function calcSATAGenerationMin(SpeedBits : std_logic_vector(6 downto 0)) return T_SATA_GENERATION is
	begin
		if (SpeedBits(0) = '1') then			return SATA_GENERATION_1;
		elsif (SpeedBits(1) = '1') then		return SATA_GENERATION_2;
		elsif (SpeedBits(2) = '1') then		return SATA_GENERATION_3;
		else															return SATA_GENERATION_1;
		end if;
	end;

	function calcSATAGenerationMax(SpeedBits : std_logic_vector(6 downto 0)) return T_SATA_GENERATION is
	begin
		if (SpeedBits(2) = '1') then			return SATA_GENERATION_3;
		elsif (SpeedBits(1) = '1') then		return SATA_GENERATION_2;
		elsif (SpeedBits(0) = '1') then		return SATA_GENERATION_1;
		else															return SATA_GENERATION_1;
		end if;
	end;

	constant WORDAC_BITS															: positive								:= log2ceilnz(128);			-- 512 Byte legacy block size => 128 * 32-bit words

	signal State																			: T_STATE									:= ST_IDLE;
	signal NextState																	: T_STATE;
	attribute FSM_ENCODING	of State									: signal is getFSMEncoding_gray(DEBUG);

	signal WordAC_inc																	: std_logic;
	signal WordAC_rst																: std_logic;
	signal WordAC_Address_us													: unsigned(WORDAC_BITS - 1 downto 0);
	signal WordAC_Finished														: std_logic;

	signal ATAWord_117_IsValid_r											: std_logic								:= '0';

	signal ATACapability_SupportsDMA									: std_logic								:= '0';
	signal ATACapability_SupportsLBA									: std_logic								:= '0';
	signal ATACapability_Supports48BitLBA							: std_logic								:= '0';
	signal ATACapability_SupportsSMART								: std_logic								:= '0';
	signal ATACapability_SupportsFLUSH_CACHE					: std_logic								:= '0';
	signal ATACapability_SupportsFLUSH_CACHE_EXT			: std_logic								:= '0';

	signal SATACapability_SupportsNCQ									: std_logic								:= '0';
	signal SATAGenerationMin													: T_SATA_GENERATION				:= SATA_GENERATION_1;
	signal SATAGenerationMax													: T_SATA_GENERATION				:= SATA_GENERATION_1;

	signal DriveName																	: T_RAWSTRING(0 to 39)		:= (others => x"00");
	signal DriveSize_LB																: unsigned(63 downto 0)		:= (others => '0');
	signal PhysicalBlockSize_ldB											: unsigned(7 downto 0)		:= (others => '0');
	signal LogicalBlockSize_ldB												: unsigned(7 downto 0)		:= (others => '0');

	signal MultipleLogicalBlocksPerPhysicalBlock			: std_logic								:= '0';
	signal LogicalBlocksPerPhysicalBlock_us						: unsigned(3 downto 0)		:= (others => '0');

	signal ATACapabilities_i													: T_SATA_ATA_CAPABILITY;
	signal SATACapabilities_i													: T_SATA_SATA_CAPABILITY;
	signal DriveInformation_i													: T_SATA_DRIVE_INFORMATION;

	signal DriveName_en																: std_logic;
	signal DriveName_d																: T_SLV_16								:= (others => '0');
	signal IDF_Valid_r																: std_logic								:= '0';
	signal IDF_Address																: std_logic_vector(IDF_Bus.Address'range);
	signal IDF_WriteEnable														: std_logic;
	signal IDF_Data																		: T_SLV_32;

	signal Commit																			: std_logic;
	signal ChecksumOK																	: std_logic;

begin
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				State			<= ST_IDLE;
			else
				State			<= NextState;
			end if;
		end if;
	end process;

	process(State, Enable, Valid, SOT, EOT, WordAC_Finished, ChecksumOK)
	begin
		NextState										<= State;

		WordAC_inc									<= '0';
		WordAC_rst									<= '0';

		Commit											<= '0';
		Error												<= '0';
		Finished										<= '0';

		case State is
			when ST_IDLE =>
				if (Enable = '1') then
					WordAC_rst						<= '1';

					NextState							<= ST_READ_WORDS;
				end if;

			when ST_READ_WORDS =>
				if (Enable = '0') then
					NextState							<= ST_IDLE;
				else
					if (Valid = '1') then
						WordAC_inc					<= '1';

						if (EOT = '1') then
							if (WordAC_Finished = '1') then
								if (ChecksumOK = '1') then
									Commit				<= '1';
									NextState			<= ST_FINISHED;
								else
									NextState			<= ST_ERROR;
								end if;
							else																	-- only EOT => frame to short
								NextState				<= ST_ERROR;
							end if;
						else	-- EOT
							if (WordAC_Finished = '1') then				-- only Finished => frame to long
								NextState				<= ST_ERROR;
							end if;
						end if;
					end if;
				end if;

			when ST_COMPLETE =>
				if (ChecksumOK = '1') then
					Commit								<= '1';
					NextState							<= ST_FINISHED;
				else
					NextState							<= ST_ERROR;
				end if;

			when ST_FINISHED =>
				Finished								<= '1';
				NextState								<= ST_IDLE;

			when ST_ERROR =>
				Error										<= '1';

		end case;
	end process;

	blkWordAC : block
		signal Counter_us	: unsigned(WORDAC_BITS - 1 downto 0)					:= (others => '0');
	begin
		Counter_us				<= upcounter_next(cnt => Counter_us, rst => WordAC_rst, en => WordAC_inc) when rising_edge(Clock);
		WordAC_Address_us	<= Counter_us;
		WordAC_Finished		<= upcounter_equal(cnt => Counter_us, value => (2**WORDAC_BITS - 1));
	end block;


	-- checksum calculation
	cs : block
		signal byte0_us			: unsigned(7 downto 0);
		signal byte1_us			: unsigned(15 downto 8);
		signal byte2_us			: unsigned(23 downto 16);
		signal byte3_us			: unsigned(31 downto 24);

		signal Checksum_nx1	: unsigned(7 downto 0);
		signal Checksum_nx2	: unsigned(7 downto 0);
		signal Checksum_us	: unsigned(7 downto 0)					:= (others => '0');
	begin
		byte0_us		<= unsigned(Data(byte0_us'range));
		byte1_us		<= unsigned(Data(byte1_us'range));
		byte2_us		<= unsigned(Data(byte2_us'range));
		byte3_us		<= unsigned(Data(byte3_us'range));

		Checksum_nx1	<= byte0_us + byte1_us + byte2_us + byte3_us;
		Checksum_nx2	<= byte0_us + byte1_us + byte2_us + byte3_us + Checksum_us;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if (SOT = '1') then
					Checksum_us		<= Checksum_nx1;
				elsif (Valid = '1') then
					Checksum_us		<= Checksum_nx2;
				end if;
			end if;
		end process;

		ChecksumOK						<= to_sl(Checksum_nx2 = 0);
	end block;


	-- ================================================================
	-- defines several registers, which are enabled by WordAC and Valid
	-- one ATA word has 16 Bits
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				ATAWord_117_IsValid_r							<= '0';
			elsif (Valid = '1') then
				case to_integer(WordAC_Address_us) is
					-- ATA word 10 to 19 (20 bytes)	- serial number (ASCII)
					-- ATA word 27 to 46 (40 bytes)	- model number (ASCII)

					-- ATA word 49 - Capabilities
					when 24 =>
						ATACapability_SupportsLBA		<= Data(25);
						ATACapability_SupportsDMA		<= Data(24);

					-- ATA word 60 to 61 - total number of user addressable logical sectors
					when 30 =>
						DriveSize_LB(31 downto 0)		<= unsigned(Data);

					-- ATA word 76 - Serial-ATA capabilities
					when 38 =>
						SATAGenerationMin						<= calcSATAGenerationMin(Data(7 downto 1));
						SATAGenerationMax						<= calcSATAGenerationMax(Data(7 downto 1));
						-- Data(3)	- reserved for future SATA signalig speeds
						-- Data(4)	- reserved for future SATA signalig speeds
						-- Data(5)	- reserved for future SATA signalig speeds
						-- Data(6)	- reserved for future SATA signalig speeds
						-- Data(7)	- reserved for future SATA signalig speeds
						SATACapability_SupportsNCQ	<= Data(8);

					-- ATA word 82 to 83 - Command set supported
					when 41 =>
						ATACapability_SupportsSMART							<= Data(0);
						--ATACapability_SupportsDMA_QUEUED				<= Data(16);			-- READ/WRITE DMA QUEUED
						ATACapability_Supports48BitLBA					<= Data(26);
						ATACapability_SupportsFLUSH_CACHE				<= Data(28);
						ATACapability_SupportsFLUSH_CACHE_EXT		<= Data(29);

					-- ATA word 86 - Command set/feature enabled/supported
					-- ATA word 88 - Ultra DMA modes

					-- ATA word 100 to 103 - total number of user addressable sectors for 48 Bit address feature set
					when 50 =>
						if (ATACapability_Supports48BitLBA = '1') then
							DriveSize_LB(31 downto 0)							<= unsigned(Data);
						end if;

					when 51 =>
						if (ATACapability_Supports48BitLBA = '1') then
							DriveSize_LB(63 downto 32)						<= unsigned(Data);
						end if;

					-- ATA word 106 - physical sector size / logical sector size
					when 53 =>
						if (Data(15 downto 14) = "01") then
							MultipleLogicalBlocksPerPhysicalBlock	<= Data(13);
							LogicalBlocksPerPhysicalBlock_us			<= unsigned(Data(3 downto 0));

							if (Data(12) = '1') then
								ATAWord_117_IsValid_r								<= '1';
							else
								ATAWord_117_IsValid_r								<= '0';
							end if;
						end if;

					-- ATA word 117 to 118 - words per logical sector
					when 58 =>
						if (ATAWord_117_IsValid_r = '1') then
							for i in 0 to 15 loop
								if (Data(i + 16) = '1') then
									LogicalBlockSize_ldB							<= to_unsigned(i + 1, LogicalBlockSize_ldB'length);			-- ShiftLeft(1) -> Data holds sector count in 16-Bit words
									exit;
								end if;

								if (i = 15) then
									LogicalBlockSize_ldB							<= to_unsigned(9, LogicalBlockSize_ldB'length);
									exit;
								end if;
							end loop;
						else
							LogicalBlockSize_ldB									<= to_unsigned(9, LogicalBlockSize_ldB'length);
						end if;

					-- upper 16 Bit of words per logical sector are ignored

					-- calculation step
					when 60 =>
						if (MultipleLogicalBlocksPerPhysicalBlock = '1') then
							PhysicalBlockSize_ldB									<= LogicalBlockSize_ldB - LogicalBlocksPerPhysicalBlock_us;
						end if;

					-- ATA word 255 - integrity word
					when others =>
						null;

				end case;
			end if;
		end if;
	end process;


	ATACapabilities_i.SupportsDMA								<= ATACapability_SupportsDMA;
	ATACapabilities_i.SupportsLBA								<= ATACapability_SupportsLBA;
	ATACapabilities_i.Supports48BitLBA					<= ATACapability_Supports48BitLBA;
	ATACapabilities_i.SupportsSMART							<= ATACapability_SupportsSMART;
	ATACapabilities_i.SupportsFLUSH_CACHE				<= ATACapability_SupportsFLUSH_CACHE;
	ATACapabilities_i.SupportsFLUSH_CACHE_EXT		<= ATACapability_SupportsFLUSH_CACHE_EXT;

	SATACapabilities_i.SupportsNCQ							<= SATACapability_SupportsNCQ;
	SATACapabilities_i.SATAGenerationMin				<= SATAGenerationMin;
	SATACapabilities_i.SATAGenerationMax				<= SATAGenerationMax;

	DriveInformation_i.DriveSize_LB							<= DriveSize_LB;
	DriveInformation_i.PhysicalBlockSize_ldB		<= PhysicalBlockSize_ldB;
	DriveInformation_i.LogicalBlockSize_ldB			<= LogicalBlockSize_ldB;
	DriveInformation_i.ATACapabilityFlags				<= ATACapabilities_i;
	DriveInformation_i.SATACapabilityFlags			<= SATACapabilities_i;

	IDF_Valid_r		<= ffrs(q => IDF_Valid_r, rst => Reset, set => Commit) when rising_edge(Clock);

	IDF_Bus.Clock								<= Clock;
	IDF_Bus.Address							<= std_logic_vector(WordAC_Address_us);
	IDF_Bus.WriteEnable					<= Valid;
	IDF_Bus.Data								<= Data;
	IDF_Bus.Valid								<= IDF_Valid_r;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				DriveInformation.DriveSize_LB																		<= (others => '0');
				DriveInformation.PhysicalBlockSize_ldB													<= (others => '0');
				DriveInformation.LogicalBlockSize_ldB														<= (others => '0');

				DriveInformation.ATACapabilityFlags.SupportsDMA									<= '0';
				DriveInformation.ATACapabilityFlags.SupportsLBA									<= '0';
				DriveInformation.ATACapabilityFlags.Supports48BitLBA						<= '0';
				DriveInformation.ATACapabilityFlags.SupportsSMART								<= '0';
				DriveInformation.ATACapabilityFlags.SupportsFLUSH_CACHE					<= '0';
				DriveInformation.ATACapabilityFlags.SupportsFLUSH_CACHE_EXT			<= '0';

				DriveInformation.SATACapabilityFlags.SupportsNCQ								<= '0';
				DriveInformation.SATACapabilityFlags.SATAGenerationMin					<= SATA_GENERATION_1;
				DriveInformation.SATACapabilityFlags.SATAGenerationMax					<= SATA_GENERATION_1;

				DriveInformation.Valid																					<= '0';
			else
				if (Commit = '1') then
					DriveInformation.DriveSize_LB																	<= DriveInformation_i.DriveSize_LB;
					DriveInformation.PhysicalBlockSize_ldB												<= DriveInformation_i.PhysicalBlockSize_ldB;
					DriveInformation.LogicalBlockSize_ldB													<= DriveInformation_i.LogicalBlockSize_ldB;

					DriveInformation.ATACapabilityFlags.SupportsDMA								<= DriveInformation_i.ATACapabilityFlags.SupportsDMA;
					DriveInformation.ATACapabilityFlags.SupportsLBA								<= DriveInformation_i.ATACapabilityFlags.SupportsLBA;
					DriveInformation.ATACapabilityFlags.Supports48BitLBA					<= DriveInformation_i.ATACapabilityFlags.Supports48BitLBA;
					DriveInformation.ATACapabilityFlags.SupportsSMART							<= DriveInformation_i.ATACapabilityFlags.SupportsSMART;
					DriveInformation.ATACapabilityFlags.SupportsFLUSH_CACHE				<= DriveInformation_i.ATACapabilityFlags.SupportsFLUSH_CACHE;
					DriveInformation.ATACapabilityFlags.SupportsFLUSH_CACHE_EXT		<= DriveInformation_i.ATACapabilityFlags.SupportsFLUSH_CACHE_EXT;

					DriveInformation.SATACapabilityFlags.SupportsNCQ							<= DriveInformation_i.SATACapabilityFlags.SupportsNCQ;
					DriveInformation.SATACapabilityFlags.SATAGenerationMin				<= DriveInformation_i.SATACapabilityFlags.SATAGenerationMin;
					DriveInformation.SATACapabilityFlags.SATAGenerationMax				<= DriveInformation_i.SATACapabilityFlags.SATAGenerationMax;

					DriveInformation.Valid																				<= '1';
				end if;
			end if;
		end if;
	end process;

end;
