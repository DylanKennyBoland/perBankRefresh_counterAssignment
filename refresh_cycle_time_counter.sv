// Author: Dylan Boland
//
// Module which implements a counter that measures the time it takes
// for a per-bank refresh to be carried out in an SDRAM memory. This time
// is known as the "refresh cycle time", and is denoted by tRFCpb in the
// JEDEC specifications for LPDDR SDRAMs.
//
// Description of the module's behaviour:
`include "design_parameters.svh" // include the design parameters

module refresh_cycle_time_counter (
	// ==== Inputs ====
	input logic clk,
	input logic rst_n,
	input logic start,
	input logic [TRFC_PB_WIDTH-1:0] trfc_pb,
	input logic [BANK_ADDR_WIDTH-1:0] bank_assigned,
	// ==== Outputs ====
	output logic assigned,
	output logic counter_done,
	output logic [BANK_ADDR_WIDTH-1:0] assigned_bank
	);
	
	// ==== Signal Declarations ====
	logic [TRFC_PB_WIDTH-1:0] count;
	logic [TRFC_PB_WIDTH-1:0] next_count;
	logic count_at_zero;
	logic assigned; // indicates if this counter instance is assigned (i.e., in the process of counting)
	logic assigned_next;
	logic [BANK_ADDR_WIDTH-1:0] assigned_bank_next;
	
	// ==== Signal Definitions ====
	assign count_at_zero = (count == {TRFC_PB_WIDTH{1'b0}});
	
	// ==== Logic for the Count Value ====
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			count <= {TRFC_PB_WIDTH{1'b0}};
		end else begin
			count <= next_count;
		end
	end
	
	// ==== Logic for Next-Count Value ====
	always_comb begin
		next_count = {TRFC_PB_WIDTH{1'b0}};
		case ({start, assigned, count_at_zero}) begin
			3'b101: next_count = trfc_pb;
			3'b0?1: next_count = count;
			3'b010: next_count = count - 1'b1;
			default: begin
				// We should not end up in here.
				$display("Error: Illegal combination for {start, assigned, count_at_zero}, {%0b, %0b, %0b}", start, assigned, count_at_zero);
			end
		endcase
	end
	
	// ==== Logic for the Assigned Output ====
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			assigned <= 1'b0;
		end else begin
			assigned <= assigned_next;
		end
	end

	always_comb begin
		assigned_next = 1'b0;
		case ({start, count_at_zero}) begin
			2'b00, 2'b11: assigned_next = 1'b1;
			2'b01: assigned_next = 1'b0;
			2'b10: begin
				$display("Error: 'start' input has asserted while counter is still counting.");
			end
		endcase
	end
	
	// ==== Logic to generate the Assigned-Bank Output ====
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			assigned_bank <= {BANK_ADDR_WIDTH{1'b0}};
		end else begin
			assigned_bank <= assigned_bank_next;
		end
	end
	
	always_comb begin
		// ==== Define Default Behaviour ====
		assigned_bank_next = assigned_bank;
		case ({start, assigned}) begin
			2'b00: assigned_bank_next = {BANK_ADDR_WIDTH{1'b0}};
			2'b10: assigned_bank_next = bank_assigned;
			// Note: If this counter is still assigned, then it is
			// in the process of counting down. As such, we should
			// hold onto the current bank information (i.e., don't change it).
			2'b01: assigned_bank_next = assigned_bank;
			// If this counter is already assigned, then it should not be
			// started again (i.e., reassigned) until it is finished counting down.
			// As such, we should not see a case where both "start" and "assigned"
			// are high at the same time.
			2'b11: begin
				$display("Error: 'start' input has asserted while the counter is already assigned.")
			end
		endcase
	end
	
	// ==== Logic for generating the counter-done indicator ====
	// The signal below will pulse high when the counter reaches zero.
	assign counter_done = assigned && count_at_zero;

endmodule