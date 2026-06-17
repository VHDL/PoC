.. _IP/arith_Prefix_And:

PoC.arith.prefix_and
####################

.. only:: html

   .. |gh-src| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/src/arith/arith_Prefix_And.vhdl
               :alt: Source Code on GitHub
   .. |gh-tb| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/tb/arith/arith_Prefix_And_tb.vhdl
               :alt: Source Code on GitHub

   .. sidebar:: GitHub Links

      * |gh-src| :pocsrc:`Sourcecode <arith/arith_Prefix_And.vhdl>`
      * |gh-tb| :poctb:`Testbench <arith/arith_Prefix_And_tb.vhdl>`

Prefix AND computation:
``y(i) <= '1' when x(i downto 0) = (i downto 0 => '1') else '0';``
This implementation uses carry chains for wider implementations.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/arith/arith_Prefix_And.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 43-51



.. only:: latex

   Source file: :pocsrc:`arith/arith_Prefix_And.vhdl <arith/arith_Prefix_And.vhdl>`
