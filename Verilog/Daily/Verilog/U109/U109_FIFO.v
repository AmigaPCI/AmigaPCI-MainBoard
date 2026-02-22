/*
LICENSE:

This work is released under the Creative Commons Attribution-NonCommercial 4.0 International
https://creativecommons.org/licenses/by-nc/4.0/

You are free to:
Share — copy and redistribute the material in any medium or format
Adapt — remix, transform, and build upon the material
The licensor cannot revoke these freedoms as long as you follow the license terms.

Under the following terms:
Attribution — You must give appropriate credit , provide a link to the license, and indicate if changes were made . You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
NonCommercial — You may not use the material for commercial purposes .
No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.

RTL MODULE:

Engineer: Jason Neus
Design Name: U109
Module Name: U109_FIFO
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: FIFO memory for crossing clock domains between Amiga and PCI busses.

Date          Who  Description
-----------------------------------
03-JAN-2026   JN   INITIAL CODE

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U109_FIFO
(
    input RESETn, CLK_WR, CLK_WR_SYNC, CLK_RD, CLK_RD_SYNC,

    input WR_EN, READ_NEXT,

    input [31:0] DATA_IN,

    output FIFO_EMPTY,
    output FIFO_FULL,
    output reg [31:0] DATA_OUT
);

//This is the BRAM asynchronous FIFO. We use the same module for two
//seperate FIFOs. One FIFO moves the data from the Amiga to the PCI bus.
//The other moves the data from the PCI bus to the Amiga.
//The "write" side ingests data from the device supplying it.
//The "read" side drives the data to the device requesting it.

reg [31:0] MEM[0:3] /* synthesis syn_ramstyle = "rw_check" */;

reg [1:0] WR_POINTER_BIN;
reg [1:0] RD_POINTER_BIN;
reg [1:0] WR_POINTER_GRAY;
reg [1:0] RD_POINTER_GRAY;
reg [1:0] WR_GRAY_SYNC1;
reg [1:0] WR_GRAY_SYNC2;
reg [1:0] RD_GRAY_SYNC1;
reg [1:0] RD_GRAY_SYNC2;

// ---------- Write side ----------
always @(posedge CLK_WR) begin
    if (!RESETn) begin
        WR_POINTER_BIN  <= 2'd0;
        WR_POINTER_GRAY <= 2'd0;
    end else begin
        if (WR_EN) begin
            MEM[WR_POINTER_BIN] <= DATA_IN;
            WR_POINTER_BIN <= WR_POINTER_BIN + 1'd1;
            WR_POINTER_GRAY <= (WR_POINTER_BIN + 1'd1) ^ ((WR_POINTER_BIN + 1'd1) >> 1);
        end
    end
end

always @(posedge CLK_WR_SYNC) begin
    if (!RESETn) begin
        RD_GRAY_SYNC1   <= 2'd0;
        RD_GRAY_SYNC2   <= 2'd0;
    end else begin
        RD_GRAY_SYNC1 <= RD_POINTER_GRAY;
        RD_GRAY_SYNC2 <= RD_GRAY_SYNC1;
    end
end

// ---------- Read side ----------
always @* begin
    DATA_OUT = MEM[RD_POINTER_BIN];
end

assign FIFO_EMPTY = (WR_GRAY_SYNC2 == RD_POINTER_GRAY);
assign FIFO_FULL = (WR_POINTER_GRAY == {~RD_GRAY_SYNC2[1], RD_GRAY_SYNC2[0]});

always @(negedge CLK_RD_SYNC) begin
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

