//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module mapper
//-------------------------------------------------------------------------------------------------
(
	input  wire       enable,

	input  wire       clock,
	input  wire       ce,

	output wire       mapped,
	output wire       ramcs,
	output wire[ 3:0] page,
	
	input  wire       reset,
	input  wire       iorq,
	input  wire       mreq,
	input  wire       m1,
	input  wire       wr,
	input  wire[15:0] a,
	input  wire[ 7:0] d
);
//-------------------------------------------------------------------------------------------------

wire iorqE3 = !iorq && a[7:0] == 8'hE3;

reg[7:0] dataE3;
always @(posedge clock, negedge reset) if(!reset) dataE3 <= 1'd0; else if(ce) if(iorqE3 && !wr && !dataE3[6]) dataE3 <= d;

wire forcemap = dataE3[7];
wire mapram = dataE3[6];
wire[3:0] mappage = dataE3[3:0];

//-------------------------------------------------------------------------------------------------

wire addr =
	a == 16'h0000 || // reset
	a == 16'h0008 || // rst 8
	a == 16'h0038 || // int
	a == 16'h0066 || // nmi
	a == 16'h04C6 || // load
	a == 16'h0562;   // save

reg automap, m1on;
always @(posedge clock, negedge reset)
	if(!reset) { automap, m1on } <= 1'd0;
	else if(ce)
		if(!mreq)
			if(!m1) begin
				if(addr) m1on <= 1'b1; // activate automapper after this cycle
				else if(a[15:3] == 13'h3FF) m1on <= 1'b0; // deactivate automapper after this cycle
				else if(a[15:8] == 8'h3D) { automap, m1on } <= 2'b11; // activate automapper immediately
			end
			else automap <= m1on;

//-------------------------------------------------------------------------------------------------

assign mapped = forcemap || (automap && enable);
assign ramcs = a[13] || mapram;
assign page = !a[13] && mapram ? 4'd3 : mappage;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
