-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein
--
-- Entity:          AXI4Stream_FIFO_cdc
--
-- Description:
-- -------------------------------------
-- A wrapper of fifo_ic_got for the AXI4-Stream interface. It implements a
-- CDC-FIFO. The size of the data-channels is FRAMES * FRAMES_DEPTH, the size
-- of the control-channels is FRAMES.
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.components.all;
use     work.axi4Stream.all;


entity AXI4Stream_FIFO_cdc is
	generic (
		FRAMES               : positive := 2;
		MAX_PACKET_DEPTH     : positive := 8;
		USER_IS_DYNAMIC     : boolean  := true;
		NO_META_FIFO        : boolean  := false
	);
	port (
		-- IN Port
		In_Clock             : in  std_logic;
		In_Reset             : in  std_logic;
		In_M2S               : in  T_AXI4Stream_M2S;
		In_S2M               : out T_AXI4Stream_S2M;
		-- OUT Port
		Out_Clock            : in  std_logic;
		Out_Reset            : in  std_logic;
		Out_M2S              : out T_AXI4Stream_M2S;
		Out_S2M              : in  T_AXI4Stream_S2M
	);
end entity;


architecture rtl of AXI4Stream_FIFO_cdc is
	constant DATA_BITS        : positive := In_M2S.Data'length;
	constant LAST_BITS        : positive := 1; -- Last is always single bit
	constant KEEP_BITS        : positive := In_M2S.Keep'length;
	constant USER_BITS        : natural  := In_M2S.User'length;
	constant DEST_BITS        : natural  := In_M2S.Dest'length;
	constant ID_BITS          : positive := In_M2S.ID'length;

	constant DATA_POS         : natural  := 0;
	constant LAST_POS         : natural  := 1;
	constant KEEP_POS         : natural  := 2;
	constant USER_POS         : natural  := 3;

	constant FIFO_BIT_VEC     : T_POSVEC := (
		DATA_POS => DATA_BITS,
		LAST_POS => LAST_BITS,
		KEEP_POS => KEEP_BITS,
		USER_POS => USER_BITS
	);

	type T_WRITER_STATE is (ST_IDLE, ST_FRAME);

	signal Writer_State       : T_WRITER_STATE  := ST_IDLE;
	signal Writer_NextState   : T_WRITER_STATE;

	signal DataFIFO_put       : std_logic;
	signal DataFIFO_DataIn    : std_logic_vector(isum(FIFO_BIT_VEC) - 1 downto 0);
	signal DataFIFO_Full      : std_logic;
	signal MetaFIFO_put       : std_logic;
	signal MetaFIFO_Full      : std_logic;

	signal DataFIFO_got       : std_logic;
	signal DataFIFO_DataOut   : std_logic_vector(DataFIFO_DataIn'range);
	signal DataFIFO_Valid     : std_logic;

	signal Out_M2S_i          : Out_M2S'subtype;

begin

	process(In_Clock)
	begin
		if rising_edge(In_Clock) then
			if (In_Reset = '1') then
				Writer_State          <= ST_IDLE;
			else
				Writer_State          <= Writer_NextState;
			end if;
		end if;
	end process;

	Write_proc : process(all)
	begin
		Writer_NextState                  <= Writer_State;

		In_S2M.Ready                      <= '0';

		DataFIFO_put                      <= '0';
		MetaFIFO_put                      <= '0';

		DataFIFO_DataIn(high(FIFO_BIT_VEC, DATA_POS) downto low(FIFO_BIT_VEC, DATA_POS)) <= In_M2S.Data;
		DataFIFO_DataIn(                                    low(FIFO_BIT_VEC, LAST_POS)) <= In_M2S.Last;
		DataFIFO_DataIn(high(FIFO_BIT_VEC, KEEP_POS) downto low(FIFO_BIT_VEC, KEEP_POS)) <= In_M2S.Keep;

		-- concatinate dynamic metadata with data
		if (USER_IS_DYNAMIC) and (USER_BITS > 0) then
			DataFIFO_DataIn(high(FIFO_BIT_VEC, USER_POS) downto low(FIFO_BIT_VEC, USER_POS)) <= In_M2S.User;
		end if;

		case Writer_State is
			when ST_IDLE =>
				In_S2M.Ready  <= not DataFIFO_Full and not MetaFIFO_Full;
				DataFIFO_put  <= In_M2S.Valid      and not MetaFIFO_Full;
				MetaFIFO_put  <= In_M2S.Valid      and not DataFIFO_Full;

				if ((In_M2S.Valid and not In_M2S.Last and not MetaFIFO_Full and not DataFIFO_Full) = '1') then
					Writer_NextState            <= ST_FRAME;
				end if;

			when ST_FRAME =>
				In_S2M.Ready                  <= not DataFIFO_Full;
				DataFIFO_put                  <= In_M2S.Valid;

				if ((In_M2S.Valid and In_M2S.Last and not DataFIFO_Full) = '1') then

					Writer_NextState            <= ST_IDLE;
				end if;
		end case;
	end process;


	Read_proc : process(all)
	begin
		Out_M2S_i.Valid  <= DataFIFO_Valid;
		DataFIFO_got     <= Out_S2M.Ready;

		Out_M2S_i.Data   <= DataFIFO_DataOut(high(FIFO_BIT_VEC, DATA_POS) downto low(FIFO_BIT_VEC, DATA_POS));
		Out_M2S_i.Last   <= DataFIFO_DataOut(                                    low(FIFO_BIT_VEC, LAST_POS));
		Out_M2S_i.Keep   <= DataFIFO_DataOut(high(FIFO_BIT_VEC, KEEP_POS) downto low(FIFO_BIT_VEC, KEEP_POS));

		-- split dynamic metadata and data from fifo output
		if (USER_IS_DYNAMIC) and (USER_BITS > 0) then
			Out_M2S_i.User   <= DataFIFO_DataOut(high(FIFO_BIT_VEC, USER_POS) downto low(FIFO_BIT_VEC, USER_POS));
		end if;
	end process;

	DataFIFO : entity work.fifo_ic_got
		generic map (
			D_BITS              => ite(USER_IS_DYNAMIC, isum(FIFO_BIT_VEC), isum(FIFO_BIT_VEC) - USER_BITS),                   -- Data Width
			MIN_DEPTH           => (MAX_PACKET_DEPTH * FRAMES),          -- Minimum FIFO Depth
			DATA_REG            => ((MAX_PACKET_DEPTH * FRAMES) <= 128), -- Store Data Content in Registers
			-- STATE_REG            => TRUE,                                 -- Registered Full/Empty Indicators
			OUTPUT_REG          => FALSE,                                -- Registered FIFO Output
			ESTATE_WR_BITS      => 0,                                    -- Empty State Bits
			FSTATE_RD_BITS      => 0                                     -- Full State Bits
		)
		port map (
			-- Writing Interface
			clk_wr              => In_Clock,
			rst_wr              => In_Reset,
			put                 => DataFIFO_put,
			din                 => DataFIFO_DataIn(ite(USER_IS_DYNAMIC, isum(FIFO_BIT_VEC), isum(FIFO_BIT_VEC) - USER_BITS) -1 downto 0),
			full                => DataFIFO_Full,
			estate_wr           => open,

			-- Reading Interface
			clk_rd              => Out_Clock,
			rst_rd              => Out_Reset,
			got                 => DataFIFO_got,
			dout                => DataFIFO_DataOut(ite(USER_IS_DYNAMIC, isum(FIFO_BIT_VEC), isum(FIFO_BIT_VEC) - USER_BITS) -1 downto 0),
			valid               => DataFIFO_Valid,
			fstate_rd           => open
		);

	Out_M2S     <= Out_M2S_i;

	genMeta : if ((not USER_IS_DYNAMIC) and (USER_BITS > 0)) or (DEST_BITS > 0) or (ID_BITS > 0) generate
		constant Dest_Pos         : natural  := 0;
		constant ID_Pos           : natural  := 1;
		constant User_Pos         : natural  := 2;

		constant Data_Bits_Vec  : T_NATVEC := (
			Dest_Pos       => DEST_BITS,
			ID_Pos         => ID_BITS,
			User_Pos       => USER_BITS
		);
		signal Meta_In  : std_logic_vector(ite(USER_IS_DYNAMIC, DEST_BITS + ID_BITS, DEST_BITS + ID_BITS + USER_BITS) -1 downto 0);
		signal Meta_Out : Meta_In'subtype;
	begin
		Meta_In(high(Data_Bits_Vec, Dest_Pos) downto low(Data_Bits_Vec, Dest_Pos)) <= In_M2S.Dest;
		Meta_In(high(Data_Bits_Vec, ID_Pos  ) downto low(Data_Bits_Vec, ID_Pos  )) <= In_M2S.ID;
		Out_M2S_i.Dest             <= Meta_Out(high(Data_Bits_Vec, Dest_Pos) downto low(Data_Bits_Vec, Dest_Pos));
		Out_M2S_i.ID               <= Meta_Out(high(Data_Bits_Vec, ID_Pos  ) downto low(Data_Bits_Vec, ID_Pos  ));

		data_gen : if not USER_IS_DYNAMIC generate
			Meta_In(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos)) <= In_M2S.User;
			Out_M2S_i.User           <= Meta_Out(high(Data_Bits_Vec, User_Pos) downto low(Data_Bits_Vec, User_Pos));
		end generate;

		NO_META_FIFO_gen : if not NO_META_FIFO generate
			MetaFIFO : entity work.fifo_ic_got
			generic map (
				D_BITS              => Meta_In'length,                     -- Data Width
				MIN_DEPTH           => imax(FRAMES, 16),          -- Minimum FIFO Depth
				DATA_REG            => ((Meta_In'length * imax(FRAMES, 16)) <= 128), -- Store Data Content in Registers
				-- STATE_REG            => TRUE,                          -- Registered Full/Empty Indicators
				OUTPUT_REG          => FALSE,                         -- Registered FIFO Output
				ESTATE_WR_BITS      => 0,                             -- Empty State Bits
				FSTATE_RD_BITS      => 0                              -- Full State Bits
			)
			port map (
				-- Writing Interface
				clk_wr              => In_Clock,
				rst_wr              => In_Reset,
				put                 => MetaFIFO_put,
				din                 => Meta_In,
				full                => MetaFIFO_Full,
				estate_wr           => open,

				-- Reading Interface
				clk_rd              => Out_Clock,
				rst_rd              => Out_Reset,
				got                 => Out_M2S_i.Valid and Out_M2S_i.Last and Out_S2M.Ready,
				dout                => Meta_Out,
				valid               => open,
				fstate_rd           => open
			);
		else generate
			MetaFIFO_Full <= '0';
			Meta_Out      <= (others => '0');
		end generate;
	end generate;

end architecture;
