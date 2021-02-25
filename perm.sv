module perm_blk(input clk, 
input rst, 
input pushin, 
output reg stopin,
input firstin, 
input [63:0] din,
output reg [2:0] m1rx, 
output reg [2:0] m1ry,
input [63:0] m1rd,
output reg [2:0] m1wx, 
output reg [2:0] m1wy,
output reg m1wr,
output reg [63:0] m1wd,
output reg [2:0] m2rx, 
output reg [2:0] m2ry,
input [63:0] m2rd,
output reg [2:0] m2wx, 
output reg [2:0] m2wy,
output reg m2wr,
output reg [63:0] m2wd,
output reg [2:0] m3rx, 
output reg [2:0] m3ry,
input [63:0] m3rd,
output reg [2:0] m3wx, 
output reg [2:0] m3wy,
output reg m3wr,
output reg [63:0] m3wd,
output reg [2:0] m4rx, 
output reg [2:0] m4ry,
input [63:0] m4rd,
output reg [2:0] m4wx, 
output reg [2:0] m4wy,
output reg m4wr,
output reg [63:0] m4wd,
output reg pushout, input stopout, output reg firstout, output reg [63:0] dout);
//reg m2wr_d;
reg [4:0] round, round_d;
reg [63:0] cmx;reg [63:0] cmx_d;
reg [2:0] cx, cy, incx, incy, cx_d, cy_d, incx_d, incy_d,outcx,outcy,outcx_d,outcy_d;
reg loaded, loaded_d, out_ready, out_ready_d, firstout_d;
reg [63:0] 	r1, r2, r1_d, r2_d, r3, r3_d;
reg [2:0] px2, py2, px3, py3, px2_d, py2_d, px3_d, py3_d, px4, py4, px4_d, py4_d;
reg [2:0] xp1m5, xp2m5, xm1m5,x0,x1,x2,x3,x4; 
reg [127:0] rotate,rotate1;
reg wow_calc; reg wow_calc_d; reg wow_theta, wow_theta_d, wow_rho, wow_rho_d, wow_pi, wow_pi_d, wow_chi, wow_chi_d, wow_iota, wow_iota_d;reg done,done_d; reg happy, happy_d;
reg yay; reg yay_d; reg stopin_d;
typedef enum reg [2:0] { invalid, w2, w2_w3, w3, w4} pcmd;
pcmd pvalid_d;
reg [2:0] pvalid;	//making pvalid a reg instead of enum //AR
typedef struct packed {
	reg [2:0] tx, ty;
	reg [5:0] ramt;
} map;
reg [5:0] permin;
map permout;
typedef struct packed { 
	reg [2:0] nx,ny;
} mapt;
mapt piout;
enum reg [1:0] {outreset, wait_out1, rest_out} outstate_d;
reg [1:0] outstate,instate;//making outstate a reg instead of enum //AR
//reg [1:0] outstate_d;
enum reg [1:0] {reset, wait_in1, rest_in} instate_d;

enum reg [3:0] {preset, wait_load, round0_c,waitstate, calcd, calcd1, calctheta, calcrhopi, calcpi, dochi, dochi1, calciota,check_round, calcc,goout}  perm_state_d;
reg [3:0] perm_state; //making perm_state a reg instead of enum //AR

always @(*) begin
	//stopin=0; 
	loaded_d=loaded;
	m1wx=incx;
	m1wy=incy;
	m1wd=din;
	stopin_d=stopin;
	pvalid_d=invalid;
	px2_d=px2;
	py2_d=py2;
	dout=0;
	//pushout=out_ready;
	out_ready_d=out_ready;
	//firstout_d=firstout;
	firstout=0;
	
	happy_d=happy;
	
	//removing latches
	permout=0;
	cmx_d=cmx;
	incx_d=incx;
	incy_d=incy;
	outcx_d=outcx;
	outcy_d=outcy;
	px3_d=px3;
	py3_d=py3;
	px4_d=px4;
	py4_d=py4;
	r2_d=r2;
	r1_d=r1;
	r3_d=r3;
	cx_d=cx;
	cy_d=cy;
	round_d=round; 
	wow_calc_d=wow_calc;
	m1wr=m1wr;
	m2wr=m2wr;
	m1wx=m1wx;
	m1wy=m1wy;
	m1wd=m1wd;
	m1rx=m1rx;
	m1ry=m1ry;
	//m2wr_d=m2wr;
	m2wx=m2wx;
	m2wy=m2wy;
	m2wd=m2wd;
	m2rx=m2rx;
	m2ry=m2ry;
	m3wr=m3wr;
	m3wx=m3wx;
	m3wy=m3wy;
	m3wd=m3wd;
	m3rx=m3rx;
	m3ry=m3ry;
	m4wr=m4wr;
	m4wx=m4wx;
	m4wy=m4wy;
	m4wd=m4wd;
	m4rx=m4rx;
	m4ry=m4ry;
	instate_d=instate_d;
	perm_state_d=perm_state_d;
	outstate_d=outstate_d;
	case (cx)
		0 :  xm1m5=4;
		1 :  xm1m5=0;
		2 :  xm1m5=1;
		3 :  xm1m5=2;
		4 :  xm1m5=3;
		default: xm1m5=0;
	endcase
	case (cx)
		0 :  xp1m5=1;
		1 :  xp1m5=2;
		2 :  xp1m5=3;
		3 :  xp1m5=4;
		4 :  xp1m5=0;
		default: xp1m5=0;
	endcase
	case (cx)
		0 :  xp2m5=2;
		1 :  xp2m5=3;
		2 :  xp2m5=4;
		3 :  xp2m5=0;
		4 :  xp2m5=1;
		default: xp2m5=0;
	endcase
	case (round)
		0	 : 	cmx_d = 64'h0000000000000001;
		1	 : 	cmx_d = 64'h0000000000008082;
		2	 : 	cmx_d = 64'h800000000000808A;
		3	 : 	cmx_d = 64'h8000000080008000;
		4	 : 	cmx_d = 64'h000000000000808B;
		5	 : 	cmx_d = 64'h0000000080000001;
		6	 : 	cmx_d = 64'h8000000080008081;
		7	 : 	cmx_d = 64'h8000000000008009;
		8	 : 	cmx_d = 64'h000000000000008A;
		9	 : 	cmx_d = 64'h0000000000000088;
		10	 : 	cmx_d = 64'h0000000080008009;
		11	 : 	cmx_d = 64'h000000008000000A;
		12	 : 	cmx_d = 64'h000000008000808B;
		13	 : 	cmx_d = 64'h800000000000008B;
		14	 : 	cmx_d = 64'h8000000000008089;
		15	 : 	cmx_d = 64'h8000000000008003;
		16	 : 	cmx_d = 64'h8000000000008002;
		17	 : 	cmx_d = 64'h8000000000000080;
		18	 : 	cmx_d = 64'h000000000000800A;
		19	 : 	cmx_d = 64'h800000008000000A;
		20	 : 	cmx_d = 64'h8000000080008081;
		21	 : 	cmx_d = 64'h8000000000008080;
		22	 : 	cmx_d = 64'h0000000080000001;
		23	 : 	cmx_d = 64'h8000000080008008;
		
	endcase
	permin={cx,cy};
	case(permin)
		6'b000000 : begin permout = {3'd0, 3'd0, 6'd0}; piout = {3'd0,3'd0};end //00  y=x, x=x+3ymod5
		6'b000001 : begin permout = {3'd1, 3'd3, 6'd36};piout = {3'd3,3'd0};end//01
		6'b000010 : begin permout = {3'd2, 3'd1, 6'd3};piout = {3'd1,3'd0};end//02
		6'b000011 : begin permout = {3'd3, 3'd4, 6'd41};piout = {3'd4,3'd0};end//03
		6'b000100 : begin permout = {3'd4, 3'd2, 6'd18};piout = {3'd2,3'd0};end//04

		6'b001000 : begin permout = {3'd0, 3'd2, 6'd1};piout = {3'd1,3'd1};end//10
		6'b001001 : begin permout = {3'd1, 3'd0, 6'd44}; piout = {3'd4,3'd1};end//11 = 2+
		6'b001010 : begin permout = {3'd2, 3'd3, 6'd10};piout = {3'd2,3'd1};end//12
		6'b001011 : begin permout = {3'd3, 3'd1, 6'd45};piout = {3'd0,3'd1};end//13
		6'b001100 : begin permout = {3'd4, 3'd4, 6'd2};piout = {3'd0,3'd1};end//14

		6'b010000 : begin permout = {3'd0, 3'd4, 6'd62};piout = {3'd2,3'd2};end//20
		6'b010001 : begin permout = {3'd1, 3'd2, 6'd6};piout = {3'd0,3'd2};end//21
		6'b010010 : begin permout = {3'd2, 3'd0, 6'd43};piout = {3'd3,3'd2};end//22
		6'b010011 : begin permout = {3'd3, 3'd3, 6'd15};piout = {3'd1,3'd2};end//23
		6'b010100 : begin permout = {3'd4, 3'd1, 6'd61};piout = {3'd4,3'd2};end//24

		6'b011000 : begin permout = {3'd0, 3'd1, 6'd28};piout = {3'd3,3'd3};end//30
		6'b011001 : begin permout = {3'd1, 3'd4, 6'd55};piout = {3'd1,3'd3};end//31				
		6'b011010 : begin permout = {3'd2, 3'd2, 6'd25};piout = {3'd4,3'd3};end//32
		6'b011011 : begin permout = {3'd3, 3'd0, 6'd21};piout = {3'd2,3'd3};end//33
		6'b011100 : begin permout = {3'd4, 3'd3, 6'd56};piout = {3'd0,3'd3};end//34

		6'b100000 : begin permout = {3'd0, 3'd3, 6'd27};piout = {3'd4,3'd4};end//40		
		6'b100001 : begin permout = {3'd1, 3'd1, 6'd20};piout = {3'd2,3'd4};end//41
		6'b100010 : begin permout = {3'd2, 3'd4, 6'd39};piout = {3'd0,3'd4};end//42
		6'b100011 : begin permout = {3'd3, 3'd2, 6'd8};piout = {3'd3,3'd4};end//43
		6'b100100 : begin permout = {3'd4, 3'd0, 6'd14};piout = {3'd1,3'd4};end//44
		default: begin permout={3'd0,3'd0,6'd0}; piout={3'd0,3'd0,6'd0};end

	endcase
	//Input state machine
	case (instate)
		reset : begin
			incx_d = 0; incy_d = 0;
			instate_d = wait_in1;
		end
		wait_in1 : begin
			m1wr=0;
			incx_d = 0; incy_d = 0;
			if(pushin&&!stopin&&firstin) begin	//added !loaded
				m1wr=1;
				incx_d=incx+1;
				instate_d = rest_in;
			end
		end
		rest_in : begin
			if(pushin&&!stopin) begin
				m1wr=1;
				incx_d=incx+1;
				if (incx==4) begin incx_d=0; incy_d=incy+1; 
					if (incy==4) begin 
						incy_d=0; 
						loaded_d=1; 
						m1wr=1;	//MAKING 1
						instate_d = wait_in1;
						stopin_d=1;
					end
				end
			end
		end
		
		default: instate_d=wait_in1; 
	endcase
	
	case (perm_state) 
		preset : begin
			cx_d=0; cy_d=0; round_d=0; pvalid_d=invalid;	//pvalid is a ff not a comb //AR
			perm_state_d=wait_load;
		end
		wait_load : begin
			cx_d=0; cy_d=0; round_d=0; r1_d=0; r2_d=0;
			if(loaded && !pushout) perm_state_d=round0_c;	//if pushout low	//loaded && 
		end
		round0_c : begin
			
			m1rx=cx; m1ry=cy;
			px2_d=cx; py2_d=cy;		//round0c=m2, d=m3,theta=m2,rho=m3,pi=m4,chi=m3,iota=m2
			pvalid_d =w2;
			m2wr=1;
			r1_d=m1rd;
			if(cy==0) r2_d=m1rd;
			else r2_d=m1rd ^ r2;
			cy_d=cy+1;
			if(cy==4) begin
				cy_d=0;
				pvalid_d=w2_w3;
				m2wr=1;
				px3_d=cx;
				py3_d=0;
				cx_d=cx+1;
				if(cx==4) begin
					cx_d=0;
					perm_state_d=waitstate;
					
					
				end
			end
			
		end
		//added a wait state for last data to get loaded //AR
		waitstate:begin
			loaded_d=0;
			stopin_d=0;
			perm_state_d=calcd;
		end
		calcd : begin
			m3rx=xm1m5; m3ry=0;
			r2_d=m3rd;
			perm_state_d=calcd1;	
		end
		calcd1 : begin
			m3rx=xp1m5; m3ry=0;
			r2_d = r2 ^ {m3rd[62:0], m3rd[63]};
			px3_d=cx;
			py3_d=1;
			pvalid_d=w3;
			cx_d=cx+1;
			if(cx==4) begin
				cx_d=0; cy_d=0;
				perm_state_d=calctheta;
			end else perm_state_d=calcd;
		end
		calctheta : begin
		
			m2rx=cx; m2ry=cy;
			m3rx=cx; m3ry=1;
			r1_d= m2rd ^ m3rd;
			px2_d=cx;
			py2_d=cy;
			pvalid_d=w2;
				m2wr=1;
			cx_d=cx+1;
			if(cx==4) begin
				cx_d=0;
				cy_d=cy+1;
				if(cy==4) begin
					cy_d=0;
					perm_state_d=calcrhopi;
					wow_calc_d=0;
				end
			end
		end
		calcrhopi : begin
			m2rx=cx; m2ry=cy;
			px4_d=permout.tx;
			py4_d=permout.ty;
			rotate={64'h0, m2rd};
			rotate=rotate<<permout.ramt;
			r3_d=rotate[63:0]|rotate[127:64];
			pvalid_d=w4;
			cx_d=cx+1;
			if(cx==4) begin
				cx_d=0;
				cy_d=cy+1;
				if(cy==4) begin
					cy_d=0;
					perm_state_d=dochi;
				end
			end	
		end		

		/*calcpi : begin 
			m3rx=cx; m3ry=cy;
			px4_d=cx; 
			py4_d=cy; 
			rotate1={64'h0, m3rd};
			r3_d=rotate1[63:0]|rotate1[127:64];
			pvalid_d=w4;
			cx_d=cx+1;
			if(cx==4) begin
				cx_d=0;
				cy_d=cy+1;
				if(cy==4) begin
					cy_d=0;
					perm_state_d=dochi;
				end
			end
		end*/
		dochi: begin
			m4rx=cx; m4ry=cy;
			px2_d=cx; py2_d=cy; px3_d=cx; py3_d=cy;
			r1_d=m4rd;r2_d=m4rd;
			pvalid_d=w2_w3; 
			m2wr=1;
			cx_d=cx+1;
			if(cx==4) begin
				cx_d=0;
				cy_d=cy+1;
				if(cy==4) begin
					cy_d=0;
					perm_state_d=dochi1;
				end
			end
		end
		dochi1: begin

			m2rx=cx;m2ry=cy; m3rx=xp1m5; m3ry=cy; m4rx=xp2m5; m4ry=cy;
			px2_d=cx; py2_d=cy; 
			if (cx==0 && cy==0) 
			r1_d = ((m2rd ^ (( m3rd ^ {64{1'b1}}) & m4rd )) ^ cmx);
			else 
			r1_d = m2rd ^ (( m3rd ^ {64{1'b1}}) & m4rd ); 
			pvalid_d=w2;
			m2wr=1;
			/*cx_d=cx+1;
			if(cx==4) begin
				cx_d=0;
				cy_d=cy+1;
				if(cy==4) begin
					cy_d=0;
					m2wr=0;
					perm_state_d=calciota;
				end
			end
		end*/
	
		/*calciota : begin
			m3rx=cx;
			m3ry=cy;
			m3wr=0;
			px2_d=cx;
			py2_d=cy;
			pvalid_d=w2;
			if(cx==0 && cy==0) 
				r1_d=m3rd ^ cmx;
			else r1_d=m3rd;
			
			//outside rounds
			/*if(happy) begin
				round_d=0;
				perm_state_d=wait_load;//added recently 
			end*/
			cx_d=cx+1;
			if(cx==4) begin
				cx_d=0;
				cy_d=cy+1;
				if(cy==4) begin
					cy_d=0;
					perm_state_d=check_round;
				/*	if(round==23) begin
						//out_ready_d=1;
						//firstout_d=1;
						//m2wr=0;
						
						outstate_d=rest_out; 
					//	if(happy) begin
					//		round_d=0;
					//		perm_state_d=wait_load;//added recently 
					//	end
							//if(round==23 && outcx_d==0 && outcy_d==0)firstout_d=1;
							//else firstout_d=0;   
					end else begin 
						round_d=round+1;
						perm_state_d=calcc;
					end*/
				end
			end	
		
		end
		check_round: begin 
			if(round==23) begin 
				outstate_d=rest_out;
				round_d=0;
				perm_state_d=wait_load; 
			end
			else begin 
				round_d=round+1;
				perm_state_d=calcc;
			end 
		end	
		
		calcc : begin
			m2rx=cx; m2ry=cy;
			px2_d=cx; py2_d=cy;
			pvalid_d = w4;
			r3_d=m2rd;
			if(cy==0) 
			r2_d=m2rd;
			else 
			r2_d=m2rd ^ r2;
			cy_d=cy+1;
			if(cy==4) begin
				cy_d=0;
				pvalid_d=w3;
				px3_d=cx;
				py3_d=0;
				cx_d=cx+1;
				if(cx==4) begin
					cx_d=0;
					m3wr=0;
					wow_calc_d=1;
					if(wow_calc==1)perm_state_d=calcd;
				end
			end
end	
default: perm_state_d= preset;	
endcase
   // pushout = 0;
	case (outstate)
		outreset : begin
		
			outcx_d = 0; outcy_d = 0;
			outstate_d = wait_out1;
		end
		wait_out1 : begin
			
			outcx_d = 0; outcy_d = 0; 
			firstout=0;
			happy_d=0;
			//redundant
			/*if(pushout&&firstout&&!stopout) begin
				m2wr=0;
				outcx_d=outcx+1;
				outstate_d = rest_out;
				firstout=0;
			end*/
		end
		rest_out : begin
		//	if (m2wx==0 && m2wy == 0 && pushout==1) m2wr=0;
			//m2wr_d=0;
				m2rx=outcx;
				m2ry=outcy; //reading output from M2
		m2wr=0;
			/*if(!stopout) 
				pushout=1;
			else pushout=0;*/
			
			if(outcx==0 && outcy ==0) begin
				firstout=1;
			end
			else firstout=0;
			
			//stopout should be opposite of pushout
			//if (stopout==0)	//AR
				//pushout=1;
			//else pushout =0;
			
			//dout=m2rd;
			
			if(pushout) begin
			
				dout = m2rd; 
				if (!stopout) begin
					outcx_d=outcx+1; 
					if (outcx==4) begin 
						outcx_d=0; outcy_d=outcy+1;
						if (outcy==4) begin 
							outcy_d=0;
								//m2wr= 0;
							outstate_d = wait_out1;
							//pushout=0;
							happy_d=1;
							//stopin_d=0;
						end
					end
				end
			end
		end
		default: outstate_d=outreset;
	endcase
	case(pvalid)
	invalid: begin 
	//m2wr_d=0; 
	m3wr=0; end //chaged m2wrd
	w2 : begin
		
		//m2wr=1;
		m2wx=px2;
		m2wy=py2;
		m2wd=r1;
	end
	w2_w3 : begin
		//m2wr=1;
		m2wx=px2;
		m2wy=py2;
		m2wd=r1;
		m3wr=1;
		m3wx=px3;
		m3wy=py3;
		m3wd=r2;
	end
	w3 : begin
		m3wr=1;
		m3wx=px3;
		m3wy=py3;
		m3wd=r2;
	end
	w4 : begin
		m4wr=1;
		m4wx=px4;
		m4wy=py4;
		m4wd=r3;
	end 
	default: pvalid_d=invalid; 
	endcase
end
/*always @ (posedge clk or posedge rst) begin
   if(rst)
      stopin <= #1 0;
   else if((perm_state == wait_load)  && (outcx == 4) && (outcy == 4))
      stopin <= #1 0;
   else if(pushin && (incx == 4) && (incy == 4)|| (perm_state == preset))
      stopin <= #1 1;
end
*/
assign pushout = (outstate==rest_out) ? 1:0;
//assign m2wr = ((perm_state ==round0_c) || (perm_state==calctheta) || (perm_state==dochi) || (perm_state==dochi1 && round!=23) ) ? 1:0;
/*always @ (posedge clk) begin
if(pushout) m2wr=0;
end*/
always @(posedge clk or posedge rst) begin 
if(rst) begin 
	round<=0;
	cx<=0; 
	wow_calc<=0; 
	done<=0;
	cy<=0; 
	incx<=0;
	incy<=0; 
	loaded<=0; 
	out_ready<=0; 
	r1<=0; 
	r2<=0; 
	r3<=0; 
	px2<=0;
	py2<=0;
	px3<=0;
	py3<=0;
	px4<=0;
	py4<=0;
	pvalid<=0;
	outcx<=0; 
	outcy<=0;
	//firstout<=0; 
	outstate<=0;
	instate<=0; 
	perm_state<=0; 
	happy<=0;
	stopin<=0;
	cmx<=0;
	//m2wr <= 0;
end
else begin 
round<=#1 round_d;
done<=#1 done_d; 
cx<=#1 cx_d; outcx<= #1 outcx_d; outcy<=#1 outcy_d; 
cy<=#1 cy_d; incx<=#1 incx_d; incy<=#1 incy_d; loaded<=#1 loaded_d; out_ready<=#1 out_ready_d; r1<=#1 r1_d; r2<=#1 r2_d; r3<=#1 r3_d; px2<=#1 px2_d;wow_calc<= #1 wow_calc_d;
py2<=#1 py2_d;px3<=#1 px3_d;py3<=#1 py3_d;px4<=#1 px4_d;py4<=#1 py4_d;pvalid<=#1 pvalid_d;
instate<=#1 instate_d; perm_state<=#1 perm_state_d; 
happy<= #1 happy_d;
//firstout<= #1 firstout_d; 
outstate<= #1 outstate_d;
stopin<= #1 stopin_d; cmx<= #1 cmx_d;
end
end
endmodule
