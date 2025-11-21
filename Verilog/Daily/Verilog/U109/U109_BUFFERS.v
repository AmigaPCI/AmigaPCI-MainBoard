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
Design Name: U109
Module Name: U109_BUFFERS
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Buffers for the PCI bus interface.

Date          Who  Description
-----------------------------------
18-NOV-2025   JN   INITIAL CODE
21-NOV-2025   JN   Added address decoding for all cycle types.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U109_BUFFERS
(
    input PHASEA_D, DEVSELn, BGn, RnW, REGISTER_CYCLE, A_LATCH_VALID,
    input [1:0] PCIAT,
    input [31:0] D_OUT,
    input [31:0] A_LATCH, 

    output ADDRESS_ENn, ADDRESS_DIR, PCI_BUF_ENn, PCI_BUF_DIR,

    inout [31:0] D,
    inout [31:0] AD
);

//////////////////////
// ADDRESS BUFFERS //
////////////////////

//The address buffers are enabled any time the PCI state machine is idle or 
//in the address phase of the cycle. The direction of the data is determined
//by who has the bus.

wire ADDRESS_VALID = (PHASEA_D && A_LATCH_VALID);
assign ADDRESS_ENn = ADDRESS_VALID;
assign ADDRESS_DIR = BGn;

///////////////////////
// DATA BUS BUFFERS //
/////////////////////

//The onboard (FPGA) data bus buffers are enabled during the data phase of a PCI cycle.
//Only enable when a PCI device has identified itself.
//These buffers are byte swapped for data phase transfers.

// Access Type         PCIAT1   PCIAT0
//-------------------------------------
//PCI Config Space 0     0        0
//PCI Config Space 1     0        1
//PCI Memory Space       1        0
//I/O Space              1        1

localparam BURST_ORDER_WRAP = 2'b10;
localparam CONFIG0_ACCESS   = 2'b00;
localparam CONFIG1_ACCESS   = 2'b01;

wire CONFIG0_SPACE = PCIAT == 2'b00;
wire CONFIG1_SPACE = PCIAT == 2'b01;
wire MEMORY_SPACE  = PCIAT == 2'b10;

wire D_TO_AMIGA   = ((REGISTER_CYCLE && RnW) || (!PHASEA_D && ((!BGn &&  RnW ) || (BGn && !RnW)))); 
wire AD_TO_PCI    = ((ADDRESS_VALID) || ((!PHASEA_D && ((!BGn && !RnW ) || (BGn && RnW)))));

wire [1:0]  A_LOW      = CONFIG0_SPACE ? CONFIG0_ACCESS : CONFIG1_SPACE ? CONFIG1_ACCESS : A_LATCH[1:0];
wire [31:0] AD_A_OUT   = MEMORY_SPACE ? {A_LATCH[31:2], BURST_ORDER_WRAP} : {12'h0, A_LATCH[19:2], A_LOW};
wire [31:0] AD_OUT     = ADDRESS_VALID ? AD_A_OUT : { D[7:0],  D[15:8],  D[23:16],  D[31:24]};
wire [31:0] D_DATA_OUT = REGISTER_CYCLE ? D_OUT : {AD[7:0], AD[15:8], AD[23:16], AD[31:24]};

assign AD = AD_TO_PCI  ? AD_OUT : 32'bz;
assign D  = D_TO_AMIGA ? D_DATA_OUT : 32'bz;

/////////////////////////////
// LEVEL SHIFTING BUFFERS //
///////////////////////////

//The level shifting buffers can be enabled for moat cycles.
//The only exception is a PCI to PCI DMA cycle, which can 
//be detected by a PCI DMA cycle where _DEVSEL asserts.
//Direction is dictated by who what the bus and cycle type.
//U812, U813, U818, U819.

//The CPU is on the "B" side.
//PCI is on the "A" side.

//               Bus Direction
//      Address Phase     Data Phase
// R/W  CPU     PCI       CPU     PCI
// --------------------------------------
//  R   A<B (0) A>B (1)   A>B (1) A<B (0)
//  W   A<B (0) A>B (1)   A<B (0) A>B (1)

assign PCI_BUF_ENn = !(PHASEA_D || (!BGn && !PHASEA_D && !DEVSELn));

//wire CPU_WRITE = !BGn && !RnW && !PHASEA_D;
//wire DMA_READ  =  BGn &&  RnW && !PHASEA_D;

//wire CPU_READ  = !BGn &&  RnW && !PHASEA_D;
//wire DMA_WRITE =  BGn && !RnW && !PHASEA_D;

assign PCI_BUF_DIR =  ((PHASEA_D && BGn) || (!PHASEA_D && ((RnW && !BGn) || (!RnW && BGn))));

endmodule