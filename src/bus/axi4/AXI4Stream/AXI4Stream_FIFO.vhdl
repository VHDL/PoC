-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:  Stefan Unrein
--
-- Entity:   AXI4Stream_FIFO
--
-- Description:
-- -------------------------------------
-- A wrapper of fifo_cc_got for the AXI4-Stream interface. The size of the data-channels is
-- FRAMES * FRAMES_DEPTH, the size of the control-channels is FRAMES.
--
-- License:
-- =============================================================================
-- Copryright 2017-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.components.all;
use     work.mem.all;
use     work.axi4.all;
use     work.axi4stream.all;


entity AXI4Stream_FIFO is
	generic (
		FRAMES              : positive := 2;
		MAX_PACKET_DEPTH    : positive := 8;
		RAM_TYPE            : T_RAM_TYPE := RAM_TYPE_OPTIMIZED;
		METADATA_IS_DYNAMIC : boolean  := true
	);
	port (
		Clock             : in  std_logic;
		Reset             : in  std_logic;
		-- IN Port
		In_M2S            : in  T_AXI4Stream_M2S;
		In_S2M            : out T_AXI4Stream_S2M;
		-- OUT Port
		Out_M2S           : out T_AXI4Stream_M2S;
		Out_S2M           : in  T_AXI4Stream_S2M
	);
end entity;


architecture rtl of AXI4Stream_FIFO is
	constant USER_BITS        : natural        := In_M2S.User'length;
	constant DATA_BITS        : positive       := In_M2S.Data'length;
	constant KEEP_BITS        : positive       := In_M2S.Keep'length;
	constant DEST_BITS        : positive       := In_M2S.Dest'length;
	constant ID_BITS          : positive       := In_M2S.ID'length;

	constant INCLUDE_META     : boolean        := (METADATA_IS_DYNAMIC) and (USER_BITS > 0);

	type T_WRITER_STATE is (ST_IDLE, ST_FRAME);
	type T_READER_STATE is (ST_IDLE, ST_FRAME);

	signal Writer_State       : T_WRITER_STATE := ST_IDLE;
	signal Writer_NextState   : T_WRITER_STATE;
	signal Reader_State       : T_READER_STATE := ST_IDLE;
	signal Reader_NextState   : T_READER_STATE;

	constant Data_Pos         : natural  := 0;
	constant Keep_Pos         : natural  := 1;
	constant Last_Pos         : natural  := 2;
	constant User_Pos         : natural  := 3;

	constant Data_Bits_Vec  : T_NATVEC := (
		Keep_Pos       => KEEP_BITS,
		Data_Pos       => DATA_BITS,
		Last_Pos       => 1,
		User_Pos       => USER_BITS
	);

	signal DataFIFO_put       : std_logic;
	signal DataFIFO_DataIn    : std_logic_vector(isum(Data_Bits_Vec) -1 downto 0);
	signal DataFIFO_Full      : std_logic;
	signal MetaFIFO_put       : std_logic;
	signal MetaFIFO_Full      : std_logic;

	signal DataFIFO_got       : std_logic;
	signal DataFIFO_DataOut   : std_logic_vector(DataFIFO_DataIn'range);
	signal DataFIFO_Valid     : std_logic;

	signal Out_M2S_i          : Out_M2S'subtype;

begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Writer_State     <= ST_IDLE;
				Reader_State     <= ST_IDLE;
			else
				Writer_State     <= Writer_NextState;
				Reader_State     <= Reader_NextState;
			end if;
		end if;
	end process;

	process(all)
	begin
		Writer_NextState                     <= Writer_State;
		In_S2M.Ready                         <= '0';
		DataFIFO_put                         <= '0';
		MetaFIFO_put                         <= '0';

		DataFIFO_DataIn(high(Data_Bits_Vec, Data_Pos) downto low(Data_Bits_Vec, Data_Pos)) <= In_M2S.Data;
		DataFIFO_DataIn(high(Data_Bits_Vec, Last_Pos))                                     <= In_M2S.Last;
		DataFIFO_DataIn(high(Data_Bits_Vec, Keep_Pos) downto low(Data_Bits_Vec, Keep_Pos)) <= In_M2S.Keep;

		-- concatinate dynamic metadata with data
		if (METADATA_IS_DYNAMIC) and (USER_BITS > 0) then
			DataFIFO_DataIn(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos)) <= In_M2S.User;
		end if;

		case Writer_State is
			when ST_IDLE =>
				In_S2M.Ready  <= not DataFIFO_Full and not MetaFIFO_Full;
				DataFIFO_put  <= In_M2S.Valid and not MetaFIFO_Full;
				MetaFIFO_put  <= In_M2S.Valid and not DataFIFO_Full;

				if ((In_M2S.Valid and not In_M2S.Last and not MetaFIFO_Full and not DataFIFO_Full) = '1') then
					Writer_NextState  <= ST_FRAME;
				end if;

			when ST_FRAME =>
				In_S2M.Ready  <= not DataFIFO_Full;
				DataFIFO_put  <= In_M2S.Valid;

				if ((In_M2S.Valid and In_M2S.Last and not DataFIFO_Full) = '1') then
					Writer_NextState  <= ST_IDLE;
				end if;
		end case;
	end process;


	process(all)
	begin
		Reader_NextState <= Reader_State;

		Out_M2S_i.Valid  <= '0';

		Out_M2S_i.Data <= DataFIFO_DataOut(high(Data_Bits_Vec, Data_Pos) downto low(Data_Bits_Vec, Data_Pos));
		Out_M2S_i.Last <= DataFIFO_DataOut(high(Data_Bits_Vec, Last_Pos))                                    ;
		Out_M2S_i.Keep <= DataFIFO_DataOut(high(Data_Bits_Vec, Keep_Pos) downto low(Data_Bits_Vec, Keep_Pos));

		-- split dynamic metadata and data from fifo output
		if (METADATA_IS_DYNAMIC) and (USER_BITS > 0) then
			Out_M2S_i.User <= DataFIFO_DataOut(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos));
		end if;

		DataFIFO_got     <= '0';

		case Reader_State is
			when ST_IDLE =>
				Out_M2S_i.Valid <= DataFIFO_Valid;
				DataFIFO_got    <= Out_S2M.Ready;

				if ((DataFIFO_Valid and not DataFIFO_DataOut(high(Data_Bits_Vec, Last_Pos)) and Out_S2M.Ready) = '1') then
					Reader_NextState  <= ST_FRAME;
				end if;

			when ST_FRAME =>
				Out_M2S_i.Valid  <= DataFIFO_Valid;
				DataFIFO_got     <= Out_S2M.Ready;

				if ((DataFIFO_Valid and DataFIFO_DataOut(high(Data_Bits_Vec, Last_Pos)) and Out_S2M.Ready) = '1') then
					Reader_NextState  <= ST_IDLE;
				end if;

		end case;
	end process;

	----------------------------------------------------------------------------
	gen_DataFIFO : if FRAMES > 2 or MAX_PACKET_DEPTH > 2 generate
	begin

		inst_cc_got : entity work.fifo_cc_got
		generic map (
			D_BITS         => ite(METADATA_IS_DYNAMIC and (USER_BITS > 0), isum(Data_Bits_Vec), isum(Data_Bits_Vec(0 to Last_Pos))),  -- Data Width
			MIN_DEPTH      => (MAX_PACKET_DEPTH * FRAMES),  -- Minimum FIFO Depth
			RAM_TYPE       => RAM_TYPE,
			DATA_REG       => ((MAX_PACKET_DEPTH * FRAMES) <= 128), -- Store Data Content in Registers
			STATE_REG      => TRUE,                                 -- Registered Full/Empty Indicators
			OUTPUT_REG     => FALSE,                                -- Registered FIFO Output
			ESTATE_WR_BITS => 0,                                    -- Empty State Bits
			FSTATE_RD_BITS => 0                                     -- Full State Bits
		)
		port map (
			-- Global Reset and Clock
			clk            => Clock,
			rst            => Reset,

			-- Writing Interface
			put            => DataFIFO_put,
			din            => DataFIFO_DataIn(high(Data_Bits_Vec, ite(INCLUDE_META, User_Pos, Last_Pos)) downto low(Data_Bits_Vec, 0)),
			full           => DataFIFO_Full,
			estate_wr      => open,

			-- Reading Interface
			got            => DataFIFO_got,
			dout           => DataFIFO_DataOut(high(Data_Bits_Vec, ite(INCLUDE_META, User_Pos, Last_Pos)) downto low(Data_Bits_Vec, 0)),
			valid          => DataFIFO_Valid,
			fstate_rd      => open
		);
	else generate

		inst_stage : entity work.fifo_stage
		generic map(
			D_BITS          => ite(METADATA_IS_DYNAMIC and (USER_BITS > 0), isum(Data_Bits_Vec), isum(Data_Bits_Vec(0 to Last_Pos))),
			PIPELINE_STAGES => FRAMES
		)
		port map(
			-- Control
			clk     => Clock,
			rst     => Reset,

			-- Input
			put     => DataFIFO_put,
			di      => DataFIFO_DataIn(high(Data_Bits_Vec, ite(INCLUDE_META, User_Pos, Last_Pos)) downto low(Data_Bits_Vec, 0)),
			ful     => DataFIFO_Full,

			-- Output
			vld     => DataFIFO_Valid,
			do      => DataFIFO_DataOut(high(Data_Bits_Vec, ite(INCLUDE_META, User_Pos, Last_Pos)) downto low(Data_Bits_Vec, 0)),
			got     => DataFIFO_got
		);

	end generate;
	-------------------------------------------------------------------

	Out_M2S     <= Out_M2S_i;

	genMeta : if ((not METADATA_IS_DYNAMIC) and (USER_BITS > 0)) or (DEST_BITS > 0) or (ID_BITS > 0) generate
		constant Dest_Pos         : natural  := 0;
		constant ID_Pos           : natural  := 1;
		constant User_Pos         : natural  := 2;

		constant Data_Bits_Vec  : T_NATVEC := (
			Dest_Pos       => DEST_BITS,
			ID_Pos         => ID_BITS,
			User_Pos       => USER_BITS
		);
		signal Meta_In  : std_logic_vector(ite(METADATA_IS_DYNAMIC, DEST_BITS + ID_BITS, DEST_BITS + ID_BITS + USER_BITS) -1 downto 0);
		signal Meta_Out : Meta_In'subtype;
	begin
		Meta_In(high(Data_Bits_Vec, Dest_Pos) downto low(Data_Bits_Vec, Dest_Pos)) <= In_M2S.Dest;
		Meta_In(high(Data_Bits_Vec, ID_Pos  ) downto low(Data_Bits_Vec, ID_Pos  )) <= In_M2S.ID;
		Out_M2S_i.Dest             <= Meta_Out(high(Data_Bits_Vec, Dest_Pos) downto low(Data_Bits_Vec, Dest_Pos));
		Out_M2S_i.ID               <= Meta_Out(high(Data_Bits_Vec, ID_Pos  ) downto low(Data_Bits_Vec, ID_Pos  ));

		data_gen : if not METADATA_IS_DYNAMIC generate
			Meta_In(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos)) <= In_M2S.User;
			Out_M2S_i.User           <= Meta_Out(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos));
		end generate;

		MetaFIFO : entity work.fifo_cc_got
		generic map (
			D_BITS          => Meta_In'length,                               -- Data Width
			MIN_DEPTH       => imax(FRAMES, 16),                             -- Minimum FIFO Depth
			DATA_REG        => ((Meta_In'length * imax(FRAMES, 16)) <= 128), -- Store Data Content in Registers
			STATE_REG       => TRUE,                                         -- Registered Full/Empty Indicators
			OUTPUT_REG      => FALSE,                                        -- Registered FIFO Output
			ESTATE_WR_BITS  => 0,                                            -- Empty State Bits
			FSTATE_RD_BITS  => 0                                             -- Full State Bits
		)
		port map (
			-- Global Reset and Clock
			clk          => Clock,
			rst          => Reset,

			-- Writing Interface
			put          => MetaFIFO_put,
			din          => Meta_In,
			full         => MetaFIFO_Full,
			estate_wr    => open,

			-- Reading Interface
			got          => Out_M2S_i.Valid and Out_M2S_i.Last and Out_S2M.Ready,
			dout         => Meta_Out,
			valid        => open,
			fstate_rd    => open
		);

	else generate
		MetaFIFO_Full <= '0';
	end generate;

end architecture;
