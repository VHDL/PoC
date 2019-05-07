## Board:                   Hitech Global Z920 ZU19-PS
##      Device:             xczu19egffvc1760-2-e
##
## -----------------------------------------------------------------------------
## -- PCIe Bus --
## -----------------------------------------------------------------------------
##  Bank:                   224, 225, 226, 227; 94
##      VCCO:               
##  Location:               PEA1, PEA2
##      Vendor:             N/A
##      Device:             PCI_E_FINGER_16X_Side_A
##      Characteristics:    

##------------
##PCIe Clocks:

## { IN  }  Bank 224 PCIE_CLK0_MGT0_P
set_property PACKAGE_PIN    AK12            [ get_ports HTG_Z920_BUS_PCIe_CLK_p ]
## { IN  }  Bank 224 PCIE_CLK0_MGT0_N
set_property PACKAGE_PIN    AK11            [ get_ports HTG_Z920_BUS_PCIe_CLK_n ]

## { IN  }  Bank 227 PCIE_CLK0_MGT1_N
set_property PACKAGE_PIN    AC9             [ get_ports HTG_Z920_BUS_PCIe_GTH_227_CLK_n ]
## { IN  }  Bank 227 PCIE_CLK0_MGT1_P
set_property PACKAGE_PIN    AC10            [ get_ports HTG_Z920_BUS_PCIe_GTH_227_CLK_p ]

## { IN  }  Bank 226 PCIE_CLK1_MGT_N
set_property PACKAGE_PIN    AF11            [ get_ports HTG_Z920_BUS_PCIe_GTH_226_CLK_n ]
## { IN  }  Bank 226 PCIE_CLK1_MGT_P
set_property PACKAGE_PIN    AF12            [ get_ports HTG_Z920_BUS_PCIe_GTH_226_CLK_p ]

## { IN  }  Bank 227 PCIE_CLK2_MGT_N
set_property PACKAGE_PIN    AD11            [ get_ports HTG_Z920_BUS_PCIe_GTH_227_CLK_n ]
## { IN  }  Bank 227 PCIE_CLK2_MGT_P
set_property PACKAGE_PIN    AD12            [ get_ports HTG_Z920_BUS_PCIe_GTH_227_CLK_p ]

## { IN  }  Bank 225 PCIE_CLK3_MGT_N
set_property PACKAGE_PIN    AH11            [ get_ports HTG_Z920_BUS_PCIe_GTH_225_CLK_n ]
## { IN  }  Bank 225 PCIE_CLK3_MGT_P
set_property PACKAGE_PIN    AH12            [ get_ports HTG_Z920_BUS_PCIe_GTH_225_CLK_p ]


##------------
##PCIe RX:

## { IN  }  Bank 227 
set_property PACKAGE_PIN    AE1             [ get_ports HTG_Z920_BUS_PCIe_Rx[0]_n ]
## { IN  }  Bank 227 
set_property PACKAGE_PIN    AE2             [ get_ports HTG_Z920_BUS_PCIe_Rx[0]_p ]
## { IN  }  Bank 227 
set_property PACKAGE_PIN    AF3             [ get_ports HTG_Z920_BUS_PCIe_Rx[1]_n ]
## { IN  }  Bank 227 
set_property PACKAGE_PIN    AF4             [ get_ports HTG_Z920_BUS_PCIe_Rx[1]_p ]
## { IN  }  Bank 227 
set_property PACKAGE_PIN    AG1             [ get_ports HTG_Z920_BUS_PCIe_Rx[2]_n ]
## { IN  }  Bank 227 
set_property PACKAGE_PIN    AG2             [ get_ports HTG_Z920_BUS_PCIe_Rx[2]_p ]
## { IN  }  Bank 227 
set_property PACKAGE_PIN    AH3             [ get_ports HTG_Z920_BUS_PCIe_Rx[3]_n ]
## { IN  }  Bank 227 
set_property PACKAGE_PIN    AH4             [ get_ports HTG_Z920_BUS_PCIe_Rx[3]_p ]


## { IN  }  Bank 226 
set_property PACKAGE_PIN    AJ1             [ get_ports HTG_Z920_BUS_PCIe_Rx[4]_n ]
## { IN  }  Bank 226 
set_property PACKAGE_PIN    AJ2             [ get_ports HTG_Z920_BUS_PCIe_Rx[4]_p ]
## { IN  }  Bank 226 
set_property PACKAGE_PIN    AK3             [ get_ports HTG_Z920_BUS_PCIe_Rx[5]_n ]
## { IN  }  Bank 226 
set_property PACKAGE_PIN    AK4             [ get_ports HTG_Z920_BUS_PCIe_Rx[5]_p ]
## { IN  }  Bank 226 
set_property PACKAGE_PIN    AL1             [ get_ports HTG_Z920_BUS_PCIe_Rx[6]_n ]
## { IN  }  Bank 226 
set_property PACKAGE_PIN    AL2             [ get_ports HTG_Z920_BUS_PCIe_Rx[6]_p ]
## { IN  }  Bank 226 
set_property PACKAGE_PIN    AM3             [ get_ports HTG_Z920_BUS_PCIe_Rx[7]_n ]
## { IN  }  Bank 226 
set_property PACKAGE_PIN    AM4             [ get_ports HTG_Z920_BUS_PCIe_Rx[7]_p ]


## { IN  }  Bank 225 
set_property PACKAGE_PIN    AN1             [ get_ports HTG_Z920_BUS_PCIe_Rx[8]_n ]
## { IN  }  Bank 225 
set_property PACKAGE_PIN    AN2             [ get_ports HTG_Z920_BUS_PCIe_Rx[8]_p ]
## { IN  }  Bank 225 
set_property PACKAGE_PIN    AP3             [ get_ports HTG_Z920_BUS_PCIe_Rx[9]_n ]
## { IN  }  Bank 225 
set_property PACKAGE_PIN    AP4             [ get_ports HTG_Z920_BUS_PCIe_Rx[9]_p ]
## { IN  }  Bank 225 
set_property PACKAGE_PIN    AR1             [ get_ports HTG_Z920_BUS_PCIe_Rx[10]_n ]
## { IN  }  Bank 225 
set_property PACKAGE_PIN    AR2             [ get_ports HTG_Z920_BUS_PCIe_Rx[10]_p ]
## { IN  }  Bank 225 
set_property PACKAGE_PIN    AT3             [ get_ports HTG_Z920_BUS_PCIe_Rx[11]_n ]
## { IN  }  Bank 225 
set_property PACKAGE_PIN    AT4             [ get_ports HTG_Z920_BUS_PCIe_Rx[11]_p ]


## { IN  }  Bank 224 
set_property PACKAGE_PIN    AU1             [ get_ports HTG_Z920_BUS_PCIe_Rx[12]_n ]
## { IN  }  Bank 224 
set_property PACKAGE_PIN    AU2             [ get_ports HTG_Z920_BUS_PCIe_Rx[12]_p ]
## { IN  }  Bank 224 
set_property PACKAGE_PIN    AV3             [ get_ports HTG_Z920_BUS_PCIe_Rx[13]_n ]
## { IN  }  Bank 224 
set_property PACKAGE_PIN    AV4             [ get_ports HTG_Z920_BUS_PCIe_Rx[13]_p ]
## { IN  }  Bank 224 
set_property PACKAGE_PIN    AW1             [ get_ports HTG_Z920_BUS_PCIe_Rx[14]_n ]
## { IN  }  Bank 224 
set_property PACKAGE_PIN    AW2             [ get_ports HTG_Z920_BUS_PCIe_Rx[14]_p ]
## { IN  }  Bank 224 
set_property PACKAGE_PIN    BA1             [ get_ports HTG_Z920_BUS_PCIe_Rx[15]_n ]
## { IN  }  Bank 224 
set_property PACKAGE_PIN    BA2             [ get_ports HTG_Z920_BUS_PCIe_Rx[15]_p ]


##------------
##PCIe TX:

## { OUT }  Bank 227
set_property PACKAGE_PIN    AD7             [ get_ports HTG_Z920_BUS_PCIe_Tx[0]_n ]
## { OUT }  Bank 227
set_property PACKAGE_PIN    AD8             [ get_ports HTG_Z920_BUS_PCIe_Tx[0]_p ]
## { OUT }  Bank 227
set_property PACKAGE_PIN    AE5             [ get_ports HTG_Z920_BUS_PCIe_Tx[1]_n ]
## { OUT }  Bank 227
set_property PACKAGE_PIN    AE6             [ get_ports HTG_Z920_BUS_PCIe_Tx[1]_p ]
## { OUT }  Bank 227
set_property PACKAGE_PIN    AF7             [ get_ports HTG_Z920_BUS_PCIe_Tx[2]_n ]
## { OUT }  Bank 227
set_property PACKAGE_PIN    AF8             [ get_ports HTG_Z920_BUS_PCIe_Tx[2]_p ]
## { OUT }  Bank 227
set_property PACKAGE_PIN    AG5             [ get_ports HTG_Z920_BUS_PCIe_Tx[3]_n ]
## { OUT }  Bank 227
set_property PACKAGE_PIN    AG6             [ get_ports HTG_Z920_BUS_PCIe_Tx[3]_p ]



## { OUT }  Bank 226
set_property PACKAGE_PIN    AH7             [ get_ports HTG_Z920_BUS_PCIe_Tx[4]_n ]
## { OUT }  Bank 226
set_property PACKAGE_PIN    AH8             [ get_ports HTG_Z920_BUS_PCIe_Tx[4]_p ]
## { OUT }  Bank 226
set_property PACKAGE_PIN    AJ5             [ get_ports HTG_Z920_BUS_PCIe_Tx[5]_n ]
## { OUT }  Bank 226
set_property PACKAGE_PIN    AJ6             [ get_ports HTG_Z920_BUS_PCIe_Tx[5]_p ]
## { OUT }  Bank 226
set_property PACKAGE_PIN    AK7             [ get_ports HTG_Z920_BUS_PCIe_Tx[6]_n ]
## { OUT }  Bank 226
set_property PACKAGE_PIN    AK8             [ get_ports HTG_Z920_BUS_PCIe_Tx[6]_p ]
## { OUT }  Bank 226
set_property PACKAGE_PIN    AL5             [ get_ports HTG_Z920_BUS_PCIe_Tx[7]_n ]
## { OUT }  Bank 226
set_property PACKAGE_PIN    AL6             [ get_ports HTG_Z920_BUS_PCIe_Tx[7]_p ]



## { OUT }  Bank 225
set_property PACKAGE_PIN    AM7             [ get_ports HTG_Z920_BUS_PCIe_Tx[8]_n ]
## { OUT }  Bank 225
set_property PACKAGE_PIN    AM8             [ get_ports HTG_Z920_BUS_PCIe_Tx[8]_p ]
## { OUT }  Bank 225
set_property PACKAGE_PIN    AN5             [ get_ports HTG_Z920_BUS_PCIe_Tx[9]_n ]
## { OUT }  Bank 225
set_property PACKAGE_PIN    AN6             [ get_ports HTG_Z920_BUS_PCIe_Tx[9]_p ]
## { OUT }  Bank 225
set_property PACKAGE_PIN    AP7             [ get_ports HTG_Z920_BUS_PCIe_Tx[10]_n ]
## { OUT }  Bank 225
set_property PACKAGE_PIN    AP8             [ get_ports HTG_Z920_BUS_PCIe_Tx[10]_p ]
## { OUT }  Bank 225
set_property PACKAGE_PIN    AR5             [ get_ports HTG_Z920_BUS_PCIe_Tx[11]_n ]
## { OUT }  Bank 225
set_property PACKAGE_PIN    AR6             [ get_ports HTG_Z920_BUS_PCIe_Tx[11]_p ]


## { OUT }  Bank 22
set_property PACKAGE_PIN    AT7             [ get_ports HTG_Z920_BUS_PCIe_Tx[12]_n ]
## { OUT }  Bank 22
set_property PACKAGE_PIN    AT8             [ get_ports HTG_Z920_BUS_PCIe_Tx[12]_p ]
## { OUT }  Bank 22
set_property PACKAGE_PIN    AU5             [ get_ports HTG_Z920_BUS_PCIe_Tx[13]_n ]
## { OUT }  Bank 22
set_property PACKAGE_PIN    AU6             [ get_ports HTG_Z920_BUS_PCIe_Tx[13]_p ]
## { OUT }  Bank 22
set_property PACKAGE_PIN    AW5             [ get_ports HTG_Z920_BUS_PCIe_Tx[14]_n ]
## { OUT }  Bank 22
set_property PACKAGE_PIN    AW6             [ get_ports HTG_Z920_BUS_PCIe_Tx[14]_p ]
## { OUT }  Bank 22
set_property PACKAGE_PIN    AY3             [ get_ports HTG_Z920_BUS_PCIe_Tx[15]_n ]
## { OUT }  Bank 22
set_property PACKAGE_PIN    AY4             [ get_ports HTG_Z920_BUS_PCIe_Tx[15]_p ]


##-------------
##PCIe control:

## { IN  }  Bank 94; Bank Voltage 3V3
set_property PACKAGE_PIN    E1              [ get_ports HTG_Z920_BUS_PCIe_WAKE ]


## { IN  }  Bank 94; Bank Voltage 3V3
set_property PACKAGE_PIN    D2              [ get_ports HTG_Z920_BUS_PCIe_PERST_n ]



## set I/O standard
set_property IOSTANDARD     LVCMOS33        [ get_ports HTG_Z920_BUS_PCIe_WAKE ]
set_property IOSTANDARD     LVCMOS33        [ get_ports HTG_Z920_BUS_PCIe_PERST_n ]

#Timing
set_false_path              -from           [ get_ports HTG_Z920_BUS_PCIe_WAKE ]
set_false_path              -from           [ get_ports HTG_Z920_BUS_PCIe_PERST_n ]

