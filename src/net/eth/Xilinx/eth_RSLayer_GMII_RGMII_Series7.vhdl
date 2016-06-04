-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- ============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Entity:				 	TODO
--
-- Description:
-- ------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- ============================================================================
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
-- ============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library UNISIM;
use			UNISIM.VCOMPONENTS.all;

library PoC;
use			PoC.config.all;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.net.all;


entity eth_RSLayer_GMII_GMII_Xilinx is
	port (
		LinkStatus							: out		STD_LOGIC;
		LinkSpeed								: out		T_SLV_2;
		DuplexStatus						: out		STD_LOGIC;

		-- RS-GMII interface
		RS_TX_Clock							: in		STD_LOGIC;
		RS_TX_Clock90						: in		STD_LOGIC;
		RS_TX_Reset							: in		STD_LOGIC;
		RS_TX_Valid							: in		STD_LOGIC;
		RS_TX_Data							: in		T_SLV_8;
		RS_TX_Error							: in		STD_LOGIC;

		RS_RX_Clock							: in		STD_LOGIC;
		RS_RX_Reset							: in		STD_LOGIC;
		RS_RX_Valid							: out		STD_LOGIC;
		RS_RX_Data							: out		T_SLV_8;
		RS_RX_Error							: out		STD_LOGIC;

		-- PHY-GMII interface
		PHY_Interface						: inout	T_NET_ETH_PHY_INTERFACE_GMII
	);
end;

-- Note:
-- ============================================================================================================================================================
-- use IDELAY instances on GMII_RX_Clock to move the clock into alignment with the data (GMII_RX_Data[7:0])

architecture rtl of eth_RSLayer_GMII_GMII_Xilinx is
	attribute KEEP							: BOOLEAN;

	signal RS_TX_Reset90				: STD_LOGIC;
	signal RX_Clock							: STD_LOGIC;
begin
	-- Transmitter Clock
	-- ==========================================================================================================================================================
	-- Instantiate a DDR output register.  This is a good way to drive
	-- GMII_TX_Clock since the clock-to-PAD delay will be the same as that for
	-- data driven from IOB Ouput flip-flops eg GMII_TX_Data[7:0].
	sync_TX_Reset90 : entity PoC.sync_Bits_Xilinx
		port map (
			Clock		=> RS_TX_Clock90,
			Input		=> RS_TX_Reset,
			Output	=> RS_TX_Reset90
		);

  TX_Clock_ODDR : ODDR
		generic map (
			DDR_CLK_EDGE	=> "SAME_EDGE"
		)
		port map (
			Q		=> PHY_Interface.TX_Clock,
			C		=> RS_TX_Clock90,
			CE	=> '1',
			D1	=> '1',
			D2	=> '0',
			R		=> RS_TX_Reset90,
			S		=> '0'
  );

	-- Receiver Clock
	-- ==========================================================================================================================================================
	BUFIO_RX_Clock : BUFIO
		port map (
			I								=> PHY_Interface.RX_Clock,
			O								=> RX_Clock
		);

	BUFR_RX_Clock : BUFR
		port map (
			I								=> PHY_Interface.RX_Clock,
			O								=> PHY_Interface.RX_RefClock
		);

	-- Output Logic : Drive TX signals through IOBs onto PHY-GMII interface
	-- ==========================================================================================================================================================
	blkTX : block
		signal TX_Data_rising		: T_SLV_4;
		signal TX_Data_falling	: T_SLV_4;
		signal TX_Control				: STD_LOGIC;

	begin
		TX_Data_rising		<= RS_TX_Data(3 downto 0);
		TX_Data_falling		<= RS_TX_Data(7 downto 4);
		TX_Control				<= RS_TX_Valid xor RS_TX_Error;

		genTXDDR : for i in 0 to 3 generate
			TX_Data_ODDR : ODDR
				generic map (
					DDR_CLK_EDGE	=> "SAME_EDGE"
				)
				port map (
					Q		=> PHY_Interface.TX_Data(i),
					C		=> RS_TX_Clock,
					CE	=> '1',
					D1	=> TX_Data_rising(i),
					D2	=> TX_Data_falling(i),
					R		=> RS_TX_Reset,
					S		=> '0'
				);
		end generate;

		TX_Control_ODDR : ODDR
			generic map (
				DDR_CLK_EDGE	=> "SAME_EDGE"
			)
			port map (
				Q		=> PHY_Interface.TX_Control,
				C		=> RS_TX_Clock,
				CE	=> '1',
				D1	=> RS_TX_Valid,
				D2	=> TX_Control,
				R		=> RS_TX_Reset,
				S		=> '0'
			);
	end block;


	-- Input Logic : Receive RX signals through IDELAYs and IOBs from PHY-GMII interface
	-- ==========================================================================================================================================================
	-- please modify the value of the IOBDELAYs according to your design.
	-- for more information on IDELAYCTRL and IODELAY, please refer to the Series-7 User Guide.
	blkRX : block
		signal IDelay_DataIn		: STD_LOGIC_VECTOR(4 downto 0);
		signal IDelay_DataOut		: STD_LOGIC_VECTOR(4 downto 0);

		signal RX_Data_rising		: T_SLV_4;
		signal RX_Data_falling	: T_SLV_4;
		signal RX_Control				: STD_LOGIC;

	begin
		IDelay_DataIn(3 downto 0)	<= PHY_Interface.RX_Data;
		IDelay_DataIn(4)					<= PHY_Interface.RX_Control;

		genIDelay : for i in 0 to 4 generate
			dly : IDELAYE1
				generic map (
					IOBDELAY_TYPE		=> "FIXED",
					DELAY_SRC				=> "I"
				)
				port map (
					IDATAIN					=> IDelay_DataIn(i),
					ODATAIN					=> '0',
					DATAOUT					=> IDelay_DataOut(i),
					DATAIN					=> '0',
					C								=> '0',
					T								=> '1',
					CE							=> '0',
					INC							=> '0',
					CINVCTRL				=> '0',
					CLKIN						=> '0',
					CNTVALUEIN			=> "00000",
					CNTVALUEOUT			=> open,
					RST							=> '0'
				);
		end generate;

		genIDDR : for i in 0 to 3 generate
			DDR : IDDR
				generic map (
					DDR_CLK_EDGE	=> "SAME_EDGE_PIPELINED"
				)
				port map (
					C		=> RX_Clock,
					CE	=> '1',
					R		=> '0',
					S		=> '0',
					D		=> IDelay_DataOut(i),
					Q1	=> RX_Data_rising(i),
					Q2	=> RX_Data_falling(i)
				);
		end generate;

		IDDR_RX_Control : IDDR
			generic map (
				DDR_CLK_EDGE	=> "SAME_EDGE_PIPELINED"
			)
			port map (
				C		=> RX_Clock,
				CE	=> '1',
				R		=> '0',
				S		=> '0',
				D		=> IDelay_DataOut(4),
				Q1	=> RX_Valid,
				Q2	=> RX_Control
			);

		RS_RX_Data(3 downto 0)		<= RX_Data_rising;
		RS_RX_Data(7 downto 4)		<= RX_Data_falling;
		RS_RX_Valid								<= RX_Valid;
		RS_RX_Error								<= RX_Valid xor RX_Control;


		process(RS_RX_Clock)
		begin
			if rising_edge(RX_Clock) then
				if (RS_RX_Reset = '1') then
					LinkStatus		<= '0';
					LinkSpeed			<= "00";
					DuplexStatus	<= '0';
				elsif (Inband_ce = '1') then
					LinkStatus		<= RX_Data_rising(0);
					LinkSpeed			<= RX_Data_rising(2 downto 1);
					DuplexStatus	<= RX_Data_rising(3);
				end if;
			end if;
		end process;

	end block;
end;
