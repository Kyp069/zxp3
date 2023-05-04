//-------------------------------------------------------------------------------------------------
module audio
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
	input  wire       mic,
	input  wire       ear,
	input  wire       speaker,
	input  wire[11:0] a1,
	input  wire[11:0] b1,
	input  wire[11:0] c1,
	input  wire[11:0] a2,
	input  wire[11:0] b2,
	input  wire[11:0] c2,
	output wire[14:0] left,
	output wire[14:0] right
);
//-------------------------------------------------------------------------------------------------

reg[7:0] ula;
always @(*) case({ speaker, ear, mic })
	0: ula <= 8'h00;
	1: ula <= 8'h24;
	2: ula <= 8'h40;
	3: ula <= 8'h64;
	4: ula <= 8'hB8;
	5: ula <= 8'hC0;
	6: ula <= 8'hF8;
	7: ula <= 8'hFF;
endcase

//-------------------------------------------------------------------------------------------------

assign  left = { 4'd0, ula, 2'd0 }+{ 2'd0, a1, 1'd0 }+{ 2'd0, a2, 1'd0 }+{ 3'd0, b1 }+{ 3'd0, b2 };
assign right = { 4'd0, ula, 2'd0 }+{ 2'd0, c1, 1'd0 }+{ 2'd0, c2, 1'd0 }+{ 3'd0, b1 }+{ 3'd0, b2 };

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
