-- =============================================================================
-- Authors:
-- Iqbal Asif (PLC2 Design GmbH)
-- Patrick Lehmann (PLC2 Design GmbH)
--
-- License:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE ;
use     IEEE.std_logic_1164.all ;
use     IEEE.numeric_std.all ;
use     IEEE.numeric_std_unsigned.all ;

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.axi4lite.all;

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library OSVVM_AXI4 ;
context OSVVM_AXI4.Axi4LiteContext;

use     work.AXI4Lite_Register_pkg.all;


entity AXI4Lite_Register_TestController is
	generic (
		CONF : T_AXI4_Register_Vector
	);
	port (
		-- Global Signal Interface
		Clk    : in    std_logic ;
		nReset : out   std_logic ;

		Irq : in    std_logic;

		ReadPort  : in   T_SLVV(0 to CONF'Length - 1)(DATA_BITS-1 downto 0);
		WritePort : out  T_SLVV(0 to CONF'Length - 1)(DATA_BITS-1 downto 0):= (others => (others => '0'));

		-- Transaction Interfaces
		AxiMasterTransRec         : inout Axi4LiteMasterTransactionRecType
	) ;
	constant AXI_ADDR_WIDTH : integer := AxiMasterTransRec.Address'length ;
	constant AXI_DATA_WIDTH : integer := AxiMasterTransRec.DataToModel'length ;

-- Not currently used in the Axi4Lite model - future use for Axi4Lite Burst Emulation modes
--  alias WriteBurstFifo is <<variable .TbAxi4.Master_1.WriteBurstFifo : osvvm.ScoreboardPkg_slv.ScoreboardPType>> ;
--  alias ReadBurstFifo  is <<variable .TbAxi4.Master_1.ReadBurstFifo  : osvvm.ScoreboardPkg_slv.ScoreboardPType>> ;
end entity;
