.. index::
   single: Third-Party Libraries

.. _THIRD:

Third Party Libraries
#####################

The PoC-Library is shiped with different third party libraries, which are
located in the ``<PoCRoot>/lib/`` folder. This document lists all these
libraries, their websites and licenses.


.. # ===========================================================================================================================================================

.. index::
   pair: Third-Party Libraries; OSVVM

.. _THIRD/OSVVM:

OSVVM
*****

**Open Source VHDL Verification Methodology (OS-VVM)** is an intelligent
testbench methodology that allows mixing of “Intelligent Coverage” (coverage
driven randomization) with directed, algorithmic, file based, and constrained
random test approaches. The methodology can be adopted in part or in whole as
needed. With OSVVM you can add advanced verification methodologies to your
current testbench without having to learn a new language or throw out your
existing testbench or testbench models.

+----------------+---------------------------------------------------------------------------------------+
| **Folder:**    | ``<PoCRoot>\lib\osvvm\``                                                              |
+----------------+---------------------------------------------------------------------------------------+
| **Copyright:** | Copyright © 2012-2025 by `SynthWorks Design Inc. <http://www.synthworks.com/>`__      |
+----------------+---------------------------------------------------------------------------------------+
| **License:**   | :doc:`Apache License, 2.0 (local copy) </References/Licenses/ApacheLicense2.0>`       |
+----------------+---------------------------------------------------------------------------------------+
| **Website:**   | `http://osvvm.org/ <http://osvvm.org/>`__                                             |
+----------------+---------------------------------------------------------------------------------------+
| **Source:**    | `https://github.com/OSVVM/OSVVM <https://github.com/OSVVM/OSVVM>`__                   |
+----------------+---------------------------------------------------------------------------------------+


Updating Linked Git Submodules
******************************

The third party libraries are embedded as Git submodules. So if the PoC-Library
was not cloned with option ``--recursive`` it's required to run the sub-module
initialization manually:

On Linux
========

.. code-block:: Bash

   cd PoCRoot
   git submodule init
   git submodule update

We recommend to rename the default remote repository name from 'origin' to
'github'.

.. code-block:: Bash

   cd PoCRoot\lib\

.. todo:: write Bash code for Linux

On OS X
========

Please see the Linux instructions.

On Windows
==========


.. code-block:: PowerShell

   cd PoCRoot
   git submodule init
   git submodule update

We recommend to rename the default remote repository name from 'origin' to
'github'.

.. code-block:: PowerShell

   cd PoCRoot\lib\
   foreach($dir in (dir -Directory)) {
     cd $dir
     git remote rename origin github
     cd ..
   }

