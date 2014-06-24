
module gxb_calib (clk);
input clk;

stratixiigx_hssi_calibration_block cal_blk(
        .clk(clk),
        .powerdn(1'b1),
        .enabletestbus(1'b0),
        .calibrationstatus());
        
endmodule
