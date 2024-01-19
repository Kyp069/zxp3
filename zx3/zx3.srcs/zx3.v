`default_nettype none
//-------------------------------------------------------------------------------------------------
//  This file is part of the ZX Spectrum +3 FPGA implementation project.
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
module zx3
//-------------------------------------------------------------------------------------------------
(
	input  wire        clock50,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       tape,
	input  wire[ 2:0] i2sIn,
	
	output wire       midi,
	output wire[ 1:0] dsg,
	output wire[ 2:0] i2sOut,

	input  wire       ps2kDQ,
	input  wire       ps2kCk,

	inout  wire       ps2mDQ,
	inout  wire       ps2mCk,

	output wire       joyCk,
	output wire       joyLd,
	output wire       joyS,
	input  wire       joyD,

	output wire       sdcCs,
	output wire       sdcCk,
	output wire       sdcMosi,
	input  wire       sdcMiso,

	output wire       fshCs,
	output wire       fshCk,
	output wire       fshRst,
	output wire       fshMosi,
	input  wire       fshMiso,

	output wire       sramLb,
	output wire       sramUb,
	output wire       sramOe,
	output wire       sramWe,
	inout  wire[ 7:0] sramDQ,
	output wire[19:0] sramA,

	output wire       dramCk,
	output wire       dramCe,
	output wire       dramCs,
	output wire       dramWe,
	output wire       dramCas,
	output wire       dramRas,

	output wire[ 1:0] led
);
//-------------------------------------------------------------------------------------------------

wire clock, power;
mmcm56 mmcm(clock50, clock, power);

//-------------------------------------------------------------------------------------------------

reg tapeini, tapegot;
always @(posedge clock) if(!power) if(!tapegot) { tapeini, tapegot } <= { tape, 1'b1 };

//-------------------------------------------------------------------------------------------------

wire[7:0] joy1;
wire[7:0] joy2;

joystick joystick
(
	.clock  (clock  ),
	.joyCk  (joyCk  ),
	.joyLd  (joyLd  ),
	.joyS   (joyS   ),
	.joyD   (joyD   ),
	.joy1   (joy1   ),
	.joy2   (joy2   )
);

//-------------------------------------------------------------------------------------------------

wire tvga;
wire boot;

wire       romIo;
wire       romWr;
wire[24:0] romA;
wire[ 7:0] romD;

wire[ 1:0] iblank = { vblank, hblank };
wire[ 1:0] isync = { vsync, hsync };
wire[17:0] irgb = { r,{2{r&i}},3'd0, g,{2{g&i}},3'd0, b,{2{b&i}},3'd0 };

wire[ 1:0] ps2ki = { ps2kDQ, ps2kCk };
wire[ 1:0] ps2ko;

wire       sdvCs;
wire       sdvCk;
wire       sdvMosi;
wire       sdvMiso;

wire       fddCe;
wire       fddRd;
wire       fddWr;
wire       fddA;
wire[ 7:0] fddD;
wire[ 7:0] fddQ;
wire       fddMtr;

demistify demistify
(
	clock, power, reset, scrl, boot,
	cep1x, cep2x,
	sdcCs, sdcCk, sdcMosi, sdcMiso,
	fshCs, fshCk, fshRst, fshMosi, fshMiso,
	romIo, romWr, romA, romD,
	iblank, isync, irgb, sync, rgb,
	ps2ki, ps2ko,
	sdvCs, sdvCk, sdvMosi, sdvMiso,
	fddCe, fddRd, fddWr, fddA, fddD, fddQ, fddMtr
);

//-------------------------------------------------------------------------------------------------

wire      strb;
wire      make;
wire[7:0] code;
ps2k ps2k(clock, ps2ko[1], ps2ko[0], strb, make, code);

wire[7:0] xaxis;
wire[7:0] yaxis;
wire[2:0] mbtns;
ps2m ps2m(clock, reset, ps2mDQ, ps2mCk, xaxis, yaxis, mbtns);

reg F9 = 1'b1, F8 = 1'b1, F5 = 1'b1;
reg alt = 1'b1, del = 1'b1, ctrl = 1'b1, bspc = 1'b1, scrl = 1'b0;
always @(posedge clock) if(strb)
	case(code)
		8'h01: F9 <= make;
		8'h0A: F8 <= make;
		8'h03: F5 <= make;
		8'h11: alt <= make;
		8'h71: del <= make;
		8'h14: ctrl <= make;
		8'h66: bspc <= make;
		8'h7E: if(!make) scrl <= ~scrl;
	endcase

//-------------------------------------------------------------------------------------------------

wire reset = power && F9 && (ctrl || alt || del) && !romIo;
wire nmi = F5;

wire cep1x;
wire cep2x;

wire[13:0] memA1;
wire[ 7:0] memQ1;

wire[17:0] memA2;
wire[ 7:0] memD2;
wire[ 7:0] memQ2;
wire       memW2;

wire hblank;
wire vblank;
wire hsync;
wire vsync;
wire r;
wire g;
wire b;
wire i;

wire ear = tape^tapeini;

wire[14:0] left;
wire[14:0] right;

zx zx
(
	.clock  (clock  ),
	.power  (power  ),
	.reset  (reset  ),
	.nmi    (nmi    ),
	.cep1x  (cep1x  ),
	.cep2x  (cep2x  ),
	.memA1  (memA1  ),
	.memQ1  (memQ1  ),
	.memA2  (memA2  ),
	.memD2  (memD2  ),
	.memQ2  (memQ2  ),
	.memW2  (memW2  ),
	.hblank (hblank ),
	.vblank (vblank ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      ),
	.ear    (ear    ),
	.midi   (midi   ),
	.left   (left   ),
	.right  (right  ),
	.strb   (strb   ),
	.make   (make   ),
	.code   (code   ),
	.xaxis  (xaxis  ),
	.yaxis  (yaxis  ),
	.mbtns  (mbtns  ),
	.joy1   (joy1   ),
	.joy2   (joy2   ),
	.cs     (sdvCs  ),
	.ck     (sdvCk  ),
	.mosi   (sdvMosi),
	.miso   (sdvMiso),
	.fddCe  (fddCe  ),
	.fddRd  (fddRd  ),
	.fddWr  (fddWr  ),
	.fddA   (fddA   ),
	.fddD   (fddD   ),
	.fddQ   (fddQ   ),
	.fddMtr (fddMtr )
);

//-------------------------------------------------------------------------------------------------

wire[15:0] lmidi, rmidi;
i2s_in i2s_in(clock, i2sIn, lmidi, rmidi);

wire[15:0] lmix = { 1'b0, lmidi[15:1] }^16'h4000+{ 1'd0,  left };
wire[15:0] rmix = { 1'b0, rmidi[15:1] }^16'h4000+{ 1'd0, right };

dsg #(15) dsg1(clock, reset, lmix, dsg[1]);
dsg #(15) dsg0(clock, reset, rmix, dsg[0]);
i2s_out i2s_out(clock, i2sOut, lmix, rmix);

//-------------------------------------------------------------------------------------------------

wire dprW2 = memW2 && (memA2[16:14] == 5 || memA2[16:14] == 7) && !memA2[13];
dprs #(16) dpr(clock, memA1, memQ1, { memA2[15], memA2[12:0] }, memD2, dprW2);

assign sramUb = 1'b1;
assign sramLb = 1'b0;
assign sramOe = 1'b0;
assign sramWe = !(romIo ? romWr : memW2);
assign sramDQ = sramWe ? 8'bZ : romIo ? romD : memD2;
assign sramA = { 2'd0, romIo ? romA[17:0] : memA2 };

assign memQ2 = sramDQ;

assign dramCk  = 1'b0;
assign dramCe  = 1'b0;
assign dramCs  = 1'b1;
assign dramWe  = 1'b1;
assign dramCas = 1'b1;
assign dramRas = 1'b1;

assign led = { 1'b0, ~sdcCs };

//-------------------------------------------------------------------------------------------------

mboot mboot(clock, !(F8 && (ctrl || alt || bspc) && boot));

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
