`include "fifo.sv"
module fifo_int(
input clk,
input reset,
input [7:0] my_input,
input Johans_stupid_signal,
input grant,
output logic [7:0] my_output,
output logic cntl,
output empty,
output logic choose_next,
output LOCK
);

// Switch Fifo
logic [7:0] in; logic empty, full;
wire [7:0] out; bit write, read;

single_fifo f (clk, reset, in, write, read, out, empty, full);


logic [7:0] nDlen, Dlen, nDlen_fifo, Dlen_fifo, counting, ncounting, crappdatan, fifo_counting, nfifo_counting;

enum logic [2:0] {idle_device,write_resp=4,read_resp=3,message=5} ds,nds, sh, nsh;
enum logic [2:0] {idle_fifo, al_dl, Destination_ID, Source_ID, Message_Addr, Message_Data, Actual_Data_length, Data} fifos, nfifos, fifos_out, nfifos_out;

logic nchoose_next,ncntl;

// Down Stream data
always_ff @(posedge clk or posedge reset) begin
	if (reset) begin
		ds <= idle_device;
		fifos <= Destination_ID;
		Dlen <= 0;
		counting <= 0;
		in <= 0;
	end else begin
		case(ds)
			idle_device: begin
				write <= #1 0;
				if(Johans_stupid_signal == 1 && my_input != 8'b00000000 ) begin
					write <= #1 1;
					in <= #1 my_input;
					case(my_input[2:0])
						3'b011: begin ds <= #1 read_resp; end//READ RESPONSE
						3'b100: begin ds <= #1 write_resp; end//WRITE RESPONSE
						3'b101: begin ds <= #1 message; end//MESSAGE
					endcase
				end
			end
			read_resp:begin
				case(fifos)
					Destination_ID: begin
						write <= #1 1;
						fifos <= #1 Source_ID;
						in <= #1 my_input;
					end
					Source_ID: begin
						fifos <= #1 Actual_Data_length;
						in <= #1 my_input;
					end
					Actual_Data_length: begin
						fifos <= #1 Data;
						in <= #1 my_input;
						Dlen <= #1 my_input;
					end
					Data: begin
						counting <= #1 counting + 1;
						if(Dlen>counting) begin
							in <= #1 my_input;
						end else begin
							fifos <= #1 Destination_ID;
							ds <= #1 idle_device;
							counting <= #1 0;
							write <= #1 0;
						end
					end
				endcase
			end
			write_resp:begin
				case(fifos)
					Destination_ID: begin
						fifos <= #1 Source_ID;
						in <= #1 my_input;
					end
					Source_ID: begin
						fifos <= #1 Actual_Data_length;
						in <= #1 my_input;
					end
					Actual_Data_length: begin
						fifos <= #1 Destination_ID;
						in <= #1 my_input;
						ds <= #1 idle_device;
					end
				endcase
			end
			message:begin
				case(fifos)
					Destination_ID: begin
						fifos <= #1 Source_ID;
						in <= #1 my_input;
					end
					Source_ID: begin
						fifos <= #1 Message_Addr;
						in <= #1 my_input;
					end
					Message_Addr: begin
						fifos <= #1 Message_Data;
						in <= #1 my_input;
					end
					Message_Data: begin
						fifos <= #1 Destination_ID;
						in <= #1 my_input;
						ds <= #1 idle_device;
					end
				endcase
			end
		endcase
	end
end

// For streaming data out of fifos
logic LOCK;
always_ff @ (posedge clk or posedge reset) begin
	if(reset) begin
		choose_next <= 0;
		cntl <= 1;
		sh <= idle_device;
		fifos_out <= idle_fifo;
		fifo_counting <= 0;
		my_output <= 0;
		Dlen_fifo <= 0;
	end else begin
		case(sh)
			idle_device: begin
				my_output <= #1 0;
				cntl <= #1 1;
				LOCK = 0;
				if(!empty)begin
					if(grant) begin
						choose_next <= #1 1;
						LOCK =1;
						case(out[2:0])
							3'b011: begin sh <= #1 read_resp; read <= #1 1; end//READ RESPONSE
							3'b100: begin sh <= #1 write_resp; read <= #1 1; end//WRITE RESPONSE
							3'b101: begin sh <= #1 message; read <= #1 1; end//MESSAGE
						endcase
					end
				end
			end
			read_resp:begin
				case(fifos_out)
					idle_fifo: fifos_out <= #1 al_dl;
					al_dl: begin
						cntl <= #1 1;
						fifos_out <= #1 Destination_ID;
						my_output <= #1 out;
					end
					Destination_ID: begin
						cntl <= #1 0;
						fifos_out <= #1 Source_ID;
						my_output <= #1 out;
					end
					Source_ID: begin
						fifos_out <= #1 Actual_Data_length;
						my_output <= #1 out;
					end
					Actual_Data_length: begin
						fifos_out <= #1 Data;
						my_output <= #1 out;
						Dlen_fifo <= #1 out;
					end
					Data: begin
						fifo_counting <= #1 fifo_counting + 1;
						if(Dlen_fifo>fifo_counting) begin
							my_output <= #1 out;
								
							if((Dlen_fifo -1)==fifo_counting) read <= #1 0;
						end else begin
							fifos_out <= #1 idle_fifo;
							sh <= #1 idle_device;
							fifo_counting <= #1 0;
							choose_next <= #1 0;
							cntl <= #1 1;
							my_output <= #1 0;
						end
					end
				endcase
			end
			write_resp: begin
				case(fifos_out)
					idle_fifo: fifos_out <= #1 al_dl;
					al_dl: begin
						cntl <= #1 1;
						fifos_out <= #1 Destination_ID;
						my_output <= #1 out;
					end
					Destination_ID: begin
						cntl <= #1 0;
						fifos_out <= #1 Source_ID;
						my_output <= #1 out;
					end
					Source_ID: begin
						fifos_out <= #1 Actual_Data_length;
						my_output <= #1 out;
					end
					Actual_Data_length: begin
						fifos_out <= #1 idle_fifo;
						my_output <= #1 out;
						sh <= #1 idle_device;
						choose_next <= #1  0;
						read <= #1 0;
					end
				endcase
			end
			message:begin
				case(fifos_out)
					idle_fifo: fifos_out <= #1 al_dl;
					al_dl: begin
						cntl <= #1 1;
						fifos_out <= #1 Destination_ID;
						my_output <= #1 out;
					end
					Destination_ID: begin
						cntl <= #1 0;
						fifos_out <= #1 Source_ID;
						my_output <= #1 out;
					end
					Source_ID: begin
						fifos_out <= #1 Message_Addr;
						my_output <= #1 out;
					end
					Message_Addr: begin
						fifos_out <= #1 Message_Data;
						my_output <= #1 out;
					end
					Message_Data: begin
						fifos_out <= #1 idle_fifo;
						my_output <= #1 out;
						sh <= #1 idle_device;
						choose_next <= #1 0;
						read <= #1 0;
					end
				endcase
			end
		endcase
	end
end

endmodule
