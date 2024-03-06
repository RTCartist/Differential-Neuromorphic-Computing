module data_upload (
    //sys input
    input                   clk_i,
    input                   rst_n_i,
    //CYUSB pin
    input                   flagA_i,
    input                   cy_full_i,
    input                   cy_empty_i,
    output                  slcs_o,
    output                  sloe_o,
    output                  slrd_o,
    output                  slrwr_o,
    output                  pktend_o,
    input           [7:0]   USB_idata_i,
    output          [7:0]   USB_odata_o,
    output          [1:0]   FIFOadr_o,
    output                  fd_sign_o,
    //signals interacting with the upper module
    input           [15:0]  memristor_adc_data_i,
    input           [15:0]  piezo_adc_data_i,
    input           [3:0]   ch_sign_i,
    input           [1:0]   mem_state_i,
    //uart
    output                  TX,
    //handshake signals
    input                   data_vld_i,//ready
    output                  data_rdy_o
);


//****************************cyUSB wire**********************************//

//USB trans FIFO
reg         [7:0]       wFIFO_idata;
wire                    wFIFO_wrreq;
wire                    wFIFO_full;

reg         [7:0]       rRAM_odata;
reg         [8:0]       rRAM_rdaddr;

//USB interaction
wire                    USB_send;
wire                    USB_norece;
wire                    USB_busy;
wire                    USB_rece_done;
wire                    USB_send_done;

wire                    uart_rdy;

//****************************cyUSB wire**********************************//

localparam              IDLE        =   4'b0001;
localparam              HEX2DEC     =   4'b0010;
localparam              SEND        =   4'b0100;
localparam              UPLOAD      =   4'b1000;

reg         [3:0]       state;

wire                    go_idle;
wire                    go_hex2dec;
wire                    go_send;
wire                    go_upload;

//****************************counter**********************************//

reg         [4:0]       byte_cnt;
reg         [3:0]       ch_cnt;//counts how many channels' data have been stored, upload once every 16 channels

//****************************HEX2DEC connection wire**********************************//

wire        [11:0]      HEX_data;
wire                    Begin_HEX2DEC; 

wire        [15:0]      DEC_data;
wire                    HEX2DEC_completed;

reg         [2:0]       hex_cnt;
reg         [11:0]      mem_adc_dec;
reg         [11:0]      mem_adc_int;
reg         [11:0]      piez_adc_dec;
reg         [11:0]      piez_adc_int;
reg         [11:0]      ch_int;

//****************************状State machine transition跳转**********************************//



`ifdef USB
    `ifdef test_ch
        assign                  go_idle     =   (state==SEND&&byte_cnt==5'd31)  ||
                                                (state==UPLOAD&&USB_send_done);
        assign                  go_hex2dec  =   (state==IDLE&&data_vld_i&&data_rdy_o&&!USB_busy);
        assign                  go_send     =   (state==HEX2DEC&&hex_cnt==3'd4&&HEX2DEC_completed);
        assign                  go_upload   =   (state==SEND&&byte_cnt==5'd31&&cy_full_i==1'b1);
    `else 
        assign                  go_idle     =   (state==SEND&&byte_cnt==5'd31)  ||
                                                (state==UPLOAD&&USB_send_done);
        assign                  go_hex2dec  =   (state==IDLE&&data_vld_i&&data_rdy_o&&!USB_busy);
        assign                  go_send     =   (state==HEX2DEC&&hex_cnt==3'd4&&HEX2DEC_completed);
        assign                  go_upload   =   (state==SEND&&byte_cnt==5'd31&&ch_cnt==4'd15&&cy_full_i==1'b1);
    `endif
`else
assign                  go_idle     =   (state==SEND&&byte_cnt==5'd31)  ||
                                        (state==UPLOAD&&USB_send_done);
assign                  go_hex2dec  =   (state==IDLE&&data_vld_i&&data_rdy_o);
assign                  go_send     =   (state==HEX2DEC&&hex_cnt==3'd4&&HEX2DEC_completed);
assign                  go_upload   =   (state==SEND&&byte_cnt==5'd31&&ch_cnt==4'd15&&uart_rdy);
`endif

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        state   <=  IDLE;
    else 
        case(state)
            IDLE: begin
                if(go_hex2dec)
                    state   <=  HEX2DEC;
            end
            HEX2DEC: begin
                if(go_send)
                    state   <=  SEND;
            end
            SEND: begin
                if(go_upload)
                    state   <=  UPLOAD;
//                else if(go_idle)
//                    state   <=  IDLE;
            end
            UPLOAD: begin
                if(go_idle)
                    state   <=  IDLE;
            end
        endcase
end

//****************************HEX2DEC**********************************//
//AD16 to BCD 169 1 6 9 
assign                  Begin_HEX2DEC   =  (state==HEX2DEC&&!go_send);  
assign                  HEX_data        =   (state==HEX2DEC&&hex_cnt==3'd0) ?   {6'b0,memristor_adc_data_i[14:9]}   : 
                                            (state==HEX2DEC&&hex_cnt==3'd1) ?   {3'b0,memristor_adc_data_i[8:0]}    :
                                            (state==HEX2DEC&&hex_cnt==3'd2) ?   {6'b0,piezo_adc_data_i[14:9]}       :
                                            (state==HEX2DEC&&hex_cnt==3'd3) ?   {3'b0,piezo_adc_data_i[8:0]}        :
                                            (state==HEX2DEC&&hex_cnt==3'd4) ?   {8'b0,ch_sign_i[3:0]}               :
                                            12'b0;

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        hex_cnt <=  0;
    else if(HEX2DEC_completed&&hex_cnt==3'd4)
        hex_cnt <=  0;
    else if(HEX2DEC_completed)
        hex_cnt <=  hex_cnt+1'b1;
end

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i) begin
        mem_adc_dec     <=  0;
        mem_adc_int     <=  0;
        piez_adc_int    <=  0;
        piez_adc_dec    <=  0;
        ch_int          <=  0;
    end
    else if(HEX2DEC_completed) begin
        case(hex_cnt)
            3'd0:   
                mem_adc_int     <=  DEC_data[11:0];
            3'd1:
                mem_adc_dec     <=  DEC_data[11:0];
            3'd2:
                piez_adc_int    <=  DEC_data[11:0];
            3'd3:
                piez_adc_dec    <=  DEC_data[11:0];
            3'd4:
                ch_int          <=  DEC_data[11:0];  
        endcase
    end
end

//****************************Byte_store**********************************//

assign                  wFIFO_wrreq =   state==SEND;

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        byte_cnt    <=  0;
    else if(state==SEND)
        byte_cnt    <=  byte_cnt+1'b1;
end

always @(*) begin
    case(byte_cnt)
        5'd0:
            wFIFO_idata     =   8'h63;//c
        5'd1:
            wFIFO_idata     =   8'h62;//b
        5'd2: begin
            if(mem_state_i==0)        //IDLE
                wFIFO_idata =   8'h49;//I
            else if(mem_state_i==2'd1)//REMEM
                wFIFO_idata =   8'h52;//R
            else if(mem_state_i==2'd2)//ADAPT
                wFIFO_idata =   8'h41;//A
            else                    //BREAK
                wFIFO_idata =   8'h42;//B
        end 
        5'd3:
            wFIFO_idata     =   8'h70;//p
        5'd4:
            wFIFO_idata     =   {4'b0011,ch_int[7:4]};//tens digit of the channel number
        5'd5:
            wFIFO_idata     =   {4'b0011,ch_int[3:0]};//ones digit of the channel number
        5'd6: begin
            if(piezo_adc_data_i[15]==1'b1)
                wFIFO_idata =   8'h2b;//positive sign
            else
                wFIFO_idata =   8'h2d;//negative sign
        end
        5'd7:
            wFIFO_idata     =   {4'b0011,piez_adc_int[11:8]};
        5'd8:
            wFIFO_idata     =   {4'b0011,piez_adc_int[7:4]};
        5'd9:
            wFIFO_idata     =   {4'b0011,piez_adc_int[3:0]};
        5'd10:
            wFIFO_idata     =   8'h2e;//decimal point
        5'd11:
            wFIFO_idata     =   {4'b0011,piez_adc_dec[11:8]};
        5'd12:
            wFIFO_idata     =   {4'b0011,piez_adc_dec[7:4]};
        5'd13:
            wFIFO_idata     =   {4'b0011,piez_adc_dec[3:0]};
        5'd14:
            wFIFO_idata     =   8'h0d;// /r
        5'd15:
            wFIFO_idata     =   8'h0a;// /n
        5'd16:
            wFIFO_idata     =   8'h63;//c
        5'd17:
            wFIFO_idata     =   8'h62;//b   
        5'd18: begin
            if(mem_state_i==0)        //IDLE
                wFIFO_idata =   8'h49;//I
            else if(mem_state_i==2'd1)//REMEM
                wFIFO_idata =   8'h52;//R
            else if(mem_state_i==2'd2)//ADAPT
                wFIFO_idata =   8'h41;//A
            else                    //BREAK
                wFIFO_idata =   8'h42;//B
        end   
        5'd19:
            wFIFO_idata     =   8'h72;//r
        5'd20:
            wFIFO_idata     =   {4'b0011,ch_int[7:4]};//positive sign
        5'd21:
            wFIFO_idata     =   {4'b0011,ch_int[3:0]};//negative sign
        5'd22: begin
            if(piezo_adc_data_i[15])
                wFIFO_idata =   8'h2b;//positive sign
            else
                wFIFO_idata =   8'h2d;//negative sign
        end
        5'd23:
            wFIFO_idata     =   {4'b0011,mem_adc_int[11:8]};
        5'd24:
            wFIFO_idata     =   {4'b0011,mem_adc_int[7:4]};
        5'd25:
            wFIFO_idata     =   {4'b0011,mem_adc_int[3:0]};
        5'd26:
            wFIFO_idata     =   8'h2e;//decimal point
        5'd27:
            wFIFO_idata     =   {4'b0011,mem_adc_dec[11:8]};
        5'd28:
            wFIFO_idata     =   {4'b0011,mem_adc_dec[7:4]};
        5'd29:
            wFIFO_idata     =   {4'b0011,mem_adc_dec[3:0]};
        5'd30:
            wFIFO_idata     =   8'h0d;// /r
        5'd31:
            wFIFO_idata     =   8'h0a;// /n
    endcase
end

//****************************channel switching**********************************//

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        ch_cnt  <=  0;
    else if(state==SEND&&go_idle)
        ch_cnt  <=  ch_cnt+1'b1;
    else if(state==UPLOAD)
        ch_cnt  <=  0;
end

//****************************USB upload control**********************************//
`ifdef USB
assign                  USB_send    =   (state==UPLOAD&&!go_idle);
assign                  USB_norece  =   1'b1;
`else
assign                  USB_send    =   go_upload;
assign                  USB_norece  =   1'b1;
`endif
//****************************handshake signal**********************************//

assign                  data_rdy_o  =   state==IDLE;

HEX2DEC HEX2DEC_u0(
    .clk_50m            (clk_i              ),
    .rst_n              (rst_n_i            ),
    .HEX_data           (HEX_data           ),
    .Begin_HEX2DEC      (Begin_HEX2DEC      ),
    .DEC_data           (DEC_data           ),
    .HEX2DEC_completed  (HEX2DEC_completed  )
);
`ifdef USB
CYUSB_control CYUSB_control_u0(
    .clk_50m                (clk_i          ),
    .rst_n                  (rst_n_i        ),
    
    .flagA                  (flagA_i        ),
    .cy_full                (cy_full_i      ),
    .cy_empty               (cy_empty_i     ),
    .slcs                   (slcs_o         ),
    .sloe                   (sloe_o         ),
    .slrd                   (slrd_o         ),
    .slrwr                  (slrwr_o        ),
    .pktend                 (pktend_o       ),
    .USB_idata              (USB_idata_i    ),
    .USB_odata              (USB_odata_o    ),
    .FIFOadr                (FIFOadr_o      ),

    .wFIFO_idata            (wFIFO_idata    ),
    .wFIFO_wrreq            (wFIFO_wrreq    ),
    .wFIFO_full             (wFIFO_full     ),

    .rRAM_odata             (rRAM_odata     ),
    .rRAM_rdaddr            (rRAM_rdaddr    ),

    .USB_send               (USB_send       ),
    .USB_norece             (USB_norece     ),
    .USB_busy               (USB_busy       ),
    .USB_rece_done          (USB_rece_done  ),
    .USB_send_done          (USB_send_done  ),
    .fd_sign                (fd_sign_o      )
);

`else

uart_upload uart_upload_u0(
    .clk_50m                (clk_i          ),
    .rst_n                  (rst_n_i        ),
    
    .wFIFO_idata            (wFIFO_idata    ),
    .wFIFO_wrreq            (wFIFO_wrreq    ),
    .wFIFO_full             (wFIFO_full     ),
    
    .uart_send              (USB_send       ),
    .uart_send_done         (USB_send_done  ),
    .uart_rdy               (uart_rdy       ),

    .TX                     (TX)
);
`endif
endmodule