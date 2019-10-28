-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Stefan Unrein
--									Max Kraft-Kugler
--									Patrick Lehmann
--									Asif Iqbal
--
-- Package:					PoC.io.led
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
use     IEEE.std_logic_1164.all;


package led is
	type T_IO_LED_COLORED_RGB is record
		R : std_logic;
		G : std_logic;
		B : std_logic;
	end record;
	type T_IO_LED_COLORED_RGB_VECTOR is array(natural range <>) of T_IO_LED_COLORED_RGB;
	
	type T_IO_LED_COLORED_RGBW is record
		R : std_logic;
		G : std_logic;
		B : std_logic;
		W : std_logic;
	end record;
	type T_IO_LED_COLORED_RGBW_VECTOR is array(natural range <>) of T_IO_LED_COLORED_RGBW;
	
	type T_IO_LED_COLORED_RGBWW is record
		R : std_logic;
		G : std_logic;
		B : std_logic;
		WW : std_logic; --Warm White
		CW : std_logic; --Cold White
	end record;
	type T_IO_LED_COLORED_RGBWW_VECTOR is array(natural range <>) of T_IO_LED_COLORED_RGBWW;
end package;
