# Namespace `PoC.xil.mig`

The namespace `PoC.xil.mig` offers pre-configured memory controllers generated
with Xilinx's Memory Interface Generator (MIG).


## Entities

  - for Spartan-6 boards:
      - [`mig_Atlys_1x128`][mig_Atlys_1x128] A DDR2 memory controller for the Digilent Atlys board
        Run PoC's netlist compiler tool twice:
         1. generate the source files from the IP core using Xilinx MIG and afterwards patch them
         2. compile them into a read to use netlist (*.ngc)
         ```
         PS> .\netlist.ps1 --coregen PoC.xil.mig.Atlys_1x128.1 -l --board Atlys
         PS> .\netlist.ps1 --xst PoC.xil.mig.Atlys_1x128.2 -l --board Atlys
         ```
  - for Kintex-7 boards:
      - ...
  - for Virtex-7 boards:
      - ...

 [mig.pkg]:										mig.pkg.vhdl

 [mig_Atlys_1x128]:						mig_Atlys_1x128.xco
