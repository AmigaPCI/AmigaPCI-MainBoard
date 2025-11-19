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
Module Name: U109_BREIDGE_REG
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Bridge registers.

Date          Who  Description
-----------------------------------
18-NOV-2025   JN   INITIAL CODE

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U109_REGISTERS (

        //Clocks
        input CLK40,

        //Busses
        input [3:0] REG_ADDRESS, //This is AD[5:2]
        input [31:30] D,
        output reg [31:0] D_OUT,

        //Cycle Start/Terminate
        input RESETn, RnW, TSn, BRIDGE_REG_SPACE, INT_STATUSn,        
        output reg REGISTER_CYCLE, REG_TACK, INT_ENn

);

//A subset of the CONFIG0 registers are implemented for the
//purpose of device identification and hardware version reporting.
//Divide the register offset by 4 to get the hex value in the specs.

localparam VENDOR_ID   = 16'd600; //0258h
localparam DEVICE_ID   = 12'd1234; //4D2h
localparam CLASS_CODE  = 24'h60000;
localparam REVISION_ID = 8'h0;

reg REG_PCI_RESET, WRITE_CYCLE;
reg [3:0] REG_CYCLE_STATE;

always @(posedge CLK40) begin
    if (!RESETn) begin
        D_OUT <= 32'h0;
        REGISTER_CYCLE <= 0;
        REG_TACK <= 0;
        INT_ENn <= 1;
        REG_PCI_RESET <= 0;
        WRITE_CYCLE <= 0;
        REG_CYCLE_STATE <= 4'h0;
    end else begin
        case (REG_CYCLE_STATE)

            4'h0 : begin
                if (!TSn && BRIDGE_REG_SPACE) begin
                    REGISTER_CYCLE <= 1;
                    WRITE_CYCLE <= (!RnW);
                    REG_CYCLE_STATE <= 4'h1;
                end else begin
                    REGISTER_CYCLE <= 0;
                end
            end

            4'h1 : begin
                case (REG_ADDRESS)
                    4'h0 : begin //0x00
                        if (WRITE_CYCLE) begin
                            REG_PCI_RESET <= D[31];
                            INT_ENn <= !(D[30]);
                        end else begin 
                            D_OUT <= {REG_PCI_RESET, !(INT_ENn), INT_STATUSn, 1'b0, DEVICE_ID, VENDOR_ID};
                        end
                    end
                    4'h2 : begin //0x08
                        D_OUT <= {CLASS_CODE, REVISION_ID}; 
                    end
                    default : D_OUT <= 32'h0;
                endcase
                REG_TACK <= 1;
                REG_CYCLE_STATE <= 4'h2;
            end

            4'h2 : begin
                REG_TACK <= 0;
                REG_CYCLE_STATE <= 4'h3;
            end

            4'h3 : begin
                REG_CYCLE_STATE <= 4'h0;
            end

        endcase
    end
end

endmodule