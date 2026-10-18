module SRAMcontroller(
    input logic         clk,
    input logic         rst_n,
    input logic [31:0]  addr,
    input logic [31:0]  data_in,
    input logic [3:0]   write_en,
    input logic         read_en,
    output logic [31:0] data_out,
    output logic        mem_ready
    );
    
    typedef enum logic [1:0] {
        IDLE,
        WRITE,
        READ,
        READ_WAIT
    } state_t;

    state_t state, next_state;
    logic       ena;
    logic[3:0]  wea;

    data_sram SRAM (
        .clka(clk),    // input wire clka
        .ena(ena),      // input wire ena
        .wea(wea),      // input wire [3 : 0] wea
        .addra(addr[15:2]),  // input wire [13 : 0] addra
        .dina(data_in),    // input wire [31 : 0] dina
        .douta(data_out)  // output wire [31 : 0] douta
    );

    //FSM 
    always_comb begin
    next_state  = state;
    ena         = 1'b0;
    wea         = 4'b0000;
    mem_ready   = 1'b0;
        case (state) 
            IDLE: begin
                mem_ready = 1'b0;
                if (read_en) begin   
                    next_state = READ;
                    ena = 1'b1;
                end
                if (write_en) begin
                        next_state = WRITE;
                        ena = 1'b1;
                        wea = write_en;
                end
            end 
            READ: begin
                ena = 1'b1; 
                next_state = READ_WAIT;
            end
            READ_WAIT: begin
                mem_ready = 1'b1;
                next_state = IDLE;
            end
            WRITE: begin
                mem_ready = 1'b1;
                next_state = IDLE;
            end
            default:next_state = IDLE;
    endcase
    end

    //update of state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin 
            state <= next_state;
        end
    end 

endmodule