## I²C-MainBus
## =============================================================================
##	Bank:						13, 15
##		VCCO:					1,8V (VCC1V8_FPGA)
##	Location:				U52 (PCA9548ARGER)
##		Vendor:				Texas Instruments
##		Device:				PCA9548A-RGER - 8-Channel I²C Switch with Reset
##		I²C-Address:	0x74 (0111 010xb)
## -----------------------------------------------------------------------------
##	Devices:				8
##		Channel 0:		UserClock
##			Location:			U34
##			Vendor:
##			Device:				Si570
##			Address:			0xE0 (1110 000xb)
##		Channel 1:		FMC Connector 1
##			Location:
##		Channel 2:		FMC Connector 2
##			Location:
##		Channel 3:		EEPROM
##			Location:
##			Vendor:
##			Device:
##			Address:			0xA8 (1010 100xb)
##		Channel 4:		SFP
##			Location:			P3
##			Address:			0xA0 (1010 000xb)
##		Channel 5:		HDMI
##			Location:
##			Vendor:
##			Device:
##			Address:			0x72 (0111 001xb)
##		Channel 6:		DDR3
##			Location:
##			Address:			0xA0, 0x30 (1010 000xb, 0011 000xb)
##		Channel 7:		SI5324
##			Location:			U24 (SI5324C-C-GM)
##			Vendor:				Silicon Labs
##			Device:				SI5324 - Any-Frequency Precision Clock Multiplier/Jitter Attenuator
##			Address:			0xA0 (1010 000xb)
## U52 - Pin 19 - SerialClock
set_property PACKAGE_PIN		AT35			[get_ports VC707_IIC_SerialClock]
## U52 - Pin 20 - SerialData
set_property PACKAGE_PIN		AU32			[get_ports VC707_IIC_SerialData]
## U52 - Pin 24 - Reset (low-active); level shifted by U70 (TXS0108E)
set_property PACKAGE_PIN		AY42			[get_ports VC707_IIC_Switch_Reset_n]
# set I/O standard
set_property IOSTANDARD			LVCMOS18	[get_ports -regexp {VC707_IIC_.*}]

# Ignore timings on async I/O pins
set_false_path								-to			[get_ports -regexp {VC707_IIC_.*}]
set_false_path								-from		[get_ports -regexp {vC707_IIC_Serial.*}]
