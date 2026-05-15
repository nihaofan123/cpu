`timescale 1ns / 1ps

// Data memory with MMIO dispatch for RV32I CPU
// Added UART debug read/write ports for difftest.
//
// Important:
//   difftest-gui prints: Data Base: 0x4000 - Hardwired to GP.
//   That means test operands/results are accessed through addresses around
//   0x0000_4000, with x3/gp initialized to 0x0000_4000.
//
// To save FPGA LUT memory, we DO NOT allocate a real sparse memory covering
// 0x0000_0000 ~ 0x0000_4000. Instead, this module maps the case-base window:
//
//   0x0000_4000 -> mem[0]
//   0x0000_4004 -> mem[1]
//   0x0000_4008 -> mem[2]
//   ...
//
// So DEPTH=1024 is enough for the current difftest data area.
module dmem #(
    parameter DEPTH = 1024,
    parameter INIT_DATA_FILE = "",
    parameter CASE_BASE = 32'h0000_4000
) (
    input         clk,

    // Normal CPU data memory interface
    input  [31:0] addr,
    input  [31:0] wdata,
    input         wen,
    input         ren,

    // MMIO interface
    input  [31:0] mmio_rdata,
    output [31:0] rdata,
    output        mmio_sel,
    output [31:0] mmio_addr,
    output [31:0] mmio_wdata,
    output        mmio_wen,

    // UART debug access to local data memory
    input         dmem_dbg_en,
    input         dmem_wr_en,
    input  [31:0] dmem_dbg_addr,
    input  [31:0] dmem_wr_data,
    output [31:0] dmem_rd_data
);

    // Keep asynchronous read behavior because the current CPU is single-cycle.
    // Do not increase DEPTH to 8192; use the 0x4000 window remap instead.
    reg [31:0] mem [0:DEPTH-1];

    integer i;
    reg [256*8-1:0] dmem_init_file_name;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'd0;
        end

        if ($value$plusargs("DMEM_INIT_FILE=%s", dmem_init_file_name)) begin
            $readmemh(dmem_init_file_name, mem);
        end else if (INIT_DATA_FILE != "") begin
            $readmemh(INIT_DATA_FILE, mem);
        end
    end

    // Synchronize debug control/address/data into dmem clock domain.
    reg        dmem_dbg_en_sync   = 1'b0;
    reg        dmem_wr_en_sync    = 1'b0;
    reg [31:0] dmem_dbg_addr_sync = 32'd0;
    reg [31:0] dmem_wr_data_sync  = 32'd0;

    always @(posedge clk) begin
        dmem_dbg_en_sync   <= dmem_dbg_en;
        dmem_wr_en_sync    <= dmem_wr_en;
        dmem_dbg_addr_sync <= dmem_dbg_addr;
        dmem_wr_data_sync  <= dmem_wr_data;
    end

    // MMIO region: any address >= 0xFFFF0000
    wire is_mmio = (addr[31:16] == 16'hFFFF);

    // -----------------------------
    // Address translation function
    // -----------------------------
    // Valid physical windows:
    //   1. low window       [0, DEPTH*4)
    //   2. testcase window  [CASE_BASE, CASE_BASE + DEPTH*4)
    // Both are mapped to local addresses [0, DEPTH*4).

    localparam [31:0] MEM_BYTES = DEPTH * 4;

    wire [31:0] cpu_case_offset = addr - CASE_BASE;
    wire [31:0] dbg_case_offset = dmem_dbg_addr_sync - CASE_BASE;

    wire cpu_low_valid  = (addr < MEM_BYTES);
    wire dbg_low_valid  = (dmem_dbg_addr_sync < MEM_BYTES);

    wire cpu_case_valid = (addr >= CASE_BASE) && (cpu_case_offset < MEM_BYTES);
    wire dbg_case_valid = (dmem_dbg_addr_sync >= CASE_BASE) && (dbg_case_offset < MEM_BYTES);

    wire cpu_addr_valid = cpu_low_valid || cpu_case_valid;
    wire dbg_addr_valid = dbg_low_valid || dbg_case_valid;

    wire [31:0] cpu_local_addr = cpu_case_valid ? cpu_case_offset : addr;
    wire [31:0] dbg_local_addr = dbg_case_valid ? dbg_case_offset : dmem_dbg_addr_sync;

    wire [$clog2(DEPTH)-1:0] cpu_word_addr = cpu_local_addr[$clog2(DEPTH)+1:2];
    wire [$clog2(DEPTH)-1:0] dbg_word_addr = dbg_local_addr[$clog2(DEPTH)+1:2];

    // Local memory write. Debug access has priority over CPU local-memory write.
    always @(posedge clk) begin
        if (dmem_dbg_en_sync) begin
            if (dmem_wr_en_sync && dbg_addr_valid) begin
                mem[dbg_word_addr] <= dmem_wr_data_sync;
            end
        end else if (wen && !is_mmio && cpu_addr_valid) begin
            mem[cpu_word_addr] <= wdata;
        end
    end

    // Local memory read is combinational to preserve current single-cycle CPU timing.
    wire [31:0] local_rdata = cpu_addr_valid ? mem[cpu_word_addr] : 32'd0;

    assign rdata = (ren && is_mmio) ? mmio_rdata : local_rdata;

    // Debug reads local data memory only, including the remapped 0x4000 testcase window.
    assign dmem_rd_data = dbg_addr_valid ? mem[dbg_word_addr] : 32'd0;

    // MMIO interface. Disable MMIO write while debug is taking over dmem port.
    assign mmio_sel   = is_mmio;
    assign mmio_addr  = addr;
    assign mmio_wdata = wdata;
    assign mmio_wen   = (!dmem_dbg_en_sync) && wen && is_mmio;

endmodule
