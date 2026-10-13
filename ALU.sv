module ALU #(
    parameter BW = 8
    )(
    input  logic [BW-1:0] in_a,
    input  logic [BW-1:0] in_b,
    output logic [BW-1:0] out,
    input  logic [3:0] opcode,
    output logic [2:0] flags
);
    logic zero, overflow, negative;
    always_comb begin
        out = '0;
        case (opcode)
            //ADD
            //4'b0000: out = $signed(in_a) + $signed(in_b);
            4'b0000: out = in_a + in_b;
            //SUB
            //4'b0001: out= $signed(in_a) - $signed(in_b);
            4'b0000: out = in_a - in_b;
            //Logical Left shift, shamnt is in_b
            4'b0010: out = in_a << in_b[$clog2(BW)-1:0] ;
            //Less than signed
            4'b0100: begin
                if (in_a[BW-1] & !in_b[BW-1])
                    out=1'b1;
                else if (!in_a[BW-1] & in_b[BW-1])
                    out=1'b0;
                else
                    out=(in_a[BW-2:0]<in_b[BW-2:0])?1:0;            
            end
            //Less than unsigned
            4'b0110: out = (in_a < in_b)?1:0;
                    //out[0]=(in_a < in_b)
                    //out=(in_a < in_b)
            //XOR
            4'b1000: out = in_a ^ in_b; //bit a bit
            //Logical right shift, shamnt is in_b
            4'b1010: out = in_a >> in_b[$clog2(BW)-1:0];
            //Arithmetic right shift
            4'b1011: out = $signed(in_a) >>> in_b[$clog2(BW)-1:0];
            //OR
            4'b1100: out = in_a | in_b;
            //AND
            4'b1110: out = in_a & in_b ;
            //pass_b
            4'b1111: out = in_b;
        endcase
    end
    always_comb begin
        overflow='0;        
        if (opcode==4'b0001) //SUB overflow
            overflow= ((in_a[BW-1] != in_b[BW-1]) & (in_a[BW-1] != out[BW-1]))?1:0;
        
        if (opcode==4'b0000) //ADD overflow
            overflow = ((in_a[BW-1] & in_b[BW-1] & ~out[BW-1]) | (~in_a[BW-1] & ~in_b[BW-1] & out[BW-1]))?1:0;
    end
    assign negative=out[BW-1];
    assign zero=(out=='0);
    assign flags={overflow,negative,zero};
endmodule