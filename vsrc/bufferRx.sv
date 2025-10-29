// -----------------------------------------------------------------------------
// Module: bufferRx
// Type  : UART receive byte-to-word buffer
// Purpose: Assemble consecutive bytes from the RX FIFO into a 32-bit word before
//          presenting it to the register file interface.
// Structure: PARAMETERS → STATE MACHINE → REGISTERS → COMBINATIONAL LOGIC →
//            INSTANTIATION → PROCESSES
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

// --- Port list ---
// clk       : System clock driving all sequential elements.
// rst       : Asynchronous active-low reset sourced from the AXI domain.
// rxValid   : Word valid flag towards the register file once four bytes arrive.
// empty     : RX FIFO empty flag used to gate reads.
// rxReady   : Register file ready flag acknowledging word capture.
// outReady  : Read enable towards the RX FIFO when the buffer needs data.
// outValid  : RX FIFO byte valid indication used for sequencing.
// data_out  : 32-bit word assembled from four incoming bytes.
// data_in   : Byte-wide data coming from the RX FIFO.
// TODO: Consider exposing the number of collected bytes for debug visibility.

module bufferRx #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter int WORD_WIDTH = 32,
    parameter int BYTE_WIDTH = 8
)(
    input  logic                 clk,
    input  logic                 rst,
    output logic                 rxValid,
    input  logic                 empty,
    input  logic                 rxReady,
    output logic                 outReady,
    input  logic                 outValid,
    output logic [WORD_WIDTH-1:0] data_out,
    input  logic [BYTE_WIDTH-1:0] data_in
);

    localparam int unsigned BYTES_PER_WORD = WORD_WIDTH / BYTE_WIDTH;

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    typedef enum logic [1:0] {
        ST_RESET,     // Ensure deterministic start-up values.
        ST_COLLECT,   // Collect consecutive bytes from the RX FIFO.
        ST_SEND       // Present the assembled word to the register file.
    } state_t;

    state_t state_q;
    state_t state_d;

    // =========================================================================
    // REGISTERS
    // =========================================================================
    logic [$clog2(BYTES_PER_WORD+1)-1:0] byte_count_q;
    logic [$clog2(BYTES_PER_WORD+1)-1:0] byte_count_d;
    logic [WORD_WIDTH-1:0]               assemble_q;
    logic [WORD_WIDTH-1:0]               assemble_d;
    logic [WORD_WIDTH-1:0]               data_out_q;
    logic [WORD_WIDTH-1:0]               data_out_d;
    logic                                rx_valid_q;
    logic                                rx_valid_d;
    logic                                out_ready_q;
    logic                                out_ready_d;

    // =========================================================================
    // COMBINATIONAL LOGIC
    // =========================================================================
    always_comb begin
        state_d      = state_q;
        byte_count_d = byte_count_q;
        assemble_d   = assemble_q;
        data_out_d   = data_out_q;
        rx_valid_d   = 1'b0;          // Default to deassert between handshakes.
        out_ready_d  = out_ready_q;

        unique case (state_q)
            ST_RESET: begin
                out_ready_d  = 1'b1;  // Immediately request the first byte.
                byte_count_d = '0;
                assemble_d   = '0;
                state_d      = ST_COLLECT;
            end

            ST_COLLECT: begin
                out_ready_d = 1'b1;
                if (!empty && outValid) begin
                    assemble_d[BYTE_WIDTH*byte_count_q +: BYTE_WIDTH] = data_in;
                    if (byte_count_q == BYTES_PER_WORD-1) begin
                        byte_count_d = '0;
                        out_ready_d  = 1'b0;  // Hold FIFO read until word consumed.
                        state_d      = ST_SEND;
                    end else begin
                        byte_count_d = byte_count_q + 1'b1;
                    end
                end
            end

            ST_SEND: begin
                out_ready_d = 1'b0;
                if (rxReady) begin
                    data_out_d  = assemble_q;
                    rx_valid_d  = 1'b1;  // Pulse valid once the consumer accepts.
                    assemble_d  = '0;
                    state_d     = ST_COLLECT;
                end
            end

            default: begin
                state_d = ST_RESET;
            end
        endcase
    end

    // =========================================================================
    // INSTANTIATION
    // =========================================================================
    // (none)

    // =========================================================================
    // PROCESSES
    // =========================================================================
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            state_q     <= ST_RESET;
            byte_count_q <= '0;
            assemble_q  <= '0;
            data_out_q  <= '0;
            rx_valid_q  <= 1'b0;
            out_ready_q <= 1'b0;
        end else begin
            state_q     <= state_d;
            byte_count_q <= byte_count_d;
            assemble_q  <= assemble_d;
            data_out_q  <= data_out_d;
            rx_valid_q  <= rx_valid_d;
            out_ready_q <= out_ready_d;
        end
    end

    assign rxValid  = rx_valid_q;
    assign outReady = out_ready_q;
    assign data_out = data_out_q;

endmodule
