## Board:                   Hitech Global Z920 ZU19-PS
##      Device:             xczu19egffvc1760-2-e
##
## -----------------------------------------------------------------------------
## -- GPIO Dip Switch --
## -----------------------------------------------------------------------------
##  Bank:                   67
##      VCCO:               1.8V (+1.8V)
##  Location:               S3
##      Vendor:             N/A
##      Device:             DIP SWITCH FHDS-8
##      Characteristics:    Pushbutton, pullup on push from 1V8 with 4K7R
##  Note:                   


## { IN  }  S3 Pin 1 - PL_USER_SW1
set_property PACKAGE_PIN    BB9             [ get_ports HTG_Z920_GPIO_Switches[0] ]
## { IN  }  S3 Pin 2 - PL_USER_SW1
set_property PACKAGE_PIN    BB8             [ get_ports HTG_Z920_GPIO_Switches[1] ]
## { IN  }  S3 Pin 3 - PL_USER_SW1
set_property PACKAGE_PIN    AY9             [ get_ports HTG_Z920_GPIO_Switches[2] ]
## { IN  }  S3 Pin 4 - PL_USER_SW1
set_property PACKAGE_PIN    AW9             [ get_ports HTG_Z920_GPIO_Switches[3] ]


## set I/O standard
set_property IOSTANDARD     LVCMOS18        [ get_ports -regexp {HTG_Z920_GPIO_Switches\[0-3]} ]

## Ignore timings on async I/O pins
set_false_path              -from           [ get_ports -regexp {HTG_Z920_GPIO_Switches\[\d\]} ]
