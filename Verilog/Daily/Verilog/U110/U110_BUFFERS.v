module U110_BUFFERS (

    input RESETn, ATA_ENn, RnW, BGn,
    input [1:0] SIZ,

    output IDELENn, IDEHRENn, IDEHWENn, IDEDIR, BURSTn, BUSDIR

);

  /////////////////
 // ATA BUFFERS //
/////////////////

assign IDEHRENn = !(RESETn && !ATA_ENn &&  RnW);
assign IDEHWENn = !(RESETn && !ATA_ENn && !RnW);

assign IDELENn  = 1;
assign IDEDIR = !RnW;

  /////////////////
 // BURST CYCLE //
/////////////////

assign BURSTn = !(SIZ[1] && SIZ[0]);

  ///////////////////
 // BUS DIRECTION //
///////////////////

//Sets the direction of unidirectional busses and signals, like the A bus or _TS.
//Will reverse direction during PCI DMA.

//0 = CPU has the bus.
//1 = PCI has the bus.

//assign BUSDIR = BGn;
assign BUSDIR = 1'b0;

endmodule
