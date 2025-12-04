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
  input CLK40, TSn, RESETn, PHASEA_D, BGn, INIT_READYn,
  input [31:16] A,

  //Chip Selects
  //output CONFIG0_ACCESS, CONFIG1_ACCESS, IO_ACCESS,
  output BRIDGE_ENn, //, BRIDGE_REG_SPACE, //CONFIG0_SPACE, CONFIG1_SPACE, IO_SPACE,
  output reg [1:0] PCIAT,
  output [4:0] IDSEL

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

wire BRIDGE_SPACE  = (RESETn && PHASEA_D && A[31:29] == BRIDGE_BASE[3:1]);
wire CONFIG0_SPACE = (A[28:20] == 9'b111111100); //$9FC (100111111100)
wire CONFIG1_SPACE = (A[28:20] == 9'b111111101); //$9FD (100111111101)
wire IO_SPACE      = (A[28:21] == 8'b11111111);  //$9E - $9F (10011110 - 10011111)

assign BRIDGE_ENn = !(BRIDGE_SPACE || !INIT_READYn);

  /////////////////////
 // PCI SLOT _IDSEL //
/////////////////////

wire SLOT4_ENABLE = (A[19:16] == 4'b0011);
wire SLOT3_ENABLE = (A[19:16] == 4'b1000);
wire SLOT2_ENABLE = (A[19:16] == 4'b0100);
wire SLOT1_ENABLE = (A[19:16] == 4'b0010);
wire SLOT0_ENABLE = (A[19:16] == 4'b0001);
wire CONFIG_SPACE = (BRIDGE_SPACE && (CONFIG0_SPACE || CONFIG1_SPACE));

assign IDSEL = !BGn ? IDSEL_OUT : 5'b00000;

reg [4:0] IDSEL_OUT;
always @(posedge CLK40) begin
  if (!RESETn) begin
    IDSEL_OUT <= 5'b00000;
    PCIAT <= 2'b00;
  end else begin
    if (!TSn) begin
      PCIAT[1] <= (IO_SPACE || (!IO_SPACE && !CONFIG0_SPACE && !CONFIG1_SPACE));
      PCIAT[0] <= (IO_SPACE || CONFIG1_SPACE);
      if (CONFIG_SPACE) begin
        IDSEL_OUT <= {SLOT4_ENABLE, SLOT3_ENABLE, SLOT2_ENABLE, SLOT1_ENABLE, SLOT0_ENABLE};
      end else begin
        IDSEL_OUT <= 5'b00000;
      end
    end
  end
end

endmodule