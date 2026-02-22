-- =============================================================================
-- Authors:
--   Stefan Unrein
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

library IEEE ;
use     IEEE.std_logic_1164.all ;
use     IEEE.numeric_std.all ;

library std;
use     std.env.all;

library PoC;
use     PoC.stream.all;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.physical.all;
use     PoC.net.all;

library OSVVM ; 
context OSVVM.OsvvmContext ;

-- use     OSVVM.ScoreBoardPkg_slv.all;

library osvvm_uart ; 
context osvvm_uart.UartContext ; 

library osvvm_Axi4 ;
context osvvm_Axi4.Axi4LiteContext ; 

-- use work.OsvvmTestCommonPkg.all ;
-- use work.AlertLogPkg.all;
-- use work.UartTbPkg.all ;


entity axi4lite_UART_tc is
	port (
		--Global signal Interface
        -- Clock : in std_logic;		
		Reset               : in std_logic;
		
		-- axi transaction record
		AXI_Manager         : inout AddressBusRecType ;
		
		-- tx transaction record
		UartTxRec           : inout UartRecType ;
		
		-- rx  transaction record
        UartRxRec           : inout UartRecType 
	);
	
	 constant AXI_ADDR_WIDTH : integer := AXi_Manager.Address'length ; 
     constant AXI_DATA_WIDTH : integer := AXi_Manager.DataToModel'length ;
	 
	 subtype AXIAddressType is std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
 	 subtype AXIDataType    is std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

end entity;
