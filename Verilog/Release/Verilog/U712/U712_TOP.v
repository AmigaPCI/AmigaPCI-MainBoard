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

Description: U712 AMIGA PCI REV 7.x FPGA. Provides MC68000 compatable cycles for chip ram and chip set register access.

See individual modules for revision history.

GitHub: https://github.com/jasonsbeer/AmigaPCI

iceprog D:\AmigaPCI\U712\APCI_U712\APCI_U712_Implmnt\sbt\outputs\bitmap\U712_TOP_bitmap.bin
*/

module U712_TOP

(
    //CLOCKS
    input CLK40_IN, CLK7, CDAC, C1, C3, RESETn,
    output CLK40B_OUT, CLK40C_OUT, CLK40D_OUT, CLK40n_OUT, CLKRAM,

    //AGNUS
    input DBRn, RAMSPACEn, REGSPACEn, AWEn, CASLn, CASUn, RAS1n, RAS0n, AGNUS_REV,
    input [9:0] DRA,
    output DRD_ENn, DRD_DIR, REGENn, RAMENn, UDSn, LDSn, ASn, BLSn, PRnW, VBENn,

    //CYCLE START/TERMINATION
    input RnW, TSn,
    output TACKn,

    //BYTE ENABLES
    input [1:0] A, SIZ,
    output CUUBEn, CUMBEn, CLMBEn, CLLBEn, UUBEn, UMBEn, LMBEn, LLBEn,

    //SDRAM
    output BANK1, BANK0, SDRAM_CSn, RASn, CASn, WEn, CLK_EN, DB_ENn, DB_DIR,
    output [10:0] CMA,

    //ATA
    input  [2:0] ATA_A,
    output [2:0] ATA_AB

    ,output TP0
    ,output TP1

);

assign TP0 = (RAS0n != RAS1n);
//assign TP1 = (!CASUn || ! CASLn);
assign TP1 = DB_ENn;

/////////////////////
// INTERNAL WIRES //
///////////////////

wire
    UDS,
    LDS,
    REG_CYCLE,
    AGNUS_WRITE_CYCLE,
    CPU_CYCLE,
    DMA_CYCLE,
    CLK40_PLL,
    DMA_WRITE_CYCLE;

wire CLK40_PAD = CLK40_IN;

///////////////////
// OUTPUT WIRES //
/////////////////

assign DRD_ENn = ~(REG_CYCLE || DMA_CYCLE);
assign DRD_DIR = ~((REG_CYCLE  && !AGNUS_WRITE_CYCLE) || (DMA_CYCLE && DMA_WRITE_CYCLE)); //REGESTER READS & DMA WRITES = 0, REG WRITES & DMA READS = 1

/////////////
// CLOCKS //
///////////

//The 14MHz clock has a rising edge on every 7MHz edge.
wire CLK14 = ~(CLK7 ^ CDAC); //XNOR

//The PLL shifts the output clock 180 degrees from the input clock.
//So we shift it 180 degrees to realign it with the input clock.

wire CLK40 = ~CLK40_PLL;

assign CLK40B_OUT = ~CLK40_PLL;
assign CLK40C_OUT = ~CLK40_PLL;
assign CLK40D_OUT = ~CLK40_PLL;
assign CLK40n_OUT =  CLK40_PLL;
assign CLKRAM     = ~CLK40_PLL;

//////////////////////////
// AGNUS STATE MACHINE //
////////////////////////

U712_AGNUS_CYCLE U712_AGNUS_CYCLE
(
    //Clocks
    .CLK40 (CLK40),
    //.CLK7 (CLK7),
    //.CDAC (CDAC),
    .CLK14 (CLK14),
    .C1 (C1),
    .C3 (C3),

    //Inputs
    .RESETn (RESETn),
    .TSn (TSn),
    .RnW (RnW),
    .REGSPACEn (REGSPACEn),
    .RAMSPACEn (RAMSPACEn),
    .DBRn (DBRn),
    .UDS (UDS),
    .LDS (LDS),

    //Outputs
    .TACKn (TACKn),
    .VBENn (VBENn),
    .ASn (ASn),
    .UDSn (UDSn),
    .LDSn (LDSn),
    .PRnW (PRnW),
    .REGENn (REGENn), 
    .RAMENn (RAMENn),
    .BLSn (BLSn),
    .REG_CYCLE (REG_CYCLE),
    .AGNUS_WRITE_CYCLE (AGNUS_WRITE_CYCLE)

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

APCI_U712_4040_pll APCI_U712_4040_pll_inst(.PACKAGEPIN(CLK40_PAD),
                                           .PLLOUTCORE(),
                                           .PLLOUTGLOBAL(CLK40_PLL),
                                           .RESET(1'b1));
endmodule