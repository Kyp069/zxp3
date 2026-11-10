//-------------------------------------------------------------------------------------------------
// ZXP3 - cinta leída directamente de la SD, por sectores, como las imágenes DSK o VHD.
// Shaeon (Carlos Palmero) para el core de Kyp (Calypso, SiDi, MiST...).
//
// El fichero TZX o TAP se monta como imagen ("S3,TZXTAP,Mount tape;") y no se carga en memoria:
// el módulo pide al firmware los sectores de 512 bytes que necesita (sd_lba / sd_rd / sd_ack) y los
// guarda en una caché de 2 sectores (1 KB de BRAM). Mientras se reproduce un sector, se pide por
// adelantado el siguiente, así que la cinta no espera a la SD salvo al saltar hacia atrás (bucles).
//
// - Formato: si los 8 primeros bytes son "ZXTape!" + 0x1A, TZX (tzxplayer); si los 4 primeros son
//   "PZXT", PZX (pzx_player); si no, TAP (tap_player).
// - TZX: handshake req != ack, bucles 0x24/0x25, 0x2A solo con stop48 = 1.
// - Conexión con user_io: sd_ack debe ser el ack de ESTA imagen (sd_ack_x[n]), para no confundir
//   sus transferencias con las de la DivMMC o los discos.
//-------------------------------------------------------------------------------------------------
module tape_sd
#(
	parameter MS = 56000,                 // ciclos de reloj por milisegundo (tzxplayer)
	parameter TS = 16                     // ciclos de reloj por T-estado (tap_player)
)
(
	input  wire       clock,

	// imagen montada (user_io)
	input  wire       img_mounted,        // pulso al montar una imagen en esta unidad
	input  wire[31:0] img_size,
	output reg [31:0] sd_lba = 32'd0,
	output reg        sd_rd = 1'b0,
	input  wire       sd_ack,             // ack de esta imagen (sd_ack_x[n])
	input  wire[ 8:0] sd_buff_addr,
	input  wire[ 7:0] sd_buff_dout,
	input  wire       sd_buff_wr,

	input  wire       play,
	input  wire       stop,
	input  wire       stop48,             // 1: el bloque 0x2A de un TZX para la cinta (modo 48K)
	output wire       busy,
	output wire       tape,
	output reg        isTap = 1'b0,
	output reg        isPzx = 1'b0,
	output wire       loading             // leyendo un sector de la SD (para un LED, por ejemplo)
);
//--- caché de 2 sectores -------------------------------------------------------------------------

	reg [7:0] cache[0:1023];              // slot 0: 0-511, slot 1: 512-1023
	reg [9:0] cRa;
	reg [7:0] cQ;
	reg       wSlot;                      // slot que se está llenando
	always @(posedge clock) begin
		if(sd_ack && sd_buff_wr) cache[{ wSlot, sd_buff_addr }] <= sd_buff_dout;
		cQ <= cache[cRa];
	end

	reg [22:0] tag[0:1];                  // sector guardado en cada slot (archivos de hasta 4 GB)
	reg  [1:0] valid = 2'b00;
	reg [31:0] size = 32'd0;
	reg        mounted = 1'b0;

	// el firmware manda el tamaño (img_size) antes del aviso de montaje: en el ciclo de
	// img_mounted ya es válido (como lo lee el core para los DSK)

	reg        ld = 1'b0;                 // lectura de un sector en curso
	reg        ackP = 1'b0;
	reg        sigOk;
	reg        pzxOk;
	assign loading = ld;

	wire[22:0] lastSec = size[31:9] - (size[8:0] == 0);

//--- servidor de bytes para los reproductores ----------------------------------------------------

	// petición de un byte: rReq != rAck; dirección rA; dato en rQ
	reg        rReq = 1'b0, rAck = 1'b0;
	reg [31:0] rA;
	reg  [7:0] rQ;
	reg  [1:0] rLat = 2'd0;
	reg        rBusy = 1'b0;
	reg [22:0] curSec = 23'd0;            // último sector servido (para la lectura adelantada)

	wire[22:0] reqSec = rA[31:9];
	wire       hit0 = valid[0] && tag[0] == reqSec;
	wire       hit1 = valid[1] && tag[1] == reqSec;
	wire       nxtCached = (valid[0] && tag[0] == curSec+1'd1) || (valid[1] && tag[1] == curSec+1'd1);

	// pide un sector a la SD en el slot indicado
	task load(input [22:0] sec, input slot);
		begin
			sd_lba <= { 9'd0, sec };
			sd_rd <= 1'b1;
			wSlot <= slot;
			valid[slot] <= 1'b0;
			tag[slot] <= sec;
			ld <= 1'b1;
		end
	endtask

	always @(posedge clock) begin
		ackP <= sd_ack;

		// montaje de una imagen nueva: vacía la caché y lee el sector 0
		if(img_mounted) begin
			size <= img_size;
			mounted <= img_size != 0;
			valid <= 2'b00;
			sd_rd <= 1'b0;
			ld <= 1'b0;
			curSec <= 23'd0;
			if(img_size != 0) begin sigOk <= 1'b1; pzxOk <= 1'b1; load(23'd0, 1'b0); end
			else begin isTap <= 1'b0; isPzx <= 1'b0; end
		end
		else begin
			// lectura en curso
			if(ld) begin
				if(sd_ack) sd_rd <= 1'b0;
				// formato: se comprueban los 8 primeros bytes del sector 0
				if(sd_ack && sd_buff_wr && tag[wSlot] == 0 && sd_buff_addr < 8 && sd_buff_dout != tzxSig(sd_buff_addr[2:0]))
					sigOk <= 1'b0;
				if(sd_ack && sd_buff_wr && tag[wSlot] == 0 && sd_buff_addr < 4 && sd_buff_dout != pzxSig(sd_buff_addr[1:0]))
					pzxOk <= 1'b0;
				if(ackP && !sd_ack) begin
					valid[wSlot] <= 1'b1;
					ld <= 1'b0;
					if(tag[wSlot] == 0) begin isTap <= !sigOk && !pzxOk; isPzx <= pzxOk; end
				end
			end

			// servir un byte
			if(rReq != rAck && !rBusy) begin
				if(hit0 || hit1) begin
					cRa <= { hit1, rA[8:0] };
					curSec <= reqSec;
					rLat <= 2'd2;
					rBusy <= 1'b1;
				end
				else if(!ld) load(reqSec, (valid[0] && tag[0] == curSec) ? 1'b1 : 1'b0);
			end
			else if(rBusy) begin
				if(rLat) rLat <= rLat-1'd1;
				else begin rQ <= cQ; rAck <= rReq; rBusy <= 1'b0; end
			end
			// lectura adelantada del sector siguiente, en el slot que no tiene el actual
			else if(!ld && mounted && curSec < lastSec && !nxtCached)
				load(curSec+1'd1, (valid[0] && tag[0] == curSec) ? 1'b1 : 1'b0);
		end
	end

	function [7:0] pzxSig(input [1:0] i);
		case(i) 0: pzxSig = "P"; 1: pzxSig = "Z"; 2: pzxSig = "X"; default: pzxSig = "T"; endcase
	endfunction

	function [7:0] tzxSig(input [2:0] i);
		case(i)
			0: tzxSig = "Z"; 1: tzxSig = "X"; 2: tzxSig = "T"; 3: tzxSig = "a";
			4: tzxSig = "p"; 5: tzxSig = "e"; 6: tzxSig = "!"; default: tzxSig = 8'h1A;
		endcase
	endfunction

//--- TZX: tzxplayer ------------------------------------------------------------------------------

	wire       req;
	reg        ack = 1'b0;
	reg        motor = 1'b0;
	reg        restart = 1'b0;
	reg  [7:0] data;
	reg [31:0] a = 32'd0, loopA = 32'd0;
	reg        tzxFetch = 1'b0;
	wire       eot, eot48, loopStart, loopNext;
	wire       tzxBusy, tzxTape;

	tzxplayer #(.TZX_MS(MS)) tzxplayer
	(
		.clk         (clock    ),
		.ce          (1'b1     ),
		.tzx_ack     (ack      ),
		.tzx_req     (req      ),
		.host_tap_in (data     ),
		.cass_motor  (motor    ),
		.restart_tape(restart  ),
		.loop_start  (loopStart),
		.loop_next   (loopNext ),
		.stop        (eot      ),
		.stop48k     (eot48    ),
		.cass_read   (tzxTape  ),
		.cass_running(tzxBusy  )
	);

//--- TAP: tap_player -----------------------------------------------------------------------------

	wire       tapReq;
	reg        tapAck = 1'b0;
	wire[21:0] tapA;
	reg        tapFetch = 1'b0;
	wire       tapBusy, tapTape;

	tap_player #(.TS(TS)) tap_player
	(
		.clock(clock                    ),
		.play (play && mounted && isTap ),
		.stop (stop || img_mounted      ),
		.size (size[21:0]               ),
		.busy (tapBusy                  ),
		.tape (tapTape                  ),
		.mReq (tapReq                   ),
		.mAck (tapAck                   ),
		.mA   (tapA                     ),
		.mQ   (rQ                       )
	);

//--- PZX: pzx_player -----------------------------------------------------------------------------

	wire       pzxReq;
	reg        pzxAck = 1'b0;
	wire[21:0] pzxA;
	reg        pzxFetch = 1'b0;
	wire       pzxBusy, pzxTape;

	pzx_player #(.TS(TS)) pzx_player
	(
		.clock (clock                    ),
		.play  (play && mounted && isPzx ),
		.stop  (stop || img_mounted      ),
		.stop48(stop48                   ),
		.size  (size[21:0]               ),
		.busy  (pzxBusy                  ),
		.tape  (pzxTape                  ),
		.mReq  (pzxReq                   ),
		.mAck  (pzxAck                   ),
		.mA    (pzxA                     ),
		.mQ    (rQ                       )
	);

	wire isTzx = !isTap && !isPzx;
	assign busy = isTap ? tapBusy : isPzx ? pzxBusy : tzxBusy;
	assign tape = isTap ? tapTape : isPzx ? pzxTape : tzxTape;

//--- peticiones de los reproductores al servidor de bytes ----------------------------------------

	always @(posedge clock) begin
		restart <= 1'b0;

		if(rReq == rAck) begin
			if(tzxFetch) begin data <= rQ; ack <= req; a <= a+1'd1; tzxFetch <= 1'b0; end
			if(tapFetch) begin tapAck <= tapReq; tapFetch <= 1'b0; end
			if(pzxFetch) begin pzxAck <= pzxReq; pzxFetch <= 1'b0; end
		end

		if(rReq == rAck && !tzxFetch && !tapFetch && !pzxFetch) begin
			if(isTzx && motor && req != ack && !loopStart && !loopNext) begin
				rA <= a; rReq <= ~rReq; tzxFetch <= 1'b1;
			end
			else if(isTap && tapReq != tapAck) begin
				rA <= { 10'd0, tapA }; rReq <= ~rReq; tapFetch <= 1'b1;
			end
			else if(isPzx && pzxReq != pzxAck) begin
				rA <= { 10'd0, pzxA }; rReq <= ~rReq; pzxFetch <= 1'b1;
			end
		end

		if(play && mounted && isTzx) begin
			a <= 32'd0; motor <= 1'b1; restart <= 1'b1;
		end
		else if(stop || eot || (eot48 && stop48) || img_mounted || !isTzx || a >= size) motor <= 1'b0;
		else if(loopStart) loopA <= a;
		else if(loopNext)  a <= loopA;
	end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
