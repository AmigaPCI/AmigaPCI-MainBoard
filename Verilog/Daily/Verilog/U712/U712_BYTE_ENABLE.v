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
Design Name: U712
Module Name: U712_BYTE_ENABLE
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: DATA TRANSFER BYTE ENABLE SIGNALS

Revision History:
    02-JUL-2025 Initial Rev 6.0 release.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U712_BYTE_ENABLE (

    input CPU_CYCLE, DMA_CYCLE, CASLn, CASUn, DB_ENn, RnW,
    input [1:0] A,
    input [1:0] SIZ,

    output CUUBEn, CUMBEn, CLMBEn, CLLBEn,
    output UUBEn, UMBEn, LMBEn, LLBEn,
    output UDS, LDS

);

////////////////////////////////
// DATA TRANSFER BYTE ENABLE //
//////////////////////////////

//ACTIVATE BYTES OF INTEREST FOR EACH DATA TRANSFER.
//THESE ARE FOR 32-BIT TRANSFERS.

wire LW_TRANS = (SIZ[1] ==  SIZ[0]);
wire WD_TRANS = (SIZ[1] && !SIZ[0]);

wire UUBE = (!A[1] && !A[0]) || LW_TRANS;
wire UMBE = (!A[1] &&  A[0]) || LW_TRANS || (!A[1] && WD_TRANS);
wire LMBE = ( A[1] && !A[0]) || LW_TRANS;
wire LLBE = ( A[1] &&  A[0]) || LW_TRANS || ( A[1] && WD_TRANS);

assign UUBEn = !UUBE;
assign UMBEn = !UMBE;
assign LMBEn = !LMBE;
assign LLBEn = !LLBE;

assign CUUBEn = !((UUBE && CPU_CYCLE) || (!CASUn && DMA_CYCLE && DB_ENn));
assign CUMBEn = !((UMBE && CPU_CYCLE) || (!CASLn && DMA_CYCLE && DB_ENn));
assign CLMBEn = !((LMBE && CPU_CYCLE) || (!CASUn && DMA_CYCLE && !DB_ENn));
assign CLLBEn = !((LLBE && CPU_CYCLE) || (!CASLn && DMA_CYCLE && !DB_ENn));

//THESE ARE FOR 16-BIT (MC68000) CHIPSET DATA TRANSFERS.
assign UDS = RnW || (!A[0] || LW_TRANS);
assign LDS = RnW || ( A[0] || WD_TRANS || LW_TRANS);

endmodule
