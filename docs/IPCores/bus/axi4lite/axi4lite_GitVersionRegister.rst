.. _IP/axi4lite_GitVersionRegister:
.. index::
   single: AXI4-Lite; axi4lite_GitVersionRegister

axi4lite_GitVersionRegister
###########################


Current version of this version Reg is `1`. Use this tcl script for Vivado synth-pre-tcl: [set_BuildVersion.tcl](/uploads/9fdf1898a1797857e11889134c5179d0/set_BuildVersion.tcl)

Interface
*********

Generics
========

:generic:`VERSION_FILE_NAME`
----------------------------

:Name:          ``xx``
:Type:          ``xxx``
:Default Value: — — — —
:Description:   Path to the Version-mem-file created by `set_BuildVersion.tcl`. Relative to ``constant MY_PROJECT_DIR``
                in ``src/PoC/my_project.vhdl``


:generic:`HEADER_FILE_NAME`
---------------------------

:Name:          ``xx``
:Type:          ``xxx``
:Default Value: — — — —
:Description:   If csv-file with all register spaces is needed, put here the name/path of csv-file. Relative to
                ``constant MY_PROJECT_DIR`` in ``src/PoC/my_project.vhdl``


:generic:`INCLUDE_XIL_DNA`
--------------------------

:Name:          ``xx``
:Type:          ``xxx``
:Default Value: — — — —
:Description:   Includes Xilinx-DNA-Port. Working for 7-Series and US/US+ Devices. Note: 7-Series has 32 times this
                "unique" ID.


:generic:`INCLUDE_XIL_USR_EFUSE`
--------------------------------

:Name:          ``xx``
:Type:          ``xxx``
:Default Value: — — — —
:Description:   Includes Usr-EFuse. {-Currently not Implemented-}


:generic:`USER_ID`
------------------

:Name:          ``xx``
:Type:          ``xxx``
:Default Value: — — — —
:Description:   96bit ID, which can be set through PL in synthesis.


Ports
=====

.. todo:: Describe AXI4-Lite ports.


Register Map
************

All registers are read-only. Version Register should always start with offset ``0x80000000`` (First PL Address).

.. tip::

   The version register should be the first address in the address space (e.g., ``0x8000_0000``), thus a software can
   check what PL firmware is active and if this firmware is compatible to the currently running software version.

| Offset | Name | Description |
|---------|-------|----------|
| 0x000 | Common.BuildDate                        | 31:24 Day <br> 23:16 Month <br> 15:0 Year |
| 0x004 | Common.NumberModule_VersionOfVersionReg | 31:8 Reserved <br> 7:0 Version-of-Version-Reg (`1`) |
| 0x008 | Common.VivadoVersion                    | 31:16 Major <br> 15:8 Minor <br> 7:0 Patch |
| 0x00C | Common.ProjektName                      | ``String`` Project-Name (20Byte) |
| 0x020 | Top.Version                             | 31:24 Major <br> 23:16 Minor <br> 15:8 Patch <br> 7:2 Commits-to-Tag(dev-build) <br> 1 Dirty_untracked <br> 0 Dirty_modified |
| 0x024 | Top.GitHash                             | Git-Hash 20Bytes. Endianess is reversed in the registers. The order of the registers is reversed as well. |
| 0x038 | Top.GitDate                             | Commit-Date: 31:24 Day <br> 23:16 Month <br> 15:0 Year |
| 0x03C | Top.GitTime                             | Commit-Time: 31:24 Hour <br> 23:16 Min <br> 15:8 Sec <br> 7:0 Time-Zone as signed|
| 0x040 | Top.BranchName_Tag                   | Branch-Name 64Byte |
| 0x080 | Top.GitURL                           | Git-URL starting after ``gitlab.plc2.de/`` (128Byte) |
| 0x100 | UID.UID                              | Only present if ``INCLUDE_XIL_DNA`` is enabled (16Byte) <br> For US/US+ lower 96bit valid, for Series-7 64bit valid |
| 0x110 | UID.User_eFuse                          | Only present if ``INCLUDE_XIL_USR_EFUSE`` is enabled |
| 0x114 | UID.User_ID                          | 96-bit User_ID set by PL |

Files
*****

Current implementations gives these *.csv and converted *.h files:
* [Version_Register.csv](/uploads/2f25caea1127e08aa8a2306504199476/Version_Register.csv)
* [Version_Register.h](/uploads/58cae3f86d3ab4da98094b09a6d9ae39/Version_Register.h)
