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
Module Name: U409_ROM_CYCLE.v
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: MC68040/MC68060 ROM cycle state machine.

Date          Who  Description
-----------------------------------
20-MAY-2026   JN   INITIAL CODE

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U409_ROM_CYCLE (

    //Clocks
    input CLK40, RESETn,
    
    //Cycle Start/Termination
    input TSn, TACK_EN,
    output reg ROM_TACK_EN,

    //Address Spaces
    input ROM_SPACE,
    output reg ROM_ENn,
    
    //ROM
    input [1:0] ROM_DELAY
);

//We support multiple timing options for ROM cycle termination.
//The exact timing is user selected by jumpers on the APCI board.

localparam [1:0] IDLE      = 2'b00;
localparam [1:0] WAIT      = 2'b01;
localparam [1:0] END_CYCLE = 2'b10;

localparam [3:0] ROM_DELAY_300 = 4'h9; //275ns
localparam [3:0] ROM_DELAY_200 = 4'h5; //200ns
localparam [3:0] ROM_DELAY_150 = 4'h3; //150ns
localparam [3:0] ROM_DELAY_100 = 4'h1; //100ns

wire [1:0] DELAY_300 = ROM_DELAY == 2'b11;
wire [1:0] DELAY_200 = ROM_DELAY == 2'b10;
wire [1:0] DELAY_150 = ROM_DELAY == 2'b01;
wire [1:0] DELAY_100 = ROM_DELAY == 2'b00;

wire ROM_CYCLE_START = (!TSn && ROM_SPACE);

reg [1:0] ROM_STATE;
reg [3:0] ROM_TACK_COUNTER;

always @(posedge CLK40) begin
    if (!RESETn) begin
        ROM_ENn          <= 1'b1;        
        ROM_STATE        <= IDLE;
        ROM_TACK_EN      <= 1'b0;
        ROM_TACK_COUNTER <= 4'h0;
    end else begin
        case (ROM_STATE)
            IDLE : begin
                if (ROM_CYCLE_START) begin
                    ROM_ENn <= 1'b0;
                    ROM_STATE <= WAIT;
                end else begin
                    ROM_ENn <= 1'b1;
                end
            end
            WAIT : begin
                if ((ROM_TACK_COUNTER == ROM_DELAY_100 && DELAY_100) ||
                    (ROM_TACK_COUNTER == ROM_DELAY_150 && DELAY_150) ||
                    (ROM_TACK_COUNTER == ROM_DELAY_200 && DELAY_200) ||
                    (ROM_TACK_COUNTER == ROM_DELAY_300 && DELAY_300)) begin
                    ROM_TACK_EN <= 1'b1;
                    ROM_STATE <= END_CYCLE;
                end else begin
                    ROM_TACK_COUNTER <= ROM_TACK_COUNTER + 1;
                end
            end
            END_CYCLE : begin
                if (TACK_EN) begin
                    ROM_TACK_EN <= 1'b0;
                    ROM_TACK_COUNTER <= 4'h0;
                    ROM_STATE <= IDLE;
                end
            end
        endcase
    end
end

endmodule