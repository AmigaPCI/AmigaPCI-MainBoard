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
Module Name: U712_TOP
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: U712 AMIGA PCI FPGA. Provides MC68000 compatable cycles for chip ram and chip set register access.

See individual modules for revision history.

GitHub: https://github.com/jasonsbeer/AmigaPCI

iceprog D:\AmigaPCI\U712\U712_icecube\U712_icecube_Implmnt\sbt\outputs\bitmap\U712_TOP_bitmap.bin
*/

module U712_TOP

(
    //CLOCKS
    input CLK40_IN, CLK7, C1, C3, RESETn,
    output CLK40B_OUT, CLK40C_OUT, CLK40D_OUT, CLK40n_OUT, CLKRAM,

    //AGNUS
    input DBRn, RAMSPACEn, REGSPACEn, AWEn, CASLn, CASUn, RAS1n, RAS0n, AGNUS_REV,
    input [9:0] DRA,
    output DRD_ENn, DRD_DIR, REGENn, RAMENn, UDSn, LDSn, ASn, BLSn, PRWn, VBENn, SAB_LATCH_EN, SAB_LATCH_CLK,

    //CYCLE START/TERMINATION
    input RnW, TSn,
    output TACKn, TCIn, TBIn,

    //BYTE ENABLES
    input [1:0] A, SIZ,
    output CUUBEn, CUMBEn, CLMBEn, CLLBEn, UUBEn, UMBEn, LMBEn, LLBEn,

    //SDRAM
    output BANK1, BANK0, SDRAM_CSn, RASn, CASn, WEn, CLK_EN, DB_ENn, DB_DIR,
    output [10:0] CMA,

    //ATA
    input  [2:0] ATA_A,
    output [2:0] ATA_AB

);

/////////////////////
// INTERNAL WIRES //
///////////////////

wire
    AGNUS_TACK,
    UDS,
    LDS,
    REG_CYCLE,
    REG_WRITE_CYCLE,
    CPU_CYCLE,
    DMA_CYCLE,
    CLK40_PLL,
    DMA_WRITE_CYCLE;

wire CLK40 = !CLK40_PLL;
wire CLK40_PAD = CLK40_IN;

///////////////////
// OUTPUT WIRES //
/////////////////

assign DRD_ENn = !(REG_CYCLE || DMA_CYCLE);
assign DRD_DIR = !((REG_CYCLE && !REG_WRITE_CYCLE) || (DMA_CYCLE && DMA_WRITE_CYCLE)); //REG READS & DMA WRITES = 0, REG WRITES & DMA READS = 1
assign CLK40B_OUT = !CLK40_PLL;
assign CLK40C_OUT = !CLK40_PLL;
assign CLK40D_OUT = !CLK40_PLL;
assign CLK40n_OUT =  CLK40_PLL;
assign CLKRAM     = !CLK40_PLL;

//////////////////////////
// AGNUS STATE MACHINE //
////////////////////////

U712_AGNUS_SM U712_AGNUS_SM
(
    //input
        .CLK40 (CLK40),
        .C1 (C1),
        .C3 (C3),
        .RESETn (RESETn),
        .RnW (RnW),
        .DBRn (DBRn),
        .RAMSPACEn (RAMSPACEn),
        .REGSPACEn (REGSPACEn),
        .TSn (TSn),
        .UDS (UDS),
        .LDS (LDS),

    //output
        .REG_CYCLE (REG_CYCLE),
        .REG_WRITE_CYCLE (REG_WRITE_CYCLE),
        .REGENn (REGENn),
        .RAMENn (RAMENn),
        .UDSn (UDSn),
        .LDSn (LDSn),
        .ASn (ASn),
        .BLSn (BLSn),
        .PRWn (PRWn),
        .VBENn (VBENn),
        .AGNUS_TACK (AGNUS_TACK)
);

////////////////////////
// CYCLE TERMINATION //
//////////////////////

U712_CYCLE_TERMINATION U712_CYCLE_TERMINATION
(
    //input
        .CLK40 (CLK40),
        .RESETn (RESETn),
        .AGNUS_TACK (AGNUS_TACK),

    //output
        .TACKn (TACKn),
        .TCIn (TCIn),
        .TBIn (TBIn) 
);

///////////////////
// BYTE ENABLES //
/////////////////

U712_BYTE_ENABLE U712_BYTE_ENABLE (

    //input
        .CPU_CYCLE (CPU_CYCLE),
        .DMA_CYCLE (DMA_CYCLE),
        .CASLn (CASLn),
        .CASUn (CASUn),
        .DB_ENn (DB_ENn),
        .RnW (RnW),
        .A (A),
        .SIZ (SIZ),

    //output
        .CUUBEn (CUUBEn),
        .CUMBEn (CUMBEn),
        .CLMBEn (CLMBEn),
        .CLLBEn (CLLBEn),
        .UUBEn (UUBEn),
        .UMBEn (UMBEn),
        .LMBEn (LMBEn),
        .LLBEn (LLBEn),
        .UDS (UDS),
        .LDS (LDS)
);

/////////////////////////////
// CHIP RAM STATE MACHINE //
///////////////////////////

U712_CHIP_RAM_SM U712_CHIP_RAM_SM
(
    //input
    .CLK40 (CLK40),
    .CLK7 (CLK7),
    .C1 (C1),
    .C3 (C3),     
    .RESETn (RESETn),
    .DBRn (DBRn),
    .AWEn (AWEn),
    .RAS1n (RAS1n),
    .RAS0n (RAS0n),
    .AGNUS_REV (AGNUS_REV),
    .DRA (DRA),
    
    //Output
    .BANK1 (BANK1),
    .BANK0 (BANK0),
    .CLK_EN (CLK_EN),
    .SDRAM_CSn (SDRAM_CSn),
    .RASn (RASn),
    .CASn (CASn),
    .WEn (WEn),
    .CMA (CMA),
    .DB_ENn (DB_ENn),
    .DB_DIR (DB_DIR),
    .SAB_LATCH_EN (SAB_LATCH_EN),
    .SAB_LATCH_CLK (SAB_LATCH_CLK),
    .CPU_CYCLE (CPU_CYCLE),
    .DMA_CYCLE (DMA_CYCLE),
    .WRITE_CYCLE (DMA_WRITE_CYCLE)
);

//////////////////
// ATA ADDRESS //
////////////////

//Connect address signals 11:9 to ATA address bits 2:0.

assign ATA_AB = ATA_A;

//////////
// PLL //
////////

//WE GENERATE THE 40MHz CLOCKS HERE BASED ON THE CLK40_IN CLOCK SIGNAL FROM THE LOCAL BUS CARD.
//WE DISTRIBUTE THE CLOCKS FROM THE PLL TO OTHER DEVICES ON THE AMIGAPCI. SINCE THIS PLL INVERTS THE CLOCK SIGNAL,
//WE PHASE MATCH IT BEFORE PUTTING THE SIGNAL OUT.

APCI_U712_4040_pll APCI_U712_4040_pll_inst(.PACKAGEPIN(CLK40_PAD),
                                           .PLLOUTCORE(),
                                           .PLLOUTGLOBAL(CLK40_PLL),
                                           .RESET(1'b1));

//Effect of FDA_FEEDBACK value
//0  = Almost exact peak match
//7  = ~2ns early peak
//15 = ~4ns early peak

/*SB_PLL40_CORE #(
    .DIVR (4'b0000),
    .DIVF (7'b0000000),
    .DIVQ (3'b100),
    .FILTER_RANGE (3'b011),
    .FEEDBACK_PATH ("DELAY"),
    .DELAY_ADJUSTMENT_MODE_FEEDBACK ("FIXED"),
    .FDA_FEEDBACK   (4'b1111),
    .DELAY_ADJUSTMENT_MODE_RELATIVE ("FIXED"),
    .FDA_RELATIVE   (4'b0000),
    .PLLOUT_SELECT ("GENCLK")
) pll (
    .LOCK           (),
    .RESETB         (1'b1),
    .REFERENCECLK   (CLK40_PAD),
    .PLLOUTGLOBAL   (CLK40_PLL),

    .EXTFEEDBACK       (1'b0),
    .DYNAMICDELAY      (8'b00000000),
    .BYPASS            (1'b0),
    .SDI               (1'b0),
    .SCLK              (1'b0),
    .LATCHINPUTVALUE   (1'b0)
);*/

endmodule