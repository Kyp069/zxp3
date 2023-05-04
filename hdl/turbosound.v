//-------------------------------------------------------------------------------------------------
module turbosound
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
	input  wire       clock,
	input  wire       ce,

	input  wire       reset,
	input  wire       iorq,
	input  wire       wr,
	input  wire       rd,
	input  wire[ 2:0] a,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,

	output wire[11:0] a1,
	output wire[11:0] b1,
	output wire[11:0] c1,

	output wire[11:0] a2,
	output wire[11:0] b2,
	output wire[11:0] c2,

	output wire       midi
);
//-------------------------------------------------------------------------------------------------

wire bdir = !iorq && a[2] && !a[0] && !wr;
wire bc1  = !iorq && a[2] &&  a[1] && !a[0] && (!rd || !wr);
wire[7:0] psgQ;

reg sel;
always @(posedge clock) if(!reset) sel <= 1'b0; else if(bdir && bc1 && d[4]) sel <= ~d[0];

//-------------------------------------------------------------------------------------------------

wire bdir1 = !sel ? bdir : 1'b0;
wire bc11 = !sel ? bc1 : 1'b0;

wire[ 7:0] q1;
wire[ 7:0] io1;

psg ay1
(
	.clock  (clock  ),
	.sel    (1'b0   ),
	.ce     (ce     ),
	.reset  (reset  ),
	.bdir   (bdir1  ),
	.bc1    (bc11   ),
	.d      (d      ),
	.q      (q1     ),
	.a      (a1     ),
	.b      (b1     ),
	.c      (c1     ),
	.io     (io1    )
);

//-------------------------------------------------------------------------------------------------

wire bdir2 = sel ? bdir : 1'b0;
wire bc12 = sel ? bc1 : 1'b0;

wire[ 7:0] q2;
wire[ 7:0] io2;

psg ay2
(
	.clock  (clock  ),
	.sel    (1'b0   ),
	.ce     (ce     ),
	.reset  (reset  ),
	.bdir   (bdir2  ),
	.bc1    (bc12   ),
	.d      (d      ),
	.q      (q2     ),
	.a      (a2     ),
	.b      (b2     ),
	.c      (c2     ),
	.io     (io2    )
);

//-------------------------------------------------------------------------------------------------

assign q = !sel ? q1 : q2;
assign midi =  !sel ? io1[2] : io2[2];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
