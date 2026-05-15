`timescale 1ns / 1ps

// Top-level for UART debug / difftest-gui.
// clk : 100MHz system clock
// rst : active-low reset button
module TopDebug (
    input        clk,
    input        rst,

    // UART
    input        uart_rxd,
    output       uart_txd,

    // Keep switch/LED MMIO so your old board tests can still run.
    input  [7:0] switches,
    output [7:0] leds
);

    // -------------------------------------------------------------------------
    // 100MHz -> 25MHz CPU clock.
    // DebugController/UART use 100MHz; CPU/memories use 25MHz.
    // -------------------------------------------------------------------------
    reg [1:0] clk_div;
    always @(posedge clk or negedge rst) begin
        if (!rst)
            clk_div <= 2'b00;
        else
            clk_div <= clk_div + 2'b01;
    end

    wire cpu_clk_raw = clk_div[1];
    wire cpu_clk;

    // In Vivado this gives a clean global clock for the divided CPU clock.
    BUFG u_cpu_clk_bufg (
        .I(cpu_clk_raw),
        .O(cpu_clk)
    );

    // -------------------------------------------------------------------------
    // UART RX / TX at 100MHz
    // -------------------------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_valid;
    wire [7:0] tx_data;
    wire       tx_start;
    wire       tx_busy;

    UartRx #(
        .CLK_FREQ(100_000_000),
        .BAUD    (115200)
    ) uUartRx (
        .clk      (clk),
        .rst_n    (rst),
        .rx_pin   (uart_rxd),
        .rx_data  (rx_data),
        .rx_valid (rx_valid)
    );

    UartTx #(
        .CLK_FREQ(100_000_000),
        .BAUD    (115200)
    ) uUartTx (
        .clk      (clk),
        .rst_n    (rst),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .tx_busy  (tx_busy),
        .tx_pin   (uart_txd)
    );

    // -------------------------------------------------------------------------
    // DebugController signals
    // -------------------------------------------------------------------------
    wire        cpu_halt;
    wire        cpu_step;
    wire        cpu_reset_pulse_100m;

    wire [4:0]  dbg_reg_addr;
    wire [31:0] dbg_reg_data;
    wire [31:0] dbg_pc;

    wire        inst_dbg_en;
    wire        inst_wr_en;
    wire [31:0] inst_dbg_addr;
    wire [31:0] inst_wr_data;
    wire [31:0] inst_rd_data;

    wire        dmem_dbg_en;
    wire        dmem_wr_en;
    wire [31:0] dmem_dbg_addr;
    wire [31:0] dmem_wr_data;
    wire [31:0] dmem_rd_data;

    DebugController uDebugCtrl (
        .clk           (clk),
        .rst_n         (rst),

        // UART
        .rx_data       (rx_data),
        .rx_valid      (rx_valid),
        .tx_data       (tx_data),
        .tx_start      (tx_start),
        .tx_busy       (tx_busy),

        // CPU control
        .cpu_halt      (cpu_halt),
        .cpu_step      (cpu_step),
        .cpu_reset     (cpu_reset_pulse_100m),

        // Register read
        .dbg_reg_addr  (dbg_reg_addr),
        .dbg_reg_data  (dbg_reg_data),

        // Instruction memory debug
        .inst_dbg_en   (inst_dbg_en),
        .inst_wr_en    (inst_wr_en),
        .inst_dbg_addr (inst_dbg_addr),
        .inst_wr_data  (inst_wr_data),
        .inst_rd_data  (inst_rd_data),

        // Data memory debug
        .dmem_dbg_en   (dmem_dbg_en),
        .dmem_wr_en    (dmem_wr_en),
        .dmem_dbg_addr (dmem_dbg_addr),
        .dmem_wr_data  (dmem_wr_data),
        .dmem_rd_data  (dmem_rd_data),

        // PC
        .dbg_pc        (dbg_pc)
    );

    // Stretch debug reset, otherwise a 1-cycle 100MHz pulse may be missed by 25MHz CPU clock.
    reg [4:0] cpu_reset_cnt;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            cpu_reset_cnt <= 5'd0;
        end else if (cpu_reset_pulse_100m) begin
            cpu_reset_cnt <= 5'd20;
        end else if (cpu_reset_cnt != 5'd0) begin
            cpu_reset_cnt <= cpu_reset_cnt - 5'd1;
        end
    end

    wire cpu_dbg_reset_stretched = (cpu_reset_cnt != 5'd0);
    wire reset_active_high       = ~rst;

    // -------------------------------------------------------------------------
    // CPU + memories + MMIO
    // -------------------------------------------------------------------------
    wire [31:0] pc;
    wire [31:0] instr;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_wen;
    wire        dmem_ren;
    wire [31:0] dmem_rdata;

    wire [31:0] mmio_addr;
    wire [31:0] mmio_wdata;
    wire        mmio_wen;
    wire [31:0] mmio_rdata;
    wire        mmio_sel;

    wire [15:0] leds_internal;
    wire [31:0] debug_out_internal;

    imem #(
        .DEPTH     (1024),
        .INIT_FILE ("")
    ) u_imem (
        .clk           (cpu_clk),
        .addr          (pc),
        .instr         (instr),
        .inst_dbg_en   (inst_dbg_en),
        .inst_wr_en    (inst_wr_en),
        .inst_dbg_addr (inst_dbg_addr),
        .inst_wr_data  (inst_wr_data),
        .inst_rd_data  (inst_rd_data)
    );

    cpu_core u_cpu_core (
        .clk          (cpu_clk),
        .reset        (reset_active_high),

        .cpu_halt     (cpu_halt),
        .cpu_step     (cpu_step),
        .cpu_dbg_reset(cpu_dbg_reset_stretched),
        .dbg_reg_addr (dbg_reg_addr),
        .dbg_reg_data (dbg_reg_data),
        .dbg_pc       (dbg_pc),

        .instr        (instr),
        .pc           (pc),

        .dmem_addr    (dmem_addr),
        .dmem_wdata   (dmem_wdata),
        .dmem_wen     (dmem_wen),
        .dmem_ren     (dmem_ren),
        .dmem_rdata   (dmem_rdata)
    );

    dmem #(
        .DEPTH          (1024),  // 4KB physical RAM; 0x4000 testcase window is remapped in dmem
        .INIT_DATA_FILE (""),
        .CASE_BASE      (32'h0000_4000)
    ) u_dmem (
        .clk           (cpu_clk),
        .addr          (dmem_addr),
        .wdata         (dmem_wdata),
        .wen           (dmem_wen),
        .ren           (dmem_ren),

        .mmio_rdata    (mmio_rdata),
        .rdata         (dmem_rdata),
        .mmio_sel      (mmio_sel),
        .mmio_addr     (mmio_addr),
        .mmio_wdata    (mmio_wdata),
        .mmio_wen      (mmio_wen),

        .dmem_dbg_en   (dmem_dbg_en),
        .dmem_wr_en    (dmem_wr_en),
        .dmem_dbg_addr (dmem_dbg_addr),
        .dmem_wr_data  (dmem_wr_data),
        .dmem_rd_data  (dmem_rd_data)
    );

    mmio u_mmio (
        .clk       (cpu_clk),
        .reset     (reset_active_high | cpu_dbg_reset_stretched),
        .input_a   ({24'd0, switches}),
        .input_b   (32'd0),
        .leds      (leds_internal),
        .debug_out (debug_out_internal),
        .addr      (mmio_addr),
        .wdata     (mmio_wdata),
        .wen       (mmio_wen),
        .rdata     (mmio_rdata)
    );

    assign leds = leds_internal[7:0];

endmodule
