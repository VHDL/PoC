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


set_property PACKAGE_PIN L33    [ get_ports HTG_Z920_HPC_PCIe_CLK_n]  ; ## { IN  } GBTCLK0_M2C_n      
set_property PACKAGE_PIN L32    [ get_ports HTG_Z920_HPC_PCIe_CLK_p]  ; ## { IN  } GBTCLK0_M2C_p      
set_property PACKAGE_PIN W42    [ get_ports HTG_Z920_HPC_PCIe_Rx_n[0]]; ## { IN  } FMC_PL_DP[05]_M2C_n
set_property PACKAGE_PIN W41    [ get_ports HTG_Z920_HPC_PCIe_Rx_p[0]]; ## { IN  } FMC_PL_DP[05]_M2C_p
set_property PACKAGE_PIN V40    [ get_ports HTG_Z920_HPC_PCIe_Rx_n[1]]; ## { IN  } FMC_PL_DP[06]_M2C_n
set_property PACKAGE_PIN V39    [ get_ports HTG_Z920_HPC_PCIe_Rx_p[1]]; ## { IN  } FMC_PL_DP[06]_M2C_p
set_property PACKAGE_PIN U42    [ get_ports HTG_Z920_HPC_PCIe_Rx_n[2]]; ## { IN  } FMC_PL_DP[04]_M2C_n
set_property PACKAGE_PIN U41    [ get_ports HTG_Z920_HPC_PCIe_Rx_p[2]]; ## { IN  } FMC_PL_DP[04]_M2C_p
set_property PACKAGE_PIN T40    [ get_ports HTG_Z920_HPC_PCIe_Rx_n[3]]; ## { IN  } FMC_PL_DP[07]_M2C_n
set_property PACKAGE_PIN T39    [ get_ports HTG_Z920_HPC_PCIe_Rx_p[3]]; ## { IN  } FMC_PL_DP[07]_M2C_p
set_property PACKAGE_PIN E42    [ get_ports HTG_Z920_HPC_PCIe_Rx_n[4]]; ## { IN  } FMC_PL_DP[03]_M2C_n
set_property PACKAGE_PIN E41    [ get_ports HTG_Z920_HPC_PCIe_Rx_p[4]]; ## { IN  } FMC_PL_DP[03]_M2C_p
set_property PACKAGE_PIN F40    [ get_ports HTG_Z920_HPC_PCIe_Rx_n[5]]; ## { IN  } FMC_PL_DP[02]_M2C_n
set_property PACKAGE_PIN F39    [ get_ports HTG_Z920_HPC_PCIe_Rx_p[5]]; ## { IN  } FMC_PL_DP[02]_M2C_p
set_property PACKAGE_PIN G42    [ get_ports HTG_Z920_HPC_PCIe_Rx_n[6]]; ## { IN  } FMC_PL_DP[01]_M2C_n
set_property PACKAGE_PIN G41    [ get_ports HTG_Z920_HPC_PCIe_Rx_p[6]]; ## { IN  } FMC_PL_DP[01]_M2C_p
set_property PACKAGE_PIN D40    [ get_ports HTG_Z920_HPC_PCIe_Rx_n[7]]; ## { IN  } FMC_PL_DP[00]_M2C_n
set_property PACKAGE_PIN D39    [ get_ports HTG_Z920_HPC_PCIe_Rx_p[7]]; ## { IN  } FMC_PL_DP[00]_M2C_p
set_property PACKAGE_PIN Y35    [ get_ports HTG_Z920_HPC_PCIe_Tx_n[0]]; ## { OUT } FMC_PL_DP[05]_C2M_n
set_property PACKAGE_PIN Y34    [ get_ports HTG_Z920_HPC_PCIe_Tx_p[0]]; ## { OUT } FMC_PL_DP[05]_C2M_p
set_property PACKAGE_PIN W37    [ get_ports HTG_Z920_HPC_PCIe_Tx_n[1]]; ## { OUT } FMC_PL_DP[06]_C2M_n
set_property PACKAGE_PIN W36    [ get_ports HTG_Z920_HPC_PCIe_Tx_p[1]]; ## { OUT } FMC_PL_DP[06]_C2M_p
set_property PACKAGE_PIN V35    [ get_ports HTG_Z920_HPC_PCIe_Tx_n[2]]; ## { OUT } FMC_PL_DP[04]_C2M_n
set_property PACKAGE_PIN V34    [ get_ports HTG_Z920_HPC_PCIe_Tx_p[2]]; ## { OUT } FMC_PL_DP[04]_C2M_p
set_property PACKAGE_PIN U37    [ get_ports HTG_Z920_HPC_PCIe_Tx_n[3]]; ## { OUT } FMC_PL_DP[07]_C2M_n
set_property PACKAGE_PIN U36    [ get_ports HTG_Z920_HPC_PCIe_Tx_p[3]]; ## { OUT } FMC_PL_DP[07]_C2M_p
set_property PACKAGE_PIN F35    [ get_ports HTG_Z920_HPC_PCIe_Tx_n[4]]; ## { OUT } FMC_PL_DP[03]_C2M_n
set_property PACKAGE_PIN F34    [ get_ports HTG_Z920_HPC_PCIe_Tx_p[4]]; ## { OUT } FMC_PL_DP[03]_C2M_p
set_property PACKAGE_PIN G37    [ get_ports HTG_Z920_HPC_PCIe_Tx_n[5]]; ## { OUT } FMC_PL_DP[02]_C2M_n
set_property PACKAGE_PIN G36    [ get_ports HTG_Z920_HPC_PCIe_Tx_p[5]]; ## { OUT } FMC_PL_DP[02]_C2M_p
set_property PACKAGE_PIN H35    [ get_ports HTG_Z920_HPC_PCIe_Tx_n[6]]; ## { OUT } FMC_PL_DP[01]_C2M_n
set_property PACKAGE_PIN H34    [ get_ports HTG_Z920_HPC_PCIe_Tx_p[6]]; ## { OUT } FMC_PL_DP[01]_C2M_p
set_property PACKAGE_PIN E37    [ get_ports HTG_Z920_HPC_PCIe_Tx_n[7]]; ## { OUT } FMC_PL_DP[00]_C2M_n
set_property PACKAGE_PIN E36    [ get_ports HTG_Z920_HPC_PCIe_Tx_p[7]]; ## { OUT } FMC_PL_DP[00]_C2M_p


