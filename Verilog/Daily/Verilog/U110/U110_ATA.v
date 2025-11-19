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
Module Name: U110_ATA
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: ATA Controller

Date          Who  Description
-----------------------------------
02-JUL-2025   JN   Initial release for Rev 6.0 hardware.
16-OCT-2025   JN   Added user selectable ATA timing.

GitHub: https://github.com/jasonsbeer/AmigaPCI
*/

module U110_ATA (

    //Clocks
    input CLK40,
    
    //Cycle Start/Terminate
    input RESETn, TSn, RnW,
    output reg ATA_TACK, ATA_LATCH,

    //ATA Addresses
    input ATA_ENn, PPIO, SPIO, PCS1 , PCS0, SCS1, SCS0,

    //ATA Chip Selects
    output CS0_PRIn, CS1_PRIn, CS0_SECn, CS1_SECn,
    output DIOR_PRIn, DIOW_PRIn, DIOR_SECn, DIOW_SECn
    
);

  ///////////////////////////
 // ATA TIMING PARAMETERS //
///////////////////////////

//T1 IS THE TIME AFTER ADDRESS IS VALID THAT WE ASSERT _DIOR/_DIOW
//T2 IS THE TIME AFTER ASSERTION OF _DIOR/_DIOW THAT READ DATA IS VALID OR WRITE DATA CAN BE LATCHED.
//T0 IS THE TOTAL CYCLE TIME.
//THESE TIMES ARE CUMULATIVE. THEY ARE THE TOTAL CLOCKS TO THAT POINT STARTING AT BASE ZERO.

//THESE ARE THE RULES FOR THE FINITE STATE MACHINE TO WORK.
//   NO TWO VALUES CAN BE THE SAME.
//   T1 MAY BE ZERO.
//   T2 MUST BE AT LEAST 2 GREATER THAN T1.

//SUBTRACT ONE CLOCK FROM T1 BECAUSE THE ADDRESS IS VALID ONE CLOCK (25ns) BEFORE _TS ASSERTS.

//For read cycles, We wait for T2 to be met and then assert _TACK on the next clock. _DIOR is then negated the clock after that.
//For write cycles, we negate _DIOW at T2 and then assert _TACK one clock after that.

//localparam M0_T1 = 8'd2;  //70ns
//localparam M0_T2 = 8'd12; //290ns
//localparam M0_T0 = 8'd24; //600ns

localparam M2_T1 = 4'd1; //30ns  1
localparam M2_T2 = 4'd5; //100ns 5
localparam M2_T0 = 4'd9; //240ns 9

localparam M4_T1 = 4'd0; //25ns  0
localparam M4_T2 = 4'd3; //70ns  3
localparam M4_T0 = 4'd5; //120ns 5

wire CS_PRIMARY   = (!CS0_PRIn || !CS1_PRIn);
wire CS_SECONDARY = (!CS0_SECn || !CS1_SECn);

wire [3:0] P_T1 = PPIO ? M4_T1 : M2_T1;
wire [3:0] S_T1 = SPIO ? M4_T1 : M2_T1;

wire [3:0] T1_ACTIVE = P_CYCLE ? (PPIO ? M4_T1 : M2_T1)
                               : (SPIO ? M4_T1 : M2_T1);

wire [3:0] T2_ACTIVE = P_CYCLE ? (PPIO ? M4_T2 : M2_T2)
                               : (SPIO ? M4_T2 : M2_T2);

wire [3:0] T0_ACTIVE = P_CYCLE ? (PPIO ? M4_T0 : M2_T0)
                               : (SPIO ? M4_T0 : M2_T0);

  //////////////////////
 // ATA CHIP SELECTS //
//////////////////////

assign CS0_PRIn = !(!ATA_ENn && PCS0);
assign CS1_PRIn = !(!ATA_ENn && PCS1);
assign CS0_SECn = !(!ATA_ENn && SCS0);
assign CS1_SECn = !(!ATA_ENn && SCS1);

assign DIOR_PRIn = !(RW_EN && !WRITE_CYCLE && P_CYCLE);
assign DIOW_PRIn = !(RW_EN &&  WRITE_CYCLE && P_CYCLE);
assign DIOR_SECn = !(RW_EN && !WRITE_CYCLE && S_CYCLE);
assign DIOW_SECn = !(RW_EN &&  WRITE_CYCLE && S_CYCLE);

  ///////////////////////
 // ATA STATE MACHINE //
///////////////////////

reg P_CYCLE, S_CYCLE, RW_EN, WRITE_CYCLE, ATA_PENDING;
reg [3:0] CYCLE_COUNT;

always @(posedge CLK40) begin
    if (!RESETn) begin        
        ATA_TACK    <= 0;
        WRITE_CYCLE <= 0;
        RW_EN       <= 0;
        P_CYCLE     <= 0;
        S_CYCLE     <= 0;
        ATA_LATCH   <= 1;
        ATA_PENDING <= 0;
        CYCLE_COUNT <= 4'h0;
    end else begin

        if (P_CYCLE || S_CYCLE) begin

                if (!TSn && !ATA_ENn) begin
                    ATA_PENDING <= 1;
                 end
                 
                 CYCLE_COUNT <= CYCLE_COUNT + 1;

                if (CYCLE_COUNT == T1_ACTIVE) begin
                    RW_EN <= 1;
                end else if (CYCLE_COUNT == T2_ACTIVE - 1) begin
                    ATA_TACK <= 1;
                end else if (CYCLE_COUNT == T2_ACTIVE) begin
                    RW_EN <= !(WRITE_CYCLE);
                    ATA_TACK <= 0;                
                end else begin
                    if (CYCLE_COUNT == T0_ACTIVE) begin
                        P_CYCLE <= 0;
                        S_CYCLE <= 0;
                        RW_EN <= 0;
                    end else if (CYCLE_COUNT == T2_ACTIVE + 2) begin
                        RW_EN <= 0;
                    end
                end

        end else begin

            if ((!TSn && !ATA_ENn) || ATA_PENDING) begin
                ATA_PENDING <= 0;
                WRITE_CYCLE <= !RnW;
                CYCLE_COUNT <= 4'h1;
                P_CYCLE <= CS_PRIMARY;
                S_CYCLE <= CS_SECONDARY;
                RW_EN <= ((CS_PRIMARY && P_T1 == 4'h0) || (CS_SECONDARY && S_T1 == 4'h0));
            end

        end
    end
end

endmodule
