module SelectiveNegator(
    input logic[31:0] in,
    input logic invertion_en,
    output logic out
);
    always_comb begin
        out=1'b0;
        if(invertion_en) begin
            if(in == '0)
                out = 1'b1;
            else 
                out = 1'b0;
        end
        else begin
            if(in == '0)
                out = 1'b0;
            else 
                out = 1'b1;
        end
    end
endmodule