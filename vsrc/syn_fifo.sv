// -----------------------------------------------------------------------------
// Module: syn_fifo
// Type  : Simple synchronous FIFO (single clock domain)
// Purpose: Provide byte buffering between AXI register accesses and UART logic.
// Structure: PARAMETERS → STATE MACHINE → REGISTERS → COMBINATIONAL LOGIC →
//            INSTANTIATION → PROCESSES
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

// --- Port list ---
// clk      : System clock shared by producer and consumer.
// rst      : Asynchronous active-low reset.
// data_in  : Write data input.
// rd_en    : Read enable from the consumer domain.
// rd_valid : Read data valid pulse.
// wr_en    : Write enable from the producer domain.
// wr_ready : Always-true indicator (no throttling implemented).
// data_out : Registered read data output.
// empty    : FIFO empty status.
// full     : FIFO full status (depth-1 convention preserved).
// TODO: Add programmable almost-full/empty thresholds for flow control.

module syn_fifo #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  rd_en,
    output logic                  rd_valid,
    input  logic                  wr_en,
    output logic                  wr_ready,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  empty,
    output logic                  full
);

    localparam int unsigned RAM_DEPTH = (1 << ADDR_WIDTH);

    // =========================================================================
    // REGISTERS
    // =========================================================================
    logic [DATA_WIDTH-1:0] mem [RAM_DEPTH-1:0];
    logic [ADDR_WIDTH-1:0] wr_pointer_q;
    logic [ADDR_WIDTH-1:0] wr_pointer_d;
    logic [ADDR_WIDTH-1:0] rd_pointer_q;
    logic [ADDR_WIDTH-1:0] rd_pointer_d;
    logic [ADDR_WIDTH:0]   status_cnt_q;
    logic [ADDR_WIDTH:0]   status_cnt_d;
    logic [DATA_WIDTH-1:0] data_out_q;
    logic [DATA_WIDTH-1:0] data_out_d;
    logic                  rd_valid_q;
    logic                  rd_valid_d;

    // =========================================================================
    // COMBINATIONAL LOGIC
    // =========================================================================
    assign wr_ready = 1'b1;

    always_comb begin
        wr_pointer_d  = wr_pointer_q;
        rd_pointer_d  = rd_pointer_q;
        status_cnt_d  = status_cnt_q;
        data_out_d    = data_out_q;
        rd_valid_d    = 1'b0;

        if (wr_en && !full) begin
            wr_pointer_d = wr_pointer_q + 1'b1;
        end

        if (rd_en && !empty) begin
            rd_pointer_d = rd_pointer_q + 1'b1;
            data_out_d   = mem[rd_pointer_q];
            rd_valid_d   = 1'b1;
        end

        unique case ({wr_en && !full, rd_en && !empty})
            2'b10: status_cnt_d = status_cnt_q + 1'b1; // Write only.
            2'b01: status_cnt_d = status_cnt_q - 1'b1; // Read only.
            default: status_cnt_d = status_cnt_q;      // Either both or none.
        endcase
    end

    assign full  = (status_cnt_q == (RAM_DEPTH-1));
    assign empty = (status_cnt_q == 0);

    // =========================================================================
    // INSTANTIATION
    // =========================================================================
    // (none)

    // =========================================================================
    // PROCESSES
    // =========================================================================
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            wr_pointer_q <= '0;
        end else begin
            wr_pointer_q <= wr_pointer_d;
            if (wr_en && !full) begin
                mem[wr_pointer_q] <= data_in;
            end
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            rd_pointer_q <= '0;
            rd_valid_q   <= 1'b0;
            data_out_q   <= '0;
        end else begin
            rd_pointer_q <= rd_pointer_d;
            rd_valid_q   <= rd_valid_d;
            data_out_q   <= data_out_d;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            status_cnt_q <= '0;
        end else begin
            status_cnt_q <= status_cnt_d;
        end
    end

    assign rd_valid = rd_valid_q;
    assign data_out = data_out_q;

endmodule
