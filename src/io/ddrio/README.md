# Namespace `PoC.io.ddrio`

The namespace `PoC.io.ddrio` offers components for dual-data-rate (DDR) input
and output of data. It uses the DDR flip flops in the FPGA
I/O buffers, if available. PoC has two platform specific
implementations for Altera and Xilinx, which are chosen, if the
appropriate `MY_DEVICE` is configured in [`my_config.vhdl`][my_config].
 

## Package(s)

The package [`PoC.ddrio`][ddrio.pkg] holds all component declarations for this namespace.


## Entities

#### Dual-Data-Rate Input

The module [`ddrio_In`][ddrio_In] captures the input data at the pad
with both edges of the clock. The data captured with the falling edge
is again synchronized to the rising edge, so that both data parts are
provided for the internal logic with the rising edge of the clock.

It's possible to configure the width of the data bus as well as the
initialization state provided for the internal logic. The vendor specific
implementations are named [`ddrio_In_Altera`][ddrio_In_Altera] and
[`ddrio_In_Xilinx`][ddrio_In_Xilinx] respectively.

See the ASCII art inside the [VHDL description][ddrio_In] for more
details on how data to is sampled at the pad.


#### Dual-Data-Rate Output

The module [`ddrio_Out`][ddrio_Out] brings out the ouput data at the pad
with both edges of the clock. The data is sampled from the internal logic
with the rising edge only.

It's possible to configure the width of the data bus as well as the
initialization state of the value present at the pad. The output
driver can be disabled by a synchronous control signal. This control
signal can be removed by a parameter to save some logic. The vendor specific
implementations are named [`ddrio_Out_Altera`][ddrio_Out_Altera] and
[`ddrio_Out_Xilinx`][ddrio_Out_Xilinx] respectively.

See the ASCII art inside the [VHDL description][ddrio_Out] for more
details on how data to is driven at the pad.


#### Dual-Data-Rate Input and Output

The module [`ddrio_InOut`][ddrio_InOut] is combination of the DDR
input and DDR output functionality described above. Two different
clocks are available for the input side and the output side.

It's possible to configure the width of the data bus, but not the 
initialization state due to a limitation of the Altera specific
implementation. The vendor specific implementations are named
[`ddrio_InOut_Altera`][ddrio_InOut_Altera] and 
[`ddrio_InOut_Xilinx`][ddrio_InOut_Xilinx] respectively.

See the ASCII art inside the [VHDL description][ddrio_InOut] for more
details on how data to is sampled and driven at the pad.


 [my_config]:						../../common/my_config.vhdl.template
 [ddrio.pkg]:						ddrio.pkg.vhdl
 [ddrio_In]:						ddrio_In.vhdl
 [ddrio_In_Altera]:			ddrio_In_Altera.vhdl
 [ddrio_In_Xilinx]:			ddrio_In_Xilinx.vhdl
 [ddrio_InOut]:					ddrio_InOut.vhdl
 [ddrio_InOut_Altera]:	ddrio_InOut_Altera.vhdl
 [ddrio_InOut_Xilinx]:	ddrio_InOut_Xilinx.vhdl
 [ddrio_Out]:						ddrio_Out.vhdl
 [ddrio_Out_Altera]:		ddrio_Out_Altera.vhdl
 [ddrio_Out_Xilinx]:		ddrio_Out_Xilinx.vhdl
