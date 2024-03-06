`include "defpara.v"
module ADS8689#(
    parameter           INITREG_CNT =   1   //log how many registers need to be configured  
)
(
    //system ports
    input               clk_50m     ,
    input               rst_n       ,
    input               begin_conv  ,
    output              conv_done   ,
    output              init_done   ,
    output  reg [15:0]  conv_data   ,
    //ADC pin
    input               RVS         ,
    output  reg         CONVST      ,
    output              ADC_RST     ,
    //SPI
    input               sdi         ,
    output              sdo         ,
    output              sclk        
);

localparam              INIT        =   3'b001 ;             
localparam              CONV        =   3'b010 ;
localparam              ACQ         =   3'b100 ;
localparam              IDLE        =   3'b011 ;

localparam              REG_WIDTH   =   $clog2(INITREG_CNT) ;
//{16'b1101010_000010100,16'h00_03};//setting detection range，03 is ±1.25*Vref，04 is ±0.625*Vref{16'b1100_0000_0000_0000,16'b0010_10000_0101011}
localparam              RANGE_SEL   =   {16'b1101010_000010100,16'h00_04};

//time to wait before initialization
`ifdef TEST
localparam              INIT_CNT    =   32'd50;
`else 
localparam              INIT_CNT    =   32'd2_999_999;
`endif


//system reg
reg         [2:0]           state               ;
reg         [2:0]           next_state          ;
reg         [REG_WIDTH:0]   reg_cnt             ;//configure the register counter to keep track of how many registers have been configured
reg         [1:0]           spi_cnt             ;//spi counter, used to count how many bytes have been sent to the SPI
reg         [31:0]          cnt                 ;
reg                         r_conv_done         ;
//SPI ports
wire                        spi_done            ;
wire        [7:0]           ADC_data            ;
reg         [7:0]           odata               ;
reg                         begin_SPI           ;

assign      ADC_RST     =   rst_n               ;
assign      conv_done   =   r_conv_done&&init_done;

reg                         init_sign           ;  
reg         [1:0]           init_delay          ;//delay the INIT signal by 2 cycles (ADC register preparation).

assign      init_done   =   init_delay[1]       ;

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        cnt <=  0;
    else begin
        case(state)
        INIT:   cnt <=  cnt+1'b1;
        ACQ:    cnt <=  0;
        CONV:   cnt <=  cnt+1'b1; 
        endcase
    end

end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        init_delay  <=  0;
    else begin
        init_delay[0]   <=  init_sign;
        init_delay[1]   <=  init_delay[0];
    end
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        state   <=  INIT        ;
    else
        state   <=  next_state  ;
end

always @(*) begin
    if(!rst_n)
       next_state   =   INIT            ;
    else 
    case(state)
        INIT: begin
            if(cnt==INIT_CNT)//wait time after reset, typical value is 20ms, set to 60ms here.
                next_state  =   ACQ     ;
            else
                next_state  =   INIT    ;
        end
        CONV:  begin
            if(RVS==1'b1)
                next_state  =   ACQ     ;
            else
                next_state  =   CONV    ;
        end
        ACQ: begin
            if(r_conv_done==1'b1)
                next_state  =   IDLE    ;
            else
                next_state  =   ACQ     ;
        end
        IDLE:begin
            if(begin_conv==1'b1||init_sign!=1'b1)
                next_state  =   CONV    ;
            else
                next_state  =   IDLE    ;
        end
        default: 
                next_state  =   CONV     ;
    endcase
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        begin_SPI   <=  0           ;
    else
    case(state)
        INIT,CONV,IDLE:
                begin_SPI   <=  0   ;
        ACQ: begin
            // if(spi_done==1'b1&&spi_cnt==2'd3)
            //     begin_SPI   <=  0   ;
            // else
            //     begin_SPI   <=  1'b1;
            if(spi_done==1'b1&&spi_cnt==2'd3)
                begin_SPI   <=  0   ;
            else
                begin_SPI   <=  1'b1;
        end
    endcase
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        CONVST      <=  0   ;
    else
    case(state)
        INIT:
            CONVST  <=  0   ;
        CONV:
            CONVST  <=  1'b1;
        ACQ:
            CONVST  <=  0   ;     
        IDLE:
            CONVST  <=  0   ; 
    endcase 
end

always @(*) begin
    if(!rst_n)
        odata       =  0   ;
    else
    case(state)
        INIT,CONV,IDLE:
            odata   =  0   ;
        ACQ:begin
            if(init_sign!=1'b1)//if it's in the initialization phase
                case(reg_cnt)//if other registers need to be written, they should be supplemented here
                'd0: //send the first configuration register
                    case(spi_cnt)
                    2'd0: 
                        odata   =   RANGE_SEL[31:24]    ;
                    2'd1:
                        odata   =   RANGE_SEL[23:16]    ;
                    2'd2:
                        odata   =   RANGE_SEL[15:8]     ;
                    2'd3:
                        odata   =   RANGE_SEL[7:0]      ;
                    endcase
                default:odata   =   0;    
                endcase
            else
                odata   =  0;//in the non-initialization phase, send the NOP instruction
        end
        default:    odata   =   0;
    endcase
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        reg_cnt <=  0;
    else
    case(state)
        INIT,CONV,IDLE:
            reg_cnt <=  reg_cnt;
        ACQ:begin
            if(r_conv_done==1'b1&&reg_cnt!=INITREG_CNT)
                reg_cnt <=  reg_cnt+1'b1;
            else
                reg_cnt <=  reg_cnt;
        end
    endcase
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        spi_cnt <=  0;
    else 
    case(state)
        INIT,CONV,IDLE:
            spi_cnt <=  0;
        ACQ:begin
            if(spi_done==1'b1)
                spi_cnt <=  spi_cnt+1'b1;
            else
                spi_cnt <=  spi_cnt;
        end
    endcase  
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        r_conv_done   <=  0;
    else
    case(state)
        INIT,CONV,IDLE:
            r_conv_done   <=  0;
        ACQ: begin
            if(spi_cnt==2'd3&&spi_done==1'b1)
                r_conv_done   <=  1'b1;
            else
                r_conv_done   <=  0   ;
        end
    endcase
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        conv_data   <=  0;
    else
    case(state)
        INIT,CONV,IDLE:
            conv_data   <=  0;
        ACQ: begin
            if(init_sign==1'b1)
                case(spi_cnt)
                2'd0:
                    conv_data[15:8]    <=  ADC_data       ;      
                2'd1:
                    conv_data[7:0]     <=  ADC_data       ;
                endcase
        end
    endcase
end

always @(posedge clk_50m or negedge rst_n) begin
    if(!rst_n)
        init_sign   <=  0;
    else
    case(state)
        INIT,CONV,IDLE:
            init_sign   <=  init_sign;
        ACQ: begin
            if(reg_cnt==INITREG_CNT-1'b1&&spi_cnt==2'd3&&spi_done==1'b1)
                init_sign   <=  init_sign+1'b1;
            else
                init_sign   <=  init_sign;
        end
    endcase
end

SPI SPI_u0(
    .clk_50m        (clk_50m)   ,
    .rst_n          (rst_n)     ,
    .odata          (odata)     ,
    .Begin_SPI      (begin_SPI) ,
    .MISO           (sdi)       ,
    .MOSI           (sdo)       ,
    .Div            (6'd16)      ,//divide by 8
    .CPOL           (1'b0)      ,
    .CPHA           (1'b0)      ,
    .CS_control     (   )       ,
    .SPI_done       (spi_done)  ,
    .SCLK           (sclk)      ,
    .CS             (   )       ,
    .idata          (ADC_data)  
);

endmodule
