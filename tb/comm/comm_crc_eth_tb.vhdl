--
-- Copyright (c) 2012
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: comm_crc_eth_tb
-- Author(s): Thomas B. Preusser <thomas.preusser@tu-dresden.de>
--
-- Test bench for CRC computation of Ethernet FCS.
--
entity comm_crc_eth_tb is
end comm_crc_eth_tb;


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library poc;
use poc.functions.all;

architecture tb of comm_crc_eth_tb is

  component comm_crc
    generic (
      GEN  : bit_vector;
      BITS : positive
    ); 
    port (
      clk  : in  std_logic;
      set  : in  std_logic;
      init : in  std_logic_vector(GEN'length-2 downto 0);
      step : in  std_logic;
      din  : in  std_logic_vector(BITS-1 downto 0);
      rmd  : out std_logic_vector(GEN'length-2 downto 0);
      zero : out std_logic
    ); 
  end component;

  -- component generics
  constant GEN : bit_vector := '1'&x"04C11DB7";

  type tDAT is array (natural range<>) of std_logic_vector(7 downto 0);
  constant DAT : tDAT := (
    x"4A", x"37", x"C0", x"12", x"78"
  );
  constant EXP : std_logic_vector(31 downto 0) := x"0E186870";

  -- component ports
  signal clk  : std_logic;
  signal rst  : std_logic;
  signal step : std_logic;
  signal din  : std_logic_vector(7 downto 0);
  signal rmd  : std_logic_vector(GEN'length-2 downto 0);
  signal zero : std_logic;

begin

  -- DUT
  DUT: comm_crc
    generic map (
      GEN  => GEN,
      BITS => 8
    )
    port map (
      clk  => clk,
      set  => rst,
      init => (others => '1'),
      step => step,
      din  => din,
      rmd  => rmd,
      zero => zero
    );

  -- Stimuli
  process

    -- Perform a Clock Cycle
    procedure cycle is
    begin
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end cycle;

  begin

    rst  <= '1';
    step <= '0';
    cycle;
    rst  <= '0';
    
    step <= '1';
    for i in DAT'range loop
      din <= reverse(DAT(i));
      cycle;
    end loop;

    step <= '0';
    cycle;

    if rmd = not reverse(EXP) then
      report "Successful." severity note;
    else
      report "Failure" severity error;
    end if;
    wait;
    
  end process;

end tb;
