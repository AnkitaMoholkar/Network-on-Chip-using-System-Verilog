`include "switch.sv"
`include "blobk.sv"

module ps (NOCI.TI t, NOCI.FO f); 


NOCI s0 (t.clk, t.reset);
NOCI s1 (t.clk, t.reset);
NOCI s2 (t.clk, t.reset);
NOCI s3 (t.clk, t.reset);

switch dut (t.clk, t.reset, t.noc_to_dev_ctl, t.noc_to_dev_data, f.noc_from_dev_ctl, f.noc_from_dev_data, s1.TO, s1.FI,s2.TO, s2.FI,s3.TO, s3.FI, s0.TO, s0.FI);


blobk device0 ( .clk(s0.clk), .reset(s0.reset), .noc_to_dev_ctl(s0.noc_to_dev_ctl), .noc_to_dev_data(s0.noc_to_dev_data),
 .noc_from_dev_ctl(s0.noc_from_dev_ctl), .noc_from_dev_data(s0.noc_from_dev_data), .Johans_stupid_signal(s0.Johans_stupid_signal));
blobk device1 (.clk(s1.clk), .reset(s1.reset), .noc_to_dev_ctl(s1.noc_to_dev_ctl), .noc_to_dev_data(s1.noc_to_dev_data),
 .noc_from_dev_ctl(s1.noc_from_dev_ctl), .noc_from_dev_data(s1.noc_from_dev_data), .Johans_stupid_signal(s1.Johans_stupid_signal));
blobk device2 (.clk(s2.clk), .reset(s2.reset), .noc_to_dev_ctl(s2.noc_to_dev_ctl), .noc_to_dev_data(s2.noc_to_dev_data),
 .noc_from_dev_ctl(s2.noc_from_dev_ctl), .noc_from_dev_data(s2.noc_from_dev_data), .Johans_stupid_signal(s2.Johans_stupid_signal));
blobk device3 ( .clk(s3.clk), .reset(s3.reset), .noc_to_dev_ctl(s3.noc_to_dev_ctl), .noc_to_dev_data(s3.noc_to_dev_data),
 .noc_from_dev_ctl(s3.noc_from_dev_ctl), .noc_from_dev_data(s3.noc_from_dev_data), .Johans_stupid_signal(s3.Johans_stupid_signal));
 


endmodule 
