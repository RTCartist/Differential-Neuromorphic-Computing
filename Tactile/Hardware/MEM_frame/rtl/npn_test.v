//manipulator control
module npn_test(
input                        clk,
input                        rst_n,
input           [15:0]       memristor_ref,
input           [15:0]       piezo_ref,
input           [3:0]        ch_sign_i,
input                        control_rdy,
output          [1:0]        o_control
// output      reg              control_done 
);

//detection parameters
parameter       mem_initial_vol     =    16'd3000;
parameter       piezo_initial_vol   =    16'd0800;
parameter       mem_noc_th          =    16'd6312;
parameter       mem_adp_th          =    16'd1903;
parameter       piezo_noc           =    16'd5950;
parameter       piezo_adp           =    16'd1304;
parameter       piezo_adp_store      =    16'd1743;
parameter       control_ch          =    4'b0010;//control channel


reg             [15:0]       mem_state_store;
reg             [15:0]       mem_state_temp;
reg             [15:0]       piezo_state_temp;
reg             [15:0]       piezo_state_store;
reg             [1:0]        bit_control;
wire                         action_1;
wire                         action_2;
wire                         action_3;
wire                         action_4;
reg                          control_begin;
reg							 control_done;
reg             [7:0]        control_time_cnt;   

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mem_state_store <=  mem_initial_vol;
        mem_state_temp  <=  mem_initial_vol;
        piezo_state_temp  <=  piezo_initial_vol;
        piezo_state_store  <=  piezo_initial_vol;
        control_begin    <=  1'b0;
    end
    else if(control_rdy&&(ch_sign_i==control_ch)&&(control_done==1'b1)) begin
        mem_state_temp  <=  memristor_ref;
        mem_state_store <=  mem_state_temp;
        piezo_state_temp  <=  piezo_ref;
        piezo_state_store <=  piezo_state_temp;
        control_begin    <= 1'b1;
    end
    else if (control_done==1'b1)
        control_begin    <= 1'b0;
end


//pain reflex
assign    action_1  = (mem_state_temp>mem_noc_th)&&(piezo_state_temp>piezo_noc);
//slip detection
assign    action_2  = (mem_state_temp<mem_adp_th)&&(piezo_state_temp<piezo_adp)&&(piezo_state_store>piezo_adp_store);

//tri-state gate
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        bit_control   <=  2'b00;
        control_done  <=  1'b1;
    end
    else if (control_begin==1'b1) begin
        if (control_time_cnt<8'hFF) begin    
            if (action_1) begin
                bit_control   <=  2'b10;
                control_done  <=  1'b0;
            end
            else if (action_2) begin
                bit_control   <=  2'b11;
                control_done  <=  1'b0;
            end
        end
        else 
            control_done <= 1'b1;
    end
    else   
        control_done <= 1'b1;
end

//
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        control_time_cnt <= 8'h00;
    else if ((control_begin==1'b1)&&(control_done==1'b0))
        control_time_cnt <= control_time_cnt +1;
    else
        control_time_cnt <= 8'h00;
end

assign  o_control      =  bit_control;
// assign  o_control      =  2'b00;
endmodule