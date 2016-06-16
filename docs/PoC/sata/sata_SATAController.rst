
sata_SATAController
###################

Provides the SATA Transport Layer to transfer ATA commands and data from host to
device and vice versa.
Reset Procedure:
----------------
The SATAController automatically powers up, if inputs PowerDown and
ClockNetwork_Reset are low. The SATAController synchronously asserts
ResetDone when his Command-Status-Error interface is ready after power-up.
It is only deasserted asynchronously in case of asynchronously asserting
PowerDown or ClockNetwork_Reset, but both are optional features.
All upper layers must be hold in reset as long as ResetDone is deasserted.
The output SATA_Clock_Stable is synchronously asserted if the output
SATA_Clock delivers a stable clock signal, so it can be used as clock
enable. SATA_Clock_Stable is hight at least one cycle before ResetDone
is asserted.
SATA_Clock_Stable might be deasserted synchronously when a change of the
SATA generation is needed and SATA_Clock is instable for a while. ResetDone
is kept asserted because Status and Error are still valid but are not
changing until the SATA_Clock is stable again. The inputs Command and
(synchronous) Reset are ignored when SATA_Clock_Stable is low.
ClockNetwork_ResetDone is asserted asynchronously when all internal clock
networks are stable. This signal can be used for debugging or if another
PLL/DLL is connected to SATA_Clock.
Command:
-------
Commands are only accepted when Status.TransportLayer is
*_TRANS_STATUS_IDLE, *_TRANS_STATUS_TRANSFER_OK or
*_TRANS_STATUS_TRANSFER_ERROR.
Command = *_SATACTRL_CMD_TRANSFER:
  Transfer and execute ATA command provided by input ATAHostRegisters.
  Completes with Status.TransportLayer:
  - *_TRANS_STATUS_TRANSFER_OK if successful. New commands can be applied
    	directly.
  - *_TRANS_STATUS_TRANSFER_ERROR if the device reports an error via the ATA
  		register block. New commands can be applied directly.
  - *_TRANS_STATUS_ERROR if a fatal error occurs. In this case at least a
  		synchronous reset must be applied.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_SATAController.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 91-156

Source file: `sata/sata_SATAController.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/sata/sata_SATAController.vhdl>`_


 
