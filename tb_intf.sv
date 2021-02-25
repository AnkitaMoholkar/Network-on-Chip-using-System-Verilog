// This is the interface definition for the testbench to ps module

interface NOCI(input reg clk, input reg reset);
    	logic noc_to_dev_ctl;
    	logic [7:0] noc_to_dev_data;
    	logic noc_from_dev_ctl;
    	logic [7:0] noc_from_dev_data;
	logic Johans_stupid_signal;
    	modport FI(input clk, input reset, input noc_from_dev_ctl, input noc_from_dev_data, input Johans_stupid_signal) ; //From NOC to PS
    	modport FO(input clk, input reset, output noc_from_dev_ctl, output noc_from_dev_data); //From PS to Baby
    	modport TI(input clk, input reset,input noc_to_dev_ctl,input noc_to_dev_data); //From Baby to PS
    	modport TO(input clk, input reset,output noc_to_dev_ctl,output noc_to_dev_data); //From PS to NOC
endinterface : NOCI
