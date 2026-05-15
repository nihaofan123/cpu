`timescale 1ns / 1ps

// Instruction memory for RV32I CPU
// Minimal debug-compatible version:
// - normal CPU fetch by PC address
// - UART debug read/write by inst_dbg_* ports
// - async read keeps your current single-cycle CPU behavior unchanged
module imem #(
    parameter DEPTH = 1024,
    parameter INIT_FILE = ""
) (
    input         clk,

    // Normal CPU fetch
    input  [31:0] addr,
    output [31:0] instr,

    // UART debug access
    input         inst_dbg_en,
    input         inst_wr_en,
    input  [31:0] inst_dbg_addr,
    input  [31:0] inst_wr_data,
    output [31:0] inst_rd_data
);

    (* ram_style = "block" *) reg [31:0] mem [0:DEPTH-1];

    integer i;
    reg [256*8-1:0] init_file_name;

    initial begin
        // Fill with NOP first, so empty memory will not become X.
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'h00000013; // addi x0, x0, 0
        end

        if ($value$plusargs("IMEM_INIT_FILE=%s", init_file_name)) begin
            $readmemh(init_file_name, mem);
        end else if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // Synchronize debug control/address/data into the imem clock domain.
    reg        inst_dbg_en_sync;
    reg        inst_wr_en_sync;
    reg [31:0] inst_dbg_addr_sync;
    reg [31:0] inst_wr_data_sync;

    always @(posedge clk) begin
        inst_dbg_en_sync   <= inst_dbg_en;
        inst_wr_en_sync    <= inst_wr_en;
        inst_dbg_addr_sync <= inst_dbg_addr;
        inst_wr_data_sync  <= inst_wr_data;
    end

    wire [$clog2(DEPTH)-1:0] cpu_word_addr = addr[$clog2(DEPTH)+1:2];
    wire [$clog2(DEPTH)-1:0] dbg_word_addr = inst_dbg_addr_sync[$clog2(DEPTH)+1:2];

    wire cpu_addr_valid = (addr < DEPTH * 4);
    wire dbg_addr_valid = (inst_dbg_addr_sync < DEPTH * 4);

    always @(posedge clk) begin
        if (inst_dbg_en_sync && inst_wr_en_sync && dbg_addr_valid) begin
            mem[dbg_word_addr] <= inst_wr_data_sync;
        end
    end

    assign instr        = cpu_addr_valid ? mem[cpu_word_addr] : 32'h00000013;
    assign inst_rd_data = dbg_addr_valid ? mem[dbg_word_addr] : 32'd0;

endmodule
