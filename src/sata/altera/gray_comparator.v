
module gray_comparator(cnt_wr, cnt_rd, high, low, full, empty);

input [2:0] cnt_wr;
input [2:0] cnt_rd;
output reg high;
output reg low;
output reg full;
output reg empty;

always @ (cnt_wr, cnt_rd) begin
	case ({cnt_wr,cnt_rd})
		6'b000000: {high,low,full,empty} <= 4'b0101;
		6'b000001: {high,low,full,empty} <= 4'b1010;
		6'b000011: {high,low,full,empty} <= 4'b1000;
		6'b000010: {high,low,full,empty} <= 4'b1000;
		6'b000110: {high,low,full,empty} <= 4'b1000;
		6'b000111: {high,low,full,empty} <= 4'b0000;
		6'b000101: {high,low,full,empty} <= 4'b0100;
		6'b000100: {high,low,full,empty} <= 4'b0100;
 
		6'b001000: {high,low,full,empty} <= 4'b0100;
		6'b001001: {high,low,full,empty} <= 4'b0101;
		6'b001011: {high,low,full,empty} <= 4'b1010;
		6'b001010: {high,low,full,empty} <= 4'b1000;
		6'b001110: {high,low,full,empty} <= 4'b1000;
		6'b001111: {high,low,full,empty} <= 4'b1000;
		6'b001101: {high,low,full,empty} <= 4'b0000;
		6'b001100: {high,low,full,empty} <= 4'b0100;
 
		6'b011000: {high,low,full,empty} <= 4'b0100;
		6'b011001: {high,low,full,empty} <= 4'b0100;
		6'b011011: {high,low,full,empty} <= 4'b0101;
		6'b011010: {high,low,full,empty} <= 4'b1010;
		6'b011110: {high,low,full,empty} <= 4'b1000;
		6'b011111: {high,low,full,empty} <= 4'b1000;
		6'b011101: {high,low,full,empty} <= 4'b1000;
		6'b011100: {high,low,full,empty} <= 4'b0000;
 
		6'b010000: {high,low,full,empty} <= 4'b0000;
		6'b010001: {high,low,full,empty} <= 4'b0100;
		6'b010011: {high,low,full,empty} <= 4'b0100;
		6'b010010: {high,low,full,empty} <= 4'b0101;
		6'b010110: {high,low,full,empty} <= 4'b1010;
		6'b010111: {high,low,full,empty} <= 4'b1000;
		6'b010101: {high,low,full,empty} <= 4'b1000;
		6'b010100: {high,low,full,empty} <= 4'b1000;
 
		6'b110000: {high,low,full,empty} <= 4'b1000;
		6'b110001: {high,low,full,empty} <= 4'b0000;
		6'b110011: {high,low,full,empty} <= 4'b0100;
		6'b110010: {high,low,full,empty} <= 4'b0100;
		6'b110110: {high,low,full,empty} <= 4'b0101;
		6'b110111: {high,low,full,empty} <= 4'b1010;
		6'b110101: {high,low,full,empty} <= 4'b1000;
		6'b110100: {high,low,full,empty} <= 4'b1000;
 
		6'b111000: {high,low,full,empty} <= 4'b1000;
		6'b111001: {high,low,full,empty} <= 4'b1000;
		6'b111011: {high,low,full,empty} <= 4'b0000;
		6'b111010: {high,low,full,empty} <= 4'b0100;
		6'b111110: {high,low,full,empty} <= 4'b0100;
		6'b111111: {high,low,full,empty} <= 4'b0101;
		6'b111101: {high,low,full,empty} <= 4'b1010;
		6'b111100: {high,low,full,empty} <= 4'b1000;
 
		6'b101000: {high,low,full,empty} <= 4'b1000;
		6'b101001: {high,low,full,empty} <= 4'b1000;
		6'b101011: {high,low,full,empty} <= 4'b1000;
		6'b101010: {high,low,full,empty} <= 4'b0000;
		6'b101110: {high,low,full,empty} <= 4'b0100;
		6'b101111: {high,low,full,empty} <= 4'b0100;
		6'b101101: {high,low,full,empty} <= 4'b0101;
		6'b101100: {high,low,full,empty} <= 4'b1010;
 
		6'b100000: {high,low,full,empty} <= 4'b1010;
		6'b100001: {high,low,full,empty} <= 4'b1000;
		6'b100011: {high,low,full,empty} <= 4'b1000;
		6'b100010: {high,low,full,empty} <= 4'b1000;
		6'b100110: {high,low,full,empty} <= 4'b0000;
		6'b100111: {high,low,full,empty} <= 4'b0100;
		6'b100101: {high,low,full,empty} <= 4'b0100;
		6'b100100: {high,low,full,empty} <= 4'b0101;
	endcase
end

endmodule
