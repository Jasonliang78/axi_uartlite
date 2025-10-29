// -----------------------------------------------------------------------------
// Module: axi_master_driver
// Type  : Teaching-oriented AXI4 Master driver (single outstanding transaction)
// Purpose: Demonstrates full AXI4 handshakes with structured FSM control.
//
// Code structure follows: 
// PARAMETERS â†? STATE MACHINE â†? REGISTERS â†? COMBINATIONAL LOGIC â†? INSTANTIATION â†? PROCESSES
// -----------------------------------------------------------------------------
module axi_master_driver #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter ADDR_WIDTH      = 32,        // AXI address width (bits)
    parameter DATA_WIDTH      = 32,        // AXI data width (bits)
    parameter BURST_LEN_WIDTH = 8,         // Width of burst length (AWLEN/ARLEN)
    parameter MAX_BURST_LEN   = 16,        // Max burst length supported
    parameter ID_WIDTH        = 1,         // Placeholder (unused)
    parameter REGION_WIDTH    = 4          // Placeholder (unused)
)(
    // =========================================================================
    // INTERFACES
    // =========================================================================
    axi_master_if.master axi_bus,          // AXI master interface bundle

    // User-side control
    input  logic                            start_i,          
    input  logic                            wr_rd_i,          
    input  logic [DATA_WIDTH/8-1:0]         wr_wstrb_i,       
    input  logic [ADDR_WIDTH-1:0]           addr_i,           
    input  logic [BURST_LEN_WIDTH-1:0]      len_i,            
    input  logic [2:0]                      size_i,           
    input  logic [1:0]                      burst_i,          
    input  logic [DATA_WIDTH-1:0]           data_i,           
    input  logic [DATA_WIDTH-1:0]           data_array_i [MAX_BURST_LEN], 
    input  logic                            use_array_i,      

    // Status outputs
    output logic                            done_o,           
    output logic [DATA_WIDTH-1:0]           data_o,           
    output logic                            data_valid_o,     
    output logic [1:0]                      resp_o,           
    output logic                            error_o,          
    output logic                            busy_o            
);

    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    typedef enum logic [2:0] {
        ST_IDLE       = 3'b000,  // Idle state
        ST_WR_ADDR    = 3'b001,  // Write address phase
        ST_WR_DATA    = 3'b010,  // Write data phase
        ST_WR_RESP    = 3'b011,  // Write response phase
        ST_RD_ADDR    = 3'b100,  // Read address phase
        ST_RD_DATA    = 3'b101   // Read data phase
    } state_t;

    state_t current_state;
    state_t next_state;

    // =========================================================================
    // REGISTERS (includes all internal signals)
    // =========================================================================
    logic [ADDR_WIDTH-1:0]      current_addr;       
    logic [BURST_LEN_WIDTH-1:0] beat_counter;       
    logic [BURST_LEN_WIDTH-1:0] total_beats;        
    logic                       is_write;           
    logic [DATA_WIDTH-1:0]      data_buffer [MAX_BURST_LEN]; 
    logic [DATA_WIDTH-1:0]      singledata_buffer;  
    logic [DATA_WIDTH/8-1:0]    wstrb_buffer;       
    logic                       use_array_buf;      
    logic [7:0]                 size_power;      
    logic [2:0] size_reg;   // latched AxSIZE for the whole transaction
    logic [1:0] burst_reg;  // latched AxBURST for the whole transaction   

    assign size_power = 8'b1 << size_reg;

    // =========================================================================
    // COMBINATIONAL LOGIC
    // - FSM next state
    // - AXI channel drive (AW/W/B/AR/R)
    // =========================================================================
    always_comb begin
        next_state = current_state;
        case (current_state)
            ST_IDLE: if (start_i && !busy_o) next_state = wr_rd_i ? ST_WR_ADDR : ST_RD_ADDR;
            ST_WR_ADDR: if (axi_bus.m_axi_awvalid && axi_bus.m_axi_awready) next_state = ST_WR_DATA;
            ST_WR_DATA: if (axi_bus.m_axi_wvalid && axi_bus.m_axi_wready && axi_bus.m_axi_wlast) next_state = ST_WR_RESP;
            ST_WR_RESP: if (axi_bus.m_axi_bvalid && axi_bus.m_axi_bready) next_state = ST_IDLE;
            ST_RD_ADDR: if (axi_bus.m_axi_arvalid && axi_bus.m_axi_arready) next_state = ST_RD_DATA;
            ST_RD_DATA: if (axi_bus.m_axi_rvalid && axi_bus.m_axi_rready && axi_bus.m_axi_rlast) next_state = ST_IDLE;
            default: next_state = ST_IDLE;
        endcase
    end

    // ------------------- AXI Write Address Channel -------------------
    always_comb begin
        axi_bus.m_axi_awvalid = 1'b0;
        axi_bus.m_axi_awaddr  = '0;
        axi_bus.m_axi_awlen   = '0;
        axi_bus.m_axi_awsize  = '0;
        axi_bus.m_axi_awburst = '0;
        axi_bus.m_axi_awlock  = 1'b0;
        axi_bus.m_axi_awcache = 4'b0011;
        axi_bus.m_axi_awprot  = 3'b010;
        axi_bus.m_axi_awqos   = 4'b0000;

        if (current_state == ST_WR_ADDR) begin
            axi_bus.m_axi_awvalid = 1'b1;
            axi_bus.m_axi_awaddr  = current_addr;
            axi_bus.m_axi_awlen   = total_beats;
            axi_bus.m_axi_awsize  = size_reg;
            axi_bus.m_axi_awburst = burst_reg;
        end
    end

    // ------------------- AXI Write Data Channel -------------------
    always_comb begin
        axi_bus.m_axi_wvalid = 1'b0;
        axi_bus.m_axi_wdata  = '0;
        axi_bus.m_axi_wlast  = 1'b0;
        axi_bus.m_axi_wstrb  = '0;

        if (current_state == ST_WR_DATA) begin
            axi_bus.m_axi_wvalid = 1'b1;
            axi_bus.m_axi_wdata  = use_array_buf ? data_buffer[beat_counter] : singledata_buffer;
            axi_bus.m_axi_wlast  = (beat_counter == total_beats);
            axi_bus.m_axi_wstrb  = wstrb_buffer;
        end
    end

    // ------------------- AXI Write Response Channel -------------------
    always_comb begin
        axi_bus.m_axi_bready = (current_state == ST_WR_RESP);
    end

    // ------------------- AXI Read Address Channel -------------------
    always_comb begin
        axi_bus.m_axi_arvalid = 1'b0;
        axi_bus.m_axi_araddr  = '0;
        axi_bus.m_axi_arlen   = '0;
        axi_bus.m_axi_arsize  = '0;
        axi_bus.m_axi_arburst = '0;
        axi_bus.m_axi_arlock  = 1'b0;
        axi_bus.m_axi_arcache = 4'b0011;
        axi_bus.m_axi_arprot  = 3'b010;
        axi_bus.m_axi_arqos   = 4'b0000;

        if (current_state == ST_RD_ADDR) begin
            axi_bus.m_axi_arvalid = 1'b1;
            axi_bus.m_axi_araddr  = current_addr;
            axi_bus.m_axi_arlen   = total_beats;
            axi_bus.m_axi_arsize  = size_reg;
            axi_bus.m_axi_arburst = burst_reg;
        end
    end

    // ------------------- AXI Read Data Channel -------------------
    always_comb begin
        axi_bus.m_axi_rready = (current_state == ST_RD_DATA);
    end

    // =========================================================================
    // INSTANTIATION (none in this module)
    // =========================================================================
    // (No submodules are instantiated â€? this driver is self-contained.)

    // =========================================================================
    // PROCESSES (sequential always_ff blocks)
    // =========================================================================

    // --- FSM state register ---
    always_ff @(posedge axi_bus.aclk or negedge axi_bus.aresetn)
        if (!axi_bus.aresetn) current_state <= ST_IDLE;
        else current_state <= next_state;

    // --- Transaction control / counters ---
    always_ff @(posedge axi_bus.aclk or negedge axi_bus.aresetn) begin
        if (!axi_bus.aresetn) begin
            current_addr  <= '0;
            beat_counter  <= '0;
            total_beats   <= '0;
            is_write      <= 1'b0;
            busy_o        <= 1'b0;
            singledata_buffer <= '0;
            wstrb_buffer  <= '0;
            use_array_buf <= 1'b0;
            size_reg      <= '0;
            burst_reg     <= '0;

            for (int i = 0; i < MAX_BURST_LEN; i++) data_buffer[i] <= '0;
        end else begin
            case (current_state)
                ST_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i && !busy_o) begin
                        current_addr <= addr_i;
                        total_beats  <= len_i;
                        beat_counter <= '0;
                        is_write     <= wr_rd_i;
                        busy_o       <= 1'b1;
                        size_reg     <= size_i;
                        burst_reg    <= burst_i;
                        if (wr_rd_i && use_array_i) begin
                            for (int i = 0; i < MAX_BURST_LEN; i++) 
                                data_buffer[i] <= data_array_i[i];
                            use_array_buf <= 1'b1;
                        end else if (wr_rd_i && ~use_array_i) begin
                            singledata_buffer <= data_i;
                            use_array_buf <= 1'b0;
                        end
                        wstrb_buffer <= wr_wstrb_i;
                    end
                end
                ST_WR_DATA: begin
                    if (axi_bus.m_axi_wvalid && axi_bus.m_axi_wready) begin
                        if (beat_counter == total_beats)
                            beat_counter <= '0;
                        else begin
                            beat_counter <= beat_counter + 1'b1;
                            case (burst_reg)
                                2'b00: ;
                                default: current_addr <= current_addr + size_power;
                            endcase
                        end
                    end
                end
                ST_RD_DATA: begin
                    if (axi_bus.m_axi_rvalid && axi_bus.m_axi_rready)
                        beat_counter <= axi_bus.m_axi_rlast ? '0 : beat_counter + 1'b1;
                end
            endcase
        end
    end

    // --- Read data capture ---
    always_ff @(posedge axi_bus.aclk or negedge axi_bus.aresetn)
        if (!axi_bus.aresetn) begin
            data_o <= '0;
            data_valid_o <= 1'b0;
        end else begin
            data_valid_o <= 1'b0;
            if (axi_bus.m_axi_rvalid && axi_bus.m_axi_rready) begin
                data_o <= axi_bus.m_axi_rdata;
                data_valid_o <= 1'b1;
            end
        end

    // --- Completion, response, and error flags ---
    always_ff @(posedge axi_bus.aclk or negedge axi_bus.aresetn)
        if (!axi_bus.aresetn) begin
            done_o  <= 1'b0;
            resp_o  <= 2'b00;
            error_o <= 1'b0;
        end else begin
            done_o <= 1'b0;
            case (current_state)
                ST_WR_RESP: 
                    if (axi_bus.m_axi_bvalid && axi_bus.m_axi_bready) begin
                        done_o  <= 1'b1;
                        resp_o  <= axi_bus.m_axi_bresp;
                        error_o <= (axi_bus.m_axi_bresp != 2'b00);
                    end
                ST_RD_DATA:
                    if (axi_bus.m_axi_rvalid && axi_bus.m_axi_rready && axi_bus.m_axi_rlast) begin
                        done_o  <= 1'b1;
                        resp_o  <= axi_bus.m_axi_rresp;
                        error_o <= (axi_bus.m_axi_rresp != 2'b00);
                    end
            endcase
        end

endmodule
