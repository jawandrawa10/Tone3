module mux2to1 #(parameter N) (
    input  logic [N-1:0] in0, in1,
    input  logic         sel,
    output logic [N-1:0] out
);
    always_comb begin
        if (sel)
            out = in1;
        else
            out = in0;
    end
endmodule

module mux3to1 #(parameter N) (
    input  logic [N-1:0] in0, in1, in2,
    input  logic [1:0]   sel,
    output logic [N-1:0] out
);
    always_comb begin
        case (sel)
            2'b00:   out = in0;
            2'b01:   out = in1;
            2'b10:   out = in2;
            default: out = '0;
        endcase
    end
endmodule
