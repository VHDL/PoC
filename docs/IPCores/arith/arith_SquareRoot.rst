.. _IP/arith_SquareRoot:

PoC.arith.SquareRoot
####################

.. only:: html

   .. |gh-src| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/src/arith/arith_SquareRoot.vhdl
               :alt: Source Code on GitHub
   .. |gh-tb| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/tb/arith/arith_SquareRoot_tb.vhdl
               :alt: Source Code on GitHub

   .. sidebar:: GitHub Links

      * |gh-src| :pocsrc:`Sourcecode <arith/arith_SquareRoot.vhdl>`
      * |gh-tb| :poctb:`Testbench <arith/arith_SquareRoot_tb.vhdl>`

Iterative Square Root Extractor.

Its computation requires (N+1)/2 steps for an argument bit width of N.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/arith/arith_SquareRoot.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 38-55



.. only:: latex

   Source file: :pocsrc:`arith/arith_SquareRoot.vhdl <arith/arith_SquareRoot.vhdl>`
