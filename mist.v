//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------
module mist
//-------------------------------------------------------------------------------------------------
#
(
	RGBW = 8
)
(
	input  wire       clock,
	input  wire       power,

	input  wire       spiCk,
	input  wire       spiSs1,
	input  wire       spiSs2,
	input  wire       spiSs3,
	input  wire       spiMosi,
	output wire       spiMiso,

	input  wire       r,
	input  wire       g,
	input  wire       b,
	input  wire       i,
	input  wire       hsync,
	input  wire       vsync,

	output wire[ 1:0] sync,
	output wire[3*RGBW-1:0] rgb,

	input  wire[ 7:0] midiQ,
	input  wire       midiS,

	output wire[63:0] status,

	output wire       ps2kCk,
	output wire       ps2kD,

	output wire[ 7:0] joy1,
	output wire[ 7:0] joy2,

	output reg [ 2:0] mbtns,
	output reg [ 7:0] xaxis,
	output reg [ 7:0] yaxis,

	output wire       dioEn,
	output wire[ 7:0] dioIx,
	output wire[31:0] dioSz,
	output wire[26:0] dioA,
	output wire[ 7:0] dioD,
	output wire       dioW,

	input  wire       fddCe,
	input  wire       fddRd,
	input  wire       fddWr,
	input  wire       fddA,
	input  wire[ 7:0] fddD,
	output wire[ 7:0] fddQ,
	input  wire       fddMtr,

	input  wire       sdcCs,
	input  wire       sdcCk,
	input  wire       sdcMosi,
	output wire       sdcMiso
);
//--- confstr -------------------------------------------------------------------------------------

	localparam confstr =
	{
		"ZXP3;;",
		"F0,ROM,Load ROM;",
		"-;",
		"O5,DivMMC,On,Off;",
		"S0U,VHD,Mount SD;",
		"S1U,DSK,Mount drive A:;",
		"S2U,DSK,Mount drive B:;",
		"-;",
		"F1,TZX,Load TZX;",
		"O6,Tape sound,Off,On;",
		"-;",
		"O7,Mouse sensitivity,Full,Half;",
		"O8,Video timing,GA,ULA;",
		"-;",
		"T0,Reset;",
		"T1,NMI;",
		"V,V2.0,2026.03.26;",
	};

//--- user io--------------------------------------------------------------------------------------

	wire[31:0] joystick_0;
	wire[31:0] joystick_1;

	wire[ 8:0] mouse_x;
	wire[ 8:0] mouse_y;
	wire[ 7:0] mouse_flags;
	wire       mouse_strobe;

	wire[ 2:0] sdRd;
	wire[ 2:0] sdWr;
	wire       sdAck;
	wire[31:0] sdLba = sdBusy ? sdcLba : fddLba;
	wire       sdBusy;
	wire       sdConf;
	wire       sdSdhc;
	wire       sdAckCf;
	wire[ 8:0] sdBuffA;
	wire[ 7:0] sdBuffD = sdBusy ? sdcBuffD : fddBuffD;
	wire[ 7:0] sdBuffQ;
	wire       sdBuffW;
	wire[ 2:0] imgMntd;
	wire[63:0] imgSize;

	user_io #(.STRLEN(235), .SD_IMAGES(3), .SERIAL_CHANNEL(1), .FEATURES(32'h2000)) user_io
	(
		.conf_str        (confstr),
		.conf_addr       (       ),
		.conf_chr        (8'd0   ),
		.clk_sys         (clock  ),
		.clk_sd          (clock  ),
		.SPI_CLK         (spiCk  ),
		.SPI_SS_IO       (spiSs1 ),
		.SPI_MOSI        (spiMosi),
		.SPI_MISO        (spiMiso),
		.ps2_kbd_clk     (ps2kCk ),
		.ps2_kbd_data    (ps2kD  ),
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
		.leds            (8'd0),
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
		.i2c_start       (),
		.i2c_read        (),
		.i2c_addr        (),
		.i2c_subaddr     (),
		.i2c_dout        (),
		.i2c_din         (8'hFF),
		.i2c_ack         (1'b0 ),
		.i2c_end         (1'b0 ),
		.serial_data     (midiQ),
		.serial_strobe   (midiS),
		.joystick_analog_0(),
		.joystick_analog_1(),
		.scandoubler_disable()
	);

//--- data io--------------------------------------------------------------------------------------

	data_io	data_io
	(
		.clk_sys       (clock  ),
		.SPI_SCK       (spiCk  ),
		.SPI_SS2       (spiSs2 ),
		.SPI_SS4       (       ),
		.SPI_DI        (spiMosi),
		.SPI_DO        (spiMiso),
		.clkref_n      (1'b0   ),
		.ioctl_download(dioEn  ),
		.ioctl_filesize(dioSz  ),
		.ioctl_index   (dioIx  ),
		.ioctl_addr    (dioA   ),
		.ioctl_din     (8'd0   ),
		.ioctl_dout    (dioD   ),
		.ioctl_wr      (dioW   ),
		.ioctl_upload  (),
		.ioctl_fileext (),
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

//--- u765 ----------------------------------------------------------------------------------------

	reg[2:1] fddRdy;
	always @(posedge clock)
		if(imgMntd[2]) fddRdy[2] <= imgSize != 0;
		else if(imgMntd[1]) fddRdy[1] <= imgSize != 0;

	wire[31:0] fddLba;
	wire[ 7:0] fddBuffD;

	u765 #(20'd1800, 1) u765
	(
		.clk_sys     (clock        ),
		.ce          (fddCe        ),
		.reset       (~power       ),
		.ready       (fddRdy       ),
		.motor       ({2{ fddMtr }}),
		.available   (2'b11        ),
		.fast        (1'b1         ),
		.nRD         (fddRd        ),
		.nWR         (fddWr        ),
		.a0          (fddA         ),
		.din         (fddD         ),
		.dout        (fddQ         ),
		.img_mounted (imgMntd[ 2:1]),
		.img_size    (imgSize[31:0]),
		.img_wp      (1'b0         ),
		.sd_rd       (sdRd[2:1]    ),
		.sd_wr       (sdWr[2:1]    ),
		.sd_ack      (sdAck        ),
		.sd_lba      (fddLba       ),
		.sd_buff_addr(sdBuffA      ),
		.sd_buff_din (fddBuffD     ),
		.sd_buff_dout(sdBuffQ      ),
		.sd_buff_wr  (sdBuffW      )
	);

//---sd card --------------------------------------------------------------------------------------

	wire[31:0] sdcLba;
	wire[ 7:0] sdcBuffD;

	sd_card sd_card
	(
		.clk_sys     (clock     ),
		.sd_rd       (sdRd[0]   ),
		.sd_wr       (sdWr[0]   ),
		.sd_ack      (sdAck     ),
		.sd_lba      (sdcLba    ),
		.sd_busy     (sdBusy    ),
		.sd_conf     (sdConf    ),
		.sd_sdhc     (sdSdhc    ),
		.sd_ack_conf (sdAckCf   ),
		.sd_buff_addr(sdBuffA   ),
		.sd_buff_din (sdcBuffD  ),
		.sd_buff_dout(sdBuffQ   ),
		.sd_buff_wr  (sdBuffW   ),
		.img_mounted (imgMntd[0]),
		.img_size    (imgSize   ),
		.allow_sdhc  (1'b1      ),
		.sd_cs       (sdcCs     ),
		.sd_sck      (sdcCk     ),
		.sd_sdi      (sdcMosi   ),
		.sd_sdo      (sdcMiso   )
	);

//--- osd -----------------------------------------------------------------------------------------

	osd #(.BIG_OSD(1'b1), .OUT_COLOR_DEPTH(RGBW)) osd
	(
		.clk_sys(clock  ),
		.ce     (1'b0   ),
		.SPI_SCK(spiCk  ),
		.SPI_SS3(spiSs3 ),
		.SPI_DI (spiMosi),
		.rotate (2'd0   ),
		.HBlank (1'b0   ),
		.VBlank (1'b0   ),
		.HSync  (hsync  ),
		.VSync  (vsync  ),
		.R_in   ({RGBW/2{ r, r&i }}),
		.G_in   ({RGBW/2{ g, g&i }}),
		.B_in   ({RGBW/2{ b, b&i }}),
		.R_out  (rgb[(3*RGBW)-1:2*RGBW]),
		.G_out  (rgb[(2*RGBW)-1:1*RGBW]),
		.B_out  (rgb[(1*RGBW)-1:0*RGBW]),
		.osd_enable()
	);

	assign sync = { 1'b1, ~(hsync^vsync) };

//-------------------------------------------------------------------------------------------------

	assign joy1 = joystick_1[7:0];
	assign joy2 = joystick_0[7:0];

	reg mouse_strobe_p;
	always @(posedge clock) begin
		mouse_strobe_p <= mouse_strobe;
		if(mouse_strobe != mouse_strobe_p) begin
			mbtns <= ~{ mouse_flags[2], mouse_flags[0], mouse_flags[1] };
			xaxis <= xaxis+(status[7] ? { mouse_flags[4], mouse_x[8:2] } : mouse_x[8:1]);
			yaxis <= yaxis+(status[7] ? { mouse_flags[5], mouse_y[8:2] } : mouse_y[8:1]);
		end
	end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
