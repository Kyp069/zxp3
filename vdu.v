//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module vdu
//-------------------------------------------------------------------------------------------------
(
	input  wire       timing,
	
	input  wire       clock,
	input  wire       ce,

	input  wire[ 2:0] border,
	output wire       busy,
	output wire       irq,
	output wire       rd,
	output wire[12:0] a,
	input  wire[ 7:0] d,

	output wire       r,
	output wire       g,
	output wire       b,
	output wire       i,
	output wire       hsync,
	output wire       vsync
);
//-------------------------------------------------------------------------------------------------

wire[8:0] hCountEnd = timing ? 9'd448 : 9'd456;
wire[8:0] vCountEnd = timing ? 9'd312 : 9'd311;

wire[8:0] irqBeg = 0;
wire[8:0] irqEnd = 64;

//-------------------------------------------------------------------------------------------------

reg[8:0] hCount;
wire hCountReset = hCount >= (hCountEnd-1);
always @(posedge clock) if(ce) if(hCountReset) hCount <= 1'd0; else hCount <= hCount+1'd1;

reg[8:0] vCount;
wire vCountReset = vCount >= (vCountEnd-1);
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) vCount <= 1'd0; else vCount <= vCount+1'd1;

reg[4:0] fCount;
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) fCount <= fCount+1'd1;

//-------------------------------------------------------------------------------------------------

wire dataEnable = hCount < 256 && vCount < 192;

reg videoEnable;
wire videoEnableLoad = hCount[3];
always @(posedge clock) if(ce) if(videoEnableLoad) videoEnable <= dataEnable;

//-------------------------------------------------------------------------------------------------

reg[7:0] dataInput;
wire dataInputLoad = (hCount[3:0] ==  9 || hCount[3:0] == 13) && dataEnable;
always @(posedge clock) if(ce) if(dataInputLoad) dataInput <= d;

reg[7:0] attrInput;
wire attrInputLoad = (hCount[3:0] == 11 || hCount[3:0] == 15) && dataEnable;
always @(posedge clock) if(ce) if(attrInputLoad) attrInput <= d;

reg[7:0] dataOutput;
wire dataOutputLoad = hCount[2:0] == 4 && videoEnable;
always @(posedge clock) if(ce) if(dataOutputLoad) dataOutput <= dataInput; else dataOutput <= { dataOutput[6:0], 1'b0 };

reg[7:0] attrOutput;
wire attrOutputLoad = hCount[2:0] == 4;
always @(posedge clock) if(ce) if(attrOutputLoad) attrOutput <= { videoEnable ? attrInput[7:3] : { 2'b00, border }, attrInput[2:0] };

wire dataSelect = dataOutput[7] ^ (fCount[4] & attrOutput[7]);

//-------------------------------------------------------------------------------------------------

wire blank = (hCount >= 320 && hCount < 416) || (vCount >= 248 && vCount < 256);

assign busy = (dataEnable && hCount[3:0] >= 3) || (vCount == (vCountEnd-1) && hCount >= (hCountEnd-2));
assign irq = vCount == 248 && hCount >= irqBeg && hCount < irqEnd;
assign rd = dataEnable && hCount[3] && hCount[0];
assign a = { !hCount[1] ? { vCount[7:6], vCount[2:0] } : { 3'b110, vCount[7:6] }, vCount[5:3], hCount[7:4], hCount[2] };

assign r = blank ? 1'b0 : dataSelect ? attrOutput[1] : attrOutput[4];
assign g = blank ? 1'b0 : dataSelect ? attrOutput[2] : attrOutput[5];
assign b = blank ? 1'b0 : dataSelect ? attrOutput[0] : attrOutput[3];
assign i = attrOutput[6];

assign hsync = hCount >= 344 && hCount < 376;
assign vsync = vCount >= 248 && vCount < 252;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
