module mux2to1 #(parameter N) (
    input logic [N-1:0] in0, in1,
    input logic sel0,
    output logic [N-1:0] out
) 
    always_comb begin
        out = 'b0;
        if (sel0) 
            out = in0;
        else 
            out = in1;
    end
endmodule