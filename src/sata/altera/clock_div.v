
module clock_div(clk, clk2, clk4);

	input clk;
	output reg clk2;
	output reg clk4;

	initial {clk4,clk2} <= 2'b00;
	always @ (posedge clk) begin
		clk2 <= ~clk2;
		clk4 <= clk4 ^ clk2;
	end

endmodule
