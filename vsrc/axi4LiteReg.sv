// ==============================================================================
// Module      : axi4LiteReg
// Purpose     : Provide a two-register AXI4-Lite accessible bank shared with the
//               UART datapath. Register 0 holds TX data written by the host and
//               register 1 reflects RX data captured from the UART receiver.
// Structure   : Parameters, state machine (not used), registers, combinational
//               logic, instantiation (not used), and processes.
// ==============================================================================

module axi4LiteReg (
    input  logic        clk,
    input  logic        rst,       // Active-low reset propagated from AXI fabric
    input  logic        wr_amba,
    input  logic [31:0] addr_rc,
    input  logic [31:0] addr_wc,
    output logic [31:0] data_out,
    input  logic [3:0]  strb,
    input  logic [31:0] data_in,
    input  logic [31:0] rx_data,
    output logic [31:0] tx_data,
    output logic        rxReady,
    input  logic        rxValid,
    output logic        txValid,
    input  logic        txReady
);

// =========================================================================
// PARAMETERS
// =========================================================================
// -----------------------------------------------------------------------------
    localparam int unsigned TX_REG_INDEX = 0;  // Host writes TX payload here
    localparam int unsigned RX_REG_INDEX = 1;  // UART receiver stores latest byte

// =========================================================================
// STATE MACHINE
// =========================================================================
// -----------------------------------------------------------------------------
// No state machine is required; the module relies on handshake strobes only.

// =========================================================================
// REGISTERS
// =========================================================================
// -----------------------------------------------------------------------------
    logic [31:0] regs [2];  // Dual-entry register bank for TX and RX data

// =========================================================================
// COMBINATIONAL LOGIC
// =========================================================================
// -----------------------------------------------------------------------------
// --- Read datapath ---
    assign data_out = regs[addr_rc[2]];  // Address bit[2] selects TX(0) or RX(1)

// -----------------------------------------------------------------------------
// --- UART handshake ---
    assign rxReady = 1'b1;               // Receiver is always ready to accept data
    assign tx_data = regs[TX_REG_INDEX]; // Latest TX payload is driven to UART TX

// =========================================================================
// INSTANTIATION
// =========================================================================
// -----------------------------------------------------------------------------
// No sub-modules instantiated inside this register bank.

// =========================================================================
// PROCESSES
// =========================================================================
// -----------------------------------------------------------------------------
// --- Register updates ---
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            regs[TX_REG_INDEX] <= '0;
            regs[RX_REG_INDEX] <= '0;
            txValid            <= 1'b0;
        end else begin
            if (wr_amba) begin
                // Byte lanes follow AXI4-Lite strobes so partial writes are preserved.
                regs[addr_wc[2]] <= (strb == 4'b0000)
                    ? regs[addr_wc[2]]
                    : { (strb[3]) ? data_in[31:24] : regs[addr_wc[2]][31:24],
                        (strb[2]) ? data_in[23:16] : regs[addr_wc[2]][23:16],
                        (strb[1]) ? data_in[15: 8] : regs[addr_wc[2]][15: 8],
                        (strb[0]) ? data_in[ 7: 0] : regs[addr_wc[2]][ 7: 0] };

                txValid <= 1'b1;  // Assert when host pushes new TX data
            end

            if (txReady && txValid) begin
                txValid <= 1'b0;  // Clear once the transmitter consumes the word
            end

            if (rxValid) begin
                regs[RX_REG_INDEX] <= rx_data;  // Latch RX data whenever available
            end
        end
    end

endmodule
