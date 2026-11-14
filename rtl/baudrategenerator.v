module baudrate_generator(
    input        Pclk, Preset_n, spiswai_i, Cpha_i, ss_i, Cpol_i,
    input  [1:0] spi_mode_i,
    input  [2:0] sppr_i, spr_i,
    output reg   Sclk, miso_receive_sclk0_o, miso_receive_sclk_o,
    output reg   mosi_send_sclk0_o, mosi_send_sclk_o,
    output [11:0] baudratedivisor
);

// declare internal signals

wire Pre_Sclk;
reg [11:0] count;

assign baudratedivisor = ((sppr_i+1)*(2**(spr_i+1)));
// Generate The Initial of SCLK Polarity using combinatinal assign
// statement with conditional operator
assign Pre_Sclk = (Cpol_i)? 1'b1:1'b0;


// generate SPI clock(Sclk)
always @(posedge Pclk or negedge Preset_n)
begin
    if(!Preset_n)
    begin
        Sclk <= Pre_Sclk;   // idle level of Cpol_i
        count <= 0;         // count is set back to 0
    end
    else
    begin
        if(((spi_mode_i == 2'b00) || (spi_mode_i == 2'b01)) && (!ss_i) && (!spiswai_i)) // clock gen enable, slave selected, spiswai=0
        begin
            if(count == ((baudratedivisor -1'b1)/2))   // 1.determine the count value
            begin
                Sclk <= ~Sclk;                         // 2.Sclk toggles at this count value
                count <= 1'd0;                         // 3.count starts from 0
            end
            else
                count <= count + 1'b1;
        end
        else                                           // if spiswai = 1 then no clock generation
        begin
            Sclk <= Pre_Sclk;                          // Sclk = idle value
            count <= 1'd0;                             // count becomes zero
        end
    end
end


// generate MOSI signals clk using Sclk at posedge of Pclk using sequential block
always @(posedge Pclk or negedge Preset_n)
begin
    if(!Preset_n)
    begin
        mosi_send_sclk_o <= 0;
        mosi_send_sclk0_o <= 0;
    end
    else
    begin
        if((!Cpha_i && Cpol_i) || (Cpha_i && !Cpol_i))
        begin
            if(Sclk == 1'b1)
            begin
                if(count == ((baudratedivisor -1'b1)/2))
                    mosi_send_sclk0_o <= 1'b1;
                else
                    mosi_send_sclk0_o <= 1'b0;
            end
            else
            begin
                mosi_send_sclk0_o <= 1'b0;
            end
        end
        else
        begin
            if((!Cpha_i && !Cpol_i) || (Cpha_i && Cpol_i))
            begin
                if(Sclk == 1'b0)
                begin
                    if(count == ((baudratedivisor -1'b1)/2))
                        mosi_send_sclk_o <= 1'b1;
                    else
                        mosi_send_sclk_o <= 1'b0;
                end
                else
                begin
                    mosi_send_sclk_o <= 1'b0;
                end
            end
        end
    end
end


// generate MISO signals clk using Sclk at posedge of Pclk using sequential block
always @(posedge Pclk or negedge Preset_n)
begin
    if(!Preset_n)
    begin
        miso_receive_sclk0_o <= 0;
        miso_receive_sclk_o <= 0;
    end
    else if((!Cpha_i && Cpol_i) || (Cpha_i && !Cpol_i))   // falling edge
    begin
        if(Sclk == 1'b1)                                  // Sclk is 1
        begin
            if(count == ((baudratedivisor -1'b1)/2))      // count = target, Sclk flips 1 to 0
                miso_receive_sclk0_o <= 1'b1;             // flag is raised
            else
                miso_receive_sclk0_o <= 1'b0;             // flag not raised
        end
        else
            miso_receive_sclk0_o <= 1'b0;                 // Sclk is not 1, flag not raised
    end
    else if((!Cpha_i && !Cpol_i) || (Cpha_i && Cpol_i))   // rising edge
    begin
        if(Sclk == 1'b0)                                  // Sclk is 0
        begin
            if(count == ((baudratedivisor -1'b1)/2))      // count = target, Sclk flips 0 to 1
                miso_receive_sclk_o <= 1'b1;              // flag is raised, sampling is going to happen
            else
                miso_receive_sclk_o <= 1'b0;              // flag is not raised
        end
        else
            miso_receive_sclk_o <= 1'b0;                  // Sclk is not 0, flag not raised
    end
end

endmodule