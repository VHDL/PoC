
xil_Reconfigurator
##################

	Many complex primitives in a Xilinx device offer a Dynamic Reconfiguration
	Port (DRP) to reconfigure the primitive at runtime without reconfiguring then
	whole FPGA.
	This module is a DRP master that can be preconfigured  at compile time with
	different configuration sets. The configuration sets are mapped into a ROM.
	The user can select a stored configuration with 'ConfigSelect' and sending a
	strobe to 'Reconfig'. The Operation completes with an other strobe on
	'ReconfigDone'.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/xil/xil_Reconfigurator.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 50-71


	 