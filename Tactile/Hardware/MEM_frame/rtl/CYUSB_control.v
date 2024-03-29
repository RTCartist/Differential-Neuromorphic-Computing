//************************20210618***************************//
//                    CYUSB读写控制模块
//************************20210621***************************//  
//从FPGA上传至主机功能（USB上传）测试完成，单包512B，内容为2个0~255循环
//从上位机发送数据到主机功能（USB下载）尚未测试
//************************20211203***************************//  
//进行了性能优化，速度有所减慢
//可保证1000个数据包不出错
//`include "param.v"
module CYUSB_control
#(

//************************系统参数***************************//
`ifdef test_ch
parameter      WRITE_NUM   =   10'd32,//表示每次写入最多写多少个字节的数据，每次写最多写512字节
`else           
parameter      WRITE_NUM   =   10'd512,
`endif
parameter      READ_NUM    =   10'd3//表示每次读取最多读取多少个字节的数据，最多为512字节

)
(
//系统输入
input               clk_50m,
input               rst_n,
//CYUSB连接线
input               flagA,//PF
input               cy_full,//FLAGB,低有效
input               cy_empty,//FLAGC,低有效
output              slcs,//CYUSB片选，低有效
output  reg         sloe,//数据有效标志位，在进行数据读写时，该信号要保持为高电平
output  reg         slrd,//异步读信号
output  reg         slrwr,//异步写信号
output  reg         pktend,//数据打包信号，当发送完一串数据后，将该位拉高，已发送的数据会被包装成一个包发送至上位机
input       [7:0]   USB_idata,//连接到CYUSB的数据线
output  reg [1:0]   FIFOadr,//端口选取地址线
//上传数据FIFO
input       [7:0]   wFIFO_idata,
input               wFIFO_wrreq,
output              wFIFO_full,
//读取数据暂存RAM
input       [7:0]   rRAM_odata,
input       [8:0]   rRAM_rdaddr,                        
//output  reg [8:0]   rRAM_wraddr,
//output  reg [7:0]   rRAM_idata,
//output  reg         rRAM_wren,
//上层模块交互信号
input               USB_send,//上层模块拉高该信号，开始进行一次USB传输
input               USB_norece,//当该信号拉高时，USB模块不会接收下一个数据包，但不会打断当前数据包的接收
output              USB_busy,//该信号为低时，说明模块可以开启一次数据传输
output              USB_rece_done,//该信号为高时，说明模块已经接收了一个USB数据包
output              USB_send_done,//该信号为高时，说明模块已经发送了一个USB数据包
output              fd_sign,//用于上层模块对inout接口流向的控制
output  reg [7:0]   USB_odata
);
//************************存储器端口***************************//

reg                         wFIFO_rdreq;
wire            [7:0]       wFIFO_odata;
wire                        wFIFO_empty;

reg             [8:0]       rRAM_wraddr;
reg             [7:0]       rRAM_idata;
reg                         rRAM_wren;

//************************系统状态机***************************//

reg             [2:0]       state;
reg             [2:0]       next_state;

localparam      IDLE            =   3'b001;
localparam      READ            =   3'b010;
localparam      WRITE           =   3'b100;   

//************************传输状态机***************************//

reg             [3:0]       t_state;
reg             [3:0]       t_next_state;

localparam      T_ADDR_SLOE     =   4'b0001;
//上面的状态对应读写时两个不同的状态：ADDR和SLOE
//在写数据时，需要提前一个时钟将ADDR准备好；读数据时，因为IDLE状态地址已经指向端口2，所以无需重新准备ADDR
//在读数据时，需要提前一个时钟准备SLOE，写数据则无需此步骤
localparam      T_TRANS         =   4'b0010;//数据传输状态
localparam      T_PKTEND_DELAY  =   4'b0100;
//上面的状态对应读写时两个不同的状态：PKTEND和DELAY
//在写时，需要使用PKTEND命令进行封包；在读时，需要一定的延时来保证系统状态机进入IDLE状态时cy_empty信号已被拉高
localparam      T_IDLE          =   4'b1000;  

//************************计数器***************************//

reg             [3:0]       time_cnt;
reg             [9:0]       byte_cnt;

//************************CYUSB数据线指向控制***************************//

assign          fd_sign         =   (state==WRITE)?1'b1:1'b0;

//************************系统状态机跳转***************************//

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        state   <=  IDLE;
    else
        state   <=  next_state;
end

always @(*) begin
    if(!rst_n)
        next_state  =   IDLE;
    else
        case(state)
            IDLE: begin
                if(cy_empty==1'b1&&USB_norece==0)
                    next_state  =   READ;
                else if(USB_send==1'b1)
                    next_state  =   WRITE;
                else
                    next_state  =   IDLE;
            end
            READ: begin
                if(t_state==T_PKTEND_DELAY&&time_cnt==4'd4)//等待一个Txflg的时间，根据数据手册，这个时间最多70ns
                    next_state  =   IDLE;
                else
                    next_state  =   READ;
            end
            WRITE: begin
                if(t_state==T_PKTEND_DELAY&&time_cnt==4'd10)
                    next_state  =   IDLE;
                else
                    next_state  =   WRITE;
            end
            default:
                    next_state  =   IDLE;
        endcase
end

//************************读写状态机跳转***************************//

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        t_state <=  T_IDLE;
    else
        t_state <=  t_next_state;
end

always @(*) begin
    if(!rst_n)
        t_next_state    =   T_IDLE;
    else
        case(state)
            IDLE:
                t_next_state    =   T_IDLE;
            WRITE: begin
                case (t_state)
                    T_IDLE:
                        t_next_state    =   T_ADDR_SLOE;
                    T_ADDR_SLOE:begin
                        if(cy_full==1'b1)
                            t_next_state    =   T_TRANS;
                        else
                            t_next_state    =   T_ADDR_SLOE;
                    end
                    T_TRANS:begin
                        if(byte_cnt==WRITE_NUM-1'b1&&time_cnt==4'd10)
                            t_next_state    =   T_PKTEND_DELAY;
                        else    
                            t_next_state    =   T_TRANS;
                    end 
                    T_PKTEND_DELAY: 
                        t_next_state    =   T_PKTEND_DELAY;
                    default:
                        t_next_state    =   T_IDLE;
                endcase
            end
            READ: begin
                case(t_state)
                    T_IDLE:
                        t_next_state    =   T_ADDR_SLOE;
                    T_ADDR_SLOE:
                        t_next_state    =   T_TRANS;
                    T_TRANS: begin
                        if(byte_cnt==READ_NUM-1'b1&&time_cnt==4'd5)
                            t_next_state    =   T_PKTEND_DELAY;
                        else
                            t_next_state    =   T_TRANS;
                    end
                    T_PKTEND_DELAY: 
                        t_next_state    =   T_PKTEND_DELAY;
                    default:
                        t_next_state    =   T_IDLE;
                endcase
            end
            default:
                t_next_state    =   T_IDLE;
        endcase
end

//************************上层交互***************************//

assign      USB_rece_done   =   (state==READ)&&(t_state==T_PKTEND_DELAY)?1'b1:0;
assign      USB_send_done   =   (state==WRITE)&&(t_state==T_PKTEND_DELAY)?1'b1:0;
assign      USB_busy        =   (state==READ)||(state==WRITE)?1'b1:0;

//************************计数器***************************//

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        time_cnt    <=  0;
    else
        case(state)
            IDLE:
                time_cnt    <=  0;
            WRITE: begin
                case(t_state)
                    T_IDLE:
                        time_cnt    <=  0;
                    T_ADDR_SLOE: begin
                        // if(time_cnt==3'd1)
                            time_cnt    <=  0;
                        // else
                        //     time_cnt    <=  time_cnt+1'b1;
                    end
                    T_TRANS: begin
                        if(time_cnt==4'd10)
                            time_cnt    <=  0;
                        else
                            time_cnt    <=  time_cnt+1'b1;
                    end
                    T_PKTEND_DELAY:
                        time_cnt    <=  time_cnt+1'b1;
                endcase
            end
            READ: begin
                case(t_state)
                    T_IDLE:
                        time_cnt    <=  0;
                    T_ADDR_SLOE:
                        time_cnt    <=  0;
                    T_TRANS: begin
                        if(time_cnt==4'd5)
                            time_cnt    <=  0;
                        else
                            time_cnt    <=  time_cnt+1'b1;
                    end
                    T_PKTEND_DELAY:
                        time_cnt    <=  time_cnt+1'b1;
                endcase
            end
        endcase
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        byte_cnt    <=  0;
    else 
        case(state)
            WRITE: begin
                if(t_state==T_TRANS) begin                  
                    if(time_cnt==4'd10)
                        byte_cnt    <=  byte_cnt+1'b1;
                    else
                        byte_cnt    <=  byte_cnt;
                end
                else
                    byte_cnt    <=  0;
            end
            READ: begin
                if(t_state==T_TRANS) begin
                    if(time_cnt==4'd5)
                        byte_cnt    <=  byte_cnt+1'b1;
                    else
                        byte_cnt    <=  byte_cnt;
                end
                else
                    byte_cnt    <=  0;
            end
            default:
                byte_cnt    <=  0;
        endcase
end

//************************CYUSB连接线***************************//

assign      slcs        =   0;

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        sloe    <=  1'b1;
    else if(state==READ)
        case(t_state)
            T_IDLE:
                sloe    <=  1'b1;
            T_ADDR_SLOE:
                sloe    <=  0;
            default:
                sloe    <=  sloe;
        endcase
    else
        sloe    <=  1'b1;
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
       slrd     <=  1'b1;
    else if(state==READ)
        case(t_state)
            T_TRANS: begin
                if(time_cnt==0)
                    slrd    <=  0;
                else if(time_cnt==4'd3)
                    slrd    <=  1'b1;
            end
            default:
                slrd    <=  1'b1;
        endcase 
    else
        slrd    <=  1'b1;
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        slrwr   <=  1'b1;
    else if(state==WRITE)
        case(t_state)
            T_TRANS: begin
                if(time_cnt==4'd6)
                    slrwr   <=  0;
                else if(time_cnt==4'd9)
                    slrwr   <=  1'b1;
            end
            default:
                slrwr   <=  1'b1;
        endcase
    else
        slrwr   <=  1'b1;
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        pktend  <=  1'b1;
    else if(state==WRITE)
        case(t_state)
            T_PKTEND_DELAY: begin
                pktend  <=  0;
            end
            default:
                pktend   <=  1'b1;
        endcase
    else
        pktend  <=  1'b1;
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        USB_odata  <=  8'h00;
    else if(state==WRITE)
        case(t_state)
            T_TRANS: begin
                if(time_cnt==4'd2)
                    USB_odata  <=  wFIFO_odata;
                else
                    USB_odata  <=  USB_odata;
            end
            default:
                USB_odata  <=  8'h00;
        endcase
    else
        USB_odata  <=  0;
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        FIFOadr <=  2'b10;
    // else if(state==READ)
    //     FIFOadr <=  2'b00;
    else
        FIFOadr <=  2'b10;
end

//************************外界存储器交互***************************//

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        wFIFO_rdreq <=  0;
    else if(state==WRITE)
        case(t_state)
            T_TRANS: begin
                if(time_cnt==4'd0)
                    wFIFO_rdreq <=  1'b1;
                else
                    wFIFO_rdreq <=  0;
            end
        endcase
    else
        wFIFO_rdreq <=  0;
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        rRAM_wraddr   <=  0;
    else if(state==READ)
        case(t_state)
            T_TRANS: begin
                if(time_cnt==4'd5)
                    rRAM_wraddr   <=  rRAM_wraddr+1'b1;
                else
                    rRAM_wraddr   <=  rRAM_wraddr;
            end
            default:
                rRAM_wraddr   <=  rRAM_wraddr;
        endcase
    else
        rRAM_wraddr   <=  0;
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        rRAM_idata   <=  0;
    else if(state==READ)
        case(t_state)
            T_TRANS: begin
                if(time_cnt==4'd3)
                    rRAM_idata   <=  USB_idata;
                else
                    rRAM_idata   <=  0;
            end
            default:
                rRAM_idata   <=  0;
        endcase
    else
        rRAM_idata   <=  0;
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        rRAM_wren   <=  0;
    else if(state==READ)
        case(t_state)
            T_TRANS: begin
                if(time_cnt==4'd3)
                    rRAM_wren   <=  1'b1;
                else
                    rRAM_wren   <=  0;
            end
            default:
                rRAM_wren   <=  0;
        endcase
    else
        rRAM_wren   <=  0;
end

write_FIFO write_FIFO1(//写入数据和标志同步，也就是说，数据和写入标志一起拉高，数据可以正常写入
    .clock      (clk_50m),
    .data       (wFIFO_idata),//o
    .rdreq      (wFIFO_rdreq),//i
    .wrreq      (wFIFO_wrreq),//o
    .empty      (wFIFO_empty),//i
    .full       (wFIFO_full),//i
    .q          (wFIFO_odata)//i
);

USB_RAM   USB_RAM1(//输出数据有两个时钟的延迟，改变ADDR后，隔一个时钟，输出才发生变换
    .rdaddress  (rRAM_rdaddr),//o
    .wraddress  (rRAM_wraddr),//i
    .clock      (clk_50m),
    .data       (rRAM_idata),//i
    .wren       (rRAM_wren),//i
    .q          (rRAM_odata)//o
);

endmodule


// always @(posedge clk or negedge rst_n) begin
//     if(and_valid) begin
//         for (i = 0;i < WIDTH ; i++) begin
//             //A[i][0] <= A[i][0] & to_be_and;
//             result <=  A[i][0]  & result;
//         end
//     end
// end

// integer i;
// for (i = 0;i < WIDTH ; i++) begin
//     assign  result  =   A[i][0]  & result;
// end