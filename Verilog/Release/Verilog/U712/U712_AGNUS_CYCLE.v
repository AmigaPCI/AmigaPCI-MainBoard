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
NonCommercial — You may not use the material for commercial purposes.
No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.

RTL MODULE:

Engineer: Jason Neus
Design Name: U712
Module Name: U712_AGNUS_CYCLE
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Agnus State Machine - Supply signals to Agnus to emulate MC68000 cycle.

Revision History
Date          Who  Description
-----------------------------------
07-JUN-2026   JN   New state machine.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U712_AGNUS_CYCLE
(
    input CLK40, CLK14, C1, C3,

    input RESETn, TSn, RnW, REGSPACEn, RAMSPACEn, DBRn, UDS, LDS,

    output TACKn, BLSn, REG_CYCLE, VBENn, 
    output reg ASn, UDSn, LDSn, PRnW, REGENn, RAMENn, AGNUS_WRITE_CYCLE    
);

//The 14MHz clock has a rising edge on every 7MHz edge.
//wire CLK14 = ~(CLK7 ^ CDAC); //XNOR

//--- Detect Cycle Start ---
wire AGNUS_SPACE = (!REGSPACEn || !RAMSPACEn);
wire AGNUS_CYCLE_RESET = (!RESETn || AGNUS_TACK_EN);

reg AGNUS_CYCLE_START;
always @(posedge CLK40, posedge AGNUS_CYCLE_RESET) begin
    if (AGNUS_CYCLE_RESET) begin
        AGNUS_CYCLE_START <= 1'b0;
    end else begin
        if (!AGNUS_CYCLE_START) begin
            AGNUS_CYCLE_START <= (!TSn && AGNUS_SPACE);
        end
    end
end

//--- Last Agnus Clock State ---
reg C1_LAST, C3_LAST;
always @(negedge CLK14) begin
    if (!RESETn) begin
        C1_LAST <= 1'b0;
        C3_LAST <= 1'b0;
    end else begin
        C1_LAST <= C1;
        C3_LAST <= C3;
    end
end

//--- Agnus State Machine ---
localparam STATE0 = 4'h0;
localparam STATE2 = 4'h1;
localparam STATE3 = 4'h2;
localparam STATE4 = 4'h3;
localparam STATE5 = 4'h4;
localparam STATE6 = 4'h5;
localparam STATE7 = 4'h6;

assign BLSn = ASn;

reg AGNUS_TACK_EN;
reg VB_EN;
reg [1:0] AGNUS_CYCLE_START_SYNC;
reg [3:0] AGNUS_STATE;
always @(posedge CLK14) begin
    if (!RESETn) begin
        PRnW   <= 1'b1;
        ASn    <= 1'b1;
        UDSn   <= 1'b1;
        LDSn   <= 1'b1;
        VB_EN  <= 1'b0;
        REGENn <= 1'b1;
        RAMENn <= 1'b1;
        AGNUS_TACK_EN <= 1'b0;
        AGNUS_WRITE_CYCLE <= 1'b0;
        AGNUS_CYCLE_START_SYNC <= 2'b00;
        AGNUS_STATE <= STATE0;
    end else begin
        case (AGNUS_STATE)
            STATE0 : begin
                PRnW   <= 1'b1;
                VB_EN <= 1'b0;
                AGNUS_WRITE_CYCLE <= 1'b0;
                AGNUS_STATE <= STATE2;
            end
            STATE2 : begin
                if (AGNUS_CYCLE_START_SYNC != 2'b00 && !C1_LAST && C3_LAST) begin
                    ASn    <= 1'b0;
                    PRnW   <= RnW;
                    LDSn   <= ~LDS;
                    UDSn   <= ~UDS;
                    REGENn <= REGSPACEn;
                    RAMENn <= RAMSPACEn;
                    AGNUS_WRITE_CYCLE <= ~RnW;
                    AGNUS_CYCLE_START_SYNC <= 2'b00;
                    AGNUS_STATE <= STATE3;
                end else begin
                    AGNUS_CYCLE_START_SYNC <= {AGNUS_CYCLE_START_SYNC[0], AGNUS_CYCLE_START};
                end
            end
            STATE3 : begin
                AGNUS_STATE <= STATE4;
            end
            STATE4 : begin
                if (DBRn && C1_LAST && !C3_LAST) begin
                    //Wait for _DBR to negate before proceeding.
                    VB_EN <= 1'b1;
                    AGNUS_STATE <= STATE5;
                    AGNUS_TACK_EN <= 1'b1;
                end
            end
            STATE5 : begin
                AGNUS_TACK_EN <= 1'b0;
                AGNUS_STATE <= STATE6;
            end
            STATE6 : begin
                AGNUS_STATE <= STATE7;
            end
            STATE7 : begin
                ASn    <= 1'b1;
                LDSn   <= 1'b1;
                UDSn   <= 1'b1;
                REGENn <= 1'b1;
                RAMENn <= 1'b1;
                AGNUS_STATE <= STATE0;
            end
        endcase
    end
end

//--- Video Bus Enable ---
wire   RAM_CYCLE = (VB_EN && !RAMSPACEn);
assign REG_CYCLE = (VB_EN && !REGSPACEn);
assign VBENn     = ~(RAM_CYCLE || REG_CYCLE);

//--- Cycle Termination ---
localparam [1:0] TACK_IDLE  = 2'b00;
localparam [1:0] TACK_ASST  = 2'b01;
localparam [1:0] TACK_NEG   = 2'b10;
localparam [1:0] TACK_REARM  = 2'b11;
localparam [3:0] RD_RAM_DELAY = 4'h4; //This can be made lesser if the CLKE signal is released sooner in the RAM FSM.
localparam [3:0] RD_REG_DELAY = 4'h2; //3 causes some instability. This timing has a very narrow tolerance.
localparam [3:0] WR_RAM_DELAY = 4'h2;
localparam [3:0] WR_REG_DELAY = 4'h6;

assign TACKn = TACK_EN ? TACK_OUT : 1'bz;

reg TACK_EN;
reg TACK_OUT;
reg [1:0] TACK_STATE;
reg [1:0] TACK_SYNC;
reg [3:0] TACK_DELAY_COUNT;
reg [3:0] TACK_DELAY;
//always @(negedge CLK40) begin
always @(posedge CLK40) begin
    if (!RESETn) begin
        TACK_EN    <= 1'b0;
        TACK_OUT   <= 1'b1;
        TACK_SYNC  <= 2'b0;
        TACK_DELAY <= RD_RAM_DELAY;
        TACK_DELAY_COUNT <= 4'h0;
        TACK_STATE <= TACK_IDLE;
    end else begin

        TACK_SYNC <= {TACK_SYNC[0], AGNUS_TACK_EN};

        case (TACK_STATE)
            TACK_IDLE : begin
                if (TACK_SYNC[1]) begin
                    TACK_EN <= 1'b1;
                    if (RnW) begin
                        TACK_DELAY <= REG_CYCLE ? RD_REG_DELAY : RD_RAM_DELAY;
                    end else begin
                        TACK_DELAY <= REG_CYCLE ? WR_REG_DELAY : WR_RAM_DELAY;
                    end
                    TACK_STATE <= TACK_ASST;
                end
            end
            TACK_ASST : begin
                if (TACK_DELAY_COUNT == TACK_DELAY) begin
                    TACK_OUT <= 1'b0;
                    TACK_DELAY_COUNT <= 4'h0;
                    TACK_STATE <= TACK_NEG;
                end else begin
                    TACK_DELAY_COUNT <= TACK_DELAY_COUNT + 1;
                end
            end
            TACK_NEG : begin
                TACK_OUT <= 1'b1;
                TACK_STATE <= TACK_REARM;
            end
            TACK_REARM : begin
                TACK_EN <= 1'b0;
                if (!TACK_SYNC[1]) begin
                    TACK_STATE <= TACK_IDLE;
                end
            end
        endcase
    end
end

endmodule