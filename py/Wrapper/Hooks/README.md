# PoC Hook Files

This folder contains "hook files", which are sourced:
  - before (`PreHookFile`) and
  - after (`PostHostFile`)
a PoC command gets executed with `poc.[sh|ps1]`. A common use case is the preparation
of special vendor or tool chain environments. E.g. many EDA tools are using FlexLM
as a license manager, which needs the environments variable `LM_LICENSE_FILE` to be
set. A `PreHookFile` can be used to load/export such a variable.


## Hook Files

The `poc.[sh.ps1]` wrapper scripts scans the argument list for a known command. If such
a command is found, a pre- and post load event is triggered for a vendor hook file and a
tool hook file.


#### Example Mentor QuestaSim on Linux:

The PoC Infrastructure is called with this command line:

```Bash
./poc.sh -v vsim PoC.arith.prng
```

The `vsim` command is recognized and the following events are scheduled:

  1. ./Mentor.pre.sh
  2. ./Mentor.QuestaSim.pre.sh
  3. running `./py/PoC.py -v vsim PoC.arith.prng`
  4. ./Mentor.QuestaSim.post.sh
  5. ./Mentor.post.sh

If a hook files doesn't exist, its skipped.


#### Example Mentor QuestaSim on Windows:

The PoC Infrastructure is called with this command line:

```PowerShell
.\poc.ps1 -v vsim PoC.arith.prng
```

The `vsim` command is recognized and the following events are scheduled:

  1. .\Mentor.pre.ps1
  2. .\Mentor.QuestaSim.pre.ps1
  3. running `.\py\PoC.py -v vsim PoC.arith.prng`
  4. .\Mentor.QuestaSim.post.ps1
  5. .\Mentor.post.ps1

If a hook files doesn't exist, its skipped.
