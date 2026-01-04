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
    input DEVSELn, TARGET_READYn, CACHE_SPACE_EN, //STOPn,
    output CLK_ADDRESS_LATCH, INIT_READYn, TACKn, TBIn, PARITY_DIR, PCI_RSTn,
    output reg P2A_READ_NEXT, A2P_READ_NEXT, TCI_ENn, BUFFER_EN, P2A_TIMEOUT, PCI_CYCLEn

    ,output TP0, TP1
);

//assign TP1 = REG_DATA;
//assign TP0 = REG_CYCLE;
assign TP0 = A2P_TIMEOUT;
assign TP1 = PCI_CYCLEn;

/////////////////
// PARAMETERS //
///////////////

localparam [1:0] BURST_TOTAL = 2'b11;
localparam PCI_TO_AMIGA = 0;
localparam AMIGA_TO_PCI = 1;
localparam BRIDGE_REGISTER_ADDRESS  = 8'hfc;

///////////////////////
// WIRE ASSIGNMENTS //
/////////////////////

assign CLK_ADDRESS_LATCH = 0;
assign INIT_READYn = !BGn ? !(INIT_EN) : 1'bz;
assign PARITY_DIR = (PCI_CYCLEn || A2P_CYCLE_EN) ? AMIGA_TO_PCI : PCI_TO_AMIGA;

/////////////////////////////////
// AMIGA TO PCI STATE MACHINE //
///////////////////////////////

//------ CPU R/W cycle synchornizer ------
reg [1:0] PCI_WRITE_EN_SYNC;
always @(negedge CLK66) begin
    if (!RESETn) begin
        PCI_WRITE_EN_SYNC <= 2'b0;
    end else begin
        PCI_WRITE_EN_SYNC <= {PCI_WRITE_EN_SYNC[0], PCI_WRITE_EN};
    end
end

//_STOP may asserted by the target device as a means to terminate the cycle.
//It takes precedence over our wishes. If the target device
//asserts _STOP, we then need to react to that by transferring the first
//word of data (if possible) and then terminate the CPU cycle by asserting _TBI. 
//If _STOP is asserted _TRDY is asserted, well,
//that's a problem and will need to result in a bus error.
//wire PCI_CYCLE_RST = (!RESETn || !STOPn || PCI_CYCLE_END);
wire PCI_CYCLE_RST = (!RESETn || PCI_CYCLE_END);
always @(posedge CLK33 or posedge PCI_CYCLE_RST) begin
    if (PCI_CYCLE_RST) begin
        PCI_CYCLEn <= 1;
    end else begin
        if (PCI_CYCLE_EN) begin
            PCI_CYCLEn <= 0;
        end
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

//------ PCI State Machine ------
//We drive the signals common to both Amiga to PCI and PCI to Amiga data
//transfer cycle types. We assert _IRDY right away and then drive the
//proper cycle type, dictated by the direction of data movement.
//This state machine also pushes data to the AD bus.

wire P2A_RST = (!RESETn || P2A_CYCLE_RST);
reg INIT_EN, A2P_CYCLE_EN, P2A_CYCLE_EN, PCI_CYCLE_EN, A2P_TIMEOUT;
reg [3:0] PCI_CYCLE_STATE;
always @(negedge CLK33 or posedge P2A_RST) begin
    if (P2A_RST) begin
        INIT_EN <= 0;
        BUFFER_EN <= 0;
        A2P_READ_NEXT <= 0;
        A2P_CYCLE_EN <= 0;
        P2A_CYCLE_EN <= 0;
        PCI_CYCLE_EN <= 0;
        A2P_TIMEOUT <= 0;
        PCI_CYCLE_STATE <= 4'h0;
    end else begin
        case (PCI_CYCLE_STATE)
            4'h0 : begin
                if (!PCI_TIPn) begin
                    INIT_EN <= 1;
                    BUFFER_EN <= 1;
                    PCI_CYCLE_EN <= 1;
                    A2P_TIMEOUT <= 0;
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
                PCI_CYCLE_EN <= 0;
                if (A2P_CYCLE_EN) begin
                    A2P_TIMEOUT <= (PCI_TIPn && DEVSELn);
                    if (TARGET_RDY_DELAY || A2P_TIMEOUT) begin
                        INIT_EN <= 0;
                        A2P_READ_NEXT <= 1;
                        A2P_CYCLE_EN <= 0;
                        BUFFER_EN <= 0;
                        A2P_TIMEOUT <= 0;
                        PCI_CYCLE_STATE <= 4'h3;
                    end
                end
            end
            4'h3 : begin
                A2P_READ_NEXT <= 0;
                PCI_CYCLE_STATE <= 4'h0;
            end
        endcase
    end
end

/////////////////////////////////
// PCI TO AMIGA STATE MACHINE //
///////////////////////////////

//Push data to the Amiga bus on the 40MHz clock.
reg P2A_CYCLE_RST, PREV_CLK, BURST_CYCLE, READ_NEXT_COUNT;
reg [1:0] P2A_CYCLE_SYNC, PCI_TIPn_SYNC;
reg [3:0] P2A_CYCLE_STATE;
always @(negedge CLK80) begin
    if (!RESETn) begin
        PREV_CLK <= 0;
        TCI_ENn <= 1;
        P2A_READ_NEXT <= 0;
        P2A_CYCLE_RST <= 0;
        BURST_CYCLE <= 0;
        READ_NEXT_COUNT <= 0;
        P2A_TIMEOUT <= 0;
        P2A_CYCLE_SYNC <= 2'b0;
        PCI_TIPn_SYNC <= 2'b0;
        P2A_CYCLE_STATE <= 4'h0;
    end else begin
        //------ Sync with 33MHz domain ------
        PCI_TIPn_SYNC <= {PCI_TIPn_SYNC[0], PCI_TIPn};

        //Get the 40MHz clock state. Capture this on the falling edge.
        PREV_CLK <= CLK40;

        //------ PCI to Amiga state machine ------
        case (P2A_CYCLE_STATE)
            4'h0 : begin
                if (P2A_CYCLE_SYNC[1] || P2A_CYCLE_SYNC[0]) begin
                    TCI_ENn <= 0;
                    BURST_CYCLE <= (!BURSTn && CACHE_SPACE_EN);
                    P2A_TIMEOUT <= 0;
                    P2A_CYCLE_STATE <= 4'h1;
                end else begin
                    P2A_CYCLE_SYNC <= {P2A_CYCLE_SYNC[0], P2A_CYCLE_EN};
                    P2A_CYCLE_RST <= 0;
                    P2A_READ_NEXT <= 0;
                end
            end
            4'h1 : begin
                 if (TACK_COUNT[0]) begin //Word 1
                    //if (STOP_CYCLE || !BURST_CYCLE) begin
                    if (!BURST_CYCLE) begin
                        P2A_CYCLE_STATE <= 4'h8;
                    end else begin
                        READ_NEXT_COUNT <= 0;
                        P2A_CYCLE_STATE <= 4'h2;
                    end
                 end else if (PCI_TIPn_SYNC[1] || PCI_TIPn_SYNC[0]) begin
                    P2A_TIMEOUT <= 1;
                end
            end
            4'h2 : begin
                P2A_READ_NEXT <= 1;
                P2A_CYCLE_STATE <= 4'h3;
            end
            4'h3 : begin
                if (TACK_COUNT[1]) begin //Word 2
                    READ_NEXT_COUNT <= 0;
                    P2A_CYCLE_STATE <= 4'h4;
                end else begin
                    READ_NEXT_COUNT <= 1;
                    P2A_READ_NEXT <= READ_NEXT_COUNT ? 0 : 1;                  
                end
            end
            4'h4 : begin
                P2A_READ_NEXT <= 1;
                P2A_CYCLE_STATE <= 4'h5;
            end
            4'h5 : begin
                if (TACK_COUNT[2]) begin //Word 3
                    READ_NEXT_COUNT <= 0;
                    P2A_CYCLE_STATE <= 4'h6;
                end else begin
                    READ_NEXT_COUNT <= 1;
                    P2A_READ_NEXT <= READ_NEXT_COUNT ? 0 : 1;
                end
            end
            4'h6 : begin
                P2A_READ_NEXT <= 1;
                P2A_CYCLE_STATE <= 4'h7;
            end
            4'h7 : begin
                if (TACK_COUNT[3]) begin //Word 4
                    READ_NEXT_COUNT <= 0;
                    P2A_CYCLE_STATE <= 4'h8;
                end else begin
                    READ_NEXT_COUNT <= 1;
                    P2A_READ_NEXT <= READ_NEXT_COUNT ? 0 : 1;
                end
            end
            4'h8 : begin
                TCI_ENn <= 1;
                P2A_READ_NEXT <= !(P2A_TIMEOUT);
                P2A_TIMEOUT <= 0;
                P2A_CYCLE_SYNC <= 2'b0;
                P2A_CYCLE_STATE <= 4'h9;
            end
            4'h9 : begin
                P2A_CYCLE_RST <= 1;
                P2A_CYCLE_STATE <= 4'h0;
            end
        endcase
    end
end

////////////////////////////
// BRIDGE REGISTER CYCLE //
//////////////////////////

//We support a write only register at offset $FC in the bridge
//config0 space.

//D[31] = PCI bus reset bit

assign PCI_RSTn = !(!RESETn || PCI_RST_REG);
wire REG_CYCLE_START = (!TSn && !RnW && BRIDGE_CONF_SPACE && A == BRIDGE_REGISTER_ADDRESS);

reg REG_CYCLE, PCI_RST_REG;
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

//------ Count _TRDY assertions ------
//We capture the number of target ready assertions in the 
//33MHz domain. It should never exceed 4. This value is then 
//synchrnonized into the 80MHz domain for assertion of _TACK.
//The target ready count is asynchronously reset from the 80MHz
//domain once each data transfer has been terminated.

wire TRDY_RST = (!RESETn || TACK_RST);
reg PCI_CYCLE_END;
reg [1:0] TRDY_POINTER;
reg [3:0] TRDY_COUNT;
always @(posedge CLK33 or posedge TRDY_RST) begin
    if (TRDY_RST) begin
        PCI_CYCLE_END <= 1;
        TRDY_COUNT <= 4'h0;
        TRDY_POINTER <= 2'h0;
    end else begin
        if (!TARGET_READYn || A2P_TIMEOUT) begin
            TRDY_POINTER <= TRDY_POINTER + 1;
            case (TRDY_POINTER)
                2'h00 : TRDY_COUNT[0] <= 1;
                2'h01 : TRDY_COUNT[1] <= 1;
                2'h02 : begin TRDY_COUNT[2] <= 1; PCI_CYCLE_END <= 1; end
                2'h03 : TRDY_COUNT[3] <= 1;
            endcase
        end else begin
            PCI_CYCLE_END <= 0;
        end
    end
end

//------ Transfer Burst Inhibit (_TBI) ------
//We have very little time to recognize assertion of _STOP
//and pass it to the CPU. We are being fast and loose
//with clock domain crossing, but we have little choice. The
//risk of metastability should be low due to _STOP asserting
//BEFORE we assert _TACK. We can just get in under the wire.

/*wire TBI_SET = (!STOPn && !BURSTn);
assign TBIn = TBI_EN ? TBI_OUT : 1'bz;

reg TBI_EN, TBI_OUT, STOP_CYCLE;
always @(posedge CLK80 or posedge TBI_SET) begin
    if (TBI_SET) begin
        TBI_EN <= 1;
        TBI_OUT <= 0;
        STOP_CYCLE <= 1;
    end else if (!RESETn) begin
        TBI_EN <= 0;
        TBI_OUT <= 1;
        STOP_CYCLE <= 0;
    end else begin
        if (!TBI_OUT) begin
            STOP_CYCLE <= 0;
            TBI_OUT <= 1;
        end else begin
            TBI_EN <= 0;
        end
    end
end*/

//------ Cycle termination (_TACK) ------
//Cycles can be terminated either by normal assertion of _TRDY by
//the PCI device or by timeout where no PCI device claims the bus.

assign TACKn = TACK_EN ? TACK_OUT : 1'bz;
assign TBIn  = (TACK_EN && !BURST_CYCLE) ? TACK_OUT : 1'bz;

wire TACK0 = ((TRDY_COUNT_SYNC[4] || TRDY_COUNT_SYNC[0]) || P2A_TIMEOUT);
wire TACK1 = ((TRDY_COUNT_SYNC[5] || TRDY_COUNT_SYNC[1]) || P2A_TIMEOUT);
wire TACK2 = ((TRDY_COUNT_SYNC[6] || TRDY_COUNT_SYNC[2]) || P2A_TIMEOUT);
wire TACK3 = ((TRDY_COUNT_SYNC[7] || TRDY_COUNT_SYNC[3]) || P2A_TIMEOUT);

reg TACK_EN, TACK_OUT, TACK_RST;
reg [3:0] TACK_STATE, TACK_COUNT;
reg [7:0] TRDY_COUNT_SYNC;
always @(posedge CLK80) begin
    if (!RESETn) begin
        TACK_EN <= 0;
        TACK_OUT <= 1;
        TACK_RST <= 0;
        TACK_COUNT <= 4'h0;
        TRDY_COUNT_SYNC <= 8'h0;
        TACK_STATE <= 4'h0;
    end else begin

        if (TACK_RST) begin
            TRDY_COUNT_SYNC <= 8'h0;
        end else begin
            TRDY_COUNT_SYNC <= {TRDY_COUNT_SYNC[3:0], TRDY_COUNT};
        end

        case (TACK_STATE)
            4'h0 : begin
                if ((TACK0) && !PREV_CLK) begin //First word
                    TACK_EN <= 1;
                    TACK_OUT <= 0;
                    TACK_COUNT[0] <= 1;
                    TACK_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                //if (BURSTn || STOP_CYCLE) begin
                if (!BURST_CYCLE) begin
                    TACK_STATE <= 4'h8;
                end else begin
                    TACK_STATE <= 4'h2;
                end
            end
            4'h2 : begin
                if ((TACK1) && !PREV_CLK) begin //Second word
                    TACK_OUT <= 0;
                    TACK_COUNT[1] <= 1;
                    TACK_STATE <= 4'h3;
                end else begin
                    TACK_OUT <= 1;
                end
            end
            4'h3 : begin
                TACK_STATE <= 4'h4;
            end
            4'h4 : begin
                if ((TACK2) && !PREV_CLK) begin //Third word
                    TACK_OUT <= 0;
                    TACK_COUNT[2] <= 1;
                    TACK_STATE <= 4'h5;
                end else begin
                    TACK_OUT <= 1;
                end
            end
            4'h5 : begin
                TACK_STATE <= 4'h6;
            end
            4'h6 : begin
                if ((TACK3) && !PREV_CLK) begin //Fourth word
                    TACK_OUT <= 0;
                    TACK_COUNT[3] <= 1;
                    TACK_STATE <= 4'h7;
                end else begin
                    TACK_OUT <= 1;
                end
            end
            4'h7 : begin
                TACK_STATE <= 4'h8;
            end
            4'h8 : begin
                TACK_OUT <= 1;
                TACK_RST <= 1;
                TACK_STATE <= 4'h9;
            end
            4'h9 : begin
                TACK_EN <= 0;
                TACK_RST <= 0;
                TACK_COUNT <= 4'h0;
                TACK_STATE <= 4'h0;
            end
        endcase
    end
end

endmodule
