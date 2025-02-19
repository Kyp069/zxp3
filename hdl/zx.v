//-------------------------------------------------------------------------------------------------
module zx
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
	input  wire       clock,  // clock 56.7504 MHz
	input  wire       power,
	input  wire       reset,
	input  wire       nmi,

	output wire       cep1x,  // pixel clock enable
	output wire       cep2x,

	output wire[13:0] memA1,  // video memory
	input  wire[ 7:0] memQ1,

	output wire[17:0] memA2,  // cpu memory
	output wire[ 7:0] memD2,
	input  wire[ 7:0] memQ2,
	output wire       memW2,

	output wire       hblank, // video
	output wire       vblank,
	output wire       hsync,
	output wire       vsync,
	output wire       r,
	output wire       g,
	output wire       b,
	output wire       i,

	input  wire       ear,    // audio
	output wire       midi,
	output wire[14:0] left, 
	output wire[14:0] right,

	input  wire       strb,   // keyboard
	input  wire       make,
	input  wire[ 7:0] code,

	input  wire[ 7:0] xaxis,  // mouse
	input  wire[ 7:0] yaxis,
	input  wire[ 2:0] mbtns,

	input  wire[ 7:0] joy1,   // joystick
	input  wire[ 7:0] joy2,

	output wire       cs,     // sd
	output wire       ck,
	output wire       mosi,
	input  wire       miso,

	output wire       fddCe,  // floppy
	output wire       fddRd,
	output wire       fddWr,
	output wire       fddA,
	output wire[ 7:0] fddD,
	input  wire[ 7:0] fddQ,
	output wire       fddMtr
);
//-------------------------------------------------------------------------------------------------

wire addr00 = !a[15] && !a[14];
wire addr01 = !a[15] &&  a[14];
wire addr10 =  a[15] && !a[14];
wire addr11 =  a[15] &&  a[14];

wire ioFE   = !iorq && !a[0];                       // ula
wire ioDF   = !iorq && !a[5];                       // kempston
wire io3F   = !iorq && a[7:0] == 8'h3F;             // usd
wire ioFFFD = !iorq && addr11 && !a[1];             // psg
wire io7FFD = !iorq && addr01 && !a[1];             // +2 mapping
wire io1FFD = !iorq && a[15:12] == 4'h1 && !a[1];   // +3 mapping
wire io3FFD = !iorq && a[15:13] == 3'b001 && !a[1]; // fdd
wire ioF3DF = !iorq && a[10:8] == 3'b011 && !a[5];  // k-mouse x axis
wire ioF7DF = !iorq && a[10:8] == 3'b111 && !a[5];  // k-mouse y axis
wire ioFEDF = !iorq && a[ 9:8] == 2'b10  && !a[5];  // k-mouse buttons

//-------------------------------------------------------------------------------------------------

reg pe14M;
reg ne7M0, pe7M0;
reg ne3M5, pe3M5;

reg[3:0] ce = 1;
always @(negedge clock) 
	if(!power) ce <= 1'd1;
	else begin
		ce <= ce+1'd1;
		pe14M <= ~ce[0] &  ce[1];
		ne7M0 <= ~ce[0] & ~ce[1] & ~ce[2];
		pe7M0 <= ~ce[0] & ~ce[1] &  ce[2];
		ne3M5 <= ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];
		pe3M5 <= ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
	end

assign cep1x = pe7M0;
assign cep2x = pe14M;

//-------------------------------------------------------------------------------------------------

reg mreqt23iorqtw3;
always @(posedge clock) if(pc3M5) mreqt23iorqtw3 <= mreq & !ioFE;

reg clk35;
always @(posedge clock) if(pe7M0) clk35 <= !(clk35 && contend);

wire memC = addr01 || (addr11 && ramPage[2]);
wire contend = !(clk35 && vduC && mreqt23iorqtw3 && (memC || ioFE));

wire nc3M5 = ne3M5 & contend;
wire pc3M5 = pe3M5 & contend;

wire necpu = nc3M5;
wire pecpu = pc3M5;

//-------------------------------------------------------------------------------------------------

reg irq;
always @(posedge clock, negedge reset) if(!reset) irq <= 1'b1; else if(pecpu) irq <= vduI;

wire iorq, mreq, rd, wr;

wire[15:0] a;
wire[ 7:0] d;
wire[ 7:0] q;

cpu cpu
(
	.clock  (clock  ),
	.ne     (necpu  ),
	.pe     (pecpu  ),
	.reset  (reset  ),
	.iorq   (iorq   ),
	.mreq   (mreq   ),
	.irq    (irq    ),
	.nmi    (nmi    ),
	.rd     (rd     ),
	.wr     (wr     ),
	.a      (a      ),
	.d      (d      ),
	.q      (q      )
);

//-------------------------------------------------------------------------------------------------

reg[4:0] portFE;
always @(posedge clock) if(pe7M0) if(ioFE && !wr) portFE <= q[4:0];

wire mic = portFE[3];
wire speaker = portFE[4];
wire[2:0] border = portFE[2:0];

//-------------------------------------------------------------------------------------------------

reg[3:0] port1FFD;
always @(posedge clock, negedge reset)
	if(!reset) port1FFD <= 1'd0;
	else if(pecpu) if(io1FFD && !wr) port1FFD <= q[3:0];

reg[5:0] port7FFD;
always @(posedge clock, negedge reset)
	if(!reset) port7FFD <= 1'd0;
	else if(pecpu) if(io7FFD && !wr) port7FFD <= { port7FFD[5]|q[5], q[4:0] };

reg[2:0] allramPage;
always @(*) case({ port1FFD[2:1], a[15:14] })
	4'h0: allramPage = 3'd0;
	4'h1: allramPage = 3'd1;
	4'h2: allramPage = 3'd2;
	4'h3: allramPage = 3'd3;
	4'h4: allramPage = 3'd4;
	4'h5: allramPage = 3'd5;
	4'h6: allramPage = 3'd6;
	4'h7: allramPage = 3'd7;
	4'h8: allramPage = 3'd4;
	4'h9: allramPage = 3'd5;
	4'hA: allramPage = 3'd6;
	4'hB: allramPage = 3'd3;
	4'hC: allramPage = 3'd4;
	4'hD: allramPage = 3'd7;
	4'hE: allramPage = 3'd6;
	4'hF: allramPage = 3'd3;
endcase

wire      allram = port1FFD[0];
wire      vmmPage = port7FFD[3];
wire[2:0] romPage = { 1'b0, port1FFD[2], port7FFD[4] };
wire[2:0] ramPage = addr01 ? 3'd5 : addr10 ? 3'd2 : port7FFD[2:0];

//-------------------------------------------------------------------------------------------------

assign memA1 = { vmmPage, vduA };

assign memA2 = { allram ? { 1'b1, allramPage } : addr00 ? { 1'b0, romPage } : { 1'b1, ramPage }, a[13:0] };
assign memD2 = q;
assign memW2 = !mreq && !wr && (allram || a[15] || a[14]);

//-------------------------------------------------------------------------------------------------

wire       vduC;
wire       vduI;
wire[12:0] vduA;
wire[ 7:0] vduD = memQ1;

video video
(
	.clock  (clock  ),
	.ce     (pe7M0  ),
	.border (border ),
	.contend(vduC   ),
	.irq    (vduI   ),
	.a      (vduA   ),
	.d      (vduD   ),
	.hblank (hblank ),
	.vblank (vblank ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      )
);

//-------------------------------------------------------------------------------------------------

wire[ 2:0] psgA = { a[15:14], a[1] };
wire[ 7:0] psgD = q;
wire[ 7:0] psgQ;

wire[11:0] a1, b1, c1;
wire[11:0] a2, b2, c2;

turbosound turbosound
(
	.clock  (clock  ),
	.ce     (pe3M5  ),
	.reset  (reset  ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.a      (psgA   ),
	.d      (psgD   ),
	.q      (psgQ   ),
	.a1     (a1     ),
	.b1     (b1     ),
	.c1     (c1     ),
	.a2     (a2     ),
	.b2     (b2     ),
	.c2     (c2     ),
	.midi   (midi   )
);

//-------------------------------------------------------------------------------------------------

audio audio
(
	.ear    (ear    ),
	.mic    (mic    ),
	.speaker(speaker),
	.a1     (a1     ),
	.b1     (b1     ),
	.c1     (c1     ),
	.a2     (a2     ),
	.b2     (b2     ),
	.c2     (c2     ),
	.left   (left   ),
	.right  (right  )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] keyA = a[15:8];
wire[5:0] if2l = ~{ joy1[5], joy1[1], joy1[0], joy1[2], joy1[3], joy1[4] };
wire[5:0] if2r = ~{ joy2[5], joy2[1], joy2[0], joy2[2], joy2[3], joy2[4] };
wire[4:0] keyQ;

keyboard keyboard
(
	.clock  (clock  ),
	.strb   (strb   ),
	.make   (make   ),
	.code   (code   ),
	.joy1   (if2l   ),
	.joy2   (if2r   ),
	.a      (keyA   ),
	.q      (keyQ   )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] usdQ;
wire[7:0] usdA = a[7:0];

usd usd
(
	.clock  (clock  ),
	.ce     (pecpu  ),
	.ne     (ne7M0  ),
	.pe     (pe7M0  ),
	.reset  (reset  ),
	.iorq   (iorq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.d      (q      ),
	.q      (usdQ   ),
	.a      (usdA   ),
	.cs     (cs     ),
	.ck     (ck     ),
	.mosi   (mosi   ),
	.miso   (miso   )
);

//-------------------------------------------------------------------------------------------------

assign fddCe = pecpu;
assign fddRd = !(io3FFD && !rd);
assign fddWr = !(io3FFD && !wr);
assign fddA = a[12];
assign fddD = q;

assign fddMtr = port1FFD[3];

//-------------------------------------------------------------------------------------------------

assign d
	= !mreq  ? memQ2
	: ioFFFD ? psgQ
	: io3F   ? usdQ
	: io3FFD ? fddQ
	: ioF3DF ? xaxis
	: ioF7DF ? yaxis
	: ioFEDF ? { 5'b11111, mbtns }
	: ioDF   ? joy1 | joy2
	: ioFE   ? { 1'b1, ear, 1'b1, keyQ }
	: 8'hFF;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
