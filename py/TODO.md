# Python Infrastructure - TODO List

## Features ideas

  - updates via Git
  - PoSh auto completion
  - PoSh drives (tb:)
  - calculate compile order of VHDL files
	- extract VHDL file embedded help/comments via Python for Sphinx autodoc

## Vendor Tool Support
  - Aldec Active-HDL
      - GUI mode for simulations

  - Cadence Incisive
  - Mentor Precision-RTL
  - Synopsys Symplify
      
  - Xilinx Vivado
      - CoreGenerator
	
## Version 1.x

#### ArgParse
  - generate a better help page
      - deterministic order
      - wider columns
  - create better sub command help pages
	
#### Attache solutions and projects to PoC

  - for IP core imports
  - for using PoC infrastructure on project files / testbenches / ...
  - create-solution / import-solution / remove-solution
  - create-project / remove-project
  - add-ipcore / remove-ipcore
  - set-default-project
	
#### IP core import into vendor tools
  - Altera Quartus
	    - incl. SDC files
  - Xilinx ISE
      - incl. UCF files
  - Xilinx Vivado
      - incl. XDC files
	
## Version 1.1

#### Configuration process
  - create a my_project.vhdl after configuration

#### Improved *.files files
  - error reporting from parser

#### PrintTree()
  - a generic function to print trees with additional information

#### Complete commands
  - `list-testbench`
  - `list-netlist`
  - `list-ipcore`
	- print results as tree (default) or list

#### All flows
  - create a custom my_config.vhdl in temp/<simulator>/ if a device is specified
	- DryRun option

#### All simulators
	- disable OverallReport if GUI mode is enabled
	
#### QuestaSim / ModelSim
  - disable `-vopt` if *ModelSim Altera Edition* is used

#### GHDL
  - pass waveform file via testbench object
	
#### All compilers
  - OverallReport on completion
	- Check if board/device matches tool flow
  
#### Incomplete features:
  - pre-compiled vendor libraries
