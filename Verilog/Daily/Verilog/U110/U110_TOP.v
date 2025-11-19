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

Engineer: Jason Neus
Design Name: U110
Module Name: U110_TOP
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: U110 AMIGA PCI FPGA - PCI Bridge, ATA Controller, Bus Arbitor

See individual modules for revision history.

GitHub: https://github.com/jasonsbeer/AmigaPCI

iceprog D:\AmigaPCI\U110\APCI_U110\APCI_U110_Implmnt\sbt\outputs\bitmap\U110_TOP_bitmap.bin

NOTE:This one has the "slow" PLL!
*/

module U110_TOP (

    //Clocks
    input CLK40_IN, CLK33,
    
    //Cycle Start/Terminate
    input RESETn, TSn, RnW,
    input [1:0] SIZ,
    output TEAn, TACKn, TCIn, TBIn,
    
    //ATA Chip Selects
    input ATA_ENn, PPIO, SPIO, PCS1 , PCS0, SCS1, SCS0,
    output CS0_PRIn, CS1_PRIn, CS0_SECn, CS1_SECn, DIOR_PRIn, DIOW_PRIn, DIOR_SECn, DIOW_SECn,

    //ATA Buffers
    output IDELENn, IDEDIR, IDEHRENn, IDEHWENn, ATA_LATCH,

    //PCI 
    input BPRO_ENn, DEVSELn, TRDYn, PHASEA_D, PCI_TACK_ENn,
    input [1:0] PCIAT,
    output DEVSEL_OUTn,

    //Arbitor and Interrupts
    output INT2n, BUSDIR, BGn, BURSTn

    //,output TP0

);

////////////////////////////
// INTERNAL SIGNAL WIRES //
//////////////////////////

wire CLK40_PAD = CLK40_IN;
wire CLK40 = CLK40_PLL;

assign DEVSEL_OUTn = DEVSELn;

  ///////////////
 // INTERRUPT //
///////////////

U110_INTERRUPT U110_INTERRUPT (

    //output
    .INT2n (INT2n)

);

  ///////////////////////
 // CYCLE TERMINATION //
///////////////////////

wire ATA_TACK;
U110_CYCLE_TERMINATION U110_CYCLE_TERMINATION (
    //INPUT
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .ATA_ENn (ATA_ENn),
    .ATA_TACK (ATA_TACK),
    .PCI_TACK_ENn (PCI_TACK_ENn),

    //output
    .TEAn (TEAn),
    .TACKn (TACKn),
    .TCIn (TCIn),
    .TBIn (TBIn)
);

  /////////////
 // BUFFERS //
/////////////

U110_BUFFERS U110_BUFFERS (
    //INPUT
    .RESETn (RESETn),
    .ATA_ENn (ATA_ENn),
    .RnW (RnW),
    .SIZ (SIZ),
    .BGn (BGn),

    //output
    .IDEHRENn (IDEHRENn),
    .IDEHWENn (IDEHWENn),
    .IDELENn (IDELENn),
    .IDEDIR (IDEDIR),
    .BURSTn (BURSTn),
    .BUSDIR (BUSDIR)
);

  ////////////////////
 // ATA CONTROLLER //
////////////////////

U110_ATA U110_ATA (
    //INPUTS
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .ATA_ENn (ATA_ENn),
    .PPIO (PPIO),
    .SPIO (SPIO),
    .PCS1 (PCS1),
    .PCS0 (PCS0),
    .SCS1 (SCS1),
    .SCS0 (SCS0),
    .TSn (TSn),
    .RnW (RnW),

    //OUTPUTS
    .CS0_PRIn (CS0_PRIn),
    .CS1_PRIn (CS1_PRIn),
    .CS0_SECn (CS0_SECn),
    .CS1_SECn (CS1_SECn),
    .DIOR_PRIn (DIOR_PRIn),
    .DIOW_PRIn (DIOW_PRIn),
    .DIOR_SECn (DIOR_SECn),
    .DIOW_SECn (DIOW_SECn),
    .ATA_TACK (ATA_TACK),
    .ATA_LATCH (ATA_LATCH)
);

  /////////////////
 // BUS ARBITOR //
/////////////////

U110_ARBITOR U110_ARBITOR (

    //output
    .BGn (BGn)
);

  ////////////////////////
 // PCI STATE MACHINE //
////////////////////////

/*U110_PCI_SM U110_PCI_SM (
    //input
    .CLK40 (CLK40),
    .CLK33 (CLK33),
    .RESETn (RESETn),
    .RnW (RnW),
    .TSn (TSn),
    .DEVSELn (DEVSELn),
    .TRDYn (TRDYn),
    .BURST (BURST),
    .BPRO_ENn (BPRO_ENn),
    .PCIAT (PCIAT),

    //output
    .PCI_CYCLEn (PCI_CYCLEn)
);*/

  /////////
 // PLL //
/////////

SB_PLL40_CORE #(
    .DIVR (4'b0000),
    .DIVF (7'b0000000),
    .DIVQ (3'b100),
    .FILTER_RANGE (3'b011),
    .FEEDBACK_PATH ("PHASE_AND_DELAY"),
    .DELAY_ADJUSTMENT_MODE_FEEDBACK ("FIXED"),
    .FDA_FEEDBACK   (4'b1111),
    //.DELAY_ADJUSTMENT_MODE_RELATIVE ("FIXED"),
    //.FDA_RELATIVE   (4'b0000),
    .PLLOUT_SELECT ("SHIFTREG_0deg"),
    .SHIFTREG_DIV_MODE (1'b0)
) pll (
    .LOCK           (),
    .RESETB         (1'b1),
    .REFERENCECLK   (CLK40_PAD),
    .PLLOUTGLOBAL   (CLK40_PLL),
    
    .EXTFEEDBACK       (1'b0),
    .DYNAMICDELAY      (8'b00001111),
    .BYPASS            (1'b0),
    .SDI               (1'b0),
    .SCLK              (1'b0),
    .LATCHINPUTVALUE   (1'b0)
);

endmodule
