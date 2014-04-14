--------------------------------------------------------------------------------
-- File       : GMII_SGMII_sgmii_adapt.vhd
-- Author     : Xilinx Inc.
--------------------------------------------------------------------------------
-- (c) Copyright 2004-2008 Xilinx, Inc. All rights reserved.
--
--------------------------------------------------------------------------------
-- Description: This is the top level entity for the SGMII adaptation
--              module.  This creates a GMII-style interface which is
--              clocked at 125MHz at 1Gbps; 12.5MHz at 100Mbps and
--              1.25MHz at 10Mbps.  The GMII-style interface has an
--              8-bit data path.  At 10/100Mbps speeds, this GMII-style
--              interface does not conform to any offical specification
--              but it is a convenient interface to use internally to
--              connect to a client MAC - for example, the Tri-Speed
--              Ethernet MAC LogiCORE from Xilinx.

--              This instantiates three sub modules, which are:
--
--              GMII_SGMII_clk_gen.vhd
--              -----------
--
--              This file creates the necessary receiver and transmitter
--              clocks and clock enables for use with the core.  Clock
--              frequencies are:
--                 * 125  MHz at an operating speed of 1Gbps
--                 * 12.5 MHz at an operating speed of 100Mbps
--                 * 1.25 MHz at an operating speed of 10Mbps
--
--              GMII_SGMII_tx_rate_adapt.vhd
--              ---------------
--
--              This module accepts transmitter data from the GMII style
--              interface from the attached client MAC.  At 1 Gbps, this
--              GMII transmitter data will be valid on evey clock cycle
--              of the 125MHz reference clock; at 100Mbps, this data
--              will be repeated for a ten clock period duration of the
--              125MHz reference clock; at 10Mbps, this data will be
--              repeated for a hundred clock period duration of the
--              125MHz reference clock.
--
--              This module will sample the input transmitter GMII data
--              synchronously to the 125MHz reference clock.  This
--              sampled data can then be connected direcly to the input
--              GMII-style interface of the Ethernet 1000BASE-X PCS/PMA
--              or SGMII LogiCORE.
--
--              GMII_SGMII_rx_rate_adapt.vhd
--              ---------------
--
--              This module accepts receiver data from the Ethernet
--              1000BASE-X PCS/PMA or SGMII LogiCORE. At 1 Gbps, this
--              data will be valid on evey clock cycle of the 125MHz
--              reference clock; at 100Mbps, this data will be repeated
--              for a ten clock period duration of the 125MHz reference
--              clock; at 10Mbps, this data will be repeated for a
--              hundred clock period duration of the 125MHz reference
--              clock.
--
--              This module will sample the input receiver data
--              synchronously to the 125MHz reference clock in the
--              centre of the data valid window.  The Start of Frame
--              Delimiter (SFD) is also detected, and if required, it is
--              realigned across the 8-bit data path.
--
--              This data will then be held constant for the
--              appropriate number of clock cycles so that it can be
--              sampled by the client MAC attached at the other end of
--              the GMII-style link.

LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
--USE			IEEE.NUMERIC_STD.ALL;

--LIBRARY UNISIM;
--USE			UNISIM.VCOMPONENTS.ALL;

--LIBRARY PoC;
--USE			PoC.config.ALL;
--USE			PoC.functions.ALL;

--LIBRARY L_Global;
--USE			L_Global.GlobalTypes.ALL;

LIBRARY L_Xilinx;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;

entity GMII_SGMII_sgmii_adapt is
      port(

      reset            : in std_logic;                     -- Asynchronous reset for entire core.

      -- Clock derivation
      -------------------
      clk125m          : in std_logic;                     -- Reference 125MHz clock.
      sgmii_clk_r      : out std_logic;                    -- Clock to client MAC (125MHz, 12.5MHz or 1.25MHz) (to rising edge DDR).
      sgmii_clk_f      : out std_logic;                    -- Clock to client MAC (125MHz, 12.5MHz or 1.25MHz) (to falling edge DDR).

      sgmii_clk_en     : out std_logic;                    -- Clock enable to client MAC (125MHz, 12.5MHz or 1.25MHz).

      -- GMII Rx
      ----------
      gmii_txd_in      : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en_in    : in std_logic;                     -- Transmit data valid signal from client MAC.
      gmii_tx_er_in    : in std_logic;                     -- Transmit error signal from client MAC.
      gmii_rxd_out     : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv_out   : out std_logic;                    -- Received data valid signal to client MAC.
      gmii_rx_er_out   : out std_logic;                    -- Received error signal to client MAC.

      -- GMII Tx
      ----------
      gmii_rxd_in      : in std_logic_vector(7 downto 0);  -- Received Data to client MAC.
      gmii_rx_dv_in    : in std_logic;                     -- Received data valid signal to client MAC.
      gmii_rx_er_in    : in std_logic;                     -- Received error signal to client MAC.
      gmii_txd_out     : out std_logic_vector(7 downto 0); -- Transmit data from client MAC.
      gmii_tx_en_out   : out std_logic;                    -- Transmit data valid signal from client MAC.
      gmii_tx_er_out   : out std_logic;                    -- Transmit error signal from client MAC.

      -- Speed Control
      ----------------
      speed_is_10_100  : in std_logic;                     -- Core should operate at either 10Mbps or 100Mbps speeds
      speed_is_100     : in std_logic                      -- Core should operate at 100Mbps speed

      );
end;


architecture adapter of GMII_SGMII_sgmii_adapt is
  ------------------------------------------------------------------------------
  -- internal signals used in this wrapper.
  ------------------------------------------------------------------------------

  -- A clock enable for the GMII transmitter and receiver data path 
  signal sgmii_clk_en_int       : std_logic;

  -- create a synchronous reset in the clk125m clock domain
  signal sync_reset             : std_logic;

  -- Resynchronous the speed settings into the local clock domain
  signal speed_is_10_100_resync : std_logic;
  signal speed_is_100_resync    : std_logic;


begin
  ------------------------------------------------------------------------------
  -- Clock Resynchronisation logic
  ------------------------------------------------------------------------------
  -- Create synchronous reset in the clk125m clock domain.
  gen_sync_reset : ENTITY L_Xilinx.Xilinx_reset_sync
		port map(
			 clk                => clk125m,
			 reset_in           => reset,
			 reset_out          => sync_reset
		);

  -- Resynchronous the speed settings into the local clock domain
  resync_speed_10_100 : ENTITY L_Xilinx.Xilinx_sync_block
		port map(
			 clk                => clk125m,
			 data_in            => speed_is_10_100,
			 data_out           => speed_is_10_100_resync
		);

  -- Resynchronous the speed settings into the local clock domain
  resync_speed_100 : ENTITY L_Xilinx.Xilinx_sync_block
		port map(
			 clk                => clk125m,
			 data_in            => speed_is_100,
			 data_out           => speed_is_100_resync
		);


  ------------------------------------------------------------------------------
  -- Component instantiation for the clock generation circuitry
  ------------------------------------------------------------------------------
  clock_generation : ENTITY L_Ethernet.GMII_SGMII_clk_gen
		port map (
			reset               => sync_reset,
			clk125m             => clk125m,
			speed_is_10_100     => speed_is_10_100_resync,
			speed_is_100        => speed_is_100_resync,
			sgmii_clk_r         => sgmii_clk_r,
			sgmii_clk_f         => sgmii_clk_f,
			sgmii_clk_en        => sgmii_clk_en_int
		);

  -- Route to output port
  sgmii_clk_en <= sgmii_clk_en_int;

  ------------------------------------------------------------------------------
  -- Component Instantiation for the transmitter rate adapt logic
  ------------------------------------------------------------------------------
  transmitter: ENTITY L_Ethernet.GMII_SGMII_tx_rate_adapt
		port map (
			reset               => sync_reset,
			clk125m             => clk125m,
			sgmii_clk_en        => sgmii_clk_en_int,
			gmii_txd_in         => gmii_txd_in,
			gmii_tx_en_in       => gmii_tx_en_in,
			gmii_tx_er_in       => gmii_tx_er_in,
			gmii_txd_out        => gmii_txd_out,
			gmii_tx_en_out      => gmii_tx_en_out,
			gmii_tx_er_out      => gmii_tx_er_out
			);

  ------------------------------------------------------------------------------
  -- Component Instantiation for the receiver rate adapt logic
  ------------------------------------------------------------------------------
  receiver: ENTITY L_Ethernet.GMII_SGMII_rx_rate_adapt
		port map (
			reset               => sync_reset,
			clk125m             => clk125m,
			sgmii_clk_en        => sgmii_clk_en_int,
			gmii_rxd_in         => gmii_rxd_in,
			gmii_rx_dv_in       => gmii_rx_dv_in,
			gmii_rx_er_in       => gmii_rx_er_in,
			gmii_rxd_out        => gmii_rxd_out,
			gmii_rx_dv_out      => gmii_rx_dv_out,
			gmii_rx_er_out      => gmii_rx_er_out
			);
end;
