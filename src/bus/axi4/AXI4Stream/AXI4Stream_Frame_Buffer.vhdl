-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	A generic AXI4-Stream buffer (FIFO).
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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

use			work.utils.all;
use			work.vectors.all;
use			work.components.all;
use			work.axi4.all;


entity AXI4Stream_Frame_Buffer is
	generic (
		FRAMES						: positive								:= 2;
		MAX_PACKET_DEPTH  : positive								:= 8
	);
	port (
		Clock							: in	std_logic;
		Reset							: in	std_logic;
		-- IN Port
		In_M2S            : in  T_AXI4Stream_M2S;
		In_S2M            : out T_AXI4Stream_S2M;
    In_Save           : in  std_logic;
    In_Drop           : in  std_logic;
		-- OUT Port
		Out_M2S           : out T_AXI4Stream_M2S;
		Out_S2M           : in  T_AXI4Stream_S2M;
    Out_Commit        : in  std_logic;
    Out_Rollback      : in  std_logic
	);
end entity;


architecture rtl of AXI4Stream_Frame_Buffer is
  constant META_BITS					: natural						:= In_M2S.User'length;
	constant DATA_BITS					: positive					:= In_M2S.Data'length;
  
	type T_WRITER_STATE is (ST_IDLE, ST_FRAME);
	type T_READER_STATE is (ST_IDLE, ST_FRAME);

	signal Writer_State								: T_WRITER_STATE																			:= ST_IDLE;
	signal Writer_NextState						: T_WRITER_STATE;
	signal Reader_State								: T_READER_STATE																			:= ST_IDLE;
	signal Reader_NextState						: T_READER_STATE;

	constant Last_BIT									: natural																							:= DATA_BITS;

	signal DataFIFO_put								: std_logic;
	signal DataFIFO_DataIn						: std_logic_vector(DATA_BITS downto 0);
	signal DataFIFO_Full							: std_logic;
	signal MetaFIFO_Full							: std_logic;

	signal DataFIFO_got								: std_logic;
	signal DataFIFO_DataOut						: std_logic_vector(DataFIFO_DataIn'range);
	signal DataFIFO_Valid							: std_logic;

	signal FrameCommit								: std_logic;
  
  signal In_SOF                     : std_logic;
  signal started                    : std_logic := '0';
  
  signal Out_M2S_i                  : T_AXI4Stream_M2S(Data(DATA_BITS -1 downto 0), User(META_BITS -1 downto 0));
  
begin
  In_SOF      <= In_M2S.Valid and not started;
  started     <= ffrs(q => started, rst => ((In_M2S.Valid and In_M2S.Last) or Reset), set => (In_M2S.Valid)) when rising_edge(Clock);
  
	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Writer_State					<= ST_IDLE;
				Reader_State					<= ST_IDLE;
			else
				Writer_State					<= Writer_NextState;
				Reader_State					<= Reader_NextState;
			end if;
		end if;
	end process;

	process(Writer_State,
					In_M2S.Valid, In_M2S.Data, In_SOF, In_M2S.Last,
					DataFIFO_Full, MetaFIFO_Full)
	begin
		Writer_NextState									<= Writer_State;

		In_S2M.Ready											<= '0';

		DataFIFO_put											<= '0';
		DataFIFO_DataIn(In_M2S.Data'range)<= In_M2S.Data;
		DataFIFO_DataIn(Last_BIT)					<= In_M2S.Last;

		case Writer_State is
			when ST_IDLE =>
				In_S2M.Ready									<= not DataFIFO_Full and not MetaFIFO_Full;
				DataFIFO_put									<= In_M2S.Valid and not MetaFIFO_Full;

				if ((In_M2S.Valid and In_SOF and not In_M2S.Last and not MetaFIFO_Full) = '1') then

					Writer_NextState						<= ST_FRAME;
				end if;

			when ST_FRAME =>
				In_S2M.Ready									<= not DataFIFO_Full;
				DataFIFO_put									<= In_M2S.Valid;

				if ((In_M2S.Valid and In_M2S.Last and not DataFIFO_Full) = '1') then

					Writer_NextState						<= ST_IDLE;
				end if;
		end case;
	end process;


	process(Reader_State,
					Out_S2M.Ready,
					DataFIFO_Valid, DataFIFO_DataOut)
	begin
		Reader_NextState								<= Reader_State;

		Out_M2S_i.Valid									<= '0';
		Out_M2S_i.Data									<= DataFIFO_DataOut(Out_M2S_i.Data'range);
		Out_M2S_i.Last									<= DataFIFO_DataOut(Last_BIT);

		DataFIFO_got										<= '0';

		case Reader_State is
			when ST_IDLE =>
				Out_M2S_i.Valid							<= DataFIFO_Valid;
				DataFIFO_got								<= Out_S2M.Ready;

				if ((DataFIFO_Valid and not DataFIFO_DataOut(Last_BIT) and Out_S2M.Ready) = '1') then
					Reader_NextState					<= ST_FRAME;
				end if;

			when ST_FRAME =>
				Out_M2S_i.Valid										<= DataFIFO_Valid;
				DataFIFO_got								<= Out_S2M.Ready;

				if ((DataFIFO_Valid and DataFIFO_DataOut(Last_BIT) and Out_S2M.Ready) = '1') then
					Reader_NextState					<= ST_IDLE;
				end if;

		end case;
	end process;

  inst_cc_got_commit : entity work.fifo_cc_got_commit
  generic map (
    D_BITS							=> DATA_BITS + 1,								-- Data Width
    NUM_FRAMES          => FRAMES +1,
    MIN_DEPTH						=> (MAX_PACKET_DEPTH * FRAMES),	-- Minimum FIFO Depth
    DATA_REG						=> ((MAX_PACKET_DEPTH * FRAMES) <= 128),											-- Store Data Content in Registers
    STATE_REG						=> TRUE,												-- Registered Full/Empty Indicators
    OUTPUT_REG					=> FALSE,												-- Registered FIFO Output
    ESTATE_WR_BITS			=> 0,														-- Empty State Bits
    FSTATE_RD_BITS			=> 0														-- Full State Bits
  )
  port map (
    -- Global Reset and Clock
    clk									=> Clock,
    rst									=> Reset,

    -- Writing Interface
    put									=> DataFIFO_put,
    din									=> DataFIFO_DataIn,
    full								=> DataFIFO_Full,
    estate_wr						=> open,
    
    save                => In_Save,
    drop                => In_Drop,

    -- Reading Interface
    got									=> DataFIFO_got,
    dout								=> DataFIFO_DataOut,
    valid								=> DataFIFO_Valid,
    fstate_rd						=> open,
    
    commit              => Out_Commit,
    rollback            => Out_Rollback
  );

  -------------------------------------------------------------------

	FrameCommit		<= DataFIFO_Valid and DataFIFO_DataOut(Last_BIT) and Out_S2M.Ready;
    
  Out_M2S     <= Out_M2S_i;

	genMeta : if META_BITS > 0 generate
    
    MetaFIFO : entity work.fifo_cc_got_commit
    generic map (
      D_BITS							=> META_BITS,								-- Data Width
      NUM_FRAMES          => FRAMES +1,
      MIN_DEPTH						=> (META_BITS * FRAMES),	-- Minimum FIFO Depth
      DATA_REG						=> ((META_BITS * FRAMES) <= 128),											-- Store Data Content in Registers
      STATE_REG						=> TRUE,												-- Registered Full/Empty Indicators
      OUTPUT_REG					=> FALSE,												-- Registered FIFO Output
      ESTATE_WR_BITS			=> 0,														-- Empty State Bits
      FSTATE_RD_BITS			=> 0														-- Full State Bits
    )
    port map (
      -- Global Reset and Clock
      clk									=> Clock,
      rst									=> Reset,

      -- Writing Interface
      put									=> In_SOF,
      din									=> In_M2S.User,
      full								=> MetaFIFO_Full,
      estate_wr						=> open,
    
      save                => In_Save,
      drop                => In_Drop,
      

      -- Reading Interface
      got									=> Out_M2S_i.Valid and Out_M2S_i.Last and Out_S2M.Ready,
      dout								=> Out_M2S_i.User,
      valid								=> open,
      fstate_rd						=> open,
    
      commit              => Out_Commit,
      rollback            => Out_Rollback
    );

	end generate;

end architecture;
