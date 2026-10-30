//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module matrix
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      strb,
	input  wire[7:0] code,
	input  wire[4:0] joy1,
	input  wire[4:0] joy2,
	input  wire[7:0] row,
	output wire[4:0] col,
	output reg       play,
	output reg       stop,
	output reg       F5,
	output reg       F9
);
//-------------------------------------------------------------------------------------------------
 
reg[4:0] key[7:0];
initial begin
	key[0] = 5'b11111; key[1] = 5'b11111; key[2] = 5'b11111; key[3] = 5'b11111;
	key[4] = 5'b11111; key[5] = 5'b11111; key[6] = 5'b11111; key[7] = 5'b11111;
	{ play, stop, F5, F9 } = {4{ 1'b1 }};
end

//-------------------------------------------------------------------------------------------------

reg make = 1'b0;
reg extended = 1'b0;

always @(posedge clock) if(strb) begin

	case(code)
		8'hF0: make  <= 1'b1;
		8'hE0: extended <= 1'b1;
		default: { make, extended } <= 2'b00;
	endcase

	if(extended)
		case(code)
			8'h7D: play <= make; // PgUp
			8'h7A: stop <= make; // PgDown

			8'h75: { key[0][0], key[4][3] } <= { 2{make} }; // up (CS + 7)
			8'h72: { key[0][0], key[4][4] } <= { 2{make} }; // down (CS + 6)
			8'h6B: { key[0][0], key[3][4] } <= { 2{make} }; // left (CS + 5)
			8'h74: { key[0][0], key[4][2] } <= { 2{make} }; // right (CS + 8)

			8'h14: key[7][1] <= make; // SS - right control
		endcase
	else
		case(code)
			// 8'h05: F1 <= make; // F1
			// 8'h06: F2 <= make; // F2
			// 8'h04: F3 <= make; // F3
			// 8'h0C: F4 <= make; // F4
			8'h03: F5 <= make; // F5
			8'h01: F9 <= make; // F9

			8'h12: key[0][0] <= make; // CS - left shift
			8'h59: key[0][0] <= make; // CS - right shift
			8'h1A: key[0][1] <= make; // Z
			8'h22: key[0][2] <= make; // X
			8'h21: key[0][3] <= make; // C
			8'h2A: key[0][4] <= make; // V

			8'h1C: key[1][0] <= make; // A
			8'h1B: key[1][1] <= make; // S
			8'h23: key[1][2] <= make; // D
			8'h2B: key[1][3] <= make; // F
			8'h34: key[1][4] <= make; // G

			8'h15: key[2][0] <= make; // Q
			8'h1D: key[2][1] <= make; // W
			8'h24: key[2][2] <= make; // E
			8'h2D: key[2][3] <= make; // R
			8'h2C: key[2][4] <= make; // T

			8'h16: key[3][0] <= make; // 1
			8'h1E: key[3][1] <= make; // 2
			8'h26: key[3][2] <= make; // 3
			8'h25: key[3][3] <= make; // 4
			8'h2E: key[3][4] <= make; // 5

			8'h45: key[4][0] <= make; // 0
			8'h46: key[4][1] <= make; // 9
			8'h3E: key[4][2] <= make; // 8
			8'h3D: key[4][3] <= make; // 7
			8'h36: key[4][4] <= make; // 6

			8'h4D: key[5][0] <= make; // P
			8'h44: key[5][1] <= make; // O
			8'h43: key[5][2] <= make; // I
			8'h3C: key[5][3] <= make; // U
			8'h35: key[5][4] <= make; // Y

			8'h5A: key[6][0] <= make; // ENTER
			8'h4B: key[6][1] <= make; // L
			8'h42: key[6][2] <= make; // K
			8'h3B: key[6][3] <= make; // J
			8'h33: key[6][4] <= make; // H

			8'h29: key[7][0] <= make; // SPACE
			8'h14: key[7][1] <= make; // SS - left control
			8'h3A: key[7][2] <= make; // M
			8'h31: key[7][3] <= make; // N
			8'h32: key[7][4] <= make; // B

			8'h54: { key[7][1], key[5][0] } <= { 2{make} }; // " (SS + P)
			8'h52: { key[7][1], key[5][1] } <= { 2{make} }; // ; (SS + P)
			8'h49: { key[7][1], key[7][2] } <= { 2{make} }; // . (SS + M)
			8'h41: { key[7][1], key[7][3] } <= { 2{make} }; // , (SS + N)
			8'h4A: { key[7][1], key[6][3] } <= { 2{make} }; // - (SS + J)
			8'h5B: { key[7][1], key[6][2] } <= { 2{make} }; // + (SS + K)
			8'h61: { key[7][1], key[0][1] } <= { 2{make} }; // : (SS + Z)
			8'h66: { key[0][0], key[4][0] } <= { 2{make} }; // delete (CS + 0)
			8'h76: { key[0][0], key[7][0] } <= { 2{make} }; // esc (CS + SPACE) - break
		endcase
end

//-------------------------------------------------------------------------------------------------

assign col =
{
	(row[0]|key[0][4])&(row[1]|key[1][4])&(row[2]|key[2][4])&(row[3]|key[3][4])&(row[4]|key[4][4])&(row[5]|key[5][4])&(row[6]|key[6][4])&(row[7]|key[7][4])&(row[3]|joy2[4])&(row[4]|joy1[1]),
	(row[0]|key[0][3])&(row[1]|key[1][3])&(row[2]|key[2][3])&(row[3]|key[3][3])&(row[4]|key[4][3])&(row[5]|key[5][3])&(row[6]|key[6][3])&(row[7]|key[7][3])&(row[3]|joy2[3])&(row[4]|joy1[0]),
	(row[0]|key[0][2])&(row[1]|key[1][2])&(row[2]|key[2][2])&(row[3]|key[3][2])&(row[4]|key[4][2])&(row[5]|key[5][2])&(row[6]|key[6][2])&(row[7]|key[7][2])&(row[3]|joy2[2])&(row[4]|joy1[2]),
	(row[0]|key[0][1])&(row[1]|key[1][1])&(row[2]|key[2][1])&(row[3]|key[3][1])&(row[4]|key[4][1])&(row[5]|key[5][1])&(row[6]|key[6][1])&(row[7]|key[7][1])&(row[3]|joy2[0])&(row[4]|joy1[3]),
	(row[0]|key[0][0])&(row[1]|key[1][0])&(row[2]|key[2][0])&(row[3]|key[3][0])&(row[4]|key[4][0])&(row[5]|key[5][0])&(row[6]|key[6][0])&(row[7]|key[7][0])&(row[3]|joy2[1])&(row[4]|joy1[4])
};

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
