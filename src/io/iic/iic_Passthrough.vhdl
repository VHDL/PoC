-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--                  Patrick Lehmann
--
-- Entity:				 	I2C passthrough module for an FPGA with debug/sniffing outputs
--
-- Description:
-- -------------------------------------
-- This module creates a transparent I2C path through an FPGA. In addition this
-- module offers a debug/sniffing line to log I2C operations.
--
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.STD_LOGIC_1164.all;
use     IEEE.NUMERIC_STD.all;

use     work.utils.all;
use     work.physical.all;
use     work.io.all;
use     work.iic.all;


entity iic_Passthrough is
	generic (
		CLOCK_FREQ     : FREQ    := 100 MHz;
		DEBOUNCE_TIME  : T_TIME  := 500.0e-9;
		SYNC_DEPTH     : natural := 3
	);
  port (
		Clock   : in    std_logic;
		Reset   : in    std_logic;
		
--  	Port_a  : inout T_IO_IIC_SERIAL := (others => (others => 'Z'));
  	Port_a_in  : in  T_IO_IIC_SERIAL_IN;
  	Port_a_out : out T_IO_IIC_SERIAL_OUT;
--		Port_b  : inout T_IO_IIC_SERIAL := (others => (others => 'Z'));
		Port_b_in  : in  T_IO_IIC_SERIAL_IN;
		Port_b_out : out T_IO_IIC_SERIAL_OUT;
		
		Debug   : out   T_IO_IIC_SERIAL_PCB
	);
end entity;


architecture rtl of iic_Passthrough is

	ATTRIBUTE MARK_DEBUG : string;
	constant GLITCH_POS : natural := 0;
	constant WAIT_POS   : natural := 1;
	
--	constant cycles  : natural := 20;--TimingToCycles(DEBOUNCE_TIME, CLOCK_FREQ);
	constant c_data  : natural := 1;
	constant c_clock : natural := 0;
	
	constant glitch_cycles : natural := 4;
	constant wait_cycles   : natural := 70;
	
	constant TIMING_TABLE	: T_NATVEC(0 to 1) := (GLITCH_POS => glitch_cycles, WAIT_POS => wait_cycles);

  signal debug_level     : std_logic_vector(1 downto 0);

	signal a_level_i         : std_logic_vector(1 downto 0);
	signal b_level_i         : std_logic_vector(1 downto 0);
	signal a_set           : std_logic_vector(1 downto 0) := (others => '0');
	signal b_set           : std_logic_vector(1 downto 0) := (others => '0');
--	signal a_set_d           : std_logic_vector(1 downto 0) := (others => '0');
--	signal b_set_d           : std_logic_vector(1 downto 0) := (others => '0');
--	signal a_set_fe        : std_logic_vector(1 downto 0);
--	signal b_set_fe        : std_logic_vector(1 downto 0);

  type t_state is (IDLE, ST_A, ST_B, ST_BW, ST_AW);	
  
	ATTRIBUTE MARK_DEBUG of a_level_i      : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of b_level_i      : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of a_set          : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of b_set          : SIGNAL IS "TRUE";
--	ATTRIBUTE MARK_DEBUG of a_set_d          : SIGNAL IS "TRUE";
--	ATTRIBUTE MARK_DEBUG of b_set_d          : SIGNAL IS "TRUE";
--	ATTRIBUTE MARK_DEBUG of a_set_fe          : SIGNAL IS "TRUE";
--	ATTRIBUTE MARK_DEBUG of b_set_fe          : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of debug_level    : SIGNAL IS "TRUE";

begin
--	a_set_d               <= a_set when rising_edge(clock);
--	b_set_d               <= b_set when rising_edge(clock);
--	a_set_fe              <= a_set_d and not a_set;
--	b_set_fe              <= b_set_d and not b_set;
	
	--SCL
	port_a_out.clock_O    <= '0';--a_set_fe(c_clock);
	port_a_out.clock_T    <= not a_set(c_clock);-- when rising_edge(clock);

	port_b_out.clock_O    <= '0';--b_set_fe(c_clock);
	port_b_out.clock_T    <= not b_set(c_clock);-- when rising_edge(clock);
	

	debug.clock       <= debug_level(c_clock);

	--SDA
	port_a_out.data_O     <= '0';--a_set_fe(c_data);
	port_a_out.data_T     <= not a_set(c_data);-- when rising_edge(clock);

	port_b_out.data_O     <= '0';--b_set_fe(c_data);
	port_b_out.data_T     <= not b_set(c_data);-- when rising_edge(clock);

	debug.data        <= debug_level(c_data);


--  sync : entity work.sync_Bits
--  generic map(
--    BITS          => 4,
--    INIT          => x"FFFFFFFF",
--    SYNC_DEPTH    => SYNC_DEPTH
--  )
--  port map(
--    Clock         => clock,
--    Input(0)      => port_a_in.data,
--    Input(1)      => port_b_in.data,
--    Input(2)      => port_a_in.clock,
--    Input(3)      => port_b_in.clock,
--    Output(0)     => a_level(c_data),
--    Output(1)     => b_level(c_data),
--    Output(2)     => a_level(c_clock),
--    Output(3)     => b_level(c_clock)
--  );
--  Clock_debounce : entity work.sync_Bits
--  generic map(
--    BITS                    => 4
--  )
--  port map(
--    Clock		      => Clock,
--    Input(0)      => port_a_in.data,
--    Input(1)      => port_b_in.data,
--    Input(2)      => port_a_in.clock,
--    Input(3)      => ,
--    Output(0)     => a_level_i(c_data),
--    Output(1)     => b_level_i(c_data),
--    Output(2)     => a_level_i(c_clock),
--    Output(3)     => b_level_i(c_clock)
--  );

	a_level_i(c_data)  <= port_a_in.data  when rising_edge(Clock);
	b_level_i(c_data)  <= port_b_in.data  when rising_edge(Clock);
	a_level_i(c_clock) <= port_a_in.clock when rising_edge(Clock);
	b_level_i(c_clock) <= port_b_in.clock when rising_edge(Clock);

	genFSM : for i in 0 to 1 generate
		ATTRIBUTE MARK_DEBUG : string;
		signal state      : t_state := IDLE;
--		signal wait_count : integer range 0 to cycles := cycles;
		signal a_level         : std_logic;
		signal b_level         : std_logic;
		
		signal Enable				: std_logic;																		-- enable counter
		signal Load					: std_logic;																		-- load Timing Value from TIMING_TABLE selected by slot
		signal Slot					: natural range 0 to (TIMING_TABLE'length - 1);	--
		signal Timeout			: std_logic;																			-- timing reached
		signal Timeout_d  	: std_logic := '0';																			-- timing reached
		signal Timeout_re  	: std_logic;																			-- timing reached
		
		ATTRIBUTE MARK_DEBUG of state    : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of a_level    : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of b_level    : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Enable    : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Load    : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Slot    : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Timeout    : SIGNAL IS "TRUE";
	begin
		Timeout_d <= Timeout when rising_edge(clock);
		Timeout_re <= Timeout and not Timeout_d;
	
		a_level <= a_level_i(i);
		b_level <= b_level_i(i);
	
		debug_level(i) <= '0' when state /= IDLE else '1';

		fsm : process(clock)
		begin
			if rising_edge(clock) then
				a_set(i) <= '0';
				b_set(i) <= '0';
				Slot     <= GLITCH_POS;
				Enable   <= '0';
				Load     <= '0';

				if reset = '1' then
					state      <= IDLE;
				else
					case state is
						when IDLE => 
							Slot     <= GLITCH_POS;
							if a_level = '0' then
								Load       <= '1';
								state      <= ST_A;
								b_set(i)   <= '1';
							end if;
							if b_level = '0' then 
								Load     <= '1';
								state    <= ST_B;
								a_set(i) <= '1';
							end if;

						when ST_A => 
							b_set(i) <= '1';
							Enable   <= '1';
								if a_level = '1' then 
									b_set(i) <= '0';
--									if Timeout = '1' and Load = '0' then
										Enable   <= '0';
										Slot     <= WAIT_POS;
										Load     <= '1';
										state    <= ST_AW;
--									else
--										state    <= IDLE;
--									end if;
								end if;
								
						when ST_AW => 
							Enable   <= '1';
							if a_level = '0' then 
								Slot     <= GLITCH_POS;
								Load       <= '1';
								state      <= ST_A;
								b_set(i)   <= '1';
							elsif Timeout_re = '1' then
								state      <= IDLE;
							end if;							

						when ST_B => 
							a_set(i) <= '1';
							Enable   <= '1';
								if b_level = '1' then 
									a_set(i) <= '0';
--									if Timeout = '1' and Load = '0' then
										Enable   <= '0';
										Slot     <= WAIT_POS;
										Load     <= '1';
										state    <= ST_BW;
--									else
--										state    <= IDLE;
--									end if;
								end if;
								
						when ST_BW => 
							Enable   <= '1';
							if b_level = '0' then 
								Slot     <= GLITCH_POS;
								Load       <= '1';
								state      <= ST_B;
								a_set(i)   <= '1';
							elsif Timeout_re = '1' then
								state      <= IDLE;
							end if;					
					end case;
				end if;
			end if;
		end process;
		
		counter : entity work.io_TimingCounter
		generic map(
			TIMING_TABLE	=> TIMING_TABLE
		)
		port map(
			Clock					=> clock,
			Enable				=> Enable,
			Load					=> Load,
			Slot					=> Slot,
			Timeout				=> Timeout
		);
  end generate;
  
  
end architecture;
