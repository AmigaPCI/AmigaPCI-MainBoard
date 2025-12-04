module U109_FIFO
(
    input CLKBUS, CLKPCI, RESETn,

    input TARGET_READYn, P2A_READ_NEXT,

    input [31:0] AD_IN,

    output P2A_FIFO_EMPTY, A2P_FIFO_EMPTY,
    output [31:0] P2A_DATA

    //,output TP0
);

//assign TP0 = P2A_FIFO_EMPTY;

//assign A2P_DATA = 32'hffffffff;
//assign P2A_DATA = 32'hffffffff;

assign P2A_FIFO_EMPTY = (RD_POINTER == WR_POINTER);
assign A2P_FIFO_EMPTY = 1;
assign P2A_DATA = mem[RD_POINTER];

reg [31:0] mem [0:3] /* synthesis syn_ramstyle = "rw_check" */;
reg [1:0] WR_POINTER; //Valid values are 0-3
reg [1:0] RD_POINTER; //Valid values are 0-3

//PCI to Amiga

//AD (PCI) BUS
always @(posedge CLKPCI) begin
    if (!RESETn) begin
        WR_POINTER <= 0;
    end else begin
        if (!TARGET_READYn) begin
            mem[WR_POINTER] <= AD_IN;
            WR_POINTER <= WR_POINTER + 1;
        end
    end
end

//D (Amiga) Bus
always @(negedge CLKBUS) begin
    if (!RESETn) begin
        RD_POINTER <= 0;
    end else begin
        if (P2A_READ_NEXT && !P2A_FIFO_EMPTY) begin
            RD_POINTER <= RD_POINTER + 1;
        end
    end
end


endmodule