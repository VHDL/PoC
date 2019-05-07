## Board:                   Hitech Global Z920 ZU19-PS
##      Device:             xczu19egffvc1760-2-e
##
## -----------------------------------------------------------------------------
## -- I2C Bus --
## -----------------------------------------------------------------------------
##  Bank:                   94
##      VCCO:               +3.3V (3.3V)
##  Location:               U53
##      Vendor:             Texas Instruments
##      Device:             PCA9548APW
##      Characteristics:    8-Channel I2C-Bus Switch
##      I2C-Address:        ___
## -----------------------------------------------------------------------------
##  Devices:                6 (out of 8)
##      Channel 00:          ZRAY I2C
##          Location:           Connector J6
##      Channel 01:         Programmable Clock Generator (User Clock)
##          Location:           U46
##          Vendor:             Silicon Labs
##          Device:             SI5341A-A-GM
##          Characteristics:    Clock Generator, 100Hz-712.5MHz, 10 Outputs
##          Address:           _____
##      Channel 02:          N/C
##          Location:           N/A
##      Channel 03:          Programmable Clock Oscillator (DRAM CLK OSC)
##          Location:           U10
##          Vendor:             Texas Instruments
##          Device:             LMK61E2
##          Characteristics:    Clock Oscillator, LVDS 200MHz
##          Address:            _____
##      Channel 04:          N/C
##          Location:           N/A
##      Channel 05:          DDR4 SODIMM I2C
##          Location:           Connector J6
##      Channel 06:         Zynq UltraScale+ MPSoC MIO16_I2C1 
##          Location:           U6 Bank 500
##          Vendor:             Xilinx
##          Device:             XCZU19EG-FFVC1760
##          Characteristics:    FPGA
##          Address:            _____
##      Channel 07:          FMC I2C
##          Location:           Connector J8

## { OUT }  U53 - Pin 22 - I2C_SCL_PL - wired together with MIO14_I2C0_SCL(level shifter inbetween)
set_property PACKAGE_PIN    C3              [ get_ports HTG_Z920_IIC_SerialClock ]
## {INOUT}  U53 - Pin 23 - I2C_SDA_PL - wired together with MIO15_I2C0_SDA(level shifter inbetween)
set_property PACKAGE_PIN    B3              [ get_ports HTG_Z920_IIC_SerialData ]
## { OUT }  U53 - Pin  2 - I2C_RST_N_PL
set_property PACKAGE_PIN    C4              [ get_ports HTG_Z920_IIC_Switch_Reset_n ]


## set I/O standard
set_property IOSTANDARD     LVCMOS33        [ get_ports -regexp {HTG_Z920_IIC_.*} ]
set_false_path              -to             [ get_ports -regexp {HTG_Z920_IIC_.*} ]
set_false_path              -from           [ get_ports -regexp {HTG_Z920_IIC_SerialData} ]
