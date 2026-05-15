`timescale 1ns / 1ps

// 32 x 32-bit register file, x0 hardwired to zero
// Added debug read port for difftest / UART DebugController.
module regfile (
    input         clk,
    input         reset,

    input  [4:0]  rs1_addr,
    input  [4:0]  rs2_addr,
    input  [4:0]  rd_addr,
    input  [31:0] rd_data,
    input         rd_wen,

    output [31:0] rs1_data,
    output [31:0] rs2_data,

    // Debug register read port
    input  [4:0]  dbg_reg_addr,
    output [31:0] dbg_reg_data
);

    reg [31:0] rf [31:0];
    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'd0;
            end

            // Difftest batch test uses x3 (gp) as the hardwired data base.
            // The GUI prints: Data Base: 0x4000 - Hardwired to GP.
            // Therefore gp must be 0x00004000 after reset, otherwise the
            // testcase program loads/stores from address 0 and all results are 0.
            rf[5'd3] <= 32'h0000_4000;
        end else if (rd_wen && (rd_addr != 5'd0)) begin
            rf[rd_addr] <= rd_data;
        end
    end

    assign rs1_data     = (rs1_addr     == 5'd0) ? 32'd0 : rf[rs1_addr];
    assign rs2_data     = (rs2_addr     == 5'd0) ? 32'd0 : rf[rs2_addr];
    assign dbg_reg_data = (dbg_reg_addr == 5'd0) ? 32'd0 : rf[dbg_reg_addr];

endmodule
