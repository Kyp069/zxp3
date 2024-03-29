//-------------------------------------------------------------------------------------------------
module keyboard
//-------------------------------------------------------------------------------------------------
//  This file is part of the ZX Spectrum +3 project.
//  Copyright (C) 2023 Kyp069 <kyp069@gmail.com>
//
//  This program is free software; you can redistribute it and/or modify it under the terms 
//  of the GNU General Public License as published by the Free Software Foundation;
//  either version 3 of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with this program;
//  if not, If not, see <https://www.gnu.org/licenses/>.
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      strb,
	input  wire      make,
	input  wire[7:0] code,
	input  wire[5:0] joy1,
	input  wire[5:0] joy2,
	output wire[4:0] q,
	input  wire[7:0] a
);
//-------------------------------------------------------------------------------------------------

reg[4:0] key[7:0];

initial begin
	key[0] = 5'b11111; key[1] = 5'b11111; key[2] = 5'b11111; key[3] = 5'b11111;
	key[4] = 5'b11111; key[5] = 5'b11111; key[6] = 5'b11111; key[7] = 5'b11111;
end

always @(posedge clock) if(strb)
	case(code)
		8'h12: key[0][0] <= make; // CS - left shift
		8'h59: key[0][0] <= make; // CS - left shift
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
		8'h14: key[7][1] <= make; // SS - right shift
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
		8'h75: { key[0][0], key[4][3] } <= { 2{make} }; // up (CS + 7)
		8'h72: { key[0][0], key[4][4] } <= { 2{make} }; // down (CS + 6)
		8'h6B: { key[0][0], key[3][4] } <= { 2{make} }; // left (CS + 5)
		8'h74: { key[0][0], key[4][2] } <= { 2{make} }; // right (CS + 8)
		8'h66: { key[0][0], key[4][0] } <= { 2{make} }; // delete (CS + 0)
		8'h76: { key[0][0], key[7][0] } <= { 2{make} }; // esc (CS + SPACE) - break
	endcase

//-------------------------------------------------------------------------------------------------

assign q =
{
	(a[0]|key[0][4])&(a[1]|key[1][4])&(a[2]|key[2][4])&(a[3]|key[3][4])&(a[4]|key[4][4])&(a[5]|key[5][4])&(a[6]|key[6][4])&(a[7]|key[7][4])&(a[3]|joy2[4])&(a[4]|joy1[4]),
	(a[0]|key[0][3])&(a[1]|key[1][3])&(a[2]|key[2][3])&(a[3]|key[3][3])&(a[4]|key[4][3])&(a[5]|key[5][3])&(a[6]|key[6][3])&(a[7]|key[7][3])&(a[3]|joy2[3])&(a[4]|joy1[3]),
	(a[0]|key[0][2])&(a[1]|key[1][2])&(a[2]|key[2][2])&(a[3]|key[3][2])&(a[4]|key[4][2])&(a[5]|key[5][2])&(a[6]|key[6][2])&(a[7]|key[7][2])&(a[3]|joy2[2])&(a[4]|joy1[2])&(a[0]|joy1[5]),
	(a[0]|key[0][1])&(a[1]|key[1][1])&(a[2]|key[2][1])&(a[3]|key[3][1])&(a[4]|key[4][1])&(a[5]|key[5][1])&(a[6]|key[6][1])&(a[7]|key[7][1])&(a[3]|joy2[1])&(a[4]|joy1[1])&(a[0]|joy2[5]),
	(a[0]|key[0][0])&(a[1]|key[1][0])&(a[2]|key[2][0])&(a[3]|key[3][0])&(a[4]|key[4][0])&(a[5]|key[5][0])&(a[6]|key[6][0])&(a[7]|key[7][0])&(a[3]|joy2[0])&(a[4]|joy1[0])
};

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
