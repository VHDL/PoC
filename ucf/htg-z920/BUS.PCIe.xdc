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
set_property PACKAGE_PIN    AE1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[0] ]
## { IN  }  Bank 227                                                        
set_property PACKAGE_PIN    AE2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[0] ]
## { IN  }  Bank 227                                                        
set_property PACKAGE_PIN    AF3             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[1] ]
## { IN  }  Bank 227                                                        
set_property PACKAGE_PIN    AF4             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[1] ]
## { IN  }  Bank 227                                                        
set_property PACKAGE_PIN    AG1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[2] ]
## { IN  }  Bank 227                                                        
set_property PACKAGE_PIN    AG2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[2] ]
## { IN  }  Bank 227                                                        
set_property PACKAGE_PIN    AH3             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[3] ]
## { IN  }  Bank 227                                                        
set_property PACKAGE_PIN    AH4             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[3] ]


## { IN  }  Bank 226 
set_property PACKAGE_PIN    AJ1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[4] ]
## { IN  }  Bank 226                                                        
set_property PACKAGE_PIN    AJ2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[4] ]
## { IN  }  Bank 226                                                        
set_property PACKAGE_PIN    AK3             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[5] ]
## { IN  }  Bank 226                                                        
set_property PACKAGE_PIN    AK4             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[5] ]
## { IN  }  Bank 226                                                        
set_property PACKAGE_PIN    AL1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[6] ]
## { IN  }  Bank 226                                                        
set_property PACKAGE_PIN    AL2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[6] ]
## { IN  }  Bank 226                                                        
set_property PACKAGE_PIN    AM3             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[7] ]
## { IN  }  Bank 226                                                        
set_property PACKAGE_PIN    AM4             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[7] ]


## { IN  }  Bank 225 
set_property PACKAGE_PIN    AN1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[8] ]
## { IN  }  Bank 225                                                        
set_property PACKAGE_PIN    AN2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[8] ]
## { IN  }  Bank 225                                                        
set_property PACKAGE_PIN    AP3             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[9] ]
## { IN  }  Bank 225                                                        
set_property PACKAGE_PIN    AP4             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[9] ]
## { IN  }  Bank 225 
set_property PACKAGE_PIN    AR1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[10] ]
## { IN  }  Bank 225                                                        
set_property PACKAGE_PIN    AR2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[10] ]
## { IN  }  Bank 225                                                        
set_property PACKAGE_PIN    AT3             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[11] ]
## { IN  }  Bank 225                                                        
set_property PACKAGE_PIN    AT4             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[11] ]


## { IN  }  Bank 224 
set_property PACKAGE_PIN    AU1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[12] ]
## { IN  }  Bank 224                                                        
set_property PACKAGE_PIN    AU2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[12] ]
## { IN  }  Bank 224                                                        
set_property PACKAGE_PIN    AV3             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[13] ]
## { IN  }  Bank 224                                                        
set_property PACKAGE_PIN    AV4             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[13] ]
## { IN  }  Bank 224                                                        
set_property PACKAGE_PIN    AW1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[14] ]
## { IN  }  Bank 224                                                        
set_property PACKAGE_PIN    AW2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[14] ]
## { IN  }  Bank 224                                                        
set_property PACKAGE_PIN    BA1             [ get_ports HTG_Z920_BUS_PCIe_Rx_n[15] ]
## { IN  }  Bank 224                                                        
set_property PACKAGE_PIN    BA2             [ get_ports HTG_Z920_BUS_PCIe_Rx_p[15] ]


##------------
##PCIe TX:

## { OUT }  Bank 227
set_property PACKAGE_PIN    AD7             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[0] ]
## { OUT }  Bank 227                                                        
set_property PACKAGE_PIN    AD8             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[0] ]
## { OUT }  Bank 227                                                        
set_property PACKAGE_PIN    AE5             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[1] ]
## { OUT }  Bank 227                                                        
set_property PACKAGE_PIN    AE6             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[1] ]
## { OUT }  Bank 227                                                        
set_property PACKAGE_PIN    AF7             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[2] ]
## { OUT }  Bank 227                                                        
set_property PACKAGE_PIN    AF8             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[2] ]
## { OUT }  Bank 227                                                        
set_property PACKAGE_PIN    AG5             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[3] ]
## { OUT }  Bank 227                                                        
set_property PACKAGE_PIN    AG6             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[3] ]



## { OUT }  Bank 226
set_property PACKAGE_PIN    AH7             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[4] ]
## { OUT }  Bank 226                                                        
set_property PACKAGE_PIN    AH8             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[4] ]
## { OUT }  Bank 226                                                        
set_property PACKAGE_PIN    AJ5             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[5] ]
## { OUT }  Bank 226                                                        
set_property PACKAGE_PIN    AJ6             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[5] ]
## { OUT }  Bank 226                                                        
set_property PACKAGE_PIN    AK7             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[6] ]
## { OUT }  Bank 226                                                        
set_property PACKAGE_PIN    AK8             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[6] ]
## { OUT }  Bank 226                                                        
set_property PACKAGE_PIN    AL5             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[7] ]
## { OUT }  Bank 226                                                        
set_property PACKAGE_PIN    AL6             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[7] ]



## { OUT }  Bank 225
set_property PACKAGE_PIN    AM7             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[8] ]
## { OUT }  Bank 225                                                        
set_property PACKAGE_PIN    AM8             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[8] ]
## { OUT }  Bank 225                                                        
set_property PACKAGE_PIN    AN5             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[9] ]
## { OUT }  Bank 225                                                        
set_property PACKAGE_PIN    AN6             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[9] ]
## { OUT }  Bank 225
set_property PACKAGE_PIN    AP7             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[10] ]
## { OUT }  Bank 225                                                        
set_property PACKAGE_PIN    AP8             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[10] ]
## { OUT }  Bank 225                                                        
set_property PACKAGE_PIN    AR5             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[11] ]
## { OUT }  Bank 225                                                        
set_property PACKAGE_PIN    AR6             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[11] ]


## { OUT }  Bank 22
set_property PACKAGE_PIN    AT7             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[12] ]
## { OUT }  Bank 22                                                         
set_property PACKAGE_PIN    AT8             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[12] ]
## { OUT }  Bank 22                                                         
set_property PACKAGE_PIN    AU5             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[13] ]
## { OUT }  Bank 22                                                         
set_property PACKAGE_PIN    AU6             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[13] ]
## { OUT }  Bank 22                                                         
set_property PACKAGE_PIN    AW5             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[14] ]
## { OUT }  Bank 22                                                         
set_property PACKAGE_PIN    AW6             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[14] ]
## { OUT }  Bank 22                                                         
set_property PACKAGE_PIN    AY3             [ get_ports HTG_Z920_BUS_PCIe_Tx_n[15] ]
## { OUT }  Bank 22                                                         
set_property PACKAGE_PIN    AY4             [ get_ports HTG_Z920_BUS_PCIe_Tx_p[15] ]


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

