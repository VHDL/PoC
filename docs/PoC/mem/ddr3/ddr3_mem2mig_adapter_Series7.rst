
ddr3_mem2mig_adapter_Series7
############################

Simplifies the application interface ("app") of the Xilinx MIG IP core.
The "mem" interface provides single-cycle fully pipelined read/write access
to the memory. All accesses are word-aligned. Always all bytes of a word are
written to the memory.

Generic parameters:

* D_BITS: Data bus width of the "mem" and "app" interface. Also size of one
  word in bits.

* DQ_BITS: Size of data bus between memory controller and external memory
  (DIMM, SoDIMM).

* MEM_A_BITS: Address bus width of the "mem" interface.

* APP_A_BTIS: Address bus width of the "app" interface.

Containts only combinational logic.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../../src/mem/ddr3/ddr3_mem2mig_adapter_Series7.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 58-91

Source file: `mem/ddr3/ddr3_mem2mig_adapter_Series7.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/mem/ddr3/ddr3_mem2mig_adapter_Series7.vhdl>`_



