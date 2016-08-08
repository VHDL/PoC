## =============================================================================================================================================================
## General Purpose I/O
## =============================================================================================================================================================
##
## Cursor Buttons
## -----------------------------------------------------------------------------
##	Bank:						34
##		VCCO:					1.5V (FPGA_1V5)
##	Location:				SW3, SW4, SW5, SW6, SW7
## -----------------------------------------------------------------------------
## {IN}		SW3; high-active; external 4k7 pulldown resistor; Bank 34; VCCO=FPGA_1V5
set_property PACKAGE_PIN	P6				[get_ports AC701_GPIO_Button_North]
## {IN}		SW7; high-active; external 4k7 pulldown resistor; Bank 34; VCCO=FPGA_1V5
set_property PACKAGE_PIN	R5				[get_ports AC701_GPIO_Button_West]
## {IN}		SW6; high-active; external 4k7 pulldown resistor; Bank 34; VCCO=FPGA_1V5
set_property PACKAGE_PIN	U6				[get_ports AC701_GPIO_Button_Center]
## {IN}		SW4; high-active; external 4k7 pulldown resistor; Bank 34; VCCO=FPGA_1V5
set_property PACKAGE_PIN	U5				[get_ports AC701_GPIO_Button_East]
## {IN}		SW5; high-active; external 4k7 pulldown resistor; Bank 34; VCCO=FPGA_1V5
set_property PACKAGE_PIN	T5				[get_ports AC701_GPIO_Button_South]
# set I/O standard
set_property IOSTANDARD		LVCMOS15	[get_ports -regexp {AC701_GPIO_Button_.*}]
# Ignore timings on async I/O pins
set_false_path								-from [get_ports -regexp {AC701_GPIO_Button_.*}]
