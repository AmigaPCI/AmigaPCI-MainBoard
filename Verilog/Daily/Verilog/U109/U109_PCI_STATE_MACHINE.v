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
Module Name: U109_PCI_STATE_MACHINE
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Part of the PCI state machine.

Date          Who  Description
-----------------------------------
18-NOV-2025   JN   INITIAL CODE
21-NOV-2025   JN   Moved PCIAT assertion to this module.
01-DEC-2025   JN   Incorporate FIFO transactions.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U109_PCI_STATE_MACHINE (

    //Clocks
    input CLK40, CLK33,

    //Cycle Start/Termination
    input RESETn, RnW, BURSTn, PCI_TIPn, BGn, TACKn,

    //FIFO
    input P2A_FIFO_EMPTY, A2P_FIFO_EMPTY,

    //Address/Data
    //input [31:0] AD,

    //PCI Signals
    output CLK_ADDRESS_LATCH, INIT_READYn, PCI_CYCLEn, PARITY_DIR, DATA_DIRECTION, PCI_WRITE_CYCLE, 
    output reg PCI_TACK_EN, P2A_READ_NEXT

);

////////////////////////
// PCI STATE MACHINE //
//////////////////////

localparam [1:0] BURST_TOTAL = 2'b11;
localparam AMIGA_TO_PCI  = 1;
localparam PCI_TO_AMIGA  = 0;
localparam FIFO_TO_PCI   = 0;
localparam FIFO_TO_AMIGA = 1;

assign CLK_ADDRESS_LATCH = 0;
assign INIT_READYn = !BGn ? !(A2P_INIT_RDY ^ P2A_INIT_RDY) : 1'bz;
assign PCI_CYCLEn = !(A2P_CYCLE ^ P2A_CYCLE);
assign PARITY_DIR = A2P_CYCLE ? AMIGA_TO_PCI : PCI_TO_AMIGA;
assign DATA_DIRECTION = A2P_CYCLE ? FIFO_TO_PCI : FIFO_TO_AMIGA;
assign PCI_WRITE_CYCLE = A2P_CYCLE;

//Direction of data flow.
// 0 = Amiga is producer, PCI is consumer
// 1 = PCI is producer, Amiga is consumer

//Drive Amiga to PCI cycles. e.g. CPU write.
reg A2P_BURST_CYCLE, A2P_INIT_RDY, A2P_CYCLE;
reg [1:0] A2P_BURST_COUNT;
reg [3:0] A2P_CYCLE_STATE;
always @(negedge CLK33) begin
    if (!RESETn) begin
        A2P_CYCLE <= 0;
        A2P_INIT_RDY <= 0;
        A2P_BURST_CYCLE <= 0;
        //a_ren <= 0;
        A2P_BURST_COUNT <= 2'b00;
        A2P_CYCLE_STATE <= 4'h0;
    end else begin
        case (A2P_CYCLE_STATE)
            4'h0 : begin
                if (!PCI_TIPn && !RnW) begin
                    A2P_CYCLE <= 1; //Signal U110 we are going.
                    A2P_BURST_CYCLE <= !(BURSTn); //Is this a burst cycle?
                    A2P_BURST_COUNT <= 2'b0; //Reset the burst counter.
                    A2P_CYCLE_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                if (A2P_FIFO_EMPTY) begin //FIFO is empty.
                    //a_ren <= 0; //Wait
                    A2P_INIT_RDY <= 0;
                    if ((!A2P_BURST_CYCLE && A2P_BURST_COUNT == 1) || (A2P_BURST_COUNT == BURST_TOTAL)) begin
                        A2P_CYCLE <= 0;
                        A2P_CYCLE_STATE <= 4'h0;
                    end
                end else begin //FIFO not empty
                    //a_ren <= 1; //Clock in the next word.

                    A2P_INIT_RDY <= 1; //Assert initiator ready.
                    A2P_BURST_COUNT <= A2P_BURST_COUNT + 1;
                    if (A2P_BURST_COUNT == (BURST_TOTAL - 1)) begin
                        A2P_CYCLE <= 0; //Disable _FRAME one clock before cycle ends.
                    end
                end

                if (PCI_TIPn) begin //Catch cycle time out or early termination.
                    A2P_CYCLE <= 0;
                    A2P_INIT_RDY <= 0;
                    A2P_CYCLE_STATE <= 4'h0;
                end
            end
        endcase
    end
end

//Drive PCI to Amiga cycles. e.g. CPU Read.
reg P2A_INIT_RDY, P2A_CYCLE, P2A_RESET; //P2A_BURST_CYCLE,  //, P2A_START, P2A_INIT_EN,P2A_CYCLE_EN,
reg [1:0] P2A_START_SYNC; //, P2A_CYCLE_EN_SYNC, P2A_INIT_EN_SYNC;
//reg [1:0] P2A_BURST_COUNT;
reg [3:0] P2A_CYCLE_STATE;

//The first SM drives the PCI bus signals on the falling clock edge.
wire P2A_CYCLE_RESET = (!RESETn || P2A_RESET);
always @(negedge CLK33, posedge P2A_CYCLE_RESET) begin
    if (P2A_CYCLE_RESET) begin
        P2A_INIT_RDY <= 0;
        P2A_CYCLE <= 0;
    end else begin
        if (RnW && !PCI_TIPn) begin
            P2A_CYCLE <= 1;
            P2A_INIT_RDY <= 1;
        end
    end
end

reg TACK_DELAY;
always @(posedge CLK40) begin
    if (!RESETn) begin
        TACK_DELAY <= 0;
    end else begin
        TACK_DELAY <= ~TACKn;
    end
end

//This SM drives the Amiga bus signals
always @(negedge CLK40) begin
    if (!RESETn) begin
        P2A_START_SYNC <= 2'b00;
        PCI_TACK_EN <= 0;
        P2A_RESET <= 0;
        P2A_READ_NEXT <= 0;
        P2A_CYCLE_STATE <= 4'h0;
    end else begin
        case (P2A_CYCLE_STATE)
            4'h0 : begin
                P2A_RESET <= 0;
                P2A_READ_NEXT <= 0;
                if ((P2A_START_SYNC[1] ^ P2A_START_SYNC[0])) begin
                    P2A_CYCLE_STATE <= 4'h1;
                end else begin
                    P2A_START_SYNC <= {P2A_START_SYNC[0], P2A_CYCLE};
                end
            end
            4'h1 : begin
                P2A_START_SYNC <= 2'b00;
                if (!P2A_FIFO_EMPTY) begin //FIFO has data!
                    PCI_TACK_EN <= 1;
                    P2A_CYCLE_STATE <= 4'h2;
                end else if (PCI_TIPn) begin //Catch cycle time out or early termination.
                    P2A_RESET <= 1;
                    P2A_CYCLE_STATE <= 4'h0;
                end
            end
            4'h2 : begin
                PCI_TACK_EN <= 0;
                 if (TACK_DELAY) begin
                    P2A_READ_NEXT <= 1; //Clock in the next word.
                    P2A_RESET <= 1;
                    P2A_CYCLE_STATE <= 4'h0;
                 end
            end

                /*if (P2A_FIFO_EMPTY) begin //FIFO is empty.
                    P2A_READ_NEXT <= 0; //Wait
                    PCI_TACK_EN   <= 0;        
                    if ((!P2A_BURST_CYCLE && P2A_BURST_COUNT == 1) || (P2A_BURST_COUNT == BURST_TOTAL)) begin
                        P2A_CYCLE_EN <= 0;
                        P2A_INIT_EN <= 0;
                        P2A_CYCLE_STATE <= 4'h0;
                    end
                end else begin //FIFO not empty
                    PCI_TACK_EN <= 1;
                    P2A_READ_NEXT <= 1; //Clock in the next word.
                    P2A_BURST_COUNT <= P2A_BURST_COUNT + 1;
                    if (P2A_BURST_COUNT == (BURST_TOTAL - 1)) begin
                        P2A_CYCLE_EN <= 0; //Disable _FRAME one clock before cycle ends.
                    end
                end
            end*/

        endcase
    end
end

endmodule
