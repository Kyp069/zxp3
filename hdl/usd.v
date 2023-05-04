//-------------------------------------------------------------------------------------------------
module usd
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
	input  wire      ce,
	input  wire      ne,
	input  wire      pe,

	input  wire      reset,
	input  wire      iorq,
	input  wire      rd,
	input  wire      wr,
	input  wire[7:0] d,
	output wire[7:0] q,
	input  wire[7:0] a,

	output reg       cs,
	output wire      ck,
	output wire      mosi,
	input  wire      miso
);
//-------------------------------------------------------------------------------------------------

wire io1F = !iorq && a == 8'h1F && !wr;
always @(posedge clock, negedge reset) if(!reset) cs <= 1'b1; else if(ce) if(io1F) cs <= d[0];

//-------------------------------------------------------------------------------------------------

wire io3F = !iorq && a == 8'h3F && (!rd || !wr);
wire[7:0] spiD = !wr ? d : 8'hFF;

spi Spi
(
	.clock  (clock  ),
	.ne     (ne     ),
	.pe     (pe     ),
	.io     (io3F   ),
	.d      (spiD   ),
	.q      (q      ),
	.ck     (ck     ),
	.mosi   (mosi   ),
	.miso   (miso   )
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
