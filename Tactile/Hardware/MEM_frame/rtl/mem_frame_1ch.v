// The main file
`include "defpara.v"
module  mem_frame_1ch
(
    //sys input
    input                   clk_i,
    input                   rst_n_i,
    //ADC pin
    input                   RVS_i,
    output                  CONVST_o,
    output                  ADC_RST_o,
    //ADC SPI
    input                   adc_sdi_i,
    output                  adc_sdo_o,
    output                  adc_sclk_o,
    //CYUSB pin
    input                   flagA_i,
    input                   cy_full_i,
    input                   cy_empty_i,
    output                  slcs_o,
    output                  sloe_o,
    output                  slrd_o,
    output                  slrwr_o,
    output                  pktend_o,
    inout           [7:0]   USB_data,
    output          [1:0]   FIFOadr_o,
    //UART
    output                  TX,
    //piezo switch
    output          [1:0]   piezo_row_o,
    output          [1:0]   piezo_col_o,
    //memristor sel
    output                  sel_d0_o,
    output                  sel_d1_o,
    output                  sel_a_o,
    output                  sel_b_o,
    output                  sel_c_o, 
    //memristor out sel
    output          [2:0]   mem_out_sel_o,
    output                  mem_out_en0_o, 
    output                  mem_out_en1_o,  
    //ctrl switch
    output  reg     [3:0]   ctrl_switch_o,//sel3,sel2,sel1,sel0
    //DAC  pin
    output  reg     [9:0]   dac_data_o,
    output                  dac_clk_o,
    //key and led
    output          [3:0]   led_o,
    output          [3:0]   key_o,
    //control IO
    output          [1:0]   o_control     
);
//****************************system parameters**********************************//
//channel parameters
localparam               test_channel    =   4'b1001;
localparam			     test_mem_channel    = 4'b0101;

//time (the unit is 20ns)
localparam              CH_PERIOD       =   32'd50_000;//the control duration for a single channel, with an initial value of 1ms
localparam              BR_AD_PERIOD_P  =   32'd6_650; //encoding scheme duty when perceiving noxious stimuli (Rp<60k Rm>100k)
localparam              BR_AD_PERIOD_PS =   32'd10_000;//encoding scheme duty when perceiving noxious stimuli (Rp<60k Rm<100k)
localparam              BR_AD_PERIOD_N  =   32'd23_350;//encoding scheme duty when perceiving mild stimuli (100k<Rp<300k Rm>100k)
localparam              CH_WAIT_TIME    =   8'd255;    //waiting time after channel switching for the analog switch to toggle
localparam              CTRL_SW_WAIT    =   8'd150;    //waiting time for the analog switch to toggle after initiating the control switch

//pulses duty parameters when perceiving normal stimulus or no stimulus
localparam              PULSE_P1  =   32'd13_350; //wide positive pulses duty 
localparam              PULSE_P2  =   32'd3_350; //short positive pulses duty

localparam              PULSE_N1  =   32'd10_000;//wide negative pulses duty
localparam              PULSE_N2  =   32'd3_350;//short negative pulses duty

//DAC output parameters (the voltage amplitudes of the encoding pulses)

localparam              DETECT_VOL      =   10'b10_0011_0100;//the parameter for voltage output used in resistance detection 10_0011_0100 0.215V
localparam              PROG_POS_VOL    =   10'b10_0100_1001;//nociception output voltage (Rp<60k Rm>100k) (10_0100_1001, 0.3019V)
localparam              PROG_SEN_POS_VOL=   10'b10_0110_1101;//sensitization output voltage (Rp<60k Rm<100k)  (10_0110_1101, 0.4508V)
localparam              PROG_NEG_VOL    =   10'b01_1100_0100;//adaptation output voltage (100k<Rp<300k Rm>100k) (01_1100_0100, -0.2482)
localparam              REMEM_POS_VOL   =   10'b10_0101_0101;//REMEM or Normal, wide positive pulse (10_0101_0101, 0.35V)
localparam              REMEM_SHORT_POS_VOL =   10'b10_0110_0110;//REMEM or Normal, short positive pulse (10_0110_0110, 0.42V)
localparam              REMEM_NEG_VOL   =   10'b01_1001_1111;//REMEM or Normal, wide negative pulse (01_1001_1111, -0.4V)
localparam              REMEM_SHORT_NEG_VOL =   10'b01_1000_0111;//REMEM or Normal, wide negative pulse (01_1000_0111, -0.5V)

//state determination parameter:(in our setup, the memristor is in series with a protective resistor of 47k and a feedback resistor of 47k.)
localparam              MEM_INIT_UP     =   16'd2501;//the maximum voltage across the memristor in its initial state with the corresponding resistance 160k
localparam              MEM_INIT_DOWN   =   16'd2280;//the minimum voltage across the memristor in its initial state with the corresponding resistance 180k

localparam              MEM_INIT_UP_almost      =   16'd3521; //100k
localparam              MEM_INIT_DOWN_almoset   =   16'd1743; //250k

localparam              PIEZO_ADAPT     =   16'd1492;//the piezoresistive film senses mild pressure, it needs to enter a sensory adaptation state, indicated by the resistance 300k
localparam              PIEZO_OVER_PRE  =   16'd4838;//the piezoresistive film senses noxious pressure, it needs to enter a nociceptor state, indicated by the resistance 60k

localparam              PIEZO_NOR_UP    =   16'd4838;//60k
localparam              PIEZO_NOR_DOWN  =   16'd3521;//100k
//when piezoresistive film is within this resistance range, the system enters into normal state, without altering the resistance value of the memristor

localparam              MEM_NO_ADAPT    =   16'd3521;//100k
//if the resistance value of the memristor falls below this threshold, it is considered incapable of further sensory adaptation

localparam              MEM_SENTI       =   16'd3521;//100k
//if the resistance value of the memristor falls below this threshold, the system enters to the sensitization state
//****************************counter**********************************//

reg         [31:0]      ch_cnt;//channel switching counter
reg         [8:0]       sw_cnt;//switch waiting counter
reg			[31:0]      global_cnt/* synthesis noprune*/;

//****************************channel marker**********************************//

reg         [3:0]       ch_sign;//which channel is currently being controlled  

//****************************control switch toggling**********************************//

reg         [3:0]       out_switch;
reg         [3:0]       piezo_switch;
reg         [3:0]       mem_switch;

//****************************control phase signal marker*******************************//
// BREAK: noxious stimuli ADAPT: mild stimuli REMEM: normal or no stimuli
wire                    control_rdy      =       (state==BREAK)||(state==ADAPT)||(state==REMEM)||(state==IDLE); 
//****************************state**********************************//

localparam               INIT            =       10'b0_000_000_001;
localparam               WAIT_CH         =       10'b0_000_000_010;
localparam               DETECT_P        =       10'b0_000_000_100;
localparam               WAIT_SW_1       =       10'b0_000_001_000;
localparam               DETECT_R        =       10'b0_000_010_000;
localparam               WAIT_SW_2       =       10'b0_000_100_000;
localparam               ADAPT           =       10'b0_001_000_000;
localparam               BREAK           =       10'b0_010_000_000;               
localparam               REMEM           =       10'b0_100_000_000;
localparam               IDLE            =       10'b1_000_000_000;

reg         [9:0]       state;

wire                    go_wait_ch;
wire                    go_detect_p;
wire                    go_wait_sw_1;
wire                    go_detect_r;
wire                    go_wait_sw_2;
wire                    go_adapt;
wire                    go_break;
wire                    go_remem;
wire                    go_idle;

//****************************adc data calculation**********************************//
reg                     begin_adc_conv;
wire                    adc_done;
wire                    adc_init_done;
wire        [15:0]      adc_data;

reg         [17:0]      adc_data_sum;      
wire        [17:0]      adc_data_abs;

reg         [15:0]      memristor_adc_data; //logging the ADC information obtained from detecting the memristor
reg         [15:0]      piezo_adc_data;     //logging the ADC information obtained from detecting the piezoresistive film

reg         [2:0]       adc_rece_cnt;//calculating the number of times ADC data has been received

//assign                  adc_data_abs    =   (adc_data_sum[17]==1'b1)?adc_data_sum[17:2]-16'h8000:16'h8000-adc_data_sum[17:2];
assign                  adc_data_abs    =   (adc_data_sum[17]==1'b1)?   adc_data_sum[17:0]-18'h20000:
                                                                        18'h20000-adc_data_sum[17:0];//0.64V
//****************************internal flag signal**********************************//

reg                     remem_direct;//indicate the direction in which the resistance of the memristor should be adjusted while in the 'remem' state. 0: The resistance of the memristor is too high, requiring the application of a positive voltage 

//****************************data upload signal**********************************//

wire                    fd_sign;
wire        [7:0]       USB_idata;
wire        [7:0]       USB_odata;

wire                    upload_data_rdy;
reg                     upload_data_vld;

wire        [1:0]       mem_state;

//****************************tri-state gate control**********************************//

assign                  USB_data        =   fd_sign?USB_odata:8'bz;
assign                  USB_idata       =   USB_data;

//****************************state machine transition**********************************//

assign                  go_wait_ch      =   ((state==ADAPT||state==BREAK||state==REMEM||state==IDLE)&&ch_cnt==CH_PERIOD-1'b1)||
                                            (state==INIT&&adc_init_done);
assign                  go_detect_p     =   (state==WAIT_CH)&&sw_cnt==CH_WAIT_TIME-1'b1;
assign                  go_wait_sw_1    =   (state==DETECT_P)&&adc_rece_cnt==3'b111&&adc_done;   
assign                  go_detect_r     =   (state==WAIT_SW_1)&&sw_cnt==CTRL_SW_WAIT-1'b1;
assign                  go_wait_sw_2    =   (state==DETECT_R)&&adc_rece_cnt==3'b111&&adc_done;
// Note: The following four transition signals are not raised at the last moment of WAIT_SW_2; they are determined as soon as the WAIT_SW_2 state is entered.
// Multiple states might be high simultaneously, so it's important for the control signals to consider priority issues.
// go_adapt has an additional mechanism designed to prevent immediate entry into the sensory adaptation state if the memristor was previously in a damage sensing state.
assign                  go_adapt        =   (state==WAIT_SW_2)&&piezo_adc_data>PIEZO_ADAPT&&piezo_adc_data<PIEZO_NOR_DOWN&&memristor_adc_data<MEM_NO_ADAPT;
assign                  go_break        =   (state==WAIT_SW_2)&&piezo_adc_data>PIEZO_OVER_PRE;
assign                  go_remem        =   (state==WAIT_SW_2)&&(memristor_adc_data>MEM_INIT_UP||memristor_adc_data<MEM_INIT_DOWN);
assign                  go_idle         =   (state==WAIT_SW_2);

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        state       <=  INIT;
    else 
    case(state)
        INIT: begin
            if(adc_init_done)
                state   <=  WAIT_CH;
        end
        WAIT_CH: begin
            if(go_detect_p)
                state   <=  DETECT_P;
        end
        DETECT_P: begin
            if(go_wait_sw_1)
                state   <=  WAIT_SW_1;
        end
        WAIT_SW_1: begin
            if(go_detect_r)
                state   <=  DETECT_R;
        end
        DETECT_R: begin
            if(go_wait_sw_2)
                state   <=  WAIT_SW_2;
        end
        WAIT_SW_2:begin
            if(go_break&&sw_cnt==CTRL_SW_WAIT-1'b1)
                state   <=  BREAK;
            else if(go_adapt&&sw_cnt==CTRL_SW_WAIT-1'b1)
                state   <=  ADAPT;
            else if(go_remem&&sw_cnt==CTRL_SW_WAIT-1'b1)
                state   <=  REMEM;
            else if(go_idle&&sw_cnt==CTRL_SW_WAIT-1'b1)
                state   <=  IDLE;
        end
        default: begin
            if(go_wait_ch)
                state   <=  WAIT_CH;
        end
    endcase
end
//****************************counter**********************************//

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        ch_cnt  <=  0;
    else if(ch_cnt==CH_PERIOD-1'b1)
        ch_cnt  <=  0;
    else if(state!=INIT)
        ch_cnt  <=  ch_cnt+1'b1;
end

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        sw_cnt  <=  0;
    else if(state==WAIT_CH) begin
        if(sw_cnt==CH_WAIT_TIME-1'b1)
            sw_cnt  <=  0;
        else
            sw_cnt  <=  sw_cnt+1'b1;
    end
    else if(state==WAIT_SW_1||state==WAIT_SW_2) begin
        if(sw_cnt==CTRL_SW_WAIT-1'b1)
            sw_cnt  <=  0;
        else
            sw_cnt  <=  sw_cnt+1'b1;
    end
end

always @(posedge clk_i or negedge rst_n_i) begin
	if(!rst_n_i)
        global_cnt <= 0;
    else
        global_cnt <= global_cnt + 1'b1;	  
end

//****************************channel switching**********************************//
`ifdef test_ch
always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        ch_sign     <=  test_channel;
    else if(ch_cnt==CH_PERIOD-1'b1)
        ch_sign     <=  test_channel;
end
`else
always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        ch_sign     <=  0;
    else if(ch_cnt==CH_PERIOD-1'b1)
        ch_sign     <=  ch_sign+1'b1;
end
`endif

assign                  sel_d0_o        =   ~sel_d1_o;//the inputs to the memristor from the two 8:1 analog switches are mutually exclusive
assign                  mem_out_en0_o   =   ~ mem_out_en1_o;//the inputs to the two 8:1 analog switches from the memristor output are mutually exclusive

assign                  piezo_row_o     =   piezo_switch[3:2];
assign                  piezo_col_o     =   piezo_switch[1:0];

assign                  mem_out_sel_o   =   out_switch[2:0];
assign                  mem_out_en1_o   =   out_switch[3];

assign                  sel_a_o         =   mem_switch[0];
assign                  sel_b_o         =   mem_switch[1];
assign                  sel_c_o         =   mem_switch[2];

assign                  sel_d1_o        =   mem_switch[3];

`ifdef test_ch
always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i) begin
        piezo_switch    <=  test_channel;
        out_switch      <=  test_mem_channel;
        mem_switch      <=  test_mem_channel;
    end
    else if(ch_cnt==CH_PERIOD-1'b1) begin
        piezo_switch    <=  test_channel;
        out_switch      <=  test_mem_channel;
        mem_switch      <=  test_mem_channel;
    end
end
`else
always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i) begin
        piezo_switch    <=  0;
        out_switch      <=  0;
        mem_switch      <=  0;
    end
    else if(ch_cnt==CH_PERIOD-1'b1) begin
        piezo_switch    <=  piezo_switch+1'b1;
        out_switch      <=  out_switch+1'b1;
        mem_switch      <=  mem_switch+1'b1;
    end
end
`endif

//****************************toggle the control switch**********************************//

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        ctrl_switch_o   <=  4'b1100;
    else 
        case(state)
              INIT,WAIT_CH,DETECT_P:begin
                    ctrl_switch_o   <=  4'b1100;//individually detect the piezoresistive film
              end
              WAIT_SW_1,DETECT_R:begin
                    ctrl_switch_o   <=  4'b0010;//individually detect the memristor
              end
              WAIT_SW_2:begin
                    if(go_adapt||go_break||go_remem)
                        ctrl_switch_o   <=  4'b0010;//modulate the memristor
                    else
                        ctrl_switch_o   <=  4'b0111;//piezoresistive sensor and memristor connected in series
              end
        endcase
end

//****************************DAC output**********************************//

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        remem_direct    <=  0;
    else if(state==WAIT_SW_2) begin
        if(memristor_adc_data>MEM_INIT_UP)
            remem_direct    <=  1'b1;
        else if(memristor_adc_data<MEM_INIT_DOWN)
            remem_direct    <=  0;
    end
end

assign                  dac_clk_o   =   clk_i;
`ifdef TEST_BOARD
always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        dac_data_o  <=  PROG_NEG_VOL;
end
`else
always @(negedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        dac_data_o  <=  10'b10_0000_0000;
    else 
        case(state)
            INIT:
                dac_data_o  <=  10'b10_0000_0000;
            WAIT_CH,DETECT_P,WAIT_SW_1,DETECT_R,WAIT_SW_2:
                dac_data_o  <=  DETECT_VOL;
            ADAPT:begin
                if(ch_cnt>=BR_AD_PERIOD_N)
                    dac_data_o  <=  DETECT_VOL;
                else
                    dac_data_o  <=  PROG_NEG_VOL;
            end
            BREAK:begin
                if(memristor_adc_data>MEM_SENTI) begin
                    if(ch_cnt>=BR_AD_PERIOD_PS)
                        dac_data_o  <=  DETECT_VOL;
                    else
                        dac_data_o  <=  PROG_SEN_POS_VOL; 
                end
                else begin 
                    if(ch_cnt>=BR_AD_PERIOD_P)
                        dac_data_o  <=  DETECT_VOL;
                    else
                        dac_data_o  <=  PROG_POS_VOL; 
                end
            end
            REMEM:begin
                if(remem_direct==1'b1) begin//low resistance
                    if(memristor_adc_data>MEM_INIT_UP_almost) begin//wide pulses
                        if(ch_cnt>=PULSE_N1)
                            dac_data_o  <=  DETECT_VOL;
                        else
                            dac_data_o  <=  REMEM_NEG_VOL;
                    end
                    else begin//short pulses
                        if(ch_cnt>=PULSE_N2)
                            dac_data_o  <=  DETECT_VOL;
                        else
                            dac_data_o  <=  REMEM_SHORT_NEG_VOL;
                    end
                end
                else begin//high resistance
                    if(memristor_adc_data<MEM_INIT_DOWN_almoset)begin//wide pulses
                        if(ch_cnt>=PULSE_P1)
                            dac_data_o  <=  DETECT_VOL;
                        else
                            dac_data_o  <=  REMEM_POS_VOL;
                    end
                    else begin//short pulses
                        if(ch_cnt>=PULSE_P2)
                            dac_data_o  <=  DETECT_VOL;
                        else
                            dac_data_o  <=  REMEM_SHORT_POS_VOL;
                    end
                end
            end
            IDLE:begin
                dac_data_o  <=  DETECT_VOL;
            end
        endcase
end
`endif

//****************************ADC reception**********************************//

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        begin_adc_conv  <=  0;
    else if(state==DETECT_P||state==DETECT_R) begin
        if(adc_rece_cnt==3'b111&&adc_done)
            begin_adc_conv  <=  0;
        else
            begin_adc_conv  <=  1'b1;
    end
    else
        begin_adc_conv  <=  0;
end

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        adc_rece_cnt    <=  0;
    else if((state==DETECT_P||state==DETECT_R)&&adc_done)
        adc_rece_cnt    <=  adc_rece_cnt+1'b1;
end

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        adc_data_sum    <=  0;
    else if(adc_done&&adc_rece_cnt>8'd3)
        adc_data_sum    <=  adc_data_sum+adc_data;
    else if(go_detect_p||go_detect_r)
        adc_data_sum    <=  0;
end 

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        memristor_adc_data  <=  0;
    else if(state==WAIT_SW_2)
        memristor_adc_data  <=  adc_data_abs[15:0];
end

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        piezo_adc_data  <=  0;
    else if(state==WAIT_SW_1)
        piezo_adc_data  <=  adc_data_abs[15:0];
end
//****************************data upload**********************************//

always @(posedge clk_i or negedge rst_n_i) begin
    if(!rst_n_i)
        upload_data_vld <=  0;
    else if(go_adapt||go_break||go_idle||go_remem)
        upload_data_vld <=  1'b1;
    else if(upload_data_rdy==0)
        upload_data_vld <=  0;
end

assign                  mem_state   =   (state==IDLE)   ?   2'd0:
                                        (state==REMEM)  ?   2'd1:
                                        (state==ADAPT)  ?   2'd2:
                                        (state==BREAK)  ?   2'd3:
                                        2'd0;

//****************************module instantiation**********************************//

ADS8689 ADS8689_u0 (
    .clk_50m                (clk_i          ),
    .rst_n                  (rst_n_i        ),
    .begin_conv             (begin_adc_conv ),
    .conv_done              (adc_done       ),
    .init_done              (adc_init_done  ),
    .conv_data              (adc_data       ),

    .RVS                    (RVS_i          ),
    .CONVST                 (CONVST_o       ),
    .ADC_RST                (ADC_RST_o      ),

    .sdi                    (adc_sdi_i      ),
    .sdo                    (adc_sdo_o      ),
    .sclk                   (adc_sclk_o     )
);

data_upload data_upload_u0 (
    .clk_i                  (clk_i          ),
    .rst_n_i                (rst_n_i        ),
    .flagA_i                (flagA_i        ),
    .cy_full_i              (cy_full_i      ),
    .cy_empty_i             (cy_empty_i     ),
    .slcs_o                 (slcs_o         ),
    .sloe_o                 (sloe_o         ),
    .slrd_o                 (slrd_o         ),
    .slrwr_o                (slrwr_o        ),
    .pktend_o               (pktend_o       ),
    .USB_idata_i            (USB_idata      ),
    .USB_odata_o            (USB_odata      ),
    .FIFOadr_o              (FIFOadr_o      ),
    .fd_sign_o              (fd_sign        ),
    .memristor_adc_data_i   (memristor_adc_data),
    .piezo_adc_data_i       (piezo_adc_data ),
    .ch_sign_i              (ch_sign        ),
    .mem_state_i            (mem_state      ),
    .TX                     (TX             ),
    .data_vld_i             (upload_data_vld),
    .data_rdy_o             (upload_data_rdy)
);

npn_test npn_test_u0        (
    .clk                    (clk_i          ),
    .rst_n                  (rst_n_i        ),
    .memristor_ref          (memristor_adc_data),
    .piezo_ref              (piezo_adc_data ),
    .ch_sign_i              (ch_sign        ),
    .control_rdy            (control_rdy    ),
    .o_control              (o_control      )
    // .control_done           (control_done)
);
endmodule