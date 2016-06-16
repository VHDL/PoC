
sata_TransceiverLayer
#####################

Asynchronous signals: PowerDown, ClockNetwork_Reset, ClockNetwork_ResetDone
Transceiver In/Outputs: VSS_*
All other signals are synchronous to SATA_Clock.
The transceiver asserts ResetDone when his Command-Status-Error
interface is ready after powerup or asynchronous reset. It is only
deasserted in case of powerdown or asynchronous reset, if supported by
the transceiver. SATA_Clock_Stable is asserted at least one cycle before
ResetDone is asserted. All upper layers must be hold in reset as long as
ResetDone is deasserted.
SATA_Clock might go instable (SATA_Clock_Stable low) during change of
SATA generation. ResetDone is kept asserted because Status and Error are
still valid but are not changing until the SATA_Clock is stable again.
The transceiver has its own internal reset procedure. Synchronous reset
via input Reset is an optional feature.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_TransceiverLayer.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 69-123

Source file: `sata/sata_TransceiverLayer.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/sata/sata_TransceiverLayer.vhdl>`_


 
