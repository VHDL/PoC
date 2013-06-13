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
-- Author(s): Martin Zabel
--
-- Global project configuration.
--
package config is

  -- FPGA / Chip vendor
  type vendor_t is (VENDOR_ALTERA, VENDOR_XILINX);


  -- Device.
  type device_t is (
    DEVICE_SPARTAN3, DEVICE_SPARTAN3E,
    DEVICE_VIRTEX5,
    DEVICE_CYCLONE1, DEVICE_CYCLONE2,
    DEVICE_STRATIX1, DEVICE_STRATIX2);

  -- Change these lines to setup configuration.
  constant VENDOR : vendor_t := VENDOR_XILINX;
  constant DEVICE : device_t := DEVICE_VIRTEX5;
  
end config;
