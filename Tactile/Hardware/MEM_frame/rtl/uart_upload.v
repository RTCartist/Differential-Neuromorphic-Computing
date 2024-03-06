module uart_upload(
    input               clk_50m,
    input               rst_n,

    input       [7:0]   wFIFO_idata,
    input               wFIFO_wrreq,
    output              wFIFO_full,

    input               uart_send,
    output              uart_send_done,
    output              uart_rdy,

    output              TX
);

reg                 uart_sign;

wire    [7:0]       wFIFO_odata;
wire                wFIFO_empty;
wire                wFIFO_rdreq;

wire    [7:0]       tx_data;
wire                begin_tx;
wire    [17:0]      baud_rate   =   18'd230400;
wire                trans_complete;

assign              uart_rdy    =   !uart_sign;
assign              tx_data     =   wFIFO_odata;
assign              begin_tx    =   uart_sign&&!(trans_complete&&wFIFO_empty);
assign              wFIFO_rdreq =   uart_sign&&trans_complete&&!(trans_complete&&wFIFO_empty);
assign              uart_send_done  =   trans_complete&&wFIFO_empty;


always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        uart_sign   <=  0;
    else if(uart_send==1'b1)
        uart_sign   <=  1'b1;
    else if(trans_complete&&wFIFO_empty)
        uart_sign   <=  0;
end

write_FIFO write_FIFO1(//writing data and flag synchronization, which means, when data and the write flag are raised together, data can be written normally
    .clock      (clk_50m),
    .data       (wFIFO_idata),//o
    .rdreq      (wFIFO_rdreq),//i
    .wrreq      (wFIFO_wrreq),//o
    .empty      (wFIFO_empty),//i
    .full       (wFIFO_full),//i
    .q          (wFIFO_odata)//i
);

uart_tx uart_tx_u0(
    .clk_50m        (clk_50m        ),
    .rst_n          (rst_n          ),
    .tx_data        (tx_data        ),
    .begin_tx       (begin_tx       ),
    .baud_rate      (baud_rate      ),
    .TX             (TX             ),
    .trans_complete (trans_complete )
);

endmodule