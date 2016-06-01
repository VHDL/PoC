-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:  Thomas B. Preußer
--
-- Module:   Interface to Dot-Matrix LCD Controllers
--
-- Description:
-- ------------
--           TODO
--
-- License:
-- ============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--                     Chair for VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--              http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;

library PoC;
use PoC.physical.all;

entity lcd_dotmatrix is
  generic(
    CLOCK_FREQ : FREQ;
    DATA_WIDTH : positive;  				-- Width of data bus (4 or 8)

    T_W        : t_time     :=  500.0e-9; -- Minimum width of E pulse
    T_SU       : t_time     :=   60.0e-9; -- Minimum RS + R/W setup time
    T_H        : t_time     :=   20.0e-9; -- Minimum RS + R/W hole time
    T_C        : t_time     := 1000.0e-9; -- Minimum cycle time

    B_RECOVER_TIME : t_time := 5.0e-6  -- Recover time after cleared Busy flag
  );
  port(
    -- Global Reset and Clock
    clk, rst : in std_logic;

		skip_bf : in std_logic := '0';  		-- Skip test for cleared busy flag

    -- Upper Layer Interface
    rdy : out std_logic;  									 -- ready for command or data
    stb : in  std_logic;  									 -- input strobe
    cmd : in  std_logic;  									 -- command / no data selector
    dat : in  std_logic_vector(7 downto 0);  -- command or data word

    -- LCD Connections
    lcd_e     : out std_logic;  -- Enable
    lcd_rs    : out std_logic;  -- Register Select
    lcd_rw    : out std_logic;  -- Read /Write, Data Direction Selector
    lcd_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);  -- Data Input
    lcd_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0)  	-- Data Output
  );
end entity;


library IEEE;
use IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;

architecture rtl of lcd_dotmatrix is
	-- State -------------------------------------------------------------------
	type tState is (Recover, BusyTest, BusyHold, Idle, Setup, Enable, Hold);
	signal State     : tState    := Recover;
	signal NextState : tState;
	signal Hi        : std_logic := '1';
	signal BF        : std_logic := '-';
	signal Toggle    : std_logic;

	-- Command / Data Buffer ---------------------------------------------------
	signal Buf  : std_logic_vector(7 downto 0) := (others => '-');
	signal CD   : std_logic                    := '-';
	signal Load : std_logic;

	-- Cycle Counters ----------------------------------------------------------
	signal CountSetup  : std_logic;
	signal CountEnable : std_logic;
	signal CountHold   : std_logic;
	signal CountCycle  : std_logic;
	signal CountBusy   : std_logic;

	signal CountDone   : std_logic;

begin

	blkCount: block is
		-- Cycle Fragmentation Times
		constant COUNT_SX : integer := TimingToCycles(T_SU, CLOCK_FREQ, ROUND_UP)-2;
		constant COUNT_WX : integer := TimingToCycles(T_W,  CLOCK_FREQ, ROUND_UP)-2;
		constant COUNT_HX : integer := TimingToCycles(T_H,  CLOCK_FREQ, ROUND_UP)-2;
		constant COUNT_CX : integer := TimingToCycles(T_C-T_SU-T_W-T_H, CLOCK_FREQ, ROUND_UP)-2;

		-- Recover Time after cleared Busy Flag
		constant COUNT_BX : integer := TimingToCycles(B_RECOVER_TIME, CLOCK_FREQ, ROUND_UP)-2;

		constant COUNT_MAX : integer := imax(T_INTVEC'(COUNT_SX, COUNT_WX, COUNT_HX, COUNT_CX, COUNT_BX));
	begin

		genCountZ: if COUNT_MAX < 0 generate
			CountDone <= '1';
		end generate genCountZ;
		genCountNZ: if COUNT_MAX >= 0 generate
			constant COUNT_BITS : positive := log2ceil(COUNT_MAX+1)+1;
			signal Count : signed(COUNT_BITS-1 downto 0) := to_signed(COUNT_SX, COUNT_BITS);
		begin
			process(clk)
			begin
				if rising_edge(clk) then
					if rst = '1' or CountSetup = '1' then
						Count <= to_signed(COUNT_SX, Count'length);
					elsif CountEnable = '1' then
						Count <= to_signed(COUNT_WX, Count'length);
					elsif CountHold = '1' then
						Count <= to_signed(COUNT_HX, Count'length);
					elsif CountCycle = '1' then
						Count <= to_signed(COUNT_CX, Count'length);
					elsif CountBusy = '1' then
						Count <= to_signed(COUNT_BX, Count'length);
					elsif CountDone = '0' then
						Count <= Count - 1;
					else
						Count <= (others => '-');
					end if;
				end if;
			end process;
			CountDone <= Count(Count'left);
		end generate genCountNZ;

	end block blkCount;

  -- Transmission State ------------------------------------------------------
  process(clk)
  begin
    if clk'event and clk = '1' then
      if rst = '1' then
        State <= Recover;
        Buf   <= (others => '-');
        CD    <= '-';
      else
        State <= NextState;

        if Load = '1' then
          Buf <= dat;
          CD  <= not cmd;
				elsif Toggle = '1' then
					Buf <= swap(Buf, DATA_WIDTH);
        end if;
      end if;
    end if;
  end process;

  genDat8: if DATA_WIDTH = 8 generate
    Hi <= '0';
    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          BF <= '-';
        else
          BF <= lcd_dat_i(7);
        end if;
      end if;
    end process;
  end generate genDat8;
  genDat4: if DATA_WIDTH = 4 generate
    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          Hi <= '1';
          BF <= '-';
        else
					Hi <= Hi xor Toggle;
					if Hi = '1' then
						BF <= lcd_dat_i(3);
					end if;
        end if;
      end if;
    end process;
  end generate genDat4;


  -- State Machine -----------------------------------------------------------
  process(State, Hi, BF, CD, CountDone, stb, skip_bf)
  begin
    NextState <= State;

    Load        <= '0';
    Toggle      <= '0';
    CountSetup  <= '0';
    CountEnable <= '0';
    CountHold   <= '0';
    CountCycle  <= '0';
    CountBusy   <= '0';

		rdy			<= '0';	-- ready for output

    lcd_e     <= '0';
    lcd_rs    <= '0';
    lcd_rw    <= '1';

		case State is
			when Recover =>
				if CountDone = '1' then
					if skip_bf = '1' then
						NextState <= Idle;
					else
						CountEnable <= '1';
						NextState   <= BusyTest;
					end if;
				end if;

      when BusyTest =>
        lcd_e <= '1';
        if CountDone = '1' then
          if Hi = '1' or BF = '1' then
						CountEnable <= '1';
            NextState   <= Recover;
					else
						CountBusy <= '1';
						NextState <= BusyHold;
          end if;
          Toggle <= '1';
				end if;

			when BusyHold =>
				if CountDone = '1' then
					NextState <= Idle;
				end if;

      when Idle =>
        rdy <= '1';
        if stb = '1' then
          Load       <= '1';
          CountSetup <= '1';
          NextState  <= Setup;
        end if;

			when Setup =>
				lcd_rs	<= CD;
				lcd_rw	<= '0';
				if CountDone = '1' then
					CountEnable <= '1';
					NextState   <= Enable;
				end if;

			when Enable =>
				lcd_e	<= '1';
				lcd_rs	<= CD;
				lcd_rw	<= '0';
				if CountDone = '1' then
					CountHold <= '1';
					NextState <= Hold;
				end if;

      when Hold =>
        lcd_rs <= CD;
        lcd_rw <= '0';
        if CountDone = '1' then
					CountCycle <= '1';
					if Hi = '1' then
            NextState <= Setup;
					else
						NextState <= Recover;
					end if;
          Toggle <= '1';
        end if;

		end case;
	end process;
	lcd_dat_o <= Buf(Buf'left downto Buf'left-DATA_WIDTH+1);

end rtl;
