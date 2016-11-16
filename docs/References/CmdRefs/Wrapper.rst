
PoC Wrapper Scripts
###################

The PoC main program :program:`PoC.py` requires a prepared environment, which
needs to be setup by platform specific wrapper scripts written as shell
scripts language (PowerShell/Bash). Moreover, the main program requires a
supported Python version, so the wrapper script will search the best matching
language environment.

The wrapper script offers the ability to hook in user-defined scripts to prepared
(before) and clean up the environment (after) a PoC execution. E.g. it's possible
to load the environment variable :envvar:`LM_LICENSE_FILE` for the FlexLM license
manager.


.. rubric:: Created Environment Variables

.. envvar:: PoCRootDirectory

   The path to PoC's root directory.


poc.ps1
========

.. program:: poc.ps1

.. option:: -D

   Enabled debug mode in the wrapper script.


poc.sh
======

.. program:: poc.sh

.. option:: -D

   Enabled debug mode in the wrapper script.
