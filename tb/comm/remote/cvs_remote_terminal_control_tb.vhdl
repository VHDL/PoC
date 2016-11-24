-- EMACS settings: -*-  tab-width:2  -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-------------------------------------------------------------------------------
-- Description:  Basic Testbench for remote_terminal_control.
--               See DUT description for details.

-- Authors:      Thomas B. Preußer <thomas.preusser@utexas.edu>
-------------------------------------------------------------------------------
-- Copyright 2007-2014 Technische Universität Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-------------------------------------------------------------------------------
entity remote_terminal_control_tb is
end remote_terminal_control_tb;

use std.textio.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library poc;
use poc.functions.all;

architecture tb of remote_terminal_control_tb is

  component remote_terminal_control
    generic (
      RESET_COUNT  : natural;
      PULSE_COUNT  : natural;
      SWITCH_COUNT : natural;
      LIGHT_COUNT  : natural;
      DIGIT_COUNT  : natural
    );
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      idat     : in  std_logic_vector(6 downto 0);
      istb     : in  std_logic;
      odat     : out std_logic_vector(6 downto 0);
      ordy     : in  std_logic;
      oput     : out std_logic;
      resets   : out std_logic_vector(imax(RESET_COUNT -1, 0) downto 0);
      pulses   : out std_logic_vector(imax(PULSE_COUNT -1, 0) downto 0);
      switches : out std_logic_vector(imax(SWITCH_COUNT-1, 0) downto 0);
      lights   : in  std_logic_vector(imax(LIGHT_COUNT-1, 0) downto 0);
      digits   : in  std_logic_vector(imax(4*DIGIT_COUNT-1, 0) downto 0)
    );
  end component;

  -- component generics
  constant RESET_COUNT  : natural :=  1;
  constant PULSE_COUNT  : natural :=  4;
  constant SWITCH_COUNT : natural :=  6;
  constant LIGHT_COUNT  : natural := 10;
  constant DIGIT_COUNT  : natural :=  2;

  -- component ports
  signal clk      : std_logic;
  signal rst      : std_logic;

  signal idat     : std_logic_vector(6 downto 0);
  signal istb     : std_logic;
  signal odat     : std_logic_vector(6 downto 0);
  signal ordy     : std_logic := '1';
  signal oput     : std_logic;

  signal resets   : std_logic_vector(imax(RESET_COUNT -1, 0) downto 0);
  signal pulses   : std_logic_vector(imax(PULSE_COUNT -1, 0) downto 0);
  signal switches : std_logic_vector(imax(SWITCH_COUNT-1, 0) downto 0);
  signal lights   : std_logic_vector(imax(LIGHT_COUNT-1, 0) downto 0);
  signal digits   : std_logic_vector(imax(4*DIGIT_COUNT-1, 0) downto 0);

  signal done : boolean := false;

begin  -- tb

  -- component instantiation
  DUT: remote_terminal_control
    generic map (
      RESET_COUNT  => RESET_COUNT,
      PULSE_COUNT  => PULSE_COUNT,
      SWITCH_COUNT => SWITCH_COUNT,
      LIGHT_COUNT  => LIGHT_COUNT,
      DIGIT_COUNT  => DIGIT_COUNT
    )
    port map (
      clk      => clk,
      rst      => rst,
      idat     => idat,
      istb     => istb,
      odat     => odat,
      ordy     => ordy,
      oput     => oput,
      resets   => resets,
      pulses   => pulses,
      switches => switches,
      lights   => lights,
      digits   => digits
    );
  lights <= b"10_0001_1101";
  digits <= x"5E";

  -- Stimuli
  process
    procedure cycle is
    begin
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end cycle;
  begin
    rst <= '1';
    cycle;
    rst <= '0';

    -- L
    idat <= "1001100";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;

    -- D
    idat <= "1000100";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;

    -- A
    idat <= "1000001";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;

    -- S
    idat <= "1010011";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;

    -- S 7A
    idat <= "1010011";
    istb <= '1';
    cycle;

    idat <= "0100000";
    istb <= '1';
    cycle;

    idat <= "0110111";
    istb <= '1';
    cycle;

    idat <= "1000001";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;

    -- S
    idat <= "1010011";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;

    -- R 5
    idat <= "1010010";
    istb <= '1';
    cycle;

    idat <= "0100000";
    istb <= '1';
    cycle;

    idat <= "0110101";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;

    -- P A8
    idat <= "1010000";
    istb <= '1';
    cycle;

    idat <= "0100000";
    istb <= '1';
    cycle;

    idat <= "1000001";
    istb <= '1';
    cycle;

    idat <= "0111000";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;

    -- P
    idat <= "1010000";
    istb <= '1';
    cycle;

    idat <= "0001010";
    istb <= '1';
    cycle;

    idat <= (others => '-');
    istb <= '0';
    while not done loop
      cycle;
    end loop;


    wait;                               -- forever

  end process;

  -- Output Reader
  process
    variable  c : character;
    variable  l : line;
  begin
    wait until rising_edge(clk);
    done <= false;
    ordy <= not ordy;
    if ordy = '1' and oput = '1' then
      c := character'val(to_integer(unsigned(odat)));
      if c = LF then
        writeline(output, l);
        done <= true;
      else
        write(l, c);
      end if;
    end if;
  end process;

end tb;
