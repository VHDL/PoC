## Board:                   Hitech Global Z920 ZU19-PS
##      Device:             xczu19egffvc1760-2-e
##
## -----------------------------------------------------------------------------
## -- System Clock --
## -----------------------------------------------------------------------------
##  Bank:                   94; 67
##      VCCO:               3.3V (+3.3V); 1.8V (+1.8V)
##  Location:               U46
##      Vendor:             Silicon Labs
##      Device:             SI5341A-A-GM
##      Characteristics:    Clock Generator, 100Hz-712.5MHz, 10 Outputs
##  Note:                   


##User Clock:
## { OUT }  U46 Pin 54 - FPGA BANK 94 3V3 - Clock 8 - CLK_USER_P
set_property PACKAGE_PIN    D4             [ get_ports HTG_Z920_ProgClock_UserClock_p ]
## { OUT }  U46 Pin 53 - FPGA BANK 94 3V3 - Clock 8 - CLK_USER_N
set_property PACKAGE_PIN    D3             [ get_ports HTG_Z920_ProgClock_UserClock_n ]


##GTR_505 FMC_PS Clock:
## { OUT }  U46 Pin 24 - FPGA BANK 505 - Clock 0 - GTR_505_REFCLK_P
set_property PACKAGE_PIN    AC37           [ get_ports HTG_Z920_ProgClock_GTR_505_p ]
## { OUT }  U46 Pin 23 - FPGA BANK 505 - Clock 0 - GTR_505_REFCLK_N
set_property PACKAGE_PIN    AC38           [ get_ports HTG_Z920_ProgClock_GTR_505_n ]


##GTY_128 FMC_PL Clock:
## { OUT }  U46 Pin 31 - FPGA BANK 128 - Clock 2 - GTY_128_REFCLK_P
set_property PACKAGE_PIN    AA32           [ get_ports HTG_Z920_ProgClock_GTY_128_p ] 
## { OUT }  U46 Pin 30 - FPGA BANK 128 - Clock 2 - GTY_128_REFCLK_N
set_property PACKAGE_PIN    AA33           [ get_ports HTG_Z920_ProgClock_GTY_128_n ]


##GTY_129 FMC_PL Clock:
## { OUT }  U46 Pin 51 - FPGA BANK 129 - Clock 7 - GTY_129_REFCLK_P
set_property PACKAGE_PIN    U32            [ get_ports HTG_Z920_ProgClock_GTY_129_p ]
## { OUT }  U46 Pin 50 - FPGA BANK 129 - Clock 7 - GTY_129_REFCLK_N
set_property PACKAGE_PIN    U33            [ get_ports HTG_Z920_ProgClock_GTY_129_n ]


##GTY_130 FMC_PL Clock:
## { OUT }  U46 Pin 38 - FPGA BANK 130 - Clock 4 - GTY_130_REFCLK_P
set_property PACKAGE_PIN    N32            [ get_ports HTG_Z920_ProgClock_GTY_130_p ]
## { OUT }  U46 Pin 37 - FPGA BANK 130 - Clock 4 - GTY_130_REFCLK_N
set_property PACKAGE_PIN    N33            [ get_ports HTG_Z920_ProgClock_GTY_130_n ]


##GTY_131 FMC_PL Clock:
## { OUT }  U46 Pin 35 - FPGA BANK 131 - Clock 3 - GTY_131_REFCLK_P
set_property PACKAGE_PIN    J32            [ get_ports HTG_Z920_ProgClock_GTY_131_p ]
## { OUT }  U46 Pin 34 - FPGA BANK 131 - Clock 3 - GTY_131_REFCLK_N
set_property PACKAGE_PIN    J33            [ get_ports HTG_Z920_ProgClock_GTY_131_n ]


##GTH_229 ZRAY Clock:
## { OUT }  U46 Pin 59 - FPGA BANK 229 - Clock 9 - GTH_229_REFCLK_P
set_property PACKAGE_PIN    Y12            [ get_ports HTG_Z920_ProgClock_GTH_229_p ]
## { OUT }  U46 Pin 58 - FPGA BANK 229 - Clock 9 - GTH_229_REFCLK_N
set_property PACKAGE_PIN    Y11           [ get_ports HTG_Z920_ProgClock_GTH_229_n ]


##GTH_231 ZRAY Clock:
## { OUT }  U46 Pin 45 - FPGA BANK 231 - Clock 6 - GTH_231_REFCLK_P
set_property PACKAGE_PIN    T12           [ get_ports HTG_Z920_ProgClock_GTH_231_p ]
## { OUT }  U46 Pin 44 - FPGA BANK 231 - Clock 6 - GTH_231_REFCLK_N
set_property PACKAGE_PIN    T11           [ get_ports HTG_Z920_ProgClock_GTH_231_n ]

  
#Clock Control:
## { OUT }  U46 Pin 6 - FPGA Bank 67 1V8 - CLK_RST_N
set_property PACKAGE_PIN    AP11           [ get_ports HTG_Z920_ProgClock_ctrl_rst_n ]
## { OUT }  U46 Pin 5 0R Pulldown?? - FPGA Out Bank 67 1V8  CLK_SYNC_N - disabled via pulldown
#set_property PACKAGE_PIN    AP10           [ get_ports HTG_Z920_ProgClock_ctrl_sync_n ]
## { OUT }  U46 Pin 48 - FPGA Bank 67 1V8 - CLK_FINC
set_property PACKAGE_PIN    AM11           [ get_ports HTG_Z920_ProgClock_ctrl_FINC ]
## { OUT }  U46 Pin 25 - FPGA Bank 67 1V8 - CLK_FDEC
set_property PACKAGE_PIN    AN11           [ get_ports HTG_Z920_ProgClock_ctrl_FDEC ]
## { IN  }  U46 Pin 47 - FPGA Bank 67 1V8 - CLK_LOL_N
set_property PACKAGE_PIN    AM10           [ get_ports HTG_Z920_ProgClock_ctrl_LOL_n ]
## { IN  }  U46 Pin 12 0R Pullup?? - FPGA Bank 67 1V8 - CLK_INTR_N --disabled via pullup
#set_property PACKAGE_PIN    AN10           [ get_ports HTG_Z920_ProgClock_ctrl_intr_n ]



## set I/O standard
set_property IOSTANDARD     LVDS           [ get_ports -regexp {HTG_Z920_ProgClock_UserClock_*} ]

set_property IOSTANDARD     LVCMOS18       [ get_ports -regexp {HTG_Z920_ProgClock_ctrl_*} ]


#Timing:
#Ignore timing on control signals (reset and sync)
set_false_path           -from             [ get_ports -regexp {HTG_Z920_ProgClock_ctrl_*}  ]


