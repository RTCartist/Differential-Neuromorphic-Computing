/* UART transmission module
* Default 8-bit data, 1 stop bit
* baud_rate is used to determine the baud rate, available baud rates are 9600/38400/115200
* trans_complete indicates transmission completion, ready for new transmission
* begin_trans indicates the start of transmission, active high
* June 14, 2019
* Usage:
* When transmitting data, place the data in tx_data and set begin_tx high
* Wait for trans_complete to be high, then set begin_tx low to complete one frame of transmission
*/

module uart_tx(
    input               clk_50m,
    input               rst_n,
    //input   [1:0]       IsParityCheck,
    input   [7:0]       tx_data,
    input               begin_tx,
    input   [17:0]      baud_rate,

    output              TX,
    output  reg         trans_complete
);

reg     [11:0]  next_state;
reg     [11:0]  state;
reg             r_TX;
reg     [12:0]  counter;
reg     [12:0]  step_counter; // Determines the time point for each conversion during UART transmission
reg     [3:0]   bit_counter;
reg             parity_signal; // Parity check signal

wire    [10:0]  frame_data;

assign frame_data = {1'b1, tx_data, 1'b0};
assign TX = r_TX;

always @(*) begin
//     if(IsParityCheck==2'd2)
//         parity_signal = ^tx_data;
//     else
//         parity_signal = ~(^tx_data);
end

always @(*) begin // Determines the time point for each conversion at different baud rates
    if (baud_rate == 18'd9600) begin
        step_counter = 13'd5208;
    end else if (baud_rate == 18'd38400) begin
        step_counter = 13'd1302;
    end else if (baud_rate == 18'd115200) begin
        step_counter = 13'd434;
    end else if (baud_rate == 18'd230400) begin
        step_counter = 13'd217;
    end else
        step_counter = 0;
end

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        counter <= 0;
    else if (counter == step_counter-1'b1)
        counter <= 0;
    else if (begin_tx == 1'b1)
        counter <= counter + 1'b1;
    else
        counter <= 0;
end

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) 
        bit_counter <= 0;
    else if (bit_counter == 4'd9 && counter == step_counter-1'b1)
        bit_counter <= 0;
    else if (counter == step_counter-1'b1)
        bit_counter <= bit_counter + 1'b1;
end

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        r_TX <= 1'b1;
    else if (begin_tx == 1'b1 && trans_complete != 1'b1)
        r_TX <= frame_data[bit_counter];
    else
        r_TX <= 1'b1;
end

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        trans_complete <= 0;
    else if (bit_counter == 4'd9 && counter == step_counter-1'b1)
        trans_complete <= 1'b1;
    else
        trans_complete <= 0;
end

// always @(posedge clk_50m or negedge rst_n) begin
//     if(!rst_n)begin
//         counter<=0;
//         bit_counter<=0;
//     end
//     else if(begin_tx==1'b1) begin
//         if(counter==step_counter-1'b1)begin
//             counter<=0;
//             bit_counter<=bit_counter+1'b1;
//         end
//         else    
//             counter<=counter+1'b1;
//     end
//     else begin
//         counter<=0;
//         bit_counter<=0;
//     end
// end

// always @(posedge clk_50m or negedge rst_n) begin
//     if(!rst_n)begin
//         r_TX<=1'b1;
//         trans_complete<=1'b0;
//     end
//     // else if(trans_complete==1'b1)//2020/9/8加入的判断语句，用于在传输完成后立即将信号置低
//     //     trans_complete  <=  0;
//     else if(IsParityCheck!=2'd0&&begin_tx==1'b1) begin
//         if(counter==0&&bit_counter!=4'd11)
//             r_TX<=frame_data[bit_counter];
//         else if(bit_counter==4'd11) begin
//             trans_complete<=1'b1;    
//             r_TX<=1;
//         end
//     end
//     else if(IsParityCheck==2'd0&&begin_tx==1'b1)begin
//         if(counter==0&&bit_counter!=4'd9)
//             r_TX<=frame_data[bit_counter];
//         else if(bit_counter==4'd9)
//             r_TX<=frame_data[10];
//         else if(bit_counter==4'd10) begin
//             trans_complete<=1'b1;    
//             r_TX<=1;
//         end
//     end
//     else if(!begin_tx)
//         trans_complete<=1'b0;
// end

endmodule
