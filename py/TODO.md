# Python Infrastructure - TODO List

## Version 1.x

#### ArgParse
  - generate a better help page
      - deterministic order
      - wider columns
  - create better sub command help pages
	
## Version 1.1

#### Configuration process
  - create a my_project.vhdl after configuration

#### Improved *.files files
  - add path statement
  - concat paths and constants
  - allow paths in library and exists expressions
  - error reporting from parser

#### PrintTree()
  - a generic function to print trees with additional information

#### Complete commands
  - `list-testbench`
  - `list-netlist`
  - `list-ipcore`
	- print results as tree (default) or list

#### All flows
  - don't rmdir a temp directory, write a purge function
  - create a custom my_config.vhdl in temp/<simulator>/ if a device is specified
	- DryRun option

#### All simulators
	- disable OverallReport if GUI mode is enabled
	
#### QuestaSim / ModelSim
  - disable `-vopt` if *ModelSim Altera Edition* is used

#### All compilers
  - OverallReport on completion
  
#### Incomplete features:
  - pre-compiled vendor libraries

## Open features
  - Attache solutions and projects to PoC
      - for IP core imports
      - for using PoC infrastructure on project files / testbenches / ...
      - create-solution / import-solution / remove-solution
      - create-project / remove-project
      - add-ipcore / remove-ipcore
      - set-default-project
  - IP core import into vendor tools
      - Altera Quartus
      - Xilinx ISE
          - incl. UCF files
      - Xilinx Vivado
          - incl. XDC files
  - updates via Git
  - PoSh auto completion
  - PoSh drives (tb:)
  - calculate compile order of VHDL files
  
## Vendor tool support
  - Aldec Active-HDL
      - GUI mode for simulations

  - Cadence Incisive
  - Mentor Precision-RTL
  - Synopsys Symplify
      
  - Xilinx Vivado
      - CoreGenerator
