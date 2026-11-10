//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module zxp3
//-------------------------------------------------------------------------------------------------
(
	input  wire       divmmc,
	input  wire       timing,

	input  wire       clock, // 56.7504 MHz
	input  wire       ne7M0,
	input  wire       pe7M0,
	input  wire       ne3M5,
	input  wire       pe3M5,

	input  wire       reset,
	output wire       rfsh,
	input  wire       nmi,

	output wire[13:0] a1,
	input  wire[ 7:0] q1,
	output wire       w1,

	output wire[18:0] a2,
	output wire[ 7:0] d2,
	input  wire[ 7:0] q2,
	output wire       r2,
	output wire       w2,

	output wire       r,
	output wire       g,
	output wire       b,
	output wire       i,
	output wire       hsync,
	output wire       vsync,

	input  wire       ear,
	output wire       midi,
	output wire[14:0] left, 
	output wire[14:0] right,

	input  wire[ 4:0] col,
	output wire[ 7:0] row,

	input  wire[ 7:0] joy1,
	input  wire[ 7:0] joy2,

	input  wire[ 2:0] mbtns,
	input  wire[ 7:0] xaxis,
	input  wire[ 7:0] yaxis,

	output wire       fddCe,
	output wire       fddRd,
	output wire       fddWr,
	output wire       fddA,
	output wire[ 7:0] fddD,
	input  wire[ 7:0] fddQ,
	output wire       fddMtr,

	output wire       sdcCs,
	output wire       sdcCk,
	output wire       sdcMosi,
	input  wire       sdcMiso
);
//--- io ------------------------------------------------------------------------------------------

	wire iorq;
	wire mreq;
	wire m1;
	wire rd;
	wire wr;

	wire[15:0] a;
	wire[ 7:0] q;

	wire iorq0FFD = !iorq && a[15:12] == 0 && !a[1];
	wire iorq1FFD = !iorq && a[15:12] == 1 && !a[1];
	wire iorq3FFD = !iorq && a[15:13] == 1 && !a[1];
	wire iorq7FFD = !iorq && a[15:14] == 1 && !a[1];
	wire iorqFFFD = !iorq && a[15:14] == 3 && !a[1];
	wire iorqFADF = !iorq && a[ 9:8] == 2'b10  && !a[5] && kmouse;
	wire iorqFBDF = !iorq && a[10:8] == 3'b011 && !a[5] && kmouse;
	wire iorqFFDF = !iorq && a[10:8] == 3'b111 && !a[5] && kmouse;
	wire iorq1F = !iorq && !a[7] && !a[6] && !a[5];
	wire iorq37 = !iorq && !a[7] && !a[6] && !a[3];
	wire iorqEB = !iorq && (a[7:0] == 8'h3F || a[7:0] == 8'hEB);
	wire iorqFE = !iorq && !a[0];

	reg[3:0] data1FFD;
	always @(posedge clock, negedge reset)
		if(!reset) data1FFD <= 1'd0; else if(pe3M5) if(iorq1FFD && !wr) data1FFD <= q[3:0];

	reg[5:0] data7FFD;
	always @(posedge clock, negedge reset)
		if(!reset) data7FFD <= 1'd0; else if(pe3M5) if(iorq7FFD && !wr) data7FFD <= { data7FFD[5]|q[5], q[4:0] };

	reg[4:0] dataFE;
	always @(posedge clock) if(ne7M0) if(iorqFE && !wr) dataFE <= q[4:0];

	reg kmouse;
	always @(posedge clock) if(pe3M5) if(joy1[5:4] || joy2[5:4]) kmouse <= 1'b0; else if(~mbtns) kmouse <= 1'b1;

	assign row = a[15:8];

//--- video ---------------------------------------------------------------------------------------

	wire[ 2:0] border = dataFE[2:0];
	wire       busy;
	wire       vrd;
	wire[12:0] va;
	wire       vi;

	vdu vdu
	(
		.timing (timing ),
		.clock  (clock  ),
		.ce     (ne7M0  ),
		.border (border ),
		.busy   (busy   ),
		.irq    (vi     ),
		.rd     (vrd    ),
		.a      (va     ),
		.d      (q1     ),
		.r      (r      ),
		.g      (g      ),
		.b      (b      ),
		.i      (i      ),
		.hsync  (hsync  ),
		.vsync  (vsync  )
	);

	assign a1 = { data7FFD[3], va };
	assign w1 = !mreq && !wr && a2[18:17] == 2 && a2[16] && a2[14] && !a2[13];

//--- sound ---------------------------------------------------------------------------------------

	wire[ 7:0] tbsQ;
	wire[14:0] tbsL;
	wire[14:0] tbsR;

	turbosound turbosound(clock, pe3M5, reset, iorq, wr, rd, { a[15:14], a[1] }, q, tbsQ, midi, tbsL, tbsR);

	wire[11:0] sound = dataFE[4:3] == 3 ? 12'd4095 : dataFE[4:3] == 2 ? 12'd3874 : dataFE[4:3] == 1 ? 12'd775 : 12'd0;

	assign left  = { 3'd0, sound }+tbsL;
	assign right = { 3'd0, sound }+tbsR;

//--- floppy --------------------------------------------------------------------------------------

	assign fddCe = pe3M5;
	assign fddRd = !(iorq3FFD && !rd);
	assign fddWr = !(iorq3FFD && !wr);
	assign fddA = a[12];
	assign fddD = q;
	assign fddMtr = data1FFD[3];

//--- divmmc --------------------------------------------------------------------------------------

	wire      mapped;
	wire      ramcs;
	wire[3:0] page;

	mapper mapper
	(
		.enable (divmmc ),
		.clock  (clock  ),
		.ce     (pe3M5  ),
		.mapped (mapped ),
		.ramcs  (ramcs  ),
		.page   (page   ),
		.reset  (reset  ),
		.iorq   (iorq   ),
		.mreq   (mreq   ),
		.m1     (m1     ),
		.wr     (wr     ),
		.a      (a      ),
		.d      (q      )
	);

	wire[7:0] sdcQ;

	sdc sdc
	(
		.enable (1'b1   ),
		.clock  (clock  ),
		.ce     (pe3M5  ),
		.cen    (ne7M0  ),
		.cep    (pe7M0  ),
		.reset  (reset  ),
		.iorq   (iorq   ),
		.rd     (rd     ),
		.wr     (wr     ),
		.a      (a[7:0] ),
		.d      (q      ),
		.q      (sdcQ   ),
		.cs     (sdcCs  ),
		.ck     (sdcCk  ),
		.mosi   (sdcMosi),
		.miso   (sdcMiso)
	);

//--- memory --------------------------------------------------------------------------------------

	reg[2:0] allramPage;
	always @(*) case({ data1FFD[2:1], a[15:14] })
		4'h0: allramPage = 3'd0;
		4'h1: allramPage = 3'd1;
		4'h2: allramPage = 3'd2;
		4'h3: allramPage = 3'd3;
		4'h4: allramPage = 3'd4;
		4'h5: allramPage = 3'd5;
		4'h6: allramPage = 3'd6;
		4'h7: allramPage = 3'd7;
		4'h8: allramPage = 3'd4;
		4'h9: allramPage = 3'd5;
		4'hA: allramPage = 3'd6;
		4'hB: allramPage = 3'd3;
		4'hC: allramPage = 3'd4;
		4'hD: allramPage = 3'd7;
		4'hE: allramPage = 3'd6;
		4'hF: allramPage = 3'd3;
	endcase

	wire[2:0] romPage = mapped ? 3'd4 : { 1'b0, data1FFD[2], data7FFD[4] };
	wire[2:0] ramPage = a[15] ? (a[14] ? data7FFD[2:0] : 3'd2) : 3'd5;

	assign a2 = data1FFD[0] ? { 2'd2, allramPage, a[13:0] } : a[15:14] ? { 2'd2, ramPage, a[13:0] } : mapped && ramcs ? { 2'd1, page, a[12:0] } : { 2'd0, romPage, a[13:0] };
	assign d2 = q;
	assign r2 = !mreq && !rd;
	assign w2 = !mreq && !wr && (data1FFD[0] || a[15:14] || (mapped && ramcs && a[13]));

//--- cpu -----------------------------------------------------------------------------------------

	reg[7:1] fb;
	always @(posedge clock, negedge reset) if(!reset) fb <= 7'h7F; else
		if(pe7M0) if(vrd) fb <= q1[7:1]; else if(!mreq && (!wr || |rd) && a[15:13] == 2) fb <= q[7:1];

	wire wayt = !(busy && !mreq && ((!a[15] && a[14]) || (a[15] && a[14] && ramPage >= 4)));

	reg irq = 1'b1;
	always @(posedge clock, negedge reset) if(!reset) irq <= 1'b1; else if(pe3M5) irq <= !vi;

	wire[7:0] d
		= !mreq ? q2
		: iorq3FFD ? fddQ
		: iorqFFFD ? tbsQ
		: iorqFADF ? { 5'h1F, mbtns }
		: iorqFBDF ? xaxis
		: iorqFFDF ? yaxis
		: iorq1F ? joy1
		: iorq37 ? joy2
		: iorqEB ? sdcQ
		: iorqFE ? { 1'b0, ear, 1'b0, col }
		: iorq0FFD && !data7FFD[5] ? { fb, 1'b1 }
		: 8'hFF;

	cpu cpu
	(
		.clock  (clock  ),
		.ne     (ne3M5  ),
		.pe     (pe3M5  ),
		.reset  (reset  ),
		.iorq   (iorq   ),
		.mreq   (mreq   ),
		.rfsh   (rfsh   ),
		.wayt   (wayt   ),
		.irq    (irq    ),
		.nmi    (nmi    ),
		.m1     (m1     ),
		.rd     (rd     ),
		.wr     (wr     ),
		.a      (a      ),
		.d      (d      ),
		.q      (q      )
	);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
