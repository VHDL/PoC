-- =============================================================================
-- Authors:         Stefan Unrein
--
-- Entity:          AXI4 De-Multiplexer
--
-- Description:
-- -------------------------------------
-- This module provides a demultiplexing functionality for AXI4 busses.
-- Based on the provided address on write or read channels, the packets are
-- forwarded to the matching output interface. The address of the connected
-- subordinates is defined by the BASE_ADDRESS and the corresponding
-- BASE_ADDRESS_MASK. Every transaction not matching any outputs is internally
-- discarted and a decode-error response is generated.
-- Note that this module terminates ID's on the input and genrates new ID's for
-- every output-port. On response reception, the response is forwarded with the
-- original ID to the manager. The number of read and write ID's is defined by
-- NUM_OUTSTANDING_READS and NUM_OUTSTANDING_WRITES, where the ID's from
-- 0 to NUM_OUTSTANDING_* -1 are generated. Every subordinate must support the
-- given number of ID's to work. Leave NUM_OUTSTANDING_* at init value 0 to
-- generate ID's of the full ID-width (2**ID-width).
-- PIPELINE_IN and PIPELINE_OUT provide the settings for input and ouput
-- pipelining stages as a timing relaxantion setting.
--
-- Example configuration:
-- 3 Subordinates with 512kB each, starting at 0x0008_0000
-- BASE_ADDRESS => (0 => 32x"x0008_0000", 1 => 32x"x0009_0000", 2 => 32x"x000A_0000")
-- BASE_ADDRESS_MASK => (0 to 2 => 32x"x0007_FFFF")
--
-- Utilization compared to Xilinx Crossbar (2.1) 1 Slave => 4 Master (32 Addr/Data)
-- | LUT  | FF   | Comment                |
-- | ---- | ---- | ---------------------- |
-- | 294  | 520  | Xilinx Crosbar ( 2 IDs)|
-- | 320  | 540  | Xilinx Crosbar (16 IDs)|
-- | 258  | 62   | 0 Glue         ( 2 IDs)|
-- | 823  | 199  | 0 Glue         (16 IDs)|
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
use     work.axi4_Full.all;
use     work.axi4stream.all;


entity axi4_DeMux is
	generic(
		BASE_ADDRESS      : T_SLUV;
		BASE_ADDRESS_MASK : BASE_ADDRESS'subtype;
		PIPELINE_IN       : natural                       := 0;
		PIPELINE_OUT      : natural_vector(BASE_ADDRESS'range)  := (others => 0);
		NUM_OUTSTANDING_READS  : natural   := 0; -- if zero, use full ID width (2**ID)
		NUM_OUTSTANDING_WRITES : natural   := 0  -- if zero, use full ID width (2**ID)
	);
	port (
		Clock             : in  std_logic;
		Reset             : in  std_logic;
		-- IN Port
		In_M2S            : in  T_AXI4_Bus_M2S;
		In_S2M            : out T_AXI4_Bus_S2M;
		-- OUT Port
		Out_M2S           : out T_AXI4_Bus_M2S_VECTOR;
		Out_S2M           : in  T_AXI4_Bus_S2M_VECTOR
	);
end entity;


architecture rtl of axi4_DeMux is
	constant RESPONSE_FIFO_DEPTH : positive := 16; --Using SRL16E, depth is maximum 16

	constant PORTS          : positive := Out_M2S'length;
	constant PORT_BITS      : positive := log2ceilnz(PORTS);

	constant IN_AW_ID_BITS    : natural := In_M2S.AWID'length;
	constant Out_AW_ID_BITS   : natural := Out_M2S(Out_M2S'low).AWID'length;
	constant IN_AR_ID_BITS    : natural := In_M2S.ARID'length;
	constant Out_AR_ID_BITS   : natural := Out_M2S(Out_M2S'low).ARID'length;

	constant ADDRESS_BITS   : natural  := imin(In_M2S.AWAddr'length, Out_M2S(0).AWAddr'length);
	constant DATA_BITS      : natural  := In_M2S.WData'length;
	constant STRB_BITS      : natural  := In_M2S.WData'length / 8;
	constant CACHE_BITS     : natural  := In_M2S.AWCache'length;
	constant PROTECT_BITS   : natural  := In_M2S.AWProt'length;
	constant RESPONSE_BITS  : natural  := In_S2M.RResp'length;
	constant USER_BITS      : natural  := In_M2S.AWUser'length;
	constant ID_BITS        : natural  := In_M2S.AWID'length;
	constant LEN_BITS       : natural  := In_M2S.AWLen'length;
	constant SIZE_BITS      : natural  := In_M2S.AWSize'length;
	constant BURST_BITS     : natural  := In_M2S.AWBurst'length;
	constant QOS_BITS       : natural  := In_M2S.AWQoS'length;
	constant REGION_BITS    : natural  := In_M2S.AWRegion'length;
	constant LOCK_BITS      : natural  := 1;

	constant ADDR_BITS_SLAVE : natural := Out_M2S(Out_M2S'low).ARAddr'length;

	signal In_M2S_g         : In_M2S'subtype;
	signal In_S2M_g         : In_S2M'subtype;
	signal In_M2S_write     : In_M2S'subtype;
	signal In_S2M_write     : In_S2M'subtype;
	signal In_M2S_read      : In_M2S'subtype;
	signal In_S2M_read      : In_S2M'subtype;
	signal Out_M2S_g        : Out_M2S'subtype;
	signal Out_S2M_g        : Out_S2M'subtype;
	signal Out_M2S_write    : Out_M2S'subtype;
	signal Out_S2M_write    : Out_S2M'subtype;
	signal Out_M2S_read     : Out_M2S'subtype;
	signal Out_S2M_read     : Out_S2M'subtype;

begin
	assert In_M2S.AWAddr'length = Out_M2S(Out_M2S'low).AWAddr'length report "PoC.axi4_DeMux:: AWAddr size of in and out not matching!" severity failure;
	assert In_M2S.ARAddr'length = Out_M2S(Out_M2S'low).ARAddr'length report "PoC.axi4_DeMux:: ARAddr size of in and out not matching!" severity failure;
	assert In_M2S.WData'length = Out_M2S(Out_M2S'low).WData'length   report "PoC.axi4_DeMux:: WData size of in and out not matching!" severity failure;
	assert In_S2M.RData'length = Out_S2M(Out_M2S'low).RData'length   report "PoC.axi4_DeMux:: RData size of in and out not matching!" severity failure;
	assert BASE_ADDRESS'length = Out_M2S'length
		report "PoC.axi4_DeMux:: Number of Base-Addresses is not equal to Number Port-Vector!"
		severity failure;

	assert BASE_ADDRESS(BASE_ADDRESS'low)'length >= ADDRESS_BITS
		report "PoC.axi4_DeMux:: The number of master address bits (" & to_string(ADDRESS_BITS) & ") is not less than or equal to the width of generic BASE_ADDRESS (" & to_string(BASE_ADDRESS(BASE_ADDRESS'low)'length) & ")!"
		severity failure;

	assert BASE_ADDRESS(BASE_ADDRESS'low)'length >= ADDR_BITS_SLAVE
		report "PoC.axi4_DeMux:: The number of slave address bits (" & to_string(ADDR_BITS_SLAVE) & ") is not less than or equal to the width of generic BASE_ADDRESS (" & to_string(BASE_ADDRESS(BASE_ADDRESS'low)'length) & ")!"
		severity failure;

	glue_in_gen : if PIPELINE_IN > 0 generate
		Glue_in : entity work.axi4_FIFO
		generic map(
			FRAMES            => PIPELINE_IN -1
		)
		port map(
			Clock             => Clock,
			Reset             => Reset,
			-- IN Port
			In_M2S            => In_M2S,
			In_S2M            => In_S2M,
			-- OUT Port
			Out_M2S           => In_M2S_g,
			Out_S2M           => In_S2M_g
		);
	else generate
		In_M2S_g <= In_M2S;
		In_S2M   <= In_S2M_g;
	end generate;

	glue_out_loop_gen : for i in Out_M2S'range generate
		glue_out_gen : if PIPELINE_OUT(i) > 0 generate
			Glue_in : entity work.axi4_FIFO
			generic map(
				FRAMES            => PIPELINE_OUT(i) -1
			)
			port map(
				Clock             => Clock,
				Reset             => Reset,
				-- IN Port
				In_M2S            => Out_M2S_g(i),
				In_S2M            => Out_S2M_g(i),
				-- OUT Port
				Out_M2S           => Out_M2S(i),
				Out_S2M           => Out_S2M(i)
			);
		else generate
			Out_M2S(i)   <= Out_M2S_g(i);
			Out_S2M_g(i) <= Out_S2M(i);
		end generate;
	end generate;

	write_blk : block
		constant NUM_INDEX         : natural := ite(NUM_OUTSTANDING_WRITES = 0, 2**Out_AW_ID_BITS, NUM_OUTSTANDING_WRITES);

		constant B_Resp_POS        : natural  := 0;
		constant B_ID_POS          : natural  := 1;
		constant B_User_POS        : natural  := 2;
		constant BACKWARD_BIT_VEC : positive_vector := (
			B_Resp_POS => RESPONSE_BITS,
			B_ID_POS   => Out_AW_ID_BITS,
			B_User_POS => USER_BITS
		);

		signal Address_hit : std_logic_vector(PORTS -1 downto 0);
		constant MUX_DATA_BITS          : natural := isum(BACKWARD_BIT_VEC);

		signal Mux_In_M2S               : T_AXI4Stream_M2S_VECTOR(0 to PORTS)(Data(isum(BACKWARD_BIT_VEC) - 1 downto 0), Keep(0 downto 0), User(0 downto 0), ID(0 downto 0), Dest(0 downto 0));
		signal Mux_In_S2M               : T_AXI4Stream_S2M_VECTOR(0 to PORTS)(User(0 downto 0));
		signal Mux_Out_M2S              : T_AXI4Stream_M2S(Data(isum(BACKWARD_BIT_VEC) - 1 downto 0), Keep(0 downto 0), User(0 downto 0), ID(0 downto 0), Dest(0 downto 0));
		signal Mux_Out_S2M              : T_AXI4Stream_S2M(User(0 downto 0));

		signal Response_fifo_put  : std_logic;
		signal Response_fifo_ful  : std_logic;
		signal Response_fifo_got  : std_logic;
		signal Response_fifo_dout : std_logic_vector(ID_BITS-1 downto 0);
		signal Response_fifo_vld  : std_logic;

		type T_STATE is (ST_Idle, ST_Dataflow, ST_DataOnly, ST_AddressOnly, St_DiscardData);

		signal State     : T_State := St_Idle;
		signal NextState : T_STATE;

		--OoO-Buffer Signals
		-- Put Port
		signal Put               : std_logic_vector(0 to PORTS -1);
		signal Full              : std_logic_vector(0 to PORTS -1);
		signal IndexOut          : T_SLUV(0 to PORTS)(log2ceilnz(NUM_INDEX) -1 downto 0);
		signal Write_Response_Error : std_logic_vector(0 to PORTS -1) := (others => '0');
	begin
		assign_gen : for i in 0 to PORTS -1 generate
			--OoO-Buffer Signals
			-- Put Port
			signal DataIn            : std_logic_vector(In_AW_ID_BITS -1 downto 0);
			-- Get Port
			signal Got               : std_logic;
			signal Valid             : std_logic;
			signal DataOut           : std_logic_vector(In_AW_ID_BITS -1 downto 0);
		begin
			Address_hit(i)       <= '1' when (unsigned(In_M2S_write.AWAddr) and not BASE_ADDRESS_MASK(i)) = (Base_Address(i) and not BASE_ADDRESS_MASK(i)) else '0';

			Write_idx : entity work.dstruct_OutOfOrderBuffer
			generic map(
				DATA_BITS => In_AW_ID_BITS,
				NUM_INDEX => NUM_INDEX
			)
			port map(
				-- INPUTS
				Clock => Clock,
				Reset => Reset,

				-- Put Port
				Put      => Put(i),
				Full     => Full(i),
				DataIn   => DataIn,
				IndexOut => IndexOut(i),

				-- Get Port
				Got      => Got,
				Valid    => Valid,
				IndexIn  => resize(unsigned(Out_S2M_write(i).BID), IndexOut(0)'length),
				DataOut  => DataOut
			);

			Got    <= Out_S2M_write(i).BValid and Mux_In_S2M(i).Ready;
			DataIn <= In_M2S_write.AWID;

			Mux_In_M2S(i).Valid <= Out_S2M_write(i).BValid;
			Mux_In_M2S(i).Data(high(BACKWARD_BIT_VEC, B_Resp_POS) downto low(BACKWARD_BIT_VEC, B_Resp_POS)) <= Out_S2M_write(i).BResp;
			Mux_In_M2S(i).Data(high(BACKWARD_BIT_VEC, B_ID_POS)   downto low(BACKWARD_BIT_VEC, B_ID_POS))   <= std_logic_vector(DataOut);
			Mux_In_M2S(i).Data(high(BACKWARD_BIT_VEC, B_User_POS) downto low(BACKWARD_BIT_VEC, B_User_POS)) <= Out_S2M_write(i).BUser;
			-- Mux_In_M2S(i).SoF  <= '1';
			Mux_In_M2S(i).Last  <= '1';

			Write_Response_Error(i) <= Got and not Valid when rising_edge(Clock);
			assert Write_Response_Error(i) = '0' report "PoC.axi4_DeMux:: Got write response on channel '" & integer'image(i) & "' but no matching index!" severity warning;
		end generate;

		process(Clock)
		begin
			if rising_edge(Clock) then
				if Reset = '1' then
					State <= St_Idle;
				else
					State <= NextState;
				end if;
			end if;
		end process;

		process(all)
			variable SelectIndex : integer;
		begin
			NextState     <= State;

			In_S2M_write  <= Initialize_AXI4_Bus_S2M(In_M2S.AWAddr'length, In_S2M.RData'length, In_S2M.RUser'length, In_S2M.BID'length, '0');
			Out_M2S_write <= (Out_M2S'range => In_M2S_write);

			for i in 0 to PORTS -1 loop
				Out_M2S_write(i).AWValid <= '0';
				Out_M2S_write(i).WValid  <= '0';
				Out_M2S_write(i).AWID   <= to_slv(resize(IndexOut(i), Out_AW_ID_BITS)); -- Have AWID always connected to OoO Index
			end loop;

			Response_fifo_put <= '0';

			Put    <= (others => '0');

			case State is
				when St_Idle =>
					SelectIndex := lssb_idx(Address_hit);

					if In_M2S_write.AWValid = '1' then
						if unsigned(Address_hit) = 0 then
							Response_fifo_put <= '1';
							In_S2M_write.AWReady <= '1';
							In_S2M_write.WReady  <= '1';

							if (In_M2S_write.WValid or In_M2S_write.WLast) = '0' then
								NextState <= St_DiscardData;
							end if;
						elsif Full(SelectIndex) = '0' then
							In_S2M_write <= Out_S2M_write(SelectIndex);
							Out_M2S_write(SelectIndex).AWValid <= In_M2S_write.AWValid;
							Out_M2S_write(SelectIndex).WValid  <= In_M2S_write.WValid;

							Put(SelectIndex) <= '1';

							if (Out_S2M_write(SelectIndex).AWReady and In_M2S_write.WValid and In_M2S_write.WLast and Out_S2M_write(SelectIndex).WReady) = '1' then -- Full transaction closed in my cycle, stay in Idle
							elsif (Out_S2M_write(SelectIndex).AWReady) = '1' then -- Address transmitted
								NextState <= ST_DataOnly;
							elsif (In_M2S_write.WValid and In_M2S_write.WLast and Out_S2M_write(SelectIndex).WReady) = '1' then -- Data transmitted
								NextState <= ST_AddressOnly;
							else
								NextState <= ST_Dataflow;
							end if;
						end if;
					end if;

				when ST_Dataflow =>
					In_S2M_write <= Out_S2M_write(SelectIndex);
					Out_M2S_write(SelectIndex).AWValid <= In_M2S_write.AWValid;
					Out_M2S_write(SelectIndex).WValid  <= In_M2S_write.WValid;

					if (In_M2S_write.AWValid and Out_S2M_write(SelectIndex).AWReady and In_M2S_write.WValid and In_M2S_write.WLast and Out_S2M_write(SelectIndex).WReady) = '1' then -- Full transaction closed
						NextState <= St_Idle;
					elsif (In_M2S_write.AWValid and Out_S2M_write(SelectIndex).AWReady) = '1' then -- Address transmitted
						NextState <= ST_DataOnly;
					elsif (In_M2S_write.WValid and In_M2S_write.WLast and Out_S2M_write(SelectIndex).WReady) = '1' then -- Data transmitted
						NextState <= ST_AddressOnly;
					end if;

				when ST_DataOnly =>
					In_S2M_write         <= Out_S2M_write(SelectIndex);
					In_S2M_write.AWReady <= '0';
					Out_M2S_write(SelectIndex).WValid  <= In_M2S_write.WValid;

					if (In_M2S_write.WValid and In_M2S_write.WLast and Out_S2M_write(SelectIndex).WReady) = '1' then -- Data transmitted
						NextState <= St_Idle;
					end if;

				when ST_AddressOnly =>
					In_S2M_write        <= Out_S2M_write(SelectIndex);
					In_S2M_write.WReady <= '0';
					Out_M2S_write(SelectIndex).AWValid <= In_M2S_write.AWValid;

					if (In_M2S_write.AWValid and Out_S2M_write(SelectIndex).AWReady) = '1' then -- Address transmitted
						NextState <= St_Idle;
					end if;

				when St_DiscardData =>
					In_S2M_write.WReady  <= '1';

					if (In_M2S_write.WValid and In_M2S_write.WLast) = '1' then
						NextState <= St_Idle;
					end if;
			end case;


			-- Connect Write Response
			In_S2M_write.BValid   <= Mux_Out_M2S.Valid;
			In_S2M_write.BResp <= Mux_Out_M2S.Data(high(BACKWARD_BIT_VEC, B_Resp_POS) downto low(BACKWARD_BIT_VEC, B_Resp_POS));
			In_S2M_write.BID   <= Mux_Out_M2S.Data(high(BACKWARD_BIT_VEC, B_ID_POS)   downto low(BACKWARD_BIT_VEC, B_ID_POS));
			In_S2M_write.BUser <= Mux_Out_M2S.Data(high(BACKWARD_BIT_VEC, B_User_POS) downto low(BACKWARD_BIT_VEC, B_User_POS));
			for i in 0 to PORTS -1 loop
				Out_M2S_write(i).BReady <= Mux_In_S2M(i).Ready;
			end loop;
		end process;

		Write_Mux : entity work.axi4stream_Mux
		generic map(
			PORTS    => PORTS +1
		)
		port map(
			Clock    => Clock,
			Reset    => Reset,

			In_M2S   => Mux_In_M2S,
			In_S2M   => Mux_In_S2M,
			Out_M2S  => Mux_Out_M2S,
			Out_S2M  => Mux_Out_S2M
		);
		Mux_Out_S2M.Ready <= In_M2S_write.BReady;

		Response_fifo : entity work.fifo_Shift
		generic map(
			DATA_BITS    => ID_BITS,
			MIN_DEPTH => RESPONSE_FIFO_DEPTH
		)
		port map(
			-- Global Control
			Clock => Clock,
			Reset => Reset,

			-- Writing Interface
			Put => Response_fifo_put,
			DataIn => In_M2S_write.ARID,
			Full => Response_fifo_ful,

			-- Reading Interface
			Got  => Response_fifo_got,
			DataOut => Response_fifo_dout,
			Valid  => Response_fifo_vld
		);

		Mux_In_M2S(PORTS).Valid <= Response_fifo_vld;
		Response_fifo_got <= Mux_In_S2M(PORTS).Ready;
		Mux_In_M2S(PORTS).Data(high(BACKWARD_BIT_VEC, B_Resp_POS) downto low(BACKWARD_BIT_VEC, B_Resp_POS)) <= C_AXI4_RESPONSE_DECODE_ERROR;
		Mux_In_M2S(PORTS).Data(high(BACKWARD_BIT_VEC, B_ID_POS)   downto low(BACKWARD_BIT_VEC, B_ID_POS))   <= Response_fifo_dout;
		Mux_In_M2S(PORTS).Data(high(BACKWARD_BIT_VEC, B_User_POS) downto low(BACKWARD_BIT_VEC, B_User_POS)) <= (others => '0');
	end block;

	read_blk : block
		constant NUM_INDEX         : natural := ite(NUM_OUTSTANDING_READS = 0, 2**(Out_M2S(Out_M2S'low).ARID'length), NUM_OUTSTANDING_READS);

		constant AR_Addr_POS       : natural  := 0;
		constant AR_Len_POS        : natural  := 1;
		constant AR_Size_POS       : natural  := 2;
		constant AR_Burst_POS      : natural  := 3;
		constant AR_User_POS       : natural  := 4;
		constant AR_Cache_POS      : natural  := 5;
		constant AR_Protect_POS    : natural  := 6;
		constant AR_Lock_POS       : natural  := 7;
		constant AR_QoS_POS        : natural  := 8;
		constant AR_Region_POS     : natural  := 9;
		constant AR_ID_POS         : natural  := 10;

		constant FORWARD_BIT_VEC   : positive_vector := (
			AR_Addr_POS   => ADDRESS_BITS,
			AR_Len_POS    => LEN_BITS    ,
			AR_Size_POS   => SIZE_BITS   ,
			AR_Burst_POS  => BURST_BITS  ,
			AR_ID_POS     => ID_BITS     ,
			AR_User_POS   => USER_BITS   ,
			AR_Cache_POS  => CACHE_BITS  ,
			AR_Protect_POS=> PROTECT_BITS,
			AR_Lock_POS   => LOCK_BITS   ,
			AR_QoS_POS    => QOS_BITS    ,
			AR_Region_POS => REGION_BITS
		);

		constant R_Data_POS     : natural  := 0;
		constant R_Resp_POS     : natural  := 1;
		constant R_ID_POS       : natural  := 2;
		constant R_User_POS     : natural  := 3;

		constant BACKWARD_BIT_VEC   : positive_vector := (
			R_Data_POS  => DATA_BITS,
			R_Resp_POS  => RESPONSE_BITS,
			R_ID_POS    => ID_BITS,
			R_User_POS  => USER_BITS
		);

		signal Address_hit  : std_logic_vector(PORTS -1 downto 0);
		signal DeMuxControl : std_logic_vector(PORTS -1 downto 0);

		constant MUX_DATA_BITS   : natural := isum(BACKWARD_BIT_VEC);
		constant DeMUX_DATA_BITS : natural := isum(FORWARD_BIT_VEC);

		signal DeMux_In_M2S             : T_AXI4STREAM_M2S(Data(DeMUX_DATA_BITS - 1 downto 0), Keep(0 downto 0), User(0 downto 0), ID(0 downto 0), Dest(0 downto 0));
		signal DeMux_In_S2M             : T_AXI4STREAM_S2M(User(0 downto 0));
		signal DeMux_Out_M2S            : T_AXI4STREAM_M2S_VECTOR(0 to PORTS -1)(Data(DeMUX_DATA_BITS - 1 downto 0), Keep(0 downto 0), User(0 downto 0), ID(0 downto 0), Dest(0 downto 0));
		signal DeMux_Out_S2M            : T_AXI4STREAM_S2M_VECTOR(0 to PORTS -1)(User(0 downto 0));

		signal Mux_In_M2S               : T_AXI4STREAM_M2S_VECTOR(0 to PORTS)(Data(MUX_DATA_BITS - 1 downto 0), Keep(0 downto 0), User(0 downto 0), ID(0 downto 0), Dest(0 downto 0));
		signal Mux_In_S2M               : T_AXI4STREAM_S2M_VECTOR(0 to PORTS)(User(0 downto 0));
		signal Mux_Out_M2S              : T_AXI4STREAM_M2S(Data(MUX_DATA_BITS - 1 downto 0), Keep(0 downto 0), User(0 downto 0), ID(0 downto 0), Dest(0 downto 0));
		signal Mux_Out_S2M              : T_AXI4STREAM_S2M(User(0 downto 0));

		signal Response_fifo_put  : std_logic;
		signal Response_fifo_ful  : std_logic;
		signal Response_fifo_got  : std_logic;
		signal Response_fifo_dout : std_logic_vector(ID_BITS-1 downto 0);
		signal Response_fifo_vld  : std_logic;
	begin


		assign_gen : for i in 0 to PORTS -1 generate
			signal Put      : std_logic;
			signal Full     : std_logic;
			signal DataIn   : std_logic_vector(ID_BITS -1 downto 0);
			signal IndexOut : unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);
			signal Got      : std_logic;
			signal DataOut  : std_logic_vector(ID_BITS -1 downto 0);
		begin
			Address_hit(i)   <= '1' when (unsigned(In_M2S_read.ARAddr) and not BASE_ADDRESS_MASK(i)) = (Base_Address(i) and not BASE_ADDRESS_MASK(i)) else '0';

			Out_M2S_read(i).ARID             <= std_logic_vector(resize(IndexOut, Out_AR_ID_BITS));
			Out_M2S_read(i).ARValid          <= DeMux_Out_M2S(i).Valid and not Full;

			Out_M2S_read(i).ARAddr           <= resize(DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_Addr_POS) downto low(FORWARD_BIT_VEC, AR_Addr_POS)), ADDR_BITS_SLAVE);
			Out_M2S_read(i).ARCache          <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_Cache_POS) downto low(FORWARD_BIT_VEC, AR_Cache_POS));
			Out_M2S_read(i).ARProt           <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_Protect_POS) downto low(FORWARD_BIT_VEC, AR_Protect_POS));
			Out_M2S_read(i).ARLen            <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_Len_POS) downto low(FORWARD_BIT_VEC, AR_Len_POS));
			Out_M2S_read(i).ARSize           <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_Size_POS) downto low(FORWARD_BIT_VEC, AR_Size_POS));
			Out_M2S_read(i).ARBurst          <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_Burst_POS) downto low(FORWARD_BIT_VEC, AR_Burst_POS));
			Out_M2S_read(i).ARLock           <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_Lock_POS) downto low(FORWARD_BIT_VEC, AR_Lock_POS));
			Out_M2S_read(i).ARQOS            <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_QoS_POS) downto low(FORWARD_BIT_VEC, AR_QoS_POS));
			Out_M2S_read(i).ARRegion         <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_Region_POS) downto low(FORWARD_BIT_VEC, AR_Region_POS));
			Out_M2S_read(i).ARUser           <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_User_POS) downto low(FORWARD_BIT_VEC, AR_User_POS));
			DataIn(ID_BITS -1 downto 0)      <= DeMux_Out_M2S(i).Data(high(FORWARD_BIT_VEC, AR_ID_POS) downto low(FORWARD_BIT_VEC, AR_ID_POS));
			DeMux_Out_S2M(i).Ready           <= Out_S2M_read(i).ARReady and not Full;

			Put                              <= DeMux_Out_M2S(i).Valid and Out_S2M_read(i).ARReady and not Full;
			Got                              <= Mux_In_S2M(i).Ready and Out_S2M_read(i).RValid and Out_S2M_read(i).RLast;

			Out_M2S_read(i).RReady           <= Mux_In_S2M(i).Ready;

			Mux_In_M2S(i).Valid              <= Out_S2M_read(i).RValid;

			Mux_In_M2S(i).Data(high(BACKWARD_BIT_VEC, R_Data_POS) downto low(BACKWARD_BIT_VEC, R_Data_POS)) <= Out_S2M_read(i).RData   ;
			Mux_In_M2S(i).Data(high(BACKWARD_BIT_VEC, R_Resp_POS) downto low(BACKWARD_BIT_VEC, R_Resp_POS)) <= Out_S2M_read(i).RResp   ;
			Mux_In_M2S(i).Data(high(BACKWARD_BIT_VEC, R_ID_POS)   downto low(BACKWARD_BIT_VEC, R_ID_POS))   <= DataOut   ;
			Mux_In_M2S(i).Data(high(BACKWARD_BIT_VEC, R_User_POS) downto low(BACKWARD_BIT_VEC, R_User_POS)) <= Out_S2M_read(i).RUser   ;
			Mux_In_M2S(i).Last  <= Out_S2M_read(i).RLast;

			Read_idx : entity work.dstruct_OutOfOrderBuffer
			generic map(
				DATA_BITS => ID_BITS,
				NUM_INDEX => NUM_INDEX
			)
			port map(
				-- INPUTS
				Clock => Clock,
				Reset => Reset,

				-- Put Port
				Put      => Put,
				Full     => Full,
				DataIn   => DataIn,
				IndexOut => IndexOut,

				-- Get Port
				Got      => Got,
				Valid    => open,
				IndexIn  => resize(unsigned(Out_S2M_read(i).RID), IndexOut'length),
				DataOut  => DataOut
			);
		end generate;

		Read_mux : entity work.axi4stream_Mux
		generic map(
			PORTS    => PORTS +1
		)
		port map(
			Clock    => Clock,
			Reset    => Reset,

			In_M2S   => Mux_In_M2S,
			In_S2M   => Mux_In_S2M,
			Out_M2S  => Mux_Out_M2S,
			Out_S2M  => Mux_Out_S2M
		);

		In_S2M_read.RValid   <= Mux_Out_M2S.Valid;
		In_S2M_read.RLast    <= Mux_Out_M2S.Last;
		Mux_Out_S2M.Ready <= In_M2S_read.RReady;

		In_S2M_read.RData       <= Mux_Out_M2S.Data(high(BACKWARD_BIT_VEC, R_Data_POS) downto low(BACKWARD_BIT_VEC, R_Data_POS));
		In_S2M_read.RResp       <= Mux_Out_M2S.Data(high(BACKWARD_BIT_VEC, R_Resp_POS) downto low(BACKWARD_BIT_VEC, R_Resp_POS));
		In_S2M_read.RID         <= Mux_Out_M2S.Data(high(BACKWARD_BIT_VEC, R_ID_POS  ) downto low(BACKWARD_BIT_VEC, R_ID_POS  ));
		In_S2M_read.RUser       <= Mux_Out_M2S.Data(high(BACKWARD_BIT_VEC, R_User_POS) downto low(BACKWARD_BIT_VEC, R_User_POS));

		DeMuxControl <= lssb(Address_hit);

		Read_DeMux : entity work.axi4stream_DeMux
		port map(
			Clock             => Clock,
			Reset             => Reset,
			-- Control interface
			DeMuxControl      => DeMuxControl,
			-- IN Port
			In_M2S            => DeMux_In_M2S,
			In_S2M            => DeMux_In_S2M,
			-- OUT Ports
			Out_M2S           => DeMux_Out_M2S,
			Out_S2M           => DeMux_Out_S2M
		);

		DeMux_In_M2S.Valid <= In_M2S_read.ARValid and not Response_fifo_ful;
		DeMux_In_M2S.Last  <= '1';
		In_S2M_read.ARReady   <= DeMux_In_S2M.Ready and not Response_fifo_ful;

		Response_fifo : entity work.fifo_Shift
		generic map(
			DATA_BITS    => ID_BITS,
			MIN_DEPTH => RESPONSE_FIFO_DEPTH
		)
		port map(
			-- Global Control
			Clock => Clock,
			Reset => Reset,

			-- Writing Interface
			Put => Response_fifo_put,
			DataIn => In_M2S_read.ARID,
			Full => Response_fifo_ful,

			-- Reading Interface
			Got  => Response_fifo_got,
			DataOut => Response_fifo_dout,
			Valid  => Response_fifo_vld
		);

		Response_fifo_put <= '1' when (In_M2S_read.ARValid and DeMux_In_S2M.Ready) = '1' and unsigned(Address_hit) = 0 else '0';

		Mux_In_M2S(PORTS).Valid <= Response_fifo_vld;
		-- Mux_In_M2S(PORTS).SOF   <= '1';
		Mux_In_M2S(PORTS).Last   <= '1';
		Response_fifo_got <= Mux_In_S2M(PORTS).Ready;
		Mux_In_M2S(PORTS).Data(high(BACKWARD_BIT_VEC, R_Data_POS) downto low(BACKWARD_BIT_VEC, R_Data_POS)) <= (others => '0');
		Mux_In_M2S(PORTS).Data(high(BACKWARD_BIT_VEC, R_Resp_POS) downto low(BACKWARD_BIT_VEC, R_Resp_POS)) <= C_AXI4_RESPONSE_DECODE_ERROR;
		Mux_In_M2S(PORTS).Data(high(BACKWARD_BIT_VEC, R_ID_POS)   downto low(BACKWARD_BIT_VEC, R_ID_POS))   <= Response_fifo_dout;
		Mux_In_M2S(PORTS).Data(high(BACKWARD_BIT_VEC, R_User_POS) downto low(BACKWARD_BIT_VEC, R_User_POS)) <= (others => '0');


		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_Addr_POS   ) downto low(FORWARD_BIT_VEC, AR_Addr_POS   )) <= resize(In_M2S_read.ARAddr, ADDRESS_BITS)  ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_Len_POS    ) downto low(FORWARD_BIT_VEC, AR_Len_POS    )) <= In_M2S_read.ARLen   ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_Size_POS   ) downto low(FORWARD_BIT_VEC, AR_Size_POS   )) <= In_M2S_read.ARSize  ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_Burst_POS  ) downto low(FORWARD_BIT_VEC, AR_Burst_POS  )) <= In_M2S_read.ARBurst ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_User_POS   ) downto low(FORWARD_BIT_VEC, AR_User_POS   )) <= In_M2S_read.ARUser  ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_Cache_POS  ) downto low(FORWARD_BIT_VEC, AR_Cache_POS  )) <= In_M2S_read.ARCache ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_Protect_POS) downto low(FORWARD_BIT_VEC, AR_Protect_POS)) <= In_M2S_read.ARProt  ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_Lock_POS   ) downto low(FORWARD_BIT_VEC, AR_Lock_POS   )) <= In_M2S_read.ARLock  ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_QoS_POS    ) downto low(FORWARD_BIT_VEC, AR_QoS_POS    )) <= In_M2S_read.ARQoS   ;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_Region_POS ) downto low(FORWARD_BIT_VEC, AR_Region_POS )) <= In_M2S_read.ARRegion;
		DeMux_In_M2S.Data(high(FORWARD_BIT_VEC, AR_ID_POS     ) downto low(FORWARD_BIT_VEC, AR_ID_POS     )) <= In_M2S_read.ARID    ;


	end block;

	assign_gen : for i in 0 to PORTS - 1 generate
		Out_M2S_g(i).AWID     <= Out_M2S_write(i).AWID    ;
		Out_M2S_g(i).AWAddr   <= Out_M2S_write(i).AWAddr  ;
		Out_M2S_g(i).AWLen    <= Out_M2S_write(i).AWLen   ;
		Out_M2S_g(i).AWSize   <= Out_M2S_write(i).AWSize  ;
		Out_M2S_g(i).AWBurst  <= Out_M2S_write(i).AWBurst ;
		Out_M2S_g(i).AWLock   <= Out_M2S_write(i).AWLock  ;
		Out_M2S_g(i).AWQOS    <= Out_M2S_write(i).AWQOS   ;
		Out_M2S_g(i).AWRegion <= Out_M2S_write(i).AWRegion;
		Out_M2S_g(i).AWUser   <= Out_M2S_write(i).AWUser  ;
		Out_M2S_g(i).AWValid  <= Out_M2S_write(i).AWValid ;
		Out_M2S_g(i).AWCache  <= Out_M2S_write(i).AWCache ;
		Out_M2S_g(i).AWProt   <= Out_M2S_write(i).AWProt  ;
		Out_M2S_g(i).WValid   <= Out_M2S_write(i).WValid  ;
		Out_M2S_g(i).WLast    <= Out_M2S_write(i).WLast   ;
		Out_M2S_g(i).WUser    <= Out_M2S_write(i).WUser   ;
		Out_M2S_g(i).WData    <= Out_M2S_write(i).WData   ;
		Out_M2S_g(i).WStrb    <= Out_M2S_write(i).WStrb   ;
		Out_M2S_g(i).BReady   <= Out_M2S_write(i).BReady  ;
		Out_M2S_g(i).ARValid  <= Out_M2S_read(i).ARValid  ;
		Out_M2S_g(i).ARAddr   <= Out_M2S_read(i).ARAddr   ;
		Out_M2S_g(i).ARCache  <= Out_M2S_read(i).ARCache  ;
		Out_M2S_g(i).ARProt   <= Out_M2S_read(i).ARProt   ;
		Out_M2S_g(i).ARID     <= Out_M2S_read(i).ARID     ;
		Out_M2S_g(i).ARLen    <= Out_M2S_read(i).ARLen    ;
		Out_M2S_g(i).ARSize   <= Out_M2S_read(i).ARSize   ;
		Out_M2S_g(i).ARBurst  <= Out_M2S_read(i).ARBurst  ;
		Out_M2S_g(i).ARLock   <= Out_M2S_read(i).ARLock   ;
		Out_M2S_g(i).ARQOS    <= Out_M2S_read(i).ARQOS    ;
		Out_M2S_g(i).ARRegion <= Out_M2S_read(i).ARRegion ;
		Out_M2S_g(i).ARUser   <= Out_M2S_read(i).ARUser   ;
		Out_M2S_g(i).RReady   <= Out_M2S_read(i).RReady   ;

		Out_S2M_write(i).AWReady <= Out_S2M_g(i).AWReady;
		Out_S2M_write(i).WReady  <= Out_S2M_g(i).WReady ;
		Out_S2M_write(i).BValid  <= Out_S2M_g(i).BValid ;
		Out_S2M_write(i).BResp   <= Out_S2M_g(i).BResp  ;
		Out_S2M_write(i).BID     <= Out_S2M_g(i).BID    ;
		Out_S2M_write(i).BUser   <= Out_S2M_g(i).BUser  ;
		Out_S2M_read(i).ARReady  <= Out_S2M_g(i).ARReady;
		Out_S2M_read(i).RValid   <= Out_S2M_g(i).RValid ;
		Out_S2M_read(i).RData    <= Out_S2M_g(i).RData  ;
		Out_S2M_read(i).RResp    <= Out_S2M_g(i).RResp  ;
		Out_S2M_read(i).RID      <= Out_S2M_g(i).RID    ;
		Out_S2M_read(i).RLast    <= Out_S2M_g(i).RLast  ;
		Out_S2M_read(i).RUser    <= Out_S2M_g(i).RUser  ;
	end generate;

	In_M2S_write.AWID     <= In_M2S_g.AWID    ;
	In_M2S_write.AWAddr   <= In_M2S_g.AWAddr  ;
	In_M2S_write.AWLen    <= In_M2S_g.AWLen   ;
	In_M2S_write.AWSize   <= In_M2S_g.AWSize  ;
	In_M2S_write.AWBurst  <= In_M2S_g.AWBurst ;
	In_M2S_write.AWLock   <= In_M2S_g.AWLock  ;
	In_M2S_write.AWQOS    <= In_M2S_g.AWQOS   ;
	In_M2S_write.AWRegion <= In_M2S_g.AWRegion;
	In_M2S_write.AWUser   <= In_M2S_g.AWUser  ;
	In_M2S_write.AWValid  <= In_M2S_g.AWValid ;
	In_M2S_write.AWCache  <= In_M2S_g.AWCache ;
	In_M2S_write.AWProt   <= In_M2S_g.AWProt  ;
	In_M2S_write.WValid   <= In_M2S_g.WValid  ;
	In_M2S_write.WLast    <= In_M2S_g.WLast   ;
	In_M2S_write.WUser    <= In_M2S_g.WUser   ;
	In_M2S_write.WData    <= In_M2S_g.WData   ;
	In_M2S_write.WStrb    <= In_M2S_g.WStrb   ;
	In_M2S_write.BReady   <= In_M2S_g.BReady  ;
	In_M2S_read.ARValid   <= In_M2S_g.ARValid ;
	In_M2S_read.ARAddr    <= In_M2S_g.ARAddr  ;
	In_M2S_read.ARCache   <= In_M2S_g.ARCache ;
	In_M2S_read.ARProt    <= In_M2S_g.ARProt  ;
	In_M2S_read.ARID      <= In_M2S_g.ARID    ;
	In_M2S_read.ARLen     <= In_M2S_g.ARLen   ;
	In_M2S_read.ARSize    <= In_M2S_g.ARSize  ;
	In_M2S_read.ARBurst   <= In_M2S_g.ARBurst ;
	In_M2S_read.ARLock    <= In_M2S_g.ARLock  ;
	In_M2S_read.ARQOS     <= In_M2S_g.ARQOS   ;
	In_M2S_read.ARRegion  <= In_M2S_g.ARRegion;
	In_M2S_read.ARUser    <= In_M2S_g.ARUser  ;
	In_M2S_read.RReady    <= In_M2S_g.RReady  ;

	In_S2M_g.AWReady <= In_S2M_write.AWReady;
	In_S2M_g.WReady  <= In_S2M_write.WReady ;
	In_S2M_g.BValid  <= In_S2M_write.BValid ;
	In_S2M_g.BResp   <= In_S2M_write.BResp  ;
	In_S2M_g.BID     <= In_S2M_write.BID    ;
	In_S2M_g.BUser   <= In_S2M_write.BUser  ;
	In_S2M_g.ARReady <= In_S2M_read.ARReady ;
	In_S2M_g.RValid  <= In_S2M_read.RValid  ;
	In_S2M_g.RData   <= In_S2M_read.RData   ;
	In_S2M_g.RResp   <= In_S2M_read.RResp   ;
	In_S2M_g.RID     <= In_S2M_read.RID     ;
	In_S2M_g.RLast   <= In_S2M_read.RLast   ;
	In_S2M_g.RUser   <= In_S2M_read.RUser   ;
end architecture;
