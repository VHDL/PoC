## =============================================================================================================================================================
## General Purpose I/O
## =============================================================================================================================================================
##
## DIP-Switches
## -----------------------------------------------------------------------------
##	Bank:						34
##		VCCO:					1.5V (FPGA_1V5)
##	Location:				SW2
## -----------------------------------------------------------------------------
## {IN}		SW2.4; high-active; external 4k7 pulldown resistor
set_property PACKAGE_PIN	R8				[get_ports AC701_GPIO_Switches[0]]
## {IN}		SW2.3; high-active; external 4k7 pulldown resistor
set_property PACKAGE_PIN	P8				[get_ports AC701_GPIO_Switches[1]]
## {IN}		SW2.2; high-active; external 4k7 pulldown resistor
set_property PACKAGE_PIN	R7				[get_ports AC701_GPIO_Switches[2]]
## {IN}		SW2.1; high-active; external 4k7 pulldown resistor
set_property PACKAGE_PIN	R6				[get_ports AC701_GPIO_Switches[3]]
# set I/O standard
set_property IOSTANDARD		LVCMOS15	[get_ports -regexp {AC701_GPIO_Switches\[\d\]}]
# Ignore timings on async I/O pins
set_false_path								-from [get_ports -regexp {AC701_GPIO_Switches\[\d\]}]
