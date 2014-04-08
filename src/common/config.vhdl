-- EMACS settings: -*-  tab-width:2  -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- ============================================================================================================================================================
-- Description:     Global configuration settings.
--                  This file evaluates the settings declared in the project specific package my_config.
--                  See also template file my_config.vhdl.template.
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
library PoC;
use			PoC.types.ALL;
use     PoC.my_config.all;

package config is
  -- FPGA / Chip vendor
	-- ===========================================================================
  type vendor_t is (
	  VENDOR_ALTERA,
		VENDOR_XILINX
--		VENDOR_LATTICE
	);

  -- Device family
  -- ===========================================================================
  type device_t is (
    DEVICE_SPARTAN3, DEVICE_SPARTAN6,                                     -- Xilinx.Spartan
    DEVICE_ZYNQ7,                                                         -- Xilinx.Zynq
		DEVICE_ARTIX7,                                                        -- Xilinx.Artix
    DEVICE_KINTEX7,                                                       -- Xilinx.Kintex
    DEVICE_VIRTEX5,  DEVICE_VIRTEX6, DEVICE_VIRTEX7,                      -- Xilinx.Virtex
    
    DEVICE_CYCLONE1, DEVICE_CYCLONE2, DEVICE_CYCLONE3,                    -- Altera.Cyclone
    DEVICE_STRATIX1, DEVICE_STRATIX2, DEVICE_STRATIX4, DEVICE_STRATIX5    -- Altera.Stratix
  );

  -- Properties of FPGA architecture
  -- ===========================================================================
  type archprops_t is
    record
      LUT_K : positive;  -- LUT Fanin
      -- INFO: include transceiver type and the like here
    end record;

	-- Functions extracting device and architecture properties from "MY_DEVICE"
  -- which is declared in package "my_config".
  -- ===========================================================================
  function VENDOR     return vendor_t;
  function DEVICE     return device_t;
  function ARCH_PROPS return archprops_t;
 
end config;

package body config is

  -- purpose: extract vendor from MY_DEVICE
  function VENDOR return vendor_t is
  begin  -- VENDOR
    case MY_DEVICE(1 to 2) is
      when "XC"   => return VENDOR_XILINX;
      when "EP"   => return VENDOR_ALTERA;
      when others => report "Unknown vendor in MY_DEVICE = " & MY_DEVICE & "." severity failure;
                         -- return statement is explicitly missing otherwise XST won't stop
    end case;
  end VENDOR;

  -- purpose: extract device from MY_DEVICE
  function DEVICE return device_t is
  begin  -- DEVICE
    case VENDOR is
      when VENDOR_ALTERA =>
        case MY_DEVICE(3 to 4) is
          when "1C"   => return DEVICE_CYCLONE1;
          when "2C"   => return DEVICE_CYCLONE2;
          when "3C"   => return DEVICE_CYCLONE3;
          when "1S"   => return DEVICE_STRATIX1;
          when "2S"   => return DEVICE_STRATIX2;
          when "4S"   => return DEVICE_STRATIX4;
          when "5S"   => return DEVICE_STRATIX5;
          when others => report "Unknown Altera device in MY_DEVICE = " & MY_DEVICE & "." severity failure;
                         -- return statement is explicitly missing otherwise XST won't stop
        end case;

      when VENDOR_XILINX =>
        case MY_DEVICE(3 to 4) is
          when "7A"   => return DEVICE_ARTIX7;
          when "7K"   => return DEVICE_KINTEX7;
          when "3S"   => return DEVICE_SPARTAN3;
          when "6S"   => return DEVICE_SPARTAN6;
          when "5V"   => return DEVICE_VIRTEX5;
          when "6V"   => return DEVICE_VIRTEX6;
          when "7V"   => return DEVICE_VIRTEX7;
          when "7Z"   => return DEVICE_ZYNQ7;
          when others => report "Unknown Xilinx device in MY_DEVICE = " & MY_DEVICE & "." severity failure;
                         -- return statement is explicitly missing otherwise XST won't stop
        end case;
    end case;
    
  end DEVICE;

  -- purpose: extract architecture properties from DEVICE
  function ARCH_PROPS return archprops_t is
    variable res : archprops_t;
    constant dev : device_t := DEVICE;
  begin
    res.LUT_K := 4;
    case dev is
		  when DEVICE_SPARTAN6 =>                                res.LUT_K := 6;
      when DEVICE_ARTIX7 =>                                  res.LUT_K := 6;
			when DEVICE_KINTEX7 =>                                 res.LUT_K := 6;
      when DEVICE_VIRTEX5|DEVICE_VIRTEX6|DEVICE_VIRTEX7 =>   res.LUT_K := 6;
			when DEVICE_ZYNQ7 =>                                   res.LUT_K := 6;
			when DEVICE_STRATIX4|DEVICE_STRATIX5 =>                res.LUT_K := 6;
      when others =>
        null;
    end case;
    return  res;
  end ARCH_PROPS;

end config;
