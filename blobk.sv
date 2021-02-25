`include "m55.sv" 
`include "nochw2.sv"
`include "perm.sv"

module blobk ( input clk, input reset, input noc_to_dev_ctl, input [7:0] noc_to_dev_data, 
output noc_from_dev_ctl, output [7:0] noc_from_dev_data, Johans_stupid_signal); 


logic pushout, stopout, pushin, stopin, firstin, firstout, m1wr, m2wr, m3wr, m4wr;
logic [2:0] m1rx, m1ry, m1wx, m1wy, m2rx, m2ry, m2wx, m2wy, m3rx, m3ry, m3wx, m3wy, m4rx, m4ry, m4wx, m4wy; 
logic [63:0] m1rd, m1wd, m2rd, m2wd, m3rd, m3wd, m4rd, m4wd, din, dout; 
 
 noc_intf n (clk, reset, noc_to_dev_ctl, noc_to_dev_data,
 noc_from_dev_ctl, noc_from_dev_data, pushin, firstin, 
 stopin,din, pushout, firstout, stopout, dout, Johans_stupid_signal); 
 
 perm_blk p(clk,reset,pushin,stopin,firstin,din,
    m1rx,m1ry,m1rd,m1wx,m1wy,m1wr,m1wd,
    m2rx,m2ry,m2rd,m2wx,m2wy,m2wr,m2wd,
    m3rx,m3ry,m3rd,m3wx,m3wy,m3wr,m3wd,
    m4rx,m4ry,m4rd,m4wx,m4wy,m4wr,m4wd,
    pushout,stopout,firstout,dout);
    
m55 m11(clk,reset,m1rx,m1ry,m1rd,m1wx,m1wy,m1wr,m1wd);
m55 m21(clk,reset,m2rx,m2ry,m2rd,m2wx,m2wy,m2wr,m2wd);
m55 m31(clk,reset,m3rx,m3ry,m3rd,m3wx,m3wy,m3wr,m3wd);
m55 m41(clk,reset,m4rx,m4ry,m4rd,m4wx,m4wy,m4wr,m4wd);

endmodule 
