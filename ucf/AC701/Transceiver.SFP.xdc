##
## Transceiver - SFP interface
## -----------------------------------------------------------------------------
##	Bank:						12, 15, 213
##		VCCO:					2.5V, 2.5V (VADJ_FPGA, VADJ_FPGA)
##		Quad117:		 
##			RefClock0		from U3 (SY89544UMG)
##			RefClock1		from U4 (SY89544UMG)
##		Placement:
##			SFP:				Quad213.Channel0 (GTPE2_CHANNEL_X0Y0)
##		Location:			P3
#$	##		I²C-Address:	0xA0 (1010 000xb)
## -----------------------------------------------------------------------------
set_property PACKAGE_PIN		R18				[get_ports AC701_SFP_TX_Disable]
set_property PACKAGE_PIN		R23				[get_ports AC701_SFP_LossOfSignal]
# set I/O standard
set_property IOSTANDARD			LVCMOS33	[get_ports AC701_SFP_TX_Disable]
set_property IOSTANDARD			LVCMOS33	[get_ports AC701_SFP_LossOfSignal]
##
## --------------------------
## SFP+ LVDS signal-pairs
## {OUT}	
set_property PACKAGE_PIN		AC10			[get_ports AC701_SFP_TX_p]
## {OUT}	
set_property PACKAGE_PIN		AD10			[get_ports AC701_SFP_TX_n]
## {IN}		
set_property PACKAGE_PIN		AC12			[get_ports AC701_SFP_RX_p]
## {IN}		
set_property PACKAGE_PIN		AD12			[get_ports AC701_SFP_RX_n]

# Ignore timings on async I/O pins
set_false_path								-to		[get_ports AC701_SFP_TX_Disable]
set_false_path								-from	[get_ports AC701_SFP_LossOfSignal]


