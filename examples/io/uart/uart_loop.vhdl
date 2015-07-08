library IEEE;
use IEEE.std_logic_1164.all;

entity uart_loop is
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    rx  : in  std_logic;
    tx  : out std_logic;
    led : out std_logic_vector(7 downto 0)
  );
end entity uart_loop;


library PoC;
use PoC.uart.all;

architecture rtl of uart_loop is

  signal rst_s : std_logic_vector(1 downto 0);

  signal Buf : std_logic_vector(7 downto 0) := (others => '0');
  signal dat : std_logic_vector(7 downto 0);
  signal put : std_logic;

  signal bclk, bclk_x8 : std_logic;

begin

  process(clk)
  begin
    if rising_edge(clk) then
      rst_s <= rst & rst_s(rst_s'left downto 1);
    end if;
  end process;

  bclk_i : uart_bclk
    generic map (
      CLK_FREQ => 50000000,
      BAUD     => 115200
    )
    port map (
      clk       => clk,
      rst       => rst_s(0),
      bclk_r    => bclk,
      bclk_x8_r => bclk_x8
    );

  rx_i : uart_rx
    port map (
      clk     => clk,
      rst     => rst_s(0),
      bclk_x8 => bclk_x8,
      rx      => rx,
      do      => dat,
      put     => put
    );

  tx_i : uart_tx
    port map (
      clk  => clk,
      rst  => rst_s(0),
      bclk => bclk,
      tx   => tx,
      di   => dat,
      put  => put,
      ful  => open
    );

  process(clk)
  begin
    if rising_edge(clk) then
      if rst_s(0) = '1' then
        Buf <= (others => '0');
      elsif put = '1' then
        Buf <= dat;
      end if;
    end if;
  end process;
  led <= Buf;

end architecture rtl;
