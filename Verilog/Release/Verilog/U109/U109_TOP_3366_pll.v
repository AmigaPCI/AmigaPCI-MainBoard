module U109_TOP_3366_pll(PACKAGEPIN,
                    PLLOUTCOREA,
                    PLLOUTCOREB,
                    PLLOUTGLOBALA,
                    PLLOUTGLOBALB,
                    RESET);

inout PACKAGEPIN;
input RESET;    /* To initialize the simulation properly, the RESET signal (Active Low) must be asserted at the beginning of the simulation */ 
output PLLOUTCOREA;
output PLLOUTCOREB;
output PLLOUTGLOBALA;
output PLLOUTGLOBALB;

SB_PLL40_2F_PAD U109_TOP_pll_inst(.PACKAGEPIN(PACKAGEPIN),
                                  .PLLOUTCOREA(PLLOUTCOREA),
                                  .PLLOUTCOREB(PLLOUTCOREB),
                                  .PLLOUTGLOBALA(PLLOUTGLOBALA),
                                  .PLLOUTGLOBALB(PLLOUTGLOBALB),
                                  .EXTFEEDBACK(),
                                  .DYNAMICDELAY(),
                                  .RESETB(RESET),
                                  .BYPASS(1'b0),
                                  .LATCHINPUTVALUE(),
                                  .LOCK(),
                                  .SDI(),
                                  .SDO(),
                                  .SCLK());

//\\ Fin=40, Fout=80;
defparam U109_TOP_pll_inst.DIVR = 4'b0000;
defparam U109_TOP_pll_inst.DIVF = 7'b0000001;
defparam U109_TOP_pll_inst.DIVQ = 3'b100;
defparam U109_TOP_pll_inst.FILTER_RANGE = 3'b011;
defparam U109_TOP_pll_inst.FEEDBACK_PATH = "DELAY";
defparam U109_TOP_pll_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
defparam U109_TOP_pll_inst.FDA_FEEDBACK = 4'b0000;
defparam U109_TOP_pll_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
defparam U109_TOP_pll_inst.FDA_RELATIVE = 4'b0000;
defparam U109_TOP_pll_inst.SHIFTREG_DIV_MODE = 2'b00;
defparam U109_TOP_pll_inst.PLLOUT_SELECT_PORTA = "GENCLK";
defparam U109_TOP_pll_inst.PLLOUT_SELECT_PORTB = "GENCLK_HALF";
defparam U109_TOP_pll_inst.ENABLE_ICEGATE_PORTA = 1'b0;
defparam U109_TOP_pll_inst.ENABLE_ICEGATE_PORTB = 1'b0;

endmodule
