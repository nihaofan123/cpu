`timescale 1ns / 1ps

// Single-cycle RV32I CPU core
// Added UART debug control ports: halt, step, debug reset, register read, PC read.
module cpu_core (
    input         clk,
    input         reset,          // active-high physical reset, in CPU clock domain/asynchronous reset source

    // Debug control from DebugController
    input         cpu_halt,        // 1 = pause CPU state update
    input         cpu_step,        // pulse/level = allow one instruction when halted
    input         cpu_dbg_reset,   // debug soft reset pulse, stretched before entering this module
    input  [4:0]  dbg_reg_addr,
    output [31:0] dbg_reg_data,
    output [31:0] dbg_pc,

    // instruction memory interface
    input  [31:0] instr,
    output [31:0] pc,

    // data memory interface
    output [31:0] dmem_addr,
    output [31:0] dmem_wdata,
    output        dmem_wen,
    output        dmem_ren,
    input  [31:0] dmem_rdata
);

    // -------------------------------------------------------------------------
    // Synchronize debug control into CPU clock domain.
    // cpu_halt is a level; cpu_step/cpu_dbg_reset are stretched before entering
    // this module, then edge-detected here to avoid executing multiple steps.
    // -------------------------------------------------------------------------
    reg halt_s1, halt_s2;
    reg step_s1, step_s2, step_s2_d;
    reg dbg_rst_s1, dbg_rst_s2;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            halt_s1    <= 1'b1;
            halt_s2    <= 1'b1;
            step_s1    <= 1'b0;
            step_s2    <= 1'b0;
            step_s2_d  <= 1'b0;
            dbg_rst_s1 <= 1'b0;
            dbg_rst_s2 <= 1'b0;
        end else begin
            halt_s1    <= cpu_halt;
            halt_s2    <= halt_s1;
            step_s1    <= cpu_step;
            step_s2    <= step_s1;
            step_s2_d  <= step_s2;
            dbg_rst_s1 <= cpu_dbg_reset;
            dbg_rst_s2 <= dbg_rst_s1;
        end
    end

    wire dbg_reset_sync = dbg_rst_s2;
    wire step_pulse     = step_s2 & ~step_s2_d;

    // CPU is allowed to change architectural state only when running or stepping.
    wire cpu_active = (~halt_s2) | step_pulse;
    wire core_reset = reset | dbg_reset_sync;

    // ---- PC register ----
    reg [31:0] pc_r;
    assign pc     = pc_r;
    assign dbg_pc = pc_r;

    // ---- decoder signals ----
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    wire [3:0]  alu_op;
    wire        alu_src_a_sel;
    wire        alu_src_b_sel;
    wire        reg_wen;
    wire [1:0]  wb_sel;
    wire        mem_wen;
    wire        mem_ren;
    wire        branch;
    wire        jump;
    wire        jump_reg;
    wire        is_load;
    wire        is_store;

    decoder u_decoder (
        .instr         (instr),
        .rs1_addr      (rs1_addr),
        .rs2_addr      (rs2_addr),
        .rd_addr       (rd_addr),
        .imm_i         (imm_i),
        .imm_s         (imm_s),
        .imm_b         (imm_b),
        .imm_u         (imm_u),
        .imm_j         (imm_j),
        .alu_op        (alu_op),
        .alu_src_a_sel (alu_src_a_sel),
        .alu_src_b_sel (alu_src_b_sel),
        .reg_wen       (reg_wen),
        .wb_sel        (wb_sel),
        .mem_wen       (mem_wen),
        .mem_ren       (mem_ren),
        .branch        (branch),
        .jump          (jump),
        .jump_reg      (jump_reg),
        .is_load       (is_load),
        .is_store      (is_store)
    );

    // ---- register file ----
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] rd_data;

    regfile u_regfile (
        .clk          (clk),
        .reset        (core_reset),
        .rs1_addr     (rs1_addr),
        .rs2_addr     (rs2_addr),
        .rd_addr      (rd_addr),
        .rd_data      (rd_data),
        .rd_wen       (reg_wen && cpu_active),
        .rs1_data     (rs1_data),
        .rs2_data     (rs2_data),
        .dbg_reg_addr (dbg_reg_addr),
        .dbg_reg_data (dbg_reg_data)
    );

    // ---- ALU ----
    wire is_auipc = (instr[6:0] == 7'b0010111);
    wire [31:0] alu_imm = is_store ? imm_s :
                          is_auipc ? imm_u :
                                     imm_i;
    wire [31:0] alu_a   = (alu_src_a_sel) ? pc_r : rs1_data;
    wire [31:0] alu_b   = (alu_src_b_sel) ? alu_imm : rs2_data;
    wire [31:0] alu_result;
    wire        alu_zero;

    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // ---- Data memory interface ----
    assign dmem_addr  = alu_result;
    assign dmem_wdata = rs2_data;
    assign dmem_wen   = mem_wen && cpu_active;
    assign dmem_ren   = mem_ren && cpu_active;

    // ---- Writeback mux ----
    wire [31:0] pc_plus4 = pc_r + 32'd4;
    assign rd_data = (wb_sel == 2'b00) ? alu_result :
                     (wb_sel == 2'b01) ? dmem_rdata  :
                     (wb_sel == 2'b10) ? pc_plus4    :
                                         imm_u;

    // ---- Branch logic ----
    wire [2:0] branch_funct3 = instr[14:12];
    wire signed_lt = ($signed(rs1_data) < $signed(rs2_data));
    wire signed_ge = !signed_lt;
    reg branch_cond;

    always @(*) begin
        case (branch_funct3)
            3'b000:  branch_cond = alu_zero;   // BEQ
            3'b001:  branch_cond = !alu_zero;  // BNE
            3'b100:  branch_cond = signed_lt;  // BLT
            3'b101:  branch_cond = signed_ge;  // BGE
            default: branch_cond = 1'b0;
        endcase
    end

    wire branch_taken = branch && branch_cond;

    // ---- Jump target calculations ----
    wire [31:0] jump_target = pc_r + imm_j;
    wire [31:0] jalr_target = (rs1_data + imm_i) & ~32'd1;

    // ---- PC next ----
    wire [31:0] pc_next;
    assign pc_next = (jump_reg)     ? jalr_target      :
                     (jump)         ? jump_target      :
                     (branch_taken) ? (pc_r + imm_b)   :
                                      pc_plus4;

    // ---- PC update ----
    always @(posedge clk or posedge core_reset) begin
        if (core_reset) begin
            pc_r <= 32'h00000000;
        end else if (cpu_active) begin
            pc_r <= pc_next;
        end else begin
            pc_r <= pc_r;
        end
    end

endmodule
