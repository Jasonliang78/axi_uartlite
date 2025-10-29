// -----------------------------------------------------------------------------
// Interface: axi_master_if
// Type     : AXI4 Master-side interface bundle
// Purpose  : Group all AXI channels and expose a master modport.
// Structure: PARAMETERS → CLK/RESET PORTS → SIGNALS (by channel) → MODPORTS
// -----------------------------------------------------------------------------
interface axi_master_if #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter ID_WIDTH     = 1,   // Placeholder (no explicit ID signals here)
    parameter REGION_WIDTH = 4
)(
    // =========================================================================
    // CLK/RESET PORTS
    // =========================================================================
    input logic aclk,
    input logic aresetn
);

    // =========================================================================
    // SIGNALS (grouped by AXI channels)
    // =========================================================================

    // ---------------------------
    // Read Address Channel (AR)
    // ---------------------------
    logic [ADDR_WIDTH-1:0]    m_axi_araddr;
    logic [1:0]               m_axi_arburst;
    logic [3:0]               m_axi_arcache;
    logic [7:0]               m_axi_arlen;
    logic [0:0]               m_axi_arlock;
    logic [2:0]               m_axi_arprot;
    logic [3:0]               m_axi_arqos;
    logic                     m_axi_arready;
    logic [REGION_WIDTH-1:0]  m_axi_arregion;
    logic [2:0]               m_axi_arsize;
    logic                     m_axi_arvalid;

    // ---------------------------
    // Write Address Channel (AW)
    // ---------------------------
    logic [ADDR_WIDTH-1:0]    m_axi_awaddr;
    logic [1:0]               m_axi_awburst;
    logic [3:0]               m_axi_awcache;
    logic [7:0]               m_axi_awlen;
    logic [0:0]               m_axi_awlock;
    logic [2:0]               m_axi_awprot;
    logic [3:0]               m_axi_awqos;
    logic                     m_axi_awready;
    logic [REGION_WIDTH-1:0]  m_axi_awregion;
    logic [2:0]               m_axi_awsize;
    logic                     m_axi_awvalid;

    // ---------------------------
    // Write Response Channel (B)
    // ---------------------------
    logic                     m_axi_bready;
    logic [1:0]               m_axi_bresp;
    logic                     m_axi_bvalid;

    // ---------------------------
    // Read Data Channel (R)
    // ---------------------------
    logic [DATA_WIDTH-1:0]    m_axi_rdata;
    logic                     m_axi_rlast;
    logic                     m_axi_rready;
    logic [1:0]               m_axi_rresp;
    logic                     m_axi_rvalid;

    // ---------------------------
    // Write Data Channel (W)
    // ---------------------------
    logic [DATA_WIDTH-1:0]      m_axi_wdata;
    logic                       m_axi_wlast;
    logic                       m_axi_wready;
    logic [(DATA_WIDTH/8)-1:0]  m_axi_wstrb; // Required byte enables
    logic                       m_axi_wvalid;

    // =========================================================================
    // MODPORTS
    // =========================================================================
    // Master view: drive address/data, accept READY/RESP from slave
    modport master (
        // Global
        input  aclk,
        input  aresetn,

        // Read Address (AR)
        output m_axi_araddr,
        output m_axi_arburst,
        output m_axi_arcache,
        output m_axi_arlen,
        output m_axi_arlock,
        output m_axi_arprot,
        output m_axi_arqos,
        input  m_axi_arready,
        output m_axi_arregion,
        output m_axi_arsize,
        output m_axi_arvalid,

        // Write Address (AW)
        output m_axi_awaddr,
        output m_axi_awburst,
        output m_axi_awcache,
        output m_axi_awlen,
        output m_axi_awlock,
        output m_axi_awprot,
        output m_axi_awqos,
        input  m_axi_awready,
        output m_axi_awregion,
        output m_axi_awsize,
        output m_axi_awvalid,

        // Write Response (B)
        output m_axi_bready,
        input  m_axi_bresp,
        input  m_axi_bvalid,

        // Read Data (R)
        input  m_axi_rdata,
        input  m_axi_rlast,
        output m_axi_rready,
        input  m_axi_rresp,
        input  m_axi_rvalid,

        // Write Data (W)
        output m_axi_wdata,
        output m_axi_wlast,
        input  m_axi_wready,
        output m_axi_wstrb,
        output m_axi_wvalid
    );

endinterface


// -----------------------------------------------------------------------------
// Interface: axi_slave_if
// Type     : AXI4 Slave-side interface bundle
// Purpose  : Group all AXI channels and expose a slave modport.
// Structure: PARAMETERS → CLK/RESET PORTS → SIGNALS (by channel) → MODPORTS
// -----------------------------------------------------------------------------
interface axi_slave_if #(
    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter ID_WIDTH     = 1,
    parameter REGION_WIDTH = 4
)(
    // =========================================================================
    // CLK/RESET PORTS
    // =========================================================================
    input logic aclk,
    input logic aresetn
);

    // =========================================================================
    // SIGNALS (grouped by AXI channels)
    // =========================================================================

    // ---------------------------
    // Read Address Channel (AR)
    // ---------------------------
    logic [ADDR_WIDTH-1:0]    s_axi_araddr;
    logic [1:0]               s_axi_arburst;
    logic [3:0]               s_axi_arcache;
    logic [7:0]               s_axi_arlen;
    logic [0:0]               s_axi_arlock;
    logic [2:0]               s_axi_arprot;
    logic [3:0]               s_axi_arqos;
    logic                     s_axi_arready;
    logic [REGION_WIDTH-1:0]  s_axi_arregion;
    logic [2:0]               s_axi_arsize;
    logic                     s_axi_arvalid;

    // ---------------------------
    // Write Address Channel (AW)
    // ---------------------------
    logic [ADDR_WIDTH-1:0]    s_axi_awaddr;
    logic [1:0]               s_axi_awburst;
    logic [3:0]               s_axi_awcache;
    logic [7:0]               s_axi_awlen;
    logic [0:0]               s_axi_awlock;
    logic [2:0]               s_axi_awprot;
    logic [3:0]               s_axi_awqos;
    logic                     s_axi_awready;
    logic [REGION_WIDTH-1:0]  s_axi_awregion;
    logic [2:0]               s_axi_awsize;
    logic                     s_axi_awvalid;

    // ---------------------------
    // Write Response Channel (B)
    // ---------------------------
    logic                     s_axi_bready;
    logic [1:0]               s_axi_bresp;
    logic                     s_axi_bvalid;

    // ---------------------------
    // Read Data Channel (R)
    // ---------------------------
    logic [DATA_WIDTH-1:0]    s_axi_rdata;
    logic                     s_axi_rlast;
    logic                     s_axi_rready;
    logic [1:0]               s_axi_rresp;
    logic                     s_axi_rvalid;

    // ---------------------------
    // Write Data Channel (W)
    // ---------------------------
    logic [DATA_WIDTH-1:0]      s_axi_wdata;
    logic                       s_axi_wlast;
    logic                       s_axi_wready;
    logic [(DATA_WIDTH/8)-1:0]  s_axi_wstrb;
    logic                       s_axi_wvalid;

    // =========================================================================
    // MODPORTS
    // =========================================================================
    // Slave view: accept addresses/data from master, drive READY/RESP
    modport slave (
        // Global
        input  aclk,
        input  aresetn,

        // Read Address (AR)
        input  s_axi_araddr,
        input  s_axi_arburst,
        input  s_axi_arcache,
        input  s_axi_arlen,
        input  s_axi_arlock,
        input  s_axi_arprot,
        input  s_axi_arqos,
        output s_axi_arready,
        input  s_axi_arregion,
        input  s_axi_arsize,
        input  s_axi_arvalid,

        // Write Address (AW)
        input  s_axi_awaddr,
        input  s_axi_awburst,
        input  s_axi_awcache,
        input  s_axi_awlen,
        input  s_axi_awlock,
        input  s_axi_awprot,
        input  s_axi_awqos,
        output s_axi_awready,
        input  s_axi_awregion,
        input  s_axi_awsize,
        input  s_axi_awvalid,

        // Write Response (B)
        input  s_axi_bready,
        output s_axi_bresp,
        output s_axi_bvalid,

        // Read Data (R)
        output s_axi_rdata,
        output s_axi_rlast,
        input  s_axi_rready,
        output s_axi_rresp,
        output s_axi_rvalid,

        // Write Data (W)
        input  s_axi_wdata,
        input  s_axi_wlast,
        output s_axi_wready,
        input  s_axi_wstrb,
        input  s_axi_wvalid
    );

endinterface
