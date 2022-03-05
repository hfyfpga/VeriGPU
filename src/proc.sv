// represents processor
module proc(
    input rst, clk,
    output reg [15:0] out,
    output reg [3:0] op,
    output reg [3:0] reg_select,
    output reg [7:0] p1,
    output [7:0] x1,
    output reg [15:0] pc,
    output reg [4:0] state,
    output reg outen,

    output reg [15:0] mem_addr,
    input [15:0] mem_rd_data,
    output reg [15:0] mem_wr_data,
    output reg mem_wr_req,
    output reg mem_rd_req,
    input mem_ack,
    input mem_busy
);
    reg [7:0] regs[16];
    reg [15:0] instruction;
    typedef enum bit[4:0] {
        RESET,
        AWAITING_INSTR,
        GOT_INSTR,
        GOT_INSTR2
    } e_state;

    wire [3:0] c1_op;
    wire [3:0] c1_reg_select;
    wire [7:0] c1_p1;

    typedef enum bit[3:0] {
        OUT = 1,
        OUTLOC = 2,
        LI = 3,
        OUTR = 4
    } e_op;

    task read_next_instr([15:0] instr_addr);
        mem_addr <= instr_addr;
        mem_rd_req <= 1;
        state <= AWAITING_INSTR;
    endtask

    task write_out([7:0] _out);
        out[7:0] <= _out;
        outen <= 1;
    endtask

    task instr_c1();
        case (c1_op)
            OUT: begin
                write_out(c1_p1);
                pc <= pc + 1;
                read_next_instr(pc + 1);
            end
            OUTLOC: begin
                mem_addr <= {8'b0, 1'b0, c1_p1[7:1]};
                mem_rd_req <= 1;
                state <= GOT_INSTR;
            end
            LI: begin
               regs[c1_reg_select] <= c1_p1;
                pc <= pc + 1;
                read_next_instr(pc + 1);
            end
            OUTR: begin
                mem_wr_req <= 0;
                write_out(regs[c1_reg_select]);
                pc <= pc + 1;
                read_next_instr(pc + 1);
           end
           default: out <= '0;
        endcase
    endtask

    task instr_c2();
        case (op)
            OUTLOC: begin
                write_out(mem_rd_data);
                pc <= pc + 1;
                read_next_instr(pc + 1);
            end
        endcase
    endtask

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out <= '0;
            pc <= '0;
            state <= RESET;
        end
        else begin
            out <= '0;
            mem_rd_req <= 0;
            mem_wr_req <= 0;
            outen <= 0;
            case(state)
                RESET: begin
                    mem_addr <= pc;
                    mem_rd_req <= 1;
                    state <= AWAITING_INSTR;
                end
                AWAITING_INSTR: begin
                    mem_rd_req <= 0;
                    if(mem_ack) begin
                        instr_c1();
                        instruction <= mem_rd_data;
                        op <= mem_rd_data[11:8];
                        reg_select <= mem_rd_data[15:12];
                        p1 <= mem_rd_data[7:0];
                    end
                end
                GOT_INSTR: begin
                    if(mem_ack) begin
                        instr_c2();
                    end
                end
                default: out <= '0;
            endcase
        end
    end
    assign c1_op = mem_rd_data[11:8];
    assign c1_reg_select = mem_rd_data[15:12];
    assign c1_p1 = mem_rd_data[7:0];
    assign x1 = regs[1];
endmodule
