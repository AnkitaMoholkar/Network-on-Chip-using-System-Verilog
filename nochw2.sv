module noc_intf (
	input clk,
	input reset,
	input tod_ctl,
	input [7:0] tod_data,
	output bit frm_ctl,
	output reg [7:0] frm_data,
	output bit pushin,
	output bit firstin,
	input stopin,
	output reg [63:0] din,
	input pushout,
	input firstout,
	output bit stopout,
	input [63:0] dout,
	output logic Johans_stupid_signal);


	bit debug =0;

	reg [7:0] Al_Dlin;
	reg [7:0] D_IDin;
	reg [7:0] S_IDin;
	reg [7:0] M_Addrin;
	reg [7:0] M_Datain;
	bit writep;
	bit readp;
	reg [7:0] Al_Dl;
	reg [7:0] D_IDout;
	reg [7:0] S_IDout;
	reg [7:0] M_Addrout;
	reg [7:0] M_Dataout;
	wire emptyp;
	wire fullp;

	fifo_messege messege (clk, reset, Al_Dlin, D_IDin, S_IDin, M_Addrin, M_Datain, writep, readp, Al_Dl, D_IDout, S_IDout, M_Addrout, M_Dataout, emptyp, fullp);

	/*
	This block is to know what cmd we get inputted!
	1.  If reset high:
	Reset all the registers! super important.
	else:
	## Check tod_ctl! ##
	if tod_ctl high:
	Restart all counters.
	Check the 8 bit input for
	Alen
	Dlen
	command
	else tod_ctl low:
	Now use the command to go into either IDLE, write, or read, as 0,1, and 2.
	0: IDLE we just wannna sit around and wait for papa to tell us what to do
	1: Crapp we gotta read this too!... Better wurrrk.. 
	2:  Crapp we got a write assigment.. better move my ass
	CHECK if stopin is high, if it is... we gotta write a messege that it did not work bud
	If everything checks out:
	first counter starts from 0,
	@ 0    
	we save Source
	@ 1
	we save Dest
	@ (starting) 2 -> (2**Alen) +2
	we save the address data 
	## Why do we have this now again? ##
	@ (starting) (2**Alen)+2 -> (2**Dlen) + ((2**Alen)+2)
	Here we put the data into out din!
	1. We check against a counter... for how much we already pushed in
	2. Dependent on where we are, either we just push data into the din, or we need to also make pushin 0.. or it will fill up perm.. we don't want that bruh
	2. 
	*/
	// ######### REGISTER USED UN THIS BLOCK!! #########
	reg [2:0] cntrl;
	reg [1:0] Alen;
	reg [2:0] Dlen;
	reg [10:0] counter;
	reg [7:0] Sourc;
	reg [7:0] Dest;
	reg [7:0] Addr;

	// Seperated for write
	reg [10:0] write_counter;
	bit write_start;
	reg [10:0] Dlen_counter;
	reg [7:0] temp;
	reg [1:0] control;

	// Seperated for read
	reg [7:0] Sourc_r;
	reg [7:0] Dest_r;
	reg [63:0] Addr_r;
	reg [1:0] Alen_r;
	reg [2:0] Dlen_r;
	bit start_read;
	bit make_request;
	bit read_flag;
	//initial #80000 $finish;

	//Write response
	reg [2:0] resp_counter;
	
	//Read response
	reg [7:0] ctrl_read_counter;
	reg [4:0] read_resp_counter;
	bit done_read;
	assign frm_ctl =1;

	//Messages	
	reg [7:0] Sourc_d;
	reg [7:0] Dest_d;
	bit pushout_d;
	bit stopin_d;

	/*always @(negedge (stopin)) begin
		Sourc_d <= #1 Sourc;
		Dest_d <= #1 Dest;
		control <= #1 3;
	end
	always @(posedge (pushout)) begin
		control <= #1 2;
		//stopout = #1 1;
	end*/

	//FIFO block
	reg [2:0] fromdata_counter;
	reg [2:0] resp_or_mess;
	reg [7:0] Al_Dl_d;
	reg [7:0] D_IDout_d;
	reg [7:0] S_IDout_d;
	reg [7:0] M_Addrout_d;
	reg [7:0] M_Dataout_d;

	bit flagfornow;
	always@(posedge(clk))begin
		if (reset)begin
			cntrl   <= 0;
			Alen    <= 0;
			Dlen    <= 0;
			counter <= 0;
			din     <= 0;
			firstin <= 0;
			pushin  <= 0;
			Sourc   <= 0;
			Dest    <= 0;
			Addr    <= 0;
			Dlen_counter <= 0;
			temp <= 0;
			write_counter <= 0;
			Dest_r <= 0;
			Alen_r <= 0;
			Dlen_r <= 0;
			Sourc_r <= 0;
			Addr_r <= 0;
			read_flag <=0;
			
			flagfornow <=0;
			pushout_d <=0;
			stopin_d <=0;
		end else begin
			// Should be in messages block... just too lazy to scroll
			pushout_d <= #1 pushout;
			stopin_d <= #1 stopin;
			
			if ((pushout==1)&&(pushout_d==0))begin
				control <= #1 2;
				//stopout = #1 1;
				flagfornow <= #1 1'b1;
			end else if ((stopin_d)>(stopin))begin
				Sourc_d <= #1 Sourc;
				Dest_d <= #1 Dest;
				control <= #1 3;
			end else ;

			if (tod_ctl)begin
				cntrl   <= #1 tod_data[2:0];
				Alen    <= #1 tod_data[7:6];
				Dlen    <= #1 tod_data[5:3];
				counter <= #1 0;
				pushin  <= #1 0;
				firstin <= #1 0;
				Dlen_counter <= #1 0;
				if (read_flag) writep <= #1 0;
				read_flag <= #1 0;
				if (stopin) write_counter <= #1 11'd0;
			end else begin
				case(cntrl)
					0: begin
						if(debug) $display("We are in cntrl IDLE"); //This is our IDLE stage bruh
						if (stopin) write_counter <= #1 11'd0;
					end
					1: begin //process read command here
						if(debug) $display("We are in cntrl read");
						if 	(counter ==0)begin
							D_IDin 	<= #1 tod_data;
							Al_Dlin <= #1 {2'b00,3'b000,3'b011};
							Alen_r  <= #1 Alen;
							Dlen_r  <= #1 Dlen;
						end else if (counter ==1) begin
							S_IDin 	<= #1 tod_data;
						end else if ((counter ==2)&& (counter <((2**Alen)+2)))begin
							M_Addrin  	<= #1 tod_data;
							read_flag <= #1 1;
							if((counter <((2**Alen)+2))+1) writep <= #1 1;
							else writep <= #1 0;
							make_request <= #1 1;
						end else begin
							make_request <= #1 1;
							writep <= #1 0;
							cntrl <= #1 0;
							counter <= #1 0;
						end
						counter <= #1 counter+1;
					end
					2: begin //process write command here
						if(debug) $display("We are in cntrl write");
						if (stopin) begin
							/*  Well... 
							if stopin happened and write in is still going on... 
							we gotta write a write response back that this write in was partially done... and go back to idle
							*/
							cntrl <= #1 0;
							write_counter <= #1 0;
						end else begin
							if 	(counter == 0)begin
								Sourc 	<= #1 tod_data; //Save the Sourc
							end else if (counter ==1) begin
								Dest 	<= #1 tod_data; // Save the Dest
							end else if ((counter >=2) && (counter <((2**Alen)+2)))begin
								Addr  	<= #1 tod_data; // Save the Address
							end else if ((counter >=((2**Alen)+2)) && (counter <=((2**Alen)+2+(2**Dlen))))	begin
								case((write_counter)%8)
									0:begin
										pushin    <= #1 0;
										firstin   <= #1 0;
										din[7:0]  <= #1 tod_data;
									end
									1:  	din[15:8]    <= #1 tod_data;
									2:  	din[23:16]   <= #1 tod_data;
									3:  	din[31:24]   <= #1 tod_data;
									4:  	din[39:32]   <= #1 tod_data;
									5:  	din[47:40]   <= #1 tod_data;
									6:  	din[55:48]   <= #1 tod_data; 
									7:begin
										din[63:56] <= #1 tod_data;
										control <= #1 1;
										//push_counter <= #1 (push_counter == 5'd24)?5'd0:push_counter+1;
										pushin <= #1 1;
										firstin <= #1 (write_counter == 7)?1:0;
									end
								endcase
								write_counter <= #1 write_counter+1;
								Dlen_counter <= #1 Dlen_counter+1;
								if (debug) $display("Dlen %d",Dlen);
								
								if(Dlen_counter == (((2**Dlen)-1))) begin
									if (debug)  $display("(2**Dlen)-1) is %d",((2**Dlen)-1));
									write_start <= #1 1;
									temp <= #1 Dlen_counter;
									cntrl <= #1 0;
								end
							end
							counter <= #1 counter+1;
						end
					end
					default: cntrl <= #1 0;
				endcase
			end
		end
	


	/*
		This is our Write Response block
	*/
	

		if (reset)begin
			writep <= 0;
			resp_counter <= 0;
			write_start <= 0;
			Al_Dlin <= 0;
			D_IDin <= 0;
			S_IDin <= 0;
			M_Addrin <=0;
			M_Datain <=0;
		end else begin
			case (resp_counter)
				3'd0:begin
					if (write_start == 1 ) begin
						pushin <= #1 0;
						if (debug) $display("temp is %b",temp);
						Al_Dlin <= #1 {2'b00,3'b000,3'b100};
						resp_counter <= #1 resp_counter + 1;
					end	 
				end
				3'd1:begin
					D_IDin <= #1 Sourc;
					resp_counter <= #1 resp_counter + 1;
				end
				3'd2:begin
					S_IDin <= #1 Dest;
					resp_counter <= #1 resp_counter + 1;
				end
				3'd3:begin
					M_Addrin <= #1 (temp+1);
					resp_counter <= #1 resp_counter + 1;
				end
				3'd4: begin
					M_Datain <= #1 temp;
					writep <= #1 1;
					resp_counter <= #1 resp_counter + 1;
				end
				3'd5: begin
					writep <= #1 0;
					resp_counter <= #1 0;
					write_start <= #1 0;
				end
			endcase
		end 
	
	/*
		This is our Read Response block
	*/

		if (reset)begin
			ctrl_read_counter <= 0;
			read_resp_counter <= 0;
			stopout <= 1;
		end else begin
			if (start_read)begin
				//writep <= #1 0;
				if (((2**Dlen_r)>ctrl_read_counter))begin
				//if (pushout ==1)begin
					//$display(ctrl_read_counter);
					case((ctrl_read_counter)%8)
						0:begin
							frm_data <= #1 dout [7:0];
							stopout <= #1 1;
							//if (read_resp_counter>0) stopout <= #1 1;
						end
						1: 	frm_data <= #1 dout [15:8];
						2: 	frm_data <= #1 dout [23:16];
						3: 	frm_data <= #1 dout [31:24];
						4: 	frm_data <= #1 dout [39:32];
						5: 	begin
							frm_data <= #1 dout [47:40];
							
						end
						6: 	begin
							frm_data <= #1 dout [55:48];
							stopout <= #1 0;
						end
						7:begin
							frm_data <= #1 dout [63:56];
							stopout <= #1 1;
							read_resp_counter <= #1 read_resp_counter + 1;
							//if (read_resp_counter == 24) begin
							//	start_read <= #1 0;
							//end
						end
					endcase
					ctrl_read_counter <= #1 ctrl_read_counter + 1;
				
				end else begin
					//$display(ctrl_read_counter);
					//$display("Outside");
					stopout <= #1 1;
					ctrl_read_counter <= #1 0;
					start_read <= #1 0;
					stopout <= #1 1;
					frm_data <= #1 0;
					//frm_ctl <= #1 0;
				end
			end else ;//stopout <= #1 1;
		end
	

	/*
		This is our messeges block
	*/



	if(reset) begin
		control <= 0;
		resp_counter <=0;
		writep <= 0;
		resp_counter <= 0;
		write_start <= 0;
		Al_Dlin <= 0;
		D_IDin <= 0;
		S_IDin <= 0;
		M_Addrin <=0;
		M_Datain <=0;
	end else begin
			case (control)
				3'd0:begin
				;
				end
				3'd1:begin
					case (resp_counter)
						3'd0:begin
							if (write_start == 1 ) begin
								if (debug) $display("Starting write response");
								Al_Dlin <= #1 {2'b00,3'b000,3'b100};
								resp_counter <= #1 resp_counter + 1;
							end	 
						end
						3'd1:begin
							D_IDin <= #1 Sourc;
							resp_counter <= #1 resp_counter + 1;
						end
						3'd2:begin
							S_IDin <= #1 Dest;
							resp_counter <= #1 resp_counter + 1;
						end
						3'd3:begin
							M_Addrin <= #1 (temp+1);
							resp_counter <= #1 resp_counter + 1;
						end
						3'd4: begin
							M_Datain <= #1 temp;
							writep <= #1 1;
							resp_counter <= #1 resp_counter + 1;
						end
						3'd5: begin
							writep <= #1 0;
							resp_counter <= #1 0;
							write_start <= #1 0;
							control <= #1 0;
						end
					endcase
				end
				3'd2:begin //message when pushout goes from 0 -> 1
					case (resp_counter)
						3'd0:begin
							if (debug) $display("Starting pushout message");
							Al_Dlin <= #1 {5'b00000,3'b101};
							resp_counter <= #1 resp_counter + 1;
						end
						3'd1:begin
							D_IDin <= #1 Sourc;
							resp_counter <= #1 resp_counter + 1;
						end
						3'd2:begin
							S_IDin <= #1 Dest;
							resp_counter <= #1 resp_counter + 1;
						end
						3'd3:begin
							M_Addrin <= #1 8'h17;//just to check given this value
							resp_counter <= #1 resp_counter + 1;
						end
						3'd4:begin
							M_Datain <= #1 8'h12;
							resp_counter <= #1 resp_counter + 1;
							writep <= #1 1;
						end
						3'd5: begin
							writep <= #1 0;
							resp_counter <= #1 0;
							control <= #1 0;
						end
					endcase
				end
				3'd3:begin //message when stopin goes from 1 -> 0
					case (resp_counter)
						3'd0:begin
							if (debug) $display("Starting stopin message");
							Al_Dlin <= #1 {5'b00000,3'b101};
							resp_counter <= #1 resp_counter + 1;
						end
						3'd1:begin
							D_IDin <= #1 Sourc_d;
							resp_counter <= #1 resp_counter + 1;
						end
						3'd2:begin
							S_IDin <= #1 Dest_d;
							resp_counter <= #1 resp_counter + 1;
						end
						3'd3:begin
							M_Addrin <= #1 8'h42; //just to check given this value
							resp_counter <= #1 resp_counter + 1;
						end
						3'd4:begin
							M_Datain <= #1 8'h78;
							resp_counter <= #1 resp_counter + 1;
							writep <= #1 1;
						end
						3'd5: begin
							writep <= #1 0;
							resp_counter <= #1 0;
							control <= #1 0;
						end
					endcase
				end
			endcase
		end
	

	/*
		This is our FIFO output block
	*/
		if (reset)begin			
			readp <= 0;
			fromdata_counter  <= 0;
			resp_or_mess <=  0;
			Al_Dl_d <= 0;
			D_IDout_d <= 0;
			S_IDout_d <= 0;
			M_Addrout_d <= 0;
			M_Dataout_d <= 0;
			frm_data <= 0;
			Johans_stupid_signal <= 0;
		end else begin
			case (resp_or_mess)
				3'd0: begin
					//Idle
					frm_data <= #1 0;
					Johans_stupid_signal <= #1 0;
					if (emptyp) ;
					else begin
						readp <= #1 1;
						resp_or_mess <= #1 2'd1;
					end
				end
				3'd1: begin
					resp_or_mess <= #1 Al_Dl[2:0];
					Al_Dl_d <= #1 Al_Dl;
					D_IDout_d <= #1 S_IDout;
					S_IDout_d <= #1 D_IDout;
					M_Addrout_d <= #1  M_Addrout;
					M_Dataout_d <= #1 M_Dataout;
					readp <= #1 0;
				end
				3'd3: begin //Read Resp!!
					if (make_request == 1) begin
						//frm_ctl = #1 1;
						if (debug) $display("Sending read response");
						case(fromdata_counter)
							3'd0: 	begin frm_data <= #1 Al_Dl_d; Johans_stupid_signal <= #1 1; end
							3'd1: 	begin frm_data <= #1 D_IDout_d; Johans_stupid_signal <= #1 0; end
							3'd2: 	frm_data <= #1 S_IDout_d;
							3'd3: begin
								frm_data <= #1 2**(Dlen_r);
								start_read <= #1 1;
							end
							3'd4: begin
								if (start_read == 0) begin
									//frm_ctl <= #1 0;
									resp_or_mess <= #1 0;
									fromdata_counter <= #1 0;
									make_request <= #1 0;
								end
							end
						endcase
						if (fromdata_counter > 3)  ;
						else fromdata_counter <= #1 fromdata_counter+1;
						end 
				end
				3'd4: begin //Write Resp!!
					case(fromdata_counter)
						3'd0: 	begin frm_data <= #1 Al_Dl_d; Johans_stupid_signal <= #1 1; end
						3'd1: 	begin frm_data <= #1 D_IDout_d; Johans_stupid_signal <= #1 0; end
						3'd2: 	frm_data <= #1 S_IDout_d;
						3'd3: begin
							frm_data <= #1 M_Addrout_d;
						end
						3'd4: begin
							frm_data <= #1 0;
							resp_or_mess <= #1 0;
							//frm_ctl <= #1 0;
						end
					endcase
					if (fromdata_counter > 3)  fromdata_counter <= #1 0;
					else begin
						fromdata_counter <= #1 fromdata_counter+1;
						//frm_ctl <= #1 1;
					end
				end
				3'd5: begin // Messege!!
					case(fromdata_counter)
						3'd0: 	begin frm_data <= #1 Al_Dl_d; Johans_stupid_signal <= #1 1; end
						3'd1: 	begin frm_data <= #1 D_IDout_d; Johans_stupid_signal <= #1 0; end
						3'd2: 	frm_data <= #1 S_IDout_d;
						3'd3: 	frm_data <= #1 M_Addrout_d;
						3'd4: begin
							frm_data <= #1 M_Dataout_d;
						end
						3'd5: begin
							frm_data <= #1 0;
							resp_or_mess <= #1 0;
							//frm_ctl <= #1 0;
						end
					endcase
					if (fromdata_counter > 4)  fromdata_counter <= #1 0;
					else begin
						fromdata_counter <= #1 fromdata_counter+1;
						//frm_ctl <= #1 1;
					end
				end
				default resp_or_mess <= #1 2'd0;
			endcase
		end
	end
endmodule
