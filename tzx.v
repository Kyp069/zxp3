//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module tzx
//-------------------------------------------------------------------------------------------------
#
(
	parameter MS = 0,
	parameter AW = 0
)
(
	input  wire         clock,
	input  wire         ce,

	output reg [AW-1:0] a,
	input  wire[   7:0] d,

	input  wire         play,
	input  wire         stop,
	output wire         busy,
	input  wire[AW-1:0] size,
	output wire         tape
);
//-------------------------------------------------------------------------------------------------

reg  ack;
wire req;
wire eot;
wire eot48;
reg  motor;
reg  restart;

reg reqd;
always @(posedge clock) reqd <= req;

reg stb;
always @(posedge clock) stb <= req != reqd;

reg[7:0] data;
always @(posedge clock) begin
	restart <= 1'b0;
	if(play) begin
		a <= 1'd0;
		ack <= 1'b1;
		motor <= 1'b1;
		restart <= 1'b1;
	end
	if(stop || eot || eot48 || a == size) begin
		ack <= 1'b0;
		motor <= 1'b0;
	end
	if(stb) begin
		a <= a+1'd1;
		ack <= req;
		data <= d;
	end
end

tzxplayer #(.TZX_MS(MS)) tzxplayer
(
	.clk         (clock  ),
	.ce          (ce     ),
	.tzx_ack     (ack    ),
	.tzx_req     (req    ),
	.host_tap_in (data   ),
	.cass_motor  (motor  ),
	.restart_tape(restart),
	.loop_start  (       ),
	.loop_next   (       ),
	.stop        (eot    ),
	.stop48k     (eot48  ),
	.cass_read   (tape   ),
	.cass_running(busy   )
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
