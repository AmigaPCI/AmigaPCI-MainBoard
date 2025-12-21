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
21-NOV-2025   JN   Moved assertion of PCIAT to PCI_STATE_MACHINE module.
27-NOV-2025   JN   Added IDSEL.
29-NOV-2025   JN   Removed bridge register address space.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U409_ADDRESS_DECODE
(   
  //Cycle Start
  input CLK40, TSn, RESETn, PCI_CYCLEn,
  input [31:16] A,

  //Chip Selects
  output BRIDGE_SPACE, BRIDGE_ENn, BRIDGE_CONF_SPACE
);

  //////////////////////
 // PCI BRIDGE SPACE //
//////////////////////

//We snoop the address on the AD bus and start a PCI cycle when
//presented the base address with _TS. If we don't latch BRIDGE_ENn
//during the cycle, it will drop as soon as we drive the AD bus for
//the PCI cycle. Since the main board buffers are driven by _BRIDGEN,
//we need to hold the bridge enable signal for the entire cycle.

localparam [3:0] BRIDGE_BASE = 4'h8;
localparam BRIDGE_ADDRESS  = 4'h0;
localparam CONF0_ADD_SPACE = 9'b111111100; //$9FC
localparam [1:0] BRIDGE_HOLD_DELAY = 2'd2;

assign BRIDGE_SPACE =       (RESETn && PCI_CYCLEn && A[31:29] == BRIDGE_BASE[3:1]);
assign BRIDGE_CONF_SPACE =  (BRIDGE_SPACE && A[28:20] == CONF0_ADD_SPACE && A[19:16] == BRIDGE_ADDRESS);
assign BRIDGE_ENn        = !(BRIDGE_SPACE || BRIDGE_CONF_SPACE || BRIDGE_HOLD || !PCI_CYCLEn);

reg BRIDGE_HOLD;
reg [1:0] BRIDGE_HOLD_COUNT;
wire BRIDGE_ENABLE = (!TSn && BRIDGE_SPACE);
always @(posedge CLK40 or posedge BRIDGE_ENABLE) begin
  if (BRIDGE_ENABLE) begin
    BRIDGE_HOLD <= 1'b1;
    BRIDGE_HOLD_COUNT <= 2'b00;
  end else if (!RESETn) begin
    BRIDGE_HOLD <= 1'b0;
    BRIDGE_HOLD_COUNT <= 2'b00;
  end else begin
    if (BRIDGE_HOLD) begin
      if (BRIDGE_HOLD_COUNT == BRIDGE_HOLD_DELAY) begin
        BRIDGE_HOLD <= 1'b0;
      end
      else begin
        BRIDGE_HOLD_COUNT <= BRIDGE_HOLD_COUNT + 1;
      end
    end
  end
end

endmodule