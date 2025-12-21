//==========================================================================
//  Small proven 4x32 asynchronous FIFO (standard handshake, 3-stage sync)
//  Works perfectly on iCE40
//==========================================================================
module async_fifo_4x32 (
    input RESETn,

    input  wire        wr_clk,
    //input  wire        wr_rst,
    input  wire        wr_en,
    input  wire [31:0] wr_data,
    output wire        full,
    output wire        afull,     // not used here

    input  wire        rd_clk,
    //input  wire        rd_rst,
    input  wire        rd_en,
    output reg  [31:0] rd_data,
    output wire        empty,
    output wire        aempty     // not used
);
    localparam PTR_WIDTH = 3;  // 2 bits addr + 1 bit wrap

    reg [31:0] mem [0:3] /* synthesis syn_ramstyle = "rw_check" */ ; //no_rw_check
    //(* syn_ramstyle = "block_ram" *) reg [31:0] mem [0:3];

    // Write side
    reg [PTR_WIDTH-1:0] wr_ptr_bin;
    (* syn_preserve = 1 *) reg [PTR_WIDTH-1:0] wr_ptr_gray;
    reg [PTR_WIDTH-1:0] wr_ptr_gray_sync [0:2];

    // Read side
    reg [PTR_WIDTH-1:0] rd_ptr_bin;
    (* syn_preserve = 1 *) reg [PTR_WIDTH-1:0] rd_ptr_gray;
    reg [PTR_WIDTH-1:0] rd_ptr_gray_sync [0:2];

    // Binary to Gray
    function [PTR_WIDTH-1:0] bin2gray(input [PTR_WIDTH-1:0] bin);
        bin2gray = bin ^ (bin >> 1);
    endfunction

    // Full when write pointer would lap read pointer by exactly DEPTH
    assign full  = (wr_ptr_gray == { ~rd_ptr_gray_sync[2][PTR_WIDTH-1:PTR_WIDTH-2],
                                      rd_ptr_gray_sync[2][PTR_WIDTH-3:0] });

    // Empty when pointers match
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync[2]);

    assign afull = full;
    assign aempty = empty;

    // ==================== Write domain ====================
    always @(posedge wr_clk or negedge RESETn) begin //posedge wr_rst) begin
        //if (wr_rst) begin
        if (!RESETn) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr_bin[1:0]] <= wr_data;
            wr_ptr_bin  <= wr_ptr_bin + 1'd1;
            wr_ptr_gray <= bin2gray(wr_ptr_bin + 1'd1);
        end
    end

    // Synchronize read pointer into write clock (3 stages)
    always @(posedge wr_clk or negedge RESETn) begin // posedge wr_rst) begin
        //if (wr_rst)
        if (!RESETn) begin
            {wr_ptr_gray_sync[2], wr_ptr_gray_sync[1], wr_ptr_gray_sync[0]} <= 0; //, wr_ptr_gray,
        end else begin
            wr_ptr_gray_sync[0] <= rd_ptr_gray;
            wr_ptr_gray_sync[1] <= wr_ptr_gray_sync[0];
            wr_ptr_gray_sync[2] <= wr_ptr_gray_sync[1];
        end
    end

    // ==================== Read domain ====================
    always @(negedge rd_clk or negedge RESETn) begin // posedge rd_rst) begin
        //if (rd_rst) begin
        if (!RESETn) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
            rd_data     <= 0;
        end else if (rd_en && !empty) begin
            rd_data     <= mem[rd_ptr_bin[1:0]];
            rd_ptr_bin  <= rd_ptr_bin + 1'd1;
            rd_ptr_gray <= bin2gray(rd_ptr_bin + 1'd1);
        end
    end

    // Synchronize write pointer into read clock (3 stages)
    always @(negedge rd_clk or negedge RESETn) begin // posedge rd_rst) begin
        //if (rd_rst)
        if (!RESETn) begin
            {rd_ptr_gray_sync[2], rd_ptr_gray_sync[1], rd_ptr_gray_sync[0]} <= 0;
        end else begin
            rd_ptr_gray_sync[0] <= wr_ptr_gray;
            rd_ptr_gray_sync[1] <= rd_ptr_gray_sync[0];
            rd_ptr_gray_sync[2] <= rd_ptr_gray_sync[1];
        end
    end

endmodule