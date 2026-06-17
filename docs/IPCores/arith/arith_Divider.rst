.. _IP/arith_Divider:

PoC.arith.Divider
#############

.. only:: html

   .. |gh-src| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/src/arith/arith_Divider.vhdl
               :alt: Source Code on GitHub
   .. |gh-tb| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/tb/arith/arith_Divider_tb.vhdl
               :alt: Source Code on GitHub

   .. sidebar:: GitHub Links

      * |gh-src| :pocsrc:`Sourcecode <arith/arith_Divider.vhdl>`
      * |gh-tb| :poctb:`Testbench <arith/arith_Divider_tb.vhdl>`

Implementation of a Non-Performing restoring divider with a configurable radix.
The multi-cycle division is controlled by 'start' / 'rdy'. A new division is
started by asserting 'start'. The result Q = A/D is available when 'rdy'
returns to '1'. A division by zero is identified by output Z. The Q and R
outputs are undefined in this case.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/arith/arith_Divider.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 38-61



.. only:: latex

   Source file: :pocsrc:`arith/arith_Divider.vhdl <arith/arith_Divider.vhdl>`
