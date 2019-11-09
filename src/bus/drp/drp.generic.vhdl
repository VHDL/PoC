-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Stefan Unrein
--
-- Entity:				 	Generic Dynamic Reconfiguration Port(DRP) bus description
--
-- Description:
-- -------------------------------------
-- This package implements a generic Dynamic Reconfiguration Port(DRP) description.
--
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
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

use work.DRP.all;


package DRP_Sized is
	generic (
		ADDRESS_BITS  : natural;
		DATA_BITS     : natural
	);
	
	
	subtype SIZED_S2M is T_DRP_Bus_S2M(
		DataOut(DATA_BITS -1 downto 0)
	);

	subtype SIZED_M2S is T_DRP_Bus_M2S(
		Address(ADDRESS_BITS -1 downto 0),
		DataIn(DATA_BITS -1 downto 0)
	);
	
	subtype SIZED_M2S_VECTOR is T_DRP_Bus_M2S_VECTOR(open)(
		Address(ADDRESS_BITS -1 downto 0),
		DataIn(DATA_BITS -1 downto 0)
	);
	
	subtype SIZED_S2M_VECTOR is T_DRP_Bus_S2M_VECTOR(open)(
		DataOut(DATA_BITS -1 downto 0)
	);

end package;
