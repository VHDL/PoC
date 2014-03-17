library IEEE;
use IEEE.std_logic_1164.all;

entity remote_terminal_control_top is
  generic (
    CLK_FREQ : positive := 50000000;
    BAUD     : positive := 115200
  );
  port (
    clk : in  std_logic;

    rxd : in  std_logic;
    txd : out std_logic;

    sw  : in  std_logic_vector(7 downto 0);
    led : out std_logic_vector(7 downto 0)
  );
end remote_terminal_control_top;


library IEEE;
use IEEE.numeric_std.all;

library poc;
use poc.functions.all;
use poc.uart.all;

architecture rtl of remote_terminal_control_top is

  -- Control
  component remote_terminal_control is
    generic (
      RESET_COUNT  : natural;
      PULSE_COUNT  : natural;
      SWITCH_COUNT : natural;
      LIGHT_COUNT  : natural;
      DIGIT_COUNT  : natural
    );
    port (
      -- Global Control
      clk  : in  std_logic;
      rst  : in  std_logic;

      -- UART Connectivity
      idat : in  std_logic_vector(6 downto 0);
      istb : in  std_logic;
      odat : out std_logic_vector(6 downto 0);
      ordy : in  std_logic;
      oput : out std_logic;

      -- Control Outputs
      resets   : out std_logic_vector(imax(RESET_COUNT -1, 0) downto 0);
      pulses   : out std_logic_vector(imax(PULSE_COUNT -1, 0) downto 0);
      switches : out std_logic_vector(imax(SWITCH_COUNT-1, 0) downto 0);

      -- Monitor Inputs
      lights : in std_logic_vector(imax(  LIGHT_COUNT-1, 0) downto 0);
      digits : in std_logic_vector(imax(4*DIGIT_COUNT-1, 0) downto 0)
    );
  end component;

  signal rst : std_logic;

  signal idat : std_logic_vector(7 downto 0);
  signal istb : std_logic;
  
  signal odat : std_logic_vector(7 downto 0);
  signal oput : std_logic;
  signal ordy : std_logic;
  
begin  -- rtl

  rst <= '0';

  blkUART: block
    signal bclk    : std_logic;
    signal bclk_x8 : std_logic;
  begin
    
    rx: uart_rx
      generic map (
        OUT_REGS => true
      )
      port map (
        clk       => clk,
        rst       => rst,
        bclk_x8_r => bclk_x8,
        rxd       => rxd,
        dos       => istb,
        dout      => idat
      );

    tx: uart_tx
      port map (
        clk    => clk,
        rst    => rst,
        bclk_r => bclk,
        stb    => oput,
        din    => odat,
        rdy    => ordy,
        txd    => txd
      );

    bclk_gen: uart_bclk
      generic map (
        CLK_FREQ => CLK_FREQ,
        BAUD     => BAUD
      )
      port map (
        clk       => clk,
        rst       => rst,
        bclk_r    => bclk,
        bclk_x8_r => bclk_x8
      );

  end block blkUART;

  term_ctrl: remote_terminal_control
    generic map (
      RESET_COUNT  => 0,
      PULSE_COUNT  => 0,
      SWITCH_COUNT => 8,
      LIGHT_COUNT  => 8,
      DIGIT_COUNT  => 2
    )
    port map (
      clk      => clk,
      rst      => rst,
      idat     => idat(6 downto 0),
      istb     => istb,
      odat     => odat(6 downto 0),
      ordy     => ordy,
      oput     => oput,
      resets   => open,
      pulses   => open,
      switches => led,
      lights   => sw,
      digits   => sw
    );
	 odat(7) <= '0';
end rtl;
