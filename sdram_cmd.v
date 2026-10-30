//-------------------------------------------------------------------------------------------------
// This file is part of the ZX Spectrum +3 project.
// https://github.com/kyp069/zxp3
//-------------------------------------------------------------------------------------------------

task NOP;
begin
	dramCe  <= 1'b1;
	dramCs  <= 1'b0;
	dramRas <= 1'b1;
	dramCas <= 1'b1;
	dramWe  <= 1'b1;
	dramDQM <= 2'b11;
	dramDQ  <= 16'bZ;
	dramBA  <= 2'b00;
	dramA   <= 13'd0;
end
endtask

task LMR;
input[12:0] mode;
begin
	dramCe  <= 1'b1;
	dramCs  <= 1'b0;
	dramRas <= 1'b0;
	dramCas <= 1'b0;
	dramWe  <= 1'b0;
	dramDQM <= 2'b11;
	dramDQ  <= 16'bZ;
	dramBA  <= 2'b00;
	dramA   <= mode;
end
endtask

task ACTIVE;
input[ 1:0] ba;
input[12:0] a;
begin
	dramCe  <= 1'b1;
	dramCs  <= 1'b0;
	dramRas <= 1'b0;
	dramCas <= 1'b1;
	dramWe  <= 1'b1;
	dramDQM <= 2'b11;
	dramDQ  <= 16'bZ;
	dramBA  <= ba;
	dramA   <= a;
end
endtask

task READ;
input[ 1:0] ba;
input[ 8:0] a;
input[ 1:0] dqm;
input pch;
begin
	dramCe  <= 1'b1;
	dramCs  <= 1'b0;
	dramRas <= 1'b1;
	dramCas <= 1'b0;
	dramWe  <= 1'b1;
	dramDQM <= dqm;
	dramDQ  <= 16'bZ;
	dramBA  <= ba;
	dramA   <= { 2'b00, pch, 1'b0, a };
end
endtask

task WRITE;
input[ 1:0] ba;
input[ 8:0] a;
input[ 1:0] dqm;
input[15:0] d;
input pch;
begin
	dramCe  <= 1'b1;
	dramCs  <= 1'b0;
	dramRas <= 1'b1;
	dramCas <= 1'b0;
	dramWe  <= 1'b0;
	dramDQM <= dqm;
	dramDQ  <= d;
	dramBA  <= ba;
	dramA   <= { 2'b00, pch, 1'b0, a };
end
endtask

task REFRESH;
begin
	dramCe  <= 1'b1;
	dramCs  <= 1'b0;
	dramRas <= 1'b0;
	dramCas <= 1'b0;
	dramWe  <= 1'b1;
	dramDQM <= 2'b11;
	dramDQ  <= 16'bZ;
	dramBA  <= 2'b00;
	dramA   <= 13'd0;
end
endtask

task PRECHARGE;
input[ 1:0] ba;
input pch;
begin
	dramCe  <= 1'b1;
	dramCs  <= 1'b0;
	dramRas <= 1'b0;
	dramCas <= 1'b1;
	dramWe  <= 1'b0;
	dramDQM <= 2'b11;
	dramDQ  <= 16'bZ;
	dramBA  <= ba;
	dramA   <= { 2'b00, pch, 10'd0 };
end
endtask

//-------------------------------------------------------------------------------------------------
