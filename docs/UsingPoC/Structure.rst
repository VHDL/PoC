
Structure
#########

Root Directory
**************

The PoC-Library is structured into several sub-directories, naming the purpose
of the directory like ``src`` for sources files or ``tb`` for testbench files.
The structure within these directories is always the same and based on PoC's
:doc:`sub-namespace tree </PoC/index>`

**Main directory overview:**

* ``lib`` - Embedded or linked external libraries.
* ``netlist`` - Configuration files and output directory for
* pre-configured netlist synthesis results from vendor IP cores or from complex PoC controllers.
* ``py`` - Supporting Python scripts.
* ``sim`` - Pre-configured waveform views for selected testbenches.
* ``src`` - PoC's source files grouped into sub-folders according to the [sub-namespace tree][wiki:subnamespacetree].
* ``tb`` - Testbench files.
* ``tcl`` - Tcl files.
* ``temp`` - A created temporary directors for various tools used by PoC's Python scripts.
* ``tools`` - Settings/highlighting files and helpers for supported tools.
* ``ucf`` - Pre-configured constraint files (\*.ucf, \*.xdc, \*.sdc) for supported FPGA boards.
* ``xst`` - Configuration files to synthesize PoC modules with Xilinx XST into a netlist.



Mapping PoC Namespaces to Folders
*********************************




