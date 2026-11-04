//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module sdc
//-------------------------------------------------------------------------------------------------
(
	input  wire      enable,

	input  wire      clock,
	input  wire      ce,
	input  wire      cen,
	input  wire      cep,

	input  wire      reset,
	input  wire      iorq,
	input  wire      rd,
	input  wire      wr,
	input  wire[7:0] a,
	input  wire[7:0] d,
	output wire[7:0] q,

	output reg       cs,
	output wire      ck,
	output wire      mosi,
	input  wire      miso
);
//-------------------------------------------------------------------------------------------------

always @(posedge clock, negedge reset)
	if(!reset) cs <= 1'b1; else if(ce) if(!iorq && !wr && (a == 8'h1F || a == 8'hE7)) cs <= d[0];

//-------------------------------------------------------------------------------------------------

reg iod, iop;
wire iorqEB = !iorq && (a == 8'h3F || a == 8'hEB) && (!rd || !wr);
always @(posedge clock) if(cep) begin iod <= iorqEB; iop <= iorqEB && !iod; end

//-------------------------------------------------------------------------------------------------

wire[7:0] spiD = !wr ? d : 8'hFF;

spi Spi
(
	.clock  (clock  ),
	.ce     (cen    ),
	.io     (iop    ),
	.d      (spiD   ),
	.q      (q      ),
	.ck     (ck     ),
	.mosi   (mosi   ),
	.miso   (miso   )
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
