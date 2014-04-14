library ieee;
use ieee.std_logic_1164.all;

entity ocrom_chain_tb is
end ocrom_chain_tb;

library ieee;
use ieee.numeric_std.all;

architecture tb of ocrom_chain_tb is

  component ocrom_chain
    generic (
      WIDTH : positive;
      ABITS : positive
    );
    port (
      cclk  : in  std_logic;
      cena  : in  std_logic;
      cdin  : in  std_logic;
      cdout : out std_logic;
      addr  : in  std_logic_vector(ABITS-1 downto 0);
      dout  : out std_logic_vector(WIDTH-1 downto 0)
    );
  end component;

  -- component generics
  constant WIDTH : positive := 3;
  constant ABITS : positive := 4;

  -- component ports
  signal cclk  : std_logic;
  signal cena  : std_logic;
  signal cdin  : std_logic;
  signal cdout : std_logic;
  signal addr  : std_logic_vector(ABITS-1 downto 0);
  signal dout  : std_logic_vector(WIDTH-1 downto 0);

begin  -- tb

  -- component instantiation
  DUT: ocrom_chain
    generic map (
      WIDTH => WIDTH,
      ABITS => ABITS
    )
    port map (
      cclk  => cclk,
      cena  => cena,
      cdin  => cdin,
      cdout => cdout,
      addr  => addr,
      dout  => dout
    );

  process
  begin
    -- Default Shift Control
    cena <= '0';
    cclk <= '0';

    -- Initialize ROM Data
    cena <= '1';
    for w in WIDTH-1 downto 0 loop
      for a in 2**ABITS-1 downto 0 loop
        cdin <= to_unsigned(a, WIDTH)(w);
        wait for 5 ns;
        cclk <= '1';
        wait for 5 ns;
        cclk <= '0';
      end loop;  -- a
    end loop;  -- w
    cena <= '0';

    -- Query and Check ROM Data
    for a in 2**ABITS-1 downto 0 loop
      addr <= std_logic_vector(to_unsigned(a, ABITS));
      wait for 10 ns;
      assert dout = std_logic_vector(to_unsigned(a, WIDTH))
        report "Content Mismatch."
        severity error;
    end loop;  -- a
    
    report "Test completed." severity note;
    wait;
    
  end process;

end tb;
