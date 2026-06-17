.. _NS/ocram:

PoC.mem.ocram
=============

The namespace ``PoC.mem.ocram`` offers different on-chip RAM abstractions.

**Package**

The package PoC.mem.ocram holds all component declarations for this namespace.

.. code-block:: VHDL

   library PoC;
   use     PoC.ocram.all;


**Entities**

 * :ref:`IP/ocram_SinglePort` - An on-chip RAM with a single port interface.
 * :ref:`IP/ocram_SimpleDualPort` - An on-chip RAM with a simple dual-port interface.
 * :ref:`IP/ocram_SimpleDualPort_wf` - An on-chip RAM with a simple dual-port
   interface and write-first behavior.
 * :ref:`IP/ocram_TrueDualPort` - An on-chip RAM with a true dual-port interface.
 * :ref:`IP/ocram_TrueDualPort_wf` - An on-chip RAM with a true dual-port
   interface and write-first behavior.

**Simulation Helper**

 * :ref:`IP/ocram_TrueDualPort_sim` - Simulation model of on-chip RAM with a true dual port interface.

**Deprecated Entities**

 * :ref:`IP/ocram_esdp` - An on-chip RAM with an extended simple dual port interface.


.. toctree::
   :hidden:

   Package <ocram.pkg>

.. toctree::
   :hidden:

   ocram_SinglePort <ocram_SinglePort>
   ocram_SimpleDualPort <ocram_SimpleDualPort>
   ocram_SimpleDualPort_wf <ocram_SimpleDualPort_wf>
   ocram_TrueDualPort <ocram_TrueDualPort>
   ocram_TrueDualPort_wf <ocram_TrueDualPort_wf>

.. toctree::
   :hidden:

   ocram_TrueDualPort_sim <ocram_TrueDualPort_sim>

.. toctree::
   :hidden:

   ocram_esdp <ocram_esdp>
