-- EMACS settings: -*-  tab-width:2  -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-------------------------------------------------------------------------------
-- Description:  Testbench for scaler.
--               See DUT description for details.
--
-- Authors:      Thomas B. Preusser <thomas.preusser@utexas.edu>
-------------------------------------------------------------------------------
-- Copyright 2007-2014 Technische Universität Dresden - Germany
--                     Chair for VLSI-Design, Diagnostics and Architecture
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
entity scaler_tb is
end scaler_tb;

library poc;
use poc.functions.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture tb of scaler_tb is

  component scaler
    generic (
      MULS : T_POSVEC := (0 => 1);
      DIVS : T_POSVEC := (0 => 1)
    );
    port (
      clk   : in  std_logic;
      rst   : in  std_logic;
      start : in  std_logic;
      arg   : in  std_logic_vector;
      msel  : in  std_logic_vector(log2ceil(MULS'length)-1 downto 0);
      dsel  : in  std_logic_vector(log2ceil(DIVS'length)-1 downto 0);
      done  : out std_logic;
      res   : out std_logic_vector
    );
  end component;

  -- component generics
  constant MULS : T_POSVEC := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  constant DIVS : T_POSVEC := (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  constant ARGS : T_NATVEC := (0, 1, 2, 3, 4, 31, 32, 33, 63, 64, 65, 95, 96, 97);

  -- component ports
  signal clk   : std_logic;
  signal rst   : std_logic;

  signal start : std_logic;
  signal arg   : std_logic_vector(7 downto 0);
  signal msel  : std_logic_vector(log2ceil(MULS'length)-1 downto 0);
  signal dsel  : std_logic_vector(log2ceil(DIVS'length)-1 downto 0);

  signal done  : std_logic;
  signal res   : std_logic_vector(7 downto 0);

begin  -- tb

  
  -- component instantiation
  DUT: scaler
    generic map (
      MULS => MULS,
      DIVS => DIVS
    )
    port map (
      clk   => clk,
      rst   => rst,
      start => start,
      arg   => arg,
      msel  => msel,
      dsel  => dsel,
      done  => done,
      res   => res
    );

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

    for i in MULS'range loop
      for j in DIVS'range loop
        for k in ARGS'range loop
          arg <= std_logic_vector(to_unsigned(ARGS(k), arg'length));
          msel <= std_logic_vector(to_unsigned(i, msel'length));
          dsel <= std_logic_vector(to_unsigned(j, dsel'length));
          start <= '1';
          cycle;

          arg   <= (others => '-');
          msel  <= (others => '-');
          dsel  <= (others => '-');
          start <= '0';

          while done /= '1' loop
            cycle;
          end loop;

          assert res = std_logic_vector(to_unsigned(((ARGS(k)*MULS(i)+DIVS(j)/2)/DIVS(j)) mod 2**res'length, res'length))
            report
              "Computation error: "&
              integer'image(ARGS(k))&'*'&integer'image(MULS(i))&'/'&integer'image(DIVS(j))&
              " -> "&integer'image(to_integer(unsigned(res)))
            severity error;
        end loop;
      end loop;
    end loop;

    report "Test complete.";
    wait;

  end process;

end tb;
