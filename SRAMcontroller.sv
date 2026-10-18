module Memory_System(
    input logic [31:0] addr,
    output logic [31:0] data_out,
    input logic [31:0] data_in,
    input logic [3:0] write_en,
    input logic read_en,
    output logic mem_ready
    );
    
    typedef enum logic [1:0] {
        IDLE,
        WRITE,
        READ,
        READ_WAIT
    } state_t;

    state_t state, next_state;
    logic ena;
    logic [3:0 ]wea;
    logic [13 : 0] addra;
    logic [31:0] dina, douta;

    data_sram SRAM (
        .clka(clka),    // input wire clka
        .ena(ena),      // input wire ena
        .wea(wea),      // input wire [3 : 0] wea
        .addra(addra),  // input wire [13 : 0] addra
        .dina(dina),    // input wire [31 : 0] dina
        .douta(douta)  // output wire [31 : 0] douta
    );

    //FSM 
    always_comb begin
    next_state = state;
    ena = 0;
    wea = 0;
    addra = '0;
    dina = '0;
    douta = '0;
    
        case (state) 
            IDLE: begin
                mem_ready = 0;
                if (read_en)
                    next_state = read;
                    addra = addr[13:0];
                    en = 1;
                if (write_en)
                    next_state = write;
                    en = 1;
                    addra = addr[13:0];
                    wea = write_en;
                    dina = data_in;
            end 

            READ: begin
                data_out = douta;
                mem_ready = 1; 
                next_state = idle;
            end

            WRITE: begin
                next_state = WRITE_WAIT;
            end 
            WRITE_WAIT: begin
                mem_ready = 1;
                next_state = IDLE
            end
    endcase
    end

    //update of state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= idle;
        end else begin 
            state <= next_state;
        end
    end 

endmodule