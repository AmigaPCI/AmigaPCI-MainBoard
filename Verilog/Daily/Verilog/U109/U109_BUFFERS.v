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

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U109_BUFFERS
(
    input PHASEA_D, DEVSELn, BGn, RnW, REGISTER_CYCLE,
    input [31:0] D_OUT,    

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

assign ADDRESS_ENn = !(PHASEA_D);
assign ADDRESS_DIR = BGn;

///////////////////////
// DATA BUS BUFFERS //
/////////////////////

//The onboard (FPGA) data bus buffers are enabled during the data phase of a PCI cycle.
//Only enable when a PCI device has identified itself.
//These buffers are byte swapped.

wire DATA_TO_AMIGA = ((REGISTER_CYCLE && RnW) || (!PHASEA_D && ((!BGn &&  RnW ) || (BGn && !RnW)))); 
wire DATA_TO_PCI   = (!PHASEA_D && ((!BGn && !RnW ) || (BGn && RnW)));

wire [31:0] D_DATA_OUT = REGISTER_CYCLE ? D_OUT : {AD[7:0], AD[15:8], AD[23:16], AD[31:24]};

assign AD = DATA_TO_PCI   ? { D[7:0],  D[15:8],  D[23:16],  D[31:24]} : 32'bz;
assign D  = DATA_TO_AMIGA ? D_DATA_OUT : 32'bz;

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