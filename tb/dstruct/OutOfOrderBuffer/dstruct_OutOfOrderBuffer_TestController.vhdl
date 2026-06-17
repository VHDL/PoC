-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Iqbal Asif
--
-- Entity:          TestController for a dstruct_OutOfOrderBuffer
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE ;
use     IEEE.std_logic_1164.all ;
use     IEEE.numeric_std.all ;
use     IEEE.numeric_std_unsigned.all ;
use     IEEE.math_real.all ;

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;

library OSVVM ;
context OSVVM.OsvvmContext ;
use     OSVVM.ScoreboardPkg_slv.all ;


entity dstruct_OutOfOrderBuffer_TestController is
	generic(
		NUM_INDEX : positive;
		DATA_BITS : positive
	);
	port (
			-- Global Signal Interface
		Clock  : in  std_logic;
		nReset : in  std_logic ;

		-- Put Port
		Put      : out std_logic;
		Full    : in  std_logic;
		DataIn   : out std_logic_vector(DATA_BITS-1 downto 0);
		IndexOut : in  unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);

		-- Get Port
		Got      : out std_logic;
		Valid    : in  std_logic;
		IndexIn  : out unsigned(log2ceilnz(NUM_INDEX) -1 downto 0);
		DataOut  : in  std_logic_vector(DATA_BITS-1 downto 0)
	);

end entity;

