-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:
--                  Iqbal Asif (PLC2 Design GmbH)
--                  Patrick Lehmann (PLC2 Design GmbH)
--
-- Entity:          AXI4Lite_Register_TestController
--
-- Description:
-- -------------------------------------
-- Testhcontroller of OSVVM Testbench of entity AXI4Lite_Register
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

library PoC;
use PoC.utils.all;
use PoC.vectors.all;
use PoC.axi4lite.all;

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library OSVVM_AXI4;
context OSVVM_AXI4.Axi4LiteContext;

entity AXI4Lite_Register_TestController is
	generic (
		CONFIG : T_AXI4_Register_Vector
	);
	port (
		-- Global Signal Interface
		Clock : in std_logic;
		Reset : in std_logic;

		Irq : in std_logic;

		ReadPort  : in T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0);
		WritePort : out T_SLVV(0 to CONFIG'Length - 1)(DATA_BITS - 1 downto 0) := (others => (others => '0'));

		-- Transaction Interfaces
		AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType
	);
	constant AXI_ADDR_WIDTH : integer := AxiMasterTransRec.Address'length;
	constant AXI_DATA_WIDTH : integer := AxiMasterTransRec.DataToModel'length;

	-- Not currently used in the Axi4Lite model - future use for Axi4Lite Burst Emulation modes
	--  alias WriteBurstFifo is <<variable .TbAxi4.Master_1.WriteBurstFifo : osvvm.ScoreboardPkg_slv.ScoreboardPType>> ;
	--  alias ReadBurstFifo  is <<variable .TbAxi4.Master_1.ReadBurstFifo  : osvvm.ScoreboardPkg_slv.ScoreboardPType>> ;
end entity;
