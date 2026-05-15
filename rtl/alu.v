`timescale 1ns / 1ps

// Single-cycle ALU for RV32I subset
module alu (
    input  [31:0] a,
    input  [31:0] b,
    input  [3:0]  op,
    output [31:0] result,
    output        zero           // 1 when result == 0
);

    reg [31:0] r;

    always @(*) begin
        case (op)
            4'b0000: r = a + b;                        // ADD
            4'b0001: r = a - b;                        // SUB
            4'b0010: r = a & b;                        // AND
            4'b0011: r = a | b;                        // OR
            4'b0100: r = a ^ b;                        // XOR
            4'b0101: r = a << b[4:0];                  // SLL
            4'b0110: r = a >> b[4:0];                  // SRL
            4'b0111: r = $signed(a) >>> b[4:0];        // SRA
            4'b1000: r = {31'd0, ($signed(a) < $signed(b))}; // SLT
            default: r = 32'hxxxxxxxx;
        endcase
    end

    assign result = r;
    assign zero   = (r == 32'd0);

endmodule
