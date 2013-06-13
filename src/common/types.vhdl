-- EMACS settings: -*-  tab-width:2  -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================================================================================================
-- Description:     Global type library.
--
-- Authors:         Thomas B. Preusser
--                  Martin Zabel
--                  Patrick Lehmann
-- ============================================================================================================================================================
-- Copyright 2007-2013 Technische Universität Dresden - Germany, Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--    http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================================================================================================

package types is

  -- FPGA / Chip vendor
	-- ==========================================================================================================================================================
  type vendor_t is (
	  VENDOR_ALTERA,
		VENDOR_XILINX--,
--		VENDOR_LATTICE
	);

  -- Device family
  -- ==========================================================================================================================================================
  type device_t is (
    DEVICE_SPARTAN3, DEVICE_SPARTAN3E, DEVICE_SPARTAN6,                   -- Xilinx.Spartan					-- FIXME: move Spartan3E to device_group_t?
    DEVICE_ZYNC7,                                                         -- Xilinx.Zync
		DEVICE_ARTIX7,                                                        -- Xilinx.Artix
    DEVICE_KINTEX7,                                                       -- Xilinx.Kintex
    DEVICE_VIRTEX5,  DEVICE_VIRTEX6, DEVICE_VIRTEX7,                      -- Xilinx.Virtex
    
    DEVICE_CYCLONE1, DEVICE_CYCLONE2,                                     -- Altera.Cyclone
    DEVICE_STRATIX1, DEVICE_STRATIX2, DEVICE_STRATIX4, DEVICE_STRATIX5    -- Altera.Stratix
  );

	-- Device group
	-- ==========================================================================================================================================================
	-- some devices have different hardmacros, e.g. Xilinx Gigabit-Transceivers (GTP, GTX, GTXE1, GTXE2, GTH, GTZ, ...)
	type devgrp_t is (
		-- Virtex5
		DEVGRP_V5LX,							-- Xilinx.Virtex5.LX
		DEVGRP_V5SXT,							-- Xilinx.Virtex5.SXT
		DEVGRP_V5LXT,							-- Xilinx.Virtex5.LXT
		DEVGRP_V5FXT,							-- Xilinx.Virtex5.FXT
		
		-- Virtex6
		DEVGRP_V6LX,							-- Xilinx.Virtex6.LX
		DEVGRP_V6SXT,							-- Xilinx.Virtex6.SXT
		DEVGRP_V6CXT,							-- Xilinx.Virtex6.CXT
		DEVGRP_V6LXT,							-- Xilinx.Virtex6.LXT
		DEVGRP_V6HXT,							-- Xilinx.Virtex6.HXT
		
		-- Virtex 7
    DEVGRP_V7XT,							-- Xilinx.Virtex7.XT
		
		-- Stratix2
		DEVGRP_S2,								-- Altera.Stratix2
		DEVGRP_S2GX,							-- Altera.Stratix2.GX
		
		-- Stratix4
		DEVGRP_S4GX,							-- Altera.Stratix4.GX
		
		-- Stratix5
		DEVGRP_S5GX								-- Altera.Stratix5.GX
	);
	
  -- Properties of FPGA architecture
  type archprops_t is
    record
      LUT_K : positive;  -- LUT Fanin
    end record;

	-- TODO: move to common/functions.vhdl?
  function ARCH_PROPS return archprops_t;
end types;

package body types is
  -- TODO: move to common/functions.vhdl?
  function ARCH_PROPS return archprops_t is
    variable res : archprops_t;
  begin
    res.LUT_K := 4;
    case DEVICE is
		  when DEVICE_SPARTAN6 =>                                res.LUT_K := 6;
      when DEVICE_ARTIX7 =>                                  res.LUT_K := 6;
			when DEVICE_KINTEX7 =>                                 res.LUT_K := 6;
      when DEVICE_VIRTEX5|DEVICE_VIRTEX6|DEVICE_VIRTEX7 =>   res.LUT_K := 6;
			when DEVICE_STRATIX4|DEVICE_STRATIX5 =>                res.LUT_K := 6;
      when others =>
        null;
    end case;
    return  res;
  end ARCH_PROPS;

end types;
