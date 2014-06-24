
module sata_tx_adapter (
	sata_gen,
	tx_datain,
	tx_ctrlin,
	tx_clkout,
	tx_dataout,
	tx_ctrlout);

	input [1:0] sata_gen;
	input [31:0] tx_datain;
	input [3:0] tx_ctrlin;
	input tx_clkout;
	output [31:0] tx_dataout;
	output [3:0] tx_ctrlout;

	reg [7:0] tx_datareg [3:0];
	reg [3:0] tx_ctrlreg;

	reg [1:0] counter;
	reg [1:0] sel0;
	reg [1:0] sel2;
	
	reg [1:0] sata_genreg;
	
	wire inen;

	assign tx_dataout = {tx_datareg[3],tx_datareg[sel2],tx_datareg[1],tx_datareg[sel0]};
	assign tx_ctrlout = {tx_ctrlreg[3],tx_ctrlreg[sel2],tx_ctrlreg[1],tx_ctrlreg[sel0]};
	assign inen = (counter == 2'b00) | sata_genreg[1];
	
	initial counter <= 2'b00;
	always @ (posedge tx_clkout) begin
		counter[0] <= ~counter[0] & ~sata_genreg[0];
		counter[1] <= counter[1] ^ (counter[0] | sata_genreg[0]);
		if (inen) begin
			tx_datareg[0] <= tx_datain[ 7: 0];
			tx_datareg[1] <= tx_datain[15: 8];
			tx_datareg[2] <= tx_datain[23:16];
			tx_datareg[3] <= tx_datain[31:24];
			tx_ctrlreg <= tx_ctrlin;
		end
		sel0 <= sata_genreg[1] ? 2'b00 : counter;
		sel2 <= sata_genreg[1] ? 2'b10 : {counter[1],1'b1};
	end
	
	initial sata_genreg <= 2'b10;
	always @ (posedge tx_clkout) sata_genreg <= sata_gen;
	
endmodule
