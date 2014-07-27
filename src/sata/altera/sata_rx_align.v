
module sata_rx_align (
	sata_gen,
	rx_clkin,
	rx_datain,
	rx_ctrlin,
	rx_errin,
	rx_outen,
	rx_syncout,
	rx_alignout,
	rx_dataout,
	rx_ctrlout);

	input [1:0] sata_gen;
	input rx_clkin;
	input [31:0] rx_datain;
	input [3:0] rx_ctrlin;
	input [3:0] rx_errin;
	output rx_outen;
	output rx_syncout;
	output rx_alignout;
	output [31:0] rx_dataout;
	output [3:0] rx_ctrlout;

	reg [55:0] rx_datareg;
	reg [6:0] rx_ctrlreg;
	reg [3:0] rx_alignreg;

	reg [1:0] counter;
	reg [1:0] sample;

	reg [1:0] sata_genreg;
	
	wire [3:0] align;
	wire error;

	assign align[0] = (rx_datareg[31: 0] == 32'h7B4A4ABC) & (rx_ctrlreg[3:0] == 4'b0001);
	assign align[1] = (rx_datareg[39: 8] == 32'h7B4A4ABC) & (rx_ctrlreg[4:1] == 4'b0001);
	assign align[2] = (rx_datareg[47:16] == 32'h7B4A4ABC) & (rx_ctrlreg[5:2] == 4'b0001);
	assign align[3] = (rx_datareg[55:24] == 32'h7B4A4ABC) & (rx_ctrlreg[6:3] == 4'b0001);

	assign error = rx_errin[0] |
		rx_errin[1] & sata_genreg[1] |
		rx_errin[2] & sata_genreg[0] |
		rx_errin[2] & sata_genreg[1] |
		rx_errin[3] & sata_genreg[1];

	assign rx_outen = (counter == sample) | sata_genreg[1];
	assign rx_syncout = (rx_alignreg != 4'b0000);
	assign rx_alignout = (align != 4'b0000);

	assign rx_dataout =
		rx_alignreg[0] ? rx_datareg[31: 0] :
		rx_alignreg[1] ? rx_datareg[39: 8] :
		rx_alignreg[2] ? rx_datareg[47:16] :
		rx_alignreg[3] ? rx_datareg[55:24] :
		32'h00000000;

	assign rx_ctrlout =
		rx_alignreg[0] ? rx_ctrlreg[3:0] :
		rx_alignreg[1] ? rx_ctrlreg[4:1] :
		rx_alignreg[2] ? rx_ctrlreg[5:2] :
		rx_alignreg[3] ? rx_ctrlreg[6:3] :
		4'b0000;

	always @ (posedge rx_clkin) begin
		if (sata_genreg[1]) begin
			rx_datareg <= {rx_datain, rx_datareg[55:32]};
			rx_ctrlreg <= {rx_ctrlin, rx_ctrlreg[6:4]};
		end else if (sata_genreg[0]) begin
			rx_datareg <= {16'h0000, rx_datain[23:16], rx_datain[7:0], rx_datareg[39:16]};
			rx_ctrlreg <= {2'b00, rx_ctrlin[2], rx_ctrlin[0], rx_ctrlreg[4:2]};
		end else begin
			rx_datareg <= {24'h000000, rx_datain[7:0], rx_datareg[31:8]};
			rx_ctrlreg <= {3'b000, rx_ctrlin[0], rx_ctrlreg[3:1]};
		end
	end

	initial counter <= 2'b00;
	always @ (posedge rx_clkin) begin
		counter[0] <= ~counter[0] & ~sata_genreg[0];
		counter[1] <= counter[1] ^ (counter[0] | sata_genreg[0]);
	end

	initial rx_alignreg <= 4'b0000;
	always @ (posedge rx_clkin) begin
		if (error) begin
			rx_alignreg <= 4'b0000;
		end else if (align != 4'b0000) begin
			rx_alignreg <= align;
		end
		if (align != 4'b0000) begin
			sample <= counter;
		end 
	end

	initial sata_genreg <= 2'b10;
	always @ (posedge rx_clkin) sata_genreg <= sata_gen;
	
endmodule
