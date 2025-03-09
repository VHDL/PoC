-- =============================================================================
-- Authors:
--   Jonas Schreiner
--
-- License:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;

library osvvm;
context osvvm.OsvvmContext;

library tb_common;
use     tb_common.OsvvmTestCommonPkg.OSVVM_RESULTS_DIR;


entity arith_prng_TestController is
	port (
		Clock : in  std_logic;
		Reset : in  std_logic;
		Got   : out std_logic := '0';
		Value : in  std_logic_vector
	);
end entity;
