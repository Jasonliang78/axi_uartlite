module amba_if (
        axi_slave_if.slave     amba_if,
        output logic           wr_amba,
        input  logic [31:0]    data_in,
        output logic [31:0]    addr_rc,
        output logic [31:0]    addr_wc,
        output logic [31:0]    data_out,
        output logic [3:0]     strb
);

localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

typedef enum logic[1:0] {
        wc_idle,
        wc_wait_addr,
        wc_wait_data,
        wc_exec
} WC_STATE_E;
typedef enum logic[1:0] {
        rc_idle,
        rc_wait_addr,
        rc_exec
} RC_STATE_E;

WC_STATE_E STATE_wc;
RC_STATE_E STATE_rc;

// Rejected by irun 15.20-s013: localparam int unsigned SIZE_WORD = amba.SIZE_WORD;
localparam int unsigned SIZE_WORD = $bits(amba_if.s_axi_wdata);
localparam int unsigned SIZE_STRB = $bits(amba_if.s_axi_wstrb);
localparam int unsigned SIZE_ADDR = $bits(amba_if.s_axi_awaddr);

logic [SIZE_ADDR-1:0]read_AWADDR;
logic [SIZE_WORD-1:0]read_WDATA;
logic [SIZE_STRB-1:0]read_WSTRB;
logic wrote, leu, aux_wc, aux_rc;

logic [2:0]read_ARPROT;
logic [SIZE_ADDR-1:0]read_ARADDR;
logic [SIZE_WORD-1:0]read_RDATA;

/* Logica do write */
always_ff @(posedge amba_if.aclk) begin
        if(~amba_if.aresetn) begin
                STATE_wc        <= wc_idle;
                read_AWADDR <= 0;
                read_WSTRB  <= 0;
                read_WDATA  <= 0;
                wrote           <= 0;
        end
        else begin
                unique case (STATE_wc)
                        wc_idle:
                        begin
                                STATE_wc        <= wc_wait_addr;
                                wrote           <= 0;
                                aux_wc          <= 0;
                        end
                        wc_wait_addr:
                        begin
                                case({amba_if.s_axi_awvalid,amba_if.s_axi_wvalid})
                                        2'b10:
                                        begin
                                                STATE_wc        <= wc_wait_data;
                                                read_AWADDR <= amba_if.s_axi_awaddr;
                                                aux_wc <= 0;
                                        end
                                        2'b11:
                                        begin
                                                STATE_wc        <= wc_exec;
                                                read_AWADDR <= amba_if.s_axi_awaddr;
                                                read_WDATA      <= amba_if.s_axi_wdata;
                                                read_WSTRB      <= amba_if.s_axi_wstrb;
                                                aux_wc <= !full;
                                        end
                                        default: aux_wc <= 0;
                                endcase
                                wrote <= 0;
                        end
                        wc_wait_data:
                        begin
                                if(amba_if.s_axi_wvalid)
                                begin
                                        STATE_wc    <= wc_exec;
                                        read_WDATA      <= amba_if.s_axi_wdata;
                                        read_WSTRB      <= amba_if.s_axi_wstrb;
                                        aux_wc <= !full;
                                end
                                else
                                        aux_wc <= 0;
                                wrote <= 0;
                        end
                        wc_exec:
                        begin
                                if(amba_if.s_axi_bready)
                                        STATE_wc   <= wc_wait_addr;
                                wrote <= 1;
                                aux_wc <= !full;
                        end
                endcase
        end
end // ALWAYS_ff write channel

always_comb  begin
        case (STATE_wc)
                wc_idle:
                begin
                        amba_if.s_axi_awready = 0;
                        amba_if.s_axi_wready  = 0;
                        amba_if.s_axi_bvalid  = 0;
                        amba_if.s_axi_bresp   = AXI_RESP_OKAY;
                        wr_amba           = 0;
                        data_out          = 0;
                        addr_wc           = 0;
                        strb              = 0;
                end
                wc_wait_addr:
                begin
                        data_out          = 0;
                        addr_wc           = 0;
                        strb              = 0;
                        amba_if.s_axi_awready = 1;
                        amba_if.s_axi_wready  = 1;
                        amba_if.s_axi_bvalid  = 0;
                        amba_if.s_axi_bresp   = AXI_RESP_OKAY;
                        wr_amba           = 0;
                end
                wc_wait_data:
                begin
                        data_out          = 0;
                        addr_wc           = 0;
                        strb              = 0;
                        amba_if.s_axi_awready = 0;
                        amba_if.s_axi_wready  = 1;
                        amba_if.s_axi_bvalid  = 0;
                        amba_if.s_axi_bresp   = AXI_RESP_OKAY;
                        wr_amba           = 0;
                end
                wc_exec:
                begin
                        data_out          = read_WDATA;
                        addr_wc           = read_AWADDR;
                        strb              = read_WSTRB;
                        amba_if.s_axi_awready = 0;
                        amba_if.s_axi_wready  = 0;
                        if(aux_wc && read_AWADDR[31:3] == 0 && read_AWADDR[2] == 1'b0)
                        begin
                                amba_if.s_axi_bresp  = AXI_RESP_OKAY;
                                wr_amba = (wrote) ? 0 : 1;
                        end
                        else
                        begin
                                amba_if.s_axi_bresp = AXI_RESP_SLVERR;
                                wr_amba = 0;
                        end
                        amba_if.s_axi_bvalid  = 1;
                end
        endcase
end
/* End lógica do write */

/* Logica do READ */
always_ff @(posedge amba_if.aclk)
begin
        if(~amba_if.aresetn)
        begin
                STATE_rc        <= rc_idle;
                read_ARPROT <= 0;
                read_ARADDR <= 0;
                read_RDATA  <= 0;
        end
        else
        begin
                unique case(STATE_rc)
                        rc_idle:
                        begin
                                STATE_rc    <= rc_wait_addr;
                                aux_rc          <= 0;
                        end
                        rc_wait_addr:begin
                                if(amba_if.s_axi_arvalid)begin
                                        read_ARADDR <= amba_if.s_axi_araddr;
                                        read_ARPROT <= amba_if.s_axi_arprot;
                                        STATE_rc        <= rc_exec;
                                        aux_rc <= !empty;
                                end
                        end
                        rc_exec:
                        begin
                                if(amba_if.s_axi_rready)
                                        STATE_rc <= rc_wait_addr;
                                aux_rc <= !empty;
                        end
                endcase //CASE DO ESTADO
        end //else
end //always_ff read channel

always_comb begin
        unique case (STATE_rc)
                rc_idle:
                begin
                        amba_if.s_axi_arready = 0;
                        amba_if.s_axi_rvalid  = 0;
                        amba_if.s_axi_rresp   = AXI_RESP_OKAY;
                        amba_if.s_axi_rdata   = 0;
                        amba_if.s_axi_rlast   = 0;
                        addr_rc           = 0;
                end
                rc_wait_addr:
                begin
                        addr_rc           = 0;
                        amba_if.s_axi_arready = 1;
                        amba_if.s_axi_rvalid  = 0;
                        amba_if.s_axi_rresp   = AXI_RESP_OKAY;
                        amba_if.s_axi_rdata   = 0;
                        amba_if.s_axi_rlast   = 0;
                end
                rc_exec:
                begin
                        amba_if.s_axi_arready = 0;
                        amba_if.s_axi_rvalid  = 1;
                        amba_if.s_axi_rlast   = 1;
                        addr_rc           = read_ARADDR;

                        if(aux_rc && read_ARADDR[31:3] == 0 && (read_ARADDR[2] == 1'b1))
                        begin
                                amba_if.s_axi_rresp = AXI_RESP_OKAY;
                                amba_if.s_axi_rdata = data_in;
                        end
                        else
                        begin
                                amba_if.s_axi_rresp = AXI_RESP_SLVERR;
                                amba_if.s_axi_rdata = 0;
                        end
                end
        endcase
end
endmodule
