entity fifo_ic_assembly_tb is
end entity fifo_ic_assembly_tb;


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;

architecture tb of fifo_ic_assembly_tb is

  -- component generics
  constant D_BITS : positive := 8;
  constant A_BITS : positive := 8;
  constant G_BITS : positive := 2;

  constant SEQ : t_intvec := (1, 0, 2, 3, 5, 4, 7, 6, 8, 10, 9, 12, 11, 13, 15, 14);

  -- component ports
  signal clk : std_logic;
  signal rst : std_logic;

  signal addr   : std_logic_vector(A_BITS-1 downto 0);
  signal ful    : std_logic;
  signal din    : std_logic_vector(D_BITS-1 downto 0);
  signal put    : std_logic;

  signal dout   : std_logic_vector(D_BITS-1 downto 0);
  signal vld    : std_logic;
  signal got    : std_logic;

begin

  DUT: entity work.fifo_ic_assembly
    generic map (
      D_BITS => D_BITS,
      A_BITS => A_BITS,
      G_BITS => G_BITS
    )
    port map (
      clk_wr => clk,
      rst_wr => rst,
      addr   => addr,
      ful    => ful,
      din    => din,
      put    => put,

      clk_rd => clk,
      rst_rd => rst,
      dout   => dout,
      vld    => vld,
      got    => got
    );

  -- Clock
  process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
    if put = '0' and vld = '0' then
      wait;
    end if;
  end process;
  rst <= '0';

  -- Writer
  process
    variable t : integer;
  begin
    put <= '1';
    for i in SEQ'range loop
      for j in 0 to 15 loop
        t := 16*SEQ(i) + j;
        addr <= std_logic_vector(to_unsigned(t, addr'length));
        din  <= std_logic_vector(to_unsigned(t, din 'length));
        wait until rising_edge(clk) and ful = '0';
      end loop;
    end loop;

    put <= '0';
    wait; -- forever
  end process;

  -- Reading Checker
  process
  begin
    got <= '1';
    for i in 0 to SEQ'length*16-1 loop
      wait until rising_edge(clk) and vld = '1';
      assert dout = std_logic_vector(to_unsigned(i, dout'length))
        report "Unexpected output: "&integer'image(to_integer(unsigned(dout)))&
               " instead of "&integer'image(i mod 2**dout'length)
        severity error;
    end loop;

    got <= '0';
    wait; -- forever
  end process;

end tb;
