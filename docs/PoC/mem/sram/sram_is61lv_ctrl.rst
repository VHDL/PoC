
sram_is61lv_ctrl
################

Controller for IS61LV Asynchronous SRAM.

Tested with SRAM: IS61LV25616AL

This component provides the :doc:`PoC.Mem </References/Interfaces/Memory>`
interface for the user application.


Configuration
*************

+------------+-------------------------------------------+
| Parameter  | Description                               |
+============+===========================================+
| A_BITS     | Number of address bits (word address).    |
+------------+-------------------------------------------+
| D_BITS     | Number of data bits (of the word).        |
+------------+-------------------------------------------+
| SDIN_REG   | Generate register for sram_data on input. |
+------------+-------------------------------------------+

.. NOTE::
   While the register on input from the SRAM chip is optional, all outputs
   to the SRAM are registered as normal. These output registers should be
   placed in an IOB on an FPGA, so that the timing relationship is
   fulfilled.


Operation
*********

Regarding the user application interface, more details can be found
:doc:`here </References/Interfaces/Memory>`.

The outer design must connect GND ('0') to the SRAM chip enable ``ce_n``.

When using an IS61LV25616: the SRAM byte enables ``lb_n`` and ``ub_n`` must be
connected to ``sram_be_n(0)`` and ``sram_be_n(1)``, respectively.

Synchronous reset is used.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../../src/mem/sram/sram_is61lv_ctrl.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 97-123

Source file: `mem/sram/sram_is61lv_ctrl.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/mem/sram/sram_is61lv_ctrl.vhdl>`_



