//-------------------------------------------------------------------------------------------------
module rom_zxp3
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
#
(
	parameter KB = 64
)
(
	input  wire                      clock,
	input  wire[$clog2(KB*1024)-1:0] a,
	input  wire[                7:0] d,
	output reg [                7:0] q,
	input  wire                      w
);
//-------------------------------------------------------------------------------------------------

//(* ram_init_file = "../rom/plus3.mif" *) reg[7:0] mem[0:(KB*1024)-1];
(* ram_init_file = "../rom/mmcen3eE.mif" *) reg[7:0] mem[0:(KB*1024)-1];

//reg[7:0] mem[0:(KB*1024)-1];
//initial $readmemh("../hdl/rom/mmcen3eE.hex", mem);

always @(posedge clock) if(w) begin mem[a] <= d; q <= d; end else q <= mem[a];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------

