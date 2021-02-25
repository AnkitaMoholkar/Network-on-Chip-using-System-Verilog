`include "my_fifo.v"
`include "johanarbi.sv"
`include "fifo_int.sv"
module switch (input logic clk, input logic reset, input logic noc_to_dev_ctl, input [7:0] noc_to_dev_data, output logic noc_from_dev_ctl, output logic [7:0] noc_from_dev_data, NOCI.TO inp1, NOCI.FI op1, NOCI.TO inp2, NOCI.FI op2,NOCI.TO inp3, NOCI.FI op3, NOCI.TO inp0, NOCI.FI op0); 

logic [7:0] my_output0, my_output1, my_output2, my_output3;
logic choose_next0, choose_next1, choose_next2, choose_next3;
logic grant0, grant1, grant2, grant3;
// Down Stream data
fifo_int f0(clk, reset, op0.noc_from_dev_data, op0.Johans_stupid_signal, grant0, my_output0, cntl0, empty0, choose_next0, LOCK0);
fifo_int f1(clk, reset, op1.noc_from_dev_data, op1.Johans_stupid_signal, grant1, my_output1, cntl1, empty1, choose_next1, LOCK1);
fifo_int f2(clk, reset, op2.noc_from_dev_data, op2.Johans_stupid_signal, grant2, my_output2, cntl2, empty2, choose_next2, LOCK2);
fifo_int f3(clk, reset, op3.noc_from_dev_data, op3.Johans_stupid_signal, grant3, my_output3, cntl3, empty3, choose_next3, LOCK3);
//Arbitration
logic [7:0] nnoc_from_dev_data;
logic [3:0] request;
logic nnoc_from_dev_ctl, LOCK;
logic emp0,emp1,emp2,emp3, ntake_next, take_next;
logic [3:0] grant;
assign emp0 = !empty0;
assign emp1 = !empty1;
assign emp2 = !empty2;
assign emp3 = !empty3;
arb a (clk, reset, request, LOCK, grant);

//assign noc_from_dev_ctl = op0.noc_from_dev_ctl;
//assign noc_from_dev_data = my_output0;
const logic [3:0] idle_arb = 4'b0000;
logic [3:0]  arbing;
logic [3:0] narbing;
always_comb begin
	nnoc_from_dev_data = noc_from_dev_data;
	nnoc_from_dev_ctl = noc_from_dev_ctl;
	narbing = arbing;
	ntake_next = 1;
	case(arbing)
		idle_arb: begin
			request = 0;
			LOCK = 0;
			grant0 = 0;
			grant1 = 0;
			grant2 = 0;
			grant3 = 0;
			narbing = idle_arb;
			request = {emp0,emp1,emp2,emp3};
			if({emp0,emp1,emp2,emp3} != 4'b0000)begin
				narbing = grant;
				if(grant==4'b1000 && emp0==1) 		begin LOCK =1; grant0 =1;end
				else if (grant==4'b0100 && emp1==1) 	begin LOCK =1; grant1 =1;end
				else if (grant==4'b0010 && emp2==1) 	begin LOCK =1; grant2 =1;end
				else if (grant==4'b0001 && emp3==1) 	begin LOCK =1; grant3 =1;end
				else;
			end
		end
		4'b1000: begin
			nnoc_from_dev_data = my_output0;
			nnoc_from_dev_ctl = cntl0;
			ntake_next = choose_next0;
			if(take_next==0) begin narbing = idle_arb; nnoc_from_dev_data=0; nnoc_from_dev_ctl =1;end
		end
		4'b0100: begin
			nnoc_from_dev_data = my_output1;
			nnoc_from_dev_ctl =cntl1;
			ntake_next = choose_next1;
			if(take_next==0) begin narbing = idle_arb; nnoc_from_dev_data=0; nnoc_from_dev_ctl =1;end
		end
		4'b0010: begin
			nnoc_from_dev_data = my_output2;
			nnoc_from_dev_ctl =cntl2;
			ntake_next = choose_next2;
			if(take_next==0) begin narbing = idle_arb; nnoc_from_dev_data=0; nnoc_from_dev_ctl =1;end
		end
		4'b0001: begin
			nnoc_from_dev_data = my_output3;
			nnoc_from_dev_ctl =cntl3;
			ntake_next = choose_next3;
			if(take_next==0) begin narbing = idle_arb; nnoc_from_dev_data=0; nnoc_from_dev_ctl =1;end
		end
	endcase
end

always_ff @ (posedge clk or posedge reset)begin
	if(reset)begin
		noc_from_dev_data <= 0;
		noc_from_dev_ctl <= 1;
		arbing <= #1 idle_arb;
		take_next <= 0;
	end else begin
		noc_from_dev_data <= #1 nnoc_from_dev_data;
		noc_from_dev_ctl <= #1 nnoc_from_dev_ctl;
		arbing <= #1 narbing;
		take_next <= ntake_next;
	end
	
end

logic [2:0] cmd, cmd_d; 
logic [7:0] temp, temp_d;
reg [8:0] size, size_d;
reg [1:0] addr_len; reg [2:0] data_len; reg [7:0] alen, alen_d, dlen, dlen_d; reg flag, flag_d; 
reg [1:0] slave, slave_d; 
enum logic [1:0] {idle,write_read,s3,s4} cs,ns;

always_comb begin
	size_d = size; 
	ns = cs;
	slave_d = slave;
	flag_d = flag;
	temp_d = temp; 
	cmd_d = cmd;
	alen_d = alen;
	dlen_d = dlen; 
	
	case (cs)
		idle: begin 
			inp1.noc_to_dev_ctl = 0;
			inp1.noc_to_dev_data= 0;
			inp2.noc_to_dev_ctl = 0;
			inp2.noc_to_dev_data= 0;
			inp3.noc_to_dev_ctl = 0;
			inp3.noc_to_dev_data= 0;
			inp0.noc_to_dev_ctl = 0;
			inp0.noc_to_dev_data= 0;
			if( (noc_to_dev_ctl == 1) && (noc_to_dev_data != 8'b00000000) ) begin
				cmd_d = noc_to_dev_data[2:0];
				addr_len = noc_to_dev_data[7:6];
				alen_d = 2**addr_len;
				data_len = noc_to_dev_data[5:3];
				dlen_d = 2**data_len; 
				flag_d = 1; 
				temp_d = noc_to_dev_data;
				ns = write_read;
			end 
			else begin 
			ns = idle; 
			end 
		end
		
		write_read: begin 
			temp_d = noc_to_dev_data;
			if (flag==1) begin 
				if (cmd == 3'b001) size_d = alen+1; 
				else size_d = alen+dlen+1; 
				ns = write_read; 
				
			if (noc_to_dev_data[1:0] == 2'b00) begin 
				inp0.noc_to_dev_ctl = 1;
				inp0.noc_to_dev_data = temp;
				inp1.noc_to_dev_ctl = 1;
				inp1.noc_to_dev_data = 0;				
				inp2.noc_to_dev_ctl = 1;
				inp2.noc_to_dev_data = 0;				
				inp3.noc_to_dev_ctl = 1;
				inp3.noc_to_dev_data = 0;
				flag_d = 0; slave_d = 2'b00; 
			end
			else if (noc_to_dev_data[1:0] == 2'b01) begin 
				inp1.noc_to_dev_ctl = 1;
				inp1.noc_to_dev_data = temp;
				inp2.noc_to_dev_ctl = 1;
				inp2.noc_to_dev_data = 0;				
				inp3.noc_to_dev_ctl =1;
				inp3.noc_to_dev_data = 0;				
				inp0.noc_to_dev_ctl = 1;
				inp0.noc_to_dev_data = 0; 
				flag_d = 0; slave_d = 2'b01;
			end  
			else if (noc_to_dev_data[1:0] == 2'b10) begin 
				inp2.noc_to_dev_ctl = 1;
				inp2.noc_to_dev_data = temp;
				inp3.noc_to_dev_ctl = 1;
				inp3.noc_to_dev_data = 0;				
				inp1.noc_to_dev_ctl = 1;
				inp1.noc_to_dev_data = 0;				
				inp0.noc_to_dev_ctl =1;
				inp0.noc_to_dev_data = 0; 
				flag_d = 0; slave_d = 2'b10;
			end
			else if (noc_to_dev_data[1:0] == 2'b11) begin 
				inp3.noc_to_dev_ctl = 1;
				inp3.noc_to_dev_data = temp;
				inp0.noc_to_dev_ctl = 1;
				inp0.noc_to_dev_data = 0;				
				inp1.noc_to_dev_ctl = 1;
				inp1.noc_to_dev_data = 0;				
				inp2.noc_to_dev_ctl = 1;
				inp2.noc_to_dev_data = 0; 
				flag_d = 0; slave_d = 2'b11;
			end
		   end
		   else begin 
		   temp_d = noc_to_dev_data; 
		   		case(slave) 
		   			2'b00: begin
		   				
				   		inp0.noc_to_dev_ctl = 0;
						inp0.noc_to_dev_data = temp;	
						inp1.noc_to_dev_ctl = 1;
						inp1.noc_to_dev_data = 0;				
						inp2.noc_to_dev_ctl = 1;
						inp2.noc_to_dev_data = 0;				
						inp3.noc_to_dev_ctl = 1;
						inp3.noc_to_dev_data = 0;
						//$display("inp1.dev.data is : %h", inp1.noc_to_dev_data ); 
					end
					2'b01: begin
						
				   		inp0.noc_to_dev_ctl = 1;
						inp0.noc_to_dev_data = 0;
						inp1.noc_to_dev_ctl = 0;
						inp1.noc_to_dev_data = temp;				
						inp2.noc_to_dev_ctl = 1;
						inp2.noc_to_dev_data = 0;				
						inp3.noc_to_dev_ctl = 1;
						inp3.noc_to_dev_data = 0;
						//$display("inp2.dev.data is : %h", inp2.noc_to_dev_data ); 
					end
					2'b10: begin
						
				   		inp0.noc_to_dev_ctl = 1;
						inp0.noc_to_dev_data = 0;
						inp1.noc_to_dev_ctl = 1;
						inp1.noc_to_dev_data = 0;				
						inp2.noc_to_dev_ctl = 0;
						inp2.noc_to_dev_data = temp;				
						inp3.noc_to_dev_ctl = 1;
						inp3.noc_to_dev_data = 0; 
						//$display("inp3.dev.data is : %h", inp3.noc_to_dev_data );
					end
					2'b11: begin
						
				   		inp0.noc_to_dev_ctl = 1;
						inp0.noc_to_dev_data = 0;
						inp1.noc_to_dev_ctl = 1;
						inp1.noc_to_dev_data = 0;				
						inp2.noc_to_dev_ctl = 1;
						inp2.noc_to_dev_data = 0;				
						inp3.noc_to_dev_ctl = 0;
						inp3.noc_to_dev_data = temp;
						//$display("inp4.dev.data is : %h", inp4.noc_to_dev_data ); 
					end
		   				
		   endcase 
			if ( size == 9'd0) begin 
			   	if (noc_to_dev_ctl && (|noc_to_dev_data)) begin 
					temp_d = noc_to_dev_data;
					cmd_d = noc_to_dev_data[2:0]; 
					alen_d = 2** (temp_d[7:6]);
					dlen_d = 2** (temp_d[5:3]);
					flag_d=1;
					ns = write_read;
					size_d=0;
					slave_d = 2'b00; 
			   	end
			   	else begin 
				   size_d = 0;			  
				   slave_d = 2'b00;
				   ns = idle; 
				end  
			end else begin
				   size_d = size - 1;
				   ns = write_read;
				 end  
			
		 end  
	end
endcase
end 

always_ff @ (posedge clk or posedge reset) begin 
	if(reset) begin
		cs<= idle;
		size<=0;
		slave<= 0;
		temp<= 0;
		flag<= 0;
		cmd<= 0;
		alen<= 0;
		dlen<= 0;
	end
	else begin 
		cs<=  ns; 
		size<=  size_d;
		slave<=  slave_d;
		temp<=  temp_d; 
		flag<=  flag_d; 
		cmd<=  cmd_d;
		alen<=  alen_d;
		dlen<=  dlen_d;
		end
end 
endmodule : switch
