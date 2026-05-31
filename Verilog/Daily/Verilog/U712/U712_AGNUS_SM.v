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
Module Name: U712_AGNUS_SM
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Agnus State Machine - Supply signals to Agnus to emulate MC68000 cycle.

Revision History
Date          Who  Description
-----------------------------------
03-OCT-2025   JN   First release
12-OCT-2025   JN   Changed state machine to falling edge and now start at STATE 1.
16-OCT-2025   JN   Modified timing to assert _TACK during S6.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U712_AGNUS_SM

(
    //Clocks
    input CLK40, C1, C3, 
        
    //Cycle Start/Termination
    input RESETn, RnW, TSn,
    output reg AGNUS_TACK,

    //Agnus
    input DBRn, RAMSPACEn, REGSPACEn, UDS, LDS,
    output reg REGENn, RAMENn, UDSn, LDSn, ASn, BLSn, PRWn,

    //Buffers
    output reg REG_CYCLE, REG_WRITE_CYCLE,// VBENn        
    output VBENn
);

////////////////////
// SYNCHRONIZERS //
//////////////////

reg [1:0] C1_SYNC, C3_SYNC, DBRn_SYNC;

always @(negedge CLK40) begin
    if (!RESETn) begin
        C1_SYNC   <= 2'b0;
        C3_SYNC   <= 2'b0;
        DBRn_SYNC <= 2'b1;
    end else begin
        C1_SYNC[0] <= C1;
        C1_SYNC[1] <= C1_SYNC[0];

        C3_SYNC[0] <= C3;
        C3_SYNC[1] <= C3_SYNC[0];

        DBRn_SYNC[0] <= DBRn;
        DBRn_SYNC[1] <= DBRn_SYNC[0];
    end
end

////////////////////////////////////////
// AGNUS MC68000 CYCLE STATE MACHINE //
//////////////////////////////////////

localparam [3:0] READ_TACK_DELAY = 4'h4;
localparam [3:0] TACK_DELAY = 4'h6;
localparam [3:0] END_CYCLE_DELAY = TACK_DELAY - READ_TACK_DELAY;

reg [3:0] AGNUS_STATE, DELAY_COUNT;
reg AGNUS_CYCLE_START, CYCLE_ASSERT, REG_READ_CYCLE, VB_EN;

assign VBENn = !(VB_EN && (!REGSPACEn || !RAMSPACEn));

always @(posedge CLK40) begin
    if (!RESETn) begin
        CYCLE_ASSERT <= 0;
    end else begin
        CYCLE_ASSERT <= (!TSn && (!RAMSPACEn || !REGSPACEn));
    end
end

always @(negedge CLK40) begin
    if (!RESETn) begin
        REGENn <= 1;
        RAMENn <= 1;
        UDSn   <= 1;
        LDSn   <= 1;
        ASn    <= 1;
        BLSn   <= 1;
        PRWn   <= 1;
        VB_EN  <= 0;
        AGNUS_CYCLE_START <= 0;
        REG_WRITE_CYCLE <= 0;
        REG_READ_CYCLE <= 0;
        REG_CYCLE  <= 0;
        AGNUS_TACK  <= 0;
        DELAY_COUNT <= 4'h0;
        AGNUS_STATE <= 4'h0;
    end else begin

        if (CYCLE_ASSERT) begin AGNUS_CYCLE_START <= 1; end

        case (AGNUS_STATE)
            4'h0 : begin
                if (C1_SYNC[1] && C3_SYNC[1]) begin //Wait for STATE 1
                    if (AGNUS_CYCLE_START) begin
                        AGNUS_CYCLE_START <= 0;
                        PRWn <= RnW;
                        REG_WRITE_CYCLE <= !RnW;
                        REG_READ_CYCLE <= !REGSPACEn && RnW;
                        DELAY_COUNT <= 4'h0;
                        AGNUS_STATE <= 4'h1;
                    end
                end
            end
            4'h1 : begin
                if (!C1_SYNC[1] && C3_SYNC[1]) begin //Wait for STATE 2.
                    RAMENn <= RAMSPACEn;
                    REGENn <= REGSPACEn;
                    ASn   <= 0;
                    UDSn  <= !(UDS);
                    LDSn  <= !(LDS);
                    BLSn  <= 0;
                    AGNUS_STATE <= 4'h2;
                end
            end
            4'h2 : begin
                if (C1_SYNC[1] && !C3_SYNC[1]) begin //Wait for STATE 4.
                    if (DBRn_SYNC[1]) begin
                        VB_EN <= 1;
                        REG_CYCLE <= !REGSPACEn;
                        AGNUS_STATE <= 4'h3;
                    end
                end
            end

            4'h3 : begin
                DELAY_COUNT ++;
                if ((REG_READ_CYCLE && (DELAY_COUNT == READ_TACK_DELAY)) || DELAY_COUNT == TACK_DELAY) begin
                    AGNUS_TACK <= 1;
                    AGNUS_STATE <= 4'h4;
                end
            end

            4'h4 : begin
                AGNUS_TACK <= 0;
                DELAY_COUNT <= 4'h0;
                AGNUS_STATE <= 4'h5;
            end

            4'h5 : begin
                AGNUS_STATE <= 4'h6;
            end

            4'h6 : begin
                if ((REG_READ_CYCLE && (END_CYCLE_DELAY == DELAY_COUNT)) || !REG_READ_CYCLE) begin
                    UDSn   <= 1;
                    LDSn   <= 1;
                    ASn    <= 1;
                    REG_CYCLE  <= 0;
                    REGENn <= 1;
                    RAMENn <= 1;
                    BLSn  <= 1;
                    PRWn  <= 1;
                    VB_EN <= 0;
                    AGNUS_STATE <= 4'h0;
                end else begin
                    DELAY_COUNT ++;
                end
            end
        endcase
    end
end

endmodule
