.. _NS/ocrom:

PoC.mem.ocrom
=============

The namespace ``PoC.mem.ocrom`` offers different on-chip ROM abstractions.

**Package**

The package PoC.mem.ocrom holds all component declarations for this namespace.

.. code-block:: VHDL

   library PoC;
   use     PoC.ocrom.all;


**Entities**

 - :ref:`ocrom_SinglePort <IP/ocrom_SinglePort>` is a on-chip RAM with a single port interface.
 - :ref:`ocrom_DualPort <IP/ocrom_DualPort>` is a on-chip RAM with a dual port interface.


.. toctree::
   :hidden:

   Package <ocrom.pkg>

.. toctree::
   :hidden:

   ocrom_SinglePort <ocrom_SinglePort>
   ocrom_DualPort <ocrom_DualPort>
