
sata_PhysicalLayerFSM
#####################

FSM for module "sata_PhysicalLayer".
Commmand-Status-Error interface is described in that module.
The Clock might be only unstable in the states ST_RESET and
ST_*_RECONFIG_WAIT. This is accomplished by:
a) During Power-up or a ClockNetwork_Reset this unit is hold in the
   reset state ST_RESET due to Trans_ResetDone = '0'. The OOB Controller is
   reseted too.
b) During reconfiguration, this FSM waits in one of the ST_*_RECONFIG_WAIT
   states. Asserting Trans_RP_ConfigReloaded is only permitted
	  after the clock is stable again.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_PhysicalLayerFSM.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 59-95

Source file: `sata/sata_PhysicalLayerFSM.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/sata/sata_PhysicalLayerFSM.vhdl>`_


	 