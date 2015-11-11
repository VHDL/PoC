OS-VVM - Open Source VHDL Verification Methodology
==================================================

**Copyright:**	Copyright © 2012-2015 by [SynthWorks Design Inc.](http://www.synthworks.com/)  
**License:**	[Artistic License 2.0](ARTISTIC2.0)  
**Download:**	[http://www.osvvm.org][1]

## About OS-VVM

[**Open Source VHDL Verification Methodology (OS-VVM)**][1] is an intelligent testbench methodology that allows mixing of “Intelligent Coverage” (coverage driven randomization) with directed, algorithmic, file based, and constrained random test approaches. The methodology can be adopted in part or in whole as needed. With OSVVM you can add advanced verification methodologies to your current testbench without having to learn a new language or throw out your existing testbench or testbench models.

Like other verification languages, it is all about methodology. OSVVM simplifies verification methodology to the following steps.

Write a high fidelity functional coverage (FC) model
Randomly select holes in the functional coverage (aka “Intelligent Coverage”)
Refine the initial randomization using sequential VHDL code
OSVVM is based on a set of open source (free) packages: CoveragePkg for functional coverage and “Intelligent Coverage”, and RandomPkg for constrained random (CR) utilities. These packages offer a similar capability and conciseness to the syntax of other verification languages (such as SystemVerilog or ‘e’). Going further, “Intelligent Coverage” is a leap ahead of what other verification languages provide. Since it is package based, it is easier to update than language syntax.

##### Benefits:
Faster simulations due to removing redundancies in CR stimulus generation.
Faster development due to removing redundancies between modeling FC and CR.
Less cost. Packages are free. Works with basic simulation licenses.
Vendor independent and works on any VHDL-2008 simulator (VHDL-2002 with some adaptations).

**CoveragePkg** package supports generation of bins for one-dimensional and cross-coverage, collection of coverage data and reporting. Those features alone are quite attractive, but the greatest advantage of this package is the ability of controlling random stimulus based on running coverage results. Thanks to this feature users can create intelligent test environments that achieve complete coverage much faster than in other languages.

**RandomPkg** package supports generation of random numbers in various formats (real, integer, signed or unsigned vectors) with various distributions (Uniform, Normal, Poisson, etc.) and with various constraints (ranges, exclusions, weights, etc.)

Source: [http://osvvm.org/about-os-vvm](http://osvvm.org/about-os-vvm)

 [1]: http://osvvm.org/
 