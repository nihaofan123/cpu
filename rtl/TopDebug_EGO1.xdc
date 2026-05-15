## =============================================================
## EGO1 constraints for TopDebug.v
## Top module ports:
##   input        clk
##   input        rst        // active-low reset button
##   input        uart_rxd   // PC -> FPGA, FPGA RX
##   output       uart_txd   // FPGA -> PC, FPGA TX
##   input  [7:0] switches
##   output [7:0] leds
## =============================================================

## -------------------------------
## 100 MHz system clock
## EGO1 SYS_CLK = P17
## -------------------------------
set_property PACKAGE_PIN P17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

## -------------------------------
## Reset button
## EGO1 FPGA_RESET = P15
## TopDebug.rst is active-low.
## -------------------------------
set_property PACKAGE_PIN P15 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property PULLUP true [get_ports rst]

## -------------------------------
## USB-UART/JTAG interface
## Manual table:
##   T4 = FPGA serial transmit side  -> connect to uart_txd
##   N5 = FPGA serial receive side   -> connect to uart_rxd
## -------------------------------
set_property PACKAGE_PIN N5 [get_ports uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd]

set_property PACKAGE_PIN T4 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]

## -------------------------------
## 8 toggle switches: SW_0 ~ SW_7
## Used by MMIO input 0xFFFF0000.
## -------------------------------
set_property PACKAGE_PIN R1 [get_ports {switches[0]}]
set_property PACKAGE_PIN N4 [get_ports {switches[1]}]
set_property PACKAGE_PIN M4 [get_ports {switches[2]}]
set_property PACKAGE_PIN R2 [get_ports {switches[3]}]
set_property PACKAGE_PIN P2 [get_ports {switches[4]}]
set_property PACKAGE_PIN P3 [get_ports {switches[5]}]
set_property PACKAGE_PIN P4 [get_ports {switches[6]}]
set_property PACKAGE_PIN P5 [get_ports {switches[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {switches[*]}]

## -------------------------------
## 8 LEDs: LED2_0 ~ LED2_7
## Used by MMIO output 0xFFFF0008.
## This mapping follows the lab-style LED[0]=K2 ... LED[7]=F6 row.
## -------------------------------
set_property PACKAGE_PIN K2 [get_ports {leds[0]}]
set_property PACKAGE_PIN J2 [get_ports {leds[1]}]
set_property PACKAGE_PIN J3 [get_ports {leds[2]}]
set_property PACKAGE_PIN H4 [get_ports {leds[3]}]
set_property PACKAGE_PIN J4 [get_ports {leds[4]}]
set_property PACKAGE_PIN G3 [get_ports {leds[5]}]
set_property PACKAGE_PIN G4 [get_ports {leds[6]}]
set_property PACKAGE_PIN F6 [get_ports {leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[*]}]

## =============================================================
## Optional alternative mappings
## =============================================================

## If you want to use the 8 DIP switches instead of the 8 toggle switches,
## comment the switch constraints above and use these instead:
# set_property PACKAGE_PIN T5 [get_ports {switches[0]}]
# set_property PACKAGE_PIN T3 [get_ports {switches[1]}]
# set_property PACKAGE_PIN R3 [get_ports {switches[2]}]
# set_property PACKAGE_PIN V4 [get_ports {switches[3]}]
# set_property PACKAGE_PIN V5 [get_ports {switches[4]}]
# set_property PACKAGE_PIN V2 [get_ports {switches[5]}]
# set_property PACKAGE_PIN U2 [get_ports {switches[6]}]
# set_property PACKAGE_PIN U3 [get_ports {switches[7]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {switches[*]}]

## If you want to use the other 8-LED row, comment the LED2 constraints above
## and use LED1_0 ~ LED1_7 instead:
# set_property PACKAGE_PIN K3 [get_ports {leds[0]}]
# set_property PACKAGE_PIN M1 [get_ports {leds[1]}]
# set_property PACKAGE_PIN L1 [get_ports {leds[2]}]
# set_property PACKAGE_PIN K6 [get_ports {leds[3]}]
# set_property PACKAGE_PIN J5 [get_ports {leds[4]}]
# set_property PACKAGE_PIN H5 [get_ports {leds[5]}]
# set_property PACKAGE_PIN H6 [get_ports {leds[6]}]
# set_property PACKAGE_PIN K1 [get_ports {leds[7]}]
# set_property IOSTANDARD LVCMOS33 [get_ports {leds[*]}]

## Optional: make unused pins harmless. Usually not required.
# set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
