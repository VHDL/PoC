-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:				 	Patrick Lehmann
--                  Stefan Unrein
--
-- Entity:				 	A generic AXI4-Stream module to pause a stream.
--
-- Description:
-- -------------------------------------
-- .. TODO:: No documentation available.
--
-- License:
-- =============================================================================
-- Copyright 2018-2019 PLC2 Design GmbH, Germany
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair of VLSI-Design, Diagnostics and Architecture
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
use     IEEE.numeric_std.all;

use     work.utils.all;
use     work.vectors.all;
use     work.axi4stream.all;


entity AXI4Stream_Pause is
	port (
		Pause               : in  std_logic;
		-- IN Port
		In_M2S              : in  T_AXI4STREAM_M2S;
		In_S2M              : out T_AXI4STREAM_S2M;
		-- OUT Ports
		Out_M2S             : out T_AXI4STREAM_M2S;
		Out_S2M             : in  T_AXI4STREAM_S2M
	);
end entity;


architecture rtl of AXI4Stream_Pause is
begin
  Out_M2S.Valid <= In_M2S.Valid and not Pause;
  Out_M2S.Data  <= In_M2S.Data;
  Out_M2S.Last  <= In_M2S.Last;
  Out_M2S.User  <= In_M2S.User;
  
  In_S2M.Ready  <= Out_S2M.Ready and not Pause;

end architecture;
