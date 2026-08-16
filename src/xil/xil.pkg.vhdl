-- =============================================================================
-- Authors:   Patrick Lehmann
--
-- Entity:    VHDL package for component declarations, types and functions
--            associated to the PoC.xil namespace
--
-- Description:
-- -------------------------------------
--    This package declares types and components for
--      - Xilinx Dynamic Reconfiguration Port (DRP) related types
--      - SystemMonitor for FPGA core temperature measurement and fan control
--        (see PoC.io.FanControl)
--      - Component declarations for Xilinx related modules
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
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
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.config.all;
use     work.utils.all;
use     work.vectors.all;


package xil is
	-- ChipScope
	-- ==========================================================================
	subtype T_XIL_CHIPSCOPE_CONTROL          is std_logic_vector(35 downto 0);
	type    T_XIL_CHIPSCOPE_CONTROL_VECTOR  is array (natural range <>) of T_XIL_CHIPSCOPE_CONTROL;

	-- Dynamic Reconfiguration Port (DRP)
	-- ==========================================================================
	subtype T_XIL_DRP_ADDRESS                is T_SLV_16;
	subtype T_XIL_DRP_DATA                  is T_SLV_16;

	type T_XIL_DRP_ADDRESS_VECTOR is array (natural range <>) of T_XIL_DRP_ADDRESS;
	type T_XIL_DRP_DATA_VECTOR    is array (natural range <>) of T_XIL_DRP_DATA;

	type T_XIL_DRP_BUS_IN is record
		Clock     : std_logic;
		Enable    : std_logic;
		ReadWrite : std_logic;
		Address   : T_XIL_DRP_ADDRESS;
		Data      : T_XIL_DRP_DATA;
	end record;

	constant C_XIL_DRP_BUS_IN_EMPTY : T_XIL_DRP_BUS_IN := (
		Clock     => '0',
		Enable    => '0',
		ReadWrite => '0',
		Address   => (others => '0'),
		Data      => (others => '0')
	);

	type T_XIL_DRP_BUS_OUT is record
		Data : T_XIL_DRP_DATA;
		Ack  : std_logic;
	end record;

	constant C_XIL_DRP_BUS_OUT_EMPTY : T_XIL_DRP_BUS_OUT := (
		Ack       => '0',
		Data      => (others => '0')
	);

	type T_XIL_DRP_CONFIG is record
	Address : T_XIL_DRP_ADDRESS;
	Mask    : T_XIL_DRP_DATA;
	Data    : T_XIL_DRP_DATA;
	end record;

-- define array indices
	constant C_XIL_DRP_MAX_CONFIG_COUNT : positive := 8;

	subtype T_XIL_DRP_CONFIG_INDEX  is integer range 0 to C_XIL_DRP_MAX_CONFIG_COUNT - 1;
	type    T_XIL_DRP_CONFIG_VECTOR is array (natural range <>) of T_XIL_DRP_CONFIG;

	type T_XIL_DRP_CONFIG_SET is record
		Configs   : T_XIL_DRP_CONFIG_VECTOR(T_XIL_DRP_CONFIG_INDEX);
		LastIndex : T_XIL_DRP_CONFIG_INDEX;
	end record;

	type T_XIL_DRP_CONFIG_ROM is array (natural range <>) of T_XIL_DRP_CONFIG_SET;

	constant C_XIL_DRP_CONFIG_EMPTY : T_XIL_DRP_CONFIG := (
		Address => (others => '0'),
		Data    => (others => '0'),
		Mask    => (others => '0')
	);

	constant C_XIL_DRP_CONFIG_SET_EMPTY : T_XIL_DRP_CONFIG_SET := (
		Configs   => (others => C_XIL_DRP_CONFIG_EMPTY),
		LastIndex => 0
	);

	function get_DNABITS return natural;

	type T_ALARM_MODE is (ALARM_MODE_HYSTERESIS, ALARM_MODE_WINDOW);

	function get_valueSysMon_SYSMONE4_USplus_OverTempUpper(temp : real) return std_logic_vector;
	function get_valueSysMon_SYSMONE4_USplus_TempLower(temp : real; mode : T_ALARM_MODE) return std_logic_vector;
	function get_valueSysMon_SYSMONE4_USplus_UserTempUpper(temp : real) return std_logic_vector;

	-- helper function to compute UG580 Equation 2-11
	function temp_to_adc_SYSMONE4(temp : real; bits : positive) return std_logic_vector;

------------COMPONENTS---------------------------
	component xil_SystemMonitor is
		port (
			Reset          : in  std_logic;  -- Reset signal for the System Monitor control logic

			Alarm_UserTemp : out std_logic; -- Temperature-sensor alarm output
			Alarm_OverTemp : out std_logic; -- Over-Temperature alarm output
			Alarm          : out std_logic; -- OR'ed output of all the alarms
			VP             : in  std_logic;  -- Dedicated analog input pair
			VN             : in  std_logic
		);
	end component;

	component xil_DNAPort is
		generic (
			SIM_DNA_VALUE : bit_vector := resize("0", get_DNABITS)   -- DNA value for simulation
		);
		port (
			Clock   : in  std_logic;
			Reset   : in  std_logic;
			Valid   : out std_logic;
			DataOut : out std_logic_vector(get_DNABITS -1 downto 0)
		);
	end component;

	component xil_ClockBuffer is
	port (
		Clock_In     : in  std_logic;
		Clock_Enable : in  std_logic := '1';
		Clock_Out    : out std_logic
	);
	end component;
end package;


package body xil is

	function get_DNABITS return natural is
	begin
		case THIS_DEVICE.DevSeries is
			when DEVICE_SERIES_7_SERIES     => return 64;
			when DEVICE_SERIES_ULTRASCALE_PLUS |
				 DEVICE_SERIES_ULTRASCALE   => return 96;
			when others => 
				report "DNABITS not implemented for selected device!" severity failure;
				return 0;
		end case;
	end function;

	--calculations based on UG580, section "Over Temperature Automatic Shutdown"

	function get_valueSysMon_SYSMONE4_USplus_OverTempUpper(temp : real) return std_logic_vector is
		variable var : std_logic_vector(15 downto 0);
	begin
		var := temp_to_adc_SYSMONE4(temp, 12) & 4x"3";
		return var;
	end function;

	function get_valueSysMon_SYSMONE4_USplus_TempLower(temp : real; mode : T_ALARM_MODE) return std_logic_vector
	is
		variable var      : real;
		variable ret      : std_logic_vector(15 downto 0);
		variable mode_bit : std_logic;
	begin
		with mode select mode_bit :=
		'0' when ALARM_MODE_HYSTERESIS,
		'1' when ALARM_MODE_WINDOW;
		ret := temp_to_adc_SYSMONE4(temp, 15) & mode_bit;
		return ret;
	end function;

	function get_valueSysMon_SYSMONE4_USplus_UserTempUpper(temp : real) return std_logic_vector is
	begin
		return temp_to_adc_SYSMONE4(temp, 16);
	end function;

	function temp_to_adc_SYSMONE4(temp : real; bits : positive) return std_logic_vector
	is
		variable var : real;
	begin
		var := ((temp + 280.2308787) * (2.0 ** bits) / 509.3140064) + 0.5;
		return std_logic_vector(to_unsigned(integer(var), bits));
	end function;

end package body;
