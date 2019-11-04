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
use     work.vectors.all;
use     work.io.all;
use     work.iic.all;


entity iic_Passthrough is
	generic (
		DEBUG                : boolean := false;
		CLOCK_FREQ           : FREQ    := 100 MHz;
		LOWEST_IIC_FREQ      : FREQ    := 70 kHz;
--		IIC_LOW_TIME         : T_TIME  := 6.4e-6;
--		SAVETY_MARGIN        : T_TIME  := 1.0e-6;
		GLITCH_CYCLES        : natural := 8;
		PULL_UP_CYCLES       : natural := 55;
		ENABLE_AKTIVE_PULLUP : boolean := false
	);
  port (
		Clock   : in    std_logic;
		Reset   : in    std_logic;
		
  	Port_a_in  : in  T_IO_IIC_SERIAL_IN;
  	Port_a_out : out T_IO_IIC_SERIAL_OUT;
  	
		Port_b_in  : in  T_IO_IIC_SERIAL_IN;
		Port_b_out : out T_IO_IIC_SERIAL_OUT;
		
--		MasterIsA  : in std_logic := '1';
		
		Port_Debug   : out   T_IO_IIC_SERIAL_PCB
	);
end entity;


architecture rtl of iic_Passthrough is
	ATTRIBUTE MARK_DEBUG     : string;
	
	constant data_pos        : natural := 1;
	constant clock_pos       : natural := 0;
	
	constant BITS            : natural := 8;
	
	constant high_low_counter_bits : natural := log2ceilnz(integer(div(CLOCK_FREQ, LOWEST_IIC_FREQ)) * 2) +1;
	
--	constant IIC_LOW_PER     : natural := TimingToCycles(IIC_LOW_TIME, CLOCK_FREQ);
--	constant SAVETY_CYCLES   : natural := TimingToCycles(SAVETY_MARGIN, CLOCK_FREQ);
	
	constant GLITCH_POS      : natural := 0;
	constant PULL_UP_POS     : natural := 1;
	constant ACK_WAIT_POS    : natural := 2;
	constant ACK_PULL_POS    : natural := 3;	

  signal debug_level     : std_logic_vector(1 downto 0);

	signal a_level_i         : std_logic_vector(1 downto 0);
	signal b_level_i         : std_logic_vector(1 downto 0);
	signal a_set           : std_logic_vector(1 downto 0) := (others => '0');
	signal b_set           : std_logic_vector(1 downto 0) := (others => '0');
	signal a_set_d           : std_logic_vector(1 downto 0) := (others => '0');
	signal b_set_d           : std_logic_vector(1 downto 0) := (others => '0');
	signal a_set_fe        : std_logic_vector(1 downto 0);
	signal b_set_fe        : std_logic_vector(1 downto 0);
	
	signal a_level_data_fe : std_logic;

  
	ATTRIBUTE MARK_DEBUG of a_level_i      : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of b_level_i      : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of a_set          : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of b_set          : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of a_set_d        : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of b_set_d        : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of a_set_fe       : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of b_set_fe       : SIGNAL IS "TRUE";
	ATTRIBUTE MARK_DEBUG of debug_level    : SIGNAL IS "TRUE";

begin
	
	a_set_d               <= a_set when rising_edge(clock);
	b_set_d               <= b_set when rising_edge(clock);
	a_set_fe              <= a_set_d and not a_set;
	b_set_fe              <= b_set_d and not b_set;
	
	--SCL---------------------------------------------------------------
	port_a_out.clock_O    <= ite(ENABLE_AKTIVE_PULLUP, a_set_fe(clock_pos), '0');
	port_a_out.clock_T    <= not a_set(clock_pos) when rising_edge(clock);

	port_b_out.clock_O    <= ite(ENABLE_AKTIVE_PULLUP, b_set_fe(clock_pos), '0');
	port_b_out.clock_T    <= not b_set(clock_pos) when rising_edge(clock);
	
	Port_Debug.clock       <= debug_level(clock_pos);
	
	a_level_i(clock_pos) <= port_a_in.clock when rising_edge(Clock); --One-Bit Sync
	b_level_i(clock_pos) <= port_b_in.clock when rising_edge(Clock); --One-Bit Sync
	-------------------------------------------------------------------

	--SDA--------------------------------------------------------------
	port_a_out.data_O     <= ite(ENABLE_AKTIVE_PULLUP, a_set_fe(data_pos), '0');
	port_a_out.data_T     <= not a_set(data_pos) when rising_edge(clock);

	port_b_out.data_O     <= ite(ENABLE_AKTIVE_PULLUP, b_set_fe(data_pos), '0');
	port_b_out.data_T     <= not b_set(data_pos) when rising_edge(clock);

	a_level_i(data_pos)  <= port_a_in.data  when rising_edge(Clock); --One-Bit Sync
	b_level_i(data_pos)  <= port_b_in.data  when rising_edge(Clock); --One-Bit Sync
	
	Port_Debug.data        <= debug_level(data_pos);
	------------------------------------------------------------------
	
	----------------------------------CLOCK----------------------------------------------------------
	clk_blk : block
		ATTRIBUTE MARK_DEBUG : string;
  	
  	type t_state is (IDLE, ST_A, ST_B, ST_BW, ST_AW, ST_ACKW, ST_ACK);	
  	
  	signal is_frame_start : std_logic;
		
		signal state      : t_state := IDLE;
--		signal wait_count : integer range 0 to cycles := cycles;
		signal a_level           : std_logic;
		signal a_level_glitch    : std_logic;
		signal a_level_glitch_d  : std_logic := '0';
		signal a_level_glitch_fe : std_logic;
		signal b_level           : std_logic;
		
		signal bit_counter       : unsigned(log2ceilnz(BITS) downto 0) := to_unsigned(BITS, log2ceilnz(BITS) +1);
		signal is_ACK_cycle      : std_logic;
		
--		signal high_counter_us   : unsigned(high_low_counter_bits -1 downto 0) := (others => '0');
		signal low_counter_us    : unsigned(high_low_counter_bits -1 downto 0) := (others => '0');
		
--		signal high_counter_us_i : unsigned(high_low_counter_bits -3 downto 0) := (others => '0');
		signal low_counter_us_i  : unsigned(high_low_counter_bits -3 downto 0) := (others => '0');
		
		signal Enable				: std_logic;																		-- enable counter
		signal Load					: std_logic;																		-- load Timing Value from TIMING_TABLE selected by slot
		signal Slot					: unsigned(1 downto 0);	--
		signal Timeout			: std_logic;																			-- timing reached
		signal Timeout_d  	: std_logic := '0';																			-- timing reached
		signal Timeout_re  	: std_logic;																			-- timing reached
		
		ATTRIBUTE MARK_DEBUG of state             : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of a_level           : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of a_level_glitch    : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of a_level_glitch_d  : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of a_level_glitch_fe : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of is_frame_start    : SIGNAL IS "TRUE";
--		ATTRIBUTE MARK_DEBUG of high_counter_us_i : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of low_counter_us_i  : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of b_level           : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of bit_counter       : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of is_ACK_cycle      : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Enable            : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Load              : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Slot              : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Timeout           : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Timeout_d         : SIGNAL IS "TRUE";
		ATTRIBUTE MARK_DEBUG of Timeout_re        : SIGNAL IS "TRUE";
	begin
		
		assert DEBUG report 
--			"IIC_LOW_PER = "          & integer'image(IIC_LOW_PER) & 
--			"  , SAVETY_CYCLES = "    & integer'image(SAVETY_CYCLES) &
			"  , high_low_counter_bits = " & integer'image(high_low_counter_bits)
--			"  , TIMING_TABLE(0) = "  & integer'image(TIMING_TABLE(0)) &
--			"  , TIMING_TABLE(1) = "  & integer'image(TIMING_TABLE(1)) &
--			"  , TIMING_TABLE(2) = "  & integer'image(TIMING_TABLE(2)) &
--			"  , TIMING_TABLE(3) = "  & integer'image(TIMING_TABLE(3))
		severity note;

		Glitch_Filter_master : entity work.io_GlitchFilter
		generic map(
			HIGH_SPIKE_SUPPRESSION_CYCLES			=> GLITCH_CYCLES,
			LOW_SPIKE_SUPPRESSION_CYCLES			=> GLITCH_CYCLES
		)
		port map(
			Clock		=> clock,
			Input		=> a_level_i(clock_pos),
			Output	=> a_level_glitch
		);
		
		a_level_glitch_d  <= a_level_glitch when rising_edge(clock);
		a_level_glitch_fe <= a_level_glitch_d and not a_level_glitch;
		
		is_frame_start    <= a_level_data_fe and a_level_glitch_d and a_level_glitch;
		
		Timeout_d <= Timeout when rising_edge(clock);
		Timeout_re <= Timeout and not Timeout_d;
	
		a_level <= a_level_i(clock_pos);
		b_level <= b_level_i(clock_pos);
	
		debug_level(clock_pos) <= '0' when state /= IDLE else '1';

		fsm : process(clock)
		begin
			if rising_edge(clock) then
				a_set(clock_pos) <= '0';
				b_set(clock_pos) <= '0';
				Slot     <= to_unsigned(GLITCH_POS, 2);
				Enable   <= '0';
				Load     <= '0';

				if reset = '1' then
					state      <= IDLE;
				else
					case state is
						when IDLE => 
							Slot     <= to_unsigned(GLITCH_POS, 2);
							if a_level = '0' then
								Load       <= '1';
								state      <= ST_A;
								b_set(clock_pos)   <= '1';
							end if;
							if b_level = '0' then 
								Load     <= '1';
								state    <= ST_B;
								a_set(clock_pos) <= '1';
							end if;

						when ST_A => 
							b_set(clock_pos) <= '1';
							Enable   <= '1';
								if a_level = '1' then 
									b_set(clock_pos) <= '0';
--									if Timeout = '1' and Load = '0' then
										Enable   <= '0';
										Slot     <= to_unsigned(PULL_UP_POS, 2);
										Load     <= '1';
										state    <= ST_AW;
--									else
--										state    <= IDLE;
--									end if;
								elsif is_ACK_cycle = '1' then
									Slot     <= to_unsigned(ACK_WAIT_POS, 2);
									Load     <= '1';
									state    <= ST_ACKW;
								end if;
								
						when ST_AW => 
							Enable   <= '1';
							if a_level = '0' then 
								Slot     <= to_unsigned(GLITCH_POS, 2);
								Load       <= '1';
								state      <= ST_A;
								b_set(clock_pos)   <= '1';
							elsif Timeout_re = '1' then
								state      <= IDLE;
							end if;			
						
						when ST_ACKW =>
							Enable   <= '1';
--							if a_level = '0' then
--								b_set(clock_pos)   <= '1';
--							end if;
							b_set(clock_pos)   <= '1';
							if is_ACK_cycle = '0' then
								Slot     <= to_unsigned(GLITCH_POS, 2);
								Load     <= '1';
								state    <= ST_A;
							elsif Timeout_re = '1' then
--								b_set(clock_pos)   <= '1';
								Slot       <= to_unsigned(ACK_PULL_POS, 2);
								Load       <= '1';
								state      <= ST_ACK;
							end if;
							
						when ST_ACK =>
							Enable           <= '1';
							a_set(clock_pos) <= '1';
							b_set(clock_pos) <= '1';
							if is_ACK_cycle = '0' then
								Slot     <= to_unsigned(GLITCH_POS, 2);
								Load     <= '1';
								state    <= ST_A;
							elsif Timeout_d = '1' then
								b_set(clock_pos) <= '0';
								if b_level = '1' then
									a_set(clock_pos) <= '0';
									if a_level = '1' then
										state      <= IDLE;
									end if;
								end if;
							end if;

						when ST_B => 
							a_set(clock_pos) <= '1';
							Enable   <= '1';
								if b_level = '1' then 
									a_set(clock_pos) <= '0';
--									if Timeout = '1' and Load = '0' then
										Enable   <= '0';
										Slot     <= to_unsigned(PULL_UP_POS, 2);
										Load     <= '1';
										state    <= ST_BW;
--									else
--										state    <= IDLE;
--									end if;
								end if;
								
						when ST_BW => 
							Enable   <= '1';
							if b_level = '0' then 
								Slot     <= to_unsigned(GLITCH_POS, 2);
								Load       <= '1';
								state      <= ST_B;
								a_set(clock_pos)   <= '1';
							elsif Timeout_re = '1' then
								state      <= IDLE;
							end if;					
					end case;
				end if;
			end if;
		end process;
		
		TimingCounter_blk : block
			ATTRIBUTE MARK_DEBUG : string;
			constant COUNTER_BITS : positive := 15;		
			
			signal TIMING_TABLE	: T_SLVV_16(0 to 3) := (
				GLITCH_POS   => (others => '0'),
				PULL_UP_POS  => (others => '0'),
				ACK_WAIT_POS => (others => '0'),
				ACK_PULL_POS => (others => '0')
			);	
			signal savety           : unsigned(low_counter_us_i'high -2 downto 0);
		
			signal Counter_s				: signed(COUNTER_BITS downto 0)		:= to_signed(glitch_cycles -1, COUNTER_BITS + 1);
			
			ATTRIBUTE MARK_DEBUG of TIMING_TABLE     : SIGNAL IS "TRUE";
			ATTRIBUTE MARK_DEBUG of savety           : SIGNAL IS "TRUE";
			ATTRIBUTE MARK_DEBUG of Counter_s        : SIGNAL IS "TRUE";
		begin	
			TIMING_TABLE(GLITCH_POS)   <= std_logic_vector(to_signed(glitch_cycles, COUNTER_BITS +1));
			TIMING_TABLE(PULL_UP_POS)  <= std_logic_vector(to_signed(PULL_UP_CYCLES, COUNTER_BITS +1));
			TIMING_TABLE(ACK_WAIT_POS) <= '0' & std_logic_vector(resize(low_counter_us_i - savety, 15));
			TIMING_TABLE(ACK_PULL_POS) <= '0' & std_logic_vector(resize(2* savety, 15));
			
			savety <= low_counter_us_i(low_counter_us_i'high downto 2); --Use 25% (div by 4) for savety margin
		
			process(Clock)
			begin
				if rising_edge(Clock) then
					if (Load = '1') then
						Counter_s		<= signed(TIMING_TABLE(to_integer(Slot)));
					elsif ((Enable = '1') and (Counter_s(Counter_s'high) = '0')) then
						Counter_s	<= Counter_s - 1;
					end if;
				end if;
			end process;

			Timeout <= Counter_s(Counter_s'high);
		
--		counter : entity work.io_TimingCounter
--		generic map(
--			TIMING_TABLE	=> TIMING_TABLE
--		)
--		port map(
--			Clock					=> clock,
--			Enable				=> Enable,
--			Load					=> Load,
--			Slot					=> Slot,
--			Timeout				=> Timeout
--		);
		end block;
		
		is_ACK_cycle <= to_sl(bit_counter = BITS);
		
		Bit_counter_proc : process(clock)
		begin
			if rising_edge(clock) then
				if reset = '1' then
					bit_counter <= to_unsigned(BITS, bit_counter'length);
				elsif a_level_glitch_fe = '1' then
					if bit_counter < BITS then
						bit_counter <= bit_counter +1;
					else
						bit_counter <= (others => '0');
					end if;
				elsif is_frame_start = '1' then
					bit_counter <= (others => '0');
				end if;
			end if;
		end process;
		
--		high_counter_us_i <= high_counter_us(high_counter_us'high downto 2);
		low_counter_us_i  <= low_counter_us(low_counter_us'high downto 2);
		
		high_low_counter_proc : process(clock)
		begin
			if rising_edge(clock) then
				if bit_counter = 0 then
					low_counter_us  <= (others => '0');
--					high_counter_us <= (others => '0');
				elsif (bit_counter < BITS) and (bit_counter > 3) then
					if a_level_glitch = '0' then
						low_counter_us <= low_counter_us +1;
					end if;
--					if a_level_glitch = '1' then
--						high_counter_us <= high_counter_us +1;
--					end if;
				end if;
			end if;
		end process;
	end block;
	
	---------------------------------------------DATA--------------------------------------------------------
	data_blk : block
		ATTRIBUTE MARK_DEBUG : string;
		
		constant TIMING_TABLE	: T_NATVEC(0 to 1) := (GLITCH_POS => glitch_cycles, PULL_UP_POS => PULL_UP_CYCLES);
		
  	type t_state is (IDLE, ST_A, ST_B, ST_BW, ST_AW);	
		
		signal state      : t_state := IDLE;
--		signal wait_count : integer range 0 to cycles := cycles;
		signal a_level         : std_logic;
		signal b_level         : std_logic;
		
		signal a_level_glitch    : std_logic;
		signal a_level_glitch_d  : std_logic := '0';
		
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
		Glitch_Filter_master_data : entity work.io_GlitchFilter
		generic map(
			HIGH_SPIKE_SUPPRESSION_CYCLES			=> GLITCH_CYCLES,
			LOW_SPIKE_SUPPRESSION_CYCLES			=> GLITCH_CYCLES
		)
		port map(
			Clock		=> clock,
			Input		=> a_level_i(data_pos),
			Output	=> a_level_glitch
		);
		a_level_glitch_d <= a_level_glitch when rising_edge(clock);
		a_level_data_fe  <= a_level_glitch_d and not a_level_glitch;
		
		Timeout_d <= Timeout when rising_edge(clock);
		Timeout_re <= Timeout and not Timeout_d;
	
		a_level <= a_level_i(data_pos);
		b_level <= b_level_i(data_pos);
	
		debug_level(data_pos) <= '0' when state /= IDLE else '1';

		fsm : process(clock)
		begin
			if rising_edge(clock) then
				a_set(data_pos) <= '0';
				b_set(data_pos) <= '0';
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
								b_set(data_pos)   <= '1';
							end if;
							if b_level = '0' then 
								Load     <= '1';
								state    <= ST_B;
								a_set(data_pos) <= '1';
							end if;

						when ST_A => 
							b_set(data_pos) <= '1';
							Enable   <= '1';
								if a_level = '1' then 
									b_set(data_pos) <= '0';
--									if Timeout = '1' and Load = '0' then
										Enable   <= '0';
										Slot     <= PULL_UP_POS;
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
								b_set(data_pos)   <= '1';
							elsif Timeout_re = '1' then
								state      <= IDLE;
							end if;							

						when ST_B => 
							a_set(data_pos) <= '1';
							Enable   <= '1';
								if b_level = '1' then 
									a_set(data_pos) <= '0';
--									if Timeout = '1' and Load = '0' then
										Enable   <= '0';
										Slot     <= PULL_UP_POS;
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
								a_set(data_pos)   <= '1';
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
	end block;

end architecture;
