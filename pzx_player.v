//-------------------------------------------------------------------------------------------------
// Reproductor de ficheros PZX (formato de Patrik Rak, versión 1.0).
// Shaeon (Carlos Palmero) para el core zxp3 de Kyp.
//
// Un PZX es una lista de bloques: etiqueta (4 bytes) + tamaño (4 bytes, LE) + contenido.
//   PULS  secuencia de pulsos (duración en T-estados); el bloque empieza en nivel bajo
//   DATA  bits con su codificación (secuencias de pulsos del 0 y del 1), nivel inicial y pulso final
//   PAUS  pausa con su nivel
//   STOP  parar la cinta (flags = 1: solo en modo 48K); al volver a pulsar Play sigue
//   otros (PZXT, BRWS...) se saltan
// Cada pulso mantiene el nivel durante su duración y al terminar lo invierte; un pulso de duración
// 0 lo invierte sin esperar.
//
// Los bytes se leen por un puerto de memoria con handshake (mReq != mAck: petición pendiente; el
// dato es válido en mQ cuando mAck vuelve a valer mReq). Mientras suena un pulso se prepara el
// siguiente, así que la latencia de la memoria no alarga los pulsos.
//-------------------------------------------------------------------------------------------------
module pzx_player
#(
	parameter TS = 16                       // ciclos de reloj por T-estado (56 MHz / 3,5 MHz)
)
(
	input  wire       clock,

	input  wire       play,                 // empieza desde el principio (o sigue tras un STOP)
	input  wire       stop,
	input  wire       stop48,               // 1: los STOP "solo en 48K" también paran
	input  wire[21:0] size,                 // tamaño del fichero en bytes
	output wire       busy,
	output reg        tape = 1'b0,          // señal EAR

	output reg        mReq = 1'b0,
	input  wire       mAck,
	output reg [21:0] mA,
	input  wire[ 7:0] mQ
);
//--- siguiente pulso (lo prepara la máquina de estados mientras suena el actual) -----------------

	reg        nValid = 1'b0;
	reg        nSet;                        // fijar el nivel al empezar el pulso
	reg        nLevel;
	reg [30:0] nDur;                        // duración en T-estados
	reg        nToggle;                     // invertir el nivel al terminar

	reg        resume = 1'b0;               // parada por un bloque STOP: Play sigue

//--- motor de pulsos -----------------------------------------------------------------------------

	reg        pActive = 1'b0;
	reg [30:0] pCnt = 31'd0;
	reg        pToggle = 1'b0;
	reg [ 7:0] div = 8'd0;
	wire       tick = div == TS-1;

	wire       pRunning = pActive && pCnt != 0;
	wire       take = !(play || stop) && !pRunning && nValid;

	reg        lvl;
	always @(posedge clock) begin
		div <= tick ? 8'd0 : div+1'd1;

		if(play || stop) begin
			pActive <= 1'b0;
			pCnt <= 31'd0;
			if(play && !resume) tape <= 1'b0;
		end
		else if(pRunning) begin
			if(tick) pCnt <= pCnt-1'd1;
		end
		else begin
			// el pulso actual (si lo hay) ha terminado
			lvl = tape;
			if(pActive && pToggle) lvl = ~lvl;
			if(nValid) begin
				if(nSet) lvl = nLevel;
				if(nDur == 0) begin
					if(nToggle) lvl = ~lvl;
					pActive <= 1'b0;
				end
				else begin
					pActive <= 1'b1;
					pCnt <= nDur;
					pToggle <= nToggle;
				end
			end
			else pActive <= 1'b0;
			tape <= lvl;
		end
	end

//--- lectura de bytes ----------------------------------------------------------------------------

	reg [21:0] a = 22'd0;                   // siguiente byte del fichero
	reg        rdBusy = 1'b0;
	reg        rdIssued = 1'b0;
	reg [ 2:0] rdN;                         // bytes que quedan por leer
	reg [31:0] acc;                         // valor leído: el último byte entra por arriba
	wire       memReady = mReq == mAck;
	wire[15:0] w16 = acc[31:16];

//--- máquina de estados --------------------------------------------------------------------------

	localparam [4:0]
		sIDLE = 0, sNEXT = 1, sTAG = 2, sSIZE = 3,
		sPULS = 4, sPW1 = 5, sPW2 = 6, sPW3 = 7, sPOUT = 8,
		sDCNT = 9, sDTAIL = 10, sDP = 11, sDS = 12, sDS2 = 13,
		sDB = 14, sDB2 = 15, sDBIT = 16, sDPW = 17, sDPUL = 18, sDT = 19,
		sPAUS = 20, sSTOP = 21, sDRAIN = 22, sSTOPPED = 23;

	reg [ 4:0] state = sIDLE;
	reg [31:0] tag;
	reg [21:0] blkEnd;

	// PULS
	reg [14:0] rep;
	reg [14:0] dhi;
	reg [30:0] dur;
	reg        first;                       // primer pulso del bloque: nivel bajo

	// DATA
	reg [30:0] nbits;
	reg        dLevel;
	reg        dFirst;
	reg [15:0] tail;
	reg [ 7:0] p0, p1;
	reg [ 8:0] si;
	reg [15:0] seq[0:511];                  // s0 en 0..255, s1 en 256..511
	reg [ 7:0] data;
	reg [ 2:0] bitn;
	reg        bitv;
	reg [ 7:0] pi;                          // pulso dentro del bit
	reg [15:0] seqQ;
	reg        seqW = 1'b0;
	reg [ 8:0] seqWA;
	reg [15:0] seqWD;
	always @(posedge clock) begin
		if(seqW) seq[seqWA] <= seqWD;
		seqQ <= seq[{ bitv, pi }];
	end

	assign busy = (state != sIDLE && state != sSTOPPED) || pActive || nValid;

	task read(input [2:0] n);
		begin rdN <= n; acc <= 32'd0; rdBusy <= 1'b1; rdIssued <= 1'b0; end
	endtask

	task emit(input set, input level, input [30:0] d, input toggle);
		begin nValid <= 1'b1; nSet <= set; nLevel <= level; nDur <= d; nToggle <= toggle; end
	endtask

	always @(posedge clock) begin
		seqW <= 1'b0;
		if(take) nValid <= 1'b0;

		if(play) begin
			nValid <= 1'b0;
			rdBusy <= 1'b0;
			resume <= 1'b0;
			if(!resume) a <= 22'd0;
			state <= sNEXT;
		end
		else if(stop) begin
			nValid <= 1'b0;
			rdBusy <= 1'b0;
			resume <= 1'b0;
			state <= sIDLE;
		end
		else if(rdBusy) begin
			if(!rdIssued) begin mA <= a; mReq <= ~mReq; rdIssued <= 1'b1; end
			else if(memReady) begin
				acc <= { mQ, acc[31:8] };
				a <= a+1'd1;
				rdIssued <= 1'b0;
				if(rdN == 1) rdBusy <= 1'b0; else rdN <= rdN-1'd1;
			end
		end
		else case(state)
			sIDLE, sSTOPPED: ;

			sNEXT: begin                                    // cabecera del siguiente bloque
				if(a + 22'd8 > size) state <= sDRAIN;
				else begin read(3'd4); state <= sTAG; end
			end
			sTAG: begin tag <= acc; read(3'd4); state <= sSIZE; end
			sSIZE: begin
				blkEnd <= a + acc[21:0];
				case(tag)
					32'h534C5550: begin first <= 1'b1; state <= sPULS; end      // "PULS"
					32'h41544144: begin read(3'd4); state <= sDCNT; end         // "DATA"
					32'h53554150: begin read(3'd4); state <= sPAUS; end         // "PAUS"
					32'h504F5453: begin read(3'd2); state <= sSTOP; end         // "STOP"
					default: begin a <= a + acc[21:0]; state <= sNEXT; end      // se salta
				endcase
			end

			//--- PULS: [cuenta] duración [parte baja de una duración de 31 bits]
			sPULS: begin
				if(a >= blkEnd) state <= sNEXT;
				else begin read(3'd2); state <= sPW1; end
			end
			sPW1: begin
				if(w16 > 16'h8000) begin rep <= w16[14:0]; read(3'd2); state <= sPW2; end
				else begin
					rep <= 15'd1;
					if(w16[15]) begin dhi <= w16[14:0]; read(3'd2); state <= sPW3; end
					else begin dur <= { 15'd0, w16 }; state <= sPOUT; end
				end
			end
			sPW2: begin
				if(w16[15]) begin dhi <= w16[14:0]; read(3'd2); state <= sPW3; end
				else begin dur <= { 15'd0, w16 }; state <= sPOUT; end
			end
			sPW3: begin dur <= { dhi, w16 }; state <= sPOUT; end
			sPOUT: begin
				if(rep == 0) state <= sPULS;
				else if(!nValid || take) begin
					emit(first, 1'b0, dur, 1'b1);
					first <= 1'b0;
					rep <= rep-1'd1;
				end
			end

			//--- DATA: bits+nivel (4), tail (2), p0 (1), p1 (1), s0[p0], s1[p1], datos
			sDCNT: begin
				nbits <= acc[30:0];
				dLevel <= acc[31];
				dFirst <= 1'b1;
				read(3'd2); state <= sDTAIL;
			end
			sDTAIL: begin tail <= w16; read(3'd2); state <= sDP; end
			sDP: begin p0 <= acc[23:16]; p1 <= acc[31:24]; si <= 9'd0; state <= sDS; end
			sDS: begin
				if(si < { 1'b0, p0 } + { 1'b0, p1 }) begin read(3'd2); state <= sDS2; end
				else state <= sDB;
			end
			sDS2: begin
				seqW <= 1'b1;
				seqWA <= si < { 1'b0, p0 } ? si : 9'd256 + (si - { 1'b0, p0 });
				seqWD <= w16;
				si <= si+1'd1;
				state <= sDS;
			end
			sDB: begin
				if(nbits == 0) state <= sDT;
				else begin read(3'd1); state <= sDB2; end
			end
			sDB2: begin data <= acc[31:24]; bitn <= 3'd7; state <= sDBIT; end
			sDBIT: begin bitv <= data[bitn]; pi <= 8'd0; state <= sDPW; end
			sDPW: state <= sDPUL;                           // espera a seqQ
			sDPUL: begin
				if(pi == (bitv ? p1 : p0)) begin
					nbits <= nbits-1'd1;
					if(nbits == 1 || bitn == 0) state <= sDB;
					else begin bitn <= bitn-1'd1; state <= sDBIT; end
				end
				else if(!nValid || take) begin
					emit(dFirst, dLevel, { 15'd0, seqQ }, 1'b1);
					dFirst <= 1'b0;
					pi <= pi+1'd1;
					state <= sDPW;
				end
			end
			sDT: begin
				if(tail == 0) begin a <= blkEnd; state <= sNEXT; end
				else if(!nValid || take) begin
					emit(dFirst, dLevel, { 15'd0, tail }, 1'b1);
					a <= blkEnd; state <= sNEXT;
				end
			end

			//--- PAUS: nivel y duración
			sPAUS: begin
				if(!nValid || take) begin
					emit(1'b1, acc[31], acc[30:0], 1'b0);
					a <= blkEnd; state <= sNEXT;
				end
			end

			//--- STOP: 0 = siempre, 1 = solo en modo 48K
			sSTOP: begin
				a <= blkEnd;
				if(w16 == 0 || (w16 == 1 && stop48)) begin resume <= 1'b1; state <= sDRAIN; end
				else state <= sNEXT;
			end

			sDRAIN: if(!nValid && !pActive) state <= resume ? sSTOPPED : sIDLE;

			default: state <= sIDLE;
		endcase
	end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
