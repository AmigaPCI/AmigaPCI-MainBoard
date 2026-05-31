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
Module Name: U712_CYCLE_TERMINATION
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Terminate all chip ram and register cycles.

Revision History
Date          Who  Description
-----------------------------------
03-OCT-2025 : JN   First release

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U712_CYCLE_TERMINATION

(
    input
        CLK40,
        RESETn,
        AGNUS_TACK,

    output
        TACKn
        //TCIn,
        //TBIn      
);

//Terminate all CPU driven Agnus cycles.
//Chip RAM and Register spaces do not support caching or bursting.

///////////////////
// OUTPUT WIRES //
/////////////////

assign TACKn = TACK_EN ? TACK_OUT : 1'bz;
//assign TBIn  = TACK_EN ? TACK_OUT : 1'bz;
//assign TCIn  = TACK_EN ? TACK_OUT : 1'bz;

/////////////////////////
// TACK STATE MACHINE //
///////////////////////

reg TACK_EN, TACK_OUT;
reg [1:0] TACK_STATE;

always @(negedge CLK40) begin
    if (!RESETn) begin
        TACK_EN  <= 0;
        TACK_OUT <= 1;
        TACK_STATE <= 2'b0;
    end else begin
        case (TACK_STATE)
            2'b00 : begin
                if (AGNUS_TACK) begin
                    TACK_EN <= 1;
                    TACK_OUT <= 0;
                    TACK_STATE <= 2'b01;
                end
            end
            2'b01 : begin
                TACK_OUT <= 1;
                TACK_STATE <= 2'b10;
            end
            2'b10 : begin
                TACK_EN <= 0;
                TACK_STATE <= 2'b0;
            end
        endcase
    end
end

endmodule