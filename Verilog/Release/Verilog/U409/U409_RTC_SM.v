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
Module Name: U409_TRANSFER_ACK
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: MC68040/MC68060 TRANSFER ACK

Date          Who  Description
-----------------------------------
18-OCT-2025   JN   Move RTC SM to dedicated module.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U409_RTC_SM (

    //Clocks
    input CLK40,
    
    //Cycle Start/Termination
    input RESETn, TSn, RTC_SPACE, 

    //Chip Enable
    output reg RTC_ENn, RTC_TACK
);


////////////////
// RTC CYCLE //
//////////////

localparam [6:0] RTC_CYCLE_COUNTER = 7'd80;

reg [6:0] RTC_COUNTER;
reg [3:0] RTC_STATE;

always @(posedge CLK40) begin
    if (!RESETn) begin
        RTC_ENn <= 1;
        RTC_TACK <= 0;
        RTC_STATE <= 4'h0;
        RTC_COUNTER <= 7'b0;
    end else begin
        case (RTC_STATE)        
            4'h0 : begin
                if (!TSn && RTC_SPACE) begin
                    RTC_STATE <= 4'h1;
                    RTC_ENn <= 0;
                end
            end
            4'h1 : begin
                if (RTC_COUNTER == RTC_CYCLE_COUNTER) begin
                    RTC_TACK <= 1;
                    RTC_STATE <= 4'h2;
                end else begin
                    RTC_COUNTER ++;
                end
            end
            4'h2 : begin
                RTC_TACK <= 0;
                RTC_STATE <= 4'h3;
            end
            4'h3 : begin
                RTC_STATE <= 4'h4;
            end
            4'h4 : begin
                RTC_ENn <= 1;
                RTC_COUNTER <= 7'b0;
                RTC_STATE <= 4'h0;
            end
        endcase
    end
end

endmodule
