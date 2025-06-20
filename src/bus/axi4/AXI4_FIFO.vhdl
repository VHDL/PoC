-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Stefan Unrein
--
-- Entity:          AXI4_FIFO
--
-- Description:
-- -------------------------------------
-- A wrapper of fifo_cc_got for AXI4-MM interface.  It creates a separate
-- FIFO for every of the five substreams. The size of the data-channels is
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
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.components.all;
use     work.axi4_Full.all;
use     work.axi4_Common.all;


entity AXI4_FIFO is
generic (
	FRAMES            : natural    := 0;
	FRAME_DEPTH       : positive   := 1
);
port (
	Clock             : in  std_logic;
	Reset             : in  std_logic;
	-- IN Port
	In_M2S            : in  T_AXI4_Bus_M2S;
	In_S2M            : out T_AXI4_Bus_S2M;
	-- OUT Port
	Out_M2S           : out T_AXI4_Bus_M2S;
	Out_S2M           : in  T_AXI4_Bus_S2M
);
end entity;


architecture rtl of AXI4_FIFO is
	constant LOCK_BITS      : natural := 1;
	constant LAST_BITS      : natural := 1;

	constant ID_POS         : natural := 0;
	constant User_POS       : natural := 1;
	constant Addr_POS       : natural := 2;
	constant Cache_POS      : natural := 3;
	constant Protect_POS    : natural := 4;
	constant Len_POS        : natural := 5;
	constant Size_POS       : natural := 6;
	constant Burst_POS      : natural := 7;
	constant Lock_POS       : natural := 8;
	constant QoS_POS        : natural := 9;
	constant Region_POS     : natural := 10;

	--Data-Only
	constant Data_POS       : natural := 3;
	constant Last_POS       : natural := 4;
	--Write-Only
	constant Strobe_POS     : natural := 2;
	--Ready/Write-Response-Only
	constant Resp_POS       : natural := 2;

	constant W_Addr_BIT_VEC   : T_POSVEC := ( ID_POS    => In_M2S.AWID'length,    User_POS    => In_M2S.AWUser'length,    Addr_POS => In_M2S.AWAddr'length,
	                                          Cache_POS => In_M2S.AWCache'length, Protect_POS => In_M2S.AWProt'length,    Len_POS  => In_M2S.AWLen'length,
	                                          Size_POS  => In_M2S.AWSize'length,  Burst_POS   => In_M2S.AWBurst'length,   Lock_POS => LOCK_BITS,
	                                          QoS_POS   => In_M2S.AWQoS'length,   Region_POS  => In_M2S.AWRegion'length
		);
	constant R_Addr_BIT_VEC   : T_POSVEC := ( ID_POS    => In_M2S.ARID'length,    User_POS    => In_M2S.ARUser'length,    Addr_POS => In_M2S.ARAddr'length,
	                                          Cache_POS => In_M2S.ARCache'length, Protect_POS => In_M2S.ARProt'length,    Len_POS  => In_M2S.ARLen'length,
	                                          Size_POS  => In_M2S.ARSize'length,  Burst_POS   => In_M2S.ARBurst'length,   Lock_POS => LOCK_BITS,
	                                          QoS_POS   => In_M2S.ARQoS'length,   Region_POS  => In_M2S.ARRegion'length
		);
	constant W_BIT_VEC      : T_POSVEC := (User_POS => In_M2S.WUser'length, Strobe_POS => In_M2S.WStrb'length, Data_POS => In_M2S.WData'length,
	                                       Last_POS => LAST_BITS
		);
	constant R_BIT_VEC      : T_POSVEC := (ID_POS   => In_S2M.RID'length,   User_POS => In_S2M.RUser'length, Resp_POS => In_S2M.RResp'length,
	                                       Data_POS => In_S2M.RData'length, Last_POS => LAST_BITS
		);
	constant B_BIT_VEC      : T_POSVEC := (ID_POS => In_S2M.BID'length, User_POS => In_S2M.BUser'length, Resp_POS => In_S2M.BResp'length);

	constant AW_POS         : natural := 0;
	constant AR_POS         : natural := 1;
	constant W_POS          : natural := 2;
	constant R_POS          : natural := 3;
	constant B_POS          : natural := 4;

	constant BIT_VEC        : T_POSVEC := (
      AW_POS => isum(W_Addr_BIT_VEC),
      AR_POS => isum(R_Addr_BIT_VEC),
			W_POS  => isum(W_BIT_VEC),
			R_POS  => isum(R_BIT_VEC),
			B_POS  => isum(B_BIT_VEC)
		);

	constant MIN_DEPTH      : T_NATVEC := (
			AW_POS => FRAMES,
			AR_POS => FRAMES,
			W_POS  => FRAMES * FRAME_DEPTH,
			R_POS  => FRAMES * FRAME_DEPTH,
			B_POS  => FRAMES
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
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Addr_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Addr_POS))
		<= In_M2S.AWAddr;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Cache_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Cache_POS))
		<= In_M2S.AWCache;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Protect_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Protect_POS))
		<= In_M2S.AWProt;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,ID_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,ID_POS))
		<= In_M2S.AWID;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Len_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Len_POS))
		<= In_M2S.AWLen;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Size_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Size_POS))
		<= In_M2S.AWSize;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Burst_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Burst_POS))
		<= In_M2S.AWBurst;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Lock_POS))
		<= In_M2S.AWLock(0);

	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,QoS_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,QoS_POS))
		<= In_M2S.AWQoS;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Region_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Region_POS))
		<= In_M2S.AWRegion;
	DataFIFO_DataIn(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,User_POS) downto
	                  low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,User_POS))
		<= In_M2S.AWUser;
	--AR IN Interface
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Addr_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Addr_POS))
		<= In_M2S.ARAddr;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Cache_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Cache_POS))
		<= In_M2S.ARCache;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Protect_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Protect_POS))
		<= In_M2S.ARProt;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,ID_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,ID_POS))
		<= In_M2S.ARID;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Len_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Len_POS))
		<= In_M2S.ARLen;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Size_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Size_POS))
		<= In_M2S.ARSize;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Burst_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Burst_POS))
		<= In_M2S.ARBurst;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Lock_POS))
		<= In_M2S.ARLock(0);

	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,QoS_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,QoS_POS))
		<= In_M2S.ARQoS;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Region_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Region_POS))
		<= In_M2S.ARRegion;
	DataFIFO_DataIn(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,User_POS) downto
	                  low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,User_POS))
		<= In_M2S.ARUser;
	--W IN Interface
	DataFIFO_DataIn(  low(BIT_VEC,W_POS) + high(W_BIT_VEC,Data_POS) downto
	                  low(BIT_VEC,W_POS) + low(W_BIT_VEC,Data_POS))
		<= In_M2S.WData;
	DataFIFO_DataIn(  low(BIT_VEC,W_POS) + high(W_BIT_VEC,Strobe_POS) downto
	                  low(BIT_VEC,W_POS) + low(W_BIT_VEC,Strobe_POS))
		<= In_M2S.WStrb;
	DataFIFO_DataIn(  low(BIT_VEC,W_POS) + high(W_BIT_VEC,User_POS) downto
	                  low(BIT_VEC,W_POS) + low(W_BIT_VEC,User_POS))
		<= In_M2S.WUser;
	DataFIFO_DataIn(  low(BIT_VEC,W_POS) + low(W_BIT_VEC,Last_POS))
		<= In_M2S.WLast;
	--R IN Interface
	DataFIFO_DataIn(  low(BIT_VEC,R_POS) + high(R_BIT_VEC,Data_POS) downto
	                  low(BIT_VEC,R_POS) + low(R_BIT_VEC,Data_POS))
		<= Out_S2M.RData;
	DataFIFO_DataIn(  low(BIT_VEC,R_POS) + high(R_BIT_VEC,Resp_POS) downto
	                  low(BIT_VEC,R_POS) + low(R_BIT_VEC,Resp_POS))
		<= Out_S2M.RResp;
	DataFIFO_DataIn(  low(BIT_VEC,R_POS) + high(R_BIT_VEC,ID_POS) downto
	                  low(BIT_VEC,R_POS) + low(R_BIT_VEC,ID_POS))
		<= Out_S2M.RID;
	DataFIFO_DataIn(  low(BIT_VEC,R_POS) + high(R_BIT_VEC,User_POS) downto
	                  low(BIT_VEC,R_POS) + low(R_BIT_VEC,User_POS))
		<= Out_S2M.RUser;
	DataFIFO_DataIn(  low(BIT_VEC,R_POS) + low(R_BIT_VEC,Last_POS))
		<= Out_S2M.RLast;
	--B IN Interface
	DataFIFO_DataIn(  low(BIT_VEC,B_POS) + high(R_BIT_VEC,Resp_POS) downto
	                  low(BIT_VEC,B_POS) + low(R_BIT_VEC,Resp_POS))
		<= Out_S2M.BResp;
	DataFIFO_DataIn(  low(BIT_VEC,B_POS) + high(R_BIT_VEC,ID_POS) downto
	                  low(BIT_VEC,B_POS) + low(R_BIT_VEC,ID_POS))
		<= Out_S2M.BID;
	DataFIFO_DataIn(  low(BIT_VEC,B_POS) + high(R_BIT_VEC,User_POS) downto
	                  low(BIT_VEC,B_POS) + low(R_BIT_VEC,User_POS))
		<= Out_S2M.BUser;

	----OUTPUT
	--AW Out Interface
	Out_M2S.AWAddr <= DataFIFO_DataOut(   low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Addr_POS) downto
	                                      low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Addr_POS));
	Out_M2S.AWCache <= DataFIFO_DataOut(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Cache_POS) downto
	                                      low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Cache_POS));
	Out_M2S.AWProt <= DataFIFO_DataOut(   low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Protect_POS) downto
	                                      low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Protect_POS));
	Out_M2S.AWID <= DataFIFO_DataOut(     low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,ID_POS) downto
	                                      low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,ID_POS));
	Out_M2S.AWLen <= DataFIFO_DataOut(    low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Len_POS) downto
	                                      low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Len_POS));
	Out_M2S.AWSize <= DataFIFO_DataOut(   low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Size_POS) downto
	                                      low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Size_POS));
	Out_M2S.AWBurst <= DataFIFO_DataOut(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Burst_POS) downto
	                                      low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Burst_POS));
	Out_M2S.AWLock(0) <= DataFIFO_DataOut(low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Lock_POS));

	Out_M2S.AWQoS <= DataFIFO_DataOut(   low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,QoS_POS) downto
	                                     low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,QoS_POS));
	Out_M2S.AWRegion <= DataFIFO_DataOut(low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,Region_POS) downto
	                                     low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,Region_POS));
	Out_M2S.AWUser <= DataFIFO_DataOut(  low(BIT_VEC,AW_POS) + high(W_Addr_BIT_VEC,User_POS) downto
	                                     low(BIT_VEC,AW_POS) + low(W_Addr_BIT_VEC,User_POS));
	--AR Out Interface
	Out_M2S.ARAddr <= DataFIFO_DataOut(   low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Addr_POS) downto
	                                      low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Addr_POS));
	Out_M2S.ARCache <= DataFIFO_DataOut(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Cache_POS) downto
	                                      low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Cache_POS));
	Out_M2S.ARProt <= DataFIFO_DataOut(   low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Protect_POS) downto
	                                      low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Protect_POS));
	Out_M2S.ARID <= DataFIFO_DataOut(     low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,ID_POS) downto
	                                      low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,ID_POS));
	Out_M2S.ARLen <= DataFIFO_DataOut(    low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Len_POS) downto
	                                      low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Len_POS));
	Out_M2S.ARSize <= DataFIFO_DataOut(   low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Size_POS) downto
	                                      low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Size_POS));
	Out_M2S.ARBurst <= DataFIFO_DataOut(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Burst_POS) downto
	                                      low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Burst_POS));
	Out_M2S.ARLock(0) <= DataFIFO_DataOut(low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Lock_POS));

	Out_M2S.ARQoS <= DataFIFO_DataOut(   low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,QoS_POS) downto
	                                     low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,QoS_POS));
	Out_M2S.ARRegion <= DataFIFO_DataOut(low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,Region_POS) downto
	                                     low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,Region_POS));
	Out_M2S.ARUser <= DataFIFO_DataOut(  low(BIT_VEC,AR_POS) + high(R_Addr_BIT_VEC,User_POS) downto
	                                     low(BIT_VEC,AR_POS) + low(R_Addr_BIT_VEC,User_POS));
	--W Out Interface
	Out_M2S.WData <= DataFIFO_DataOut(low(BIT_VEC,W_POS) + high(W_BIT_VEC,Data_POS) downto
	                                  low(BIT_VEC,W_POS) + low(W_BIT_VEC,Data_POS));
	Out_M2S.WStrb <= DataFIFO_DataOut(low(BIT_VEC,W_POS) + high(W_BIT_VEC,Strobe_POS) downto
	                                  low(BIT_VEC,W_POS) + low(W_BIT_VEC,Strobe_POS));
	Out_M2S.WUser <= DataFIFO_DataOut(low(BIT_VEC,W_POS) + high(W_BIT_VEC,User_POS) downto
	                                  low(BIT_VEC,W_POS) + low(W_BIT_VEC,User_POS));
	Out_M2S.WLast <= DataFIFO_DataOut(low(BIT_VEC,W_POS) + low(W_BIT_VEC,Last_POS));

	--R Out Interface
	In_S2M.RData <= DataFIFO_DataOut( low(BIT_VEC,R_POS) + high(R_BIT_VEC,Data_POS) downto
	                                  low(BIT_VEC,R_POS) + low(R_BIT_VEC,Data_POS));
	In_S2M.RResp <= DataFIFO_DataOut( low(BIT_VEC,R_POS) + high(R_BIT_VEC,Resp_POS) downto
	                                  low(BIT_VEC,R_POS) + low(R_BIT_VEC,Resp_POS));
	In_S2M.RUser <= DataFIFO_DataOut( low(BIT_VEC,R_POS) + high(R_BIT_VEC,User_POS) downto
	                                  low(BIT_VEC,R_POS) + low(R_BIT_VEC,User_POS));
	In_S2M.RLast <= DataFIFO_DataOut( low(BIT_VEC,R_POS) + low(R_BIT_VEC,Last_POS));

	In_S2M.RID <= DataFIFO_DataOut(   low(BIT_VEC,R_POS) + high(R_BIT_VEC,ID_POS) downto
	                                  low(BIT_VEC,R_POS) + low(R_BIT_VEC,ID_POS));
	--B Out Interface
	In_S2M.BResp <= DataFIFO_DataOut( low(BIT_VEC,B_POS) + high(R_BIT_VEC,Resp_POS) downto
	                                  low(BIT_VEC,B_POS) + low(R_BIT_VEC,Resp_POS));
	In_S2M.BUser <= DataFIFO_DataOut( low(BIT_VEC,B_POS) + high(R_BIT_VEC,User_POS) downto
	                                  low(BIT_VEC,B_POS) + low(R_BIT_VEC,User_POS));
	In_S2M.BID <= DataFIFO_DataOut(   low(BIT_VEC,B_POS) + high(R_BIT_VEC,ID_POS) downto
	                                  low(BIT_VEC,B_POS) + low(R_BIT_VEC,ID_POS));


	gen : for i in 0 to 4 generate
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

		genStage : if FRAMES > 3 generate
		begin

			DataFifo : entity work.fifo_cc_got
			generic map (
				D_BITS              => BIT_VEC(i),    -- Data Width
				MIN_DEPTH           => MIN_DEPTH(i),  -- Minimum FIFO Depth
				DATA_REG            => FALSE,											  -- Store Data Content in Registers
				STATE_REG           => TRUE,										    -- Registered Full/Empty Indicators
				OUTPUT_REG          => FALSE,												-- Registered FIFO Output
				ESTATE_WR_BITS      => 0,														-- Empty State Bits
				FSTATE_RD_BITS      => 0														-- Full State Bits
			)
			port map (
				-- Global Reset and Clock
				rst                 => Reset,
				clk                 => Clock,
				-- Writing Interface
				put                 => DataFIFO_put,
				din                 => DataFIFO_DataIn_i,
				full                => DataFIFO_Full,
				estate_wr           => open,

				-- Reading Interface
				got                 => DataFIFO_got,
				dout                => DataFIFO_DataOut_i,
				valid               => DataFIFO_Valid,
				fstate_rd           => open
			);
		else generate

			Stage : entity work.fifo_stage
			generic map(
				D_BITS          => BIT_VEC(i),
				STAGES          => FRAMES +1,
				LIGHT_WEIGHT    => (i = AW_POS) or (i = AR_POS) or (i = B_POS)
			)
			port map(
				-- Control
				clk     => Clock,
				rst     => Reset,

				-- Input
				put     => DataFIFO_put,
				di      => DataFIFO_DataIn_i,
				ful     => DataFIFO_Full,

				-- Output
				vld     => DataFIFO_Valid,
				do      => DataFIFO_DataOut_i,
				got     => DataFIFO_got
			);

		end generate;

	end generate;


end architecture;
