derive_pll_clocks
derive_clock_uncertainty

create_clock -name clock50 -period 20.000 [get_ports clock50]
create_clock -name spiCk   -period 41.666 [get_registers demistify:demistify|substitute_mcu:controller|spi_controller:spi|sck]

set_clock_groups -asynchronous -group [get_clocks pll|altpll_component|auto_generated|pll1|clk[0]] -group [get_clocks spiCk]

set_false_path -to   {sync*}
set_false_path -to   {rgb*}
#set_false_path -to   {i2s*}
set_false_path -to   {dsg*}
set_false_path -to   {midi*}
#set_false_path -to   {ps2k*}
#set_false_path -to   {ps2m*}
set_false_path -to   {joy*}
set_false_path -to   {sdc*}
set_false_path -to   {sram*}
set_false_path -to   {dram*}
set_false_path -to   {stm}
set_false_path -to   {led}

set_false_path -from {tape}
set_false_path -from {ps2k*}
#set_false_path -from {ps2m*}
set_false_path -from {joy*}
set_false_path -from {sdc*}
#set_false_path -from {sram*}
