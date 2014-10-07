
// Copyright 2014 Ettus Research LLC
// axi_mux -- takes arbitrary number of AXI stream, merges them to 1 output channel
// Round-robin if PRIO=0, priority if PRIO=1 (lower number ports get priority)
// Bubble cycles are inserted after each packet

module axi_mux
  #(parameter PRIO=0,
    parameter WIDTH=64,
    parameter BUFFER=0,
    parameter SIZE=4)
   (input clk, input reset, input clear,
    input [(WIDTH*SIZE)-1:0] i_tdata, input [SIZE-1:0] i_tlast, input [SIZE-1:0] i_tvalid, output [SIZE-1:0] i_tready,
    output [WIDTH-1:0] o_tdata, output o_tlast, output o_tvalid, input o_tready);

   wire [WIDTH-1:0]    o_tdata_int;
   wire 	       o_tlast_int, o_tvalid_int, o_tready_int;
   
   reg [3:0] 	       st_port;
   reg 		       st_active;

   always @(posedge clk)
     if(reset)
       begin
	  st_port <= 0;
	  st_active <= 1'b0;
       end
     else
       if(st_active)
	 begin
	    if(o_tlast_int & o_tvalid_int & o_tready_int)
	      begin
		 st_active <= 1'b0;
		 if((PRIO != 0) | (st_port == (SIZE-1)))
		   st_port <= 0;
		 else
		   st_port <= st_port + 1;
	      end
	 end // if (st_active)
       else
	 if(i_tvalid[st_port])
	   st_active <= 1'b1;
	 else
	   if(st_port == (SIZE-1))
	     st_port <= 0;
	   else
	     st_port <= st_port + 1;
   
   genvar 		 i;
   generate
      for(i=0;i<SIZE;i=i+1)
	begin : gen1
	   assign i_tready[i] = st_active & o_tready_int & (st_port == i);
	end
   endgenerate

   assign o_tvalid_int = st_active & i_tvalid[st_port];
   assign o_tlast_int = i_tlast[st_port];

   genvar 		 j;
   generate
      for (j=0;j<WIDTH;j=j+1)
	begin : gen2
	   assign o_tdata_int[j] = i_tdata[st_port*WIDTH+j];
	end
   endgenerate
   
   generate
      if(BUFFER == 0)
	begin
	   assign o_tdata = o_tdata_int;
	   assign o_tlast = o_tlast_int;
	   assign o_tvalid = o_tvalid_int;
	   assign o_tready_int = o_tready;
	end
      else
	axi_fifo_short #(.WIDTH(WIDTH+1)) axi_fifo_short
	  (.clk(clk), .reset(reset), .clear(clear),
	   .i_tdata({o_tlast_int,o_tdata_int}), .i_tvalid(o_tvalid_int), .i_tready(o_tready_int),
	   .o_tdata({o_tlast,o_tdata}), .o_tvalid(o_tvalid), .o_tready(o_tready),
	   .space(), .occupied());
   endgenerate
   
endmodule // axi__mux
