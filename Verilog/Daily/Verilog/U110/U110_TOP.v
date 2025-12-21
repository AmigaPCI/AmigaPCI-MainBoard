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

*/

module U110_TOP (

    //Clocks
    input CLK66_IN, CLK40_IN, CLK33_IN,
    
    //Cycle Start/Terminate
    input  RESETn, TSn, RnW,
    input  [1:0] SIZ,
    output TEAn, TCIn, TBIn, 
    inout  TACKn,
    
    //ATA Chip Selects
    input  ATA_ENn, PPIO, SPIO, PCS1 , PCS0, SCS1, SCS0,
    output CS0_PRIn, CS1_PRIn, CS0_SECn, CS1_SECn, DIOR_PRIn, DIOW_PRIn, DIOR_SECn, DIOW_SECn,

    //ATA Buffers
    output IDELENn, IDEDIR, IDEHRENn, IDEHWENn, ATA_LATCH,

    //PCI 
    input  DEVSELn, TRDYn, PCI_TACK_ENn, PCI_CYCLEn, UUBEn, UMBEn, LMBEn, LLBEn, BRIDGE_ENn, PARITY_DA,
    input  [1:0] PCIAT,
    input  [4:0] BUSREQ,
    output DEVSEL_OUTn, FRAMEn, PCI_TIPn, PARITY, W_LATCH_ENn,
    output [3:0] CBE,


    //Arbitor and Interrupts
    output INT2n, BUSDIR, BGn, BURSTn

    ,output TP0,TP1,TP2

);

//assign TP0 = CLK33;
//assign TP1 = CLK66; //13
//assign TP2 = CLK40;
//assign TP0 = PCI_TIPn;

////////////////////////////
// INTERNAL SIGNAL WIRES //
//////////////////////////

wire CLK66 = CLK66_IN;
wire CLK40_PAD = CLK40_IN;
wire CLK40;
//wire CLK33_PAD = CLK33_IN;
wire CLK33 = !CLK33_IN;
wire ATA_TACK;
wire PCI_TIMEOUT;
wire A2P_TACK_EN;
wire TACK_OUT;

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

U110_CYCLE_TERMINATION U110_CYCLE_TERMINATION (
    //INPUT
    .CLK40 (CLK40),
    //.CLK33 (CLK33),
    .RESETn (RESETn),
    //.ATA_ENn (ATA_ENn),
    .ATA_TACK (ATA_TACK),
    .PCI_TACK_ENn (PCI_TACK_ENn),
    .PCI_TIMEOUT (PCI_TIMEOUT),
    .A2P_TACK_EN (A2P_TACK_EN),

    //output
    .TEAn (TEAn),
    .TACKn (TACKn),
    .TCIn (TCIn),
    .TBIn (TBIn),
    .TACK_OUT (TACK_OUT)

    //,.TP1(TP1)
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

    //input
    .BUSREQ (BUSREQ),

    //output
    .BGn (BGn)
);

  ////////////////////////
 // PCI STATE MACHINE //
////////////////////////

U110_PCI_BRIDGE U110_PCI_BRIDGE (

    //input
    .CLK66 (CLK66),
    .CLK40 (CLK40),
    .CLK33 (CLK33),
    .RESETn (RESETn),
    .TSn (TSn),
    .RnW (RnW),
    .TACK_OUT (TACK_OUT),
    //.TACKn (TACKn),
    .BGn (BGn),
    .PCI_CYCLEn (PCI_CYCLEn),
    .DEVSELn (DEVSELn),
    .UUBEn (UUBEn),
    .UMBEn (UMBEn),
    .LMBEn (LMBEn),
    .LLBEn (LLBEn),
    .BURSTn (BURSTn),
    .BRIDGE_ENn (BRIDGE_ENn), 
    .PARITY_DA (PARITY_DA),
    .PCIAT (PCIAT),

    //output
    .FRAMEn (FRAMEn),
    .PCI_TIPn (PCI_TIPn),
    .W_LATCH_ENn (W_LATCH_ENn),
    .PCI_TIMEOUT (PCI_TIMEOUT),
    .A2P_TACK_EN (A2P_TACK_EN),
    .PARITY (PARITY),
    .CBE (CBE)

    ,.TP0(TP0),.TP1(TP1), .TP2(TP2)
);

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
) pll40 (
    .LOCK            (),
    .RESETB          (1'b1),
    .REFERENCECLK   (CLK40_PAD),
    //.PACKAGEPIN      (CLK40_PAD),
    .PLLOUTGLOBAL    (CLK40),
    .PLLOUTCORE      (),    
    .EXTFEEDBACK     (1'b0),
    .DYNAMICDELAY    (8'b00001111),
    .BYPASS          (1'b0),
    .SDI             (1'b0),
    .SCLK            (1'b0),
    .LATCHINPUTVALUE (1'b0)
);

/*SB_PLL40_PAD #(
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
) pll33 (
    .LOCK            (),
    .RESETB          (1'b1),
    //.REFERENCECLK   (CLK33_PAD),
    .PACKAGEPIN      (CLK33_PAD),
    .PLLOUTGLOBAL    (CLK33),
    .PLLOUTCORE      (),    
    .EXTFEEDBACK     (1'b0),
    .DYNAMICDELAY    (8'b00001111),
    .BYPASS          (1'b0),
    .SDI             (1'b0),
    .SCLK            (1'b0),
    .LATCHINPUTVALUE (1'b0)
);*/

endmodule
