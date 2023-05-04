`default_nettype none
//-------------------------------------------------------------------------------------------------
module np1
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
	input  wire       clock50,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       tape,
	output wire       midi,
	output wire[ 1:0] dsg,
	output wire[ 2:0] i2s,

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

	output wire       sramUb,
	output wire       sramLb,
	output wire       sramOe,
	output wire       sramWe,

	output wire       dramCk,
	output wire       dramCe,
	output wire       dramCs,
	output wire       dramWe,
	output wire       dramRas,
	output wire       dramCas,

	output wire       stm,
	output wire       led
);
//-------------------------------------------------------------------------------------------------

wire clock, power;
pll pll(clock50, clock, power);

//-------------------------------------------------------------------------------------------------

reg tapeini, tapegot;
always @(posedge clock) if(!power) if(!tapegot) { tapeini, tapegot } <= { tape, 1'b1 };

//-------------------------------------------------------------------------------------------------

wire[7:0] joy1;
wire[7:0] joy2;

joystick Joystick
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

wire       romIo;
wire       romWr;
wire[24:0] romA;
wire[ 7:0] romD;

wire[ 1:0] iblank = { vblank, hblank };
wire[ 1:0] isync = { vsync, hsync };
wire[17:0] irgb = { r,{4{r&i}},r, g,{4{g&i}},g, b,{4{b&i}},b };

wire[1:0] ps2ki = { ps2kDQ, ps2kCk };
wire[1:0] ps2ko;

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
	clock, power, reset,
	cep1x, cep2x,
	sdcCs, sdcCk, sdcMosi, sdcMiso,
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
ps2k ps2k(clock, ps2ko, strb, make, code);

wire[7:0] xaxis;
wire[7:0] yaxis;
wire[2:0] mbtns;
ps2m mouse(clock, reset, ps2mDQ, ps2mCk, xaxis, yaxis, mbtns);

reg F9 = 1'b1;
reg F5 = 1'b1;
always @(posedge clock) if(strb)
	case(code)
		8'h01: F9 <= make;
		8'h03: F5 <= make;
	endcase

//-------------------------------------------------------------------------------------------------

wire reset = power && F9 && !romIo;
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

wire ear = tape ^ tapeini;

wire[14:0] left;
wire[14:0] right;

zx Zx
(
	clock, power, reset, nmi,
	cep1x, cep2x,
	memA1,memQ1, memA2,memD2,memQ2,memW2,
	hblank, vblank, hsync, vsync, r, g, b, i,
	ear, midi, left, right,
	strb, make, code,
	xaxis, yaxis, mbtns,
	joy1, joy2,
	sdvCs, sdvCk, sdvMosi, sdvMiso,
	fddCe, fddRd, fddWr, fddA, fddD, fddQ, fddMtr
);

//-------------------------------------------------------------------------------------------------

dsg #(14) dsg1(clock, reset,  left, dsg[1]);
dsg #(14) dsg0(clock, reset, right, dsg[0]);
i2s i2sOut(clock, i2s, { 1'b0,  left }, { 1'b0, right });

//-------------------------------------------------------------------------------------------------

wire dprW2 = memW2 && (memA2[16:14] == 5 || memA2[16:14] == 7) && !memA2[13];
dprs #(16) dpr(clock, memA1, memQ1, { memA2[15], memA2[12:0] }, memD2, dprW2);

wire[7:0] romQ;
rom_zxp3 rom(clock, romIo ? romA[15:0] : memA2[15:0], romD, romQ, romWr);

wire[7:0] ramQ;
ram #(128) ram(clock, memA2[16:0], memD2, ramQ, memW2);

assign memQ2 = memA2[17] ? ramQ : !memA2[16] ? romQ : 8'hFF;

//-------------------------------------------------------------------------------------------------

assign sramUb = 1'b1;
assign sramLb = 1'b1;
assign sramOe = 1'b1;
assign sramWe = 1'b1;

assign dramCk = 1'b0;
assign dramCe = 1'b0;
assign dramCs = 1'b1;
assign dramWe = 1'b1;
assign dramRas = 1'b1;
assign dramCas = 1'b1;

assign led = sdcCs;
assign stm = 1'b0;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
