-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Stefan Unrein
--									Max Kraft-Kugler
--									Patrick Lehmann
--									Asif Iqbal
--
-- Package:					TBD
--
-- Description:
-- -------------------------------------
--		For detailed documentation see below.
--
-- License:
-- =============================================================================
-- Copyright 2017-2019 PLC2 Design GmbH, Germany
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
use     IEEE.STD_LOGIC_1164.ALL;
use     IEEE.NUMERIC_STD.ALL;

use     work.utils.all;
use     work.iic.all;


entity iic_RawMultiplexer is
	generic (
		PORTS : positive := 2
	);
	port (
		sel       : in  unsigned(log2ceilnz(PORTS) - 1 downto 0);
		broadcast : in  std_logic := '0';
		Input_m2s : in  T_IO_IIC_SERIAL_OUT_VECTOR(PORTS - 1 downto 0);
		Input_s2m : out T_IO_IIC_SERIAL_IN_VECTOR(PORTS - 1 downto 0);
			
		Output_m2s : out T_IO_IIC_SERIAL_OUT;
		Output_s2m : in  T_IO_IIC_SERIAL_IN
	);
end entity;

architecture rtl of iic_RawMultiplexer is
	function get_clock_t_and(input : T_IO_IIC_SERIAL_OUT_VECTOR) return std_logic is
		variable temp : std_logic_vector(input'range);
	begin
		for i in input'range loop
			temp(i) := input(i).clock_t;
		end loop;
		return slv_and(temp);
	end function;
	
	function get_data_t_and(input : T_IO_IIC_SERIAL_OUT_VECTOR) return std_logic is
		variable temp : std_logic_vector(input'range);
	begin
		for i in input'range loop
			temp(i) := input(i).data_t;
		end loop;
		return slv_and(temp);
	end function;
	
	function get_clock_o_and(input : T_IO_IIC_SERIAL_OUT_VECTOR) return std_logic is
		variable temp : std_logic_vector(input'range);
	begin
		for i in input'range loop
			temp(i) := input(i).clock_o;
		end loop;
		return slv_and(temp);
	end function;
	
	function get_data_o_and(input : T_IO_IIC_SERIAL_OUT_VECTOR) return std_logic is
		variable temp : std_logic_vector(input'range);
	begin
		for i in input'range loop
			temp(i) := input(i).data_o;
		end loop;
		return slv_and(temp);
	end function;
	
	signal is_Clock_t : std_logic;
	signal is_Data_t : std_logic;
	signal is_Clock_o : std_logic;
	signal is_Data_o : std_logic;
begin
	gen: for i in 0 to PORTS - 1 generate
		Input_s2m(i).Clock <= Output_s2m.Clock when (sel = i) or (broadcast = '1') else '0';
		Input_s2m(i).Data  <= Output_s2m.Data  when (sel = i) or (broadcast = '1') else '0';
	end generate;
	
	is_Clock_t         <= get_clock_t_and(Input_m2s);
	is_Clock_o         <= get_clock_o_and(Input_m2s);
	is_Data_t          <= get_data_t_and(Input_m2s);
	is_Data_o          <= get_data_o_and(Input_m2s);
	Output_m2s.Clock_O <= ite(broadcast = '0', Input_m2s(to_index(sel)).Clock_O, is_Clock_o);
	Output_m2s.Clock_T <= ite(broadcast = '0', Input_m2s(to_index(sel)).Clock_T, is_Clock_t);
	Output_m2s.Data_O  <= ite(broadcast = '0', Input_m2s(to_index(sel)).Data_O, is_Data_o);
	Output_m2s.Data_T  <= ite(broadcast = '0', Input_m2s(to_index(sel)).Data_T, is_Data_t);
end architecture;
