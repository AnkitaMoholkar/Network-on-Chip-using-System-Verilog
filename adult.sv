// This is a simple test bench for the permutation block
//
`timescale 1ns/10ps

`include "tb_intf.sv"
`include "ps.sv"


module top();
reg clk,reset;
reg firstoutH;
reg errpos=0;

wire pushout;
reg stopout;
reg pushoutH;
wire [63:0] dout;
reg [63:0] doutH;
NOCI bif(clk,reset);


`protect


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

typedef struct {
ERRBLK experrs[$];
} EE;

EE ee[3:0];

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

typedef struct {
    DD fifoout[$];
} MFIFO;

MFIFO fout[3:0];
DD dd_exp[3:0];

reg [63:0] pdata[$];
typedef struct {
    reg [63:0] pdata[$];
} PDAT;

PDAT pdat[3:0];


reg stopinlow[3:0];
reg pushoutHigh[3:0];
reg readSeen[3:0];

semaphore BUS;  // used to serialize access to the bus
semaphore READ; // used to keep multiple reads from happening at the same time

default clocking ckb @(posedge(clk)) ;



endclocking

task die(input string msg);
	$display("\n\n\n- - - - - - - - - - - Error - - - - - - - - - -");
	$display("  at %8.1fns",$realtime);
	$display("  %s",msg);
	$display("- - - - - - - - - - - Error - - - - - - - - - -\n\n\n");
	errpos=1;
	#20;
	$finish;
endtask : die

task push_out(reg [5:0] dix,reg [63:0] dat,reg [1:0] ix);
	DD di;
	di.dix=dix;
	di.dat=dat;
	fout[ix].fifoout.push_front(di);
endtask : push_out

task ctllow();
    if (bif.noc_from_dev_ctl) begin
        die("ctl high when in message");
    end
endtask : ctllow

initial begin
    reg [7:0] adl,cmd;
    reg [7:0] msgA,msgD;
    reg [63:0] rdata,edata;
    reg [1:0] ix;
    int rdlen;
    DD de;
    ERRBLK eblk;
    stopinlow[0]=1;
    stopinlow[1]=1;
    stopinlow[2]=1;
    stopinlow[3]=1;
    readSeen[0]=0;
    readSeen[1]=0;
    readSeen[2]=0;
    readSeen[3]=0;
    
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
                ##1; // get the dest
                    ctllow();
                ##1; // and the source
                    ix=bif.noc_from_dev_data[1:0];
                    ctllow();
                ##1; // ignore the src/dest for now
                ctllow();
                adl=bif.noc_from_dev_data;
                if(cmd[7:6]!=0) die("Got an error on read response");
                while(adl > 0) begin
                    rdata=0;
                    for(int iq=0; iq < 8; iq+=1) begin
                        ##1;
                        rdata={bif.noc_from_dev_data,rdata[63:8]};
                        ctllow();
                    end
                    adl-=8;
                    de=fout[ix].fifoout.pop_back();
                    edata=de.dat;
                    if(rdata !== edata) begin
                        die($sformatf("Error received %08x, expected %08x seq %d",rdata,edata,de.dix));
                    end else begin
//                        $display("%08x worked",rdata);
                    end
                end
                #1;
                readSeen[ix]=1;
            end
            CCWriteResp: begin
                ##1; // dest
                    ctllow();
                ##1; // src
                    ix=bif.noc_from_dev_data[1:0];
                    ctllow();
                ##1; // ignore the src/dest for now
                ctllow();
                adl=bif.noc_from_dev_data;
                eblk=ee[ix].experrs.pop_back();
                if(eblk.errtype != cmd[7:6]) die($sformatf("Expected error code wrong. Got %x expected %x",
                    cmd[7:6],eblk.code));
                if(eblk.errtype == 1) begin
                    if(adl != eblk.code) die($sformatf("Expecting error reason %x, got %x",eblk.code,adl));
                end else begin
                    if(adl != eblk.datalen) die($sformatf("Data length (noc %h) error on write resp Expected %x, got %x",
                        ix,eblk.datalen,adl));
                end
            end
            CCMessage: begin
                ##1;
                    // destination
                    ctllow();
                ##1;
                    ix=bif.noc_from_dev_data[1:0]; // source
                    ctllow();
                ##1;    // ignore the src/dst for now
                msgA=bif.noc_from_dev_data;
                    ctllow();
                ##1;
                ctllow();
                msgD=bif.noc_from_dev_data;
                if(msgA==8'h42 && msgD==8'h78) begin
                    #1;
                    stopinlow[ix]=1;
                end else if(msgA==8'h17 && msgD==8'h12) begin 
                    #1;
                    pushoutHigh[ix]=1;
                end else begin
                    die($sformatf("Got an unexpected message %x %x",msgA,msgD));
                end
            end
        
        endcase
    end
end
// handle the read requests...
task Hread0(input reg[7:0] id);
    int dleft;
    reg [1:0] alen;
    reg [2:0] dlen;
    reg [7:0] saddr,daddr;
    reg [1:0] ix;
    ix=id[1:0];
    forever begin
        ##1;
        if (!pushoutHigh[ix]) continue;
//        $display("pushoutHigh %t",$realtime);
        dleft=200;
        daddr=id;
        saddr=$urandom_range(8'h80,8'hf0);
        while(dleft > 0) begin
            ##1 #1;
            alen=0;   // keep address shorter
            dlen=$urandom_range(3,7);
            while( (1<<dlen) > dleft ) dlen=$urandom_range(3,7);
            READ.get(1);
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
            while(!readSeen[ix]) ##1;
            readSeen[ix]=0;
            READ.put(1);
        end
        ##1 #1;
        pushoutHigh[ix]=0;
    end
endtask :Hread0

task Hread1(input reg[7:0] id);
    int dleft;
    reg [1:0] alen;
    reg [2:0] dlen;
    reg [7:0] saddr,daddr;
    reg [1:0] ix;
    ix=id[1:0];
    forever begin
        ##1;
        if (!pushoutHigh[ix]) continue;
//        $display("pushoutHigh %t",$realtime);
        dleft=200;
        daddr=id;
        saddr=$urandom_range(8'h80,8'hf0);
        while(dleft > 0) begin
            ##1 #1;
            alen=0;   // keep address shorter
            dlen=$urandom_range(3,7);
            while( (1<<dlen) > dleft ) dlen=$urandom_range(3,7);
            READ.get(1);
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
            while(!readSeen[ix]) ##1;
            readSeen[ix]=0;
            READ.put(1);
        end
        ##1 #1;
        pushoutHigh[ix]=0;
    end
endtask :Hread1

task Hread2(input reg[7:0] id);
    int dleft;
    reg [1:0] alen;
    reg [2:0] dlen;
    reg [7:0] saddr,daddr;
    reg [1:0] ix;
    ix=id[1:0];
    forever begin
        ##1;
        if (!pushoutHigh[ix]) continue;
//        $display("pushoutHigh %t",$realtime);
        dleft=200;
        daddr=id;
        saddr=$urandom_range(8'h80,8'hf0);
        while(dleft > 0) begin
            ##1 #1;
            alen=0;   // keep address shorter
            dlen=$urandom_range(3,7);
            while( (1<<dlen) > dleft ) dlen=$urandom_range(3,7);
            READ.get(1);
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
            while(!readSeen[ix]) ##1;
            readSeen[ix]=0;
            READ.put(1);
        end
        ##1 #1;
        pushoutHigh[ix]=0;
    end
endtask :Hread2

task Hread3(input reg[7:0] id);
    int dleft;
    reg [1:0] alen;
    reg [2:0] dlen;
    reg [7:0] saddr,daddr;
    reg [1:0] ix;
    ix=id[1:0];
    forever begin
        ##1;
        if (!pushoutHigh[ix]) continue;
//        $display("pushoutHigh %t",$realtime);
        dleft=200;
        daddr=id;
        saddr=$urandom_range(8'h80,8'hf0);
        while(dleft > 0) begin
            ##1 #1;
            alen=0;   // keep address shorter
            dlen=$urandom_range(3,7);
            while( (1<<dlen) > dleft ) dlen=$urandom_range(3,7);
            READ.get(1);
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
            while(!readSeen[ix]) ##1;
            readSeen[ix]=0;
            READ.put(1);
        end
        ##1 #1;
        pushoutHigh[ix]=0;
    end
endtask :Hread3


task push_in0(reg [5:0] dixx,reg [63:0] datx,reg[7:0] id);
    reg [2:0] dls[$];
    int dtg;
    int ra;
    reg [2:0] dl;
    reg [1:0] al;
    reg [7:0] idst,isrc;
    int dcnt;
    reg [63:0] w64;
    reg [1:0] ix;
    ERRBLK eb;
    ix=id[1:0];
//    $display("ix is %b id is %b",ix,id);
    pdat[ix].pdata.push_front(datx);
    if(pdat[ix].pdata.size()>=25) begin
        while( !stopinlow[ix] ) ##1;
        idst=id;
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
        while(dls.size()>0) begin
            dl=dls.pop_back();
//            $display("Getting the bus %d",ix);
            BUS.get(1);
//            $display("Got the bus %d",ix);
            al=0;
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data={al,dl,3'h2};
            ##1 #1;
            bif.noc_to_dev_ctl=0;
            bif.noc_to_dev_data=idst;
            ##1 #1;
            bif.noc_to_dev_data=isrc;
            for(int iq=0; iq < (1<<al); iq+=1) begin
                ##1 #1;
                bif.noc_to_dev_data=0;
            end
            dcnt=(1<<dl);
            while(dcnt > 0) begin
                w64=pdat[ix].pdata.pop_back();
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
            ee[ix].experrs.push_front(eb);
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data=0;
            stopinlow[ix]=0;
//            $display("Releasing the bus %d",ix);
            BUS.put(1);
            while(ee[ix].experrs.size()!=0) ##1 #1;
        end
        
        // Just hang for now...
        ##1 #1;
    end
endtask : push_in0

task push_in1(reg [5:0] dixx,reg [63:0] datx,reg[7:0] id);
    reg [2:0] dls[$];
    int dtg;
    int ra;
    reg [2:0] dl;
    reg [1:0] al;
    reg [7:0] idst,isrc;
    int dcnt;
    reg [63:0] w64;
    reg [1:0] ix;
    ERRBLK eb;
    ix=id[1:0];
//    $display("ix is %b id is %b",ix,id);
    pdat[ix].pdata.push_front(datx);
    if(pdat[ix].pdata.size()>=25) begin
        while( !stopinlow[ix] ) ##1;
        idst=id;
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
        while(dls.size()>0) begin
            dl=dls.pop_back();
//            $display("Getting the bus %d",ix);
            BUS.get(1);
//            $display("Got the bus %d",ix);
            al=0;
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data={al,dl,3'h2};
            ##1 #1;
            bif.noc_to_dev_ctl=0;
            bif.noc_to_dev_data=idst;
            ##1 #1;
            bif.noc_to_dev_data=isrc;
            for(int iq=0; iq < (1<<al); iq+=1) begin
                ##1 #1;
                bif.noc_to_dev_data=0;
            end
            dcnt=(1<<dl);
            while(dcnt > 0) begin
                w64=pdat[ix].pdata.pop_back();
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
            ee[ix].experrs.push_front(eb);
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data=0;
            stopinlow[ix]=0;
//            $display("Releasing the bus %d",ix);
            BUS.put(1);
            while(ee[ix].experrs.size()!=0) ##1 #1;
        end
        
        // Just hang for now...
        ##1 #1;
    end
endtask : push_in1

task push_in2(reg [5:0] dixx,reg [63:0] datx,reg[7:0] id);
    reg [2:0] dls[$];
    int dtg;
    int ra;
    reg [2:0] dl;
    reg [1:0] al;
    reg [7:0] idst,isrc;
    int dcnt;
    reg [63:0] w64;
    reg [1:0] ix;
    ERRBLK eb;
    ix=id[1:0];
//    $display("ix is %b id is %b",ix,id);
    pdat[ix].pdata.push_front(datx);
    if(pdat[ix].pdata.size()>=25) begin
        while( !stopinlow[ix] ) ##1;
        idst=id;
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
        while(dls.size()>0) begin
            dl=dls.pop_back();
//            $display("Getting the bus %d",ix);
            BUS.get(1);
//            $display("Got the bus %d",ix);
            al=0;
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data={al,dl,3'h2};
            ##1 #1;
            bif.noc_to_dev_ctl=0;
            bif.noc_to_dev_data=idst;
            ##1 #1;
            bif.noc_to_dev_data=isrc;
            for(int iq=0; iq < (1<<al); iq+=1) begin
                ##1 #1;
                bif.noc_to_dev_data=0;
            end
            dcnt=(1<<dl);
            while(dcnt > 0) begin
                w64=pdat[ix].pdata.pop_back();
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
            ee[ix].experrs.push_front(eb);
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data=0;
            stopinlow[ix]=0;
//            $display("Releasing the bus %d",ix);
            BUS.put(1);
            while(ee[ix].experrs.size()!=0) ##1 #1;
        end
        
        // Just hang for now...
        ##1 #1;
    end
endtask : push_in2

task push_in3(reg [5:0] dixx,reg [63:0] datx,reg[7:0] id);
    reg [2:0] dls[$];
    int dtg;
    int ra;
    reg [2:0] dl;
    reg [1:0] al;
    reg [7:0] idst,isrc;
    int dcnt;
    reg [63:0] w64;
    reg [1:0] ix;
    ERRBLK eb;
    ix=id[1:0];
//    $display("ix is %b id is %b",ix,id);
    pdat[ix].pdata.push_front(datx);
    if(pdat[ix].pdata.size()>=25) begin
        while( !stopinlow[ix] ) ##1;
        idst=id;
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
        while(dls.size()>0) begin
            dl=dls.pop_back();
//            $display("Getting the bus %d",ix);
            BUS.get(1);
//            $display("Got the bus %d",ix);
            al=0;
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data={al,dl,3'h2};
            ##1 #1;
            bif.noc_to_dev_ctl=0;
            bif.noc_to_dev_data=idst;
            ##1 #1;
            bif.noc_to_dev_data=isrc;
            for(int iq=0; iq < (1<<al); iq+=1) begin
                ##1 #1;
                bif.noc_to_dev_data=0;
            end
            dcnt=(1<<dl);
            while(dcnt > 0) begin
                w64=pdat[ix].pdata.pop_back();
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
            ee[ix].experrs.push_front(eb);
            ##1 #1;
            bif.noc_to_dev_ctl=1;
            bif.noc_to_dev_data=0;
            stopinlow[ix]=0;
//            $display("Releasing the bus %d",ix);
            BUS.put(1);
            while(ee[ix].experrs.size()!=0) ##1 #1;
        end
        
        // Just hang for now...
        ##1 #1;
    end
endtask : push_in3


initial begin
    clk=1;
    bif.noc_to_dev_ctl=0;
    bif.noc_to_dev_data=0;
    pushoutHigh[0]=0;
    pushoutHigh[1]=0;
    pushoutHigh[2]=0;
    pushoutHigh[3]=0;
    BUS=new(1);
    READ=new(1);
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
    fork
        Hread0(8'h40);
        Hread1(8'h41);
        Hread2(8'h42);
        Hread3(8'h43);
    join_none
    fork
        t10(8'h40);
        t11(8'h41);
        t12(8'h42);
        t13(8'h43);
    join
    $display("\n\n\nOh what joy, It's a happy perm block\n\n\n");
    $finish;
end
task t10(input reg[7:0] id);
    reg [63:0] din;
    reg [5:0] dix;	// data index for 1600 bits
    string line;
    int limit=0;
    int fi;
    int junk;
    reg lasti=0;
    reg [1:0] ix;
    ix=id[1:0];
    dix=0;
    repeat(5) @(posedge(clk))#1;
    fi=$fopen("/home/morris/272/f20/sha3_module_tests.txt","r");
    while(!$feof(fi)) begin
        if(limit>1000) break;
		junk=$fgets(line,fi);
		if(line.len()<2) continue;
		case(line[0])
			"#": continue;
			"i": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
				if(!lasti) begin
                  limit+=1;
				end
				push_in0(dix,din,id);
				lasti=1;
			end
			"o": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
//				$display("Pushing expected dix %d value %016x",dix,din);
				push_out(dix,din,ix);
				lasti=0;
			end
			"e":  begin
				repeat(10000) @(posedge(clk))#1;
				if(fout[ix].fifoout.size()>0) begin
					die($sformatf("not all data pushed out in 10,000 clocks from %02h\n    %d items left",id,fout[ix].fifoout.size()));
				end
				$finish;
			end
			default: begin
				$display("You didn't handle line correctly\n%s\n",line);
			end
		endcase
    end
    $fclose(fi);
    repeat(10000) @(posedge(clk))#1;
    if(fout[ix].fifoout.size()>0) begin
        die($sformatf("not all data pushed out in 10,000 clocks from %02h\n    %d items left",id,fout[ix].fifoout.size()));
    end

endtask : t10

task t11(input reg[7:0] id);
    reg [63:0] din;
    reg [5:0] dix;	// data index for 1600 bits
    string line;
    int limit=0;
    int fi;
    int junk;
    reg lasti=0;
    reg [1:0] ix;
    ix=id[1:0];
    dix=0;
    repeat(5) @(posedge(clk))#1;
    fi=$fopen("/home/morris/272/f20/sha3_module_tests.txt","r");
    while(!$feof(fi)) begin
        if(limit>1000) break;
		junk=$fgets(line,fi);
		if(line.len()<2) continue;
		case(line[0])
			"#": continue;
			"i": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
				if(!lasti) begin
                  limit+=1;
				end
				push_in1(dix,din,id);
				lasti=1;
			end
			"o": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
//				$display("Pushing expected dix %d value %016x",dix,din);
				push_out(dix,din,ix);
				lasti=0;
			end
			"e":  begin
				repeat(10000) @(posedge(clk))#1;
				if(fout[ix].fifoout.size()>0) begin
					die($sformatf("not all data pushed out in 10,000 clocks from %02h\n    %d items left",id,fout[ix].fifoout.size()));
				end
				$finish;
			end
			default: begin
				$display("You didn't handle line correctly\n%s\n",line);
			end
		endcase
    end
    $fclose(fi);
    repeat(10000) @(posedge(clk))#1;
    if(fout[ix].fifoout.size()>0) begin
        die($sformatf("not all data pushed out in 10,000 clocks from %02h\n    %d items left",id,fout[ix].fifoout.size()));
    end

endtask : t11

task t12(input reg[7:0] id);
    reg [63:0] din;
    reg [5:0] dix;	// data index for 1600 bits
    string line;
    int limit=0;
    int fi;
    int junk;
    reg lasti=0;
    reg [1:0] ix;
    ix=id[1:0];
    dix=0;
    repeat(5) @(posedge(clk))#1;
    fi=$fopen("/home/morris/272/f20/sha3_module_tests.txt","r");
    while(!$feof(fi)) begin
        if(limit>1000) break;
		junk=$fgets(line,fi);
		if(line.len()<2) continue;
		case(line[0])
			"#": continue;
			"i": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
				if(!lasti) begin
                  limit+=1;
				end
				push_in2(dix,din,id);
				lasti=1;
			end
			"o": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
//				$display("Pushing expected dix %d value %016x",dix,din);
				push_out(dix,din,ix);
				lasti=0;
			end
			"e":  begin
				repeat(10000) @(posedge(clk))#1;
				if(fout[ix].fifoout.size()>0) begin
					die($sformatf("not all data pushed out in 10,000 clocks from %02h\n    %d items left",id,fout[ix].fifoout.size()));
				end
				$finish;
			end
			default: begin
				$display("You didn't handle line correctly\n%s\n",line);
			end
		endcase
    end
    $fclose(fi);
    repeat(10000) @(posedge(clk))#1;
    if(fout[ix].fifoout.size()>0) begin
        die($sformatf("not all data pushed out in 10,000 clocks from %02h\n    %d items left",id,fout[ix].fifoout.size()));
    end

endtask : t12

task t13(input reg[7:0] id);
    reg [63:0] din;
    reg [5:0] dix;	// data index for 1600 bits
    string line;
    int limit=0;
    int fi;
    int junk;
    reg lasti=0;
    reg [1:0] ix;
    ix=id[1:0];
    dix=0;
    repeat(5) @(posedge(clk))#1;
    fi=$fopen("/home/morris/272/f20/sha3_module_tests.txt","r");
    while(!$feof(fi)) begin
        if(limit>1000) break;
		junk=$fgets(line,fi);
		if(line.len()<2) continue;
		case(line[0])
			"#": continue;
			"i": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
				if(!lasti) begin
                  limit+=1;
				end
				push_in3(dix,din,id);
				lasti=1;
			end
			"o": begin
				junk=$sscanf(line,"%*c %d %x",dix,din);
//				$display("Pushing expected dix %d value %016x",dix,din);
				push_out(dix,din,ix);
				lasti=0;
			end
			"e":  begin
				repeat(10000) @(posedge(clk))#1;
				if(fout[ix].fifoout.size()>0) begin
					die($sformatf("not all data pushed out in 10,000 clocks from %02h\n    %d items left",id,fout[ix].fifoout.size()));
				end
				$finish;
			end
			default: begin
				$display("You didn't handle line correctly\n%s\n",line);
			end
		endcase
    end
    $fclose(fi);
    repeat(10000) @(posedge(clk))#1;
    if(fout[ix].fifoout.size()>0) begin
        die($sformatf("not all data pushed out in 10,000 clocks from %02h\n    %d items left",id,fout[ix].fifoout.size()));
    end

endtask : t13


`endprotect

ps p(bif.TI,bif.FO);

initial begin
//    repeat(1_000_000) @(posedge(clk));
    $dumpfile("perm.vcd");
    $dumpvars(9,top);
    repeat(100000) @(posedge(clk));
    #5;
    $dumpoff;

end

endmodule : top
