--------------------------------------------------------------------------------
-- File       : GMII_SGMII_tx_rate_adapt.vhd
-- Author     : Xilinx Inc.
--------------------------------------------------------------------------------
-- (c) Copyright 2004-2008 Xilinx, Inc. All rights reserved.
--
-- 
--------------------------------------------------------------------------------
-- Description: This module accepts transmitter data from the GMII style
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
--              GMII- style interface of the Ethernet 1000BASE-X PCS/PMA
--              or SGMII LogiCORE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity GMII_SGMII_tx_rate_adapt is
  port(
    reset               : in std_logic;                     -- Synchronous reset.
    clk125m             : in std_logic;                     -- Reference 125MHz transmitter clock.
    sgmii_clk_en        : in std_logic;                     -- Clock enable pulse for the transmitter logic on clock falling edge (125MHz, 12.5MHz, 1.25MHz).
    gmii_txd_in         : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
    gmii_tx_en_in       : in std_logic;                     -- Transmit data valid signal from client MAC.
    gmii_tx_er_in       : in std_logic;                     -- Transmit error signal from client MAC.
    gmii_txd_out        : out std_logic_vector(7 downto 0); -- Transmit data from client MAC.
    gmii_tx_en_out      : out std_logic;                    -- Transmit data valid signal from client MAC.
    gmii_tx_er_out      : out std_logic                     -- Transmit error signal from client MAC.
    );
end;


architecture rtl of GMII_SGMII_tx_rate_adapt is

begin
  -- At 1Gbps speeds, sgmii_clk_en is permantly tied to logic 1
  -- and the input data will be sampled on every clock cycle.  At 10Mbs
  -- and 100Mbps speeds, sgmii_clk_en will be at logic 1 only only one clock
  -- cycle in ten, or one clock cycle in a hundred, respectively.

  -- The sampled output GMII transmitter data is sent directly into the
  -- Ethernet 1000BASE-X PCS/PMA or SGMII LogiCORE synchronously to the
  -- 125MHz reference clock.

  sample_gmii_tx: process (clk125m)
  begin
    if clk125m'event and clk125m = '1' then
      if reset = '1' then
        gmii_txd_out   <= (others => '0');
        gmii_tx_en_out <= '0';
        gmii_tx_er_out <= '0';
      elsif sgmii_clk_en = '1' then
        gmii_txd_out   <= gmii_txd_in;
        gmii_tx_en_out <= gmii_tx_en_in;
        gmii_tx_er_out <= gmii_tx_er_in;
      end if;
    end if;
  end process sample_gmii_tx;
end;

