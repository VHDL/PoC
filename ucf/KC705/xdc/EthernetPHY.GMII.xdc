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
##		Translated from ucf File
##		########################
##
## single-ended, parallel TX path					
## {OUT}		U37.16
set_property PACKAGE_PIN		M27				[get_ports KC705_EthernetPHY_TX_Valid]
## {OUT}		U37.13
set_property PACKAGE_PIN		N29				[get_ports KC705_EthernetPHY_TX_Error]
## {OUT}		U37.18
set_property PACKAGE_PIN		N27				[get_ports KC705_EthernetPHY_TX_DATA<0>]
## {OUT}		U37.19
set_property PACKAGE_PIN		N25				[get_ports KC705_EthernetPHY_TX_DATA<1>]
## {OUT}		U37.20
set_property PACKAGE_PIN		M29				[get_ports KC705_EthernetPHY_TX_DATA<2>]
## {OUT}		U37.24
set_property PACKAGE_PIN		L28				[get_ports KC705_EthernetPHY_TX_DATA<3>]
## {OUT}		U37.25
set_property PACKAGE_PIN		J26				[get_ports KC705_EthernetPHY_TX_DATA<4>]
## {OUT}		U37.26
set_property PACKAGE_PIN		K26				[get_ports KC705_EthernetPHY_TX_DATA<5>]
## {OUT}		U37.28
set_property PACKAGE_PIN		L30				[get_ports KC705_EthernetPHY_TX_DATA<6>]
## {OUT}		U37.29
set_property PACKAGE_PIN		J28				[get_ports KC705_EthernetPHY_TX_DATA<7>]

set_property IOSTANDARD		LVCMOS25	[get_ports -regexp {KC705_EthernetPHY_TX_.*}]
set_property SLEW					FAST			[get_ports -regexp {KC705_EthernetPHY_TX_.*}]

##
## single-ended, parallel RX path
## {IN}			U37.4
set_property PACKAGE_PIN		R28				[get_ports KC705_EthernetPHY_RX_Valid]
## {IN}			U37.8
set_property PACKAGE_PIN		V26				[get_ports KC705_EthernetPHY_RX_Error]
## {IN}			U37.3
set_property PACKAGE_PIN		U30				[get_ports KC705_EthernetPHY_RX_DATA<0>]
## {IN}			U37.128
set_property PACKAGE_PIN		U25				[get_ports KC705_EthernetPHY_RX_DATA<1>]
## {IN}			U37.126
set_property PACKAGE_PIN		T25				[get_ports KC705_EthernetPHY_RX_DATA<2>]
## {IN}			U37.125
set_property PACKAGE_PIN		U28				[get_ports KC705_EthernetPHY_RX_DATA<3>]
## {IN}			U37.124
set_property PACKAGE_PIN		R19				[get_ports KC705_EthernetPHY_RX_DATA<4>]
## {IN}			U37.123
set_property PACKAGE_PIN		T27				[get_ports KC705_EthernetPHY_RX_DATA<5>]
## {IN}			U37.121
set_property PACKAGE_PIN		T26				[get_ports KC705_EthernetPHY_RX_DATA<6>]
## {IN}			U37.120
set_property PACKAGE_PIN		T28				[get_ports KC705_EthernetPHY_RX_DATA<7>]

set_property IOSTANDARD		LVCMOS25	[get_ports -regexp {KC705_EthernetPHY_RX_.*}]
set_property SLEW					FAST			[get_ports -regexp {KC705_EthernetPHY_RX_.*}]
##
########In ucf format
#### Timing names
##NET "KC705_EthernetPHY_RX_Clock"								TNM_NET = "TGRP_EthernetPHY_RX_Clock";
##NET "KC705_EthernetPHY_RX_Data[?]"							TNM			= "EthernetPHY_RX";
##NET "KC705_EthernetPHY_RX_Valid"								TNM			= "EthernetPHY_RX";
##NET "KC705_EthernetPHY_RX_Error"								TNM			= "EthernetPHY_RX";
####
#### RX clock frequency
##TIMESPEC "TS_EthernetPHY_RX_Clock" = PERIOD "TGRP_EthernetPHY_RX_Clock" 125 MHz HIGH 50%;
####
#### according to IEEE 802.3 clause 35.4.2.3:
####		t_SETUP(RCVR) = 2.0 ns
####		t_HOLD(RCVR)	= 0.0 ns
##TIMEGRP "EthernetPHY_RX" OFFSET = IN 2.0 VALID 2.0 ns BEFORE "KC705_EthernetPHY_RX_Clock" RISING;
####TIMEGRP "EthernetPHY_RX" OFFSET = IN 2.7 VALID 3.2 ns BEFORE "KC705_EthernetPHY_RX_Clock" RISING;		-- from CoreGen Wizard
