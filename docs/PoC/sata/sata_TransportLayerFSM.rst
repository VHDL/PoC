
sata_TransportLayerFSM
######################

See notes on module 'sata_TransportLayer'.
The Clock might be only unstable in the FSM state ST_RESET.
During Power-up or a ClockNetwork_Reset this unit is hold in the
reset state ST_RESET due to MyReset = '1'.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_TransportLayerFSM.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 52-102


	 