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

## { OUT }  U58 - Pin 24 - UART_PL_RXD


##User Clock:
## { OUT }  U46 Pin 54 - FPGA BANK 94 3V3 - Clock 8 - CLK_USER_P
set_property PACKAGE_PIN    D4             [ get_ports HTG_Z920_SystemClock_UserClock_p]
## { OUT }  U46 Pin 53 - FPGA BANK 94 3V3 - Clock 8 - CLK_USER_N
set_property PACKAGE_PIN    D3             [ get_ports HTG_Z920_SystemClock_UserClock_n]
  
#Clock Control:
## { OUT }  U46 Pin 6 - FPGA Bank 67 1V8 - CLK_RST_N
set_property PACKAGE_PIN    AP11           [ get_ports HTG_Z920_SystemClock_ctrl_rst_n]
## { OUT }  U46 Pin 5 0R Pulldown?? - FPGA Out Bank 67 1V8  CLK_SYNC_N
set_property PACKAGE_PIN    AP10           [ get_ports HTG_Z920_SystemClock_ctrl_sync_n]
## { OUT }  U46 Pin 48 - FPGA Bank 67 1V8 - CLK_FINC
set_property PACKAGE_PIN    AM11           [ get_ports HTG_Z920_SystemClock_ctrl_FINC]
## { OUT }  U46 Pin 25 - FPGA Bank 67 1V8 - CLK_FDEC
set_property PACKAGE_PIN    AN11           [ get_ports HTG_Z920_SystemClock_ctrl_FDEC]
## { IN  }  U46 Pin 47 - FPGA Bank 67 1V8 - CLK_LOL_N
set_property PACKAGE_PIN    AM10           [ get_ports HTG_Z920_SystemClock_ctrl_LOL_n]
## { IN  }  U46 Pin 12 0R Pullup?? - FPGA Bank 67 1V8 - CLK_INTR_N
set_property PACKAGE_PIN    AN10           [ get_ports HTG_Z920_SystemClock_ctrl_intr_n]



## set I/O standard
set_property IOSTANDARD     LVPECL         [get_ports -regexp {HTG_Z920_SystemClock_UserClock_*}]

set_property IOSTANDARD     LVCMOS18       [get_ports -regexp {HTG_Z920_SystemClock_ctrl_*}]




#Timing:
#Ignore timing on control signals (reset and sync)
set_false_path                      -from     [get_ports -regexp {HTG_Z920_SystemClock_ctrl_*} ]


#TODO #FIXIT Check LVPECL is correct !!!
#TODO #FIXIT Check no timing needed on sync !!!


# # specify a XXX MHz clock
# create_clock -period XXXXX -name PIN_SystemClock_XXXMHz [get_ports HTG_Z920_SystemClock_UserClock_p]



##Other clocks coming from chip:##############
##  GTR_505_REFCLK_P  FMC_PS (DP0-DP3)  AC37 
##  GTR_505_REFCLK_N  FMC_PS (DP0-DP3)  AC38
##  
##  
##  GTY_128_REFCLK_P  FMC_PL (DP4-DP7)  AA32 
##  GTY_128_REFCLK_N  FMC_PL (DP4-DP7)  AA33
##  
##
##  GTY_131_REFCLK_P  FMC_PL (DP0-DP3)  J32
##  GTY_131_REFCLK_N  FMC_PL (DP0-DP3)  J33 
##  
##
##  GTY_130_REFCLK_P  FMC_PL (DP8-DP11)  N32
##  GTY_130_REFCLK_N  FMC_PL (DP8-DP11)  N33
##  
##  GTH_229_REFCLK_P  ZRAY  Y12
##  GTH_229_REFCLK_N  ZRAY  Y11
##  
##
##  GTH_231_REFCLK_P  ZRAY  T12 
##  GTH_231_REFCLK_N  ZRAY  T11
##  
##
##  GTY_129_REFCLK_P  FMC_PL (DP12-DP15)  U32
##  GTY_129_REFCLK_N  FMC_PL (DP12-DP15)  U33
###############################################




