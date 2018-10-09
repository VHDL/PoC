## =============================================================================================================================================================
## Xilinx Design Constraint File (XDC)
## =============================================================================================================================================================
## Board:         Digilent - Arty
## FPGA:          Xilinx Artix 7
## =============================================================================================================================================================
## General Purpose I/O 
## =============================================================================================================================================================
## Ethernet PHY
## =============================================================================================================================================================
## -----------------------------------------------------------------------------
##	Bank:						15
##	VCCO:						3.3V (VCC3V3)
##	Location:					J9 
## -----------------------------------------------------------------------------

## common signals and management
## -------------------------------------
## {OUT}
set_property PACKAGE_PIN  C16       [ get_ports ArtyA7_EthernetPHY_Reset_n ]
## {OUT}
set_property PACKAGE_PIN  G18       [ get_ports ArtyA7_EthernetPHY_ReferenceClock ]
## {OUT}
set_property PACKAGE_PIN  F16       [ get_ports ArtyA7_EthernetPHY_Management_Clock ]
## {INOUT}
set_property PACKAGE_PIN  K13       [ get_ports ArtyA7_EthernetPHY_Management_Data ]
## {IN}
set_property PACKAGE_PIN  G14       [ get_ports ArtyA7_EthernetPHY_CRS ]
## {IN}
set_property PACKAGE_PIN  D17       [ get_ports ArtyA7_EthernetPHY_COL ]

# set I/O standard
set_property IOSTANDARD   LVCMOS33  [ get_ports -regexp {ArtyA7_EthernetPHY_.*} ]
## Ignore timings on async I/O pins
set_false_path                  -to [ get_ports ArtyA7_EthernetPHY_Reset_n ]
set_false_path                  -to [ get_ports ArtyA7_EthernetPHY_Management_Clock ]
set_false_path                  -to [ get_ports ArtyA7_EthernetPHY_Management_Data ]
set_false_path                -from [ get_ports ArtyA7_EthernetPHY_Management_Data ]
set_false_path                -from [ get_ports ArtyA7_EthernetPHY_CRS ]
set_false_path                -from [ get_ports ArtyA7_EthernetPHY_COL ]