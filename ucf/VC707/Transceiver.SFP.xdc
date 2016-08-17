## Transceiver - SFP interface
## =============================================================================
##	Bank:						13, 15
##		VCCO:					1,8V (VCC1V8_FPGA)
##	Location:				P3
##		I2C-Address:	0xA0 (1010 000xb)
## ; low-active; external 4k7 pullup resistor; level shifted by Q4 (NDS331N)
set_property PACKAGE_PIN		AP33			[get_ports VC707_SFP_TX_Disable_n]
## ; high-active; external 4k7 pullup resistor; level shifted by U69 (SN74AVC1T45)
set_property PACKAGE_PIN		BB38			[get_ports VC707_SFP_LossOfSignal]
# set I/O standard
set_property IOSTANDARD			LVCMOS18	[get_ports VC707_SFP_TX_Disable_n]
set_property IOSTANDARD			LVCMOS18	[get_ports VC707_SFP_LossOfSignal]

## SGMII LVDS signal-pairs
## --------------------------
##	Bank:						113
##	ReferenceClock
##		Location:			P3
## {OUT}
set_property PACKAGE_PIN		AM4				[get_ports VC707_SFP_TX_p]
## {OUT}
set_property PACKAGE_PIN		AM3				[get_ports VC707_SFP_TX_n]
## {IN}
set_property PACKAGE_PIN		AL6				[get_ports VC707_SFP_RX_p]
## {IN}
set_property PACKAGE_PIN		AL5				[get_ports VC707_SFP_RX_n]

# Ignore timings on async I/O pins
set_false_path								-to			[get_ports VC707_SFP_TX_Disable_n]
set_false_path								-from		[get_ports VC707_SFP_LossOfSignal]
