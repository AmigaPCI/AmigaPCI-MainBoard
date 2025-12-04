//==========================================================================
//  Bidirectional 4 x 32-bit Async FIFO for iCE40
//  Direction 0: Amiga → PCI
//  Direction 1: PCI  → Amiga
//==========================================================================
module U109_BRIDGE_FIFO_DIR (

    //General
    input  wire        dir,         // 0 = Amiga→PCI active, 1 = PCI→Amiga active

    // ------------------------------------------------------------------
    // Amiga side (40 MHz domain)
    // ------------------------------------------------------------------
    input  wire        amiga_clk,
    //input  wire        amiga_rst,   // async assert, sync deassert recommended
    input RESETn,

    output TP0, TP1,

    // Write port (active when dir==0)
    input  wire        a_wen,
    input  wire [31:0] a_wdata,
    output wire        a_wready,    // not full
    // Read port (active when dir==1)
    output wire [31:0] a_rdata,
    output wire        a_rempty,
    input  wire        a_ren,

    // ------------------------------------------------------------------
    // PCI side (33 MHz domain)
    // ------------------------------------------------------------------
    //input CLK33,
    input  wire        pci_clk,
    //input  wire        pci_rst,

    // Write port (active when dir==1)
    input  wire        p_wen,
    input  wire [31:0] p_wdata,
    output wire        p_wready,
    // Read port (active when dir==0)
    output wire [31:0] p_rdata,
    output wire        p_rempty,
    input  wire        p_ren
);

    // One shared 4x32 memory
    reg [31:0] mem [0:3];

    // =================================================================
    // Direction 0: Amiga → PCI FIFO
    // =================================================================
    wire        a2p_push   = dir == 0 && a_wen;
    wire        a2p_pop    = dir == 0 && p_ren;
    wire        a2p_full;
    wire        a2p_empty;
    wire [31:0] a2p_rdata;

    async_fifo_4x32 fifo_a2p (
        .RESETn (RESETn),
        .wr_clk    (amiga_clk),
        //.wr_rst    (amiga_rst),
        .wr_en     (a2p_push),
        .wr_data   (a_wdata),
        .full      (a2p_full),
        .afull     (),              // not used

        .rd_clk    (pci_clk),
        //.rd_clk (CLK33),
        //.rd_rst    (pci_rst),
        .rd_en     (a2p_pop),
        .rd_data   (a2p_rdata),
        .empty     (a2p_empty),
        .aempty    ()
    );

    assign a_wready   = dir == 0 ? ~a2p_full  : ~p2a_full;
    assign p_rempty   = dir == 0 ?  a2p_empty :  p2a_empty;
    assign p_rdata    = a2p_rdata;

    // =================================================================
    // Direction 1: PCI → Amiga FIFO
    // =================================================================
    wire        p2a_push   = dir == 1 && p_wen;
    wire        p2a_pop    = dir == 1 && a_ren;
    wire        p2a_full;
    wire        p2a_empty;
    wire [31:0] p2a_rdata;

    async_fifo_4x32 fifo_p2a (
        .RESETn (RESETn),
        .wr_clk    (pci_clk),
        //.wr_clk (CLK33),
        //.wr_rst    (pci_rst),
        .wr_en     (p2a_push),
        .wr_data   (p_wdata),
        .full      (p2a_full),
        .afull     (),

        .rd_clk    (amiga_clk),
        //.rd_rst    (amiga_rst),
        .rd_en     (p2a_pop),
        .rd_data   (p2a_rdata),
        .empty     (p2a_empty),
        .aempty    ()

        ,.TP0 (TP0), .TP1(TP1)
    );

    assign p_wready   = dir == 1 ? ~p2a_full  : ~a2p_full;
    assign a_rempty   = dir == 1 ?  p2a_empty :  a2p_empty;
    assign a_rdata    = p2a_rdata;

endmodule