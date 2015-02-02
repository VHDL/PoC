--
-- Entity: v5temac_gmii
-- Author(s): File created by Coregen from Xilinx (see below).
-- 
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2009-07-17 15:19:10 $
--

-------------------------------------------------------------------------------
-- Title      : Virtex-5 Ethernet MAC Wrapper
-------------------------------------------------------------------------------
-- File       : v5temac_gmii.v
-- Author     : Xilinx
-------------------------------------------------------------------------------
-- Copyright (c) 2004-2008 by Xilinx, Inc. All rights reserved.
-- This text/file contains proprietary, confidential
-- information of Xilinx, Inc., is distributed under license
-- from Xilinx, Inc., and may be used, copied and/or
-- disclosed only pursuant to the terms of a valid license
-- agreement with Xilinx, Inc. Xilinx hereby grants you
-- a license to use this text/file solely for design, simulation,
-- implementation and creation of design files limited
-- to Xilinx devices or technologies. Use with non-Xilinx
-- devices or technologies is expressly prohibited and
-- immediately terminates your license unless covered by
-- a separate agreement.
--
-- Xilinx is providing this design, code, or information
-- "as is" solely for use in developing programs and
-- solutions for Xilinx devices. By providing this design,
-- code, or information as one possible implementation of
-- this feature, application or standard, Xilinx is making no
-- representation that this implementation is free from any
-- claims of infringement. You are responsible for
-- obtaining any rights you may require for your implementation.
-- Xilinx expressly disclaims any warranty whatsoever with
-- respect to the adequacy of the implementation, including
-- but not limited to any warranties or representations that this
-- implementation is free from claims of infringement, implied
-- warranties of merchantability or fitness for a particular
-- purpose.
--
-- Xilinx products are not intended for use in life support
-- appliances, devices, or systems. Use in such applications are
-- expressly prohibited.
--
-- This copyright and support notice must be retained as part
-- of this text at all times. (c) Copyright 2004-2008 Xilinx, Inc.
-- All rights reserved.

--------------------------------------------------------------------------------
-- Description:  This wrapper file instantiates the full Virtex-5 Ethernet 
--               MAC (EMAC) primitive.  For one or both of the two Ethernet MACs
--               (EMAC0/EMAC1):
--
--               * all unused input ports on the primitive will be tied to the
--                 appropriate logic level;
--
--               * all unused output ports on the primitive will be left 
--                 unconnected;
--
--               * the Tie-off Vector will be connected based on the options 
--                 selected from CORE Generator;
--
--               * only used ports will be connected to the ports of this 
--                 wrapper file.
--
--               This simplified wrapper should therefore be used as the 
--               instantiation template for the EMAC in customer designs.
--------------------------------------------------------------------------------

library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------------------------------------
-- The entity declaration for the Virtex-5 Embedded Ethernet MAC wrapper.
--------------------------------------------------------------------------------

entity eth_TEMAC_GMII_Virtex5 is
    port(
        -- Client Receiver Interface - EMAC0
        EMAC0CLIENTRXCLIENTCLKOUT       : out std_logic;
        CLIENTEMAC0RXCLIENTCLKIN        : in  std_logic;
        EMAC0CLIENTRXD                  : out std_logic_vector(7 downto 0);
        EMAC0CLIENTRXDVLD               : out std_logic;
        EMAC0CLIENTRXDVLDMSW            : out std_logic;
        EMAC0CLIENTRXGOODFRAME          : out std_logic;
        EMAC0CLIENTRXBADFRAME           : out std_logic;
        EMAC0CLIENTRXFRAMEDROP          : out std_logic;
        EMAC0CLIENTRXSTATS              : out std_logic_vector(6 downto 0);
        EMAC0CLIENTRXSTATSVLD           : out std_logic;
        EMAC0CLIENTRXSTATSBYTEVLD       : out std_logic;

        -- Client Transmitter Interface - EMAC0
        EMAC0CLIENTTXCLIENTCLKOUT       : out std_logic;
        CLIENTEMAC0TXCLIENTCLKIN        : in  std_logic;
        CLIENTEMAC0TXD                  : in  std_logic_vector(7 downto 0);
        CLIENTEMAC0TXDVLD               : in  std_logic;
        CLIENTEMAC0TXDVLDMSW            : in  std_logic;
        EMAC0CLIENTTXACK                : out std_logic;
        CLIENTEMAC0TXFIRSTBYTE          : in  std_logic;
        CLIENTEMAC0TXUNDERRUN           : in  std_logic;
        EMAC0CLIENTTXCOLLISION          : out std_logic;
        EMAC0CLIENTTXRETRANSMIT         : out std_logic;
        CLIENTEMAC0TXIFGDELAY           : in  std_logic_vector(7 downto 0);
        EMAC0CLIENTTXSTATS              : out std_logic;
        EMAC0CLIENTTXSTATSVLD           : out std_logic;
        EMAC0CLIENTTXSTATSBYTEVLD       : out std_logic;

        -- MAC Control Interface - EMAC0
        CLIENTEMAC0PAUSEREQ             : in  std_logic;
        CLIENTEMAC0PAUSEVAL             : in  std_logic_vector(15 downto 0);

        -- Clock Signal - EMAC0
        GTX_CLK_0                       : in  std_logic;
        PHYEMAC0TXGMIIMIICLKIN          : in  std_logic;
        EMAC0PHYTXGMIIMIICLKOUT         : out std_logic;

        -- GMII Interface - EMAC0
        GMII_TXD_0                      : out std_logic_vector(7 downto 0);
        GMII_TX_EN_0                    : out std_logic;
        GMII_TX_ER_0                    : out std_logic;
        GMII_RXD_0                      : in  std_logic_vector(7 downto 0);
        GMII_RX_DV_0                    : in  std_logic;
        GMII_RX_ER_0                    : in  std_logic;
        GMII_RX_CLK_0                   : in  std_logic;

        DCM_LOCKED_0                    : in  std_logic;

        -- Asynchronous Reset
        RESET                           : in  std_logic
        );
end;


architecture rtl of eth_TEMAC_GMII_Virtex5 is
	
	signal TEMAC_TX_Ack							: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal TX_FSM_Valid							: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal TX_FSM_Data							: T_SLVV_8(PORTS - 1 downto 0);
	signal TX_FSM_UnderrunDetected	: STD_LOGIC_VECTOR(PORTS - 1 downto 0);

	signal TEMAC_RX_Valid						: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal TEMAC_RX_Data						: T_SLVV_8(PORTS - 1 downto 0);
	signal TEMAC_RX_GoodFrame				: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal TEMAC_RX_BadFrame				: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal RX_FSM_OverflowDetected	: STD_LOGIC_VECTOR(PORTS - 1 downto 0);

begin

	genFIFOChain : for i in 0 to PORTS - 1 generate
		constant SOF_BIT						: NATURAL			:= 8;
		constant EOF_BIT						: NATURAL			:= 9;
	
		signal XClk_TX_FIFO_Valid		: STD_LOGIC;
		signal XClk_TX_FIFO_DataOut	: STD_LOGIC_VECTOR(9 downto 0);
		signal XClk_TX_FIFO_got			: STD_LOGIC;

		signal TX_FIFO_DataOut			: STD_LOGIC_VECTOR(9 downto 0);
		signal TX_FIFO_Full					: STD_LOGIC;
		
		signal TX_FIFO_Valid				: STD_LOGIC;
		signal TX_FIFO_Data					: T_SLV_8;
		signal TX_FIFO_SOF					: STD_LOGIC;
		signal TX_FIFO_EOF					: STD_LOGIC;
		signal TX_FSM_Commit				: STD_LOGIC;
		signal TX_FSM_Rollback			: STD_LOGIC;
		
		signal TX_FSM_Ack						: STD_LOGIC;
		
		signal RX_FSM_Valid					: STD_LOGIC;
		signal RX_FSM_Data					: T_SLV_8;
		signal RX_FSM_SOF						: STD_LOGIC;
		signal RX_FSM_EOF						: STD_LOGIC;
		signal RX_FSM_Commit				: STD_LOGIC;
		signal RX_FSM_Rollback			: STD_LOGIC;
		
		signal RX_FIFO_put					: STD_LOGIC;
		signal RX_FIFO_DataIn				: STD_LOGIC_VECTOR(9 downto 0);
		signal RX_FIFO_Full					: STD_LOGIC;
		signal RX_FIFO_got					: STD_LOGIC;
		signal RX_FIFO_Valid				: STD_LOGIC;
		signal RX_FIFO_DataOut			: STD_LOGIC_VECTOR(9 downto 0);
		signal RX_FIFO_Ack					: STD_LOGIC;
		
		signal XClk_RX_FIFO_Full		: STD_LOGIC;


	begin
		-- ==========================================================================================================================================================
		-- ASSERT statements
		-- ==========================================================================================================================================================
		assert ((TX_FIFO_DEPTHS(i) * 1 Byte) >= ite(TX_ENABLE_UNDERRUN_PROTECTION(i),	ite(SUPPORT_JUMBO_FRAMES(i), 10 KiB, 1522 Byte), 0 Byte))	report "TX-FIFO is to small" severity ERROR;
		assert ((RX_FIFO_DEPTHS(i) * 1 Byte) >=																				ite(SUPPORT_JUMBO_FRAMES(i), 10 KiB, 1522 Byte))					report "RX-FIFO is to small" severity ERROR;

		-- ==========================================================================================================================================================
		-- TX path
		-- ==========================================================================================================================================================
		genTX_XClk0 : if (TX_INSERT_CROSSCLOCK_FIFO(i) = FALSE) generate
			XClk_TX_FIFO_Valid											<= TX_Valid(i);
			XClk_TX_FIFO_DataOut(TX_Data(i)'range)	<= TX_Data(i);
			XClk_TX_FIFO_DataOut(SOF_BIT)						<= TX_SOF(i);
			XClk_TX_FIFO_DataOut(EOF_BIT)						<= TX_EOF(i);
			TX_Ack(i)																<= XClk_TX_FIFO_got;
		end generate;
		genTX_XClk1 : if (TX_INSERT_CROSSCLOCK_FIFO(i) = TRUE) generate
			signal XClk_TX_FIFO_DataIn		: STD_LOGIC_VECTOR(9 downto 0);
			signal XClk_TX_FIFO_Full			: STD_LOGIC;
		begin
			XClk_TX_FIFO_DataIn(TX_Data(i)'range)		<= TX_Data(i);
			XClk_TX_FIFO_DataIn(SOF_BIT)						<= TX_SOF(i);
			XClk_TX_FIFO_DataIn(EOF_BIT)						<= TX_EOF(i);
		
			XClk_TX_FIFO : entity PoC.fifo_ic_got
				generic map (
					D_BITS							=> XClk_TX_FIFO_DataIn'length,
					MIN_DEPTH						=> 16,
					DATA_REG						=> TRUE,
					OUTPUT_REG					=> FALSE,
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0
				)
				port map (
					-- Write Interface
					clk_wr							=> TX_Clock(i),
					rst_wr							=> TX_Reset(i),
					put									=> TX_Valid(i),
					din									=> XClk_TX_FIFO_DataIn,
					full								=> XClk_TX_FIFO_Full,
					estate_wr						=> open,

					-- Read Interface
					clk_rd							=> RS_TX_Clock(i),
					rst_rd							=> RS_TX_Reset(i),
					got									=> XClk_TX_FIFO_got,
					valid								=> XClk_TX_FIFO_Valid,
					dout								=> XClk_TX_FIFO_DataOut,
					fstate_rd						=> open
				);
			
			TX_Ack(i)	<= NOT XClk_TX_FIFO_Full;
		end generate;

		XClk_TX_FIFO_got	<= not TX_FIFO_Full;

		-- TX-Buffer Underrun Protection (configured by: TX_DISABLE_UNDERRUN_PROTECTION)
		-- ========================================================================================================================================================
		--	transactional behaviour:
		--	-	enabled:	each frame is committed when EOF is set (*_FIFO_Out(EOF_BIT))
		--	-	disabled:	each word is immediately committed, so incomplete frames can be consumed by the TX-MAC-statemachine
		--
		--	impact an FIFO_DEPTH:
		--	-	enabled:	FIFO_DEPTH must be greater than max. frame size (normal frames: ca. 1550 bytes; JumboFrames: ca. 9100 bytes)
		--	-	disabled:	TX-FIFO becomes optional; set FIFO_DEPTH to 0 to disable TX-FIFO
		-- ========================================================================================================================================================
		gen0 : if (TX_ENABLE_UNDERRUN_PROTECTION(i) = FALSE) generate
			TX_FIFO : entity PoC.fifo_cc_got_tempgot
				generic map (
					D_BITS							=> XClk_TX_FIFO_DataOut'length,
					MIN_DEPTH						=> TX_FIFO_DEPTHS(i),
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0,
					DATA_REG						=> FALSE,
					STATE_REG						=> TRUE,
					OUTPUT_REG					=> FALSE
				)
				port map (
					clk									=> RS_TX_Clock(i),
					rst									=> RS_TX_Reset(i),

					-- Write Interface
					put									=> XClk_TX_FIFO_Valid,
					din									=> XClk_TX_FIFO_DataOut,
					full								=> TX_FIFO_Full,
					estate_wr						=> open,

					-- Temporary put control
					commit							=> TX_FSM_Commit,
					rollback						=> TX_FSM_Rollback,

					-- Read Interface
					got									=> TX_FSM_Ack,
					valid								=> TX_FIFO_Valid,
					dout								=> TX_FIFO_DataOut,
					fstate_rd						=> open
				);
		end generate;
		gen1 : if (TX_ENABLE_UNDERRUN_PROTECTION(i) = TRUE) generate
			signal Commit			: STD_LOGIC;
		begin
			Commit		<= XClk_TX_FIFO_Valid and XClk_TX_FIFO_DataOut(EOF_BIT);
		
			TX_FIFO : entity PoC.fifo_cc_got_tempput
				generic map (
					D_BITS							=> XClk_TX_FIFO_DataOut'length,
					MIN_DEPTH						=> TX_FIFO_DEPTHS(i),
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0,
					DATA_REG						=> FALSE,
					STATE_REG						=> TRUE,
					OUTPUT_REG					=> FALSE
				)
				port map (
					clk									=> RS_TX_Clock(i),
					rst									=> RS_TX_Reset(i),

					-- Write Interface
					put									=> XClk_TX_FIFO_Valid,
					din									=> XClk_TX_FIFO_DataOut,
					full								=> TX_FIFO_Full,
					estate_wr						=> open,

					-- Temporary put control
					commit							=> Commit,
					rollback						=> '0',

					-- Read Interface
					got									=> TX_FSM_Ack,
					valid								=> TX_FIFO_Valid,
					dout								=> TX_FIFO_DataOut,
					fstate_rd						=> open
				);
		end generate;
		
		TX_FIFO_Data		<= TX_FIFO_DataOut(TX_FIFO_Data'range);
		TX_FIFO_SOF			<= TX_FIFO_DataOut(SOF_BIT);
		TX_FIFO_EOF			<= TX_FIFO_DataOut(EOF_BIT);

		TX_FSM : entity PoC.eth_TEMAC_TX_FSM
			port map (
				Clock							=> Eth_TX_Clock(i),
				Reset							=> Eth_TX_Reset(i),
				
				Valid							=> TX_FIFO_Valid,
				Data							=> TX_FIFO_Data,
				EOF								=> TX_FIFO_EOF,
				Ack								=> TX_FSM_Ack,
				Commit						=> TX_FSM_Commit,
				Rollback					=> TX_FSM_Rollback,
				
				UnderrunDetected	=> TX_FSM_UnderrunDetected(i),
				
				TEMAC_Valid				=> TX_FSM_Valid(i),
				TEMAC_Data				=> TX_FSM_Data(i),
				TEMAC_Ack					=> TEMAC_TX_Ack(i)
			);

		-- =========================================================================
		-- RX path
		-- =========================================================================
		RXFSM : entity PoC.eth_TEMAC_RX_FSM
			port map (
				Clock							=> Eth_TX_Clock(i),
				Reset							=> Eth_TX_Reset(i),
				
				TEMAC_Valid				=> TEMAC_RX_Valid(i),
				TEMAC_Data				=> TEMAC_RX_Data(i),
				TEMAC_GoodFrame		=> TEMAC_RX_GoodFrame(i),
				TEMAC_BadFrame		=> TEMAC_RX_BadFrame(i),
				
				OverflowDetected	=> RX_FSM_OverflowDetected(i),
				
				Valid							=> RX_FSM_Valid,
				Data							=> RX_FSM_Data,
				SOF								=> RX_FSM_SOF,
				EOF								=> RX_FSM_EOF,
				Ack								=> RX_FIFO_Ack,
				Commit						=> RX_FSM_Commit,
				Rollback					=> RX_FSM_Rollback
			);
		
		RX_FIFO_put												<= RX_FSM_Valid;
		RX_FIFO_DataIn(RX_FSM_Data'range)	<= RX_FSM_Data;
		RX_FIFO_DataIn(SOF_BIT)						<= RX_FSM_SOF;
		RX_FIFO_DataIn(EOF_BIT)						<= RX_FSM_EOF;
		RX_FIFO_Ack												<= not RX_FIFO_Full;
		
		RX_FIFO : ENTITY PoC.fifo_cc_got_tempput
			GENERIC MAP (
				D_BITS							=> RX_FIFO_DataIn'length,
				MIN_DEPTH						=> RX_FIFO_DEPTHS(i),
				ESTATE_WR_BITS			=> 0,
				FSTATE_RD_BITS			=> 0,
				DATA_REG						=> FALSE,
				STATE_REG						=> TRUE,
				OUTPUT_REG					=> FALSE
			)
			PORT MAP (
				clk									=> RS_RX_Clock(i),
				rst									=> RS_RX_Reset(i),

				-- Write Interface
				put									=> RX_FIFO_put,
				din									=> RX_FIFO_DataIn,
				full								=> RX_FIFO_Full,
				estate_wr						=> OPEN,

				-- Temporary put control
				commit							=> RX_FSM_Commit,
				rollback						=> RX_FSM_Rollback,

				-- Read Interface
				got									=> RX_FIFO_got,
				valid								=> RX_FIFO_Valid,
				dout								=> RX_FIFO_DataOut,
				fstate_rd						=> OPEN
			);

		RX_FIFO_got			<= not XClk_RX_FIFO_Full;
		
		genRX_XClk0 : if (RX_INSERT_CROSSCLOCK_FIFO(i) = FALSE) generate
			RX_Valid(i)							<= RX_FIFO_Valid;
			RX_Data(i)							<= RX_FIFO_DataOut(RX_Data(i)'range);
			RX_SOF(i)								<= RX_FIFO_DataOut(SOF_BIT);
			RX_EOF(i)								<= RX_FIFO_DataOut(EOF_BIT);
			XClk_RX_FIFO_Full				<= not RX_Ack(i);
		end generate;
		genRX_XClk1 : if (RX_INSERT_CROSSCLOCK_FIFO(i) = TRUE) generate
			signal XClk_RX_FIFO_DataOut		: STD_LOGIC_VECTOR(9 downto 0);
		begin
			XClk_RX_FIFO : ENTITY PoC.fifo_ic_got
				GENERIC MAP (
					D_BITS							=> RX_FIFO_DataOut'length,
					MIN_DEPTH						=> 16,
					DATA_REG						=> TRUE,
					OUTPUT_REG					=> FALSE,
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0
				)
				PORT MAP (
					-- Write Interface
					clk_wr							=> RS_RX_Clock(i),
					rst_wr							=> RS_RX_Reset(i),
					put									=> RX_FIFO_Valid,
					din									=> RX_FIFO_DataOut,
					full								=> XClk_RX_FIFO_Full,
					estate_wr						=> OPEN,

					-- Read Interface
					clk_rd							=> RX_Clock(i),
					rst_rd							=> RX_Reset(i),
					got									=> RX_Ack(i),
					valid								=> RX_Valid(i),
					dout								=> XClk_RX_FIFO_DataOut,
					fstate_rd						=> OPEN
				);
	
			RX_Data(i)	<= XClk_RX_FIFO_DataOut(RX_Data(i)'range);
			RX_SOF(i)		<= XClk_RX_FIFO_DataOut(SOF_BIT);
			RX_EOF(i)		<= XClk_RX_FIFO_DataOut(EOF_BIT);
		end generate;
	end generate;
end;
