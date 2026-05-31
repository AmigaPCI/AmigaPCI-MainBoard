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
    input  TSn, OVL, RnW, //TEAn,
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
    //output SPIO_J, PPIO_J,

    output PCS0, PCS1, SCS0, SCS1, PPIO, SPIO, ATA_ENn,

    //Flash
    input  FLASH_DISJn,
    output FLASH_ENn, FLASH_READn, FLASH_WRITEn, FLASH_WPn, FLASH_RSTn,
    output [1:0] FLASH_BANK

);

assign TBIn = (BRIDGE_ENn && !ATA_SPACE) ? 1'b0 : 1'bz;
//assign TCIn = (BRIDGE_ENn && !ATA_SPACE) ? 1'b0 : 1'bz; //No Caching Allowed
assign TCIn = ROM_SPACE ? 1'b1 : ((!BRIDGE_ENn && ATA_SPACE) ? 1'bz : 1'b0); //Cache the ROM space only

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
wire AUTOVECTOR;
wire FLASH_TACK;
wire FLASH_SPACE;
wire RTC_TACK_EN;
wire RTC_SPACE;
wire ROM_SPACE;
wire AGNUS_SPACE;
wire ROM_TACK_EN;
wire TACK_EN;
wire CIA_TACK_EN;
wire CIA0_SPACE;
wire CIA1_SPACE;
wire CIA_SPACE = (CIA0_SPACE || CIA1_SPACE);

assign BUF_ENn = !((!ROM_SPACE && !CIA_SPACE && !RTC_SPACE) && (AGNUS_SPACE || ATA_SPACE || FLASH_SPACE || !BRIDGE_ENn));
assign PORTSIZE = CIA_SPACE || !REGSPACEn || RTC_SPACE || ATA_SPACE || FLASH_SPACE;

//assign D = AUTOCONFIG_SPACE && RnW ? D_OUT : 4'bz;
//assign CONFIGENn = !(CONFIGURED); //Signal PCI bridge to start autoconfig
assign CONFIGENn = 0;
assign CPUCONFn  = 1; //!(!CONFIGURED && !PCI_CONFIGUREDn); //Signal local bus card to start autoconfig

////////////////
// ROM CYCLE //
//////////////

U409_ROM_CYCLE U409_ROM_CYCLE (
    //INPUTS
    .CLK40 (CLK40),
    .RESETn (RESETn),    
    .TSn (TSn),
    .TACK_EN (TACK_EN),
    .ROM_SPACE (ROM_SPACE),
    .ROM_DELAY (ROM_DELAY),

    //OUTPUTS
    .ROM_TACK_EN (ROM_TACK_EN),
    .ROM_ENn (ROM_ENn)
);

///////////////////////
// TRANSFER ACK TOP //
/////////////////////

U409_TRANSFER_ACK U409_TRANSFER_ACK (
    //INPUTS
    .CLK40_IN (CLK40_IN),
    .CLK40 (CLK40),
    .CLK_CIA (CLK_CIA),
    .RESETn (RESETn),
    .TSn (TSn),  
    .AGNUS_SPACE (AGNUS_SPACE),
    .AUTOVECTOR (AUTOVECTOR),
    .FLASH_TACK (FLASH_TACK),
    .RTC_TACK_EN (RTC_TACK_EN),
    .ROM_TACK_EN (ROM_TACK_EN),
    .CIA_TACK_EN (CIA_TACK_EN),

    //OUTPUT
    .TACK_EN (TACK_EN),

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
    .TT (TT),
    .A (A[31:12]),
    .AUTOBOOT (AUTOBOOT),
    .FLASH_DISJn (FLASH_DISJn),

    //OUTPUTS
    .ROM_SPACE (ROM_SPACE),
    .CIA0_SPACE (CIA0_SPACE),
    .CIA1_SPACE (CIA1_SPACE),
    .RAMSPACEn (RAMSPACEn),
    .REGSPACEn (REGSPACEn),
    .AGNUS_SPACE (AGNUS_SPACE),
    .AUTOVECTOR (AUTOVECTOR),
    .RTC_SPACE (RTC_SPACE),
    .ATA_SPACE (ATA_SPACE),
    .ATA_ENn (ATA_ENn),
    .PCS0 (PCS0),
    .PCS1 (PCS1),
    .SCS0 (SCS0),
    .SCS1 (SCS1),
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

//////////////////
// CIA CCYCLES //
////////////////

U409_CIA_CYCLE U409_CIA_CYCLE (
    //Inputs
    .CLK40 (CLK40),
    .CLK28 (CLK28_IN),
    .RESETn (RESETn),
    .RnW (RnW),
    .TSn (TSn),
    .CIA0_SPACE (CIA0_SPACE),
    .CIA1_SPACE (CIA1_SPACE),
    .TACK_EN (TACK_EN),

    //Outputs
    .CLK_CIA (CLK_CIA),
    .CIA_TACK_EN (CIA_TACK_EN),
    .CIACS0n (CIACS0n),
    .CIACS1n (CIACS1n)
    
);

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
    .RTC_TACK_EN (RTC_TACK_EN)
);

////////////////
// ATA STUFF //
//////////////

//Pass through the ATA PIO jumper settings
assign PPIO = PPIO_J;
assign SPIO = SPIO_J;

//assign PPIO = 1;
//assign SPIO = 1;

//assign PPIO_J = CIA_TACK_EN;
//assign PPIO_J = ROM_TACK_EN;
//assign PPIO_J = TP;
//assign SPIO_J = RAMSPACEn;

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
