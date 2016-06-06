
sata_TransportLayer
###################

Provides transport of frames via SATA links for the Host endpoint.
Automatically awaits a Register Frame after the link has been established.
To initiate a new connection (later on), synchronously reset this layer and
the underlying SATAController at the same time.
Configuration
-------------
DEV_INIT_TIMEOUT:  Maximum time to wait for the initial register FIS after
  the link has been established. During this period, the device boots its
  firmware and may execute a (short) self diagnostic.
NODATA_RETRY_TIMEOUT: For ATA commands of category NO-DATA:
  a) maximum time to transmit register FIS (ATA command) to the device,
     including necessary retries, as well as
  b) maximum time to wait for a correct register FIS (ATA command completion
     status) from the device after it was once corrupted  (e.g. CRC error).
  Note: This timeout does not cover the execution time of the ATA command
  required by the device (time between a) and b) defined above). This is because
  the execution time highly depends on the ATA command and drive
  characteristics. A FLUSH CACHE might complete in some seconds, a (full)
  DRIVE DIAGNOSTICS may take several minutes.
DATA_READ_TIMEOUT: Maximum time to wait for a data FIS and the final
  register FIS from the device during reads (PIO or DMA).
DATA_WRITE_TIMEOUT: Maximum time to wait until device is ready to receive
  data as well as maximum time to wait for final register FIS from device
  during writes (PIO or DMA).
CSE Interface:
--------------
New commands are accepted when Status is *_STATUS_IDLE, *_STATUS_TRANSFER_OK
or *_STATUS_TRANSFER_ERROR.
ATAHostHostRegisters must be applied with command *_CMD_TRANSFER.
After issuing a command, status means:
*_STATUS_TRANSFER_OK:    Transfer completed with no error.
*_STATUS_TRANSFER_ERROR: Transfer completed with error bit in ATA register set.
*_STATUS_ERROR: 					Fatal error occured. Synchronous reset of whole
													SATA stack must be applied.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_TransportLayer.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 89-160


	 