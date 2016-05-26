-------------------------------------------------------------------------------
-- Title      : 1000BASE-X RocketIO wrapper
-- Project    : Virtex-5 Embedded Tri-Mode Ethernet MAC Wrapper
-- File       : gtp_dual_1000X.vhd
-- Version    : 1.8
-------------------------------------------------------------------------------
--
-- (c) Copyright 2004-2010 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
------------------------------------------------------------------------
-- Description:  This is the VHDL instantiation of a Virtex-5 GTP
--               RocketIO tile for the Embedded Ethernet MAC.
--
--               Two GTP's must be instantiated regardless of how many
--               GTPs are used in the MGT tile.
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

library UNISIM;
use UNISIM.Vcomponents.ALL;


entity GTP_dual_1000X is
   port (
          RESETDONE_0           : out   std_logic;
          ENMCOMMAALIGN_0       : in    std_logic;
          ENPCOMMAALIGN_0       : in    std_logic;
          LOOPBACK_0            : in    std_logic;
          POWERDOWN_0           : in    std_logic;
          RXUSRCLK_0            : in    std_logic;
          RXUSRCLK2_0           : in    std_logic;
          RXRESET_0             : in    std_logic;
          TXCHARDISPMODE_0      : in    std_logic;
          TXCHARDISPVAL_0       : in    std_logic;
          TXCHARISK_0           : in    std_logic;
          TXDATA_0              : in    std_logic_vector (7 downto 0);
          TXUSRCLK_0            : in    std_logic;
          TXUSRCLK2_0           : in    std_logic;
          TXRESET_0             : in    std_logic;
          RXCHARISCOMMA_0       : out   std_logic;
          RXCHARISK_0           : out   std_logic;
          RXCLKCORCNT_0         : out   std_logic_vector (2 downto 0);
          RXDATA_0              : out   std_logic_vector (7 downto 0);
          RXDISPERR_0           : out   std_logic;
          RXNOTINTABLE_0        : out   std_logic;
          RXRUNDISP_0           : out   std_logic;
          RXBUFERR_0            : out   std_logic;
          TXBUFERR_0            : out   std_logic;
          PLLLKDET_0            : out   std_logic;
          TXOUTCLK_0            : out   std_logic;
          RXELECIDLE_0    	: out   std_logic;
          TX1N_0                : out   std_logic;
          TX1P_0                : out   std_logic;
          RX1N_0                : in    std_logic;
          RX1P_0                : in    std_logic;

          TX1N_1_UNUSED         : out   std_logic;
          TX1P_1_UNUSED         : out   std_logic;
          RX1N_1_UNUSED         : in    std_logic;
          RX1P_1_UNUSED         : in    std_logic;


          CLK_DS                : in    std_logic;
          REFCLKOUT             : out   std_logic;
          GTRESET               : in    std_logic;
          PMARESET              : in    std_logic;
          DCM_LOCKED            : in    std_logic
          );
end GTP_dual_1000X;


architecture structural of GTP_dual_1000X is

  ----------------------------------------------------------------------
  -- Signal declarations for GTP
  ----------------------------------------------------------------------

   signal GND_BUS               : std_logic_vector (55 downto 0);
   signal PLLLOCK               : std_logic;


   signal RXNOTINTABLE_0_INT    : std_logic;
   signal RXDATA_0_INT          : std_logic_vector (7 downto 0);
   signal RXCHARISK_0_INT       : std_logic;
   signal RXDISPERR_0_INT       : std_logic;
   signal RXRUNDISP_0_INT       : std_logic;

   signal RXBUFSTATUS_float0    : std_logic_vector(1 downto 0);
   signal TXBUFSTATUS_float0    : std_logic;
   signal gt_txoutclk1_0        : std_logic;

   signal rxelecidle0_i         : std_logic;
   signal resetdone0_i          : std_logic;


   attribute ASYNC_REG                        : string;

begin

   GND_BUS(55 downto 0) <= (others => '0');

   ----------------------------------------------------------------------
   -- Wait for both PLL's to lock
   ----------------------------------------------------------------------


   PLLLKDET_0        <=   PLLLOCK;


   ----------------------------------------------------------------------
   -- Wire internal signals to outputs
   ----------------------------------------------------------------------

   RXNOTINTABLE_0  <=   RXNOTINTABLE_0_INT;
   RXDISPERR_0     <=   RXDISPERR_0_INT;
   TXOUTCLK_0      <=   gt_txoutclk1_0;

   RESETDONE_0          <= resetdone0_i;
   RXELECIDLE_0         <= rxelecidle0_i;




   ----------------------------------------------------------------------
   -- Instantiate the Virtex-5 GTP
   -- EMAC0 connects to GTP 0 and EMAC1 connects to GTP 1
   ----------------------------------------------------------------------

   -- Direct from the RocketIO Wizard output
   GTP_1000X : ROCKETIO_WRAPPER_GTP
    generic map (
        WRAPPER_SIM_GTPRESET_SPEEDUP   => 1,
        WRAPPER_SIM_PLL_PERDIV2        => x"190"
    )
    port map (
        ------------------- Shared Ports - Tile and PLL Ports --------------------
        TILE0_CLKIN_IN                 => CLK_DS,
        TILE0_GTPRESET_IN              => GTRESET,
        TILE0_PLLLKDET_OUT             => PLLLOCK,
        TILE0_REFCLKOUT_OUT            => REFCLKOUT,
        ---------------------- Loopback and Powerdown Ports ----------------------
	TILE0_LOOPBACK0_IN(2 downto 1) => "00",
        TILE0_LOOPBACK0_IN(0)          => LOOPBACK_0,
        TILE0_RXPOWERDOWN0_IN(0)       => POWERDOWN_0,
        TILE0_RXPOWERDOWN0_IN(1)       => POWERDOWN_0,
        TILE0_TXPOWERDOWN0_IN(0)       => POWERDOWN_0,
        TILE0_TXPOWERDOWN0_IN(1)       => POWERDOWN_0,
        --------------------- Receive Ports - 8b10b Decoder ----------------------
        TILE0_RXCHARISCOMMA0_OUT       => RXCHARISCOMMA_0,
        TILE0_RXCHARISK0_OUT           => RXCHARISK_0_INT,
        TILE0_RXDISPERR0_OUT           => RXDISPERR_0_INT,
        TILE0_RXNOTINTABLE0_OUT        => RXNOTINTABLE_0_INT,
        TILE0_RXRUNDISP0_OUT           => RXRUNDISP_0_INT,
        ----------------- Receive Ports - Clock Correction Ports -----------------
        TILE0_RXCLKCORCNT0_OUT         => RXCLKCORCNT_0,
        ------------- Receive Ports - Comma Detection and Alignment --------------
        TILE0_RXENMCOMMAALIGN0_IN      => ENMCOMMAALIGN_0,
        TILE0_RXENPCOMMAALIGN0_IN      => ENPCOMMAALIGN_0,
        ----------------- Receive Ports - RX Data Path interface -----------------
        TILE0_RXDATA0_OUT              => RXDATA_0_INT,
        TILE0_RXRECCLK0_OUT            => open,
        TILE0_RXRESET0_IN              => RXRESET_0,
        TILE0_RXUSRCLK0_IN             => RXUSRCLK_0,
        TILE0_RXUSRCLK20_IN            => RXUSRCLK_0,
        ------ Receive Ports - RX Elastic Buffer and Phase Alignment Ports -------
        TILE0_RXBUFSTATUS0_OUT(2)      => RXBUFERR_0,
        TILE0_RXBUFSTATUS0_OUT(1 downto 0) => RXBUFSTATUS_float0,
        TILE0_RXBUFRESET0_IN           => RXRESET_0,
        ----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
        TILE0_RXELECIDLE0_OUT          => rxelecidle0_i,
        TILE0_RXN0_IN                  => RX1N_0,
        TILE0_RXP0_IN                  => RX1P_0,
        ------------- ResetDone Ports --------------------------------------------
        TILE0_RESETDONE0_OUT           => resetdone0_i,
        -------------- Transmit Ports - 8b10b Encoder Control Ports --------------
        TILE0_TXCHARDISPMODE0_IN       => TXCHARDISPMODE_0,
        TILE0_TXCHARDISPVAL0_IN        => TXCHARDISPVAL_0,
        TILE0_TXCHARISK0_IN            => TXCHARISK_0,
        ----------- Transmit Ports - TX Buffering and Phase Alignment ------------
        TILE0_TXBUFSTATUS0_OUT(1)      => TXBUFERR_0,
        TILE0_TXBUFSTATUS0_OUT(0)      => TXBUFSTATUS_float0,
        ---------------- Transmit Ports - TX Data Path interface -----------------
        TILE0_TXDATA0_IN               => TXDATA_0,
        TILE0_TXOUTCLK0_OUT            => gt_txoutclk1_0,
        TILE0_TXRESET0_IN              => TXRESET_0,
        TILE0_TXUSRCLK0_IN             => TXUSRCLK_0,
        TILE0_TXUSRCLK20_IN            => TXUSRCLK2_0,
        ------------- Transmit Ports - TX Driver and OOB signalling --------------
        TILE0_TXN0_OUT                 => TX1N_0,
        TILE0_TXP0_OUT                 => TX1P_0,
        TILE0_LOOPBACK1_IN             => "000",
        TILE0_RXPOWERDOWN1_IN          => "00",
        TILE0_TXPOWERDOWN1_IN          => "00",
        TILE0_RXCHARISCOMMA1_OUT       => open,
        TILE0_RXCHARISK1_OUT           => open,
        TILE0_RXDISPERR1_OUT           => open,
        TILE0_RXNOTINTABLE1_OUT        => open,
        TILE0_RXRUNDISP1_OUT           => open,
        TILE0_RXCLKCORCNT1_OUT         => open,
        TILE0_RXENMCOMMAALIGN1_IN      => '0',
        TILE0_RXENPCOMMAALIGN1_IN      => '0',
        TILE0_RXDATA1_OUT              => open,
        TILE0_RXRECCLK1_OUT            => open,
        TILE0_RXRESET1_IN              => '0',
        TILE0_RXUSRCLK1_IN             => '0',
        TILE0_RXUSRCLK21_IN            => '0',
        TILE0_RXBUFRESET1_IN           => '0',
        TILE0_RXBUFSTATUS1_OUT         => open,
        TILE0_RXELECIDLE1_OUT          => open,
        TILE0_RXN1_IN                  => RX1N_1_UNUSED,
        TILE0_RXP1_IN                  => RX1P_1_UNUSED,
        TILE0_RESETDONE1_OUT           => open,
        TILE0_TXCHARDISPMODE1_IN       => '0',
        TILE0_TXCHARDISPVAL1_IN        => '0',
        TILE0_TXCHARISK1_IN            => '0',
        TILE0_TXBUFSTATUS1_OUT         => open,
        TILE0_TXDATA1_IN               => "00000000",
        TILE0_TXOUTCLK1_OUT            => open,
        TILE0_TXRESET1_IN              => '0',
        TILE0_TXUSRCLK1_IN             => '0',
        TILE0_TXUSRCLK21_IN            => '0',
        TILE0_TXN1_OUT                 => TX1N_1_UNUSED,
        TILE0_TXP1_OUT                 => TX1P_1_UNUSED
   );


   -------------------------------------------------------------------------------
   -- EMAC0 to GTP logic shim
   -------------------------------------------------------------------------------

   -- When the RXNOTINTABLE condition is detected, the Virtex5 RocketIO
   -- GTP outputs the raw 10B code in a bit swapped order to that of the
   -- Virtex-II Pro RocketIO.
   gen_rxdata0 : process (RXNOTINTABLE_0_INT, RXDISPERR_0_INT, RXCHARISK_0_INT, RXDATA_0_INT,
                         RXRUNDISP_0_INT)
   begin
      if RXNOTINTABLE_0_INT = '1' then
         RXDATA_0(0) <= RXDISPERR_0_INT;
         RXDATA_0(1) <= RXCHARISK_0_INT;
         RXDATA_0(2) <= RXDATA_0_INT(7);
         RXDATA_0(3) <= RXDATA_0_INT(6);
         RXDATA_0(4) <= RXDATA_0_INT(5);
         RXDATA_0(5) <= RXDATA_0_INT(4);
         RXDATA_0(6) <= RXDATA_0_INT(3);
         RXDATA_0(7) <= RXDATA_0_INT(2);
         RXRUNDISP_0 <= RXDATA_0_INT(1);
         RXCHARISK_0 <= RXDATA_0_INT(0);

      else
         RXDATA_0    <= RXDATA_0_INT;
         RXRUNDISP_0 <= RXRUNDISP_0_INT;
         RXCHARISK_0 <= RXCHARISK_0_INT;

      end if;
   end process gen_rxdata0;



end structural;
