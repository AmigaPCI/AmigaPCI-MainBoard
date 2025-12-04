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

    //Cycle Start/Terminate
    input RESETn, TSn, RnW, BURSTn, BGn, TACKn,
    output TACK_ENn,

    //PCI
    input TARGET_READYn, DEVSELn, PHASEA_D, PCI_TIPn,
    output PCI_CYCLEn, CLK_ADDRESS_LATCH, ADDRESS_DIR, ADDRESS_ENn, //INT_ENn,
    output BRIDGE_ENn, PCI_BUF_ENn, PCI_BUF_DIR, INIT_READYn, PARITY_DIR, PARITY_DA,
    output [1:0] PCIAT,
    output [4:0] IDSEL,

    //Busses
    inout [31:0] D,
    inout [31:0] AD

    , output TP0, TP1
);

assign TP0 = PHASEA_D;
assign TP1 = BRIDGE_ENn;

//Need to connect to _INT2!
//wire INT_STATUSn = 1;

/////////////////////
// INTERNAL WIRES //
///////////////////

//wire CLK40_PAD = CLK40_IN;
wire CLK40 = CLK40_IN;
wire CLK33_PAD = CLK33_IN;
wire CLK33_PLL;
wire CLK33 = !CLK33_PLL;
wire PCI_TACK_EN;
wire DATA_DIRECTION;
wire PCI_WRITE_CYCLE;
wire [31:0] P2A_DATA;
wire [31:0] A2P_DATA = 32'hffffffff;
wire P2A_FIFO_EMPTY, A2P_FIFO_EMPTY;
wire P2A_READ_NEXT;

//assign TACK_ENn = !(REG_TACK || PCI_TACK_EN);
assign TACK_ENn = !(PCI_TACK_EN);

//assign TP0 = p_ren;

//////////////////////////////
// PCI CYCLE STATE MACHINE //
////////////////////////////

U109_PCI_STATE_MACHINE U109_PCI_STATE_MACHINE (
    .CLK40 (CLK40),
    .CLK33 (CLK33),
    .RESETn (RESETn),
    .RnW (RnW),
    .BURSTn (BURSTn),
    .PCI_TIPn (PCI_TIPn),
    .BGn (BGn),
    .TACKn (TACKn),
    .P2A_FIFO_EMPTY (P2A_FIFO_EMPTY),
    .A2P_FIFO_EMPTY (A2P_FIFO_EMPTY),
    .PCI_CYCLEn (PCI_CYCLEn),
    .CLK_ADDRESS_LATCH (CLK_ADDRESS_LATCH),
    .INIT_READYn (INIT_READYn),
    .PARITY_DIR (PARITY_DIR),
    .DATA_DIRECTION (DATA_DIRECTION),
    .PCI_WRITE_CYCLE (PCI_WRITE_CYCLE),
    .PCI_TACK_EN (PCI_TACK_EN),
    .P2A_READ_NEXT (P2A_READ_NEXT)
);

//////////////////
// PCI BUFFERS //
////////////////

U109_BUFFERS U109_BUFFERS(
    //INPUTS
    .CLK40 (CLK40),
    .CLK33 (CLK33),
    .RESETn (RESETn),
    .TSn (TSn),
    .PHASEA_D (PHASEA_D),
    .DEVSELn (DEVSELn),
    .BGn (BGn),
    .RnW (RnW),
    .PCI_TIPn (PCI_TIPn),
    .BRIDGE_ENn (BRIDGE_ENn),
    .PCI_CYCLEn (PCI_CYCLEn),
    .PCI_WRITE_CYCLE (PCI_WRITE_CYCLE),
    .PCIAT (PCIAT),
    .P2A_DATA (P2A_DATA),
    .A2P_DATA (A2P_DATA),

    //output
    .ADDRESS_ENn (ADDRESS_ENn),
    .ADDRESS_DIR (ADDRESS_DIR),
    .PCI_BUF_ENn (PCI_BUF_ENn),
    .PCI_BUF_DIR (PCI_BUF_DIR),
    .PARITY_DA (PARITY_DA),

    //inout
    .D (D),
    .AD (AD)
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
   .PHASEA_D (PHASEA_D),
   .BGn (BGn),
   .INIT_READYn (INIT_READYn),
   .A (AD[31:16]),

   //output
   .BRIDGE_ENn (BRIDGE_ENn),
   .PCIAT (PCIAT),
   .IDSEL (IDSEL)
);

//////////////////
// BRIDGE FIFO //
////////////////

U109_FIFO U109_FIFO
(
    //input
    .CLKBUS (CLK40),
    .CLKPCI (CLK33),
    .RESETn (RESETn),

    .TARGET_READYn (TARGET_READYn),
    .P2A_READ_NEXT (P2A_READ_NEXT),

    .AD_IN (AD),

    //output
    .P2A_FIFO_EMPTY (P2A_FIFO_EMPTY),
    .A2P_FIFO_EMPTY (A2P_FIFO_EMPTY),
    .P2A_DATA (P2A_DATA)

    //,.TP0 (TP0)
);

//Direction of data flow.
// 0 = Amiga is producer, PCI is consumer
// 1 = PCI is producer, Amiga is consumer

//Trigger the FIFO to latch incoming data.
/*wire amiga_write_en = (!TACKn && !RnW); //CPU write or DMA read. Data moves D -> AD.
wire pci_write_en   = (!TARGET_READYn && RnW); //CPU read or DMA write. Data moves D <- AD.

//assign TP0 = DATA_DIRECTION;
//assign TP1 = a_rempty;

U109_BRIDGE_FIFO_DIR U109_BRIDGE_FIFO_DIR (
    .RESETn (RESETn),

    .dir       (DATA_DIRECTION),   
    .amiga_clk (CLK40),
    .pci_clk   (CLK33),

    // --- CPU WRITE or DMA READ ---
    //DIR==0 = Amiga is producer, PCI is consumer
    //Amiga side
    .a_wen     (amiga_write_en), 
    .a_wdata   (D),
    .a_wready  (amiga_wready), //FIFO not full.

    // PCI side
    .p_ren     (p_ren),
    .p_rdata   (p_rdata),
    .p_rempty  (p_rempty), //FIFO empty.

    // --- CPU READ or DMA WRITE ---
    //DIR==1 = PCI is producer, Amiga is consumer
    //Amiga side
    .a_ren     (a_ren),
    .a_rdata   (a_rdata),
    .a_rempty  (a_rempty), //FIFO empty.

    // PCI side
    .p_wen     (pci_write_en),
    .p_wdata   (AD),
    .p_wready  (pci_wready) //FIFO not full

    ,.TP0 (TP0), .TP1 (TP1)

    
);*/

///////////////////////
// BRIDGE REGISTERS //
/////////////////////

/*U109_REGISTERS U109_REGISTERS (

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
);*/

  /////////
 // PLL //
/////////

//icecube2 struggles with synthesizing two PLLs.
//It will throw errors but still seems to work fine.

//SB_PLL40_CORE #(
/*SB_PLL40_PAD #(
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
    .SHIFTREG_DIV_MODE (2'b00)
) pll40 (
    .LOCK            (),
    .RESETB          (1'b1),
    .PACKAGEPIN      (CLK40_PAD),
    .PLLOUTGLOBAL    (CLK40),
    .PLLOUTCORE      (), 
    .EXTFEEDBACK     (1'b0),
    .DYNAMICDELAY    (8'b00000000),
    .BYPASS          (1'b0),
    .SDI             (1'b0),
    .SCLK            (1'b0),
    .LATCHINPUTVALUE (1'b0)
);*/

//8ns early
/*SB_PLL40_PAD #(
    .DIVR (4'b0000),
    .DIVF (7'b0000000),
    .DIVQ (3'b011),
    .FILTER_RANGE (3'b011),
    .FEEDBACK_PATH ("PHASE_AND_DELAY"),
    .DELAY_ADJUSTMENT_MODE_FEEDBACK ("FIXED"),
    //.DELAY_ADJUSTMENT_MODE_FEEDBACK ("DYNAMIC"),
    .FDA_FEEDBACK   (4'b0000),
    //.DELAY_ADJUSTMENT_MODE_RELATIVE ("FIXED"),
    //.FDA_RELATIVE   (4'b0000),
    .PLLOUT_SELECT ("SHIFTREG_0deg"),
    .SHIFTREG_DIV_MODE (2'b00),
    .ENABLE_ICEGATE (1'b0)
) pll33 (
    .LOCK            (),
    .RESETB          (1'b1),
    .PACKAGEPIN      (CLK33_PAD),
    .PLLOUTGLOBAL    (CLK33_PLL),
    .PLLOUTCORE      (),
    .EXTFEEDBACK     (1'b0),
    .DYNAMICDELAY    (8'b00000000),
    .BYPASS          (1'b0),
    .SDI             (1'b0),
    .SCLK            (1'b0),
    .LATCHINPUTVALUE (1'b0)
);*/

//4ns early
SB_PLL40_PAD #(
    .DIVR (4'b0000),
    .DIVF (7'b0011111),
    .DIVQ (3'b101),
    .FILTER_RANGE (3'b011),
    .FEEDBACK_PATH ("SIMPLE"),
    .PLLOUT_SELECT ("GENCLK"),
    .ENABLE_ICEGATE (1'b0)
) pll33 (
    .LOCK            (),
    .RESETB          (1'b1),
    .PACKAGEPIN      (CLK33_PAD),
    .PLLOUTGLOBAL    (CLK33_PLL),
    .PLLOUTCORE      (),
    .EXTFEEDBACK     (1'b0),
    .DYNAMICDELAY    (8'b00000000),
    .BYPASS          (1'b0),
    .SDI             (1'b0),
    .SCLK            (1'b0),
    .LATCHINPUTVALUE (1'b0)
);

endmodule
