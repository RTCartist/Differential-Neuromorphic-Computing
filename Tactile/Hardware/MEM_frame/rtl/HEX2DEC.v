/*

Module Name: HEX2DEC
Function: Convert a 12-bit hexadecimal number to a 16-bit BCD code (decimal)
Overview: The input is limited to a 12-bit hexadecimal number. When using, raise Begin_HEX2DEC while entering data on HEX_data, wait for HEX2DEC_completed to be raised (lasts for one clock cycle), then read the 16-bit BCD code on DEC_data. The calculation process is as follows: 1. Shift the input to the left by one bit to the output. 2. Determine if the four 4-bit hexadecimal numbers in the 16-bit output are greater than or equal to 5; if greater than 5, add 3 to the corresponding 4-bit hexadecimal number. 3. Repeat the above steps until the last input bit is shifted to the output, at which point no further judgment is made, and the output is directly produced.
*/
module HEX2DEC
(
    input                   clk_50m,
    input                   rst_n,
    input   [11:0]          HEX_data,
    input                   Begin_HEX2DEC,

    output  reg [15:0]      DEC_data,
    output  reg             HEX2DEC_completed
);

parameter   IDLE    =   4'b0001;
parameter   SHIFT   =   4'b0010;
parameter   JUDGE   =   4'b0100;
parameter   ADD     =   4'b1000;

reg     [3:0]   state;

reg     [3:0]   step_counter;
reg     [15:0]  sign_bit;


always @(posedge clk_50m or negedge rst_n) begin 
    if(!rst_n)  begin
        DEC_data            <=  0;
        state               <=  IDLE;
        sign_bit            <=  0;
        HEX2DEC_completed   <=  0;
    end
    else 
        case(state)
        IDLE:begin
            HEX2DEC_completed   <=  0;
            DEC_data            <=  0;
            if(Begin_HEX2DEC==1'b1&&HEX2DEC_completed!=1'b1)
                state   <=  SHIFT;
            else
                state   <=  IDLE;
        end
        SHIFT:begin
            DEC_data    <=  {DEC_data[14:0],HEX_data[11-step_counter]};
            state       <=  JUDGE;
            if(step_counter==4'd11) begin
                state   <=  IDLE;
                HEX2DEC_completed   <=  1'b1;
            end
            else
                state   <=  JUDGE;
        end
        JUDGE:begin
            state       <=  ADD;
            if(DEC_data[15:12]>=4'd5)
                sign_bit[15:12] <=  4'b0011;
            else
                sign_bit[15:12] <=  0;
            if(DEC_data[11:8]>=4'd5)
                sign_bit[11:8]  <=  4'b0011;
            else
                sign_bit[11:8] <=  0;
            if(DEC_data[7:4]>=4'd5)
                sign_bit[7:4]   <=  4'b0011;
            else
                sign_bit[7:4] <=  0;
            if(DEC_data[3:0]>=4'd5)
                sign_bit[3:0]   <=  4'b0011;
            else
                sign_bit[3:0] <=  0;
        end
        ADD:begin
            DEC_data    <=  DEC_data+sign_bit;
            sign_bit    <=  0;
            // if(step_counter==4'd11) begin
            //     state   <=  IDLE;
            //     HEX2DEC_completed   <=  1'b1;
            // end
            // else
            state       <=  SHIFT; 
        end
        default: begin
            state   <=  IDLE;
        end
        endcase
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        step_counter    <=  0;
    else if(state==IDLE)
        step_counter    <=  0;
    else if(state==SHIFT)
        step_counter    <=  step_counter+1'b1;
end

endmodule