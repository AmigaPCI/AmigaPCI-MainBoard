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
Module Name: U409_FLASH
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Flash Cycle State Machine

Date         Who  Description
----------------------------------
17-OCT-2025  JN   INITIAL CODE
05-NOV-2025  JN   Add one clock to read cycle.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U409_FLASH
(

    //Clocls
    input CLK40,
    
    //Cycle Start/Terminate
    input RESETn, TSn, RnW,
    output reg FLASH_TACK,

    //FLASH Control Signals
    input FLASH_SPACE,
    output FLASH_WPn, FLASH_RSTn, FLASH_READn, FLASH_WRITEn,
    output reg FLASH_ENn

);

assign FLASH_WPn = 1;
assign FLASH_RSTn = RESETn;

//////////////////////////
// FLASH STATE MACHINE //
////////////////////////

assign FLASH_READn  = !(FLASH_ENABLED && !WRITE_CYCLE);
assign FLASH_WRITEn = !(FLASH_ENABLED &&  WRITE_CYCLE);

reg WRITE_CYCLE, FLASH_ENABLED;
reg [3:0] FLASH_STATE_COUNTER;

always @(posedge CLK40) begin
    if (!RESETn) begin
        FLASH_ENn <= 1;
        FLASH_TACK <= 0;
        WRITE_CYCLE <= 0;
        FLASH_ENABLED <= 0;
        FLASH_STATE_COUNTER <= 4'h0;
    end else begin

    case (FLASH_STATE_COUNTER)
        4'h0 : begin
            if (!TSn && FLASH_SPACE) begin
                FLASH_ENn     <= 0;
                FLASH_ENABLED <= 1;
                WRITE_CYCLE   <= !(RnW);
                FLASH_STATE_COUNTER <= 4'h1;
            end
        end
        4'h1 : begin
            FLASH_STATE_COUNTER <= 4'h2;
            FLASH_TACK <= WRITE_CYCLE;
        end
        4'h2 : begin
            if (WRITE_CYCLE) begin
                FLASH_ENABLED <= 0;
                FLASH_TACK    <= 0;
            end else begin
                FLASH_TACK <= 1;
            end
            FLASH_STATE_COUNTER <= 4'h3;
        end
        4'h3 : begin
            if (WRITE_CYCLE) begin
                FLASH_ENn   <= 1;
                WRITE_CYCLE <= 0;
                FLASH_STATE_COUNTER <= 4'h0;
            end else begin
                FLASH_TACK <= 0;
                FLASH_STATE_COUNTER <= 4'h4;
            end
        end
        4'h4 : begin
            FLASH_STATE_COUNTER <= 4'h5;
        end
        4'h5 : begin
            FLASH_ENn     <= 1;
            FLASH_ENABLED <= 0;
            FLASH_STATE_COUNTER <= 4'h0;
        end
    endcase

    end   
end

endmodule
