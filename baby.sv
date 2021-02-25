// This is a simple test bench for the permutation block
//
`timescale 1ns/10ps

`include "tb_intf.sv"
`include "ps.sv"


module top();
reg clk,reset;
reg firstoutH;
reg [63:0] din;
reg [5:0] dix;	// data index for 1600 bits
reg errpos=0;

wire pushout;
reg stopout;
reg pushoutH;
wire [63:0] dout;
reg [63:0] doutH;
NOCI bif(clk,reset);


`protect

int gcnt=0;

typedef struct packed {
	reg [5:0] dix;
	reg [63:0] dat;
} DD;

typedef enum {
    NoError,
    ReadNoData,
    WriteStopin,
    BadAddress
} ERRCD;

typedef struct packed {
    ERRCD code;
    reg [1:0] errtype;
    reg [7:0] datalen;
} ERRBLK;

ERRBLK experrs[$];

typedef enum {
    CCNOP,
    CCRead,
    CCWrite,
    CCReadResp,
    CCWriteResp,
    CCMessage,
    CCRes0,
    CCRes1
} CCODES;

int picnt=80;
int damt;

DD fifoout[$];
DD dd_exp;

//reg tod_ctl;
//reg [7:0] tod_data;
//reg frm_ctl;
//reg [7:0] frm_data;
reg [63:0] pdata[$];

reg [7:0] idst;
reg [7:0] isrc;
reg [63:0] w64;
int dcnt;

reg stopinlow;
reg pushoutHigh;
reg readSeen;

semaphore BUS;

default clocking ckb @(posedge(clk)) ;



endclocking

task die(input string msg);
	$display("\n\n\n- - - - - - - - - - - Error - - - - - - - - - -");
	$display("  at %8.1fns",$realtime/10);
	$display("  %s",msg);
	$display("- - - - - - - - - - - Error - - - - - - - - - -\n\n\n");
	errpos=1;
	#20;
	$finish;
endtask : die

task push_out(reg [5:0] dix,reg [63:0] dat);
	DD di;
	di.dix=dix;
	di.dat=dat;
	fifoout.push_front(di);
endtask : push_out

initial begin
    reg [7:0] adl,cmd;
    reg [7:0] msgA,msgD;
    reg [63:0] rdata,edata;
    int rdlen;
    DD de;
    ERRBLK eblk;
    stopinlow=1;
    readSeen=0;
    
    ##4 ;
    forever begin
        ##1;
        if (!bif.noc_from_dev_ctl) die("No control from NOC interface when not in message");
        cmd=bif.noc_from_dev_data;
        case(cmd[2:0])
            CCNOP,CCRes0,CCRes1: continue;
            CCRead: begin
                die("Got a read from the NOC interface");
            end
            CCWrite: begin
                die("Got a write from the NOC interface");
            end
            CCReadResp: begin
                ##3; // ignore the src/dest for now
                adl=bif.noc_from_dev_data;
                if(cmd[7:6]!=0) die("Got an error on read response");
                while(adl > 0) begin
                    rdata=0;
                    for(int ix=0; ix < 8; ix+=1) begin
                        ##1;
                        rdata={bif.noc_from_dev_data,rdata[63:8]};
                    end
                    adl-=8;
                    de=fifoout.pop_back();
                    edata=de.dat;
                    if(rdata !== edata) begin
                        die($sformatf("Error received %08x, expected %08x seq %d",rdata,edata,de.dix));
                    end else begin
//                        $display("%08x worked",rdata);
                    end
                end
                #1;
                readSeen=1;
            end
            CCWriteResp: begin
                ##3; // ignore the src/dest for now
                adl=bif.noc_from_dev_data;
                eblk=experrs.pop_back();
                if(eblk.errtype != cmd[7:6]) die($sformatf("Expected error code wrong. Got %x expected %x",
                    cmd[7:6],eblk.code));
                if(eblk.errtype == 1) begin
                    if(adl != eblk.code) die($sformatf("Expecting error reason %x, got %x",eblk.code,adl));
                end else begin
                    if(adl != eblk.datalen) die($sformatf("Data length error on write resp Expected %x, got %x",
                        eblk.datalen,adl));
                end
            end
            CCMessage: begin
                ##3;    // ignore the src/dst for now
                msgA=bif.noc_from_dev_data;
                ##1;
                msgD=bif.noc_from_dev_data;
                if(msgA==8'h42 && msgD==8'h78) begin
                    #1;
                    stopinlow=1;
                end else if(msgA==8'h17 && msgD==8'h12) begin 
                    #1;
                    pushoutHigh=1;
                end else begin
                    die($sformatf("Got an unexpected message %x %x",msgA,msgD));
                end
            end
        
        endcase
    end
end
// handle the read requests...
initial begin
    int dleft;
    reg [1:0] alen;
    reg [2:0] dlen;
    reg [7:0] saddr,daddr;
    forever begin
        ##1;
        if (!pushoutHigh) continue;
//        $display("pushoutHigh %t",$realtime);
        dleft=200;
        daddr=8'h40;
        saddr=$urandom_range(8'h80,8'hf0);
        while(dleft > 0) begin
            ##1 #1;
            alen=1;   // keep address shorter
            dlen=$urandom_range(3,7);
            while( (1<<dlen) > dleft ) dlen=$urandom_range(3,7);
            BUS.get(1);
//            $display("Read Request has the bus %t",$realtime);
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data={alen,dlen,3'b001};
            ##1 #1;
            bif.noc_to_dev_ctl=0;
            bif.noc_to_dev_data=daddr;
            ##1 #1;
            bif.noc_to_dev_ctl=0;
            bif.noc_to_dev_data=saddr;
            for(int ix=0; ix<(1<<alen); ix+=1) begin
                ##1 #1;
                bif.noc_to_dev_ctl=0;
                bif.noc_to_dev_data=0;
            end
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data=0;
            dleft -= (1<<dlen);
//            $display("Read Request releasing the bus %t",$realtime);
            BUS.put(1); // release the bus and wait for the data to come back
            while(!readSeen) ##1;
            readSeen=0;
        end
        ##1 #1;
        pushoutHigh=0;
    end
end

task push_in(reg [5:0] dixx,reg [63:0] datx);
    reg [2:0] dls[$];
    int dtg;
    int ra;
    reg [2:0] dl;
    reg [1:0] al;
    ERRBLK eb;
    pdata.push_front(datx);
    if(pdata.size()>=25) begin
        while( !stopinlow ) ##1;
        idst=8'h40;
        isrc=$urandom_range(8'h80,8'hF0);
        dtg=200;
        dls.delete();
        while(dtg > 0) begin
            dl=$urandom_range(3,7);
            ra=(1<<dl);
            if(ra > dtg) continue;
            dtg -= ra;
            dls.push_front(dl);
        end
//        $display("dls debug = = = = = = = = = = = =");
        while(dls.size()>0) begin
            dl=dls.pop_back();
//            $display("dl %d ra %d",dl,1<<dl);
            BUS.get(1);
//            $display("Pushin grabbed bus %t",$realtime);
            al=0;
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data={al,dl,3'h2};
            ##1 #1;
            bif.noc_to_dev_ctl=0;
            bif.noc_to_dev_data=idst;
            ##1 #1;
            bif.noc_to_dev_data=isrc;
            for(int ix=0; ix < (1<<al); ix+=1) begin
                ##1 #1;
                bif.noc_to_dev_data=0;
            end
            dcnt=(1<<dl);
            while(dcnt > 0) begin
                w64=pdata.pop_back();
//                $display("w64 %h @%t",w64,$realtime);
                for(int qq=0; qq < 8; qq+=1) begin
                    ##1 #1;
                    bif.noc_to_dev_data=w64[7:0];
                    w64>>=8;
                end
                dcnt -=8;
            end
            eb.code=NoError;
            eb.errtype=2'b00;
            eb.datalen=(1<<dl);
            experrs.push_front(eb);
            ##1 #1;
//            $display("Pushin releasing the bus %t",$realtime);
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data=0;
            stopinlow=0;
            BUS.put(1);


        end
        
        // Just hang for now...
        ##1 #1;
    end
endtask : push_in


initial begin
    clk=1;
    bif.noc_to_dev_ctl=0;
    bif.noc_to_dev_data=0;
    pushoutHigh=0;
    BUS=new(1);
//    repeat(20_000_000) begin
    repeat(13_000_000) begin
        #5 clk=~clk;
        #5 clk=~clk;
    end
    $display("ran out of clocks");
    $finish;
end

initial begin
    reset=1;
    repeat(3) @(posedge(clk)) #1;
    reset=0;
end

function string diff(input reg[63:0] a, input reg[63:0] b);
	string rv;
	reg [63:0] delta;
	delta=a^b;
	rv="";
	for(int ix=0; ix < 16; ix+=1) begin
		if(delta[63:60]!=0) rv={rv,"^"}; else rv={rv," "};
		delta <<= 4;
	end
	return rv;
endfunction : diff



initial begin
    string line;
    int fi;
    int junk;
    reg lasti=0;
    dix=0;
    repeat(5) @(posedge(clk))#1;
    fi=$fopen("/home/morris/272/f20/sha3_module_tests.txt","r");
    while(!$feof(fi)) begin
		junk=$fgets(line,fi);
		if(line.len()<2) continue;
		case(line[0])
			"#": continue;
			"i": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
				if(!lasti) begin
                    gcnt += 1;
				end
				push_in(dix,din);
				lasti=1;
			end
			"o": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
//				$display("Pushing expected dix %d value %016x",dix,din);
				push_out(dix,din);
				lasti=0;
			end
			"e":  begin
				repeat(10000) @(posedge(clk))#1;
				if(fifoout.size()>0) begin
					die($sformatf("not all data pushed out in 10,000 clocks\n    %d items left",fifoout.size()));
				end else begin
					$display("\n\n\nOh what joy, It's a happy perm block\n\n\n");
				end
				$finish;
			end
			default: begin
				$display("You didn't handle line correctly\n%s\n",line);
			end
		endcase
    end
    $fclose(fi);
end

`endprotect

ps p(bif.TI,bif.FO);

initial begin
//    repeat(10_000_000) @(posedge(clk));
    $dumpfile("perm.vcd");
    $dumpvars(9,top);
    repeat(100000) @(posedge(clk));
    #5;
    $dumpoff;

end

endmodule : top
