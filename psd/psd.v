`default_nettype none
//-------------------------------------------------------------------------------------------------
module psd
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       tape,

	output wire       i2sCk,
	output wire       i2sWs,
	output wire       i2sD,

	output wire       dramCk,
	output wire       dramCe,
	output wire       dramCs,
	output wire       dramWe,
	output wire       dramRas,
	output wire       dramCas,

	input  wire       spiCk,
	input  wire       spiSs2,
	input  wire       spiSs3,
	input  wire       spiSsIo,
	input  wire       spiMosi,
	inout  wire       spiMiso,

	output wire[ 2:0] led
);
//-------------------------------------------------------------------------------------------------

wire clock;
wire power;

pll pll(clock50, clock, power);

//-------------------------------------------------------------------------------------------------

localparam confStr =
{
	"ZXP3;;",
	"F0,ROM,Load ROM;",
	"S0,DSK,Mount drive A:;",
	"S1,DSK,Mount drive B:;",
	"S2,VHD,Mount SD;",
	"V,V1.0;"
};

wire       uiokCk;
wire       uiokD;

wire[ 8:0] mouse_x;
wire[ 8:0] mouse_y;
wire[ 7:0] mouse_flags;
wire       mouse_strobe;

wire[31:0] joystick_0;
wire[31:0] joystick_1;

wire[63:0] status;

wire[ 2:0] sdRd;
wire[ 2:0] sdWr;
wire       sdAck;
wire[31:0] sdLba = sdcBusy ? sdcLba : fddLba;
wire       sdBusy;
wire       sdConf;
wire       sdSdhc;
wire       sdAckCf;
wire[ 8:0] sdBuffA;
wire[ 7:0] sdBuffD = sdcBusy ? sdcBuffD : fddBuffD;
wire[ 7:0] sdBuffQ;
wire       sdBuffW;
wire[ 2:0] imgMntd;
wire[63:0] imgSize;

wire novga;

user_io #(.STRLEN(89), .SD_IMAGES(3), .FEATURES(32'h2000)) user_io
(
	.conf_str        (confStr),
	.conf_addr       (       ),
	.conf_chr        (8'd0   ),
	.clk_sys         (clock  ),
	.clk_sd          (clock  ),
	.SPI_CLK         (spiCk  ),
	.SPI_SS_IO       (spiSsIo),
	.SPI_MOSI        (spiMosi),
	.SPI_MISO        (spiMiso),
	.ps2_kbd_clk     (uiokCk ),
	.ps2_kbd_data    (uiokD  ),
	.ps2_kbd_clk_i   (1'b0),
	.ps2_kbd_data_i  (1'b0),
	.ps2_mouse_clk   (),
	.ps2_mouse_data  (),
	.ps2_mouse_clk_i (1'b0),
	.ps2_mouse_data_i(1'b0),
	.sd_rd           (sdRd   ),
	.sd_wr           (sdWr   ),
	.sd_ack          (sdAck  ),
	.sd_ack_conf     (sdAckCf),
	.sd_ack_x        (),
	.sd_lba          (sdLba  ),
    .sd_conf         (sdConf ),
	.sd_sdhc         (sdSdhc ),
	.sd_buff_addr    (sdBuffA),
	.sd_din          (sdBuffD),
	.sd_din_strobe   (),
	.sd_dout         (sdBuffQ),
	.sd_dout_strobe  (sdBuffW),
	.img_mounted     (imgMntd),
	.img_size        (imgSize),
	.rtc             (),
	.ypbpr           (),
	//.leds            (8'd0),
	.status          (status),
	.buttons         (),
	.switches        (),
	.no_csync        (),
	.core_mod        (),
	.key_pressed     (),
	.key_extended    (),
	.key_code        (),
	.key_strobe      (),
	.kbd_out_data    (8'd0),
	.kbd_out_strobe  (1'b0),
	.mouse_x         (mouse_x),
	.mouse_y         (mouse_y),
	.mouse_z         (),
	.mouse_flags     (mouse_flags),
	.mouse_strobe    (mouse_strobe),
	.mouse_idx       (),
	.joystick_0      (joystick_0),
	.joystick_1      (joystick_1),
	.joystick_2      (),
	.joystick_3      (),
	.joystick_4      (),
	//.i2c_start       (),
	//.i2c_read        (),
	//.i2c_addr        (),
	//.i2c_subaddr     (),
	//.i2c_dout        (),
	//.i2c_din         (8'hFF),
	//.i2c_ack         (1'b0 ),
	//.i2c_end         (1'b0 ),
	.serial_data     (8'd0),
	.serial_strobe   (1'd0),
	.joystick_analog_0(),
	.joystick_analog_1(),
	.scandoubler_disable(novga)
);

//-------------------------------------------------------------------------------------------------

wire       romIo;
wire[26:0] romA;
wire[ 7:0] romD;
wire       romW;

data_io	data_io
(
	.clk_sys       (clock  ),
	.SPI_SCK       (spiCk  ),
	.SPI_SS2       (spiSs2 ),
	.SPI_SS4       (       ),
	.SPI_DI        (spiMosi),
	.SPI_DO        (spiMiso),
	.clkref_n      (1'b0   ),
	.ioctl_download(romIo  ),
	.ioctl_upload  (       ),
	.ioctl_index   (       ),
	.ioctl_addr    (romA   ),
	.ioctl_din     (8'h00  ),
	.ioctl_dout    (romD   ),
	.ioctl_wr      (romW   ),
	.ioctl_fileext (),
	.ioctl_filesize(),
	.QCSn          (1'b1),
	.QSCK          (1'b1),
	.QDAT          (4'hF),
	.hdd_clk       (1'b0),
	.hdd_cmd_req   (1'b0),
	.hdd_cdda_req  (1'b0),
	.hdd_dat_req   (1'b0),
	.hdd_cdda_wr   (),
	.hdd_status_wr (),
	.hdd_addr      (),
	.hdd_wr        (),
	.hdd_data_out  (),
	.hdd_data_in   (16'd0),
	.hdd_data_rd   (),
	.hdd_data_wr   (),
	.hdd0_ena      (),
	.hdd1_ena      ()
);

//-------------------------------------------------------------------------------------------------

wire      fddCe;
wire      fddRd;
wire      fddWr;
wire      fddA;
wire[7:0] fddD;
wire[7:0] fddQ;
wire      fddMtr;

reg[1:0] fddRdy;
always @(posedge clock, negedge reset)
	if(!reset) fddRdy <= 2'b00;
	else if(imgMntd[0]) fddRdy[0] <= imgSize != 0;
	else if(imgMntd[1]) fddRdy[1] <= imgSize != 0;

wire[31:0] fddLba;
wire[ 7:0] fddBuffD;

u765 #(20'd1800, 1) u765
(
	.clk_sys     (clock        ),
	.ce          (fddCe        ),
	.reset       (~reset       ),
	.ready       (fddRdy       ),
	.motor       ({2{fddMtr}}  ),
	.available   (2'b11        ),
	.fast        (1'b1         ),
	.nRD         (fddRd        ),
	.nWR         (fddWr        ),
	.a0          (fddA         ),
	.din         (fddD         ),
	.dout        (fddQ         ),
	.img_mounted (imgMntd[1:0] ),
	.img_size    (imgSize[31:0]),
	.img_wp      (1'b0         ),
	.sd_rd       (sdRd[1:0]    ),
	.sd_wr       (sdWr[1:0]    ),
	.sd_ack      (sdAck        ),
	.sd_lba      (fddLba       ),
	.sd_buff_addr(sdBuffA      ),
	.sd_buff_din (fddBuffD     ),
	.sd_buff_dout(sdBuffQ      ),
	.sd_buff_wr  (sdBuffW      )
);

//-------------------------------------------------------------------------------------------------

wire[31:0] sdcLba;
wire       sdcBusy;
wire[ 7:0] sdcBuffD;

wire sdvCs;
wire sdvCk;
wire sdvMosi;
wire sdvMiso;

sd_card sd_card
(
	.clk_sys     (clock     ),
	.sd_rd       (sdRd[2]   ),
	.sd_wr       (sdWr[2]   ),
	.sd_ack      (sdAck     ),
	.sd_ack_conf (sdAckCf   ),
	.sd_conf     (sdConf    ),
	.sd_sdhc     (sdSdhc    ),
	.sd_lba      (sdcLba    ),
	.sd_buff_addr(sdBuffA   ),
	.sd_buff_din (sdcBuffD  ),
	.sd_buff_dout(sdBuffQ   ),
	.sd_buff_wr  (sdBuffW   ),
	.img_mounted (imgMntd[2]),
	.img_size    (imgSize   ),
	.allow_sdhc  (1'b1      ),
	.sd_busy     (sdcBusy   ),
	.sd_cs       (sdvCs     ),
	.sd_sck      (sdvCk     ),
	.sd_sdi      (sdvMosi   ),
	.sd_sdo      (sdvMiso   )
);

//-------------------------------------------------------------------------------------------------

wire      strb;
wire      make;
wire[7:0] code;
ps2k ps2k(clock, uiokD, uiokCk, strb, make, code);

reg F9 = 1'b1;
reg F5 = 1'b1;
always @(posedge clock) if(strb)
	case(code)
		8'h01: F9 <= make;
		8'h03: F5 <= make;
	endcase

reg[2:0] mbtns = 3'b111;
reg[7:0] xaxis;
reg[7:0] yaxis;
always @(posedge clock) if(mouse_strobe) begin
	mbtns <= ~{ mouse_flags[2], mouse_flags[0], mouse_flags[1] };
	xaxis <= xaxis+mouse_x[8:1];
	yaxis <= yaxis+mouse_y[8:1];
end

wire[7:0] joy1 = joystick_0[7:0];
wire[7:0] joy2 = joystick_1[7:0];

//-------------------------------------------------------------------------------------------------

wire cep1x;
wire cep2x;

wire hblank;
wire vblank;
wire hsync;
wire vsync;
wire r;
wire g;
wire b;
wire i;

wire[17:0] rgbosd;

osd #(.BIG_OSD(1'b1)) osd
(
	.clk_sys(clock  ),
	.ce     (1'b0   ),
	.SPI_SCK(spiCk  ),
	.SPI_SS3(spiSs3 ),
	.SPI_DI (spiMosi),
	.rotate (2'd0   ),
	//.HBlank (1'b0   ),
	//.VBlank (1'b0   ),
	.HSync  (hsync  ),
	.VSync  (vsync  ),
	.R_in   ({3{r,r&i}}),
	.G_in   ({3{g,g&i}}),
	.B_in   ({3{b,b&i}}),
	.R_out  (rgbosd[17:12]),
	.G_out  (rgbosd[11: 6]),
	.B_out  (rgbosd[ 5: 0])
);

scandoubler scandoubler
(
	.clock   (clock  ),
	.enable  (~novga ),
	.ice     (cep1x  ),
	.iblank  ({ vblank, hblank}),
	.isync   ({ vsync, hsync}),
	.irgb    (rgbosd ),
	.oce     (cep2x  ),
	.osync   (sync   ),
	.orgb    (rgb    )
);

//-------------------------------------------------------------------------------------------------

wire[13:0] memA1;
wire[ 7:0] memQ1;

wire[17:0] memA2;
wire[ 7:0] memD2;
wire[ 7:0] memQ2 = memA2[17] ? ramQ : !memA2[16] ? romQ : 8'hFF;
wire       memW2;

wire dprW2 = memW2 && (memA2[16:14] == 5 || memA2[16:14] == 7) && !memA2[13];
dprs #(16) dpr(clock, memA1, memQ1, { memA2[15], memA2[12:0] }, memD2, dprW2);

wire[7:0] romQ;
ram #(64) rom(clock, romIo ? romA[15:0] : memA2[15:0], romD, romQ, romW);

wire[7:0] ramQ;
ram #(128) ram(clock, memA2[16:0], memD2, ramQ, memW2);

//-------------------------------------------------------------------------------------------------

wire[14:0] left;
wire[14:0] right;

i2s_out i2s_out(clock, { i2sD, i2sWs, i2sCk }, { 1'b0,  left }, { 1'b0, right });

//-------------------------------------------------------------------------------------------------

wire reset = power && F9 && !romIo;
wire nmi = F5;

wire ear = ~tape;

zx zx
(
	.clock  (clock  ),
	.power  (power  ),
	.reset  (reset  ),
	.nmi    (nmi    ),
	.memA1  (memA1  ),
	.memQ1  (memQ1  ),
	.memA2  (memA2  ),
	.memD2  (memD2  ),
	.memQ2  (memQ2  ),
	.memW2  (memW2  ),
	.cep1x  (cep1x  ),
	.cep2x  (cep2x  ),
	.hblank (hblank ),
	.vblank (vblank ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      ),
	.ear    (ear    ),
	.midi   (       ),
	.left   (left   ),
	.right  (right  ),
	.strb   (strb   ),
	.make   (make   ),
	.code   (code   ),
	.mbtns  (mbtns  ),
	.xaxis  (xaxis  ),
	.yaxis  (yaxis  ),
	.joy1   (joy1   ),
	.joy2   (joy2   ),
	.cs     (sdvCs  ),
	.ck     (sdvCk  ),
	.mosi   (sdvMosi),
	.miso   (sdvMiso),
	.fddCe  (fddCe  ),
	.fddRd  (fddRd  ),
	.fddWr  (fddWr  ),
	.fddA   (fddA   ),
	.fddD   (fddD   ),
	.fddQ   (fddQ   ),
	.fddMtr (fddMtr )
);

//-------------------------------------------------------------------------------------------------

assign dramCk = 1'b0;
assign dramCe = 1'b0;
assign dramCs = 1'b1;
assign dramWe = 1'b1;
assign dramRas = 1'b1;
assign dramCas = 1'b1;

assign led = 3'b111;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
