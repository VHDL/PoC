
module gray_counter (clk, inc, cnt);

	input clk;
	input inc;
	output reg [2:0] cnt;

	initial cnt <= 3'b000;
	always @ (posedge clk) begin
		if (inc) begin
			case (cnt)
				3'b000: cnt <= 3'b001;
				3'b001: cnt <= 3'b011;
				3'b011: cnt <= 3'b010;
				3'b010: cnt <= 3'b110;
				3'b110: cnt <= 3'b111;
				3'b111: cnt <= 3'b101;
				3'b101: cnt <= 3'b100;
				3'b100: cnt <= 3'b000;
			endcase
		end
	end

endmodule
