.. _IP/arith_Prefix_Or:

PoC.arith.prefix_or
###################

.. only:: html

   .. |gh-src| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/src/arith/arith_Prefix_Or.vhdl
               :alt: Source Code on GitHub
   .. |gh-tb| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/tb/arith/arith_Prefix_Or_tb.vhdl
               :alt: Source Code on GitHub

   .. sidebar:: GitHub Links

      * |gh-src| :pocsrc:`Sourcecode <arith/arith_Prefix_Or.vhdl>`
      * |gh-tb| :poctb:`Testbench <arith/arith_Prefix_Or_tb.vhdl>`

Prefix OR computation:
``y(i) <= '0' when x(i downto 0) = (i downto 0 => '0') else '1';``
This implementation uses carry chains for wider implementations.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/arith/arith_Prefix_Or.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 43-51



.. only:: latex

   Source file: :pocsrc:`arith/arith_Prefix_Or.vhdl <arith/arith_Prefix_Or.vhdl>`
