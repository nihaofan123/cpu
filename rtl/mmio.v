`timescale 1ns / 1ps

// Memory-mapped IO module for board peripherals
// Addresses:
//   0xFFFF0000 - Switch input (read)
//   0xFFFF0004 - Button input (read)
//   0xFFFF0008 - LED output (write)
//   0xFFFF000C - Debug/result output (write)
module mmio (
    input         clk,
    input         reset,
    // Logical MMIO registers
    input  [31:0] input_a,
    input  [31:0] input_b,
    output [15:0] leds,
    output [31:0] debug_out,
    // dmem interface
    input  [31:0] addr,
    input  [31:0] wdata,
    input         wen,
    output [31:0] rdata
);

    reg [31:0] led_reg;
    reg [31:0] debug_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            led_reg   <= 32'd0;
            debug_reg <= 32'd0;
        end else if (wen) begin
            case (addr)
                32'hFFFF0008: led_reg   <= wdata;
                32'hFFFF000C: debug_reg <= wdata;
                default: ;
            endcase
        end
    end

    // Read mux
    assign rdata = (addr == 32'hFFFF0000) ? input_a :
                   (addr == 32'hFFFF0004) ? input_b :
                   32'd0;

    assign leds      = led_reg[15:0];
    assign debug_out = debug_reg;

endmodule
