
sata_PhysicalLayer
##################

Represents the PhysicalLayer of the SATA stack. Detects if a device is
present and establishes a communication, both using OOB.
Clock might be unstable as defined in module sata_PhysicalLayerFSM.
After Power-Up or a ClockNetwork_Reset (indicated by Trans_ResetDone = '0')
this layer automatically tries to establish a communication with speed
negotiation. A device is detected by indefinitly polling using OOB COMRESET.
The result is indicated by output Status:
Status can be one of the following:
- SATA_PHY_STATUS_RESET: 					PhysicalLayer is resetting.
- SATA_PHY_STATUS_NODEVICE: 				No device detected yet.
- SATA_PHY_STATUS_NOCOMMUNICATION: Device detected, but communication not
																		yet established.
- SATA_PHY_STATUS_COMMUNICATING:		Device detected and communication
																		established.
- SATA_PHY_STATUS_ERROR:						See output Error.
It is guaranteed, that after SATA_PHY_STATUS_COMMUNICATING is signaled,
the clock is stable (i.e. no reconfiguration) until a Command or a global
Reset/PowerDown/ClockNetwork_Reset is applied.
Error can be one of the following:
- SATA_PHY_ERROR_NONE: 				No error.
- SATA_PHY_ERROR_LINK_DEAD: 		Received OOB sequences after link was
																established. Resetting this stack on behalf
																of receiving COMRESET is not yet supported.
- SATA_PHY_ERROR_NEGOTIATION:	Speed negotiation failed.
Commands are only accepted when Status is SATA_PHY_STATUS_COMMUNICATING or
SATA_PHY_STATUS_ERROR. Possible Commands are:
- SATA_PHY_CMD_NONE: 							Do nothing.
- SATA_PHY_CMD_INIT_CONNECTION: 		Init connection with speed negotiation.
- SATA_PHY_CMD_REINIT_CONNECTION: 	Reinit connection at same speed.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_PhysicalLayer.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 81-138

Source file: `sata/sata_PhysicalLayer.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/sata/sata_PhysicalLayer.vhdl>`_


	 