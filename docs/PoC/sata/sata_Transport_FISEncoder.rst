
sata_FISEncoder
###############

See notes on module 'sata_TransportLayer'.
Status:
-------
*_RESET: 								Link_Status is not yet IDLE.
*_IDLE:									Ready to send new FIS.
*_SENDING: 							Sending FIS.
*_SEND_OK:								FIS transmitted and acknowledged with R_OK  by other end.
*_SEND_ERROR:						FIS transmitted and acknowledged with R_ERR by other end.
*_SYNC_ESC:							Sending aborted by SYNC.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_Transport_FISEncoder.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 55-95


	 