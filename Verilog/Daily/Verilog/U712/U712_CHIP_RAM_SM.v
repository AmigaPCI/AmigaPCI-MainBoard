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

RTL MODULE: U712_CHIP_RAM

Engineer: Jason Neus
Design Name: U712
Module Name: U712_TOP
Project Name: AmigaPCI
Target Devices: iCE40-HX4K-TQ144

Description: Chip RAM state machine

Revision History
Date          Who  Description
-----------------------------------
03-OCT-2025 : JN   First release

GitHub: https://github.com/jasonsbeer/AmigaPCI

iceprog D:\AmigaPCI\U712\U712_icecube\U712_icecube_Implmnt\sbt\outputs\bitmap\U712_TOP_bitmap.bin
*/
 
module U712_CHIP_RAM_SM
(
    //Clocks
    input CLK40, CLK7, C1, C3,     

    //Cycle Start/Termination
    input RESETn,

    //Agnus
    input DBRn, AWEn, RAS1n, RAS0n, AGNUS_REV,
    input [9:0] DRA,
    
    //SDRAM Control Signals
    output BANK1, BANK0,
    output reg SDRAM_CSn, RASn, CASn, WEn, CLK_EN,
    output reg [10:0] CMA,
    
    //Buffers
    output SAB_LATCH_EN, SAB_LATCH_CLK,
    output reg DB_ENn, DB_DIR, CPU_CYCLE, DMA_CYCLE, WRITE_CYCLE
);

assign SAB_LATCH_EN  = 0; //0=Real Time
assign SAB_LATCH_CLK = 0;

/////////////////
// PARAMETERS //
///////////////

//THE SDRAM COMMAND CONSTANTS ARE: _CS, _RAS, _CAS, _WE
localparam [3:0] NOP             = 4'b1111;
localparam [3:0] PRECHARGE       = 4'b0010;
localparam [3:0] BANKACTIVATE    = 4'b0011;
localparam [3:0] READ            = 4'b0101;
localparam [3:0] WRITE           = 4'b0100;
localparam [3:0] AUTOREFRESH     = 4'b0001;
localparam [3:0] MODEREGISTER    = 4'b0000;
localparam [8:0] REFRESH_DEFAULT = 9'd290;

///////////
// SYNC //
/////////

//Synchronize signals from the 7MHz domain to the 40MHz domain.

reg [1:0] C1_SYNC, C3_SYNC, RAS_SYNC, DBRn_SYNC, AWEn_SYNC;

always @(negedge CLK40) begin
    if (!RESETn) begin
        C1_SYNC   <= 2'b0;
        C3_SYNC   <= 2'b0;
        RAS_SYNC  <= 2'b0;
        DBRn_SYNC <= 2'b0;
        AWEn_SYNC <= 2'b0;
    end else begin
        C1_SYNC[1] <= C1_SYNC[0];
        C1_SYNC[0] <= C1;

        C3_SYNC[1] <= C3_SYNC[0];
        C3_SYNC[0] <= C3;

        RAS_SYNC[1] <= RAS_SYNC[0];
        RAS_SYNC[0] <= RAS1n != RAS0n;

        DBRn_SYNC[1] <= DBRn_SYNC[0];
        DBRn_SYNC[0] <= DBRn;

        AWEn_SYNC[1] <= AWEn_SYNC[0];
        AWEn_SYNC[0] <= AWEn;
    end
end

///////////////////////////////
// AGNUS DRAM ADDRESS LATCH //
/////////////////////////////

//Latch the row and column addresses in the 7MHz domain.
    
reg [9:0] ROW_ADDRESS;
always @(posedge C3) begin
    if (!RESETn) begin
        ROW_ADDRESS <= 10'b0;
    end else begin
        ROW_ADDRESS <= AGNUS_REV ? DRA : { RAS0n, DRA[9:1] };
    end
end

reg [8:0] COL_ADDRESS;
always @(negedge C1) begin
    if (!RESETn) begin
        COL_ADDRESS <= 9'b0;
    end else begin
        if (AGNUS_REV) begin
            COL_ADDRESS <= DRA[9:1];
        end else begin
            COL_ADDRESS <= {1'b0, DRA[9:2]};
        end
    end
end

//////////////////////
// REFRESH COUNTER //
////////////////////

//THE REFRESH OPERATION MUST BE PERFORMED 8192 TIMES EVERY 64ms.
//SO...8192 TIMES IN 64,000,000ns. THATS ONCE EVERY 7812.5ns.
//7812.5ns IS EQUAL TO APPROX...

// 28 3.55MHz CLOCK CYCLES
// 56 7.16MHz CLOCK CYCLES
//185 25MHz CLOCK CYCLES
//244 33MHz CLOCK CYCLES
//296 40MHz CLOCK CYCLES
//370 50MHz CLOCK CYCLES

reg REFRESH;
reg [8:0] REFRESH_COUNTER;
wire REFRESH_RST = (!RESETn || SDRAM_CMD == AUTOREFRESH) ? 1'b1 : 1'b0;

always @(negedge CLK40, posedge REFRESH_RST) begin
    if (REFRESH_RST) begin
        REFRESH_COUNTER <= 9'b0;
        REFRESH <= 0;
    end else begin
        if (REFRESH_COUNTER == REFRESH_DEFAULT) begin
            REFRESH <= 1;
        end else begin
            REFRESH_COUNTER ++;
            REFRESH <= 0;
        end
    end
end

/////////////////////////////
// CHIP RAM STATE MACHINE //
///////////////////////////

/*
THIS IS THE AGNUS DRAM MULTIPLEXING.
MA9 ONLY EXISTS ON 8375 VARIANTS.
IN AGNUS 8372A, _RAS0 = A19. _RAS1 = A19 INVERSE.

     MA9   MA8 MA7 MA6 MA5 MA4 MA3 MA2 MA1 MA0
    ----- -------------------------------------
ROW: A19   A17 A16 A15 A14 A13 A12 A11 A10  A9
COL: A20   A18  A8  A7  A6  A5  A4  A3  A2  A1

AGNUS MULTIADAPTER ADDRESS SIGNAL CONFIGURATION

      DRA9 DRA8 DRA7 DRA6 DRA5 DRA4 DRA3 DRA2 DRA1 DRA0
      -------------------------------------------------
8372A  MA8  MA7  MA6  MA5  MA4  MA3  MA2  MA1  MA0  x
8375   MA9  MA8  MA7  MA6  MA5  MA4  MA3  MA2  MA1  MA0

           DRA9 DRA8 DRA7 DRA6 DRA5 DRA4 DRA3 DRA2 DRA1 DRA0
           -------------------------------------------------
8372A ROW  A17  A16  A15  A14  A13  A12  A11  A10  A9   x
      COL  A18  A8   A7   A6   A5   A4   A3   A2   A1   x
8375  ROW  A19  A17  A16  A15  A14  A13  A12  A11  A10  A9
      COL  A20  A18  A8   A7   A6   A5   A4   A3   A2   A1
*/

assign BANK1 = 1;
assign BANK0 = 1;

reg SDRAM_CONFIGURED;
reg [3:0] SDRAM_CMD;
reg [3:0] SDRAM_STATE;

//Assert the enable signal of the chip ram data bridge.
//This is done in the 7MHz domain.
wire DMA_A1 = AGNUS_REV ? DRA[0] : DRA[1];
always @(negedge CLK7) begin
    if (!RESETn) begin
        DB_ENn <= 1;
        DB_DIR <= 1;
    end else begin
        DB_ENn <= !(!DBRn && DMA_A1 && (RAS1n != RAS0n));
        DB_DIR <= !AWEn;
    end
end

//The SDRAM state machine.
always @(negedge CLK40) begin
    if (!RESETn) begin
        DMA_CYCLE <= 0;
        CPU_CYCLE <= 0;
        SDRAM_CONFIGURED <= 0;
        SDRAM_CMD <= NOP;
        SDRAM_STATE <= 4'h0;
        SDRAM_CSn <= 1;
        RASn <= 1;
        CASn <= 1;
        WEn <= 1;
        CMA <= 11'b0;
        CLK_EN <= 1;
        WRITE_CYCLE <= 0;
    end else begin

        SDRAM_CSn <= SDRAM_CMD[3];
        RASn  <= SDRAM_CMD[2];
        CASn  <= SDRAM_CMD[1];
        WEn   <= SDRAM_CMD[0];

        case (SDRAM_CMD)
            PRECHARGE    : CMA <= 11'b10000000000;
            MODEREGISTER : CMA <= 11'b00000100000; //CAS latency = 2, 1 word sequential bursts.
            BANKACTIVATE : CMA <= {1'b0, ROW_ADDRESS};
            READ, WRITE  : CMA <= {2'b10, COL_ADDRESS}; //Include auto precharge.
            default      : CMA <= 11'b0;
        endcase

        if (!SDRAM_CONFIGURED) begin
            if (SDRAM_STATE != 4'h0) begin SDRAM_STATE ++; end
            case (SDRAM_STATE)
                4'h0 : begin
                    SDRAM_CMD <= PRECHARGE;
                    SDRAM_STATE <= 4'h1;
                end
                4'h2 : begin
                    SDRAM_CMD <= MODEREGISTER;
                end
                4'h5, 4'h8 : begin
                    SDRAM_CMD <= AUTOREFRESH;
                end
                4'hB : begin
                    SDRAM_CONFIGURED <= 1;
                    SDRAM_STATE <= 4'h0;
                end
                default : begin
                    SDRAM_CMD <= NOP;
                end
            endcase
        end else begin
            case (SDRAM_STATE)
                4'h0 : begin
                    if (REFRESH && !C1_SYNC[1] && !C3_SYNC[1]) begin
                        //Always refresh during S3 or S0.
                        SDRAM_CMD <= AUTOREFRESH;
                        SDRAM_STATE <= 4'h1;
                    end else if (RAS_SYNC == 2'b11) begin
                        SDRAM_CMD   <= BANKACTIVATE;
                        WRITE_CYCLE <= !AWEn_SYNC[1];
                        if (DBRn_SYNC[1]) begin
                            CPU_CYCLE <= 1;
                        end else begin
                            DMA_CYCLE <= 1;
                        end
                        SDRAM_STATE <= 4'h3;
                    end
                end

                //REFRESH STATES
                //-----------------------------------
                4'h1 : begin SDRAM_CMD <= NOP; SDRAM_STATE <= 4'h2; end
                4'h2 : begin SDRAM_STATE <= 4'h0; end

                //SDRAM CYCLE STATES
                //-----------------------------------
                4'h3 : begin
                    SDRAM_STATE <= 4'h4;
                    if (!WRITE_CYCLE) begin
                        //Read Cycle
                        SDRAM_CMD <= READ;
                    end else begin
                        //Write Cycle
                        SDRAM_CMD <= WRITE;
                    end
                end

                4'h4 : begin
                    SDRAM_CMD <= NOP;
                    SDRAM_STATE <= 4'h5;
                end

                4'h5 : begin
                    CLK_EN <= WRITE_CYCLE;
                    SDRAM_STATE <= 4'h6;
                end

                4'h6 : begin
                    if (!C1_SYNC[1] && !C3_SYNC[1]) begin //Wait for State 7
                        SDRAM_STATE <= 4'h7;
                    end
                end

                4'h7 : begin
                    SDRAM_STATE <= 4'h8;
                end

                4'h8 : begin
                    DMA_CYCLE <= 0;
                    CPU_CYCLE <= 0;           
                    CLK_EN <= 1;
                    WRITE_CYCLE <= 0;
                    SDRAM_STATE <= 4'h0;
                end
            endcase
        end
    end
end

endmodule