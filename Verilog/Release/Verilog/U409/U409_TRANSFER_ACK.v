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
    //input CLK40_IN, CLK40, CLK_CIA, RESETn,
    input CLK40, CLK_CIA, RESETn,
    
    //Cycle Start/Termination
    input TSn, //TEAn, //AC_TACK,
    output TBIn, TCIn,
    inout TACKn,

    //Address Spaces
    input ROM_SPACE, CIA_ENABLE, AGNUS_SPACE, AUTOVECTOR, BRIDGE_ENn,
    output reg ROM_ENn,
    
    //External TACK Enables
    input RTC_TACK, FLASH_TACK,

    //ROM
    input [1:0] ROM_DELAY
);

///////////////////////////
// MC68040 TRANSFER ACK //
/////////////////////////

//None of the U409 cycles support burst, so all cycles are terminated with a burst inhibit.
//The cycle termination signals come out a little early here to account for
//latency in any downstream logic. This timing may not work 100% of the time if connected directly
//to the CPU.

reg TACK_EN;
reg TACK_OUT;

assign TACKn = TACK_EN ? TACK_OUT : 1'bz;
assign TBIn  = TACK_EN ? TACK_OUT : 1'bz;
assign TCIn  = TACK_EN ? (ROM_ENn ? TACK_OUT : 1'b1) : 1'bz;

reg [3:0] TACK_STATE;
//always @(posedge CLK40_IN) begin
always @(posedge CLK40) begin
    if (!RESETn) begin
        TACK_EN <= 0;
        TACK_OUT <= 1;
        TACK_STATE <= 4'h0;
    end else begin
        case (TACK_STATE)
            4'h0 : begin
                //if (ROM_TACK_EN || RTC_TACK || IRQ_TACK_EN || AC_TACK || CIA_TACK_EN || DELAYED_TACK_EN || FLASH_TACK) begin
                if (ROM_TACK_EN || RTC_TACK || IRQ_TACK_EN || CIA_TACK_EN || DELAYED_TACK_EN || FLASH_TACK) begin
                    TACK_EN  <= 1;
                    TACK_OUT <= 0;
                    TACK_STATE <= 4'h1;
                end
            end
            4'h1 : begin
                TACK_OUT <= 1;
                TACK_STATE <= 4'h2;
            end
            4'h2 : begin
                TACK_EN <= 0;
                TACK_STATE <= 4'h0;
            end
        endcase
    end
end

////////////////
// ROM CYCLE //
//////////////

//We support multiple timing options for ROM cycle termination.
//The exact timing is user selected by jumpers on the APCI board.

localparam [3:0] ROM_DELAY_275 = 4'h8; //275ns
localparam [3:0] ROM_DELAY_200 = 4'h5; //200ns
localparam [3:0] ROM_DELAY_150 = 4'h3; //150ns
localparam [3:0] ROM_DELAY_100 = 4'h1; //100ns

wire [1:0] DELAY_275 = ROM_DELAY == 2'b11;
wire [1:0] DELAY_200 = ROM_DELAY == 2'b10;
wire [1:0] DELAY_150 = ROM_DELAY == 2'b01;
wire [1:0] DELAY_100 = ROM_DELAY == 2'b00;

reg [1:0] ROM_TACK_STATE;
reg [3:0] ROM_TACK_COUNTER;
reg ROM_TACK_EN;
always @(posedge CLK40) begin
    if (!RESETn) begin
        ROM_TACK_EN <= 0;
        ROM_TACK_COUNTER <= 4'h0;
        ROM_TACK_STATE <= 2'b00;
        ROM_ENn <= 1;
    end else begin
        case (ROM_TACK_STATE)
            2'b00 : begin
                if (!TSn && ROM_SPACE) begin
                    ROM_TACK_STATE <= 2'b01;
                    ROM_ENn <= 0;
                end else begin
                    ROM_ENn <= 1;
                end
            end
            2'b01 : begin
                if ((ROM_TACK_COUNTER == ROM_DELAY_100 && DELAY_100) ||
                    (ROM_TACK_COUNTER == ROM_DELAY_150 && DELAY_150) ||
                    (ROM_TACK_COUNTER == ROM_DELAY_200 && DELAY_200) ||
                    (ROM_TACK_COUNTER == ROM_DELAY_275 && DELAY_275)) begin
                    ROM_TACK_EN <= 1;
                    ROM_TACK_STATE <= 2'b10;
                end else begin
                    ROM_TACK_COUNTER ++;
                end
            end
            2'b10 : begin
                ROM_TACK_EN <= 0;
                ROM_TACK_STATE <= 2'b11;
            end
            2'b11 : begin
                ROM_TACK_COUNTER <= 4'h0;
                ROM_TACK_STATE <= 2'b00;
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

///////////////////////
// CIA TRANSFER ACK //
/////////////////////

//CYCLE TERMINATION FOR CIA CYCLES MUST OCCUR AT OR JUST AFTER THE
//FALLING EDGE OF THE CIA CLOCK WHILE THE CHIP SELECT IS ENABLED.

reg [1:0] LASTCLK, CIA_ENABLED, CIA_STATE;
reg CIA_TACK_EN;

always @(posedge CLK40) begin
    if (!RESETn) begin
        CIA_TACK_EN <= 0;
        LASTCLK     <= 2'b00;
        CIA_ENABLED <= 2'b00;
        CIA_STATE   <= 2'b00;
    end else begin
        LASTCLK[1] <= LASTCLK[0];
        LASTCLK[0] <= CLK_CIA;

        CIA_ENABLED[1] <= CIA_ENABLED[0];
        CIA_ENABLED[0] <= CIA_ENABLE;

        case (CIA_STATE)
            2'b00 : begin
                if (CIA_ENABLED[1]) CIA_STATE <= 2'b01;
            end
            2'b01 : begin
                if (LASTCLK[1]) CIA_STATE <= 2'b10;
            end
            2'b10 : begin
                if (!LASTCLK[1]) begin
                    CIA_TACK_EN <= 1;
                    CIA_STATE <= 2'b11;
                end
            end
            2'b11 : begin
                CIA_TACK_EN <= 0;
                if (!CIA_ENABLED[1]) begin
                    CIA_STATE <= 2'b00;
                end
            end
        endcase
    end
end

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
    
wire DELAYED_TACK_RST = (!TACKn || !RESETn || AGNUS_SPACE || !BRIDGE_ENn); // || !TEAn;
    
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
                    DELAYED_TACK_COUNTER ++;
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
