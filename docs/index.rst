.. include:: shields.inc

.. raw:: latex

   \part{Introduction}

.. #
   This library is published and maintained by **Chair for VLSI Design, Diagnostics
   and Architecture** - Faculty of Computer Science, Technische Universität Dresden,
   Germany |br|
   `https://tu-dresden.de/ing/informatik/ti/vlsi <https://tu-dresden.de/ing/informatik/ti/vlsi>`_

.. only:: html

   .. image:: /_static/logos/tu-dresden.jpg
      :scale: 10
      :alt: Technische Universität Dresden

.. only:: latex

   .. image:: /_static/logos/tu-dresden.jpg
      :scale: 80
      :alt: Technische Universität Dresden

--------------------------------------------------------------------------------

.. only:: html

   |SHIELD:svg:PoC-github| |SHIELD:svg:PoC-src-license| |SHIELD:svg:PoC-ghp-doc| |SHIELD:svg:PoC-doc-license|


.. only:: latex

   |SHIELD:png:PoC-github| |SHIELD:png:PoC-src-license| |SHIELD:png:PoC-ghp-doc| |SHIELD:png:PoC-doc-license|


The PoC-Library Documentation
#############################

PoC - "Pile of Cores" provides implementations for often required hardware
functions such as Arithmetic Units, Caches, Clock-Domain-Crossing Circuits,
FIFOs, RAM wrappers, and I/O Controllers. The hardware modules are typically
provided as VHDL or Verilog source code, so it can be easily re-used in a
variety of hardware designs.

All hardware modules use a common set of VHDL packages to share new VHDL types,
sub-programs and constants. Additionally, a set of simulation helper packages
eases the writing of testbenches. Because PoC hosts a huge amount of IP cores,
all cores are grouped into sub-namespaces to build a better hierachy.

Various simulation and synthesis tool chains are supported to interoperate with
PoC. To generalize all supported free and commercial vendor tool chains, PoC is
shipped with a Python based infrastructure to offer a command line based frontend.


.. only:: html

   News
   ****

.. only:: latex

   .. rubric:: News

.. attention:: v3.0.0

   .. rublic:: Planned Additions

   * AXI4 multiplexer / demultiplexer
   * AXI4-Lite multiplexer / demultiplexer

   .. rublic:: Planned Changes

   * Rename branch ``master`` to ``main```
   * Restructure AXI4 subdirectories.
   * Whitespace fixes.
   * ``axi4lite_VersionRegister``

     * Reworked memory layout
     * Linux driver

.. admonition:: v2.3.0

   * New AXI4-Lite devices

     * ``axi4lite_BlockRAMAdapter``
     * ``axi4lite_DRPdapter``
     * ``axi4lite_UART``
     * ``axi4lite_HRClock``

   * Documentation updates
   * More OSVVM-based testcases

.. admonition:: v2.2.0

   * Documentation updates
   * More OSVVM-based testcases

.. admonition:: v2.1.0

   * :ref:`IP/axi4lite_GitVersionRegister`

.. admonition:: v2.0.0

   * :ref:`IP/axi4lite_Register`
   * :ref:`NS/axi4` namespace: 2 packages, 5 entities
   * :ref:`NS/axi4lite` namespace: 2 packages, 3 entities
   * :ref:`NS/axi4stream` namespace: 1 package, 7 entities


.. attention::

   In **Feb. 2025**, The PoC-Library was forked to the VHDL namespace at GitHub, which is operated by the Open-Source
   VHDL Group (OSVG). It's planned to update The PoC-Library (new features, bug fixes, etc) as well as removing some
   burdens like Xilinx ISE support.

   In **July 2025**, the changes made, upcoming changes as well as a roadmap will be presented at
   `FPGA Conference Europe 2025 <https://www.fpga-conference.eu/>`__ in Munich. Besides general PoC updates, a first
   AXI4-Lite IP core will be release to The PoC-Library.

See :ref:`Change Log <CHANGE>` for latest updates.


.. only:: html

   Cite the PoC-Library
   ********************

.. only:: latex

   .. rubric:: Cite the PoC-Library

The PoC-Library hosted at `GitHub.com <https://www.github.com>`_. Please use the
following `biblatex <https://www.ctan.org/pkg/biblatex>`_ entry to cite us:

.. code-block:: tex

   # BibLaTex example entry
   @online{poc,
     title={{PoC - Pile of Cores}},
     author={{Contributors of the Open Source VHDL Group}},
     organization={{OSVG}},
     year={2025},
     url={https://github.com/VHDL/PoC},
     urldate={2025-03-04},
   }


.. toctree::
   :caption: Introduction
   :hidden:

   WhatIsPoC/index
   QuickStart
   GetInvolved/index
   References/Licenses/License
   References/Licenses/Doc-License


.. raw:: latex

   \part{General}

.. toctree::
   :caption: General
   :hidden:

   UsingPoC/index
   Interfaces/index
   Miscelaneous/ThirdParty
   ConstraintFiles/index
   ToolChains/index
   Examples/index

.. raw:: latex

   \part{IP Cores}

.. toctree::
   :caption: IP Cores
   :hidden:

   PoC.alt.* <IPCores/alt/index>
   PoC.arith.* <IPCores/arith/index>
   PoC.bus.* <IPCores/bus/index>
   PoC.cache.* <IPCores/cache/index>
   PoC.comm.* <IPCores/comm/index>
   PoC.dstruct.* <IPCores/dstruct/index>
   PoC.fifo.* <IPCores/fifo/index>
   PoC.io.* <IPCores/io/index>
   PoC.mem.* <IPCores/mem/index>
   PoC.misc.* <IPCores/misc/index>
   PoC.net.* <IPCores/net/index>
   PoC.sort.* <IPCores/sort/index>
   PoC.sync.* <IPCores/sync/index>
   PoC.xil.* <IPCores/xil/index>

.. raw:: latex

   \part{Packages}

.. toctree::
   :caption: Packages
   :hidden:

   PoC.components <IPCores/common/components>
   PoC.context <IPCores/common/context>
   PoC.config <IPCores/common/config>
   PoC.fileio <IPCores/common/fileio>
   PoC.math <IPCores/common/math>
   PoC.strings <IPCores/common/strings>
   PoC.utils <IPCores/common/utils>
   PoC.vectors <IPCores/common/vectors>

.. raw:: latex

   \part{References and Reports}

.. toctree::
   :caption: References and Reports
   :hidden:

   unittests/index
   References/CommandReference
   References/Database
   PyInfrastructure/index
   More ... <References/more>

.. raw:: latex

   \part{Appendix}

.. toctree::
   :caption: Appendix
   :hidden:

   ChangeLog/index
   Glossary
   genindex

.. ifconfig:: visibility in ('PoCInternal')

   .. raw:: latex

      \part{Main Internal}

   .. toctree::
      :caption: Internal
      :hidden:

      Internal/ToDo
      Internal/Sphinx
