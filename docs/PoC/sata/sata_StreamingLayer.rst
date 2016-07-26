
sata_StreamingLayer
###################

Executes ATA commands.
Automatically issues an "identify device" when the SATA Controller is
idle after power-up or reset.
If initial or requested IDENTIFY DEVICE failed, then FSM stays in error state.
Either *_ERROR_IDENTIFY_DEVICE_ERROR or *_ERROR_DEVICE_NOT_SUPPORTED are
signaled. To leave this state, apply one of the following:
- assert synchronous reset for whole SATA stack, or
- issue *_CMD_IDENTIFY_DEVICE.
If the Transport Layer encounters a fatal error, then FSM stays in error
state and *_ERROR_TRANSPORT_ERROR is signaled. To leave this state assert
synchronous reset for whole SATA stack.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_StreamingLayer.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 61-131

Source file: `sata/sata_StreamingLayer.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/sata/sata_StreamingLayer.vhdl>`_


	 