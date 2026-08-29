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
    input CLK40_IN, CLK33_IN,
    
    //Cycle Signals
    input  RESETn, TSn,
    inout  RnW,
    inout  [1:0] SIZ,
    output TCIn, TBIn, DATA_DIR,
    output [1:0] A_LOW,
    input TACKn_IN,
    output TACKn_OUT,
    
    //ATA Chip Selects
    input  ATA_ENn, PCS1, PCS0, SCS1, SCS0,
    input  ATA_J901, ATA_J902, ATA_J903,
    output CS0_PRIn, CS1_PRIn, CS0_SECn, CS1_SECn, DIOR_PRIn, DIOW_PRIn, DIOR_SECn, DIOW_SECn,

    //ATA Buffers
    output IDELENn, IDEDIR, IDEHRENn, IDEHWENn, ATA_LATCH,

    //PCI 
    input  AD31, PCI_CYCLEn, UUBEn, UMBEn, LMBEn, LLBEn, BRIDGE_ENn, PARITY_DA, IRDYn,
    input  [2:0] PCIAT,    
    output DEVSEL_OUTn, PCI_TIPn, PARITY, W_LATCH_ENn, LATCH_ADn, PCI_BUFF_ENn, PPDMA,
    inout  DEVSELn, FRAMEn,
    inout  [3:0] CBE,
    
    //Arbiter and Interrupts
    input  BRn, LOCKn, PCIINTENn, PCIINTn,
    input  [4:0] BUSREQ,
    output INT2n, BUSDIR, BGn, BURSTn, CPUBUSn,
    output [4:0] BUSGNT,
    inout  BBn

    ,output TP0
    //,output TP1
    //,output TP2

);

//assign TP0 = CLK33;
assign TP0 = PCI_TIPn;

//wire ATA_J901 = 1'b1;
//wire ATA_J902 = 1'b1;
//wire ATA_J903 = 1'b1;

////////////////////////////
// INTERNAL SIGNAL WIRES //
//////////////////////////

//wire CLK66 = CLK66_IN;
wire CLK33_PAD = CLK33_IN;
wire CLK40_PAD = CLK40_IN;
wire CLK40;
wire CLK33_PLL;
wire CLK33 = !CLK33_PLL;
wire ATA_TACK;
//wire W_LATCH_EN;
wire DMA_START;
wire DMA_WRITE_CYCLE;
wire BB_EN;
wire CPU_BUS_OWN;
wire [1:0] SIZ_OUT;

////////////////////////////
// EXTERNAL SIGNAL WIRES //
//////////////////////////

assign BUSDIR  = ~CPU_BUS_OWN; //BUSDIR = 1 = PCI HAS BUS
assign CPUBUSn = ~CPU_BUS_OWN;
assign DEVSEL_OUTn = DEVSELn; //Communicates DEVSELn to U109.

//assign TT = BUSDIR ? xxxx : 2'bz;
assign BBn = !CPU_BUS_OWN ? ~BB_EN : 1'bz;
assign SIZ = !CPU_BUS_OWN ?  SIZ_OUT : 2'bz;
assign RnW = !CPU_BUS_OWN ? ~DMA_WRITE_CYCLE : 1'bz;
//assign WLATCH_FRAMEn = ~(W_LATCH_EN || (!CPU_BUS_OWN && DMA_START));

  ///////////////
 // INTERRUPT //
///////////////

U110_INTERRUPT U110_INTERRUPT (
    //input
    .PCIINTn (PCIINTn),
    .PCIINTENn (PCIINTENn),

    //output
    .INT2n (INT2n)
);

  ///////////////////////
 // CYCLE TERMINATION //
///////////////////////

U110_CYCLE_TERMINATION U110_CYCLE_TERMINATION (
    //INPUT
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .ATA_TACK (ATA_TACK),
    .PCI_CYCLEn (PCI_CYCLEn),

    //output
    .TACKn_IN (TACKn_IN),
    .TACKn_OUT (TACKn_OUT),
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
    .CPU_BUS_OWN (CPU_BUS_OWN),
    .SIZ (SIZ),

    //output
    .IDEHRENn (IDEHRENn),
    .IDEHWENn (IDEHWENn),
    .IDELENn (IDELENn),
    .IDEDIR (IDEDIR),
    .BURSTn (BURSTn),
    .DATA_DIR (DATA_DIR)
);

  ////////////////////
 // ATA CONTROLLER //
////////////////////

U110_ATA U110_ATA (
    //INPUTS
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .ATA_ENn (ATA_ENn),
    .ATA_J901 (ATA_J901), 
    .ATA_J902 (ATA_J902), 
    .ATA_J903 (ATA_J903),
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

U110_ARBITER U110_ARBITER (
    //input
    .CLK40 (CLK40),
    .CLK33 (CLK33),
    .RESETn (RESETn),
    .BRn (BRn),
    .BBn (BBn),
    //.BB_EN (BB_EN),
    .LOCKn (LOCKn),
    //.CPU_BUS (CPU_BUS),
    .BUSREQ (BUSREQ),

    //output
    .BGn (BGn),
    .CPU_BUS_OWN (CPU_BUS_OWN),
    .BUSGNT (BUSGNT)

    //,.TP0 (TP0)//, .TP2 (TP2)
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
    .AD31 (AD31),
    .BGn (BGn),
    .PCI_CYCLEn (PCI_CYCLEn),
    .UUBEn (UUBEn),
    .UMBEn (UMBEn),
    .LMBEn (LMBEn),
    .LLBEn (LLBEn),
    .BRIDGE_ENn (BRIDGE_ENn), 
    .PARITY_DA (PARITY_DA),
    .IRDYn (IRDYn),
    .CPU_BUS_OWN (CPU_BUS_OWN),
    .PCIAT (PCIAT),

    //output
    .A_LOW (A_LOW),
    .SIZ_OUT (SIZ_OUT),
    .PCI_TIPn (PCI_TIPn),
    .DMA_WRITE_CYCLE (DMA_WRITE_CYCLE),
    .BB_EN (BB_EN),
    .DMA_START (DMA_START),
    .PPDMA (PPDMA),
    .W_LATCH_ENn (W_LATCH_ENn),
    .LATCH_ADn (LATCH_ADn),
    .PCI_BUFF_ENn (PCI_BUFF_ENn),
    .PARITY (PARITY),

    //inout
    .FRAMEn (FRAMEn),
    .DEVSELn (DEVSELn),
    .CBE (CBE)

    //,.TP0(TP0)
    //,.TP1(TP1)
    //, .TP2(TP2)
);

  /////////
 // PLL //
/////////

U110_4040_pll U110_4040_pll_inst(.PACKAGEPIN(CLK40_PAD),
                                 .PLLOUTCORE(),
                                 .PLLOUTGLOBAL(CLK40),
                                 .RESET(1'b1));

U110_3366_pll U110_3366_pll_inst(.PACKAGEPIN(CLK33_PAD),
                                 .PLLOUTCOREA(),
                                 .PLLOUTCOREB(),
                                 .PLLOUTGLOBALA(CLK66),
                                 .PLLOUTGLOBALB(CLK33_PLL),
                                 .RESET(1'b1));

endmodule
