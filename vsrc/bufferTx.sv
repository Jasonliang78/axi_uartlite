// -----------------------------------------------------------------------------
// Module: bufferTx
// Type  : UART transmit word-to-byte buffer
// Purpose: Break 32-bit register data into sequential bytes destined for the
//          transmit FIFO.
// Structure: PARAMETERS → STATE MACHINE → REGISTERS → COMBINATIONAL LOGIC →
//            INSTANTIATION → PROCESSES
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

// --- Port list ---
// clk       : System clock feeding the buffer.
// rst       : Asynchronous active-low reset shared with the AXI domain.
// txValid   : Register file request to push a 32-bit word toward the UART.
// full      : TX FIFO full indication preventing byte pushes.
// outReady  : TX FIFO write-ready handshake.
// txReady   : Back-pressure indicator to the register file.
// outValid  : Byte valid flag asserted while a byte is presented.
// data_in   : 32-bit word from the register file.
// data_out  : Byte presented to the TX FIFO.
// TODO: Allow configuration of byte ordering for endianness experiments.

module bufferTx #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter int WORD_WIDTH = 32,
    parameter int BYTE_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic                  txValid,
    input  logic                  full,
    input  logic                  outReady,
    output logic                  txReady,
    output logic                  outValid,
    input  logic [WORD_WIDTH-1:0] data_in,
    output logic [BYTE_WIDTH-1:0] data_out
);

    localparam int unsigned BYTES_PER_WORD = WORD_WIDTH / BYTE_WIDTH;

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    typedef enum logic [1:0] {
        ST_IDLE,     // Wait for a new word from the register file.
        ST_SEND,     // Stream bytes toward the TX FIFO.
        ST_CLEANUP   // Release the handshake once all bytes were sent.
    } state_t;

    state_t state_q;
    state_t state_d;

    // =========================================================================
    // REGISTERS
    // =========================================================================
    logic [WORD_WIDTH-1:0]               word_q;
    logic [WORD_WIDTH-1:0]               word_d;
    logic [$clog2(BYTES_PER_WORD)-1:0]   byte_index_q;
    logic [$clog2(BYTES_PER_WORD)-1:0]   byte_index_d;
    logic                                tx_ready_q;
    logic                                tx_ready_d;
    logic                                out_valid_q;
    logic                                out_valid_d;
    logic [BYTE_WIDTH-1:0]               data_out_q;
    logic [BYTE_WIDTH-1:0]               data_out_d;

    // =========================================================================
    // COMBINATIONAL LOGIC
    // =========================================================================
    always_comb begin
        state_d       = state_q;
        word_d        = word_q;
        byte_index_d  = byte_index_q;
        tx_ready_d    = tx_ready_q;
        out_valid_d   = out_valid_q;
        data_out_d    = data_out_q;

        unique case (state_q)
            ST_IDLE: begin
                tx_ready_d  = 1'b1;
                out_valid_d = 1'b0;
                byte_index_d = '0;
                if (txValid) begin
                    word_d      = data_in;
                    tx_ready_d  = 1'b0;
                    state_d     = ST_SEND;
                end
            end

            ST_SEND: begin
                tx_ready_d = 1'b0;
                if (!full && outReady) begin
                    data_out_d  = word_q[BYTE_WIDTH*byte_index_q +: BYTE_WIDTH];
                    out_valid_d = 1'b1;
                    if (byte_index_q == BYTES_PER_WORD-1) begin
                        state_d = ST_CLEANUP;
                    end else begin
                        byte_index_d = byte_index_q + 1'b1;
                    end
                end
            end

            ST_CLEANUP: begin
                out_valid_d = 1'b0;
                tx_ready_d  = 1'b1;
                state_d     = ST_IDLE;
            end

            default: begin
                state_d = ST_IDLE;
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
            state_q      <= ST_IDLE;
            word_q       <= '0;
            byte_index_q <= '0;
            tx_ready_q   <= 1'b1;
            out_valid_q  <= 1'b0;
            data_out_q   <= '0;
        end else begin
            state_q      <= state_d;
            word_q       <= word_d;
            byte_index_q <= byte_index_d;
            tx_ready_q   <= tx_ready_d;
            out_valid_q  <= out_valid_d;
            data_out_q   <= data_out_d;
        end
    end

    assign txReady = tx_ready_q;
    assign outValid = out_valid_q;
    assign data_out = data_out_q;

endmodule
