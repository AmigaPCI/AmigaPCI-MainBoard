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
    input  RESETn, RnW, BURSTn, BGn, BBn,
    output TBIn,
    inout  TSn, 

    //PCI
    input  DEVSELn, PCI_TIPn, W_LATCH_FRAMEn, //W_LATCH_ENn,
    output PCI_CYCLEn, CLK_ADDRESS_LATCH, ADDRESS_DIR, ADDRESS_ENn, PCI_RSTn,
    output BRIDGE_ENn, PCI_BUF_ENn, PCI_BUF_DIR, PARITY_DIR, PARITY_DA,
    output [2:0] PCIAT,
    output [4:0] IDSEL,
    inout  INIT_READYn, TARGET_READYn, TACKn, STOPn,

    //Busses
    inout [31:0] D,
    inout [31:0] AD

    ,output TP0, output TP1
);

//assign TP0 = TACK_EN;
//assign TP1 = TACKn_OUT;

//assign TP0 = CPU_BUS;
//assign TP1 = A2P_WR_EN;
//assign TP0 = CPU_BUS;
//assign TP1 = A2P_FIFO_EMPTY;
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
wire P2A_FIFO_FULL;
wire A2P_FIFO_EMPTY;
wire A2P_FIFO_FULL;
wire P2A_READ_NEXT;
wire A2P_READ_NEXT;
wire PCI_WRITE_EN;
wire BRIDGE_SPACE;
wire BRIDGE_CONF_SPACE;
wire CACHE_SPACE;
wire BUFFER_EN;
wire P2A_TIMEOUT;
wire CACHE_SPACE_EN;
wire RETRY_CYCLE;
wire TACK_EN, TACKn_OUT;
wire TACKn_IN = TACKn;
wire P2A_BURST_CYCLE;

/////////////////////
// EXTERNAL WIRES //
///////////////////

assign TACKn  = TACK_EN ? TACKn_OUT : 1'bz;
assign TBIn   = (TACK_EN && !P2A_BURST_CYCLE) ? TACKn_OUT : 1'bz;

////////////////
// BUS OWNER //
//////////////

 //Identfiy when the CPU is actively using the bus.
reg CPU_BUS;
always @(posedge CLK40) begin
    if (!RESETn) begin
        CPU_BUS <= 1;
    end else begin
        if (!BGn) begin
            CPU_BUS <= 1;
        end else if (BBn) begin
            CPU_BUS <= 0;
        end
    end
end

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
    .CPU_BUS (CPU_BUS),
    .REG_DATA (D[31]),
    .BURSTn (BURSTn),
    .PCI_TIPn (PCI_TIPn),
    .BRIDGE_CONF_SPACE (BRIDGE_CONF_SPACE),
    //.A (AD[7:0]),
    .A (AD[15]),
    .TARGET_READYn (TARGET_READYn),
    .STOPn (STOPn),
    .CACHE_SPACE_EN (CACHE_SPACE_EN),

    .PCI_CYCLEn (PCI_CYCLEn),
    .RETRY_CYCLE (RETRY_CYCLE),
    .BUFFER_EN (BUFFER_EN),
    .INIT_READYn (INIT_READYn),
    .PARITY_DIR (PARITY_DIR),
    .PCI_RSTn (PCI_RSTn),
    .P2A_READ_NEXT (P2A_READ_NEXT),
    .A2P_READ_NEXT (A2P_READ_NEXT),
    .P2A_BURST_CYCLE (P2A_BURST_CYCLE),
    .P2A_TIMEOUT (P2A_TIMEOUT),
    .TACKn_IN (TACKn_IN),
    .TACK_EN (TACK_EN),
    .TACKn_OUT (TACKn_OUT)
    ,.TP0 (TP0)
    ,.TP1 (TP1)
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
    .CPU_BUS (CPU_BUS),
    //.DEVSELn (DEVSELn),
    .PCI_TIPn (PCI_TIPn),
    .BRIDGE_SPACE (BRIDGE_SPACE),
    .CACHE_SPACE (CACHE_SPACE),
    .BUFFER_EN (BUFFER_EN),
    .P2A_TIMEOUT (P2A_TIMEOUT),
    .W_LATCH_FRAMEn (W_LATCH_FRAMEn),
    .RETRY_CYCLE (RETRY_CYCLE),
    .P2A_DATA (P2A_DATA),
    .A2P_DATA (A2P_DATA),

    //output
    .ADDRESS_ENn (ADDRESS_ENn),
    .ADDRESS_DIR (ADDRESS_DIR),
    .PCI_BUF_ENn (PCI_BUF_ENn),
    .PCI_BUF_DIR (PCI_BUF_DIR),
    .PCI_WRITE_EN (PCI_WRITE_EN),
    .CACHE_SPACE_EN (CACHE_SPACE_EN),
    .CLK_ADDRESS_LATCH (CLK_ADDRESS_LATCH),
    .PARITY_DA (PARITY_DA),
    .IDSEL (IDSEL),
    .PCIAT (PCIAT),

    //inout
    .D (D),
    .AD (AD)

    //,.TP0 (TP0),.TP1 (TP1)
);

///////////////////////
// ADDRESS DECODING //
/////////////////////

U109_ADDRESS_DECODE U109_ADDRESS_DECODE
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

//////////////////////////////
// PCI TO AMIGA (P2A) FIFO //
////////////////////////////

//DATA_ DIRECTION
//PCI_TO_AMIGA  = 1
//AMIGA_TO_PCI  = 0;
wire DATA_DIRECTION = ((CPU_BUS && !PCI_WRITE_EN) || (!CPU_BUS && !RnW));
wire P2A_WR_EN = (BUFFER_EN && DATA_DIRECTION && !TARGET_READYn);

U109_FIFO P2A_FIFO
(
    .RESETn (RESETn),
    .CLK_WR (CLK33), //Data generating device bus clock.
    .CLK_WR_SYNC (CLK66), //2x Write Clock
    .CLK_RD (CLK40), //Data consuming device bus clock.
    .CLK_RD_SYNC (CLK80), //2x Read Clock
    .WR_EN (P2A_WR_EN), //Write data into the fifo.
    .READ_NEXT (P2A_READ_NEXT), //Advance to next stored fifo value.
    .DATA_IN (AD), //Data input to fifo.
    .FIFO_EMPTY (P2A_FIFO_EMPTY), //Is the fifo empty?
    .FIFO_FULL (P2A_FIFO_FULL), //Is the FIFO full?
    .DATA_OUT (P2A_DATA) //Data out from the fifo.
);

//////////////////////////////
// AMIGA TO PCI (A2P) FIFO //
////////////////////////////

wire A2P_WR_EN = (!DATA_DIRECTION && ((CPU_BUS && !W_LATCH_FRAMEn) || (!CPU_BUS && !TACKn_IN)));

//Hackmasters unite!
//There is a whopping 16ns latency between the external _TACK assertion and 
//A2P_WR_EN goeing high, missing the desired clock edge.
//Only DMA cycles are effected, so we invert the clock during DMA cycles.
//This means we latch the data 1/2 clock late.
//This delay is certainly due to the i/o nature of this pin. The real fix may be
//to implement a second _TACK pin that is input only. These types of delays seem to
//be common with the the ice40 FPGA and can be observed on other i/o pins. This delay
//is an extreme example.
wire A2P_CLK40 = CPU_BUS ? CLK40_PLL : !CLK40_PLL;

U109_FIFO A2P_FIFO
(
    .RESETn (RESETn),
    //.CLK_WR (CLK40), //Data generating device bus clock.
    .CLK_WR (A2P_CLK40), //Data generating device bus clock.
    .CLK_WR_SYNC (CLK80), //2x Write Clock
    .CLK_RD (CLK33), //Data consuming device bus clock.
    .CLK_RD_SYNC (CLK66), //2x Read Clock
    .WR_EN (A2P_WR_EN), //Write data into the fifo.
    .READ_NEXT (A2P_READ_NEXT), //Advance to next stored fifo value.
    .DATA_IN (D), //Data input to fifo.
    .FIFO_EMPTY (A2P_FIFO_EMPTY), //Is the fifo empty?
    .FIFO_FULL (A2P_FIFO_FULL), //Is the FIFO full?
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
