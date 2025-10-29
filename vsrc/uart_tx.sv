// -----------------------------------------------------------------------------
// Module: uart_tx
// Type  : UART transmitter (8N1 framing)
// Purpose: Serialize bytes supplied by the transmit FIFO using a configurable
//          baud divider.
// Structure: PARAMETERS → STATE MACHINE → REGISTERS → COMBINATIONAL LOGIC →
//            INSTANTIATION → PROCESSES
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

// --- Port list ---
// i_Clock    : System clock driving the UART.
// rst        : Asynchronous active-low reset.
// i_RTS      : Request-to-send indication from the host logic.
// empty      : TX FIFO empty flag used to guard transmissions.
// rd_valid   : Byte-valid flag from the TX FIFO.
// i_TX_Byte  : Byte fetched from the TX FIFO for transmission.
// o_TX_Active: High while serialization is in progress.
// o_TX_Serial: Serial output line toward the external pin.
// o_TX_Done  : Pulse indicating frame completion.
// TODO: Support configurable stop-bit counts in addition to the single stop bit.

module uart_tx #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter int CLKS_PER_BIT = 217
)(
    input  logic       i_Clock,
    input  logic       rst,
    input  logic       i_RTS,
    input  logic       empty,
    input  logic       rd_valid,
    input  logic [7:0] i_TX_Byte,
    output logic       o_TX_Active,
    output logic       o_TX_Serial,
    output logic       o_TX_Done
);

    localparam int CLOCK_CNT_WIDTH = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    typedef enum logic [2:0] {
        ST_IDLE,       // Waiting for a byte request.
        ST_START_BIT,  // Driving the start bit (logic 0).
        ST_DATA_BITS,  // Sending eight payload bits.
        ST_STOP_BIT,   // Driving the stop bit (logic 1).
        ST_CLEANUP     // One-cycle cleanup stage.
    } state_t;

    state_t state_q;
    state_t state_d;

    // =========================================================================
    // REGISTERS
    // =========================================================================
    logic [CLOCK_CNT_WIDTH:0] clock_cnt_q;
    logic [CLOCK_CNT_WIDTH:0] clock_cnt_d;
    logic [2:0]               bit_index_q;
    logic [2:0]               bit_index_d;
    logic [7:0]               tx_data_q;
    logic [7:0]               tx_data_d;
    logic                     tx_done_q;
    logic                     tx_done_d;
    logic                     tx_active_q;
    logic                     tx_active_d;
    logic                     tx_serial_q;
    logic                     tx_serial_d;

    // =========================================================================
    // COMBINATIONAL LOGIC
    // =========================================================================
    always_comb begin
        state_d      = state_q;
        clock_cnt_d  = clock_cnt_q;
        bit_index_d  = bit_index_q;
        tx_data_d    = tx_data_q;
        tx_done_d    = tx_done_q;
        tx_active_d  = tx_active_q;
        tx_serial_d  = tx_serial_q;

        unique case (state_q)
            ST_IDLE: begin
                tx_serial_d = 1'b1;
                tx_done_d   = 1'b0;
                clock_cnt_d = '0;
                bit_index_d = '0;
                tx_active_d = 1'b0;
                if (!empty && i_RTS && rd_valid) begin
                    tx_data_d   = i_TX_Byte;
                    tx_active_d = 1'b1;
                    state_d     = ST_START_BIT;
                end
            end

            ST_START_BIT: begin
                tx_serial_d = 1'b0;
                tx_done_d   = 1'b0;
                if (clock_cnt_q < CLKS_PER_BIT-1) begin
                    clock_cnt_d = clock_cnt_q + 1'b1;
                end else begin
                    clock_cnt_d = '0;
                    state_d     = ST_DATA_BITS;
                end
            end

            ST_DATA_BITS: begin
                tx_serial_d = tx_data_q[bit_index_q];
                if (clock_cnt_q < CLKS_PER_BIT-1) begin
                    clock_cnt_d = clock_cnt_q + 1'b1;
                end else begin
                    clock_cnt_d = '0;
                    if (bit_index_q == 3'd7) begin
                        bit_index_d = '0;
                        state_d     = ST_STOP_BIT;
                    end else begin
                        bit_index_d = bit_index_q + 1'b1;
                    end
                end
            end

            ST_STOP_BIT: begin
                tx_serial_d = 1'b1;
                if (clock_cnt_q < CLKS_PER_BIT-1) begin
                    clock_cnt_d = clock_cnt_q + 1'b1;
                end else begin
                    clock_cnt_d = '0;
                    tx_done_d   = 1'b1;
                    tx_active_d = 1'b0;
                    state_d     = ST_CLEANUP;
                end
            end

            ST_CLEANUP: begin
                tx_serial_d = 1'b1;
                tx_done_d   = 1'b1;
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
    always_ff @(posedge i_Clock or negedge rst) begin
        if (!rst) begin
            state_q      <= ST_IDLE;
            clock_cnt_q  <= '0;
            bit_index_q  <= '0;
            tx_data_q    <= '0;
            tx_done_q    <= 1'b0;
            tx_active_q  <= 1'b0;
            tx_serial_q  <= 1'b1;
        end else begin
            state_q      <= state_d;
            clock_cnt_q  <= clock_cnt_d;
            bit_index_q  <= bit_index_d;
            tx_data_q    <= tx_data_d;
            tx_done_q    <= tx_done_d;
            tx_active_q  <= tx_active_d;
            tx_serial_q  <= tx_serial_d;
        end
    end

    assign o_TX_Active = tx_active_q;
    assign o_TX_Serial = tx_serial_q;
    assign o_TX_Done   = tx_done_q;

endmodule
