-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- Copyright (c) 2011
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
-- Entity: crc_tb
-- Author(s): Thomas B. Preusser <thomas.preusser@tu-dresden.de>
--
-- Test bench for CRC computation.
--
entity comm_crc_tb is
end comm_crc_tb;


library IEEE;
use IEEE.std_logic_1164.all;

library PoC;
use PoC.utils.all;

architecture tb of comm_crc_tb is

  component comm_crc
		generic (
			GEN		: bit_vector;		 															-- Generator Polynom
			BITS	: positive;			 															-- Number of Bits to be processed in parallel

			STARTUP_RMD : std_logic_vector	:= "0";
			OUTPUT_REGS : boolean						:= true
		);
		port (
			clk	: in	std_logic;																-- Clock

			set	: in	std_logic;																-- Parallel Preload of Remainder
			init : in	std_logic_vector(abs(mssb_idx(GEN)-GEN'right)-1 downto 0);	--
			step : in	std_logic;																-- Process Input Data (MSB first)
			din	: in	std_logic_vector(BITS-1 downto 0);				--

			rmd	: out std_logic_vector(abs(mssb_idx(GEN)-GEN'right)-1 downto 0);	-- Remainder
			zero : out std_logic																-- Remainder is Zero
		);
  end component;

  -- component generics
  constant GEN : bit_vector := "1101";

  type tDAT is array (natural range<>) of std_logic_vector(0 to 31);
  constant DAT : tDAT := (
    -- RMD zero, RMD non-zero
    x"01120a60", x"01120a68",
    x"01120abd", x"f1120abd",
    x"01120b8b", x"01126b8b",
    x"0112144b", x"0172144b",
    x"dddddddd", x"ddddddda"
  );

  -- component ports
  signal clk  : std_logic;
  signal rst  : std_logic;
  signal step : std_logic;
  signal din  : std_logic_vector(0 downto 0);
  signal rmd  : std_logic_vector(GEN'length-2 downto 0);
  signal zero : std_logic;

begin

  -- DUT
  DUT: comm_crc
    generic map (
      GEN  => GEN,
      BITS => 1
    )
    port map (
      clk  => clk,
      set  => rst,
      init => (others => '0'),
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
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
      clk <= '0';
    end cycle;

    variable errors : natural;

  begin

    clk <= '0';

    errors := 0;
    for j in DAT'range loop
      -- Reset Cycle
      rst  <= '1';
      step <= '0';
      cycle;

      rst  <= '0';
      step <= '1';
      for i in 0 to 31 loop
        din <= DAT(j)(i to i);
        cycle;
      end loop;

      if (zero = '1') /= (j mod 2 = 0) then
        report "Failed Test "&integer'image(j)&"."
          severity error;
        errors := errors + 1;
      end if;
    end loop;

    report "Test completed: "&integer'image(errors)&" error(s)." severity note;
    wait;

  end process;

end tb;
