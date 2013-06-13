--
-- Copyright (c) 2008
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Package: config
-- Authors: Martin Zabel   <martin.zabel@tu-dresden.de>
--          Thomas Preußer <thomas.preusser@tu-dresden.de>
--
-- Global project configuration.
--
-- This is a template file.
-- Copy file into your project compile directory and change setup appropiatly.
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2012-07-31 11:58:07 $
--
package config is

  -- FPGA / Chip vendor
  type vendor_t is (VENDOR_ALTERA, VENDOR_XILINX);


  -- Device
  type device_t is (
    DEVICE_SPARTAN3, DEVICE_SPARTAN3E,  -- Xilinx.Spartan
    DEVICE_SPARTAN6,
    DEVICE_VIRTEX5,  DEVICE_VIRTEX6,    -- Xilinx.Virtex
    
    DEVICE_CYCLONE1, DEVICE_CYCLONE2,   -- Altera.Cyclone
    DEVICE_STRATIX1, DEVICE_STRATIX2    -- Altera.Stratix
  );

  -- Change these lines to setup configuration.
  constant VENDOR : vendor_t := VENDOR_XILINX;
  constant DEVICE : device_t := DEVICE_VIRTEX5;
  
  -- Properties of FPGA architecture
  type archprops_t is
    record
      LUT_K : positive;  -- LUT Fanin
    end record;

  function ARCH_PROPS return archprops_t;
  
end config;

package body config is

  function ARCH_PROPS return archprops_t is
    variable res : archprops_t;
  begin
    res.LUT_K := 4;
    case DEVICE is
      when DEVICE_VIRTEX5|DEVICE_VIRTEX6|DEVICE_SPARTAN6 =>
        res.LUT_K := 6;
      when others =>
        null;
    end case;
    return  res;
  end ARCH_PROPS;

end config;
