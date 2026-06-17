.. _IP/arith_PRNG:

PoC.arith.PRNG
##############

.. only:: html

   .. |gh-src| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/src/arith/arith_PRNG.vhdl
               :alt: Source Code on GitHub
   .. |gh-tb| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/tb/arith/arith_PRNG_tb.vhdl
               :alt: Source Code on GitHub

   .. sidebar:: GitHub Links

      * |gh-src| :pocsrc:`Sourcecode <arith/arith_PRNG.vhdl>`
      * |gh-tb| :poctb:`Testbench <arith/arith_PRNG_tb.vhdl>`

This module implementes a Pseudo-Random Number Generator (PRNG) with
configurable bit count (``BITS``). This module uses an internal list of FPGA
optimized polynomials from 3 to 168 bits. The polynomials have at most 5 tap
positions, so that long shift registers can be inferred instead of single
flip-flops.

The generated number sequence includes the value all-zeros, but not all-ones.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/arith/arith_PRNG.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 46-57



.. only:: latex

   Source file: :pocsrc:`arith/arith_PRNG.vhdl <arith/arith_PRNG.vhdl>`
