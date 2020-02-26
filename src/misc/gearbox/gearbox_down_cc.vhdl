-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	A downscaling gearbox module with a common clock (cc) interface.
--
-- Description:
-- -------------------------------------
-- This module provides a downscaling gearbox with a common clock (cc)
-- interface. It perfoems a 'word' to 'byte' splitting. The default order is
-- LITTLE_ENDIAN (starting at byte(0)). Input "In_Data" and output "Out_Data"
-- are of the same clock domain "Clock". Optional input and output registers
-- can be added by enabling (ADD_***PUT_REGISTERS = TRUE).
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library PoC;
use			PoC.math.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.components.all;


entity gearbox_down_cc is
	generic (
		DEBUG									: boolean 	:= false;
		INPUT_BITS						: positive	:= 32;
		OUTPUT_BITS						: positive	:= 8;
		META_BITS							: natural		:= 112;
		USE_UNCOMPLETE_FRAME	: boolean 	:= true;
		BIT_GROUP							:	natural 	:= 8;
		ADD_INPUT_REGISTERS		: boolean		:= false;
		ADD_OUTPUT_REGISTERS	: boolean		:= false
	);
	port (
		Clock				: in	std_logic;

		In_Sync			: in	std_logic;
		In_Valid		: in	std_logic;
		In_Next			: out	std_logic;
		In_Last			: in	std_logic_vector(ite(USE_UNCOMPLETE_FRAME, 1, 0) - 1 downto 0);
		In_Data			: in	std_logic_vector(INPUT_BITS - 1 downto 0);
		In_Meta			: in	std_logic_vector(META_BITS - 1 downto 0);
		In_BE				: in	std_logic_vector(ite(USE_UNCOMPLETE_FRAME, INPUT_BITS / BIT_GROUP, 0) - 1 downto 0);

		Out_Sync		: out	std_logic;
		Out_Valid		: out	std_logic;
		Out_Data		: out	std_logic_vector(OUTPUT_BITS - 1 downto 0);
		Out_BE			: out	std_logic_vector(ite(USE_UNCOMPLETE_FRAME, OUTPUT_BITS / BIT_GROUP, 0) - 1 downto 0);
		Out_Meta		: out	std_logic_vector(META_BITS - 1 downto 0);
		Out_First		: out	std_logic;
		Out_Last		: out	std_logic
	);
end entity;


architecture rtl of gearbox_down_cc is
	constant C_VERBOSE				: boolean			:= FALSE;		--POC_VERBOSE;
	
	constant DIVISOR							: positive		:= greatestCommonDivisor(INPUT_BITS, OUTPUT_BITS);
	constant BITS_PER_CHUNK		: positive		:= ite(USE_UNCOMPLETE_FRAME,DIVISOR + (DIVISOR / BIT_GROUP), DIVISOR);
	constant INPUT_CHUNKS			: positive		:= INPUT_BITS / DIVISOR;
	constant OUTPUT_CHUNKS		: positive		:= OUTPUT_BITS / DIVISOR;
	constant IN_DATA_BITS_INTERN 	: positive 		:= ite(USE_UNCOMPLETE_FRAME,INPUT_BITS + In_BE'length, INPUT_BITS);
	constant OUT_DATA_BITS_INTERN : positive 		:= ite(USE_UNCOMPLETE_FRAME,OUTPUT_BITS + Out_BE'length, OUTPUT_BITS);

	subtype T_CHUNK					is std_logic_vector(BITS_PER_CHUNK - 1 downto 0);
	type T_CHUNK_VECTOR			is array(natural range <>) of T_CHUNK;

	subtype T_MUX_INDEX			is integer range 0 to INPUT_CHUNKS - 1;
	type T_MUX_INPUT is record
		Index			: T_MUX_INDEX;
		UseBuffer	: boolean;
	end record;

	type T_MUX_INPUT_LIST		is array(natural range <>) of T_MUX_INPUT;
	type T_MUX_INPUT_STRUCT is record
		List		: T_MUX_INPUT_LIST(0 to OUTPUT_CHUNKS - 1);
		Reg_en	: std_logic;
		Nxt			: std_logic;
		First		: std_logic;
		Last		: std_logic;
	end record;
	type T_MUX_DESCRIPTIONS		is array(natural range <>) of T_MUX_INPUT_STRUCT;

	function genMuxDescription return T_MUX_DESCRIPTIONS is
		variable DESC				: T_MUX_DESCRIPTIONS(0 to INPUT_CHUNKS - 1);
		variable UseBuffer	: boolean;
		variable k					: T_MUX_INDEX;
	begin
		if C_VERBOSE then		report "genMuxDescription: IC=" & integer'image(INPUT_CHUNKS) severity NOTE;		end if;

		k := INPUT_CHUNKS - 1;
		for i in 0 to INPUT_CHUNKS - 1 loop
			if C_VERBOSE then		report "  i: " & integer'image(i) & "  List:" severity NOTE;		end if;
			UseBuffer					:= TRUE;
			for j in 0 to OUTPUT_CHUNKS - 1 loop
				k													:= (k + 1) mod INPUT_CHUNKS;
				UseBuffer									:= UseBuffer and (k /= 0);
				DESC(i).List(j).Index			:= k;
				DESC(i).List(j).UseBuffer	:= UseBuffer;

				if C_VERBOSE then		report "    j= " & integer'image(j) & "  k=" & INTEGER'image(DESC(i).List(j).Index) severity NOTE;		end if;
			end loop;
			DESC(i).Reg_en		:= to_sl(not UseBuffer);
			DESC(i).Nxt				:= to_sl(k + OUTPUT_CHUNKS >= INPUT_CHUNKS);
			DESC(i).First			:= to_sl(i = 0);
			DESC(i).Last			:= to_sl(i = INPUT_CHUNKS - 1);

			if C_VERBOSE then		report "    en=" & std_logic'image(DESC(i).Reg_en) & "  nxt=" & STD_LOGIC'image(DESC(i).Nxt) severity NOTE;		end if;
		end loop;
		return DESC;
	end function;

	constant MUX_INPUT_TRANSLATION		: T_MUX_DESCRIPTIONS		:= genMuxDescription;

	-- create vector-vector from vector (4 bit)
	function to_chunkv(slv : std_logic_vector) return T_CHUNK_VECTOR is
		constant CHUNKS		: positive		:= slv'length / BITS_PER_CHUNK;
		variable Result		: T_CHUNK_VECTOR(CHUNKS - 1 downto 0);
	begin
		if ((slv'length mod BITS_PER_CHUNK) /= 0) then	report "to_chunkv: width mismatch - slv'length is no multiple of BITS_PER_CHUNK (slv'length=" & INTEGER'image(slv'length) & "; BITS_PER_CHUNK=" & INTEGER'image(BITS_PER_CHUNK) & ")" severity FAILURE;	end if;

		for i in 0 to CHUNKS - 1 loop
			Result(i)	:= slv(slv'low + ((i + 1) * BITS_PER_CHUNK) - 1 downto slv'low + (i * BITS_PER_CHUNK));
		end loop;
		return Result;
	end function;

	-- convert vector-vector to flatten vector
	function to_slv(slvv : T_CHUNK_VECTOR) return std_logic_vector is
		variable slv			: std_logic_vector((slvv'length * BITS_PER_CHUNK) - 1 downto 0);
	begin
		for i in slvv'range loop
			slv(((i + 1) * BITS_PER_CHUNK) - 1 downto (i * BITS_PER_CHUNK))		:= slvv(i);
		end loop;
		return slv;
	end function;
	
	function get_cnt_val_last_bit (slv : std_logic_vector) return unsigned is
		-- variable index 	: integer (0 to slv'high)	:= 0;
		variable inc 		: integer 								:= DIVISOR / BIT_GROUP;
		-- variable temp	 	: unsigned (log2ceilnz(INPUT_CHUNKS) - 1 downto 0)	:= (others => '0');
	begin
		for i in 1 to INPUT_CHUNKS - 1 loop
			if slv(i * inc) = '0' then 
				return to_unsigned(i - 1,log2ceilnz(INPUT_CHUNKS));
			end if;
		end loop;
		return to_unsigned(INPUT_CHUNKS - 1,log2ceilnz(INPUT_CHUNKS));
	end function;

	signal In_Sync_d					: std_logic																					:= '0';
	signal In_Data_d					:	std_logic_vector(IN_DATA_BITS_INTERN - 1 downto 0):= (others => '0');
	signal In_Meta_d					:	std_logic_vector(META_BITS - 1 downto 0)					:= (others => '0');
	signal In_Valid_d					: std_logic																					:= '0';
	signal In_Last_d					: std_logic																					:= '0';
	signal In_Last_intern			: std_logic;
	-- signal In_Last_intern_d		: std_logic																					:= '0';
	
	signal Uncomplete					: std_logic																					:= '0';

	signal MuxSelect_rst			: std_logic;
	signal MuxSelect_rst_last	: std_logic;
	signal rst_last_flag			: std_logic;
	signal MuxSelect_rst_ld		: std_logic																					:= '0';
	signal MuxSelect_en				: std_logic;
	signal MuxSelect_us				: unsigned(log2ceilnz(INPUT_CHUNKS) - 1 downto 0)	:= (others => '0');
	signal MuxSelect_ov				: std_logic;

	signal Nxt								: std_logic;
	signal Nxt_last						: std_logic																					:= '0';
	signal AutoIncrement			: std_logic;

	signal GearBoxInput				: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto 0);
	signal GearBoxBuffer_en		: std_logic;
	signal GearBoxBuffer			: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto 1)				:= (others => (others => '0'));
	signal GearBoxOutput			: T_CHUNK_VECTOR(OUTPUT_CHUNKS - 1 downto 0);
	signal MetaBuffer					:	std_logic_vector(META_BITS - 1 downto 0)					:= (others => '0');

	signal SyncOut						: std_logic;
	signal ValidOut						: std_logic;
	signal DataOut						:	std_logic_vector(OUT_DATA_BITS_INTERN - 1 downto 0);
	signal MetaOut						:	std_logic_vector(META_BITS - 1 downto 0);
	signal FirstOut						: std_logic;
	signal LastOut						: std_logic;

	signal Out_Sync_d					: std_logic																					:= '0';
	signal Out_Valid_d				: std_logic																					:= '0';
	signal Out_Data_d					:	std_logic_vector(OUTPUT_BITS - 1 downto 0)				:= (others => '0');
	signal Out_BE_d						:	std_logic_vector(Out_BE'length - 1 downto 0)			:= (others => '0');
	signal Out_Meta_d					:	std_logic_vector(META_BITS - 1 downto 0)					:= (others => '0');
	signal Out_First_d				: std_logic																					:= '0';
	signal Out_Last_d					: std_logic																					:= '0';

begin
	assert (not C_VERBOSE)
		report "gearbox_down_cc:" & LF &
					 "  INPUT_BITS=" & integer'image(INPUT_BITS) &
					 "  OUTPUT_BITS=" & integer'image(OUTPUT_BITS) &
					 "  INPUT_CHUNKS=" & integer'image(INPUT_CHUNKS) &
					 "  OUTPUT_CHUNKS=" & integer'image(OUTPUT_CHUNKS) &
					 "  BITS_PER_CHUNK=" & integer'image(BITS_PER_CHUNK)
		severity NOTE;
	assert (INPUT_BITS > OUTPUT_BITS)	report "OUTPUT_BITS must be less than INPUT_BITS, otherwise it's no down-sizing gearbox." severity FAILURE;
	assert (not USE_UNCOMPLETE_FRAME) or (((INPUT_BITS mod BIT_GROUP) = 0) and ((OUTPUT_BITS mod BIT_GROUP) = 0)) report "If USE_UNCOMPLETE_FRAME is used, INPUT_BITS and OUTPUT_BITS must be multiple of BIT_GROUP!" severity failure;
	assert (not USE_UNCOMPLETE_FRAME) or ((INPUT_BITS mod OUTPUT_BITS) = 0) report "If USE_UNCOMPLETE_FRAME is used, OUTPUT_BITS must be multiple of INPUT_BITS!" severity failure;
	
	
	Input_gen0 : if USE_UNCOMPLETE_FRAME generate
		In_Sync_d					<= In_Sync;--	when registered(Clock, ADD_INPUT_REGISTERS);
		In_Last_intern 		<= In_Last_d and In_Valid_d;
		-- In_Last_intern_d	<= In_Last_intern when rising_edge(clock);
		-- Uncomplete;
		Input_gen0_reg0 : if ADD_INPUT_REGISTERS generate
			In_Valid_d	<= In_Valid				when rising_edge(Clock);
			In_Meta_d		<= In_Meta				when rising_edge(Clock);
			In_Last_d		<= In_Last(0)			when rising_edge(Clock);
		end generate;
		Input_gen0_reg1 : if not ADD_INPUT_REGISTERS generate
			In_Valid_d	<= In_Valid	;
			In_Meta_d		<= In_Meta	;
			In_Last_d		<= In_Last(0);
		end generate;
		
		Input_data_gen0 : for i in 0 to BIT_GROUP - 1 generate
			assert not DEBUG report "In_Data_d(" & integer'image(i) & ")<= In_Data(" & integer'image(i) & ")when registered ...;" severity note;
			Input_data_gen0_reg0 : if ADD_INPUT_REGISTERS generate
				In_Data_d(i)<= In_Data(i)	when rising_edge(Clock);
			end generate;
			Input_data_gen0_reg1 : if not ADD_INPUT_REGISTERS generate
				In_Data_d(i)<= In_Data(i);
			end generate;
		end generate;
		
		Input_data_gen1 : for i in BIT_GROUP to IN_DATA_BITS_INTERN - 1 generate
			constant BE_mod 	: natural := (i + 1) mod (BIT_GROUP + 1);
			constant BE_count : natural := (i + 1) / (BIT_GROUP + 1);
		begin
			assert not DEBUG report "-------------------------------------------------" severity note;
			assert not DEBUG report "i        ='" & integer'image(i) & "'" severity note;
			assert not DEBUG report "BE_mod    ='" & natural'image(BE_mod) & "'" severity note;
			assert not DEBUG report "BE_count ='" & natural'image(BE_count) & "'" severity note;
			Input_data_gen0_reg0 : if ADD_INPUT_REGISTERS generate
				In_Data_d(i)<= ite(BE_mod = 0, In_BE(BE_count - 1), In_Data(i - BE_count))	when rising_edge(Clock);
			end generate;
			Input_data_gen0_reg1 : if not ADD_INPUT_REGISTERS generate
				In_Data_d(i)<= ite(BE_mod = 0, In_BE(BE_count - 1), In_Data(i - BE_count));
			end generate;
		end generate;
	end generate;
	
	Input_gen1 : if not USE_UNCOMPLETE_FRAME generate
		In_Sync_d					<= In_Sync;--	when registered(Clock, ADD_INPUT_REGISTERS);
		Input_gen1_reg0 : if ADD_INPUT_REGISTERS generate
			In_Valid_d	<= In_Valid		when rising_edge(Clock);
			In_Meta_d		<= In_Meta		when rising_edge(Clock);
			In_Data_d		<= In_Data		when rising_edge(Clock);
			-- In_Last_d		<= In_Last(0);
		end generate;
		Input_gen1_reg1 : if not ADD_INPUT_REGISTERS generate
			In_Valid_d	<= In_Valid	;
			In_Meta_d		<= In_Meta	;
			In_Data_d		<= In_Data	;
			-- In_Last_d		<= In_Last(0);
		end generate;
	end generate;

	GearBoxInput			<= to_chunkv(In_Data_d(IN_DATA_BITS_INTERN - 1 downto 0));
	GearBoxBuffer_en	<= MUX_INPUT_TRANSLATION(to_index(MuxSelect_us, INPUT_CHUNKS)).Reg_en and In_Valid_d;

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (GearBoxBuffer_en = '1') then
				GearBoxBuffer		<= to_chunkv(In_Data_d(IN_DATA_BITS_INTERN - 1 downto BITS_PER_CHUNK));
				MetaBuffer			<= In_Meta_d;
			end if;
		end if;
	end process;

	MuxSelect_rst		<= In_Sync_d or MuxSelect_ov or MuxSelect_rst_last;
	MuxSelect_en		<= In_Valid_d or MuxSelect_ov or AutoIncrement;
	MuxSelect_us		<= upcounter_next(cnt => MuxSelect_us, rst => MuxSelect_rst, en => MuxSelect_en) when rising_edge(Clock);
	MuxSelect_ov		<= upcounter_equal(cnt => MuxSelect_us, value => (INPUT_CHUNKS - 1));

	Nxt							<= MUX_INPUT_TRANSLATION(to_index(MuxSelect_us, INPUT_CHUNKS)).Nxt or MuxSelect_rst_last or (Nxt_last and (In_Sync_d or not In_Valid_d));
	Nxt_last				<= Nxt when rising_edge(clock);
	AutoIncrement		<= '1' when Nxt = '0' and (MuxSelect_us /= 0 or (MuxSelect_us = 0 and In_Valid_d = '1')) else '0';
	
	rst_last_flag				<= '1' when MuxSelect_us = get_cnt_val_last_bit(In_BE) else '0';
	MuxSelect_rst_last	<= rst_last_flag and (MuxSelect_rst_ld or In_Last_intern);
	MuxSelect_rst_ld		<= In_Last_intern when rising_edge(clock) and (In_Last_intern = '1' or nxt = '1' or In_Sync_d = '1');

	In_Next					<= Nxt;

	-- generate gearbox multiplexer structure
	genMux : for j in 0 to OUTPUT_CHUNKS - 1 generate
		signal MuxInput		: T_CHUNK_VECTOR(INPUT_CHUNKS - 1 downto 0);
	begin
		genMuxInputs : for i in 0 to INPUT_CHUNKS - 1 generate
			assert (not C_VERBOSE)
				report "i= " & integer'image(i) & " " &
							 "j= " & integer'image(j) & " " &
							 "-> idx= " & integer'image(MUX_INPUT_TRANSLATION(i).List(j).Index) & " " &
							 "-> useBuffer= " & boolean'image(MUX_INPUT_TRANSLATION(i).List(j).UseBuffer) & " " &
							 "-> Nxt= " & std_logic'image(MUX_INPUT_TRANSLATION(i).Nxt)
				severity NOTE;

			connectToInput : if (MUX_INPUT_TRANSLATION(i).List(j).UseBuffer = FALSE) generate
				MuxInput(i)	<= GearBoxInput(MUX_INPUT_TRANSLATION(i).List(j).Index);
			end generate;
			connectToBuffer : if (MUX_INPUT_TRANSLATION(i).List(j).UseBuffer = TRUE) generate
				MuxInput(i)	<= GearBoxBuffer(MUX_INPUT_TRANSLATION(i).List(j).Index);
			end generate;
		end generate;

		GearBoxOutput(j)	<= MuxInput(to_index(MuxSelect_us, INPUT_CHUNKS));
	end generate;



	Output_gen1 : if not USE_UNCOMPLETE_FRAME generate
		SyncOut			<= MuxSelect_ov;
		ValidOut		<= In_Valid_d or MuxSelect_ov or AutoIncrement;
		DataOut			<= to_slv(GearBoxOutput);
		MetaOut			<= MetaBuffer;
		FirstOut		<= MUX_INPUT_TRANSLATION(to_index(MuxSelect_us, INPUT_CHUNKS)).First;
		LastOut			<= MUX_INPUT_TRANSLATION(to_index(MuxSelect_us, INPUT_CHUNKS)).Last;
	
		Output_gen1_reg0 : if ADD_OUTPUT_REGISTERS generate
			Out_Sync_d	<= SyncOut	when rising_edge(Clock);
			Out_Valid_d	<= ValidOut	when rising_edge(Clock);
			Out_Data_d	<= DataOut	when rising_edge(Clock);
			Out_Meta_d	<= MetaOut	when rising_edge(Clock);
			Out_First_d	<= FirstOut	when rising_edge(Clock);
			Out_Last_d	<= LastOut	when rising_edge(Clock);
		end generate;
		Output_gen1_reg1 : if not ADD_OUTPUT_REGISTERS generate
			Out_Sync_d	<= SyncOut	;
			Out_Valid_d	<= ValidOut	;
			Out_Data_d	<= DataOut	;
			Out_Meta_d	<= MetaOut	;
			Out_First_d	<= FirstOut	;
			Out_Last_d	<= LastOut	;
		end generate;
		
		Out_Sync		<= Out_Sync_d;
		Out_Valid		<= Out_Valid_d;
		Out_Data		<= Out_Data_d;
		Out_Meta		<= Out_Meta_d;
		Out_First		<= Out_First_d;
		Out_Last		<= Out_Last_d;
	end generate;
	
	Output_gen0 : if USE_UNCOMPLETE_FRAME generate
		SyncOut			<= MuxSelect_ov or MuxSelect_rst_last;
		ValidOut		<= (In_Valid_d or MuxSelect_ov or AutoIncrement) and not In_Sync_d;
		DataOut			<= to_slv(GearBoxOutput);
		MetaOut			<= MetaBuffer;
		FirstOut		<= MUX_INPUT_TRANSLATION(to_index(MuxSelect_us, INPUT_CHUNKS)).First;
		LastOut			<= MUX_INPUT_TRANSLATION(to_index(MuxSelect_us, INPUT_CHUNKS)).Last or MuxSelect_rst_last;
		
		Output_gen0_reg0 : if ADD_OUTPUT_REGISTERS generate
			Out_Sync_d	<= SyncOut	when rising_edge(Clock);
			Out_Valid_d	<= ValidOut	when rising_edge(Clock);
			Out_Meta_d	<= MetaOut	when rising_edge(Clock);
			Out_First_d	<= FirstOut	when rising_edge(Clock);
			Out_Last_d	<= LastOut	when rising_edge(Clock);
		end generate;
		Output_gen0_reg1 : if not ADD_OUTPUT_REGISTERS generate
			Out_Sync_d	<= SyncOut	;
			Out_Valid_d	<= ValidOut	;
			Out_Meta_d	<= MetaOut	;
			Out_First_d	<= FirstOut	;
			Out_Last_d	<= LastOut	;
		end generate;
		Output_data_gen0 : for i in 0 to BIT_GROUP - 1 generate
			Output_gen0_reg0 : if ADD_OUTPUT_REGISTERS generate
				Out_Data_d(i)		<= DataOut(i)	when rising_edge(Clock);
			end generate;
			Output_gen0_reg1 : if not ADD_OUTPUT_REGISTERS generate
				Out_Data_d(i)		<= DataOut(i);
			end generate;
		end generate;
		
		Output_data_gen1 : for i in BIT_GROUP to OUT_DATA_BITS_INTERN - 1 generate
--			constant t_mod 		: natural := (i + 1) mod 5;
			constant BE_count : natural := (i + 1) / (BIT_GROUP + 1);
		begin
			Output_data_gen_data : if ((i + 1) mod (BIT_GROUP + 1)) /= 0 generate
				Output_data_gen_data_reg1 : if not ADD_OUTPUT_REGISTERS generate
					Out_Data_d(i - BE_count)	<= DataOut(i)	;
				end generate;
				Output_data_gen_data_reg0 : if ADD_OUTPUT_REGISTERS generate
					Out_Data_d(i - BE_count)	<= DataOut(i)	when rising_edge(Clock);
				end generate;
			end generate;
			Output_data_gen_BE : if ((i + 1) mod (BIT_GROUP + 1)) = 0 generate
				Output_data_gen_BE_reg0 : if ADD_OUTPUT_REGISTERS generate
					Out_BE_d(BE_count - 1)		<= DataOut(i)	when rising_edge(Clock);
				end generate;
				Output_data_gen_BE_reg1 : if not ADD_OUTPUT_REGISTERS generate
					Out_BE_d(BE_count - 1)		<= DataOut(i)	;
				end generate;
			end generate;
		end generate;
		
		Out_Sync		<= Out_Sync_d;
		Out_Valid		<= Out_Valid_d;
		Out_Data		<= Out_Data_d;
		Out_BE			<= Out_BE_d;
		Out_Meta		<= Out_Meta_d;
		Out_First		<= Out_First_d;
		Out_Last		<= Out_Last_d;
	end generate;
	
end architecture;
