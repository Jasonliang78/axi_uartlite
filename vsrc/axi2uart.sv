// -----------------------------------------------------------------------------
// Module: axi2uart
// Type  : AXI4 to UART bridge top level
// Purpose: Tie the AXI register bank, UART datapath, and FIFOs into a cohesive
//          peripheral.
// Structure: PARAMETERS → STATE MACHINE → REGISTERS → COMBINATIONAL LOGIC →
//            INSTANTIATION → PROCESSES
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

// --- Port list ---
// amba_intf : AXI4-Lite hierarchical interface bundle.
// i_RTS     : Host-driven read strobe for the TX FIFO (Request To Send).
// i_Rx_Serial: Incoming UART RX serial line.
// o_CTS     : Clear To Send back to the host once RX data is ready.
// o_TX_Serial: UART TX serial output.
// o_TX_Done : Pulse when a byte finishes transmission.
// TODO: Add optional interrupt outputs for TX empty and RX full conditions.

module axi2uart #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter int CLKS_PER_BIT = 217
)(
    axi_slave_if.slave amba_intf,
    input  logic           i_RTS,
    input  logic           i_Rx_Serial,
    output logic           o_CTS,
    output logic           o_TX_Serial,
    output logic           o_TX_Done
);

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    // No local FSM is required; behaviour is entirely structural.

    // =========================================================================
    // REGISTERS (internal signals)
    // =========================================================================
    logic        wr_amba;
    logic [31:0] addr_rc;
    logic [31:0] addr_wc;
    logic [3:0]  strb;
    logic [31:0] if2reg;
    logic [31:0] reg2if;

    logic [31:0] rx_data;
    logic [31:0] tx_data;
    logic        rxReady;
    logic        rxValid;
    logic        txValid;
    logic        txReady;

    logic        fullTx;
    logic        emptyTx;
    logic        fullRx;
    logic        emptyRx;

    logic [7:0]  tx_fifo_din;
    logic [7:0]  tx_fifo_dout;
    logic        tx_fifo_wr_en;
    logic        tx_fifo_wr_ready;
    logic        tx_fifo_rd_valid;

    logic [7:0]  rx_fifo_din;
    logic [7:0]  rx_fifo_dout;
    logic        rx_fifo_wr_ready;
    logic        rx_fifo_rd_valid;
    logic        rx_fifo_rd_en;
    logic        rx_done;

    // =========================================================================
    // COMBINATIONAL LOGIC
    // =========================================================================
    // Direct signal wiring only; no additional combinational behaviour.

    // =========================================================================
    // INSTANTIATION
    // =========================================================================
    amba_if u_amba_if (
        .amba_if (amba_intf),
        .wr_amba (wr_amba),
        .data_in (reg2if),
        .addr_rc (addr_rc),
        .addr_wc (addr_wc),
        .data_out(if2reg),
        .strb    (strb)
    );

    axi4LiteReg u_regfile (
        .clk      (amba_intf.aclk),
        .rst      (amba_intf.aresetn),
        .wr_amba  (wr_amba),
        .addr_rc  (addr_rc),
        .addr_wc  (addr_wc),
        .data_out (reg2if),
        .strb     (strb),
        .data_in  (if2reg),
        .rx_data  (rx_data),
        .tx_data  (tx_data),
        .rxReady  (rxReady),
        .rxValid  (rxValid),
        .txValid  (txValid),
        .txReady  (txReady)
    );

    bufferTx u_buffer_tx (
        .clk      (amba_intf.aclk),
        .rst      (amba_intf.aresetn),
        .txValid  (txValid),
        .full     (fullTx),
        .outReady (tx_fifo_wr_ready),
        .txReady  (txReady),
        .outValid (tx_fifo_wr_en),
        .data_in  (tx_data),
        .data_out (tx_fifo_din)
    );

    syn_fifo u_tx_fifo (
        .clk      (amba_intf.aclk),
        .rst      (amba_intf.aresetn),
        .data_in  (tx_fifo_din),
        .rd_en    (i_RTS),
        .rd_valid (tx_fifo_rd_valid),
        .wr_en    (tx_fifo_wr_en),
        .wr_ready (tx_fifo_wr_ready),
        .data_out (tx_fifo_dout),
        .empty    (emptyTx),
        .full     (fullTx)
    );

    uart_tx #(
        .CLKS_PER_BIT (CLKS_PER_BIT)
    ) u_uart_tx (
        .i_Clock   (amba_intf.aclk),
        .rst       (amba_intf.aresetn),
        .i_RTS     (i_RTS),
        .empty     (emptyTx),
        .rd_valid  (tx_fifo_rd_valid),
        .i_TX_Byte (tx_fifo_dout),
        .o_TX_Active(),
        .o_TX_Serial(o_TX_Serial),
        .o_TX_Done (o_TX_Done)
    );

    uart_rx #(
        .CLKS_PER_BIT (CLKS_PER_BIT)
    ) u_uart_rx (
        .i_Clock    (amba_intf.aclk),
        .rst        (amba_intf.aresetn),
        .i_Rx_Serial(i_Rx_Serial),
        .wr_ready   (rx_fifo_wr_ready),
        .full       (fullRx),
        .o_CTS      (o_CTS),
        .o_RX_Done  (rx_done),
        .o_Rx_Byte  (rx_fifo_din)
    );

    syn_fifo u_rx_fifo (
        .clk      (amba_intf.aclk),
        .rst      (amba_intf.aresetn),
        .data_in  (rx_fifo_din),
        .rd_en    (rx_fifo_rd_en),
        .rd_valid (rx_fifo_rd_valid),
        .wr_en    (rx_done),
        .wr_ready (rx_fifo_wr_ready),
        .data_out (rx_fifo_dout),
        .empty    (emptyRx),
        .full     (fullRx)
    );

    bufferRx u_buffer_rx (
        .clk      (amba_intf.aclk),
        .rst      (amba_intf.aresetn),
        .rxValid  (rxValid),
        .empty    (emptyRx),
        .rxReady  (rxReady),
        .outReady (rx_fifo_rd_en),
        .outValid (rx_fifo_rd_valid),
        .data_out (rx_data),
        .data_in  (rx_fifo_dout)
    );

    // =========================================================================
    // PROCESSES
    // =========================================================================
    // No clocked logic beyond instantiated submodules.

endmodule
