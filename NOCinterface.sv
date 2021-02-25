`include "nochw2.sv"
`include "perm.sv"
`include "m55.sv"
module NOCinterface(input clk, input reset, input tod_ctl, input [7:0] tod_data, output frm_ctl, output [7:0] frm_data, output pushout);


perm_blk p(clk,reset,pushin,stopin,firstin,din,
    m1ax,m1ay,m1rd,m1wx,m1wy,m1wr,m1wd,
    m2ax,m2ay,m2rd,m2wx,m2wy,m2wr,m2wd,
    m3ax,m3ay,m3rd,m3wx,m3wy,m3wr,m3wd,
    m4ax,m4ay,m4rd,m4wx,m4wy,m4wr,m4wd,
    pushout,stopout,firstout,dout);
    
m55 m1(clk,reset,m1ax,m1ay,m1rd,m1wx,m1wy,m1wr,m1wd);
m55 m2(clk,reset,m2ax,m2ay,m2rd,m2wx,m2wy,m2wr,m2wd);
m55 m3(clk,reset,m3ax,m3ay,m3rd,m3wx,m3wy,m3wr,m3wd);
m55 m4(clk,reset,m4ax,m4ay,m4rd,m4wx,m4wy,m4wr,m4wd);

noc_intf n(clk,reset,
    tod_ctl,tod_data,frm_ctl,frm_data,
    pushin,firstin,stopin,din,pushout,firstout,stopout,dout);
endmodule
