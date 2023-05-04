//-------------------------------------------------------------------------------------------------
module spi
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
	input  wire      ne,
	input  wire      pe,
	input  wire      io,
	input  wire[7:0] d,
	output reg [7:0] q,
	output wire      ck,
	output wire      mosi,
	input  wire      miso
);
//-------------------------------------------------------------------------------------------------

reg iod, iop;
always @(posedge clock) if(pe) begin iod <= io; iop <= io && !iod; end

//-------------------------------------------------------------------------------------------------

reg[7:0] sr;
reg[4:0] cc = 5'b10000;

always @(negedge clock) if(ne)
	if(cc[4]) begin
		if(iop) begin
			q <= sr;
			sr <= d;
			cc <= 1'd0;
		end
	end
	else begin
		cc <= cc+1'd1;
		if(cc[0]) sr <= { sr[6:0], miso };
	end

//-------------------------------------------------------------------------------------------------

assign ck = cc[0];
assign mosi = sr[7];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
