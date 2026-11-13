//-------------------------------------------------------------------------------------------------
module scandoubler
//-------------------------------------------------------------------------------------------------
#
(
	parameter HCW  = 9,   // horizontal counter width
	parameter RGBW = 18   // rgb width
)
(
	input  wire           clock,
	input  wire           novga,

	input  wire           ice,
	input  wire[     1:0] isync,
	input  wire[RGBW-1:0] irgb,

	input  wire           oce,
	output wire[     1:0] osync,
	output wire[RGBW-1:0] orgb
);
//-------------------------------------------------------------------------------------------------

reg iHSyncDelayed, iHSyncPosedge, iHSyncNegedge;
always @(posedge clock) if(ice) begin
	iHSyncDelayed <= isync[0];
	iHSyncPosedge <= !iHSyncDelayed && isync[0];
	iHSyncNegedge <= iHSyncDelayed && !isync[0];
end

reg iVSyncDelayed, iVSyncNegedge;
always @(posedge clock) if(ice) begin
	iVSyncDelayed <= isync[1];
	iVSyncNegedge <= iVSyncDelayed && !isync[1];
end

reg oHSyncDelayed, oHSyncPosedge;
always @(posedge clock) if(oce) begin
	oHSyncDelayed <= isync[0];
	oHSyncPosedge <= !oHSyncDelayed && isync[0];
end

//-------------------------------------------------------------------------------------------------

reg[HCW-1:0] iHCount;
always @(posedge clock) if(ice) if(iHSyncNegedge) iHCount <= 1'd0; else iHCount <= iHCount+1'd1;

reg[HCW-1:0] iHSyncBeg;
always @(posedge clock) if(ice) if(iHSyncPosedge) iHSyncBeg <= iHCount;

reg[HCW-1:0] iHSyncEnd;
always @(posedge clock) if(ice) if(iHSyncNegedge) iHSyncEnd <= iHCount;

reg line;
always @(posedge clock) if(ice) if(iVSyncNegedge) line <= 0; else if(iHSyncNegedge) line <= ~line;

//-------------------------------------------------------------------------------------------------

reg[HCW-1:0] oHCount;
always @(posedge clock) if(oce) if(oHSyncPosedge) oHCount <= iHSyncEnd-(iHSyncEnd-iHSyncBeg); else if(oHCount == iHSyncEnd) oHCount <= 0; else oHCount <= oHCount+1'd1;

//-------------------------------------------------------------------------------------------------

reg ohs;
always @(posedge clock) if(oce) if(oHCount == iHSyncBeg) ohs <= 1'b1; else if(oHCount == iHSyncEnd) ohs <= 1'b0;

//-------------------------------------------------------------------------------------------------

// Xilinx: set parameter -infer_ramb8 No in XST to avoid PhysDesignRules:2410 warning

reg[RGBW-1:0] brgb;
reg[RGBW-1:0] buffer[0:(2*2**HCW)-1]; // 2 lines of 2**HCW pixels of RGBW words

always @(posedge clock) if(ice) buffer[{ line, iHCount }] <= irgb;
always @(posedge clock) if(oce) brgb <= buffer[{ ~line, oHCount }];

assign osync = novga ? { 1'b1, ~^isync } : { isync[1], ohs };
assign orgb = novga ? irgb : brgb;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
