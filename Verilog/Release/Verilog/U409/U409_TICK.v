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
Design Name: U409
Module Name: U409_TICK
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: 50 AND 60Hz TICK CLOCKS

Revision History:
    01-JUL-2025 : INITIAL REV 6.0 CODE

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U409_TICK
(
    input CLK28_IN,
    output reg TICK60, TICK50
);

//////////////////
// TICK CLOCKS //
////////////////

localparam [8:0] H_TOTAL      = 9'd455;
localparam [9:0] V_TOTAL_PAL  = 9'd312;
localparam [9:0] V_TOTAL_NTSC = 9'd262;

reg [8:0] H_COUNT;
reg [9:0] V_COUNT_PAL, V_COUNT_NTSC;

always @(posedge CLK28_IN) begin

    if (H_COUNT == H_TOTAL -1) begin

        H_COUNT <= 0;

        if (V_COUNT_PAL == (V_TOTAL_PAL * 2) - 1) begin
            V_COUNT_PAL <= 0;
            TICK50 <= ~TICK50;
        end else begin
            V_COUNT_PAL <= V_COUNT_PAL + 1;
        end

        if (V_COUNT_NTSC == (V_TOTAL_NTSC * 2) - 1) begin
            V_COUNT_NTSC <= 0;
            TICK60 <= ~TICK60;
        end else begin
            V_COUNT_NTSC <= V_COUNT_NTSC + 1;
        end

    end else begin
        H_COUNT <= H_COUNT + 1;
    end
end



endmodule




