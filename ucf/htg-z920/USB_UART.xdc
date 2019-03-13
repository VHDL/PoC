
## Board:                   Hitech Global Z920 ZU19-PS
##      Device:             xczu19egffvc1760-2-e
##
## -----------------------------------------------------------------------------
## -- USB UART --
## -----------------------------------------------------------------------------
##  Bank:                   93
##      VCCO:               3.3V (+3.3V)
##  Location:               U58
##      Vendor:             Silicon Labs
##      Device:             CP2103-GM
##      Baud-Rate:          300 Bd - 1 MBd
##  Note:                   USB-UART is the master, FPGA is the slave => so TX is an input and RX an output

## { OUT }  U58 - Pin 24 - UART_PL_RXD
set_property PACKAGE_PIN    A7              [get_ports HTG_Z920_USB_UART_RX]
## { IN  }  U58 - Pin 25 - UART_PL_TXD
set_property PACKAGE_PIN    B7              [get_ports HTG_Z920_USB_UART_TX]

## { IN  }  U58 - Pin 23 - UART_PL_CTS
set_property PACKAGE_PIN    E7              [get_ports HTG_Z920_USB_UART_CTS_n]
## { OUT }  U58 - Pin 22 - UART_PL_RTS
set_property PACKAGE_PIN    D7              [get_ports HTG_Z920_USB_UART_RTS_n]


## { OUT }  U58 - Pin 9 - UART_PL_RST_N - 4.7K Pullup 3V3
set_property PACKAGE_PIN    B8              [get_ports HTG_Z920_USB_UART_RST_n]
## { OUT }  U58 - Pin 11 - UART_PL_SUSPEND_N - 4.7K Pullup 3V3
set_property PACKAGE_PIN    A8              [get_ports HTG_Z920_USB_UART_SUSPEND_n]


## {INOUT}  U58 - Pin 19 - UART_PL_GPIO0 - Controlls LED D2, too
set_property PACKAGE_PIN    F6              [get_ports HTG_Z920_USB_UART_GPIO0]
## {INOUT}  U58 - Pin 18 - UART_PL_GPIO1
set_property PACKAGE_PIN    E6              [get_ports HTG_Z920_USB_UART_GPIO1]
## {INOUT}  U58 - Pin 17 - UART_PL_GPIO2
set_property PACKAGE_PIN    F7              [get_ports HTG_Z920_USB_UART_GPIO2]
## {INOUT}  U58 - Pin 16 - UART_PL_GPIO3
set_property PACKAGE_PIN    D6              [get_ports HTG_Z920_USB_UART_GPIO3]

## { IN  }  J1 - Pin 1 via 4.7K prot - UART_PL_PERI_PWR
set_property PACKAGE_PIN    C8              [get_ports HTG_Z920_USB_UART_PERI_PWR]


## set I/O standard
set_property IOSTANDARD     LVCMOS33        [get_ports -regexp {HTG_Z920_USB_UART_.*}]

## Ignore timings on async I/O pins
set_false_path                      -to     [get_ports HTG_Z920_USB_UART_RX]
set_false_path                      -from   [get_ports HTG_Z920_USB_UART_TX]
set_false_path                      -to     [get_ports HTG_Z920_USB_UART_CTS_n]
set_false_path                      -from   [get_ports HTG_Z920_USB_UART_RTS_n]
set_false_path                      -to     [get_ports HTG_Z920_USB_UART_RST_n]
set_false_path                      -to     [get_ports HTG_Z920_USB_UART_SUSPEND_n]
set_false_path                      -from   [get_ports HTG_Z920_USB_UART_PERI_PWR]

