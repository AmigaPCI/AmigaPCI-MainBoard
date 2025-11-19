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
Module Name: U109_ADDRESS_DECODE
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: ADDRESS DECODE

Date          Who  Description
-----------------------------------
16-NOV-2025   JN   INITIAL CODE

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U409_ADDRESS_DECODE
(   
    //Cycle Start
    input RESETn, PHASEA_D,
    input [31:15] A,

    //Chip Selects
    //output CONF0_ACCESS, CONF1_ACCESS, IO_ACCESS,
    output BRIDGE_ENn, BRIDGE_REG_SPACE,
    output [1:0] PCIAT
);

  //////////////////////
 // PCI BRIDGE SPACE //
//////////////////////

//The address space can be snooped up to the completion of the address
//phase of a PCI cycle. States of these signals should be latched
//at the start of a new cycle.

// Access Type         PCIAT1   PCIAT0
//-------------------------------------
//PCI Config Space 0     0        0
//PCI Config Space 1     0        1
//PCI Memory Space       1        0
//I/O Space              1        1

localparam [3:0] BRIDGE_BASE = 4'h8;

assign BRIDGE_ENn =  !(RESETn && PHASEA_D && A[31:29] == BRIDGE_BASE[3:1]);

assign CONF0_SPACE      = (PHASEA_D && A[28:20] == 9'b111111100);
assign CONF1_SPACE      = (PHASEA_D && A[28:20] == 9'b111111101);
assign IO_SPACE         = (PHASEA_D && A[28:21] == 8'b11111111);
assign BRIDGE_REG_SPACE = (!BRIDGE_ENn && CONF0_SPACE && A[19:15] == 5'b00001);

assign PCIAT[1] = (IO_SPACE || (!IO_SPACE && !CONF0_SPACE && !CONF1_SPACE));
assign PCIAT[0] = (IO_SPACE || CONF1_SPACE);

endmodule