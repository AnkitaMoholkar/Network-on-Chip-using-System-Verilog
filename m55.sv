// This is a memory model for the perm_blk
//

module m55(input clk, input rst, input reg [2:0] rx,input reg [2:0] ry, output reg [63:0] rd,
    input reg [2:0] wx,input reg [2:0] wy, input reg wr, input reg [63:0] wd);
    
    reg [4:0][4:0][63:0] mdata;
    
    always @(*) begin
        rd<=#1 mdata[ry][rx];
    end
    always @(posedge(clk) or posedge(rst)) begin
	/*$display("[0][0][64] %h",mdata[0][0]);
	$display("[1][0][64] %h",mdata[0][1]);
	$display("[2][0][64] %h",mdata[0][2]);
	$display("[3][0][64] %h",mdata[0][3]);
	$display("[4][0][64] %h",mdata[0][4]);
	$display("[0][1][64] %h",mdata[1][0]);
	*/
        if(rst) begin
            mdata <= 64'hdeaddeaddeaddead;
        end else begin
            if(wr) begin
                mdata[wy][wx]<=#1 wd;
            end
        end
    end
endmodule : m55
