.. _IP/arith_Shifter_Barrel:

PoC.arith.Shifter_Barrel
########################

.. only:: html

   .. |gh-src| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/src/arith/arith_Shifter_Barrel.vhdl
               :alt: Source Code on GitHub
   .. |gh-tb| image:: /_static/logos/GitHub-Mark-32px.png
               :scale: 40
               :target: https://github.com/VHDL/PoC/blob/master/tb/arith/arith_Shifter_Barrel_tb.vhdl
               :alt: Source Code on GitHub

   .. sidebar:: GitHub Links

      * |gh-src| :pocsrc:`Sourcecode <arith/arith_Shifter_Barrel.vhdl>`
      * |gh-tb| :poctb:`Testbench <arith/arith_Shifter_Barrel_tb.vhdl>`

This Barrel-Shifter supports:

* shifting and rotating
* right and left operations
* arithmetic and logic mode (only valid for shift operations)

This is equivalent to the CPU instructions: SLL, SLA, SRL, SRA, RL, RR



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/arith/arith_Shifter_Barrel.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 45-57



.. only:: latex

   Source file: :pocsrc:`arith/arith_Shifter_Barrel.vhdl <arith/arith_Shifter_Barrel.vhdl>`
