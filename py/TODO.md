
ArgParse
  - generate a better help page
      - deterministic order
      - wider columns
  - create better sub command help pages

Command all simulators:
  - print a report
  
Command list-testbench
  - --kind parameter
  - list testbenches as tree
  
Command list-netlist
  - --kind parameter
  - list testbenches as tree

Command vsim:
  - disable -vopt if Altera Edition is used
  
Command configure / setup ?
  - semi automatic configuration
  - support more vendor tools

Incomplete features:
  - pre-compiled vendor libraries
  
Open features
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
  
Vendor tool support
  - Aldec Active-HDL
      - GUI mode for simulations

  - Cadence Incisive
  - Mentor Precision-RTL
  - Synopsys Symplify
      
  - Xilinx Vivado
      - Synthesis
      - CoreGenerator



