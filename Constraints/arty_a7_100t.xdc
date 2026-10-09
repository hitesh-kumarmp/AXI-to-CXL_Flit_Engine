## Arty A7-100

## 100 MHz clock
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {CLK}]
create_clock -add -name sys_clk -period 10.000 -waveform {0 5} [get_ports {CLK}]

## USB-UART
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports {UART_RX}]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports {UART_TX}]

## Switch 0
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} [get_ports {SW[0]}]

## Button 0
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]

## LEDs
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {LED[0]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {LED[1]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {LED[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {LED[3]}]