
sata_PrimitiveDetector
######################

Detects primitives in the incoming data stream from the physical link. If
a primitive X is continued via the CONT primitive and scrambled dummy data,
this unit outputs X continously until a new primitve (except ALIGN) arrives.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_Link_PrimitiveDetector.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 44-53

Source file: `sata/sata_Link_PrimitiveDetector.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/sata/sata_Link_PrimitiveDetector.vhdl>`_


	 