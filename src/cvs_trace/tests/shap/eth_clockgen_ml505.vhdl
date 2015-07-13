--
-- Entity: clockgen_ml505
-- Author(s): Martin Zabel
-- 
-- Clock generator for ML505 board.
--
-- Signal names in capital letter correspond to board schmetic signal names.
-- CLK_FPGA_P/N is a differential 200 MHz clock source.
--
-- Provided clocks are:
-- - "clk_eth":
--     125 MHz for user application logic, synchronized reset is "rst_eth"
--
-- - "clk_gmii_tx":TX clock for GMII interface and TEMAC (125 MHz)
-- - "clk_gmii_rx" RX clock for GMII interface and TEMAC (125 MHz)
--
-- - "clk_delayctrl":
--     reference clock for IODELAYCTRL components (200 MHz),
--     synchronized reset is "rst_delayctrl"
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-03-30 08:54:40 $
--

-------------------------------------------------------------------------------
-- Naming Conventions:
-- (Based on: Keating and Bricaud: "Reuse Methodology Manual")
--
-- active low signals: "*_n"
-- clock signals: "clk", "clk_div#", "clk_#x"
-- reset signals: "rst", "rst_n"
-- generics: all UPPERCASE
-- user defined types: "*_TYPE"
-- state machine next state: "*_ns"
-- state machine current state: "*_cs"
-- output of a register: "*_r"
-- asynchronous signal: "*_a"
-- pipelined or register delay signals: "*_p#"
-- data before being registered into register with the same name: "*_nxt"
-- clock enable signals: "*_ce"
-- internal version of output port: "*_i"
-- tristate internal signal "*_z"
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity eth_clockgen_ml505 is
  
  port (
    CLK_FPGA_P       : in  std_logic;
    CLK_FPGA_N       : in  std_logic;
    PHY_RXCLK        : in  std_logic;
    FPGA_CPU_RESET_B : in  std_logic;
    clk_eth          : out std_logic;
    clk_gmii_tx      : out std_logic;
    clk_gmii_rx      : out std_logic;
    clk_delayctrl    : out std_logic;
    async_rst        : out std_logic;
    rst_eth          : out std_logic;
    rst_delayctrl    : out std_logic;
    locked           : out std_logic);

end eth_clockgen_ml505;

architecture rtl of eth_clockgen_ml505 is
  signal fpga_cpu_reset : std_logic;
  signal async_rst_i    : std_logic;

  signal clk_fpga_bufo  : std_logic;
  signal phy_rxclk_dlyd : std_logic;

  signal pll125_clkfbout : std_logic;
  signal pll125_locked   : std_logic;
  signal clk_125mhz      : std_logic;
  
  signal clk_eth_i       : std_logic;
  signal clk_delayctrl_i : std_logic;
  
  signal locked_i : std_logic;

  signal rst_eth_i       : std_logic_vector(6 downto 0);
  signal rst_delayctrl_i : std_logic_vector(12 downto 0);
  
begin  -- rtl

  -----------------------------------------------------------------------------
  -- Asynchronous reset
  -----------------------------------------------------------------------------
  fpga_cpu_reset <= not FPGA_CPU_RESET_B;
  async_rst_i    <= fpga_cpu_reset or (not locked_i);
  async_rst      <= async_rst_i;
  
  -----------------------------------------------------------------------------
  -- Clock Buffer for External Clock Pins
  -----------------------------------------------------------------------------
  ibuf_clkfpga : IBUFGDS port map(
    I  => CLK_FPGA_P,
    IB => CLK_FPGA_N,
    O  => clk_fpga_bufo);

  -----------------------------------------------------------------------------
  -- Generate reference clock for IODELAYCTRL
  -----------------------------------------------------------------------------
  bufg_delayctrl : BUFG  port map(
    I => clk_fpga_bufo,
    O => clk_delayctrl_i);

  clk_delayctrl <= clk_delayctrl_i;

  -----------------------------------------------------------------------------
  -- Generate 125 MHz clock for clk_gmii_tx and clk_eth
  -----------------------------------------------------------------------------
  pll125 : PLL_ADV
    generic map(
      BANDWIDTH          => "OPTIMIZED",
      CLKIN1_PERIOD      => 5.000,
      CLKIN2_PERIOD      => 10.000,
      CLKOUT0_DIVIDE     => 8,
      CLKOUT0_PHASE      => 0.000,
      CLKOUT0_DUTY_CYCLE => 0.500,
      COMPENSATION       => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE      => 1,
      CLKFBOUT_MULT      => 5,
      CLKFBOUT_PHASE     => 0.0,
      REF_JITTER         => 0.005000)
    port map (
      CLKFBIN    => pll125_clkfbout,
      CLKINSEL   => '1',
      CLKIN1     => clk_fpga_bufo,
      CLKIN2     => '0',
      DADDR      => (others => '0'),
      DCLK       => '0',
      DEN        => '0',
      DI         => (others => '0'),
      DWE        => '0',
      REL        => '0',
      RST        => fpga_cpu_reset,
      CLKFBDCM   => open,
      CLKFBOUT   => pll125_clkfbout,
      CLKOUTDCM0 => open,
      CLKOUTDCM1 => open,
      CLKOUTDCM2 => open,
      CLKOUTDCM3 => open,
      CLKOUTDCM4 => open,
      CLKOUTDCM5 => open,
      CLKOUT0    => clk_125mhz,
      CLKOUT1    => open,
      CLKOUT2    => open,
      CLKOUT3    => open,
      CLKOUT4    => open,
      CLKOUT5    => open,
      DO         => open,
      DRDY       => open,
      LOCKED     => pll125_locked);

  bufg_clk125mhz : BUFG port map (
    I => clk_125mhz,
    O => clk_eth_i);

  clk_eth     <= clk_eth_i;
  clk_gmii_tx <= clk_eth_i;

  -----------------------------------------------------------------------------
  -- Generate GMII RX clock
  -----------------------------------------------------------------------------

  delay_phy_rxclk : IODELAY
    generic map (
      IDELAY_TYPE    => "FIXED",
      IDELAY_VALUE   => 0,
      DELAY_SRC      => "I",
      SIGNAL_PATTERN => "CLOCK")
    port map (
      IDATAIN    => PHY_RXCLK,
      ODATAIN    => '0',
      DATAOUT    => phy_rxclk_dlyd,
      DATAIN     => '0',
      C          => '0',
      T          => '0',
      CE         => '0',
      INC        => '0',
      RST        => '0');

  bufg_gmii_rx : BUFG port map (
    I => phy_rxclk_dlyd,
    O => clk_gmii_rx);
  
  -----------------------------------------------------------------------------
  -- Combined "locked"
  -----------------------------------------------------------------------------

  locked_i <= pll125_locked;
  locked   <= locked_i;

  -----------------------------------------------------------------------------
  -- Synchronizing reset
  -----------------------------------------------------------------------------

  rstgen_eth : process (clk_eth_i, async_rst_i)
  begin
    if async_rst_i = '1' then
      rst_eth_i <= (others => '1');
    elsif clk_eth_i'event and clk_eth_i = '1' then
      rst_eth_i <= rst_eth_i(rst_eth_i'left-1 downto 0) & '0';
    end if;
  end process rstgen_eth;

  rst_eth <= rst_eth_i(rst_eth_i'left);

  
  rstgen_delayctrl :process (clk_delayctrl_i, async_rst_i)
  begin
    if (async_rst_i = '1') then
      rst_delayctrl_i <= (others => '1');
    elsif clk_delayctrl_i'event and clk_delayctrl_i = '1' then
      rst_delayctrl_i <= rst_delayctrl_i(rst_delayctrl_i'left-1 downto 0) & '0';
    end if;
  end process rstgen_delayctrl;

  rst_delayctrl <= rst_delayctrl_i(rst_delayctrl_i'left);
  
end rtl;
