##
## SPI-Bus
## -----------------------------------------------------------------------------
##	Bank:						35
##		VCCO:					3.3V (VCC3V3)
##	Location:				J6 (2x3 header)
## -----------------------------------------------------------------------------
## {OUT}	SerialClock
set_property PACKAGE_PIN  F1        [ get_ports ArtyA7_SPI_SerialClock ]
## {OUT}	SlaveSelect
set_property PACKAGE_PIN  C1        [ get_ports ArtyA7_SPI_SlaveSelect ]
## {OUT}	MOSI (Master Out - Slave In)
set_property PACKAGE_PIN  H1        [ get_ports ArtyA7_SPI_MOSI ]
## {IN}    MISO (Master In - Slave Out)
set_property PACKAGE_PIN  G1        [ get_ports ArtyA7_SPI_MISO ]
# set I/O standard
set_property IOSTANDARD   LVCMOS33  [ get_ports -regexp {ArtyA7_SPI_.*} ]

# Ignore timings on async I/O pins
set_false_path                -to		[ get_ports ArtyA7_SPI_SerialClock ]
set_false_path                -to		[ get_ports ArtyA7_SPI_SlaveSelect ]
set_false_path                -to		[ get_ports ArtyA7_SPI_MOSI        ]
set_false_path                -from	[ get_ports ArtyA7_SPI_MISO        ]
