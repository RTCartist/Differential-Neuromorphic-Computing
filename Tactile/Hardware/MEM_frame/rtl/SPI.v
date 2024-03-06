/*
        Module Name: SPI
        Function: SPI protocol layer module for data exchange
        Overview:
            Begin_SPI is set to 1 to start data exchange. The data to be sent is placed on odata. When SPI_done is high, data from the slave can be received by reading idata, and odata can be changed to send the next set of data. SPI_done only lasts for one clock cycle (50m).
            CPOL and CPHA are used to set clock polarity and phase polarity (no support for changing phase polarity during transmission; if phase polarity needs to be changed, Begin_SPI needs to be changed one clock cycle in advance)
*/
module SPI(
    input               clk_50m,    // System input clock
    input               rst_n,      // Reset
    input   [7:0]       odata,      // Data to be sent, from the perspective of the FPGA master controller, FPGA->SPI->peripheral
    input               Begin_SPI,  // Input control signal for SPI module
    input               MISO,       // Master input slave output data line
    input   [5:0]       Div,        // Set to 2/4/8/16/32/64, indicating the speed of SPI (i.e., division factor)
    input               CPOL,       // Clock polarity setting 
    input               CPHA,       // Phase polarity setting
    input               CS_control, // CS control chip select input signal

    output  reg         SPI_done,   // SPI_done
    output  reg         SCLK,       // Synchronous clock
    output  reg         MOSI,       // Master output slave input
    output              CS,         // Output chip select
    output  reg [7:0]   idata       // Output data
);

reg     [5:0]   trans_cnt;
reg     [4:0]   byte_cnt;
reg     [7:0]   SSPSR;  // Shift register

// Assign MOSI = SSPSR[7];

assign  CS = CS_control;

// Clock counter   
always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n)
        trans_cnt <= 0;
    else if (trans_cnt == Div - 1'b1)
        trans_cnt <= 0;
    else if (Begin_SPI == 1'b1 && byte_cnt < 4'd9 && SPI_done == 0)
        trans_cnt <= trans_cnt + 1'b1;
    else    
        trans_cnt <= 0;
end

// Initialization 
always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        SSPSR   <= 0;
        MOSI    <= 1'b1;
        byte_cnt <= 0;
        SCLK    <= CPOL;
        // CS    <= 1'b1;
    end
    else if (Begin_SPI == 1'b1 && byte_cnt < 4'd9 && SPI_done == 0) begin
        if (CPHA == 0) begin // Sample in the first clock cycle, launch in the second clock cycle
            if (trans_cnt == ((Div >> 1) - 1'b1)) begin // In the middle of the period
                // SSPSR <= odata;
                SCLK    <= CPOL; // Idle clock at this time
                byte_cnt <= byte_cnt + 1'b1;
                if (byte_cnt == 0) begin
                    SSPSR <= odata; // If this is a new byte, put the data to be output into the shift register
                    MOSI  <= odata[7]; // Arrange the data to be output
                end
                else begin
                    MOSI <= SSPSR[7]; // Arrange the data to be output
                end
            end
            else if (trans_cnt == Div - 1'b1) begin // At the end of the period
                SSPSR <= {SSPSR[6:0], MISO}; // The first edge is here, start sampling
                SCLK  <= ~CPOL;
            end
        end
        else if (CPHA == 1'b1) begin // Sample in the second clock cycle, launch in the first clock cycle
            if (trans_cnt == ((Div >> 1) - 1'b1)) begin // In the middle of the period, sample the output
                if (byte_cnt != 0) begin
                    SCLK  <= CPOL;
                    SSPSR <= {SSPSR[6:0], MISO};
                end
            end
            else if (trans_cnt == (Div - 1'b1)) begin // At the end of the period
                byte_cnt <= byte_cnt + 1'b1;
                if (byte_cnt == 0) begin
                    SCLK  <= ~CPOL;
                    SSPSR <= odata; // If this is a new byte, put the data to be output into the shift register
                    MOSI  <= odata[7]; // Arrange the data to be output
                end
                else if (byte_cnt != 4'd8) begin
                    SCLK  <= ~CPOL;
                    MOSI  <= SSPSR[7]; // Arrange the data to be output
                end
            end
        end
    end
    else begin
        SCLK    <= CPOL;
        MOSI    <= 1'b1;
        byte_cnt <= 0;
    end
end

always @(posedge clk_50m or negedge rst_n) begin
    if (!rst_n) begin
        idata    <= 0;
        SPI_done <= 0;
    end
    else if (Begin_SPI == 1'b1 && byte_cnt == 4'd9) begin
        idata    <= SSPSR;
        SPI_done <= 1'b1;
    end
    else
        SPI_done <= 0;
end

endmodule
