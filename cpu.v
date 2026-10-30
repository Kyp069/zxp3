//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module cpu
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       ne,
	input  wire       pe,
	input  wire       reset,
	output wire       iorq,
	output wire       mreq,
	output wire       rfsh,
	input  wire       wayt,
	input  wire       irq,
	input  wire       nmi,
	output wire       m1,
	output wire       rd,
	output wire       wr,
	output wire[15:0] a,
	input  wire[ 7:0] d,
	output wire[ 7:0] q
);
//-------------------------------------------------------------------------------------------------

T80pa Cpu
(
	.CLK    (clock  ),
	.CEN_n  (ne     ),
	.CEN_p  (pe     ),
	.RESET_n(reset  ),
	.BUSRQ_n(1'b1   ),
	.WAIT_n (wayt   ),
	.BUSAK_n(       ),
	.HALT_n (       ),
	.IORQ_n (iorq   ),
	.MREQ_n (mreq   ),
	.RFSH_n (rfsh   ),
	.INT_n  (irq    ),
	.NMI_n  (nmi    ),
	.M1_n   (m1     ),
	.RD_n   (rd     ),
	.WR_n   (wr     ),
	.A      (a      ),
	.DI     (d      ),
	.DO     (q      ),
	.DIRSet (1'b0   ),
	.DIR    (212'd0 ),
	.OUT0   (1'b0   ),
	.REG    (       ),
	.R800_mode(1'b0 )
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
