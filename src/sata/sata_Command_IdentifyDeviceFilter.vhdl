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
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.strings.ALL;
USE			PoC.sata.ALL;


ENTITY sata_IdentifyDeviceFilter IS
	GENERIC (
		DEBUG												: BOOLEAN						:= FALSE
	);
	PORT (
		Clock												: IN	STD_LOGIC;
		Reset												: IN	STD_LOGIC;

		Enable											: IN	STD_LOGIC;
		Error												: OUT	STD_LOGIC;
		Finished										: OUT	STD_LOGIC;
		
		Valid												: IN	STD_LOGIC;
		Data												: IN	T_SLV_32;
		SOT													: IN	STD_LOGIC;
		EOT													: IN	STD_LOGIC;
		
		CRC_OK											: IN	STD_LOGIC;
		
		DriveInformation						: OUT	T_SATA_DRIVE_INFORMATION
	);
END;

ARCHITECTURE rtl OF sata_IdentifyDeviceFilter IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;

	TYPE T_STATE IS (
		ST_IDLE,
		ST_READ_WORDS,
		ST_COMPLETE,
		ST_FINISHED,
		ST_ERROR
	);
	
	FUNCTION to_01(slv : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
	BEGIN
	  return  to_stdlogicvector(to_bitvector(slv));
	END;
	
	FUNCTION calcSATAGenerationMin(SpeedBits : STD_LOGIC_VECTOR(6 DOWNTO 0)) RETURN T_SATA_GENERATION IS
	BEGIN
		IF (SpeedBits(0) = '1') THEN
			RETURN SATA_GENERATION_1;
		ELSIF (SpeedBits(1) = '1') THEN
			RETURN SATA_GENERATION_2;
		ELSIF (SpeedBits(2) = '1') THEN
			RETURN SATA_GENERATION_3;
		ELSE
			RETURN SATA_GENERATION_1;
		END IF;
	END;
	
	FUNCTION calcSATAGenerationMax(SpeedBits : STD_LOGIC_VECTOR(6 DOWNTO 0)) RETURN T_SATA_GENERATION IS
	BEGIN
		IF (SpeedBits(2) = '1') THEN
			RETURN SATA_GENERATION_3;
		ELSIF (SpeedBits(1) = '1') THEN
			RETURN SATA_GENERATION_2;
		ELSIF (SpeedBits(0) = '1') THEN
			RETURN SATA_GENERATION_1;
		ELSE
			RETURN SATA_GENERATION_1;
		END IF;
	END;
	
	CONSTANT WORDAC_BITS															: POSITIVE								:= log2ceilnz(128);			-- 512 Byte legacy block size => 128 * 32-bit words
	
	SIGNAL State																			: T_STATE									:= ST_IDLE;
	SIGNAL NextState																	: T_STATE;
	ATTRIBUTE FSM_ENCODING	OF State									: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));
	
	SIGNAL WordAC_inc																	: STD_LOGIC;
	SIGNAL WordAC_Load																: STD_LOGIC;
	SIGNAL WordAC_Address_us													: UNSIGNED(WORDAC_BITS - 1 DOWNTO 0);
	SIGNAL WordAC_Finished														: STD_LOGIC;
	
	SIGNAL ATAWord_117_IsValid_r											: STD_LOGIC								:= '0';
	
	SIGNAL ATACapability_SupportsDMA									: STD_LOGIC								:= '0';	
	SIGNAL ATACapability_SupportsLBA									: STD_LOGIC								:= '0';
	SIGNAL ATACapability_Supports48BitLBA							: STD_LOGIC								:= '0';
	SIGNAL ATACapability_SupportsSMART								: STD_LOGIC								:= '0';	
	SIGNAL ATACapability_SupportsFLUSH_CACHE					: STD_LOGIC								:= '0';
	SIGNAL ATACapability_SupportsFLUSH_CACHE_EXT			: STD_LOGIC								:= '0';
	
	SIGNAL SATACapability_SupportsNCQ									: STD_LOGIC								:= '0';
	SIGNAL SATAGenerationMin													: T_SATA_GENERATION				:= SATA_GENERATION_1;
	SIGNAL SATAGenerationMax													: T_SATA_GENERATION				:= SATA_GENERATION_1;
	
	SIGNAL DriveName																	: T_RAWSTRING(0 TO 39)		:= (OTHERS => x"00");
	SIGNAL DriveSize_LB																: UNSIGNED(63 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL PhysicalBlockSize_ldB											: UNSIGNED(7 DOWNTO 0)		:= (OTHERS => '0');
	SIGNAL LogicalBlockSize_ldB												: UNSIGNED(7 DOWNTO 0)		:= (OTHERS => '0');
	
	SIGNAL MultipleLogicalBlocksPerPhysicalBlock			: STD_LOGIC								:= '0';
	SIGNAL LogicalBlocksPerPhysicalBlock_us						: UNSIGNED(3 DOWNTO 0)		:= (OTHERS => '0');
	
	SIGNAL ATACapabilities_i													: T_SATA_ATA_CAPABILITY;
	SIGNAL SATACapabilities_i													: T_SATA_SATA_CAPABILITY;
	SIGNAL DriveInformation_i													: T_SATA_DRIVE_INFORMATION;
	
	SIGNAL Commit																			: STD_LOGIC;
	SIGNAL ChecksumOK																	: STD_LOGIC;
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
	
	PROCESS(State, Enable, Valid, SOT, EOT, WordAC_Finished, CRC_OK, ChecksumOK)
	BEGIN
		NextState										<= State;
		
		WordAC_inc									<= '0';
		WordAC_Load									<= '0';
		
		Commit											<= '0';
		Error												<= '0';
		Finished										<= '0';
		
		CASE State IS
			WHEN ST_IDLE =>
				IF (Enable = '1') THEN
					WordAC_Load						<= '1';
					
					NextState							<= ST_READ_WORDS;
				END IF;

			WHEN ST_READ_WORDS =>
				IF (Enable = '0') THEN
					NextState							<= ST_IDLE;
				ELSE
					IF (Valid = '1') THEN
						-- IF (SOT
						
						WordAC_inc					<= '1';
						
						IF (EOT = '1') THEN
							IF (WordAC_Finished = '1') THEN
								IF (CRC_OK = '1') THEN
									IF (ChecksumOK = '1') THEN
										Commit			<= '1';
										NextState		<= ST_FINISHED;
									ELSE
										NextState		<= ST_ERROR;
									END IF;
								ELSE
									NextState			<= ST_COMPLETE;
								END IF;
							ELSE																	-- only EOT => frame to short
								NextState				<= ST_ERROR;
							END IF;
						ELSE	-- EOT
							IF (WordAC_Finished = '1') THEN				-- only Finished => frame to long
								NextState				<= ST_ERROR;
							END IF;
						END IF;
					END IF;
				END IF;
			
			-- TODO: use ChecksumOK !!!!
			WHEN ST_COMPLETE =>
				IF (CRC_OK = '1') THEN
					IF (ChecksumOK = '1') THEN
						Commit							<= '1';
						NextState						<= ST_FINISHED;
					ELSE
						NextState						<= ST_ERROR;
					END IF;
				END IF; -- CRC_OK
			
			WHEN ST_FINISHED =>
				Finished								<= '1';
				NextState								<= ST_IDLE;
				
			WHEN ST_ERROR =>
				Error										<= '1';
				
		END CASE;
	END PROCESS;
	
	
	blkWordAC : BLOCK
		SIGNAL Counter_us				: UNSIGNED(WORDAC_BITS - 1 DOWNTO 0)					:= (OTHERS => '0');
	BEGIN
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (WordAC_Load = '1') THEN
					Counter_us				<= (OTHERS => '0');
				ELSIF (WordAC_inc = '1') THEN
					Counter_us			<= Counter_us + 1;
				END IF;
			END IF;
		END PROCESS;

		-- address output
		WordAC_Address_us	<= Counter_us;
		WordAC_Finished		<= to_sl(Counter_us = (Counter_us'range => '1'));
	END BLOCK;

	
	-- checksum calculation
	cs : BLOCK
		SIGNAL byte0_us			: UNSIGNED(7 DOWNTO 0);
		SIGNAL byte1_us			: UNSIGNED(15 DOWNTO 8);
		SIGNAL byte2_us			: UNSIGNED(23 DOWNTO 16);
		SIGNAL byte3_us			: UNSIGNED(31 DOWNTO 24);
		
		SIGNAL Checksum_nx1	: UNSIGNED(7 DOWNTO 0);
		SIGNAL Checksum_nx2	: UNSIGNED(7 DOWNTO 0);
		SIGNAL Checksum_us	: UNSIGNED(7 DOWNTO 0)					:= (OTHERS => '0');
	BEGIN
		byte0_us		<= unsigned(to_01(Data(byte0_us'range)));
		byte1_us		<= unsigned(to_01(Data(byte1_us'range)));
		byte2_us		<= unsigned(to_01(Data(byte2_us'range)));
		byte3_us		<= unsigned(to_01(Data(byte3_us'range)));
	
		Checksum_nx1	<= byte0_us + byte1_us + byte2_us + byte3_us;
		Checksum_nx2	<= byte0_us + byte1_us + byte2_us + byte3_us + Checksum_us;
	
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF (SOT = '1') THEN
					Checksum_us			<= Checksum_nx1;
				ELSE
					IF (Valid = '1') THEN
						Checksum_us		<= Checksum_nx2;
					END IF;
				END IF;
			END IF;
		END PROCESS;
		
		ChecksumOK						<= to_sl(Checksum_nx2 = 0);
	END BLOCK;
	
	
	-- ================================================================
	-- defines several registers, which are enabled by WordAC and Valid
	-- one ATA word has 16 Bits
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				ATAWord_117_IsValid_r							<= '0';
			ELSE
				CASE to_integer(WordAC_Address_us) IS
					-- ATA word 10 to 19 (20 bytes) - serial number (ASCII)
					--WHEN 5 =>
					
					-- ATA word 27 to 46 - model number (ASCII)
					WHEN 13 =>
						IF (Valid = '1') THEN
							DriveName(0)								<= Data(31 DOWNTO 24);
							DriveName(1)								<= Data(23 DOWNTO 16);
						END IF;
					
					WHEN 14 =>
						IF (Valid = '1') THEN
							DriveName(2)								<= Data(15 DOWNTO 8);
							DriveName(3)								<= Data(7 DOWNTO 0);
							DriveName(4)								<= Data(31 DOWNTO 24);
							DriveName(5)								<= Data(23 DOWNTO 16);
						END IF;
					
					WHEN 15 =>
						IF (Valid = '1') THEN
							DriveName(6)								<= Data(15 DOWNTO 8);
							DriveName(7)								<= Data(7 DOWNTO 0);
							DriveName(8)								<= Data(31 DOWNTO 24);
							DriveName(9)								<= Data(23 DOWNTO 16);
						END IF;
					
					WHEN 16 =>
						IF (Valid = '1') THEN
							DriveName(10)								<= Data(15 DOWNTO 8);
							DriveName(11)								<= Data(7 DOWNTO 0);
							DriveName(12)								<= Data(31 DOWNTO 24);
							DriveName(13)								<= Data(23 DOWNTO 16);
						END IF;
					
					WHEN 17 =>
						IF (Valid = '1') THEN
							DriveName(14)								<= Data(15 DOWNTO 8);
							DriveName(15)								<= Data(7 DOWNTO 0);
							DriveName(16)								<= Data(31 DOWNTO 24);
							DriveName(17)								<= Data(23 DOWNTO 16);
						END IF;

					WHEN 18 =>
						IF (Valid = '1') THEN
							DriveName(18)								<= Data(15 DOWNTO 8);
							DriveName(19)								<= Data(7 DOWNTO 0);
							DriveName(20)								<= Data(31 DOWNTO 24);
							DriveName(21)								<= Data(23 DOWNTO 16);
						END IF;
					
					WHEN 19 =>
						IF (Valid = '1') THEN
							DriveName(22)								<= Data(15 DOWNTO 8);
							DriveName(23)								<= Data(7 DOWNTO 0);
							DriveName(24)								<= Data(31 DOWNTO 24);
							DriveName(25)								<= Data(23 DOWNTO 16);
						END IF;
						
					WHEN 20 =>
						IF (Valid = '1') THEN
							DriveName(26)								<= Data(15 DOWNTO 8);
							DriveName(27)								<= Data(7 DOWNTO 0);
							DriveName(28)								<= Data(31 DOWNTO 24);
							DriveName(29)								<= Data(23 DOWNTO 16);
						END IF;

					WHEN 21 =>
						IF (Valid = '1') THEN
							DriveName(30)								<= Data(15 DOWNTO 8);
							DriveName(31)								<= Data(7 DOWNTO 0);
							DriveName(32)								<= Data(31 DOWNTO 24);
							DriveName(33)								<= Data(23 DOWNTO 16);
						END IF;
					
					WHEN 22 =>
						IF (Valid = '1') THEN
							DriveName(34)								<= Data(15 DOWNTO 8);
							DriveName(35)								<= Data(7 DOWNTO 0);
							DriveName(36)								<= Data(31 DOWNTO 24);
							DriveName(37)								<= Data(23 DOWNTO 16);
						END IF;
						
					WHEN 23 =>
						IF (Valid = '1') THEN
							DriveName(38)								<= Data(15 DOWNTO 8);
							DriveName(39)								<= Data(7 DOWNTO 0);
						END IF;
					
					-- ATA word 49 - Capabilities
					WHEN 24 =>
						IF (Valid = '1') THEN
							ATACapability_SupportsLBA		<= Data(25);
							ATACapability_SupportsDMA		<= Data(24);
						END IF;
					
					-- ATA word 60 to 61 - total number of user addressable logical sectors
					WHEN 30 =>
						IF (Valid = '1') THEN
							DriveSize_LB(31 DOWNTO 0)		<= unsigned(Data);
						END IF;
					
					-- ATA word 76 - Serial-ATA capabilities
					WHEN 38 =>
						IF (Valid = '1') THEN
							SATAGenerationMin						<= calcSATAGenerationMin(Data(7 DOWNTO 1));
							SATAGenerationMax						<= calcSATAGenerationMax(Data(7 DOWNTO 1));
							-- Data(3)	- reserved for future SATA signalig speeds
							-- Data(4)	- reserved for future SATA signalig speeds
							-- Data(5)	- reserved for future SATA signalig speeds
							-- Data(6)	- reserved for future SATA signalig speeds
							-- Data(7)	- reserved for future SATA signalig speeds
							SATACapability_SupportsNCQ	<= Data(8);
						END IF;
					
					-- ATA word 82 to 83 - Command set supported
					WHEN 41 =>
						IF (Valid = '1') THEN
							ATACapability_SupportsSMART							<= Data(0);
							--ATACapability_SupportsDMA_QUEUED				<= Data(16);			-- READ/WRITE DMA QUEUED
							ATACapability_Supports48BitLBA					<= Data(26);
							ATACapability_SupportsFLUSH_CACHE				<= Data(28);
							ATACapability_SupportsFLUSH_CACHE_EXT		<= Data(29);
						END IF;

					-- ATA word 86 - Command set/feature enabled/supported
					
					-- ATA word 88 - Ultra DMA modes
					
					-- ATA word 100 to 103 - total number of user addressable sectors for 48 Bit address feature set
					WHEN 50 =>
						IF (Valid = '1') THEN
							IF (ATACapability_Supports48BitLBA = '1') THEN
								DriveSize_LB(31 DOWNTO 0)							<= unsigned(Data);
							END IF;
						END IF;
					
					WHEN 51 =>
						IF (Valid = '1') THEN
							IF (ATACapability_Supports48BitLBA = '1') THEN
								DriveSize_LB(63 DOWNTO 32)						<= unsigned(Data);
							END IF;
						END IF;
					
					-- ATA word 106 - physical sector size / logical sector size
					WHEN 53 =>
						IF (Valid = '1') THEN
							IF (Data(15 DOWNTO 14) = "01") THEN		
								MultipleLogicalBlocksPerPhysicalBlock	<= Data(13);
								LogicalBlocksPerPhysicalBlock_us			<= unsigned(Data(3 DOWNTO 0));
							
								IF (Data(12) = '1') THEN
									ATAWord_117_IsValid_r								<= '1';
								ELSE
									ATAWord_117_IsValid_r								<= '0';
								END IF;
							END IF;
						END IF;
					
					-- ATA word 117 to 118 - words per logical sector
					WHEN 58 =>
						IF (Valid = '1') THEN
							IF (ATAWord_117_IsValid_r = '1') THEN
								FOR I IN 0 TO 15 LOOP
									IF (Data(I + 16) = '1') THEN
										LogicalBlockSize_ldB								<= to_unsigned(I + 1, LogicalBlockSize_ldB'length);			-- ShiftLeft(1) -> Data holds sector count in 16-Bit words
										EXIT;
									END IF;
									
									IF (I = 15) THEN
										LogicalBlockSize_ldB								<= to_unsigned(9, LogicalBlockSize_ldB'length);
										EXIT;
									END IF;
								END LOOP;
							ELSE
								LogicalBlockSize_ldB										<= to_unsigned(9, LogicalBlockSize_ldB'length);
							END IF;
						END IF;
					
					-- upper 16 Bit of words per logical sector are ignored
	--				WHEN 59 =>
	--					IF (Valid = '1') THEN
	--						
	--					END IF;
					
					-- calculation step
					WHEN 60 =>
						IF (Valid = '1') THEN
							IF (MultipleLogicalBlocksPerPhysicalBlock = '1') THEN
								PhysicalBlockSize_ldB									<= LogicalBlockSize_ldB - LogicalBlocksPerPhysicalBlock_us;
							END IF;
						END IF;
					
					-- ATA word 255 - integrity word
					WHEN OTHERS =>
						NULL;
						
				END CASE;
			END IF;
		END IF;
	END PROCESS;
	
	ATACapabilities_i.SupportsDMA								<= ATACapability_SupportsDMA;
	ATACapabilities_i.SupportsLBA								<= ATACapability_SupportsLBA;
	ATACapabilities_i.Supports48BitLBA					<= ATACapability_Supports48BitLBA;
	ATACapabilities_i.SupportsSMART							<= ATACapability_SupportsSMART;
	ATACapabilities_i.SupportsFLUSH_CACHE				<= ATACapability_SupportsFLUSH_CACHE;
	ATACapabilities_i.SupportsFLUSH_CACHE_EXT		<= ATACapability_SupportsFLUSH_CACHE_EXT;
	
	SATACapabilities_i.SupportsNCQ							<= SATACapability_SupportsNCQ;
	SATACapabilities_i.SATAGenerationMin				<= SATAGenerationMin;
	SATACapabilities_i.SATAGenerationMax				<= SATAGenerationMax;
		
	DriveInformation_i.DriveName								<= DriveName;
	DriveInformation_i.DriveSize_LB							<= DriveSize_LB;
	DriveInformation_i.PhysicalBlockSize_ldB		<= PhysicalBlockSize_ldB;
	DriveInformation_i.LogicalBlockSize_ldB			<= LogicalBlockSize_ldB;
	DriveInformation_i.ATACapabilityFlags				<= ATACapabilities_i;
	DriveInformation_i.SATACapabilityFlags			<= SATACapabilities_i;


	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				DriveInformation.DriveName																			<= (OTHERS => x"00");
				DriveInformation.DriveSize_LB																		<= (OTHERS => '0');
				DriveInformation.PhysicalBlockSize_ldB													<= (OTHERS => '0');
				DriveInformation.LogicalBlockSize_ldB														<= (OTHERS => '0');
				
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
			ELSE
				IF (Commit = '1') THEN
					DriveInformation.DriveName																		<= DriveInformation_i.DriveName;
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
				END IF;
			END IF;
		END IF;
	END PROCESS;

END;
