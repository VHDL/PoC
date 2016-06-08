
sata_Physical_OOBControl_Host
#############################

Executes the COMRESET / COMINIT procedure.
If the clock is unstable, than Reset must be asserted.
Automatically tries to establish a communication when Reset is deasserted.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_Physical_OOBControl_Host.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 53-82

Source file: `sata/sata_Physical_OOBControl_Host.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/sata/sata_Physical_OOBControl_Host.vhdl>`_


	 