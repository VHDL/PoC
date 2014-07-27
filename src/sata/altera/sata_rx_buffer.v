
module sata_rx_buffer (
	clk_wr,
	en_wr,
	data_wr,
	high_wr,
	low_wr,
	full_wr,
	empty_wr,
	
	clk_rd,
	en_rd,
	data_rd,
	high_rd,
	low_rd,
	full_rd,
	empty_rd);

	input clk_wr;
	input en_wr;
	input [36:0] data_wr;
	output high_wr;
	output low_wr;
	output full_wr;
	output empty_wr;
	
	input clk_rd;
	input en_rd;
	output reg [36:0] data_rd;
	output high_rd;
	output low_rd;
	output full_rd;
	output empty_rd;
	
	reg [2:0] cnt_rd_clkwr;
	reg [2:0] cnt_wr_clkrd;

	(* ramstyle = "logic" *)
	reg [36:0] rx_buffer [7:0];

	wire [2:0] cnt_rd;
	wire [2:0] cnt_wr;
	
	wire read;
	wire write;

	assign read = ~empty_rd & en_rd;
	assign write = ~full_wr & en_wr;

	always @ (posedge clk_wr) begin
		if (write) begin
			rx_buffer[cnt_wr] <= data_wr;
		end
	end

	always @ (posedge clk_rd) begin
		if (read) begin
			data_rd <= rx_buffer[cnt_rd];
		end
	end

	always @ (posedge clk_wr) cnt_rd_clkwr <= cnt_rd;
	always @ (posedge clk_rd) cnt_wr_clkrd <= cnt_wr;

	gray_counter read_counter (
		.clk(clk_rd),
		.inc(read),
		.cnt(cnt_rd));

	gray_counter write_counter (
		.clk(clk_wr),
		.inc(write),
		.cnt(cnt_wr));

	gray_comparator read_comp (
		.cnt_wr(cnt_wr_clkrd),
		.cnt_rd(cnt_rd),
		.high(high_rd),
		.low(low_rd),
		.full(full_rd),
		.empty(empty_rd));

	gray_comparator write_comp (
		.cnt_wr(cnt_wr),
		.cnt_rd(cnt_rd_clkwr),
		.high(high_wr),
		.low(low_wr),
		.full(full_wr),
		.empty(empty_wr));

endmodule
