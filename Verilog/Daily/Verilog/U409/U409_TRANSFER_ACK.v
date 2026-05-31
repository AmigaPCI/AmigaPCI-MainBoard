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
Design Name: U409
Module Name: U409_TRANSFER_ACK
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: MC68040/MC68060 TRANSFER ACK

Date          Who  Description
-----------------------------------
01-JUL-2025   JN   INITIAL REV 6.0 CODE
14-SEP-2025   JN   Added ROM delay and improved _TACK timing.
22-SEP-2025   JN   Added RTC termination.
11-OCT-2025   JN   Fixed erroneous assertion of RTC termination.
18-OCT-2025   JN   Moved RTC to dedicated module.
05-NOV-2025   JN   Changed ROM timing options to support Kicksmash.
07-NOV-2025   JN   Modified ROM state machine.
14-NOV-2025   JN   Modified slowest ROM timing from 250 to 275ns.
24-NOV-2025   JN   Added _TEA to cycle timeout reset.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U409_TRANSFER_ACK (

    //Clocks
    input CLK40_IN, CLK40, CLK_CIA, RESETn,
    
    //Cycle Start/Termination
    input TSn,
    output reg TACK_EN,
    inout TACKn,

    //Address Spaces
    input AGNUS_SPACE, AUTOVECTOR, //CIA_ENABLE,
    
    //External TACK Enables
    input RTC_TACK_EN, FLASH_TACK, ROM_TACK_EN, CIA_TACK_EN

);

///////////////////////////
// MC68040 TRANSFER ACK //
/////////////////////////

assign TACKn = TACK_EN ? TACK_OUT : 1'bz;

wire TACK_START = (ROM_TACK_EN || RTC_TACK_EN || IRQ_TACK_EN || CIA_TACK_EN || DELAYED_TACK_EN || FLASH_TACK);

reg TACK_OUT;
reg [3:0] TACK_STATE;

always @(posedge CLK40_IN) begin
    if (!RESETn) begin
        TACK_EN <= 1'b0;
        TACK_OUT <= 1'b1;
        TACK_STATE <= 4'h0;
    end else begin
        case (TACK_STATE)
            4'h0 : begin
                if (TACK_START) begin
                    TACK_EN  <= 1'b1;
                    TACK_OUT <= 1'b0;
                    TACK_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                TACK_OUT <= 1'b1;
                TACK_STATE <= 4'h2;
            end
            4'h2 : begin
                TACK_EN <= 1'b0;
                TACK_STATE <= 4'h0;
            end
        endcase
    end
end

////////////////
// IRQ CYCLE //
//////////////

//The AmigaPCI only supports autovectoring, which is how all Amiga's are.
//No data is actually transfered, so we ack interrupt acknowledge cycles after two clocks.

reg IRQ_TACK_EN;
reg [1:0] IRQ_TACK_COUNTER;

always @(posedge CLK40) begin
    if (!RESETn) begin
        IRQ_TACK_COUNTER <= 2'b0;
        IRQ_TACK_EN <= 0;
    end else begin
        case (IRQ_TACK_COUNTER)
            2'b00 : begin
                if (!TSn && AUTOVECTOR) begin
                    IRQ_TACK_COUNTER <= 2'b01;
                end
            end
            2'b01 : begin
                IRQ_TACK_EN <= 1;
                IRQ_TACK_COUNTER <= 2'b10;
            end
            2'b10 : begin
                IRQ_TACK_EN <= 0;
                IRQ_TACK_COUNTER <= 2'b00;
            end
        endcase
    end
end

/*always @(posedge CLK40) begin
    if (!RESETn) begin
        IRQ_TACK_COUNTER <= 2'b0;
        IRQ_TACK_EN <= 0;
    end else begin
        case (IRQ_TACK_COUNTER)
            2'b00 : begin
                if (!TSn && AUTOVECTOR) begin
                    IRQ_TACK_COUNTER <= 2'b01;
                end
            end
            2'b01 : begin
                IRQ_TACK_COUNTER <= 2'b10;
            end
            2'b10 : begin
                IRQ_TACK_EN <= 1;
                IRQ_TACK_COUNTER <= 2'b11;
            end
            2'b11 : begin
                IRQ_TACK_EN <= 0;
                IRQ_TACK_COUNTER <= 2'b00;
            end
        endcase
    end
end*/

//////////////////////////
// UNRESPONSIVE CYCLES //
////////////////////////

//END THE CYCLE WHEN THE CPU LOOKS FOR AN ADDRESS WE DON'T EXPLICITLY SUPPORT.
//CIA CYCLES ARE THE LONGEST CYCLES WE SUPPORT, WHICH TAKE ~1us. WE WAIT ABOUT 3us
//AND THEN ASSERT _TACK OURSELVES.

//Because of the potential length of time Agnus can hold the bus, we do not
//apply the unresponsive count to chip ram or register cycles.

localparam DELAYED_TACK_DELAY = 7'd125;

reg [6:0] DELAYED_TACK_COUNTER;
reg [1:0] DELAYED_TACK_STATE;
reg DELAYED_TACK_EN;

wire TACKn_INT = TACK_EN ? TACK_OUT : TACKn;
wire DELAYED_TACK_RST = (!TACKn_INT || !RESETn || AGNUS_SPACE);
    
always @(posedge CLK40, posedge DELAYED_TACK_RST) begin
    if (DELAYED_TACK_RST) begin
        DELAYED_TACK_EN <= 0;
        DELAYED_TACK_STATE <= 2'b0;
        DELAYED_TACK_COUNTER <= 7'b0;
    end else begin

        case (DELAYED_TACK_STATE)
            2'b00 : begin
                if (!TSn) begin
                    DELAYED_TACK_COUNTER <= 7'd1;
                    DELAYED_TACK_STATE <= 2'b01;
                end
            end
            2'b01 : begin
                if (DELAYED_TACK_COUNTER == DELAYED_TACK_DELAY) begin
                    DELAYED_TACK_EN <= 1;
                    DELAYED_TACK_STATE <= 2'b10;
                end else begin
                    DELAYED_TACK_COUNTER <= DELAYED_TACK_COUNTER + 1;
                end
            end
            2'b10 : begin
                DELAYED_TACK_EN <= 0;
                DELAYED_TACK_COUNTER <= 7'b0;
                DELAYED_TACK_STATE <= 2'b00;
            end
        endcase
    end
end

endmodule