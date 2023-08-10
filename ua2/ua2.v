`default_nettype none
//-------------------------------------------------------------------------------------------------
module ua2
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire[ 1:0] sync,
	output reg        rgbCk,
	output wire       rgbEn,
	output wire[23:0] rgb,

	input  wire       tape,

	output wire       i2sD,
	output wire       i2sW,
	output wire       i2sCk,

	input  wire       ps2kDQ,
	input  wire       ps2kCk,
	
	inout  wire       ps2mDQ,
	inout  wire       ps2mCk,

	output wire       sdcCs,
	output wire       sdcCk,
	output wire       sdcMosi,
	input  wire       sdcMiso,

	output wire       sramWe,
	inout  wire[ 7:0] sramDQ,
	output wire[20:0] sramA,

	output wire[ 1:0] led,
	output wire       stm
);
//-------------------------------------------------------------------------------------------------

wire clock, power;
pll pll(clock50, clock, power);

//-------------------------------------------------------------------------------------------------
/*
reg[3:0] ce;
always @(negedge clock, negedge power) if(!power) ce <= 1'd1; else ce <= ce+1'd1;

reg pe14M;
always @(negedge clock) pe14M <= ~ce[0] &  ce[1];

reg pe7M0;
always @(negedge clock) pe7M0 <= ~ce[0] & ~ce[1] &  ce[2];

wire[12:0] romA = vduA;
wire[ 7:0] romQ;
rom #(8, "../hdl/rom/fairlight.hex") rom(clock, romA, romQ);

wire[12:0] vduA;
wire[ 7:0] vduD = romQ;
wire hblank, vblank, hsync, vsync, r, g, b, i;
video video
(
	clock,
	pe7M0,
	3'd0,
	,
	,
	vduA,
	vduD,
	hblank,
	vblank,
	hsync,
	vsync,
	r,
	g,
	b,
	i
);

always @(posedge clock) if(pe14M) rgbCk <= ~rgbCk;

assign rgbEn = ~(hblank|vblank);
assign sync = { 1'b1, ~(vsync ^ hsync) };
assign rgb = rgbEn ? { r,{7{r&i}}, g,{7{g&i}}, b,{7{b&i}} } : 1'd0;

assign led = {2{ ~power }};
assign stm = 1'b0;
*/
//-------------------------------------------------------------------------------------------------

wire      strb;
wire      make;
wire[7:0] code;
ps2k ps2k(clock, { ps2kDQ, ps2kCk }, strb, make, code);

wire[2:0] btns;
wire[7:0] xaxis;
wire[7:0] yaxis;
ps2m ps2m(clock, reset, { ps2mDQ, ps2mCk }, btns, xaxis, yaxis);

reg F9 = 1'b1;
reg F5 = 1'b1;
always @(posedge clock) if(strb)
	case(code)
		8'h01: F9 <= make;
		8'h03: F5 <= make;
	endcase

//-------------------------------------------------------------------------------------------------

wire reset = power & F9;
wire nmi = F5;

wire cepix;
wire cecpu;

wire hblank;
wire vblank;
wire hsync;
wire vsync;
wire r;
wire g;
wire b;
wire i;

wire ear = tape;

wire[14:0] left;
wire[14:0] right;

wire[13:0] memA1;
wire[ 7:0] memQ1;
wire       memW2;
wire[17:0] memA2;
wire[ 7:0] memD2;
wire[ 7:0] memQ2;

zx zx
(
	.clock  (clock  ),
	.power  (power  ),
	.reset  (reset  ),
	.nmi    (nmi    ),
	.cepix  (cepix  ),
	.cecpu  (cecpu  ),
	.hblank (hblank ),
	.vblank (vblank ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      ),
	.ear    (ear    ),
	.left   (left   ),
	.right  (right  ),
	.strb   (strb   ),
	.make   (make   ),
	.code   (code   ),
	.mbtns  (btns   ),
	.xaxis  (xaxis  ),
	.yaxis  (yaxis  ),
	.cs     (sdcCs  ),
	.ck     (sdcCk  ),
	.mosi   (sdcMosi),
	.miso   (sdcMiso),
	.fddMtr (       ),
	.fddIoRd(       ),
	.fddIoWr(       ),
	.fddIoA (       ),
	.fddIoD (       ),
	.fddIoQ (8'hFF  ),
	.memA1  (memA1  ),
	.memQ1  (memQ1  ),
	.memR2  (       ),
	.memW2  (memW2  ),
	.memA2  (memA2  ),
	.memD2  (memD2  ),
	.memQ2  (memQ2  )
);

//-------------------------------------------------------------------------------------------------

always @(posedge clock) if(cepix) rgbCk <= ~rgbCk;

assign rgbEn = ~(hblank|vblank);
assign sync = { 1'b1, ~(vsync^hsync) };
assign rgb = rgbEn ? { r,r,{6{r&i}}, g,g,{6{g&i}}, b,b,{6{b&i}} } : 1'd0;

//-------------------------------------------------------------------------------------------------

wire[15:0] lmix = { 1'd0,  left };
wire[15:0] rmix = { 1'd0, right };
i2s i2s(clock, { i2sD, i2sW, i2sCk }, lmix, rmix);

//-------------------------------------------------------------------------------------------------

wire dprW2 = memW2 && memA2[17] && (memA2[16:14] == 5 || memA2[16:14] == 7);
dprs #(16) drp(clock, memA1, memQ1, dprW2, memA2[13:0], memD2);

wire[7:0] romQ;
rom_zxp3 rom(clock, memA2[15:0], romQ);

assign sramWe = !(memA2[17] && memW2);
assign sramDQ = sramWe ? 8'bZ : memD2;
assign sramA = { 3'd0, memA2 };

assign memQ2 = memA2[17] ? sramDQ : romQ;

assign led = ~{ reset, power };
assign stm = 1'b0;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
