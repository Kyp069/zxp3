//-------------------------------------------------------------------------------------------------
// Reproductor de ficheros TAP (formato estándar de la ROM del Spectrum).
// Shaeon (Carlos Palmero) para el core zxp3 de Kyp. Basado en la parte TAP de tape.sv del core
// ZX-Spectrum de MiST/MiSTer (Till Harbaum / Sorgelig).
//
// Un TAP es una lista de bloques: longitud (2 bytes, little endian) + bloque (flag, datos, checksum).
// Cada bloque se reproduce como lo haría la ROM al grabarlo:
//   tono guía de 8063 pulsos (cabecera, flag < 128) o 3223 (datos) de 2168 T,
//   sincronismo de 667 T y 735 T,
//   cada bit como dos pulsos iguales: 855 T (0) o 1710 T (1), del bit más alto al más bajo,
//   1000 ms de pausa después de cada bloque.
// La cinta se lee byte a byte por un puerto de memoria con handshake (mReq != mAck: petición
// pendiente; el dato es válido en mQ cuando mAck vuelve a valer mReq).
//-------------------------------------------------------------------------------------------------
module tap_player
#(
	parameter TS = 16                       // ciclos de reloj por T-estado (56 MHz / 3,5 MHz)
)
(
	input  wire       clock,

	input  wire       play,                 // arranca desde el principio
	input  wire       stop,
	input  wire[21:0] size,                 // tamaño del fichero en bytes
	output reg        busy = 1'b0,
	output reg        tape = 1'b0,          // señal EAR

	output reg        mReq = 1'b0,
	input  wire       mAck,
	output reg [21:0] mA,
	input  wire[ 7:0] mQ
);
//-------------------------------------------------------------------------------------------------

	localparam [3:0] sIDLE = 0, sLEN0 = 1, sLEN1 = 2, sFLAG = 3, sPILOT = 4, sSYNC1 = 5, sSYNC2 = 6,
	                 sBYTE = 7, sBIT = 8, sPAUSE = 9;

	reg [ 3:0] state = sIDLE;
	reg        waitMem = 1'b0;              // esperando un byte de la memoria
	reg [21:0] a = 22'd0;                   // siguiente byte del fichero
	reg [15:0] len = 16'd0;                 // bytes que quedan del bloque
	reg [12:0] pulses = 13'd0;              // pulsos que quedan del tono guía
	reg [ 7:0] data;
	reg [ 2:0] bitn;
	reg        half;                        // primera o segunda mitad del bit
	reg [11:0] tcnt = 12'd0;                // T-estados que quedan del pulso actual
	reg [ 7:0] div = 8'd0;                  // ciclos de reloj dentro del T-estado
	reg [21:0] pause = 22'd0;               // T-estados de pausa

	wire tick = div == TS-1;                // fin de un T-estado
	wire memReady = mReq == mAck;

	// pide un byte de la memoria
	task fetch(input [21:0] addr);
		begin mA <= addr; mReq <= ~mReq; waitMem <= 1'b1; end
	endtask

	// empieza un pulso: el nivel cambia al final de cada pulso, como en la grabación
	task pulse(input [11:0] t);
		begin tcnt <= t; end
	endtask

	always @(posedge clock) begin
		div <= tick ? 8'd0 : div+1'd1;

		if(play) begin
			a <= 22'd0;
			busy <= 1'b1;
			tape <= 1'b0;
			tcnt <= 12'd0;
			pause <= 22'd0;
			state <= sLEN0;
			fetch(22'd0);
		end
		else if(stop || state == sIDLE) begin
			busy <= 1'b0;
			state <= sIDLE;
		end
		else if(tick && tcnt != 0) begin
			// pulso en curso
			tcnt <= tcnt-1'd1;
			if(tcnt == 1) tape <= ~tape;
		end
		else if(tick && pause != 0) begin
			pause <= pause-1'd1;
			if(pause == 22'd3500000-22'd3500) tape <= 1'b0;   // nivel bajo tras 1 ms de pausa
		end
		else if(tcnt == 0 && pause == 0 && (!waitMem || memReady)) begin
			waitMem <= 1'b0;
			case(state)
				sLEN0: begin                      // longitud del bloque (byte bajo)
					if(a >= size) state <= sIDLE;
					else begin len[7:0] <= mQ; a <= a+1'd1; fetch(a+1'd1); state <= sLEN1; end
				end
				sLEN1: begin                      // longitud del bloque (byte alto)
					len[15:8] <= mQ; a <= a+1'd1;
					if(len[7:0] == 0 && mQ == 0) begin fetch(a+1'd1); state <= sLEN0; end
					else begin fetch(a+1'd1); state <= sFLAG; end
				end
				sFLAG: begin                      // el flag decide la longitud del tono guía
					pulses <= mQ[7] ? 13'd3223 : 13'd8063;
					state <= sPILOT;
				end
				sPILOT: begin
					if(pulses != 0) begin pulses <= pulses-1'd1; pulse(12'd2168); end
					else begin pulse(12'd667); state <= sSYNC1; end
				end
				sSYNC1: begin pulse(12'd735); state <= sSYNC2; end
				sSYNC2: begin                     // el primer byte (flag) ya está en mQ
					data <= mQ; a <= a+1'd1; len <= len-1'd1;
					bitn <= 3'd7; half <= 1'b0;
					state <= sBIT;
				end
				sBYTE: begin                      // siguiente byte del bloque
					data <= mQ; a <= a+1'd1; len <= len-1'd1;
					bitn <= 3'd7; half <= 1'b0;
					state <= sBIT;
				end
				sBIT: begin
					pulse(data[bitn] ? 12'd1710 : 12'd855);
					half <= ~half;
					if(half) begin
						if(bitn != 0) bitn <= bitn-1'd1;
						else if(len != 0) begin fetch(a); state <= sBYTE; end
						else begin pause <= 22'd3500000; fetch(a); state <= sPAUSE; end
					end
				end
				sPAUSE: state <= sLEN0;           // tras la pausa, el siguiente bloque
				default: state <= sIDLE;
			endcase
		end
	end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
