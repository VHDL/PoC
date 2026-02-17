-- =============================================================================
-- Authors:
--   Stefan Unrein
--   Adrian Weiland
--
-- Entity:
--
-- Description:
-- -------------------------------------
-- A BCD counting clock with nanoseconds resolution accessible via AXI4-Lite.
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
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
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.physical.all;
use     work.vectors.all;
use     work.axi4lite.all;
use     work.clock.all;


entity AXI4Lite_HighResolutionClock is
	generic (
		CLOCK_FREQUENCY      : FREQ;                                -- Frequency of input clock
		USE_CDC              : boolean             := False;        -- enable/disable CDC FIFO
		REGISTER_NANOSECONDS : natural             := 0 ;           -- NUM pipelining stages
		SECOND_RESOLUTION    : T_SECOND_RESOLUTION := NANOSECONDS   -- Time_sec_res in NANOSECONDS, MICROSECONDS or MILLISECONDS
	);
	port (
		Clock   : in std_logic;
		Reset   : in std_logic;

		AXI_clock    : in  std_logic;
		AXI_reset    : in  std_logic;
		AXI4Lite_m2s : in  T_AXI4Lite_BUS_M2S;
		AXI4Lite_s2m : out T_AXI4Lite_BUS_S2M;

		Nanoseconds  : out unsigned(63 downto 0);
		Datetime     : out T_CLOCK_DATETIME
	);
end entity;


architecture rtl of AXI4Lite_HighResolutionClock is
	constant PERIOD_NANOSECONDS : natural := TimingToCycles(1.0e-9, CLOCK_FREQUENCY);

	function generateRegisterConfiguration return T_AXI4_Register_Vector is
		variable temp : T_AXI4_Register_Vector(0 to 9);
		variable pos  : natural := 0;
		variable addr : natural := 0;
	begin
		--                              IRQ
		--temp(pos) := to_AXI4_Register(Name => "Dummy_register",            Address => to_unsigned(addr, 32), RegisterMode => ReadOnly);       -- Dummy register for later use
		addr := addr + 4; -- pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Config_reg",                Address => to_unsigned(addr, 32), RegisterMode => ReadWrite);  -- (en, inc, correction_threshold(29..0))
		addr := addr + 4; pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Nanoseconds_lower",         Address => to_unsigned(addr, 32), RegisterMode => ReadOnly);       -- Nanoseconds(31..0)
		addr := addr + 4; pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Nanoseconds_upper",         Address => to_unsigned(addr, 32), RegisterMode => ReadOnly);       -- Nanoseconds(63..32)  -> trigger on upper
		addr := addr + 4; pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Time_HMS",                  Address => to_unsigned(addr, 32), RegisterMode => ReadOnly);       -- Time
		addr := addr + 4; pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Date_Ymd",                  Address => to_unsigned(addr, 32), RegisterMode => ReadOnly);       -- Date
		addr := addr + 4; pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Time_sec_res",              Address => to_unsigned(addr, 32), RegisterMode => ReadOnly);       -- ns, ms or us counter
		addr := addr + 4; pos := pos + 1;
		addr := addr + 4;  -- dummy register
		temp(pos) := to_AXI4_Register(Name => "Nanoseconds_to_load_lower", Address => to_unsigned(addr, 32), RegisterMode => ReadWrite_NotRegistered);  -- todo: clear on read? Nanoseconds to load
		addr := addr + 4; pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Nanoseconds_to_load_upper", Address => to_unsigned(addr, 32), RegisterMode => ReadWrite_NotRegistered);  -- Nanoseconds to load
		addr := addr + 4; pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Datetime_to_load_HMS",      Address => to_unsigned(addr, 32), RegisterMode => ReadWrite_NotRegistered);  -- Datetime to be loaded
		addr := addr + 4; pos := pos + 1;
		temp(pos) := to_AXI4_Register(Name => "Datetime_to_load_Ymd",      Address => to_unsigned(addr, 32), RegisterMode => ReadWrite_NotRegistered);  -- Datetime to be loaded
		addr := addr + 4; pos := pos + 1;
		return temp(0 to pos - 1);
	end function;

	constant RegisterConfiguration : T_AXI4_Register_Vector := generateRegisterConfiguration;

	signal Reg_WritePort           : T_SLVV(0 to (RegisterConfiguration'length - 1))(31 downto 0) := (others => (others => '0'));
	signal Reg_ReadPort            : T_SLVV(0 to (RegisterConfiguration'length - 1))(31 downto 0) := (others => (others => '0'));
	signal Reg_ReadPort_hit        : std_logic_vector(0 to (RegisterConfiguration'length - 1))    := (others => '0');

	signal AXI4Lite_m2s_b : AXI4Lite_m2s'subtype;  -- buffered AXI signal
	signal AXI4Lite_s2m_b : AXI4Lite_s2m'subtype;  -- buffered AXI signal

	signal Nanoseconds_registers : T_SLUV(0 to REGISTER_NANOSECONDS)(63 downto 0) := (others => (others => '0'));
	signal Nanoseconds_i         : Nanoseconds'subtype;

	signal Load_nanoseconds     : std_logic := '0';
	signal Load_datetime        : std_logic := '0';
	signal Nanoseconds_to_load  : Nanoseconds'subtype;
	signal Datetime_to_load_slv : std_logic_vector(63 downto 0) := (others => '0');
	signal Datetime_to_load     : Datetime'subtype;

	signal Config_reg : unsigned(31 downto 0);

	-- nanosecond counter correction
	signal Ns_inc                : std_logic := '0';
	signal Ns_dec                : std_logic := '0';
	signal en                    : std_logic := '0';
	signal inc                   : std_logic := '0';
	signal disable               : std_logic := '0';
	signal correction            : std_logic := '0';
	signal correction_counter    : unsigned(29 downto 0) := (others => '0');
	signal correction_threshold  : unsigned(29 downto 0) := (others => '0');

begin
	Pipelining_gen: if REGISTER_NANOSECONDS > 0 generate
		Pipelining: process(Clock)
		begin
			if rising_edge(Clock) then
				Nanoseconds_registers(0) <= Nanoseconds_i - to_unsigned(REGISTER_NANOSECONDS * PERIOD_NANOSECONDS, 64);  -- substract delay of registering from initial value
				for i in 1 to REGISTER_NANOSECONDS loop
					Nanoseconds_registers(i) <= Nanoseconds_registers(i - 1);
				end loop;
			end if;
		end process;
	else generate
		Nanoseconds_registers(0) <= Nanoseconds_i;
	end generate;
	Nanoseconds <= Nanoseconds_registers(REGISTER_NANOSECONDS);

	CDC_gen: if USE_CDC generate
		FIFO_CDC: entity work.AXI4Lite_FIFO_CDC
			port map (
				-- IN Port
				In_Clock   => AXI_clock,
				In_Reset   => AXI_reset,
				In_M2S     => AXI4Lite_m2s,
				In_S2M     => AXI4Lite_s2m,
				-- OUT Port
				Out_Clock  => Clock,
				Out_Reset  => Reset,
				Out_M2S    => AXI4Lite_m2s_b,
				Out_S2M    => AXI4Lite_s2m_b
			);
	else generate
		AXI4Lite_m2s_b <= AXI4Lite_m2s;
		AXI4Lite_s2m   <= AXI4Lite_s2m_b;
	end generate;

	ClockRegister : entity work.AXI4Lite_Register
		generic map (
			CONFIG        => RegisterConfiguration
		)
		port map (
			Clock                      => Clock,
			Reset                      => Reset,
			AXI4Lite_m2s             => AXI4Lite_m2s_b,
			AXI4Lite_s2m             => AXI4Lite_s2m_b,
			RegisterFile_ReadPort      => Reg_ReadPort,
			RegisterFile_ReadPort_hit  => Reg_ReadPort_hit,
			RegisterFile_WritePort     => Reg_WritePort
		);

	Reg_WritePort(get_index("Nanoseconds_lower", RegisterConfiguration)) <= std_logic_vector(Nanoseconds(31 downto 0));
	Reg_WritePort(get_index("Nanoseconds_upper", RegisterConfiguration)) <= std_logic_vector(Nanoseconds(63 downto 32));
	Reg_WritePort(get_index("Time_sec_res",      RegisterConfiguration)) <= std_logic_vector(Datetime.secondsResolution);
	Reg_WritePort(get_index("Time_HMS",          RegisterConfiguration)) <= (
		 5 downto  0 => std_logic_vector(Datetime.Seconds),
		11 downto  6 => std_logic_vector(Datetime.Minutes),
		16 downto 12 => std_logic_vector(Datetime.Hours),
		31 downto 17 => std_logic_vector(to_unsigned(0, 15))  -- reserved
	);
	Reg_WritePort(get_index("Date_Ymd", RegisterConfiguration))          <= (
		 4 downto  0 => std_logic_vector(Datetime.Day),
		 8 downto  5 => std_logic_vector(Datetime.Month),
		21 downto  9 => std_logic_vector(Datetime.Year),
		31 downto 22 => std_logic_vector(to_unsigned(0, 10))  -- reserved
	);

	-- Register time of load registers when upper register is hit, only writing to the lower register will not have an effect.
	Nanoseconds_to_load(31 downto 0)  <= unsigned(Reg_ReadPort(get_index("Nanoseconds_to_load_lower", RegisterConfiguration))) when rising_edge(Clock) and Reg_ReadPort_hit(get_index("Nanoseconds_to_load_lower", RegisterConfiguration)) = '1';
	Nanoseconds_to_load(63 downto 32) <= unsigned(Reg_ReadPort(get_index("Nanoseconds_to_load_upper", RegisterConfiguration))) when rising_edge(Clock);

	Datetime_to_load_slv(31 downto 0)  <= Reg_ReadPort(get_index("Datetime_to_load_HMS", RegisterConfiguration)) when rising_edge(Clock) and Reg_ReadPort_hit(get_index("Datetime_to_load_HMS", RegisterConfiguration)) = '1';
	Datetime_to_load_slv(63 downto 32) <= Reg_ReadPort(get_index("Datetime_to_load_Ymd", RegisterConfiguration)) when rising_edge(Clock);
	Datetime_to_load                   <= slv_to_datetime(Datetime_to_load_slv(31 downto 0), Datetime_to_load_slv(63 downto 32));  -- type conversion with function from clock.pkg.vhdl

	Load_nanoseconds <= Reg_ReadPort_hit(get_index("Nanoseconds_to_load_upper", RegisterConfiguration)) when rising_edge(Clock);  -- flag which indicates that a new time has to be loaded
	Load_datetime    <= Reg_ReadPort_hit(get_index("Datetime_to_load_Ymd",      RegisterConfiguration)) when rising_edge(Clock);  -- flag which indicates that a new time has to be loaded

	HRClock: entity work.clock_HighResolution
		generic map (
			CLOCK_FREQUENCY     => CLOCK_FREQUENCY,
			SECOND_RESOLUTION   => SECOND_RESOLUTION
		)
		port map (
			Clock               => Clock,
			Reset               => Reset,

			Load_nanoseconds    => Load_nanoseconds,
			Load_datetime       => Load_datetime,
			Nanoseconds_to_load => Nanoseconds_to_load,
			Datetime_to_load    => Datetime_to_load,
			Ns_inc              => Ns_inc,
			Ns_dec              => Ns_dec,

			Nanoseconds         => Nanoseconds_i,
			Datetime            => Datetime
	);

	Config_reg           <= unsigned(Reg_ReadPort(get_index("Config_reg", RegisterConfiguration)));
	en                   <= Config_reg(31);                              -- enable increment / decrement
	inc                  <= Config_reg(30);                              -- increment / decrement
	correction_threshold <= Config_reg(29 downto 0);                     -- threshold in amount of clock cycles when a correction should be made
	disable              <= '1' when correction_threshold = 0 else '0';  -- internal disable signal in case no valid threshold is set
	correction_proc: process(all)
	begin
		if rising_edge(Clock) then
			correction <= '0';
			if (Reset or Load_nanoseconds) = '1' then
				correction_counter <= (others => '0');
			elsif correction_counter >= correction_threshold - 1 then
				correction         <= '1';
				correction_counter <= (others => '0');
			else
				correction_counter <= correction_counter + 1;
			end if;
		end if;
	end process;
	Ns_inc <= en and     inc and correction and not disable when rising_edge(Clock);  -- en and inc     and correction and not disable
	Ns_dec <= en and not inc and correction and not disable when rising_edge(Clock);  -- en and not inc and correction and not disable
end architecture;
