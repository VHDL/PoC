
sata_LinkLayer
##############

Represents the Link Layer of the SATA stack and provides a logical link for
transmitting frames. The frames are transmitted across the physical link
provided by the Physical Layer (sata_PhysicalLayer).
The SATA Transport Layer and Link layer are connected via the TX_* path for
sending frames and RX_* path for receiving frames. Success or failure of a
transmission is indicated via the frame state FIFOs TX_FS_* and RX_FS_* for
each direction, respectivly.
As defined in Serial ATA Revision 3.0, section 9.4.4:
- Receiving DMAT is handled as R_IP.
- DMAT is not send.
Does not support dummy scrambling of TX primitives.


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/sata/sata_LinkLayer.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 61-119


	 