
# Python Infrastructure - TODO List

#### ArgParse
  - generate a better help page
      - deterministic order
      - wider columns
  - create better sub command help pages

#### Command: `list-testbench`
  - list testbenches as tree
  
#### Command `list-netlist`
  - list testbenches as tree

#### Command `list-ipcore`
  - list testbenches as tree

#### Command `vsim`:
  - disable `-vopt` if *ModelSim Altera Edition* is used
  
#### Incomplete features:
  - pre-compiled vendor libraries

#### MaxFailedAssertions
  - stop simulation if MaxFailedAssertions is reached

#### PrintTree function

## Version 1.1

#### Improved *.files files
  - add path statement
  - concat paths and constants
  - allow paths in library and exists expressions
  - error reporting from parser

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
