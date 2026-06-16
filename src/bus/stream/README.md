# Namespace `PoC.bus.stream`

The namespace `PoC.bus.stream` offers different modules for the *PoC.Stream* interface.

> [!IMPORTANT]  
> *PoC.Stream* components will be replaced by *AXI4-Stream* components.
> 

## Package

The package [`PoC.stream`][stream.pkg] holds all component declarations for this namespace.


## Entities

 - [`stream_DeMux`][stream_DeMux] a generic de-multiplexer implementation.
 - [`stream_FIFO`][stream_FIFO] a generic stream buffer/FIFO implementation.
 - [`stream_FrameGenerator`][stream_FrameGenerator]
 - [`stream_Mirror`][stream_Mirror] a generic stream-mirror implementation.
 - [`stream_Mux`][stream_Mux] a generic multiplexer implementation.
 - [`stream_Source`][stream_Source] a generic data source for simulation.


 [stream.pkg]:				stream.pkg.vhdl

 [stream_DeMux]:            stream_DeMux.vhdl
 [stream_FIFO]:             stream_FIFO.vhdl
 [stream_FrameGenerator]:   stream_FrameGenerator.vhdl
 [stream_Mirror]:           stream_Mirror.vhdl
 [stream_Mux]:              stream_Mux.vhdl
 [stream_Source]:           stream_Source.vhdl
