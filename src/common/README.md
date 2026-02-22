# Namespace `PoC`

The namespace `PoC` offers common packages.

## Packages

 -  [`PoC.config`][config] - implements PoC's configuration mechanism.
 -  [`PoC.components`][components] - implements synthesizable functions
    that map to common gates and flip-flops.
 -  [`PoC.debug`][debug]
 -  [`PoC.fileio`][fileio]
 -  [`PoC.math`][math] - implements special mathematical functions.
 -  [`PoC.physical`][physical] - implements new physical types like frequency
    `FREQ`, baudrate and memory. Various type conversion functions are
    provided, too. 
 -  [`PoC.strings`][strings] - implements string operations on strings of fixed size.
 -  [`PoC.utils`][utils] - implements common helper functions
 -  [`PoC.vectors`][vectors] - declares multi-dimensional vector types and
    implements conversion functions for these types. 

**Usage:**

```VHDL

use work.config.all;
use work.debug.all;
use work.fileio.all;       -- If supported by the vendor tool
use work.math.all;
use work.physical.all;
use work.strings.all;
use work.utils.all;
use work.vectors.all;
```


## Context

[`PoC.common`][common] offers a VHDL-2008 context for all common PoC packages.


## Templates

 - [`PoC.my_config`][my_config]
 - [`PoC.my_project`][my_project]


 [config]:			config.vhdl
 [components]:	components.vhdl
 [debug]:				debug.vhdl
 [fileio]:			fileio.vhdl
 [math]:				math.vhdl
 [physical]:		physical.vhdl
 [strings]:			strings.vhdl
 [utils]:				utils.vhdl
 [vectors]:			vectors.vhdl

 [common]:			common.vhdl

 [my_config]:		my_config.vhdl.template
 [my_project]:	my_project.vhdl.template
