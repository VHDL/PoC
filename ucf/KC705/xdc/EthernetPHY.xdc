##
## Ethernet PHY - Marvell Alaska Ultra
## -----------------------------------------------------------------------------
##	Bank:						14, 15, 117
##		VCCO:					2.5V, 2.5V (VCC2V5_FPGA, VCC2V5_FPGA)
##	Location:				U37
##		Vendor:				Marvell
##		Device:				M88E1111 - BAB1C000
##		MDIO-Address:	0x05 (---0 0111b)
##		I²C-Address:	I²C management mode is not enabled
##
##
##		Translated from ucf File
##		########################
##
## common signals and management
## --------------------------
## {IN}			U37.36
set_property PACKAGE_PIN		L20				[get_ports KC705_EthernetPHY_Reset_n]
## {IN}			U37.32
set_property PACKAGE_PIN		N30				[get_ports KC705_EthernetPHY_Interrupt_n]
## {OUT}		U37.35
set_property PACKAGE_PIN		R23				[get_ports KC705_EthernetPHY_Management_Clock]
## {INOUT}	U37.33
set_property PACKAGE_PIN		J21				[get_ports KC705_EthernetPHY_Management_Data]

# set I/O standard
set_property IOSTANDARD		LVCMOS25		[get_ports KC705_EthernetPHY_Reset_n]
set_property IOSTANDARD		LVCMOS25		[get_ports KC705_EthernetPHY_Interrupt_n]
set_property IOSTANDARD		LVCMOS25		[get_ports KC705_EthernetPHY_Management_Clock]
set_property IOSTANDARD		LVCMOS25		[get_ports KC705_EthernetPHY_Management_Data]


## Ignore timings on async I/O pins
##set_false_path								-from	[get_ports KC705_EthernetPHY_Reset_n]
##set_false_path								-to		[get_ports KC705_EthernetPHY_Management_Clock]
##set_false_path								-from	[get_ports KC705_EthernetPHY_Interrupt_n]
##set_false_path								-to		[get_ports KC705_EthernetPHY_Management_Data]
##set_false_path								-from	[get_ports KC705_EthernetPHY_Management_Data]
