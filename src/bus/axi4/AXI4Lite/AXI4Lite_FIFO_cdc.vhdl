-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein
--
-- Entity:          AXI4Lite_FIFO_cdc
--
-- Description:
-- -------------------------------------
-- A wrapper of fifo_ic_got for AXI4-Lite interface.  It creates a separate
-- CDC-FIFO for every of the five substreams. The size of the data-channels is
-- FRAMES * FRAMES_DEPTH, the size of the control-channels is FRAMES.
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
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

use			work.utils.all;
use			work.vectors.all;
use			work.components.all;
use			work.axi4Lite.all;
use			work.axi4_Common.all;


entity AXI4Lite_FIFO_cdc is
	generic (
		FRAMES         : positive := 2;
		DATA_REG       : boolean  := false;  -- Store Data Content in Registers
		OUTPUT_REG     : boolean  := false   -- Registered FIFO Output
	);
	port (
		-- IN Port
		In_Clock          : in	std_logic;
		In_Reset          : in	std_logic;
		In_M2S            : in  T_AXI4Lite_Bus_M2S;
		In_S2M            : out T_AXI4Lite_Bus_S2M;
		-- OUT Port
		Out_Clock         : in	std_logic;
		Out_Reset         : in	std_logic;
		Out_M2S           : out T_AXI4Lite_Bus_M2S;
		Out_S2M           : in  T_AXI4Lite_Bus_S2M
	);
end entity;


architecture rtl of AXI4Lite_FIFO_cdc is
  constant Address_BITS   : natural  := In_M2S.AWAddr'length;
  constant Data_BITS      : natural  := In_M2S.WData'length;
  constant STRB_BITS      : natural  := In_M2S.WData'length / 8;
  constant CACHE_BITS     : natural  := In_M2S.AWCache'length;
  constant PROTECT_BITS   : natural  := In_M2S.AWProt'length;
  constant RESPONSE_BITS  : natural  := In_S2M.RResp'length;

  constant Addr_POS       : natural  := 0;
  constant Cache_POS      : natural  := 1;
  constant Protect_POS    : natural  := 2;
  constant Data_POS       : natural  := 0;
  constant Strobe_POS     : natural  := 1;
  constant Resp_POS       : natural  := 1;
  constant Addr_BIT_VEC   : T_POSVEC := (Addr_POS => Address_BITS, Cache_POS => CACHE_BITS, Protect_POS => PROTECT_BITS);
  constant W_BIT_VEC      : T_POSVEC := (Data_POS => Data_BITS, Strobe_POS => STRB_BITS);
  constant R_BIT_VEC      : T_POSVEC := (Data_POS => Data_BITS, Resp_POS => RESPONSE_BITS);
  constant B_BIT_VEC      : T_POSVEC := (Resp_POS => RESPONSE_BITS);

  constant AW_POS         : natural  := 0;
  constant AR_POS         : natural  := 1;
  constant W_POS          : natural  := 2;
  constant R_POS          : natural  := 3;
  constant B_POS          : natural  := 4;

  constant BIT_VEC        : T_POSVEC := (
      AW_POS => isum(Addr_BIT_VEC),
      AR_POS => isum(Addr_BIT_VEC),
      W_POS  => isum(W_BIT_VEC),
      R_POS  => isum(R_BIT_VEC),
      B_POS  => isum(B_BIT_VEC)
    );

  signal   In_Ready_vec      : std_logic_vector(0 to 4);
  signal   In_Valid_vec      : std_logic_vector(0 to 4);
  signal   Out_Ready_vec     : std_logic_vector(0 to 4);
  signal   Out_Valid_vec     : std_logic_vector(0 to 4);
  signal   DataFIFO_DataIn   : std_logic_vector(isum(BIT_VEC) -1 downto 0);
  signal   DataFIFO_DataOut  : std_logic_vector(isum(BIT_VEC) -1 downto 0);



begin
  -----INPUT
  In_S2M.AWReady  <= In_Ready_vec(AW_POS);
  In_S2M.ARReady  <= In_Ready_vec(AR_POS);
  In_S2M.WReady   <= In_Ready_vec(W_POS );
  Out_M2S.RReady  <= In_Ready_vec(R_POS );
  Out_M2S.BReady  <= In_Ready_vec(B_POS );

  In_Valid_vec(AW_POS)  <= In_M2S.AWValid;
  In_Valid_vec(AR_POS)  <= In_M2S.ARValid;
  In_Valid_vec(W_POS )  <= In_M2S.WValid;
  In_Valid_vec(R_POS )  <= Out_S2M.RValid;
  In_Valid_vec(B_POS )  <= Out_S2M.BValid;

  -----OUTPUT
  Out_Ready_vec(AW_POS) <= Out_S2M.AWReady;
  Out_Ready_vec(AR_POS) <= Out_S2M.ARReady;
  Out_Ready_vec(W_POS ) <= Out_S2M.WReady ;
  Out_Ready_vec(R_POS ) <= In_M2S.RReady;
  Out_Ready_vec(B_POS ) <= In_M2S.BReady;

  Out_M2S.AWValid  <= Out_Valid_vec(AW_POS);
  Out_M2S.ARValid  <= Out_Valid_vec(AR_POS);
  Out_M2S.WValid   <= Out_Valid_vec(W_POS );
  In_S2M.RValid    <= Out_Valid_vec(R_POS );
  In_S2M.BValid    <= Out_Valid_vec(B_POS );

  -----INPUT
  --AW IN Interface
  DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(Addr_BIT_VEC,Addr_POS) downto
                    low(BIT_VEC,AW_POS) + low(Addr_BIT_VEC,Addr_POS))
    <= In_M2S.AWAddr;
  DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(Addr_BIT_VEC,Cache_POS) downto
                    low(BIT_VEC,AW_POS) + low(Addr_BIT_VEC,Cache_POS))
    <= In_M2S.AWCache;
  DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(Addr_BIT_VEC,Protect_POS) downto
                    low(BIT_VEC,AW_POS) + low(Addr_BIT_VEC,Protect_POS))
    <= In_M2S.AWProt;
  --AR IN Interface
  DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(Addr_BIT_VEC,Addr_POS) downto
                    low(BIT_VEC,AR_POS) + low(Addr_BIT_VEC,Addr_POS))
    <= In_M2S.ARAddr;
  DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(Addr_BIT_VEC,Cache_POS) downto
                    low(BIT_VEC,AR_POS) + low(Addr_BIT_VEC,Cache_POS))
    <= In_M2S.ARCache;
  DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(Addr_BIT_VEC,Protect_POS) downto
                    low(BIT_VEC,AR_POS) + low(Addr_BIT_VEC,Protect_POS))
    <= In_M2S.ARProt;
  --W IN Interface
  DataFIFO_DataIn(  low(BIT_VEC,W_POS) + high(W_BIT_VEC,Data_POS) downto
                    low(BIT_VEC,W_POS) + low(W_BIT_VEC,Data_POS))
    <= In_M2S.WData;
  DataFIFO_DataIn(  low(BIT_VEC,W_POS) + high(W_BIT_VEC,Strobe_POS) downto
                    low(BIT_VEC,W_POS) + low(W_BIT_VEC,Strobe_POS))
    <= In_M2S.WStrb;
  --R IN Interface
  DataFIFO_DataIn(  low(BIT_VEC,R_POS) + high(R_BIT_VEC,Data_POS) downto
                    low(BIT_VEC,R_POS) + low(R_BIT_VEC,Data_POS))
    <= Out_S2M.RData;
  DataFIFO_DataIn(  low(BIT_VEC,R_POS) + high(R_BIT_VEC,Resp_POS) downto
                    low(BIT_VEC,R_POS) + low(R_BIT_VEC,Resp_POS))
    <= Out_S2M.RResp;
  --B IN Interface
  DataFIFO_DataIn(  low(BIT_VEC,B_POS) + high(B_BIT_VEC,Resp_POS) downto
                    low(BIT_VEC,B_POS) + low(B_BIT_VEC,Resp_POS))
    <= Out_S2M.BResp;

  ----OUTPUT
  --AW Out Interface
  Out_M2S.AWAddr <= DataFIFO_DataOut( low(BIT_VEC,AW_POS) + high(Addr_BIT_VEC,Addr_POS) downto
                                      low(BIT_VEC,AW_POS) + low(Addr_BIT_VEC,Addr_POS));
  Out_M2S.AWCache <= DataFIFO_DataOut(low(BIT_VEC,AW_POS) + high(Addr_BIT_VEC,Cache_POS) downto
                                      low(BIT_VEC,AW_POS) + low(Addr_BIT_VEC,Cache_POS));
  Out_M2S.AWProt <= DataFIFO_DataOut( low(BIT_VEC,AW_POS) + high(Addr_BIT_VEC,Protect_POS) downto
                                      low(BIT_VEC,AW_POS) + low(Addr_BIT_VEC,Protect_POS));
  --AR Out Interface
  Out_M2S.ARAddr <= DataFIFO_DataOut( low(BIT_VEC,AR_POS) + high(Addr_BIT_VEC,Addr_POS) downto
                                      low(BIT_VEC,AR_POS) + low(Addr_BIT_VEC,Addr_POS));
  Out_M2S.ARCache <= DataFIFO_DataOut(low(BIT_VEC,AR_POS) + high(Addr_BIT_VEC,Cache_POS) downto
                                      low(BIT_VEC,AR_POS) + low(Addr_BIT_VEC,Cache_POS));
  Out_M2S.ARProt <= DataFIFO_DataOut( low(BIT_VEC,AR_POS) + high(Addr_BIT_VEC,Protect_POS) downto
                                      low(BIT_VEC,AR_POS) + low(Addr_BIT_VEC,Protect_POS));
  --W Out Interface
  Out_M2S.WData <= DataFIFO_DataOut(  low(BIT_VEC,W_POS) + high(W_BIT_VEC,Data_POS) downto
                                      low(BIT_VEC,W_POS) + low(W_BIT_VEC,Data_POS));
  Out_M2S.WStrb <= DataFIFO_DataOut(  low(BIT_VEC,W_POS) + high(W_BIT_VEC,Strobe_POS) downto
                                      low(BIT_VEC,W_POS) + low(W_BIT_VEC,Strobe_POS));
  --R Out Interface
  In_S2M.RData <= DataFIFO_DataOut(   low(BIT_VEC,R_POS) + high(R_BIT_VEC,Data_POS) downto
                                      low(BIT_VEC,R_POS) + low(R_BIT_VEC,Data_POS));
  In_S2M.RResp <= DataFIFO_DataOut(   low(BIT_VEC,R_POS) + high(R_BIT_VEC,Resp_POS) downto
                                      low(BIT_VEC,R_POS) + low(R_BIT_VEC,Resp_POS));
  --B Out Interface
  In_S2M.BResp <= DataFIFO_DataOut(   low(BIT_VEC,B_POS) + high(B_BIT_VEC,Resp_POS) downto
                                      low(BIT_VEC,B_POS) + low(B_BIT_VEC,Resp_POS));


  gen_fifo : for i in 0 to 4 generate
    signal DataFIFO_put       : std_logic;
    signal DataFIFO_DataIn_i  : std_logic_vector(BIT_VEC(i) -1 downto 0);
    signal DataFIFO_DataOut_i : std_logic_vector(BIT_VEC(i) -1 downto 0);
    signal DataFIFO_Full      : std_logic;
    signal DataFIFO_got       : std_logic;
    signal DataFIFO_Valid     : std_logic;
  begin

    DataFIFO_put       <= In_Valid_vec(i) and not DataFIFO_Full;
    In_Ready_vec(i)    <= not DataFIFO_Full;
    DataFIFO_DataIn_i  <= DataFIFO_DataIn(high(BIT_VEC,i) downto low(BIT_VEC,i));

    DataFIFO_DataOut(high(BIT_VEC,i) downto low(BIT_VEC,i)) <= DataFIFO_DataOut_i;
    DataFIFO_got       <= Out_Ready_vec(i);
    Out_Valid_vec(i)   <= DataFIFO_Valid;

		inst_ic_got : entity work.fifo_ic_got
		generic map (
			D_BITS             => BIT_VEC(i),
			MIN_DEPTH          => FRAMES,
			DATA_REG           => DATA_REG,
			OUTPUT_REG         => OUTPUT_REG,
			ESTATE_WR_BITS     => 0,
			FSTATE_RD_BITS     => 0
		)
		port map (
			-- Writing Interface
			clk_wr              => ite(i<3,In_Clock,Out_Clock),
			rst_wr              => ite(i<3,In_Reset,Out_Reset),
			put                 => DataFIFO_put,
			din                 => DataFIFO_DataIn_i,
			full                => DataFIFO_Full,
			estate_wr           => open,

			-- Reading Interface
			clk_rd              => ite(i<3,Out_Clock,In_Clock),
			rst_rd              => ite(i<3,Out_Reset,In_Reset),
			got                 => DataFIFO_got,
			dout                => DataFIFO_DataOut_i,
			valid               => DataFIFO_Valid,
			fstate_rd           => open
		);


  end generate;


end architecture;
