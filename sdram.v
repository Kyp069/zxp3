//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module sdram
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	output reg        ready,

	input  wire       rfsh,
	input  wire       rd,
	input  wire       wr,
	input  wire[23:0] a,
	input  wire[15:0] d,
	output reg [15:0] q,

	output reg        dramCe,
	output reg        dramCs,
	output reg        dramWe,
	output reg        dramRas,
	output reg        dramCas,
	output reg [ 1:0] dramDQM,
	inout  wire[15:0] dramDQ,
	output reg [ 1:0] dramBA,
	output reg [12:0] dramA
);
//-------------------------------------------------------------------------------------------------
`include "sdram_cmd.v"
//-------------------------------------------------------------------------------------------------

reg rdd = 1'b0, rdp = 1'b0;
always @(posedge clock) begin rdd <= rd; rdp <= rd && !rdd; end

reg wrd = 1'b0, wrp = 1'b0;
always @(posedge clock) begin wrd <= wr; wrp <= wr && !wrd; end

reg rfshd = 1'b0, rfshp = 1'b0;
always @(posedge clock) begin rfshd <= rfsh; rfshp <= !rfsh && rfshd; end

//-------------------------------------------------------------------------------------------------

initial ready = 0;

localparam sIDLE = 0;
localparam sREAD = 1;
localparam sWRITE = 2;
localparam sREFRESH = 3;

reg[13:0] count = 1'd0;
reg[ 1:0] state = sIDLE;

always @(negedge clock) begin
	NOP;
	count <= count+1'd1;
	if(!ready)
		case(count)
			11200: PRECHARGE(2'b00, 1'b1);
			11208: LMR(14'b0000_1_00_010_0_000);
			11216: REFRESH;
			11224: REFRESH;
			11232: REFRESH;
			11240: REFRESH;
			11248: REFRESH;
			11256: REFRESH;
			11264: REFRESH;
			11272: REFRESH;
			11280: ready <= 1'b1;
		endcase
	else
		case(state)
			sIDLE: begin
				count <= 1'd0;
				if(rdp) begin ACTIVE(a[23:22], a[21:9]); state <= sREAD; end else
				if(wrp) begin ACTIVE(a[23:22], a[21:9]); state <= sWRITE; end else
				if(rfshp) begin REFRESH; state <= sREFRESH; end
			end
			sREAD:
				case(count)
					0: READ(2'b00, a[23:22], a[8:0], 1'b1);
					3: begin q <= dramDQ; state <= sIDLE; end
				endcase
			sWRITE:
				case(count)
					0: WRITE(2'b00, a[23:22], a[8:0], 1'b1);
					3: state <= sIDLE;
				endcase
			sREFRESH:
				case(count)
					3: state <= sIDLE;
				endcase
		endcase
end

//-------------------------------------------------------------------------------------------------

assign dramDQ = dramWe ? 16'bZ : d;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
