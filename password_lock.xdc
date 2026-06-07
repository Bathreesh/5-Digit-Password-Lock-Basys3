## Clock
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 \
             -waveform {0 5} [get_ports clk]

## Buttons
set_property PACKAGE_PIN U18 [get_ports btn_c]   ;# BTNC
set_property PACKAGE_PIN T18 [get_ports btn_u]   ;# BTNU
set_property PACKAGE_PIN W19 [get_ports btn_l]   ;# BTNL
set_property PACKAGE_PIN T17 [get_ports btn_r]   ;# BTNR
set_property PACKAGE_PIN U17 [get_ports btn_d]   ;# BTND

set_property IOSTANDARD LVCMOS33 [get_ports btn_c]
set_property IOSTANDARD LVCMOS33 [get_ports btn_u]
set_property IOSTANDARD LVCMOS33 [get_ports btn_l]
set_property IOSTANDARD LVCMOS33 [get_ports btn_r]
set_property IOSTANDARD LVCMOS33 [get_ports btn_d]

## Mode Switch
set_property PACKAGE_PIN V17 [get_ports sw_mode]  ;# SW[0]
set_property IOSTANDARD LVCMOS33 [get_ports sw_mode]

## LEDs
set_property PACKAGE_PIN U16 [get_ports led_locked]  ;# LED[0]
set_property PACKAGE_PIN E19 [get_ports led_unlock]  ;# LED[1]
set_property PACKAGE_PIN U19 [get_ports led_wrong]   ;# LED[2]

set_property IOSTANDARD LVCMOS33 [get_ports led_locked]
set_property IOSTANDARD LVCMOS33 [get_ports led_unlock]
set_property IOSTANDARD LVCMOS33 [get_ports led_wrong]