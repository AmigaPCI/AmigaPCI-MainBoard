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
    input CLK40_IN, CLK33_IN,
    output CLK66_OUT,

    //Cycle Start/Terminate
    input RESETn, TSn, RnW, BURSTn, BGn,
    output TBIn,

    //PCI
    input  TARGET_READYn, DEVSELn, PCI_TIPn, W_LATCH_ENn, //STOPn,
    output PCI_CYCLEn, CLK_ADDRESS_LATCH, ADDRESS_DIR, ADDRESS_ENn, PCI_RSTn,
    output BRIDGE_ENn, PCI_BUF_ENn, PCI_BUF_DIR, INIT_READYn, PARITY_DIR, PARITY_DA,
    output [2:0] PCIAT,
    output [4:0] IDSEL,
    output TACKn,

    //Busses
    inout [31:0] D,
    inout [31:0] AD

    ,output TP0, TP1
);

//assign TP0 = W_LATCH_ENn;
//assign TP1 = P2A_READ_NEXT;

/////////////////////
// INTERNAL WIRES //
///////////////////

wire CLK80_PLL;
wire CLK80 = CLK80_PLL;
wire CLK40_PAD = CLK40_IN;
wire CLK40_PLL;
wire CLK40 = CLK40_PLL;
wire CLK33_PAD = CLK33_IN;
wire CLK33_PLL;
wire CLK33 = !(CLK33_PLL);
wire CLK66_PLL;
wire CLK66 = CLK66_PLL;
assign CLK66_OUT = CLK66_PLL;

wire [31:0] P2A_DATA;
wire [31:0] A2P_DATA;
wire P2A_FIFO_EMPTY;
wire A2P_FIFO_EMPTY;
wire P2A_READ_NEXT;
wire A2P_READ_NEXT;
wire PCI_WRITE_EN;
wire BRIDGE_SPACE;
wire BRIDGE_CONF_SPACE;
wire CACHE_SPACE;
wire BUFFER_EN;
wire P2A_TIMEOUT;
wire CACHE_SPACE_EN;

//////////////////////////////
// PCI CYCLE STATE MACHINE //
////////////////////////////

U109_PCI_STATE_MACHINE U109_PCI_STATE_MACHINE (
    .CLK80 (CLK80),
    .CLK66 (CLK66),
    .CLK40 (CLK40),
    .CLK33 (CLK33),
    .RESETn (RESETn),
    .TSn (TSn),
    .RnW (RnW),
    .REG_DATA (D[31]),
    .BURSTn (BURSTn),
    .PCI_TIPn (PCI_TIPn),
    .BGn (BGn),
    .PCI_WRITE_EN (PCI_WRITE_EN),
    .BRIDGE_CONF_SPACE (BRIDGE_CONF_SPACE),
    .A (AD[7:0]),
    .P2A_FIFO_EMPTY (P2A_FIFO_EMPTY),
    .A2P_FIFO_EMPTY (A2P_FIFO_EMPTY),
    .DEVSELn (DEVSELn),
    .TARGET_READYn (TARGET_READYn),
    .CACHE_SPACE_EN (CACHE_SPACE_EN),
    //.STOPn (STOPn),

    .PCI_CYCLEn (PCI_CYCLEn),
    .BUFFER_EN (BUFFER_EN),
    .CLK_ADDRESS_LATCH (CLK_ADDRESS_LATCH),
    .INIT_READYn (INIT_READYn),
    .PARITY_DIR (PARITY_DIR),
    .TACKn (TACKn),
    .PCI_RSTn (PCI_RSTn),
    .P2A_READ_NEXT (P2A_READ_NEXT),
    .A2P_READ_NEXT (A2P_READ_NEXT),
    .TBIn (TBIn),
    .P2A_TIMEOUT (P2A_TIMEOUT)
    ,.TP0 (TP0), .TP1 (TP1)
);

//////////////////
// PCI BUFFERS //
////////////////

U109_BUFFERS U109_BUFFERS(
    //INPUTS
    .CLK40 (CLK40),
    .CLK33 (CLK33),
    .RESETn (RESETn),
    .RnW (RnW),
    .TSn (TSn),
    .BURSTn (BURSTn),
    .DEVSELn (DEVSELn),
    .BGn (BGn),
    .PCI_TIPn (PCI_TIPn),
    .BRIDGE_SPACE (BRIDGE_SPACE),
    .CACHE_SPACE (CACHE_SPACE),
    .BUFFER_EN (BUFFER_EN),
    .P2A_TIMEOUT (P2A_TIMEOUT),
    .P2A_DATA (P2A_DATA),
    .A2P_DATA (A2P_DATA),

    //output
    .ADDRESS_ENn (ADDRESS_ENn),
    .ADDRESS_DIR (ADDRESS_DIR),
    .PCI_BUF_ENn (PCI_BUF_ENn),
    .PCI_BUF_DIR (PCI_BUF_DIR),
    .PCI_WRITE_EN (PCI_WRITE_EN),
    .CACHE_SPACE_EN (CACHE_SPACE_EN),
    .PARITY_DA (PARITY_DA),
    .IDSEL (IDSEL),
    .PCIAT (PCIAT),

    //inout
    .D (D),
    .AD (AD)

    //,.TP1 (TP1)
);

///////////////////////
// ADDRESS DECODING //
/////////////////////

U409_ADDRESS_DECODE U409_ADDRESS_DECODE
(
   //input
   .CLK40 (CLK40),
   .RESETn (RESETn),
   .TSn (TSn),
   .BUFFER_EN (BUFFER_EN),
   .PCI_CYCLEn (PCI_CYCLEn),
   .A (AD[31:16]),

   //output
   .BRIDGE_SPACE (BRIDGE_SPACE),
   .CACHE_SPACE (CACHE_SPACE),
   .BRIDGE_ENn (BRIDGE_ENn),
   .BRIDGE_CONF_SPACE (BRIDGE_CONF_SPACE)
);

////////////////////////
// PCI TO AMIGA FIFO //
//////////////////////

//DATA_ DIRECTION
//PCI_TO_AMIGA  = 1
//AMIGA_TO_PCI  = 0;
wire DATA_DIRECTION = (!BGn && !PCI_WRITE_EN);
wire P2A_WR_EN = (BUFFER_EN && DATA_DIRECTION && !TARGET_READYn);

U109_FIFO P2A_FIFO
(
    .RESETn (RESETn),
    .CLK_WR (CLK33), //Data generating device bus clock.
    .CLK_RD (CLK40), //Data consuming device bus clock.
    .CLK_SYNC (CLK80), //2x Read Clock
    .WR_EN (P2A_WR_EN), //Write data into the fifo.
    .READ_NEXT (P2A_READ_NEXT), //Advance to next stored fifo value.
    .DATA_IN (AD), //Data input to fifo.
    .FIFO_EMPTY (P2A_FIFO_EMPTY), //Is the fifo empty?
    .DATA_OUT (P2A_DATA) //Data out from the fifo.
);

////////////////////////
// AMIGA TO PCI FIFO //
//////////////////////

wire A2P_WR_EN = (!W_LATCH_ENn && !DATA_DIRECTION);

U109_FIFO A2P_FIFO
(
    .RESETn (RESETn),
    .CLK_WR (CLK40), //Data generating device bus clock.
    .CLK_RD (CLK33), //Data consuming device bus clock.
    .CLK_SYNC (CLK66), //2x Read Clock
    .WR_EN (A2P_WR_EN), //Write data into the fifo.
    .READ_NEXT (A2P_READ_NEXT), //Advance to next stored fifo value.
    .DATA_IN (D), //Data input to fifo.
    .FIFO_EMPTY (A2P_FIFO_EMPTY), //Is the fifo empty?
    .DATA_OUT (A2P_DATA) //Data out from the fifo.
);

  /////////
 // PLL //
/////////

//icecube2 struggles with synthesizing two PLLs.
//It will throw a lot of warnings but works fine.

U109_TOP_4080_pll U109_TOP_4080_pll(
    .PACKAGEPIN(CLK40_PAD),
    .PLLOUTCOREA(),
    .PLLOUTCOREB(),
    .PLLOUTGLOBALA(CLK80_PLL),
    .PLLOUTGLOBALB(CLK40_PLL),
    .RESET(1'b1));

U109_TOP_3366_pll U109_TOP_3366_pll(
    .PACKAGEPIN(CLK33_PAD),
    .PLLOUTCOREA(),
    .PLLOUTCOREB(),
    .PLLOUTGLOBALA(CLK66_PLL),
    .PLLOUTGLOBALB(CLK33_PLL),
    .RESET(1'b1));

endmodule
