//-------------------------------------------------------------------------------------------------
module flash
//-------------------------------------------------------------------------------------------------
(
	input  wire clock,

	output reg  vga,

	output reg  cs,
	output wire ck,
	output wire rst,
	output wire mosi,
	input  wire miso
);
//-------------------------------------------------------------------------------------------------

reg[3:0] ce = 0;
always @(negedge clock) ce <= ce+1'd1;

wire pe = ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ne = ~ce[0] & ~ce[1] & ~ce[2];

//-------------------------------------------------------------------------------------------------

reg io;

reg[7:0] d;
reg[8:0] fc = 0;

always @(posedge clock) if(pe)
if(!fc[8]) begin
	fc <= fc+1'd1;

	case(fc)
		 0: cs <= 1'b1;
		15: cs <= 1'b0;

		16: begin io <= 1'b1; d <= 8'hE9; end // 8'hE9 (exit 4 bit mode)
		17: begin io <= 1'b0; end

		32: cs <= 1'b1;
		33: cs <= 1'b0;

		48: begin io <= 1'b1; d <= 8'h03; end // 8'h03 (read 00704D)
		49: begin io <= 1'b0; end

		64: begin io <= 1'b1; d <= 8'h00; end // 8'h00
		65: begin io <= 1'b0; end

		80: begin io <= 1'b1; d <= 8'h70; end // 8'h70
		81: begin io <= 1'b0; end

		96: begin io <= 1'b1; d <= 8'h4D; end // 8'h4D
		97: begin io <= 1'b0; end

		112: begin io <= 1'b1; d <= 8'hFF; end
		113: begin io <= 1'b0; end

		128: vga <= q[1:0] == 2'b10;
		129: cs <= 1'b1;
	endcase
end

//-------------------------------------------------------------------------------------------------

reg[4:0] count = 5'b10000;
always @(posedge clock) if(ne) if(!count[4]) count <= count+1'd1; else if(io) count <= 1'd0;

reg[7:0] q;
always @(posedge clock) if(ne) if(count[0]) q <= { q[6:0], miso }; else if(count[4]) if(io) q <= d;

assign ck = count[0];
assign rst = cs ? 1'bZ : 1'b1;
assign mosi = q[7];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
