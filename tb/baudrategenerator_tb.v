module Baudrategenerator_tb();

// declare input ports as reg data types
 reg Pclk;
 reg Preset_n;
 reg spiswai_i;
 reg ss_i;
 reg Cpol_i;
 reg Cpha_i;
 reg [2:0] sppr_i,spr_i;
 reg [1:0] spi_mode_i;
 
 // output ports as wire data types
 
 wire [11:0] baudratedivisor;
 wire Sclk;
 wire miso_receive_sclk0_o, miso_receive_sclk_o,  mosi_send_sclk0_o, mosi_send_sclk_o;
 
 // instantiate the unit under test or RTL
 baudrate_generator UUT (
 Pclk, Preset_n, spiswai_i, Cpha_i, ss_i, Cpol_i,
 spi_mode_i[1:0], sppr_i [2:0], spr_i[2:0], 
 Sclk, miso_receive_sclk0_o, miso_receive_sclk_o,  mosi_send_sclk0_o, mosi_send_sclk_o,
 baudratedivisor [11:0]
 );
 
 // generate Pclk for data trasnfer
  
  always 
   begin
         Pclk = 1'b0;
    forever
     #10 Pclk = ~Pclk;
   end
  
  // write a task to initialize the inputs
   
  task initialize();
   begin
    spiswai_i = 0;
	ss_i = 0;
	Cpol_i = 0;
	Cpha_i = 0;
   end 
  endtask	
  
  // write a task to reset all ports   
  
    task reset ();
	 begin
	    Preset_n = 1'b0;
		#20;
		Preset_n = 1'b1;
	 end
	endtask
	
  // write a task to give stimulus to ports
   
    task stimulus(input i, input j);
	 begin
	    Cpol_i = i;
		Cpha_i = j;
		spi_mode_i = 2'b00;
		sppr_i = 3'b000;
		spr_i = 3'b010;
		ss_i =  1'b0;
	 end
	endtask
    
  // call all the tasks in the inital block
     
	 initial  
	    begin
          initialize;
		  reset;
		  stimulus (0,0);
		  #500;
		  stimulus (0,1);
		  #1000;
		  $finish;
		end
	
	endmodule 
		  