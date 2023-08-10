//-------------------------------------------------------------------------------------------------
module demistify
//-------------------------------------------------------------------------------------------------
//  This file is part of the ZX Spectrum +3 project.
//  Copyright (C) 2023 Kyp069 <kyp069@gmail.com>
//
//  This program is free software; you can redistribute it and/or modify it under the terms 
//  of the GNU General Public License as published by the Free Software Foundation;
//  either version 3 of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with this program;
//  if not, If not, see <https://www.gnu.org/licenses/>.
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       power,
	input  wire       reset,
	input  wire       tvga,
	output wire       boot,

	input  wire       cep1x,
	input  wire       cep2x,

	output wire       sdcCs,
	output wire       sdcCk,
	output wire       sdcMosi,
	input  wire       sdcMiso,

	output wire       fshCs,
	output wire       fshCk,
	output wire       fshRst,
	output wire       fshMosi,
	input  wire       fshMiso,

	output wire       romIo,
	output wire       romWr,
	output wire[24:0] romA,
	output wire[ 7:0] romD,

	input  wire[ 1:0] iblank,
	input  wire[ 1:0] isync,
	input  wire[17:0] irgb,

	output wire[ 1:0] osync,
	output wire[17:0] orgb,

	input  wire[ 1:0] ps2ki,
	output wire[ 1:0] ps2ko,

	input  wire       sdvCs,
	input  wire       sdvCk,
	input  wire       sdvMosi,
	output wire       sdvMiso,

	input  wire       fddCe,
	input  wire       fddRd,
	input  wire       fddWr,
	input  wire       fddA,
	input  wire[ 7:0] fddD,
	output wire[ 7:0] fddQ,
	input  wire       fddMtr
);
//-------------------------------------------------------------------------------------------------

wire uioMiso;
wire dioMiso;
wire spiMiso = spiSsIo ? dioMiso : uioMiso;

wire spiCk = sdcCk;
wire spiSs2, spiSs3, spiSs4, spiSsIo, spiMosi;

substitute_mcu #(.sysclk_frequency(560)) controller
(
	.clk          (clock  ),
	.reset_in     (power  ),
	.reset_out    (       ),
	.spi_cs       (sdcCs  ),
	.spi_clk      (sdcCk  ),
	.spi_mosi     (sdcMosi),
	.spi_miso     (sdcMiso),
	.spi_req      (       ),
	.spi_ack      (1'b1   ),
	.spi_ss2      (spiSs2 ),
	.spi_ss3      (spiSs3 ),
	.spi_ss4      (spiSs4 ),
	.spi_srtc     (       ),
	.conf_data0   (spiSsIo),
	.spi_toguest  (spiMosi),
	.spi_fromguest(spiMiso),
	.ps2k_dat_in  (ps2ki[1]),
	.ps2k_clk_in  (ps2ki[0]),
	.ps2k_clk_out (       ),
	.ps2k_dat_out (       ),
	.ps2m_dat_in  (1'b1   ),
	.ps2m_clk_in  (1'b1   ),
	.ps2m_dat_out (       ),
	.ps2m_clk_out (       ),
	.joy1         (8'hFF  ),
	.joy2         (8'hFF  ),
	.joy3         (8'hFF  ),
	.joy4         (8'hFF  ),
	.rxd          (1'b0   ),
	.txd          (       ),
	.intercept    (       ),
	.buttons      (32'hFFFFFFFF),
	.c64_keys     (64'hFFFFFFFFFFFFFFFF)
);

//-------------------------------------------------------------------------------------------------

localparam CONF_STR =
{
	"ZX;;",
	"F,ROM,Load ROM;",
	"S0,DSK,Mount drive A:;",
	"S1,DSK,Mount drive B:;",
	"S2,VHD,Mount SD;",
	"T1,Reset FPGA;",
	"V,V1.0;"
};

wire[ 2:0] sdRd;
wire[ 2:0] sdWr;
wire       sdAck;
wire       sdAckConf;
wire[31:0] sdLba = sdcBusy ? sdcLba : fddLba;
wire       sdConf;
wire       sdSdhc;
wire       sdBuffW;
wire[ 8:0] sdBuffA;
wire[ 7:0] sdBuffQ;
wire[ 7:0] sdBuffD = sdcBusy ? sdcBuffD : fddBuffD;

wire[ 2:0] imgMntd;
wire[63:0] imgSize;

wire[63:0] status;

user_io #(.STRLEN(100), .SD_IMAGES(3)) user_io
(
	.conf_str      (CONF_STR),
	.conf_addr     (        ),
	.conf_chr      (8'd0    ),

	.clk_sys       (clock   ),
	.clk_sd        (clock   ),

	.SPI_CLK       (spiCk   ),
	.SPI_SS_IO     (spiSsIo ),
	.SPI_MOSI      (spiMosi ),
	.SPI_MISO      (uioMiso ),

	.ps2_kbd_data  (ps2ko[1]),
	.ps2_kbd_clk   (ps2ko[0]),
	.ps2_kbd_data_i(1'b0),
	.ps2_kbd_clk_i (1'b0),

	.sd_rd         (sdRd     ),
	.sd_wr         (sdWr     ),
	.sd_ack        (sdAck    ),
	.sd_ack_conf   (sdAckConf),
	.sd_lba        (sdLba    ),
	.sd_dout_strobe(sdBuffW  ),
	.sd_buff_addr  (sdBuffA  ),
	.sd_dout       (sdBuffQ  ),
	.sd_din        (sdBuffD  ),
	.sd_ack_x      (         ),
	.sd_conf       (sdConf   ),
	.sd_sdhc       (sdSdhc   ),
	.sd_din_strobe (         ),

	.img_mounted   (imgMntd),
	.img_size      (imgSize),

	.ps2_mouse_data(),
	.ps2_mouse_clk (),
	.ps2_mouse_data_i(1'b0),
	.ps2_mouse_clk_i(1'b0),

	.key_code      (),
	.key_strobe    (),
	.key_pressed   (),
	.key_extended  (),

	.mouse_x       (),
	.mouse_y       (),
	.mouse_z       (),
	.mouse_idx     (),
	.mouse_flags   (),
	.mouse_strobe  (),

	.joystick_0    (),
	.joystick_1    (),
	.joystick_2    (),
	.joystick_3    (),
	.joystick_4    (),
	.joystick_analog_0(),
	.joystick_analog_1(),

	.rtc           (),
	.ypbpr         (),
	.status        (status),
	.buttons       (),
	.switches      (),
	.no_csync      (),
	.core_mod      (),
	.kbd_out_data  (8'd0),
	.kbd_out_strobe(1'b0),
	.serial_data   (8'd0),
	.serial_strobe (1'd0),
	.scandoubler_disable()
);

//-------------------------------------------------------------------------------------------------

data_io data_io
(
	.clk_sys       (clock  ),
	.clkref_n      (1'b0   ),
	.SPI_SCK       (spiCk  ),
	.SPI_SS2       (spiSs2 ),
	.SPI_SS4       (spiSs4 ),
	.SPI_DI        (spiMosi),
	.SPI_DO        (dioMiso),
	.ioctl_download(romIo  ),
	.ioctl_upload  (       ),
	.ioctl_index   (       ),
	.ioctl_wr      (romWr  ),
	.ioctl_addr    (romA   ),
	.ioctl_din     (8'h00  ),
	.ioctl_dout    (romD   ),
	.ioctl_fileext (       ),
	.ioctl_filesize(       ),
	.QCSn          (1'b1   ),
	.QSCK          (1'b1   ),
	.QDAT          (4'b1111),
	.hdd_clk       (1'b0   ),
	.hdd_cmd_req   (1'b0   ),
	.hdd_cdda_req  (1'b0   ),
	.hdd_dat_req   (1'b0   ),
	.hdd_cdda_wr   (       ),
	.hdd_status_wr (       ),
	.hdd_addr      (       ),
	.hdd_wr        (       ),
	.hdd_data_out  (       ),
	.hdd_data_in   (16'd0  ),
	.hdd_data_rd   (       ),
	.hdd_data_wr   (       ),
	.hdd0_ena      (       ),
	.hdd1_ena      (       )
);

//-------------------------------------------------------------------------------------------------

reg[1:0] fddRdy;
always @(posedge clock) if(imgMntd[0]) fddRdy[0] <= imgSize != 0;
always @(posedge clock) if(imgMntd[1]) fddRdy[1] <= imgSize != 0;

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

sd_card sd_card
(
	.clk_sys     (clock     ),
	.sd_rd       (sdRd[2]   ),
	.sd_wr       (sdWr[2]   ),
	.sd_ack      (sdAck     ),
	.sd_ack_conf (sdAckConf ),
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

wire[17:0] osdrgb;

osd #(.OSD_AUTO_CE(1'b0)) osd
(
	.clk_sys(clock  ),
	.ce     (cep1x  ),
	.SPI_SCK(spiCk  ),
	.SPI_SS3(spiSs3 ),
	.SPI_DI (spiMosi),
	.rotate (2'd0   ),
	.HSync  (isync[0]),
	.VSync  (isync[1]),
	.R_in   (irgb[17:12]),
	.G_in   (irgb[11: 6]),
	.B_in   (irgb[ 5: 0]),
	.R_out  (osdrgb[17:12]),
	.G_out  (osdrgb[11: 6]),
	.B_out  (osdrgb[ 5: 0])
);

//-------------------------------------------------------------------------------------------------

assign boot = ~status[1];

//-------------------------------------------------------------------------------------------------

wire vga;
flash flash(clock, vga, fshCs, fshCk, fshRst, fshMosi, fshMiso);

scandoubler scandoubler
(
	.clock  (clock  ),
	.enable (vga^tvga),
	.ice    (cep1x  ),
	.iblank (iblank ),
	.isync  (isync  ),
	.irgb   (osdrgb ),
	.oce    (cep2x  ),
	.osync  (osync  ),
	.orgb   (orgb   )
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
