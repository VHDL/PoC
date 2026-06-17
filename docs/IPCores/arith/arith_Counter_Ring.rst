.. _IP/arith_Counter_Ring:

PoC.arith.counter_ring
######################

.. only:: html

   .. |gh-src| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/src/arith/arith_Counter_Ring.vhdl
               :alt: Source Code on GitHub
   .. |gh-tb| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/tb/arith/arith_Counter_Ring_tb.vhdl
               :alt: Source Code on GitHub

   .. sidebar:: GitHub Links

      * |gh-src| :pocsrc:`Sourcecode <arith/arith_Counter_Ring.vhdl>`
      * |gh-tb| :poctb:`Testbench <arith/arith_Counter_Ring_tb.vhdl>`

This module implements an up/down ring-counter with loadable initial value
(``seed``) on reset. The counter can be configured to a Johnson counter by
enabling ``INVERT_FEEDBACK``. The number of counter bits is configurable with
``BITS``.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/arith/arith_Counter_Ring.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 41-54



.. only:: latex

   Source file: :pocsrc:`arith/arith_Counter_Ring.vhdl <arith/arith_Counter_Ring.vhdl>`
