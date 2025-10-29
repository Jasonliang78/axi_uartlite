// -----------------------------------------------------------------------------
// Module: uart_rx
// Type  : UART receiver (8N1 framing)
// Purpose: Sample serial data and deliver bytes into the receive FIFO while
//          coordinating flow control with the register interface.
// Structure: PARAMETERS → STATE MACHINE → REGISTERS → COMBINATIONAL LOGIC →
//            INSTANTIATION → PROCESSES
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

// --- Port list ---
// i_Clock    : System clock feeding the UART.
// rst        : Asynchronous active-low reset.
// i_Rx_Serial: Serial input line from the external pin.
// wr_ready   : RX FIFO write-ready indicator.
// full       : RX FIFO full flag to back-pressure the UART.
// o_CTS      : Clear-to-send flag toward the external peer.
// o_RX_Done  : Indicates that a new byte has been sampled.
// o_Rx_Byte  : The received byte aligned to the system clock domain.
// TODO: Provide parity checking hooks for future protocol variants.

module uart_rx #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter int CLKS_PER_BIT = 87
)(
    input  logic       i_Clock,
    input  logic       rst,
    input  logic       i_Rx_Serial,
    input  logic       wr_ready,
    input  logic       full,
    output logic       o_CTS,
    output logic       o_RX_Done,
    output logic [7:0] o_Rx_Byte
);

    localparam int CLOCK_CNT_WIDTH = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    typedef enum logic [2:0] {
        ST_IDLE,       // Monitoring for the start bit.
        ST_START_BIT,  // Validating the start bit midpoint.
        ST_DATA_BITS,  // Sampling eight payload bits.
        ST_STOP_BIT,   // Sampling the stop bit.
        ST_CLEANUP     // Waiting for FIFO availability.
    } state_t;

    state_t state_q;
    state_t state_d;

    // =========================================================================
    // REGISTERS
    // =========================================================================
    logic                 rx_data_meta_q;
    logic                 rx_data_sync_q;
    logic [CLOCK_CNT_WIDTH:0] clock_cnt_q;
    logic [CLOCK_CNT_WIDTH:0] clock_cnt_d;
    logic [2:0]               bit_index_q;
    logic [2:0]               bit_index_d;
    logic [7:0]               rx_byte_q;
    logic [7:0]               rx_byte_d;
    logic                     rx_done_q;
    logic                     rx_done_d;
    logic                     rx_cts_q;
    logic                     rx_cts_d;

    // =========================================================================
    // COMBINATIONAL LOGIC
    // =========================================================================
    always_comb begin
        state_d       = state_q;
        clock_cnt_d   = clock_cnt_q;
        bit_index_d   = bit_index_q;
        rx_byte_d     = rx_byte_q;
        rx_done_d     = rx_done_q;
        rx_cts_d      = rx_cts_q;

        unique case (state_q)
            ST_IDLE: begin
                clock_cnt_d = '0;
                bit_index_d = '0;
                rx_done_d   = 1'b0;
                rx_cts_d    = 1'b0;
                if (rx_data_sync_q == 1'b0) begin
                    state_d = ST_START_BIT;
                end
            end

            ST_START_BIT: begin
                if (clock_cnt_q == (CLKS_PER_BIT-1)/2) begin
                    if (rx_data_sync_q == 1'b0) begin
                        clock_cnt_d = '0;
                        state_d     = ST_DATA_BITS;
                    end else begin
                        state_d = ST_IDLE;
                    end
                end else begin
                    clock_cnt_d = clock_cnt_q + 1'b1;
                end
            end

            ST_DATA_BITS: begin
                if (clock_cnt_q < CLKS_PER_BIT-1) begin
                    clock_cnt_d = clock_cnt_q + 1'b1;
                end else begin
                    clock_cnt_d = '0;
                    rx_byte_d[bit_index_q] = rx_data_sync_q;
                    if (bit_index_q == 3'd7) begin
                        bit_index_d = '0;
                        state_d     = ST_STOP_BIT;
                    end else begin
                        bit_index_d = bit_index_q + 1'b1;
                    end
                end
            end

            ST_STOP_BIT: begin
                if (clock_cnt_q < CLKS_PER_BIT-1) begin
                    clock_cnt_d = clock_cnt_q + 1'b1;
                end else begin
                    clock_cnt_d = '0;
                    rx_done_d   = 1'b1;
                    state_d     = ST_CLEANUP;
                end
            end

            ST_CLEANUP: begin
                if (!full && wr_ready) begin
                    rx_cts_d  = 1'b1;
                    state_d   = ST_IDLE;
                end
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
    always_ff @(posedge i_Clock or negedge rst) begin
        if (!rst) begin
            rx_data_meta_q <= 1'b1;
            rx_data_sync_q <= 1'b1;
        end else begin
            rx_data_meta_q <= i_Rx_Serial;
            rx_data_sync_q <= rx_data_meta_q;
        end
    end

    always_ff @(posedge i_Clock or negedge rst) begin
        if (!rst) begin
            state_q     <= ST_IDLE;
            clock_cnt_q <= '0;
            bit_index_q <= '0;
            rx_byte_q   <= '0;
            rx_done_q   <= 1'b0;
            rx_cts_q    <= 1'b0;
        end else begin
            state_q     <= state_d;
            clock_cnt_q <= clock_cnt_d;
            bit_index_q <= bit_index_d;
            rx_byte_q   <= rx_byte_d;
            rx_done_q   <= rx_done_d;
            rx_cts_q    <= rx_cts_d;
        end
    end

    assign o_CTS     = rx_cts_q;
    assign o_RX_Done = rx_done_q;
    assign o_Rx_Byte = rx_byte_q;

endmodule
