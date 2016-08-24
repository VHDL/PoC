## =============================================================================================================================================================
## Xilinx User Constraint File (UCF)
## =============================================================================================================================================================
##	Board:					Xilinx - Artix-7 AC701
##	FPGA:						Xilinx Artix-7
##		Device:				XC7A200T
##		Package:			FBG676
##		Speedgrade:		-2
##
##	Notes:
##		AC701: VCCO_VADJ is defaulted to 2.5V (choices: 1.8V, 2.5V, 3.3V)
##
## =============================================================================================================================================================
## Clock Sources
## =============================================================================================================================================================
##
## User Clock
## -----------------------------------------------------------------------------
##		Bank:						14
##			VCCO:					3.3V (FPGA_3V3)
##		Location:				U34 (SI570)
##			Vendor:				Silicon Labs
##			Device:				SI570BAB0000544DG
##			Frequency:		10 - 810 MHz, 50ppm
##			Default Freq:	156.250 MHz
##			I²C-Address:	0x5D #$ (0111 010xb)
set_property PACKAGE_PIN	M21			[get_ports AC701_ProgUserClock_p]
set_property PACKAGE_PIN	M22			[get_ports AC701_ProgUserClock_n]
# set I/O standard
set_property IOSTANDARD		LVDS_25	[get_ports -regexp {AC701_ProgUserClock_[p|n]}]
