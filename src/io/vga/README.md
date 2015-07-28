VGA modules overview

VGA output could be devided into 4 steps:

1. Generate VGA timing.
2. Access Video RAM.
3. (optional) Post-process Color data, such as palette indexing.
4. Physical layer: Registered output of VGA signals. Or control of
   off-chip PHY.

Control signals for the physical layer, such as H-Sync and V-Sync,
must be pipelined through the particular modules so that control and
data signals are always in sync. The "vga" package defines a record
"VGA_PHY_CTRL_TYPE" combining all necessary signals.

The following modules are provided:

 - Step 1:  
    vga_timing		Timing for 640x480

 - Step 2:  
    vga_testcard3_data	Generates testcard data for 3-Bit per pixel (8 colors).

 - Step 3:  
    <none yet>

 - Step 4:  
    vga_phy   			Drives VGA signal outputs, includes blanking.  
    vga_ch7301c_ctrl	Controller for external CH7301C DVI transmitter.  
    vga_ch7301c_init	IIC init sequence for   CH7301C DVI transmitter.  
    vga_sil1172_ctrl	Controller for external SIL1172 DVI transmitter.

 - Step 1-3:  
    vga_testcard3		Complete testcard design including timing, and
  			data logic for a simple VGA test with 3-Bit
			per pixel (8 colors). Only a specific PHY must
			be still connected. 
