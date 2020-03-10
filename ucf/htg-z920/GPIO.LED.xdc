## Board:                   Hitech Global Z920 ZU19-PS
##      Device:             xczu19egffvc1760-2-e
##
## -----------------------------------------------------------------------------
## -- GPIO LED --
## -----------------------------------------------------------------------------
##  Bank:                   94
##      VCCO:               3.3V (+3.3V)
##  Location:               D10, D11, D12, D13
##      Vendor:             N/A
##      Device:             LED (Green Green Red Red)
##      Characteristics:    330R input resistor infornt of LEDs D10 - D13
##  Note:                   

## { IN  }  D10 - PL LED 1 -3V3 Bank Voltage
set_property PACKAGE_PIN    A3              [ get_ports HTG_Z920_GPIO_LED[0] ]
## { IN  }  D11 - PL LED 2 -3V3 Bank Voltage
set_property PACKAGE_PIN    A4              [ get_ports HTG_Z920_GPIO_LED[1] ]
## { IN  }  D12 - PL LED 3 -3V3 Bank Voltage
set_property PACKAGE_PIN    B5              [ get_ports HTG_Z920_GPIO_LED[2] ]
## { IN  }  D13 - PL LED 4 -3V3 Bank Voltage
set_property PACKAGE_PIN    A5              [ get_ports HTG_Z920_GPIO_LED[3] ]



## set I/O standard
set_property IOSTANDARD     LVCMOS33        [ get_ports -regexp {HTG_Z920_GPIO_LED*} ]

## Ignore timings on async I/O pins
set_false_path              -from           [ get_ports -regexp {HTG_Z920_GPIO_LED*} ]

