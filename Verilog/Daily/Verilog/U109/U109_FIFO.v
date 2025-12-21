module U109_FIFO
(
    input RESETn, CLK_WR, CLK_RD, CLK_SYNC,

    input WR_EN, READ_NEXT,

    input [31:0] DATA_IN,

    output FIFO_EMPTY,
    output reg [31:0] DATA_OUT
);

//This is the BRAM asynchronous FIFO. We use the same module for two
//seperate FIFOs. One FIFO moves the data from the Amiga to the PCI bus.
//The other moves the data from the PCI bus to the Amiga.
//The "write" side ingests data from the device supplying it.
//The "read" side drives the data to the device requesting it.
//The sync_clk is 2x the normal read bus clock. For the AmigaPCI,
//this is done to decrease the time between when the FIFO is 
//loaded and the time we signal it is OK to terminate. Because the 2x
//clock is synchronous with the read clock, this works without
//additional synchronization.

reg [31:0] MEM[0:3] /* synthesis syn_ramstyle = "rw_check" */;

reg [1:0] WR_POINTER_BIN;
reg [1:0] RD_POINTER_BIN;
reg [1:0] WR_POINTER_GRAY;
reg [1:0] RD_POINTER_GRAY;
reg [1:0] WR_GRAY_SYNC1;
reg [1:0] WR_GRAY_SYNC2;

// ---------- Write side ----------
always @(posedge CLK_WR) begin
    if (!RESETn) begin
        WR_POINTER_BIN <= 2'd0;
        WR_POINTER_GRAY <= 2'd0;
    end else if (WR_EN) begin
        MEM[WR_POINTER_BIN] <= DATA_IN;
        WR_POINTER_BIN <= WR_POINTER_BIN + 1'd1;
        WR_POINTER_GRAY <= (WR_POINTER_BIN + 1'd1) ^ ((WR_POINTER_BIN + 1'd1) >> 1);
    end
end

// ---------- Read side ----------
always @* begin
    DATA_OUT = MEM[RD_POINTER_BIN];
end

assign FIFO_EMPTY = (WR_GRAY_SYNC2 == RD_POINTER_GRAY);
always @(negedge CLK_SYNC) begin
    if (!RESETn) begin
        RD_POINTER_GRAY <= 2'd0;
        WR_GRAY_SYNC1   <= 2'd0;
        WR_GRAY_SYNC2   <= 2'd0;
    end else begin
        WR_GRAY_SYNC1 <= WR_POINTER_GRAY;
        WR_GRAY_SYNC2 <= WR_GRAY_SYNC1;
        RD_POINTER_GRAY <= RD_POINTER_BIN ^ (RD_POINTER_BIN >> 1);
    end
end

always @(negedge CLK_RD) begin
    if (!RESETn) begin
        RD_POINTER_BIN  <= 2'd0;
    end else begin
        if (READ_NEXT) begin
            RD_POINTER_BIN <= RD_POINTER_BIN + 1'd1;
        end
    end
end

endmodule

