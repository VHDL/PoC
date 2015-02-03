
module sata_rx_adapter (
	sata_gen,
	rx_clkin,
	rx_datain,
	rx_ctrlin,
	rx_errin,
	rx_clkout,
	rx_syncout,
	rx_dataout,
	rx_ctrlout);

	input [1:0] sata_gen;
	input rx_clkin;
	input [31:0] rx_datain;
	input [3:0] rx_ctrlin;
	input [3:0] rx_errin;
	input rx_clkout;
	output rx_syncout;
	output [31:0] rx_dataout;
	output [3:0] rx_ctrlout;

	reg rx_syncreg;

	wire rx_syncin;
	wire rx_outen;
	wire read;
	wire write;

	wire [31:0] data_wr;
	wire [31:0] data_rd;
	wire [3:0] ctrl_wr;
	wire [3:0] ctrl_rd;
	wire align_wr;
	wire align_rd;

	wire high_rd;
	wire low_rd;
	wire full_rd;
	wire empty_rd;
	wire high_wr;

	initial rx_syncreg <= 1'b0;
	always @ (posedge rx_clkout)
		rx_syncreg <= (rx_syncreg | (~high_rd & ~low_rd)) & rx_syncin & ~full_rd & ~empty_rd;
	
	assign read = ~(low_rd & align_rd);
	assign write = ~(high_wr & align_wr) & rx_outen;
	
	assign {rx_ctrlout,rx_dataout} = {ctrl_rd,data_rd};
	assign rx_syncout =  rx_syncreg;

	sata_rx_align align (
		.sata_gen(sata_gen),
		.rx_clkin(rx_clkin),
		.rx_datain(rx_datain),
		.rx_ctrlin(rx_ctrlin),
		.rx_errin(rx_errin),
		.rx_outen(rx_outen),
		.rx_syncout(rx_syncin),
		.rx_alignout(align_wr),
		.rx_dataout(data_wr),
		.rx_ctrlout(ctrl_wr));

	sata_rx_buffer buffer (
		.clk_wr(rx_clkin),
		.en_wr(write),
		.data_wr({align_wr,ctrl_wr,data_wr}),
		.high_wr(high_wr),
		.low_wr(),
		.full_wr(),
		.empty_wr(),
		.clk_rd(rx_clkout),
		.en_rd(read),
		.data_rd({align_rd,ctrl_rd,data_rd}),
		.high_rd(high_rd),
		.low_rd(low_rd),
		.full_rd(full_rd),
		.empty_rd(empty_rd));

endmodule
