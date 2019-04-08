## Board:                   Hitech Global Z920 ZU19-PS
##      Device:             xczu19egffvc1760-2-e
##
## -----------------------------------------------------------------------------
## -- PCIe Root Complex FMC --
## -----------------------------------------------------------------------------
##  Bank:                   128, 129, 130, 131
##      VCCO:               CML
##  Location:               J8 FMC Header 
##      Vendor:             Hitech Global
##      Device:             HTG-FMC-PCIE-RC
##      Characteristics:    8x PCIe Root complex FMC
##      Main features:      X8 PCI Express Root
##                          Clock (100MHz, 250MHz, etc.)
##                          Frequency Synthesizer
##                          EEPROM
##                          FMC Connector
##                          I2C config is performed via main I2C bus of the Z920
##------------


set_property PACKAGE_PIN L33    [ get_ports HTG_Z920_HPC_PCIe_CLK_n]         ; ## { IN  } GBTCLK0_M2C_n      
set_property PACKAGE_PIN L32    [ get_ports HTG_Z920_HPC_PCIe_CLK_p]         ; ## { IN  } GBTCLK0_M2C_p      
set_property PACKAGE_PIN W42    [ get_ports HTG_Z920_HPC_PCIe_Rx[0]_n]       ; ## { OUT } FMC_PL_DP[05]_M2C_n
set_property PACKAGE_PIN W41    [ get_ports HTG_Z920_HPC_PCIe_Rx[0]_p]       ; ## { OUT } FMC_PL_DP[05]_M2C_p
set_property PACKAGE_PIN V40    [ get_ports HTG_Z920_HPC_PCIe_Rx[1]_n]       ; ## { OUT } FMC_PL_DP[06]_M2C_n
set_property PACKAGE_PIN V39    [ get_ports HTG_Z920_HPC_PCIe_Rx[1]_p]       ; ## { OUT } FMC_PL_DP[06]_M2C_p
set_property PACKAGE_PIN U42    [ get_ports HTG_Z920_HPC_PCIe_Rx[2]_n]       ; ## { OUT } FMC_PL_DP[04]_M2C_n
set_property PACKAGE_PIN U41    [ get_ports HTG_Z920_HPC_PCIe_Rx[2]_p]       ; ## { OUT } FMC_PL_DP[04]_M2C_p
set_property PACKAGE_PIN T40    [ get_ports HTG_Z920_HPC_PCIe_Rx[3]_n]       ; ## { OUT } FMC_PL_DP[07]_M2C_n
set_property PACKAGE_PIN T39    [ get_ports HTG_Z920_HPC_PCIe_Rx[3]_p]       ; ## { OUT } FMC_PL_DP[07]_M2C_p
set_property PACKAGE_PIN E42    [ get_ports HTG_Z920_HPC_PCIe_Rx[4]_n]       ; ## { OUT } FMC_PL_DP[03]_M2C_n
set_property PACKAGE_PIN E41    [ get_ports HTG_Z920_HPC_PCIe_Rx[4]_p]       ; ## { OUT } FMC_PL_DP[03]_M2C_p
set_property PACKAGE_PIN F40    [ get_ports HTG_Z920_HPC_PCIe_Rx[5]_n]       ; ## { OUT } FMC_PL_DP[02]_M2C_n
set_property PACKAGE_PIN F39    [ get_ports HTG_Z920_HPC_PCIe_Rx[5]_p]       ; ## { OUT } FMC_PL_DP[02]_M2C_p
set_property PACKAGE_PIN G42    [ get_ports HTG_Z920_HPC_PCIe_Rx[6]_n]       ; ## { OUT } FMC_PL_DP[01]_M2C_n
set_property PACKAGE_PIN G41    [ get_ports HTG_Z920_HPC_PCIe_Rx[6]_p]       ; ## { OUT } FMC_PL_DP[01]_M2C_p
set_property PACKAGE_PIN D40    [ get_ports HTG_Z920_HPC_PCIe_Rx[7]_n]       ; ## { OUT } FMC_PL_DP[00]_M2C_n
set_property PACKAGE_PIN D39    [ get_ports HTG_Z920_HPC_PCIe_Rx[7]_p]       ; ## { OUT } FMC_PL_DP[00]_M2C_p
set_property PACKAGE_PIN Y35    [ get_ports HTG_Z920_HPC_PCIe_Tx[0]_n]       ; ## { IN  } FMC_PL_DP[05]_C2M_n
set_property PACKAGE_PIN Y34    [ get_ports HTG_Z920_HPC_PCIe_Tx[0]_p]       ; ## { IN  } FMC_PL_DP[05]_C2M_p
set_property PACKAGE_PIN W37    [ get_ports HTG_Z920_HPC_PCIe_Tx[1]_n]       ; ## { IN  } FMC_PL_DP[06]_C2M_n
set_property PACKAGE_PIN W36    [ get_ports HTG_Z920_HPC_PCIe_Tx[1]_p]       ; ## { IN  } FMC_PL_DP[06]_C2M_p
set_property PACKAGE_PIN V35    [ get_ports HTG_Z920_HPC_PCIe_Tx[2]_n]       ; ## { IN  } FMC_PL_DP[04]_C2M_n
set_property PACKAGE_PIN V34    [ get_ports HTG_Z920_HPC_PCIe_Tx[2]_p]       ; ## { IN  } FMC_PL_DP[04]_C2M_p
set_property PACKAGE_PIN U37    [ get_ports HTG_Z920_HPC_PCIe_Tx[3]_n]       ; ## { IN  } FMC_PL_DP[07]_C2M_n
set_property PACKAGE_PIN U36    [ get_ports HTG_Z920_HPC_PCIe_Tx[3]_p]       ; ## { IN  } FMC_PL_DP[07]_C2M_p
set_property PACKAGE_PIN F35    [ get_ports HTG_Z920_HPC_PCIe_Tx[4]_n]       ; ## { IN  } FMC_PL_DP[03]_C2M_n
set_property PACKAGE_PIN F34    [ get_ports HTG_Z920_HPC_PCIe_Tx[4]_p]       ; ## { IN  } FMC_PL_DP[03]_C2M_p
set_property PACKAGE_PIN G37    [ get_ports HTG_Z920_HPC_PCIe_Tx[5]_n]       ; ## { IN  } FMC_PL_DP[02]_C2M_n
set_property PACKAGE_PIN G36    [ get_ports HTG_Z920_HPC_PCIe_Tx[5]_p]       ; ## { IN  } FMC_PL_DP[02]_C2M_p
set_property PACKAGE_PIN H35    [ get_ports HTG_Z920_HPC_PCIe_Tx[6]_n]       ; ## { IN  } FMC_PL_DP[01]_C2M_n
set_property PACKAGE_PIN H34    [ get_ports HTG_Z920_HPC_PCIe_Tx[6]_p]       ; ## { IN  } FMC_PL_DP[01]_C2M_p
set_property PACKAGE_PIN E37    [ get_ports HTG_Z920_HPC_PCIe_Tx[7]_n]       ; ## { IN  } FMC_PL_DP[00]_C2M_n
set_property PACKAGE_PIN E36    [ get_ports HTG_Z920_HPC_PCIe_Tx[7]_p]       ; ## { IN  } FMC_PL_DP[00]_C2M_p


