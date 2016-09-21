-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Package:				 	TODO
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;


package sata_TransceiverTypes is
	type T_SATA_TRANSCEIVER_REFCLOCK_SOURCE is (
		SATA_TRANSCEIVER_REFCLOCK_INTERNAL,
		SATA_TRANSCEIVER_REFCLOCK_GTREFCLK0,
		SATA_TRANSCEIVER_REFCLOCK_GTREFCLK1
	);

	function to_bv (source : T_SATA_TRANSCEIVER_REFCLOCK_SOURCE) return bit_vector;
	function to_slv(source : T_SATA_TRANSCEIVER_REFCLOCK_SOURCE) return std_logic_vector;

	type T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS is record
		RefClockIn_IBUFDS			: std_logic_vector(1 downto 0);
		RefClockIn_BUFG				: std_logic;
		DRP_Clock							: std_logic;
	end record;

	type T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS is record
		RX_n									: std_logic;
		RX_p									: std_logic;
	end record;

	type T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS is record
		TX_n									: std_logic;
		TX_p									: std_logic;
	end record;

	type T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS_VECTOR		is array(natural range <>) of T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
	type T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR		is array(natural range <>) of T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS;
	type T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR	is array(natural range <>) of T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS;

end;

package body sata_TransceiverTypes is
	function to_bv(source : T_SATA_TRANSCEIVER_REFCLOCK_SOURCE) return bit_vector is
	begin
		case source is
			when SATA_TRANSCEIVER_REFCLOCK_GTREFCLK0 => return "001";
			when SATA_TRANSCEIVER_REFCLOCK_GTREFCLK1 => return "010";
			when SATA_TRANSCEIVER_REFCLOCK_INTERNAL  => return "111";
		end case;
	end function;

	function to_slv(source : T_SATA_TRANSCEIVER_REFCLOCK_SOURCE) return std_logic_vector is
	begin
		return to_stdlogicvector(to_bv(source));
	end function;
end;
