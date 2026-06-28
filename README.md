<!--- DO NOT EDIT! This file is generated from .tpl --->
# The PoC-Library

[![Sourcecode on GitHub](https://img.shields.io/badge/VHDL-PoC-63bf7f?longCache=true&style=flat-square&longCache=true&logo=GitHub)](https://GitHub.com/VHDL/PoC)
[![Sourcecode License](https://img.shields.io/badge/code-Apache%202.0-97CA00?longCache=true&style=flat-square&longCache=true&logo=Apache)](LICENSE.md)
[![Documentation](https://img.shields.io/website?longCache=true&style=flat-square&label=VHDL.github.io%2FPoC&logo=GitHub&logoColor=fff&up_color=blueviolet&up_message=Read%20now%20%E2%9E%9A&url=https%3A%2F%2FVHDL.github.io%2FPoC%2Findex.html)](https://VHDL.github.io/PoC/)
[![Documentation License](https://img.shields.io/badge/doc-CC--BY%204.0-green?longCache=true&style=flat-square&logo=CreativeCommons&logoColor=fff)](docs/Doc-License.rst)    
![Latest tag](https://img.shields.io/github/tag/VHDL/PoC.svg?style=flat)
[![Latest release](https://img.shields.io/github/release/VHDL/PoC.svg?style=flat)](https://github.com/VHDL/PoC/releases)

<!--
This library is published and maintained by **Chair for VLSI Design, Diagnostics and Architecture** - 
Faculty of Computer Science, Technische Universität Dresden, Germany 
**http://vlsi-eda.inf.tu-dresden.de**

![Technische Universität Dresden](https://github.com/VLSI-EDA/PoC/wiki/images/logo_tud.gif)
-->

Table of Content:
--------------------------------------------------------------------------------
 1. [Overview](#1-overview)
 2. [Quick Start Guide](#2-quick-start-guide)  
    2.1. [Requirements and Dependencies](#21-requirements-and-dependencies)  
    2.2. [Download](#22-download)  
    2.3. [Configuring PoC on a Local System](#23-configuring-poc-on-a-local-system)  
    2.4. [Integration](#24-integration)  
    2.5. [Updating](#25-updating)
 3. [Common Notes](#3-common-notes)
 4. [Cite the PoC-Library](#4-cite-the-poc-library)

--------------------------------------------------------------------------------

## 1 Overview

PoC - “Pile of Cores” provides implementations for often required hardware functions such as
Arithmetic Units, Caches, Clock-Domain-Crossing Circuits, FIFOs, RAM wrappers, and I/O Controllers.
The hardware modules are typically provided as VHDL or Verilog source code, so it can be easily
re-used in a variety of hardware designs.

All hardware modules use a common set of VHDL packages to share new VHDL types, sub-programs and
constants. Additionally, a set of simulation helper packages eases the writing of testbenches.
Because PoC hosts a huge amount of IP cores, all cores are grouped into sub-namespaces to build a
clear hierachy.

Various simulation and synthesis tool chains are supported to interoperate with PoC. To generalize
all supported free and commercial vendor tool chains, PoC is shipped with a Python based
infrastructure to offer a command line based frontend.


## 2 Quick Start Guide

This **Quick Start Guide** gives a fast and simple introduction into PoC. All topics can be found in
the [Using PoC][201] section at [VHDL.GitHub.io/PoC][202] with much more details and examples.


### 2.1 Requirements and Dependencies

The PoC-Library comes with some scripts to ease most of the common tasks, like running testbenches or
generating IP cores. PoC uses Python 3 as a platform independent scripting environment. All Python
scripts are wrapped in Bash or PowerShell scripts, to hide some platform specifics of Darwin, Linux or
Windows. See [Requirements][211] for further details.

[211]: http://VHDL.github.io/PoC/UsingPoC/Requirements.html


#### PoC requires:
 -  A [supported synthesis tool chain][2111], if you want to synthezise IP cores.
 -  A [supported simulator tool chain][2112], if you want to simulate IP cores.
 -  The **Python 3** programming language and runtime, if you want to use PoC's infrastructure.
 -  A shell to execute shell scripts:
    -  **Bash** on Linux and OS X
    -  **PowerShell** on Windows

[2111]: http://VHDL.github.io/PoC/WhatIsPoC/SupportedToolChains.html
[2112]: http://VHDL.github.io/PoC/WhatIsPoC/SupportedToolChains.html


#### PoC optionally requires:
 -  **Git command line** tools or
 -  **Git User Interface**, if you want to check out the latest 'master' or 'release' branch.


#### PoC depends on third part libraries:
  -  [OSVVM][2132]  
    Open Source VHDL Verification Methodology.
   
All dependencies are available as GitHub repositories and are linked to PoC as Git submodules into the
[`PoCRoot\lib`][205] directory. See [Third Party Libraries][206] for more details on these libraries.

[2132]: https://github.com/OSVVM/OSVVM

[201]: http://VHDL.github.io/PoC/UsingPoC/index.html
[202]: http://VHDL.github.io/PoC/
[205]: https://github.com/VHDL/PoC/tree/Vivado/lib
[206]: http://VHDL.github.io/PoC/Miscelaneous/ThirdParty.html


### 2.2 Download

The PoC-Library can be downloaded as a [zip-file][221] (latest 'Vivado' branch), cloned with `git clone`
or embedded with `git submodule add` from GitHub. GitHub offers HTTPS and SSH as transfer protocols. See
the [Download][222] page for further details. The installation directory is referred to as `PoCRoot`.

Protocol | Git Clone Command
-------- | :-----------------------------------------------------------
HTTPS    | `git clone --recursive https://github.com/VHDL/PoC.git PoC`
SSH      | `git clone --recursive ssh://git@github.com:VHDL/PoC.git PoC`

[221]: https://github.com/VHDL/PoC/archive/master.zip
[222]: http://VHDL.github.io/PoC/UsingPoC/Download.html

### 2.3 Configuring PoC on a Local System

To explore PoC's full potential, it's required to configure some paths and synthesis or simulation tool
chains. The following commands start a guided configuration process. Please follow the instructions on
screen. It's possible to relaunch the process at any time, for example to register new tools or to update
tool versions. See [Configuration][231] for more details.

> [!CAUTION]
> Outdated, needs refinement

[231]: http://VHDL.github.io/PoC/UsingPoC/PoCConfiguration.html

### 2.4 Integration

The PoC-Library is meant to be integrated into other HDL projects. Therefore it's recommended to create
a library folder and add the PoC-Library as a Git submodule. After the repository linking is done, some
short configuration steps are required to setup paths, tool chains and the target platform. The following
command line instructions show a short example on how to integrate PoC.

#### a) Adding the Library as a Git submodule

The following command line instructions will create the folder `lib\PoC\` and clone the PoC-Library as a
[Git submodule][2411] into that folder. `ProjectRoot` is the directory of the hosting Git. A detailed list
of steps can be found at [Integration][2412].

```powershell
cd ProjectRoot
mkdir lib | cd
git submodule add https://github.com:VHDL/PoC.git PoC
cd PoC
git remote rename origin github
cd ..\..
git add .gitmodules lib\PoC
git commit -m "Added new git submodule PoC in 'lib\PoC' (PoC-Library)."
```

[2411]: http://git-scm.com/book/en/v2/Git-Tools-Submodules
[2412]: http://VHDL.github.io/PoC/UsingPoC/Integration.html

#### b) Creating PoC's `project_configuration.vhdl` and `local_configuration.vhdl` Files

The PoC-Library needs two VHDL files for its configuration. These files are used to determine the most
suitable implementation depending on the provided target information. Copy the following two template
files into your project's source folder. Rename these files to \*.vhdl and configure the VHDL constants
in the files:

```powershell
cd ProjectRoot
cp lib\PoC\src\common\project_configuration.vhdl.template src\common\project_configuration.vhdl
cp lib\PoC\src\common\local_configuration.vhdl.template src\common\local_configuration.vhdl
```

[project_configuration.vhdl](https://github.com/VHDL/PoC/blob/Vivado/src/common/project_configuration.vhdl.template) defines
two global constants, which need to be adjusted:

```vhdl
constant MY_BOARD            : string := "CHANGE THIS"; -- e.g. Custom, ML505, KC705, Atlys
constant MY_DEVICE           : string := "CHANGE THIS"; -- e.g. None, XC5VLX50T-1FF1136, EP2SGX90FF1508C3
```

[local_configuration.vhdl](https://github.com/VHDL/PoC/blob/Vivado/src/common/local_configuration.vhdl.template) also
defines two global constants, which need to be adjusted:

```vhdl
constant LOCAL_PROJECT_DIR      : string := "CHANGE THIS"; -- e.g. d:/vhdl/myproject/, /home/me/projects/myproject/"
```

Further informations are provided at [Creating project_configuration/local_configuration.vhdl][2431].

[2431]: http://VHDL.github.io/PoC/UsingPoC/VHDLConfiguration.html

#### c) Adding PoC's Common Packages to a Synthesis or Simulation Project

PoC is shipped with a set of common packages, which are used by most of its modules. These packages are
stored in the `PoCRoot\src\common` directory. PoC also provides a VHDL context in `common.vhdl` , which
can be used to reference all packages at once.


#### d) Compiling Shipped IP Cores

Some IP Cores are shipped as pre-configured vendor IP Cores. If such IP cores shall be used in a HDL
project, it's recommended to use PoC to create, compile and if needed patch these IP cores. See
[Synthesis][2461] for more details.

[2461]: http://VHDL.github.io/PoC/UsingPoC/Synthesis.html


### 2.5 Updating

The PoC-Library can be updated by using `git fetch` and `git merge`.

```PowerShell
cd PoCRoot
# update the local repository
git fetch --prune
# review the commit tree and messages, using the 'treea' alias
git treea
# if all changes are OK, do a fast-forward merge
git merge
```

**See also:**
 -  [**Running one or more testbenches**][251]  
    The installation can be checked by running one or more of PoC's testbenches.
 -  [**Running one or more netlist generation flows**][252]  
    The installation can also be checked by running one or more of PoC's synthesis flows.

[251]: http://VHDL.github.io/PoC/UsingPoC/Simulation.html
[252]: http://VHDL.github.io/PoC/UsingPoC/Synthesis.html 


## 3. Common Notes

**The PoC-Library** is structured into several sub-folders naming the purpose of the folder like
[`src`](src) for sources files or [`tb`](tb) for testbench files. The structure within these folders
is always the same and based on PoC's sub-namespace tree.

**Main directory overview:**

 -  [`lib`](lib) - Embedded or linked external libraries.
 -  [`src`](src) - PoC's source files grouped into sub-folders according to the sub-namespace tree.
 -  [`tb`](tb) - Testbench files.
 -  [`temp`](temp) - Automatically created temporary directors for various tools used by PoC's Python scripts.
 -  [`tools`](tools) - Settings/highlighting files and helpers for supported tools.
 -  [`ucf`](ucf) - Pre-configured constraint files (\*.ucf, \*.xdc, \*.sdc) for supported FPGA boards.


All VHDL source files should be compiled into the VHDL library `PoC`. If not indicated otherwise, all
source files can be compiled using the VHDL-93 or VHDL-2008 language version. Incompatible files are
named `*.v93.vhdl` and `*.v08.vhdl` to denote the highest supported language version.


## 4 Cite the PoC-Library

If you are using the PoC-Library, please let us know. We are grateful for your project's reference.
The PoC-Library hosted at [GitHub.com](https://www.github.com). Please use the following
[biblatex](https://www.ctan.org/pkg/biblatex) entry to cite us:

```bibtex
# BibLaTex example entry
@online{poc,
  title={{PoC - Pile of Cores}},
  author={{Contributors of the Open Source VHDL Group}},
  organization={{OSVG}},
  year={2025},
  url={https://github.com/VHDL/PoC},
  urldate={2025-03-04},
}
```
