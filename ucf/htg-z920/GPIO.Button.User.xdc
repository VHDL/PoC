## Board:                   Hitech Global Z920 ZU19-PS
##      Device:             xczu19egffvc1760-2-e
##
## -----------------------------------------------------------------------------
## -- GPIO User Button --
## -----------------------------------------------------------------------------
##  Bank:                   93
##      VCCO:               3.3V (+3.3V)
##  Location:               PB1
##      Vendor:             Bourns
##      Device:             7914G-1-000E
##      Characteristics:    Pushbutton, pullup on push from 3V3 with 4K7R
##  Note:                   


## { IN  }  PB1 -3V3 Bank Voltage
set_property PACKAGE_PIN    D8              [ get_ports HTG_Z920_GPIO_Button_User[0] ]


## set I/O standard
set_property IOSTANDARD     LVCMOS33        [get_ports -regexp {HTG_Z920_GPIO_Button_.*}]

## Ignore timings on async I/O pins
set_false_path                      -from     [get_ports -regexp {HTG_Z920_GPIO_Button_User\[\d\]} ]
