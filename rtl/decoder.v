`timescale 1ns / 1ps

// RV32I decoder for the subset required by the project
module decoder (
    input  [31:0] instr,
    // register addresses
    output [4:0]  rs1_addr,
    output [4:0]  rs2_addr,
    output [4:0]  rd_addr,
    // immediate values (raw, used by cpu_core)
    output [31:0] imm_i,   // I-type
    output [31:0] imm_s,   // S-type
    output [31:0] imm_b,   // B-type
    output [31:0] imm_u,   // U-type
    output [31:0] imm_j,   // J-type
    // ALU control
    output [3:0]  alu_op,
    output        alu_src_a_sel,  // 0=rs1_data, 1=PC (for auipc)
    output        alu_src_b_sel,  // 0=rs2_data, 1=imm (I-type)
    // register writeback
    output        reg_wen,
    output [1:0]  wb_sel,         // 00=alu_result, 01=mem_rdata, 10=pc+4, 11=imm_u
    // memory control
    output        mem_wen,
    output        mem_ren,
    // branch / jump
    output        branch,
    output        jump,
    output        jump_reg,        // jalr
    // instruction type identification
    output        is_load,
    output        is_store
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    // register addresses
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr  = instr[11:7];

    // ---- immediate generation ----
    // I-type
    assign imm_i = {{21{instr[31]}}, instr[30:25], instr[24:21], instr[20]};
    // S-type
    assign imm_s = {{21{instr[31]}}, instr[30:25], instr[11:8], instr[7]};
    // B-type
    assign imm_b = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    // U-type
    assign imm_u = {instr[31:12], 12'd0};
    // J-type
    assign imm_j = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:25], instr[24:21], 1'b0};

    // ---- control signal defaults ----
    reg [3:0]  alu_op_r;
    reg        alu_src_a_sel_r;
    reg        alu_src_b_sel_r;
    reg        reg_wen_r;
    reg [1:0]  wb_sel_r;
    reg        mem_wen_r;
    reg        mem_ren_r;
    reg        branch_r;
    reg        jump_r;
    reg        jump_reg_r;
    reg        is_load_r;
    reg        is_store_r;
    reg        illegal_instr_r;

    assign alu_op         = alu_op_r;
    assign alu_src_a_sel  = alu_src_a_sel_r;
    assign alu_src_b_sel  = alu_src_b_sel_r;
    assign reg_wen        = reg_wen_r;
    assign wb_sel         = wb_sel_r;
    assign mem_wen        = mem_wen_r;
    assign mem_ren        = mem_ren_r;
    assign branch         = branch_r;
    assign jump           = jump_r;
    assign jump_reg       = jump_reg_r;
    assign is_load        = is_load_r;
    assign is_store       = is_store_r;

    always @(*) begin
        // defaults
        alu_op_r        = 4'b0000;  // ADD
        alu_src_a_sel_r = 1'b0;     // rs1
        alu_src_b_sel_r = 1'b0;     // rs2
        reg_wen_r       = 1'b0;
        wb_sel_r        = 2'b00;    // alu_result
        mem_wen_r       = 1'b0;
        mem_ren_r       = 1'b0;
        branch_r        = 1'b0;
        jump_r          = 1'b0;
        jump_reg_r      = 1'b0;
        is_load_r       = 1'b0;
        is_store_r      = 1'b0;
        illegal_instr_r = 1'b0;

        case (opcode)
            7'b0110011: begin // R-type
                reg_wen_r       = 1'b1;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_op_r = 4'b0000; // ADD
                        else if (funct7 == 7'b0100000)
                            alu_op_r = 4'b0001; // SUB
                        else
                            illegal_instr_r = 1'b1;
                    end
                    3'b111: alu_op_r = 4'b0010; // AND
                    3'b110: alu_op_r = 4'b0011; // OR
                    3'b100: alu_op_r = 4'b0100; // XOR
                    3'b001: alu_op_r = 4'b0101; // SLL
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_op_r = 4'b0110; // SRL
                        else if (funct7 == 7'b0100000)
                            alu_op_r = 4'b0111; // SRA
                        else
                            illegal_instr_r = 1'b1;
                    end
                    3'b010: alu_op_r = 4'b1000; // SLT
                    default: illegal_instr_r = 1'b1;
                endcase
            end

            7'b0010011: begin // I-type ALU
                reg_wen_r       = 1'b1;
                alu_src_b_sel_r = 1'b1; // use immediate
                case (funct3)
                    3'b000: alu_op_r = 4'b0000; // ADDI
                    3'b111: alu_op_r = 4'b0010; // ANDI
                    3'b110: alu_op_r = 4'b0011; // ORI
                    3'b100: alu_op_r = 4'b0100; // XORI
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_op_r = 4'b0101; // SLLI
                        else
                            illegal_instr_r = 1'b1;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_op_r = 4'b0110; // SRLI
                        else if (funct7 == 7'b0100000)
                            alu_op_r = 4'b0111; // SRAI
                        else
                            illegal_instr_r = 1'b1;
                    end
                    3'b010: alu_op_r = 4'b1000; // SLTI
                    default: illegal_instr_r = 1'b1;
                endcase
            end

            7'b0000011: begin // Load
                if (funct3 == 3'b010) begin
                    is_load_r       = 1'b1;
                    reg_wen_r       = 1'b1;
                    mem_ren_r       = 1'b1;
                    alu_src_b_sel_r = 1'b1; // use immediate offset
                    alu_op_r        = 4'b0000; // ADD base + offset
                    wb_sel_r        = 2'b01; // mem_rdata
                end else begin
                    illegal_instr_r = 1'b1;
                end
            end

            7'b0100011: begin // Store
                if (funct3 == 3'b010) begin
                    is_store_r      = 1'b1;
                    mem_wen_r       = 1'b1;
                    alu_src_b_sel_r = 1'b1; // use immediate offset
                    alu_op_r        = 4'b0000; // ADD base + offset
                end else begin
                    illegal_instr_r = 1'b1;
                end
            end

            7'b1100011: begin // B-type (branch)
                case (funct3)
                    3'b000, 3'b001, 3'b100, 3'b101: begin
                        branch_r = 1'b1;
                        alu_op_r = 4'b0001; // SUB for equality compare helper
                    end
                    default: illegal_instr_r = 1'b1;
                endcase
            end

            7'b1101111: begin // JAL
                jump_r          = 1'b1;
                reg_wen_r       = 1'b1;
                wb_sel_r        = 2'b10; // pc+4
            end

            7'b1100111: begin // JALR
                if (funct3 == 3'b000) begin
                    jump_reg_r      = 1'b1;
                    reg_wen_r       = 1'b1;
                    alu_src_b_sel_r = 1'b1; // use immediate
                    alu_op_r        = 4'b0000; // ADD
                    wb_sel_r        = 2'b10; // pc+4
                end else begin
                    illegal_instr_r = 1'b1;
                end
            end

            7'b0110111: begin // LUI
                reg_wen_r       = 1'b1;
                wb_sel_r        = 2'b11; // imm_u
            end

            7'b0010111: begin // AUIPC
                reg_wen_r       = 1'b1;
                alu_src_a_sel_r = 1'b1;   // PC
                alu_src_b_sel_r = 1'b1;   // imm
                alu_op_r        = 4'b0000; // ADD
                wb_sel_r        = 2'b00;  // alu_result
            end

            default: begin
                // unrecognized opcode, all signals stay at 0
            end
        endcase

        if (illegal_instr_r) begin
            alu_op_r        = 4'b0000;
            alu_src_a_sel_r = 1'b0;
            alu_src_b_sel_r = 1'b0;
            reg_wen_r       = 1'b0;
            wb_sel_r        = 2'b00;
            mem_wen_r       = 1'b0;
            mem_ren_r       = 1'b0;
            branch_r        = 1'b0;
            jump_r          = 1'b0;
            jump_reg_r      = 1'b0;
            is_load_r       = 1'b0;
            is_store_r      = 1'b0;
        end
    end

endmodule
