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
## SGMII LVDS signal-pairs
## --------------------------
##	Bank:						117
##		Quad117:
##			RefClock0		SGMII RefClock (ICS844021I)
##			RefClock1		KC705_SMA_RefClock
##		Placement:
##			Lane:				Quad117.Channel1 (GTXE2_CHANNEL_X0Y9)
##	ReferenceClock:
##		RefClock:			Quad117.MGTRefClock0
##		Location:			U2 (ICS844021I)
##		Vendor:				Integrated Circuit Systems
#$	##		Device:				ICS844021AGI-01LF
##		Frequency:		125 MHz
##
## reference clocks
## --------------------------												
## {IN}			U2.6
set_property PACKAGE_PIN		G7				[get_ports KC705_EthernetPHY_RefClock_125MHz_n]
## {IN}			U2.7
set_property PACKAGE_PIN		G8				[get_ports KC705_EthernetPHY_RefClock_125MHz_p]
## {OUT}		U37.A4
set_property PACKAGE_PIN		J3				[get_ports KC705_EthernetPHY_SGMII_TX_n]
## {OUT}		U37.A3
set_property PACKAGE_PIN		J4				[get_ports KC705_EthernetPHY_SGMII_TX_p]
## {IN}			U37.A8
set_property PACKAGE_PIN		H5				[get_ports KC705_EthernetPHY_SGMII_RX_n]
## {IN}			U37.A7
set_property PACKAGE_PIN		H6				[get_ports KC705_EthernetPHY_SGMII_RX_p]
