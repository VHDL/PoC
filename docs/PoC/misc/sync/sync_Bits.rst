
sync_Bits
#########

This module synchronizes multiple flag bits from clock-domain ``Clock1`` to
clock-domain ``Clock``. The clock-domain boundary crossing is done by two
synchronizer D-FFs. All bits are independent from each other. If a known
vendor like Altera or Xilinx are recognized, a vendor specific
implementation is choosen.

.. ATTENTION::
   Use this synchronizer only for long time stable signals (flags).

CONSTRAINTS:
	General:
		Please add constraints for meta stability to all '_meta' signals and
		timing ignore constraints to all '_async' signals.

	Xilinx:
		In case of a Xilinx device, this module will instantiate the optimized
		module PoC.xil.SyncBits. Please attend to the notes of xil_SyncBits.vhdl.

	Altera sdc file:
		TODO


Entity Declaration:
~~~~~~~~~~~~~~~~~~~

.. literalinclude:: ../../../../src/misc/sync/sync_Bits.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 60-71

	 
	 