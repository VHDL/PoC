.. _IP/axi4lite_GitVersionRegister:
.. index::
   single: AXI4-Lite; axi4lite_GitVersionRegister

axi4lite_GitVersionRegister
###########################

Current version of this version Reg is `1`. Use this tcl script for Vivado synth-pre-tcl: [set_BuildVersion.tcl](/uploads/9fdf1898a1797857e11889134c5179d0/set_BuildVersion.tcl)

Based on :ref:`IP/axi4lite_Register`


.. _IP/axi4lite_GitVersionRegister/goals:

.. topic:: Design Goals

   * Provide all information as read-only data.
   * Gather tool external information (Git information, data/time, ...) via pre-TCL script.
   * Integrate vendor and device specific information.


.. _IP/axi4lite_GitVersionRegister/features:

.. topic:: Features

   * Provide all data read-only via AXI4-Lite interface.
   * Provide project information.

     * Project name.
     * Version

   * Provide build information.

     * Build data and time.
     * Build tool chain

   * Provide Git environment information.

     * Commit data and time.
     * Commit hash
     * Reference (branch or tag)
     * Repository URL

   * Provide device unique information

     * AMD/Xilinx: E-Fuse bits (32 bits)
     * AMD/Xilinx: DNA bits (64 or 96 bits)
     * AMD/Xilinx: User bitstream bits (32 bits)

   * Provide user defined read-only word

     * User-defined 32-bits


.. _IP/axi4lite_GitVersionRegister/instantiation:

Instantiation
*************

.. _IP/axi4lite_GitVersionRegister/inst/Simple:

Simple Register
===============

.. grid:: 2

   .. grid-item::
      :columns: 5

      .. todo:: needs documentation

   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         Version : entity PoC.axi4lite_GitVersionRegister
         port map (
           Clock        => Clock,
           Reset        => Reset,

           AXI4Lite_m2s => VersionRegister_m2s,
           AXI4Lite_s2m => VersionRegister_s2m
         );

.. _IP/axi4lite_GitVersionRegister/inst/Xilinx:

AMD/Xilinx Extensions
=====================

.. grid:: 2

   .. grid-item::
      :columns: 5

      .. todo:: needs documentation

   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         Version : entity PoC.axi4lite_GitVersionRegister
         generic map (
           INCLUDE_XIL_DNA       => true,
           INCLUDE_XIL_USR_EFUSE => true
         )
         port map (
           Clock        => Clock,
           Reset        => Reset,

           AXI4Lite_m2s => VersionRegister_m2s,
           AXI4Lite_s2m => VersionRegister_s2m
         );


.. _IP/axi4lite_GitVersionRegister/interface:

Interface
*********

.. _IP/axi4lite_GitVersionRegister/generics:

Generics
========

.. _IP/axi4lite_GitVersionRegister/gen/VERSION_FILE_NAME:

:generic:`VERSION_FILE_NAME`
----------------------------

:Name:          :generic:`VERSION_FILE_NAME`
:Type:          :type:`string`
:Default Value: — — — —
:Description:   Path to the Version-mem-file created by `set_BuildVersion.tcl`. Relative to ``constant MY_PROJECT_DIR``
                in ``src/PoC/my_project.vhdl``


.. _IP/axi4lite_GitVersionRegister/gen/HEADER_FILE_NAME:

:generic:`HEADER_FILE_NAME`
---------------------------

:Name:          :generic:`HEADER_FILE_NAME`
:Type:          :type:`string`
:Default Value: — — — —
:Description:   If csv-file with all register spaces is needed, put here the name/path of csv-file. Relative to
                ``constant MY_PROJECT_DIR`` in ``src/PoC/my_project.vhdl``


.. _IP/axi4lite_GitVersionRegister/gen/INCLUDE_XIL_DNA:

:generic:`INCLUDE_XIL_DNA`
--------------------------

:Name:          :generic:`INCLUDE_XIL_DNA`
:Type:          :type:`boolean`
:Default Value: — — — —
:Description:   Includes Xilinx-DNA-Port. Working for 7-Series and US/US+ Devices. Note: 7-Series has 32 times this
                "unique" ID.


.. _IP/axi4lite_GitVersionRegister/gen/INCLUDE_XIL_USR_EFUSE:

:generic:`INCLUDE_XIL_USR_EFUSE`
--------------------------------

:Name:          :generic:`INCLUDE_XIL_USR_EFUSE`
:Type:          :type:`boolean`
:Default Value: — — — —
:Description:   Includes Usr-EFuse. :red:`Currently not Implemented`


.. _IP/axi4lite_GitVersionRegister/gen/USER_ID:

:generic:`USER_ID`
------------------

:Name:          :generic:`USER_ID`
:Type:          :type:`std_logic_vector(31 downto 0)`
:Default Value: — — — —
:Description:   96bit ID, which can be set through PL in synthesis.


.. _IP/axi4lite_GitVersionRegister/ports:

Ports
=====

.. _IP/axi4lite_GitVersionRegister/port/Clock:

:port:`Clock`
-------------

:Name:          ``Clock``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/axi4lite_GitVersionRegister/port/Reset:

:port:`Reset`
-------------

:Name:          ``Reset``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/axi4lite_GitVersionRegister/port/AXI4Lite_m2s:

:port:`AXI4Lite_m2s`
--------------------

:Name:          ``AXI4Lite_m2s``
:Type:          ``axi4lite.T_AXI4Lite_Bus_m2s``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/axi4lite_GitVersionRegister/port/AXI4Lite_s2m:

:port:`AXI4Lite_s2m`
--------------------

:Name:          ``AXI4Lite_s2m``
:Type:          ``axi4lite.T_AXI4Lite_Bus_s2m``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/axi4lite_GitVersionRegister/configuration:

Configuration
*************

.. _IP/axi4lite_GitVersionRegister/config/User:

User defined Word
=================

.. todo:: tbd


.. _IP/axi4lite_GitVersionRegister/RegisterMap:

Register Map
************

All registers are read-only. Version Register should always start with offset ``0x80000000`` (First PL Address).

.. tip::

   The version register should be the first address in the address space (e.g., ``0x8000_0000``), thus a software can
   check what PL firmware is active and if this firmware is compatible to the currently running software version.

+--------+-----------------------------------------+-------------------------------------------------------------------+
| Offset | Name                                    | Description                                                       |
+========+=========================================+===================================================================+
| 0x000  | Common.BuildDate                        | 31:24 Day |br| 23:16 Month |br| 15:0 Year                         |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x004  | Common.NumberModule_VersionOfVersionReg | 31:8 Reserved |br| 7:0 Version-of-Version-Reg (``1``)             |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x008  | Common.VivadoVersion                    | 31:16 Major |br| 15:8 Minor |br| 7:0 Patch                        |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x00C  | Common.ProjektName                      | ``String`` Project-Name (20 bytes)                                |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x020  | Top.Version                             | 31:24 Major |br| 23:16 Minor |br| 15:8 Patch |br|                 |
|        |                                         | 7:2 Commits-to-Tag(dev-build) |br| 1 Dirty_untracked |br|         |
|        |                                         | 0 Dirty_modified                                                  |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x024  | Top.GitHash                             | Git-Hash 20Bytes. Endianess is reversed in the registers. The     |
|        |                                         | order of the registers is reversed as well.                       |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x038  | Top.GitDate                             | Commit-Date: 31:24 Day |br| 23:16 Month |br| 15:0 Year            |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x03C  | Top.GitTime                             | Commit-Time: 31:24 Hour |br| 23:16 Min |br| 15:8 Sec |br|         |
|        |                                         | 7:0 Time-Zone as signed                                           |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x040  | Top.BranchName_Tag                      | Branch-Name 64Byte                                                |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x080  | Top.GitURL                              | Git-URL starting after ``gitlab.plc2.de/`` (128Byte)              |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x100  | UID.UID                                 | Only present if ``INCLUDE_XIL_DNA`` is enabled (16Byte) |br|      |
|        |                                         | For US/US+ lower 96 bit valid, for Series-7 64 bit valid          |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x110  | UID.User_eFuse                          | Only present if ``INCLUDE_XIL_USR_EFUSE`` is enabled              |
+--------+-----------------------------------------+-------------------------------------------------------------------+
| 0x114  | UID.User_ID                             | 96-bit User_ID set by PL                                          |
+--------+-----------------------------------------+-------------------------------------------------------------------+

.. _IP/axi4lite_GitVersionRegister/Driver:

Driver
******

Bare Metal
==========

.. todo:: needs to be documented

Linux Kernel Driver
===================

.. attention:: under development


.. _IP/axi4lite_GitVersionRegister/RelatedFiles:

Related Files
*************

Current implementations gives these *.csv and converted *.h files:

* Version_Register.csv
* Version_Register.h
