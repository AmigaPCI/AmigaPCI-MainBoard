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

Description: U110 AMIGA PCI FPGA - PCI finiate state machine.

See individual modules for revision history.

GitHub: https://github.com/jasonsbeer/AmigaPCI

Date          Who  Description
-----------------------------------
29-NOV-2025   JN   Initial code.
*/

module U110_BUFFERS (

    input CLK40, RESETn, ATA_ENn, RnW, CPU_BUS,
    input [1:0] SIZ,

    output IDELENn, IDEHRENn, IDEHWENn, IDEDIR, BURSTn,
    output reg BUSDIR

);

  /////////////////
 // ATA BUFFERS //
/////////////////

assign IDEHRENn = !(RESETn && !ATA_ENn &&  RnW);
assign IDEHWENn = !(RESETn && !ATA_ENn && !RnW);

assign IDELENn  = 1;
assign IDEDIR = !RnW;

  /////////////////
 // BURST CYCLE //
/////////////////

assign BURSTn = !(SIZ[1] && SIZ[0]);

  ///////////////////
 // BUS DIRECTION //
///////////////////

//Sets the direction of unidirectional busses and signals, like the A bus or _TS.
//Will reverse direction during PCI DMA.

//0 = CPU has the bus.
//1 = PCI has the bus.

always @(negedge CLK40) begin
  if (!RESETn) begin
    BUSDIR <= 0;
  end else begin
    if (CPU_BUS) begin
      BUSDIR <= 0;
    end else begin
      BUSDIR <= 1;
    end
  end
end


endmodule
