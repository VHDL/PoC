
What is PoC?
************

PoC - "Pile of Cores" provides implementations for often required hardware functions such as FIFOs, RAM wrapper, and ALUs. The hardware modules are typically
provided as VHDL or Verilog source code, so it can be easily re-used in a variety of hardware designs.

.. rubric:: The PoC-Library has the following goals:

* independenability
* generics implementations
* efficient, resource 'schonend' and fast implementations
* optimized for several target architectures if suitable

.. rubric:: PoC's independancies:

* platform independenability on the host system: Darwin, Linux or Windows
* target independenability on the device target: ASIC or FPGA
* vendor independenability on the device vendor: Altera, Lattice, Xilinx, ...
* tool chain independenability for simulation and synthesis tool chains
