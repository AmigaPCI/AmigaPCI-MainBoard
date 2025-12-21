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
    input CLK80, CLK66, CLK40, CLK33, RESETn, TSn, RnW,

    //Cycle Start/Termination
    input REG_DATA, BURSTn, PCI_TIPn, BGn, PCI_WRITE_EN, BRIDGE_CONF_SPACE, 
    input [7:0] A,

    //FIFO
    input P2A_FIFO_EMPTY, A2P_FIFO_EMPTY,

    //PCI Signals
    input DEVSELn, TARGET_READYn,
    output CLK_ADDRESS_LATCH, INIT_READYn, PARITY_DIR, TACKn, PCI_RSTn,
    output reg P2A_READ_NEXT, A2P_READ_NEXT, TCI_ENn, PCI_CYCLEn

    //,output TP0, TP1
);

//assign TP1 = REG_DATA;
//assign TP0 = REG_CYCLE;

/////////////////
// PARAMETERS //
///////////////

localparam [1:0] BURST_TOTAL = 2'b11;
localparam PCI_TO_AMIGA = 0;
localparam AMIGA_TO_PCI = 1;

///////////////////////
// WIRE ASSIGNMENTS //
/////////////////////

assign CLK_ADDRESS_LATCH = 0;
assign INIT_READYn = !BGn ? !(INIT_EN) : 1'bz;
assign PARITY_DIR = (PCI_CYCLEn || A2P_CYCLE_EN) ? AMIGA_TO_PCI : PCI_TO_AMIGA;

/////////////////////////////////
// AMIGA TO PCI STATE MACHINE //
///////////////////////////////

reg [1:0] PCI_WRITE_EN_SYNC;
always @(negedge CLK66) begin
    if (!RESETn) begin
        PCI_WRITE_EN_SYNC <= 2'b0;
    end else begin
        PCI_WRITE_EN_SYNC <= {PCI_WRITE_EN_SYNC[0], PCI_WRITE_EN};
    end
end

//Capture _TRDY so we can sample it on the falling edge.
reg TARGET_RDY_DELAY;
always @(posedge CLK33) begin
    if (!RESETn) begin
        TARGET_RDY_DELAY <= 0;
    end else begin
        TARGET_RDY_DELAY <= !(TARGET_READYn);
    end
end

//We drive the signals common to both Amiga to PCI and PCI to Amiga data
//transfer cycle types. We assert _IRDY right away and then drive the
//proper cycle type, dictated by the direction of data movement.
//This state machine also pushes data to the AD bus.
wire P2A_RST = (!RESETn || P2A_CYCLE_RST);
reg INIT_EN, A2P_CYCLE_EN, P2A_CYCLE_EN;
reg [3:0] PCI_CYCLE_STATE;
always @(negedge CLK33, posedge P2A_RST) begin
    if (P2A_RST) begin
        INIT_EN <= 0;
        A2P_READ_NEXT <= 0;
        A2P_CYCLE_EN <= 0;
        P2A_CYCLE_EN <= 0;
        PCI_CYCLEn <= 1;
        PCI_CYCLE_STATE <= 4'h0;
    end else begin
        case (PCI_CYCLE_STATE)
            4'h0 : begin
                if (!PCI_TIPn) begin
                    INIT_EN <= 1;
                    PCI_CYCLEn <= 0;
                    PCI_CYCLE_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                if (PCI_WRITE_EN_SYNC[1]) begin
                    A2P_CYCLE_EN <= 1;
                    P2A_CYCLE_EN <= 0;
                end else begin
                    A2P_CYCLE_EN <= 0;
                    P2A_CYCLE_EN <= 1;
                end
                PCI_CYCLE_STATE <= 4'h2;
            end
            4'h2 : begin
                //Watch for A2P cycle termination.
                //P2A cycle is terminated via the asynchronous reset.
                if (A2P_CYCLE_EN && (TARGET_RDY_DELAY || (PCI_TIPn && DEVSELn))) begin
                    INIT_EN <= 0;
                    A2P_READ_NEXT <= 1;
                    A2P_CYCLE_EN <= 0;
                    PCI_CYCLE_STATE <= 4'h3;
                end
            end
            4'h3 : begin
                A2P_READ_NEXT <= 0;
                PCI_CYCLEn <= 1;
                PCI_CYCLE_STATE <= 4'h0;
            end
        endcase
    end
end

/////////////////////////////////
// PCI TO AMIGA STATE MACHINE //
///////////////////////////////

//Push data to the Amiga bus on the 40MHz clock.
reg PCI_TACK_EN, P2A_CYCLE_RST, PREV_CLK;
reg [1:0] PCI_TIPn_SYNC, P2A_CYCLE_SYNC;
reg [3:0] P2A_CYCLE_STATE;
always @(negedge CLK80) begin
    if (!RESETn) begin
        PREV_CLK <= 0;
        TCI_ENn <= 1;
        PCI_TACK_EN <= 0;
        P2A_READ_NEXT <= 0;
        P2A_CYCLE_RST <= 0;
        P2A_CYCLE_SYNC <= 2'b0;
        PCI_TIPn_SYNC <= 2'b0;
        P2A_CYCLE_STATE <= 4'h0;
    end else begin
        //------ Sync with 33MHz domain ------
        PCI_TIPn_SYNC <= {PCI_TIPn_SYNC[0], PCI_TIPn};

        //Get the previous 40MHz clock state.
        PREV_CLK <= CLK40;

        //------ PCI to Amiga state machine ------
        case (P2A_CYCLE_STATE)
            4'h0 : begin
                if (P2A_CYCLE_SYNC[1] || P2A_CYCLE_SYNC[0]) begin
                    P2A_CYCLE_STATE <= 4'h1;
                    TCI_ENn <= 0;
                end else begin
                    P2A_CYCLE_SYNC <= {P2A_CYCLE_SYNC[0], P2A_CYCLE_EN};
                    P2A_CYCLE_RST <= 0;
                    P2A_READ_NEXT <= 0;
                end
            end
            4'h1 : begin
                P2A_CYCLE_SYNC <= 2'b0;
                if (!P2A_FIFO_EMPTY) begin
                    PCI_TACK_EN <= 1;
                    P2A_CYCLE_STATE <= 4'h2;
                end else if (PCI_TIPn_SYNC[1] || PCI_TIPn_SYNC[0]) begin
                    P2A_CYCLE_STATE <= 4'h3;
                end
            end
            4'h2 : begin
                 if (!TACK_OUT) begin
                    P2A_CYCLE_STATE <= 4'h3;
                 end
            end
            4'h3 : begin
                PCI_TACK_EN <= 0;
                TCI_ENn <= 1;
                if (PREV_CLK) begin
                    P2A_READ_NEXT <= 1;
                    P2A_CYCLE_STATE <= 4'h4;
                end
            end
            4'h4 : begin
                P2A_CYCLE_RST <= 1;
                P2A_CYCLE_STATE <= 4'h0;
            end
        endcase
    end
end

////////////////////////////
// BRIDGE REGISTER CYCLE //
//////////////////////////

//We support a write only register at offset $FF in the bridge
//config0 space.

//D[31] = PCI bus reset bit

localparam BRIDGE_REG_ADD  = 8'hfc;

assign PCI_RSTn = !(!RESETn || PCI_RST_REG);
wire REG_CYCLE_START = (!TSn && !RnW && BRIDGE_CONF_SPACE && A == BRIDGE_REG_ADD);

reg REG_CYCLE, PCI_RST_REG, REG_TACK;
always @(posedge CLK40 or posedge REG_CYCLE_START) begin
    if (REG_CYCLE_START) begin
        REG_CYCLE <= 1;
    end else if (!RESETn) begin
        PCI_RST_REG <= 0;
        REG_CYCLE <= 0;
    end else begin
        if (REG_CYCLE) begin
            PCI_RST_REG <= REG_DATA;
            REG_CYCLE <= 0;
        end
    end    
end

////////////////////////
// CYCLE TERMINATION //
//////////////////////

assign TACKn = TACK_EN ? TACK_OUT : 1'bz;

reg TACK_EN, TACK_OUT;
reg [1:0] TACK_STATE;
always @(posedge CLK40) begin
    if (!RESETn) begin
        TACK_EN <= 0;
        TACK_OUT <= 1;
        TACK_STATE <= 2'b00;
    end else begin
        case (TACK_STATE)
            2'b00 : begin
                if (PCI_TACK_EN) begin
                    TACK_OUT <= 0;
                    TACK_EN <= 1;
                    TACK_STATE <= 2'b01;
                end
            end
            2'b01 : begin
                TACK_OUT <= 1;
                TACK_STATE <= 2'b10;
            end
            2'b10 : begin
                TACK_EN <= 0;
                TACK_STATE <= 2'b00;
            end
        endcase
    end
end

endmodule
