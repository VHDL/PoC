-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein
--
-- Entity:          A generic AXI4-Stream buffer (FIFO).
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.components.all;
use     work.axi4.all;
use     work.axi4stream.all;
use     work.mem.all;


entity AXI4Stream_FIFO_tempput is
	generic (
		RAM_TYPE            : T_RAM_TYPE := RAM_TYPE_OPTIMIZED;--RAM_TYPE_AUTO;     
		FRAMES              : positive   := 2;
		MAX_PACKET_DEPTH    : positive   := 8;
		USER_IS_DYNAMIC     : boolean    := true;
		NO_META_FIFO        : boolean    := false;
		ESTATE_WR_BITS      : natural    := 0;      -- Empty State Bits
		FSTATE_RD_BITS      : natural    := 0       -- Full State Bits
	);
	port (
		Clock             : in  std_logic;
		Reset             : in  std_logic;
		-- IN Port
		In_M2S            : in  T_AXI4Stream_M2S;
		In_S2M            : out T_AXI4Stream_S2M;
		In_Commit         : in  std_logic;
		In_Rollback       : in  std_logic;
		EState_WR         : out std_logic_vector(imax(0, ESTATE_WR_BITS-1) downto 0);
		-- OUT Port
		Out_M2S           : out T_AXI4Stream_M2S;
		Out_S2M           : in  T_AXI4Stream_S2M;
		FState_RD         : out std_logic_vector(imax(0, FSTATE_RD_BITS-1) downto 0)
	);
end entity;


architecture rtl of AXI4Stream_FIFO_tempput is
	constant USER_BITS        : natural        := In_M2S.User'length;
	constant DATA_BITS        : positive       := In_M2S.Data'length;
	constant KEEP_BITS        : positive       := In_M2S.Keep'length;
	constant DEST_BITS        : positive       := In_M2S.Dest'length;
	constant ID_BITS          : positive       := In_M2S.ID'length;
	
	constant INCLUDE_META     : boolean        := (USER_IS_DYNAMIC) and (USER_BITS > 0);

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

	signal In_SOF                     : std_logic;
	signal started                    : std_logic := '0';

	--We set the ranges of Out_S2M_i manually to the values from input to force the input and output record to be the same sizes.
	signal Out_M2S_i                  : T_AXI4Stream_M2S(Data(DATA_BITS -1 downto 0), Keep(DATA_BITS /8 -1 downto 0), User(USER_BITS -1 downto 0), ID(ID_BITS-1 downto 0), DEST(DEST_BITS-1 downto 0));

begin
	assert not NO_META_FIFO report "PoC.AXI4Stream_FIFO_tempput:: NO_META_FIFO is set. Meta Fifo is removed! Dest, ID and, depending on USER_IS_DYNAMIC, User is removed" severity warning;
	
	In_SOF      <= In_M2S.Valid and not started;
	started     <= ffrs(q => started, rst => ((In_M2S.Valid and In_M2S.Last) or Reset), set => (In_M2S.Valid)) when rising_edge(Clock);
	
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
		if (USER_IS_DYNAMIC) and (USER_BITS > 0) then
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
		if (USER_IS_DYNAMIC) and (USER_BITS > 0) then
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

	inst_cc_got_tempput : entity work.fifo_cc_got_tempput
	generic map (
		RAM_TYPE       => RAM_TYPE,
		D_BITS         => ite(USER_IS_DYNAMIC and (USER_BITS > 0), isum(Data_Bits_Vec), isum(Data_Bits_Vec(0 to Last_Pos))),								-- Data Width
		MIN_DEPTH      => (MAX_PACKET_DEPTH * FRAMES),	-- Minimum FIFO Depth
		DATA_REG       => ((MAX_PACKET_DEPTH * FRAMES) <= 128),											-- Store Data Content in Registers
		STATE_REG      => TRUE,												-- Registered Full/Empty Indicators
		OUTPUT_REG     => FALSE,												-- Registered FIFO Output
		ESTATE_WR_BITS => ESTATE_WR_BITS,														-- Empty State Bits
		FSTATE_RD_BITS => FSTATE_RD_BITS														-- Full State Bits
	)
	port map (
		-- Global Reset and Clock
		clk            => Clock,
		rst            => Reset,

		-- Writing Interface
		put            => DataFIFO_put,
		din            => DataFIFO_DataIn(high(Data_Bits_Vec, ite(INCLUDE_META, User_Pos, Last_Pos)) downto low(Data_Bits_Vec, 0)),
		full           => DataFIFO_Full,
		estate_wr      => estate_wr,
		
		commit         => In_Commit,
		rollback       => In_Rollback,

		-- Reading Interface
		got            => DataFIFO_got,
		dout           => DataFIFO_DataOut(high(Data_Bits_Vec, ite(INCLUDE_META, User_Pos, Last_Pos)) downto low(Data_Bits_Vec, 0)),
		valid          => DataFIFO_Valid,
		fstate_rd      => fstate_rd
	);
		
	Out_M2S     <= Out_M2S_i;

	genMeta : if (((not USER_IS_DYNAMIC) and (USER_BITS > 0)) or (DEST_BITS > 0) or (ID_BITS > 0)) generate
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
			MetaFIFO : entity work.fifo_cc_got_tempput
			generic map (
				D_BITS          => Meta_In'length, -- Data Width
				MIN_DEPTH       => imax(FRAMES, 16),               -- Minimum FIFO Depth
				DATA_REG        => ((Meta_In'length * imax(FRAMES, 16)) <= 128), -- Store Data Content in Registers
				STATE_REG       => TRUE,                          -- Registered Full/Empty Indicators
				OUTPUT_REG      => FALSE,                         -- Registered FIFO Output
				ESTATE_WR_BITS  => 0,                             -- Empty State Bits
				FSTATE_RD_BITS  => 0                              -- Full State Bits
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
			
				commit       => In_Commit,
				rollback     => In_Rollback,
				
				-- Reading Interface
				got          => Out_M2S_i.Valid and Out_M2S_i.Last and Out_S2M.Ready,
				dout         => Meta_Out,
				valid        => open,
				fstate_rd    => open
			);
		else generate
			MetaFIFO_Full <= '0';
			Meta_Out      <= (others => '0');
		end generate;
	end generate;

end architecture;
