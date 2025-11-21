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
Design Name: U110
Module Name: U110_TOP
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: U109 AMIGA PCI FPGA - Bridge registers, PCI Cycle Start, FIFO, Bus duplexer.

GitHub: https://github.com/jasonsbeer/AmigaPCI

iceprog D:\AmigaPCI\U109\APCI_U109\APCI_U109_Implmnt\sbt\outputs\bitmap\U109_TOP_bitmap.bin
*/

module U109_TOP (

    //Clocks
    input CLK40_IN, CLK33,

    //Cycle Start/Terminate
    input RESETn, TSn, RnW, BURSTn, BGn,
    output TACK_ENn,

    //PCI
    input TARGET_READYn, DEVSELn,
    output PCI_CYCLEn, PHASEA_D, CLK_ADDRESS_LATCH, ADDRESS_DIR, ADDRESS_ENn, INT_ENn,
    output BRIDGE_ENn, PCI_BUF_ENn, PCI_BUF_DIR, INIT_READYn,
    output [1:0] PCIAT,

    //Busses
    inout [31:0] D,
    inout [31:0] AD

    //, output TP0, TP1
);

//Need to connect to _INT2!
wire INT_STATUSn = 1;

/////////////////////
// INTERNAL WIRES //
///////////////////

wire CLK40_PAD = CLK40_IN;
wire CLK40;
wire BRIDGE_REG_SPACE, CONFIG0_SPACE, CONFIG1_SPACE, IO_SPACE, A_LATCH_VALID, PCI_TACK_EN;
wire REGISTER_CYCLE;
wire REG_TACK;
wire [31:0] A_LATCH;
wire [31:0] D_OUT;

assign INIT_READYn = PHASEA_D;
assign TACK_ENn = !(REG_TACK || PCI_TACK_EN);

//////////////////////////////
// PCI CYCLE STATE MACHINE //
////////////////////////////

U109_PCI_STATE_MACHINE U109_PCI_STATE_MACHINE (
    .CLK40 (CLK40),
    .CLK33 (CLK33),
    .RESETn (RESETn),
    .TSn (TSn),
    .RnW (RnW),
    .BRIDGE_ENn (BRIDGE_ENn),
    .BURSTn (BURSTn),
    .BRIDGE_REG_SPACE (BRIDGE_REG_SPACE),
    .DEVSELn (DEVSELn),
    .AD (AD),
    .TARGET_READYn (TARGET_READYn),
    .PCI_CYCLEn (PCI_CYCLEn),
    .CLK_ADDRESS_LATCH (CLK_ADDRESS_LATCH),
    .A_LATCH_VALID (A_LATCH_VALID),
    .PHASEA_D (PHASEA_D),
    .PCI_TACK_EN (PCI_TACK_EN),
    .CONFIG0_SPACE (CONFIG0_SPACE),
    .CONFIG1_SPACE (CONFIG1_SPACE),
    .IO_SPACE (IO_SPACE),
    .PCIAT (PCIAT),
    .A_LATCH (A_LATCH)
);

//////////////////
// PCI BUFFERS //
////////////////

U109_BUFFERS U109_BUFFERS(
    //INPUTS
    .PHASEA_D (PHASEA_D),
    .DEVSELn (DEVSELn),
    .BGn (BGn),
    .RnW (RnW),
    .REGISTER_CYCLE (REGISTER_CYCLE),
    .D_OUT (D_OUT),
    .A_LATCH (A_LATCH),
    .A_LATCH_VALID (A_LATCH_VALID),
    .PCIAT (PCIAT),

    //output
    .ADDRESS_ENn (ADDRESS_ENn),
    .ADDRESS_DIR (ADDRESS_DIR),
    .PCI_BUF_ENn (PCI_BUF_ENn),
    .PCI_BUF_DIR (PCI_BUF_DIR),

    //inout
    .D (D),
    .AD (AD)

    //,.TP0(TP0)
);

///////////////////////
// ADDRESS DECODING //
/////////////////////

U409_ADDRESS_DECODE U409_ADDRESS_DECODE
(
   //input
   .RESETn (RESETn),
   .PHASEA_D (PHASEA_D),
   .A (AD[31:15]),

   //output
   .BRIDGE_ENn (BRIDGE_ENn),
   .BRIDGE_REG_SPACE (BRIDGE_REG_SPACE),
   .CONFIG0_SPACE (CONFIG0_SPACE),
   .CONFIG1_SPACE (CONFIG1_SPACE),
   .IO_SPACE (IO_SPACE)
);

///////////////////////
// BRIDGE REGISTERS //
/////////////////////

U109_REGISTERS U109_REGISTERS (

    //input
    .CLK40 (CLK40),
    .RESETn (RESETn),
    .RnW (RnW),
    .TSn (TSn),
    .BRIDGE_REG_SPACE (BRIDGE_REG_SPACE),
    .INT_STATUSn (INT_STATUSn),
    .REG_ADDRESS (AD[5:2]), //This is AD[5:2]
    .D (D[31:30]),
    
    //output
    .REGISTER_CYCLE (REGISTER_CYCLE),
    .REG_TACK (REG_TACK),
    .INT_ENn (INT_ENn),
    .D_OUT (D_OUT)
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
    .FDA_FEEDBACK   (4'b0000),
    //.DELAY_ADJUSTMENT_MODE_RELATIVE ("FIXED"),
    //.FDA_RELATIVE   (4'b0000),
    .PLLOUT_SELECT ("SHIFTREG_0deg"),
    .SHIFTREG_DIV_MODE (1'b0)
) pll40 (
    .LOCK           (),
    .RESETB         (1'b1),
    .REFERENCECLK   (CLK40_PAD),
    .PLLOUTGLOBAL   (CLK40),
    
    .EXTFEEDBACK       (1'b0),
    .DYNAMICDELAY      (8'b00000000),
    .BYPASS            (1'b0),
    .SDI               (1'b0),
    .SCLK              (1'b0),
    .LATCHINPUTVALUE   (1'b0)
);

endmodule
