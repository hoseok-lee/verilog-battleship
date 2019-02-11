// use update_control as the control module

module update_screen_datapath(
    // master input
    CLOCK,

    // VGA inputs
    cell_x_in, cell_y_in,
    cell_colour_in,
    screen_state,
    // input control signals
    START_DRAWING,

    // output controls
    screen_counter,
    // VGA outputs
    screen_x_out, screen_y_out,
    screen_colour_out
);

    input             CLOCK;
    input             START_DRAWING;
    input [2:0]       screen_state;
    input [8:0]       cell_x_in;
    input [7:0]       cell_y_in;
    input [2:0]       cell_colour_in;

    output reg [16:0] screen_counter;
    output reg [8:0]  screen_x_out;
    output reg [7:0]  screen_y_out;
    output reg [2:0]  screen_colour_out;


        // STATE DEFINITIONS
    localparam
        S_BLACK_SCREEN          = 3'd0,
        S_GAME_BOARD            = 3'd1,
        S_PLAYER1_WIN_SCREEN    = 3'd2,
        S_PLAYER2_WIN_SCREEN    = 3'd3;


        // determines whether the screen is drawing the first first pixel or not
    reg               first_pixel;


        // screen RAMs
    wire  [16:0]      RAM_address;
    wire  [2:0]       PLAYER1_WIN_SCREEN_colour, PLAYER2_WIN_SCREEN_colour;


    vga_address_translator a3(screen_x_out, screen_y_out, RAM_address);
    player1win a1(
        .address(RAM_address),
        .clock  (CLOCK),
        .data   (3'b0),
        .wren   (1'b0),
        .q      (PLAYER1_WIN_SCREEN_colour)
    );
    player2win a2(
        .address(RAM_address),
        .clock  (CLOCK),
        .data   (3'b0),
        .wren   (1'b0),
        .q      (PLAYER2_WIN_SCREEN_colour)
    );


    always @(*)
        begin :signal_table
            case (screen_state)
                S_BLACK_SCREEN:
                    screen_colour_out <= 3'b000;
                S_GAME_BOARD:
                    screen_colour_out <= cell_colour_in;
                S_PLAYER1_WIN_SCREEN:
                    screen_colour_out <= PLAYER1_WIN_SCREEN_colour;
                S_PLAYER2_WIN_SCREEN:
                    screen_colour_out <= PLAYER2_WIN_SCREEN_colour;

                default:
                    screen_colour_out <= 3'b000;
            endcase
        end


    always @(posedge CLOCK)
        if (START_DRAWING)
            begin
                screen_counter <= 17'b0;
                screen_x_out <= 9'b0;
                screen_y_out <= 8'b0;

                first_pixel <= 1'b1;
            end

        else
                // only draw a select part of the screen
            if (screen_state == S_GAME_BOARD)
                begin
                    screen_x_out <= cell_x_in;
                    screen_y_out <= cell_y_in;
                end

                // draw the whole screen
            else
                begin
                    screen_counter <= screen_counter+17'b1;

                    if (first_pixel)
                        first_pixel <= 1'b0;

                    else
                        begin
                            screen_x_out <= screen_x_out+9'b1;

                            if (screen_x_out == 9'd319)
                                begin
                                    screen_y_out <= screen_y_out+8'b1;
                                    screen_x_out <= 9'b0;
                                end
                        end
                end
endmodule