## =============================================================================================================================================================
## Xilinx Design Constraint File (XDC)
## =============================================================================================================================================================
## Board:         Digilent - ArtyZ7
## FPGA:          Xilinx Zynq 7000
## =============================================================================================================================================================
## General Purpose I/O 
## =============================================================================================================================================================
## Ethernet PHY
## =============================================================================================================================================================
## -----------------------------------------------------------------------------
##	Bank:						500,501
##	VCCO:						3.3V,1.8V (VCC3V3,VCC1V8)
##	Location:					J8 
## -----------------------------------------------------------------------------

## common signals and management
## -------------------------------------
## {OUT}    
set_property PACKAGE_PIN  B5        [ get_ports ArtyZ7_EthernetPHY_Reset_n ]			
## {IN}    
set_property PACKAGE_PIN  E9        [ get_ports ArtyA7_EthernetPHY_Interrupt_n ]		
## {OUT}  
set_property PACKAGE_PIN  C10       [ get_ports ArtyZ7_EthernetPHY_Management_Clock ]				
## {INOUT}  
set_property PACKAGE_PIN  C11       [ get_ports ArtyZ7_EthernetPHY_Management_Data ]	
# set I/O standard
set_property IOSTANDARD   LVCMOS33  [ get_ports -regexp {ArtyZ7_EthernetPHY_.*} ]
## Ignore timings on async I/O pins
set_false_path                -to   [ get_ports ArtyZ7_EthernetPHY_Reset_n ]
set_false_path                -from [ get_ports ArtyZ7_EthernetPHY_Interrupt_n ]
set_false_path                -to   [ get_ports ArtyZ7_EthernetPHY_Management_Clock ]
set_false_path                -to   [ get_ports ArtyZ7_EthernetPHY_Management_Data ]
set_false_path                -from [ get_ports ArtyZ7_EthernetPHY_Management_Data ]
