//-------------------------------------------------------------------------------------------------
module i2s_in
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
	input  wire[ 2:0] i2s,
	output reg [15:0] left,
	output reg [15:0] right
);
//-------------------------------------------------------------------------------------------------

reg[1:0] cks;
always @(posedge clock) cks <= { cks[0], i2s[0] };

//-------------------------------------------------------------------------------------------------

reg ckd;
wire ckp = cks[1] && !ckd;
always @(posedge clock) ckd <= cks[1];

reg lrd;
wire lrp = i2s[1] != lrd;
always @(posedge clock) if(ckp) lrd <= i2s[1];

//-------------------------------------------------------------------------------------------------

reg[16:0] sr = 17'd1;
always @(posedge clock) if(ckp) begin
	if(lrp) begin
		sr <= 17'd1;
		if(lrd) right <= sr[15:0]; else left <= sr[15:0];
	end
	else if(!sr[16]) sr <= { sr[15:0], i2s[2] };
end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
