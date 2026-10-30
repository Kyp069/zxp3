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
	inout  reg [15:0] dramDQ,
	output reg [ 1:0] dramBA,
	output reg [12:0] dramA
);
//-------------------------------------------------------------------------------------------------
`include "sdram_cmd.v"
//-------------------------------------------------------------------------------------------------

reg rfshd = 1'b1, rfshp = 1'b0;
always @(negedge clock) begin rfshd <= rfsh; rfshp <= !rfsh && rfshd; end

reg rdd = 1'b0, rdp = 1'b0;
always @(negedge clock) begin rdd <= rd; rdp <= rd && !rdd; end

reg wrd = 1'b0, wrp = 1'b0;
always @(negedge clock) begin wrd <= wr; wrp <= wr && !wrd; end

//-------------------------------------------------------------------------------------------------

initial ready = 0;

localparam sIDLE = 0;
localparam sREAD = 1;
localparam sWRITE = 2;
localparam sREFRESH = 3;

reg counting = 1'b0;
reg[13:0] count = 1'd0;
reg[ 1:0] state = sIDLE;

always @(posedge clock) begin
	NOP;
	if(counting) count <= count+1'd1; else count <= 1'd0;
	if(!ready) begin
		counting <= 1'b1;
		case(count)
			12000: PRECHARGE(2'b00, 1'b1);		// PRECHARGE: all, tRP's minimum value is 20ns
			12008: LMR(13'b000_1_00_010_0_000);	// LDM: CL = 2, BT = seq, BL = 1, 20ns
			12016: REFRESH;						// REFRESH, tRFC's minimum value is 60ns
			12024: REFRESH;						// REFRESH, tRFC's minimum value is 60ns
			12032: REFRESH;						// REFRESH, tRFC's minimum value is 60ns
			12040: REFRESH;						// REFRESH, tRFC's minimum value is 60ns
			12048: REFRESH;						// REFRESH, tRFC's minimum value is 60ns
			12056: REFRESH;						// REFRESH, tRFC's minimum value is 60ns
			12064: REFRESH;						// REFRESH, tRFC's minimum value is 60ns
			12072: REFRESH;						// REFRESH, tRFC's minimum value is 60ns
			12080: ready <= 1'b1;
		endcase
	end
	else
		case(state)
		/*	sIDLE: begin
				counting <= 1'b0;
				if(rdp) state <= sREAD; else
				if(wrp) state <= sWRITE; else
				if(rfshp) state <= sREFRESH;
			end
			sREAD: begin
				counting <= 1'b1;
				case(count)
				0: ACTIVE(a[23:22], a[21:9]);
				3: READ(a[23:22], a[8:0], 2'b00, 1'b1);
				6: q <= dramDQ;
				7: state <= sIDLE;
				endcase
			end
			sWRITE: begin
				counting <= 1'b1;
				case(count)
				0: ACTIVE(a[23:22], a[21:9]);
				3: WRITE(a[23:22], a[8:0], 2'b00, d, 1'b1);
				7: state <= sIDLE;
				endcase
			end
			sREFRESH: begin
				counting <= 1'b1;
				case(count)
				1: REFRESH;
				7: state <= sIDLE;
				endcase
			end*/
		sIDLE: begin
			counting <= 1'b0;
			if(rdp)   begin ACTIVE(a[23:22], a[21:9]); state <= sREAD; end else
			if(wrp)   begin ACTIVE(a[23:22], a[21:9]); state <= sWRITE; end else
			if(rfshp) begin REFRESH; state <= sREFRESH; end
		end
		sREAD: begin
			counting <= 1'b1;
			case(count)
				0: READ(a[23:22], a[8:0], 2'b00, 1'b1);
				2: begin q <= dramDQ; state <= sIDLE; end
			endcase
		end
		sWRITE: begin
			counting <= 1'b1;
			case(count)
				0: WRITE(a[23:22], a[8:0], 2'b00, d, 1'b1);
				2: state <= sIDLE;
			endcase
		end
		sREFRESH: begin
			counting <= 1'b1;
			case(count)
				2: state <= sIDLE;
			endcase
		end
	endcase
end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
