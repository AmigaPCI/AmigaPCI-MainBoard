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
Module Name: U409_TOP
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: ADDRESS DECODE, ROM, TRANSFER ACK, AUTOCONFIG

See individual modules for revision history.

GitHub: https://github.com/jasonsbeer/AmigaPCI

iceprog D:\AmigaPCI\U409\U409_icecube\U409_icecube_Implmnt\sbt\outputs\bitmap\U409_TOP_bitmap.bin
*/

module U409_TOP (

    //Clocks
    input  CLK40_IN, CLK28_IN, XCLK, XCLK_ENn, RESETn,
    output AGNUS_CLK, TICK60, TICK50, CLK_CIA, 
    
    //Cycle Start/Termination    
    input  TSn, OVL, RnW, TEAn,
    output TBIn, TCIn,
    input [1:0] TT,
    inout TACKn,

    //Data and Address Bus    
    input [31:1] A,
    //inout [7:4] D,

    //Chip Selects/Address Spaces
    output ROM_ENn, CIACS0n, CIACS1n, RAMSPACEn, REGSPACEn, RTC_ENn, PORTSIZE,
    output BUF_ENn,
    
    //Configuration Signals
    //input PCI_CONFIGUREDn
    input [1:0] ROM_DELAY,    
    output CONFIGENn, CPUCONFn,

    //PCI
    input BRIDGE_ENn,
    //output [1:0] PCIAT,

    //ATA
    input AUTOBOOT, SPIO_J, PPIO_J,
    output PCS0, PCS1, SCS0, SCS1, PPIO, SPIO, ATA_ENn,

    //Flash
    input  FLASH_DISJn,
    output FLASH_ENn, FLASH_READn, FLASH_WRITEn, FLASH_WPn, FLASH_RSTn,
    output [1:0] FLASH_BANK

);

//////////////////
// AGNUS CLOCK //
////////////////

//Agnus is clocked by the oscillator at X3 unless XCLK is enabled by a video device.
//In that case, pass the XCLK signal instead.

assign AGNUS_CLK = XCLK_ENn ? CLK28_IN : XCLK;

///////////////////
// SIGNAL WIRES //
/////////////////

wire CLK40;
//wire AUTOCONFIG_SPACE;
wire AUTOVECTOR;
wire CIA_SPACE;
wire CIA_ENABLE;
wire FLASH_TACK;
wire FLASH_SPACE;
wire RTC_TACK;
wire RTC_SPACE;
wire ROM_SPACE;
//wire CONFIGURED;
wire AGNUS_SPACE;

//wire [7:1] LIDE_BASE;
//wire [3:0] PRO_BASE;
//wire [3:0] D_OUT;
//wire [3:0] D_IN = AUTOCONFIG_SPACE && !RnW ? D[7:4] : 4'h0;

assign BUF_ENn = !((!ROM_SPACE && !CIA_SPACE && !RTC_SPACE) && (AGNUS_SPACE || ATA_SPACE || FLASH_SPACE || !BRIDGE_ENn));
assign PORTSIZE = CIA_SPACE || !REGSPACEn || RTC_SPACE || ATA_SPACE || FLASH_SPACE;
//assign BUF_ENn = !(AGNUS_SPACE || AUTOCONFIG_SPACE || ATA_SPACE || FLASH_SPACE || !BRIDGE_ENn);
//assign PORTSIZE = CIA_SPACE || !REGSPACEn || RTC_SPACE || AUTOCONFIG_SPACE || ATA_SPACE || FLASH_SPACE;
//assign D = AUTOCONFIG_SPACE && RnW ? D_OUT : 4'bz;
//assign CONFIGENn = !(CONFIGURED); //Signal PCI bridge to start autoconfig
assign CONFIGENn = 0;
assign CPUCONFn  = 1; //!(!CONFIGURED && !PCI_CONFIGUREDn); //Signal local bus card to start autoconfig

//////////////
// BUFFERS //
////////////

//Enable the level shifting buffers when we are in the LVTTL space.
/*wire LV_SPACE = ((!ROM_SPACE && !CIA_SPACE && !RTC_SPACE) && (AGNUS_SPACE || ATA_SPACE || FLASH_SPACE || !BRIDGE_ENn));
always @(posedge CLK40) begin
    if (!RESETn) begin
        BUF_ENn <= 1;
    end else begin
        if (!TSn && LV_SPACE) begin
            BUF_ENn <= 0;
        end else if (!LV_SPACE) begin
            BUF_ENn <= 1;
        end
    end
end*/

///////////////////////
// TRANSFER ACK TOP //
/////////////////////

U409_TRANSFER_ACK U409_TRANSFER_ACK (
    //INPUTS
    .CLK40_IN (CLK40_IN),
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .TSn (TSn),
    .TEAn (TEAn),
    .ROM_SPACE (ROM_SPACE),
    .CIA_ENABLE (CIA_ENABLE),
    .CLK_CIA (CLK_CIA),
    .AGNUS_SPACE (AGNUS_SPACE),
    .AUTOVECTOR (AUTOVECTOR),
    //.AC_TACK (AC_TACK),
    .ROM_DELAY (ROM_DELAY),
    .FLASH_TACK (FLASH_TACK),
    .RTC_TACK (RTC_TACK),

    //OUTPUTS
    .TBIn (TBIn),
    .TCIn (TCIn),
    .ROM_ENn (ROM_ENn),

    //INOUTS
    .TACKn (TACKn)
);

/////////////////////////
// ADDRESS DECODE TOP //
///////////////////////

U409_ADDRESS_DECODE U409_ADDRESS_DECODE (
    //INPUTS
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .RnW (RnW),
    .OVL (OVL),
    .CIA_ENABLE (CIA_ENABLE),
    //.CONFIGURED (CONFIGURED),
    .TT (TT),
    .A (A[31:12]),
    //.LIDE_BASE (LIDE_BASE),
    .AUTOBOOT (AUTOBOOT),
    .FLASH_DISJn (FLASH_DISJn),

    //OUTPUTS
    .ROM_SPACE (ROM_SPACE),
    .CIA_SPACE (CIA_SPACE),
    .CIACS0n (CIACS0n),
    .CIACS1n (CIACS1n),
    .RAMSPACEn (RAMSPACEn),
    .REGSPACEn (REGSPACEn),
    .AGNUS_SPACE (AGNUS_SPACE),
    .AUTOVECTOR (AUTOVECTOR),
    .RTC_SPACE (RTC_SPACE),
    //.AUTOCONFIG_SPACE (AUTOCONFIG_SPACE),
    .ATA_SPACE (ATA_SPACE),
    .ATA_ENn (ATA_ENn),
    .PCS0 (PCS0),
    .PCS1 (PCS1),
    .SCS0 (SCS0),
    .SCS1 (SCS1),
    //.PCIAT (PCIAT),
    //.BRIDGE_ENn (BRIDGE_ENn),
    .FLASH_BANK (FLASH_BANK),
    .FLASH_SPACE (FLASH_SPACE)
);

/////////////////////
// TICK CLOCK TOP //
///////////////////

U409_TICK U409_TICK (
    //Inputs
    .CLK28_IN (CLK28_IN),

    //Outputs
    .TICK60 (TICK60),
    .TICK50 (TICK50)
);

////////////////////
// CIA CLOCK TOP //
//////////////////

U409_CIA U409_CIA (
    .CLK28_IN (CLK28_IN),
    .RESETn (RESETn),
    .CIA_SPACE (CIA_SPACE),
    .CLK_CIA (CLK_CIA),
    .CIA_ENABLE (CIA_ENABLE)
);

/////////////////
// AUTOCONFIG //
///////////////

/*U409_AUTOCONFIG U409_AUTOCONFIG (
    //INPUT
    .CLK40,
    .RESETn,
    .AUTOCONFIG_SPACE (AUTOCONFIG_SPACE),
    .RnW (RnW),
    .TSn (TSn),
    .AUTOBOOT (AUTOBOOT),
    .D_IN (D_IN),
    .A (A[7:1]),

    //OUTPUT
    //.BRIDGE_BASE (BRIDGE_BASE),
    .LIDE_BASE (LIDE_BASE),
    //.PRO_BASE (PRO_BASE),
    .D_OUT (D_OUT),
    .CONFIGURED (CONFIGURED),
    .AC_TACK (AC_TACK)
);*/

////////////
// FLASH //
//////////

U409_FLASH U409_FLASH (
    //INPUT
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .TSn (TSn),
    .RnW (RnW),
    .FLASH_SPACE (FLASH_SPACE),

    //OUTPUTS
    .FLASH_ENn (FLASH_ENn),
    .FLASH_WPn (FLASH_WPn),
    .FLASH_READn (FLASH_READn),
    .FLASH_WRITEn (FLASH_WRITEn),
    .FLASH_RSTn (FLASH_RSTn),
    .FLASH_TACK (FLASH_TACK)
);

//////////
// RTC //
////////

U409_RTC_SM U409_RTC_SM (
    //input
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .TSn (TSn),
    .RTC_SPACE (RTC_SPACE), 

    //output
    .RTC_ENn (RTC_ENn),
    .RTC_TACK (RTC_TACK)
);

////////////////
// ATA STUFF //
//////////////

//Pass through the ATA PIO jumper settings
assign PPIO = PPIO_J;
assign SPIO = SPIO_J;

//////////
// PLL //
////////

wire CLK40_PAD = CLK40_IN;

SB_PLL40_CORE #(
    .DIVR (4'b0000),
    .DIVF (7'b0000000),
    .DIVQ (3'b100),
    .FILTER_RANGE (3'b011),
    .FEEDBACK_PATH ("PHASE_AND_DELAY"),
    .DELAY_ADJUSTMENT_MODE_FEEDBACK ("FIXED"),
    .FDA_FEEDBACK   (4'b0000),
    //.DELAY_ADJUSTMENT_MODE_RELATIVE ("FIXED"),
    //.FDA_RELATIVE   (4'b0000),
    .PLLOUT_SELECT ("SHIFTREG_0deg"),
    .SHIFTREG_DIV_MODE (1'b0)
) pll (
    .LOCK           (),
    .RESETB         (1'b1),
    .REFERENCECLK   (CLK40_PAD),
    .PLLOUTGLOBAL   (CLK40),
    
    .EXTFEEDBACK       (1'b0),
    .DYNAMICDELAY      (8'b00001111),
    .BYPASS            (1'b0),
    .SDI               (1'b0),
    .SCLK              (1'b0),
    .LATCHINPUTVALUE   (1'b0)
);

endmodule
