library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- 5x7 LED matrix scan driver.
--
-- Lights one pixel at a time (row x column). This keeps the current
-- through the 74HC595 row outputs at a single LED's worth - do NOT
-- change to row-wise scanning without adding row driver transistors.
--
-- For each pixel a 16-bit frame is shifted into the 74HC595 (rows) /
-- STP08DP05 (columns) chain at ~3 MHz, latched with a rising edge on
-- EN, and displayed for DISPLAY_TIME before moving to the next pixel.

entity led_matrix_controller is
    Port (
        CLOCK_50 : in std_logic;
        enable : in std_logic;  -- Connected to SWITCH[2]
        char_select : in std_logic_vector(3 downto 0);  -- Select character to display (0-F)
        LedMatrix_CLK : out std_logic;
        LedMatrix_EN : out std_logic;
        LedMatrix_Data : out std_logic;
        status_led : out std_logic  -- Status LED for switch
    );
end led_matrix_controller;

architecture Behavioral of led_matrix_controller is

    -- Character ROM for 5x7 LED matrix (16 characters: 0-9, A-F)
    type char_rom_type is array (0 to 15, 0 to 6) of std_logic_vector(4 downto 0);
    constant char_rom : char_rom_type := (
        -- Character '0'
        0 => ("01110", "10001", "10011", "10101", "11001", "10001", "01110"),
        -- Character '1'
        1 => ("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
        -- Character '2'
        2 => ("01110", "10001", "00001", "00010", "00100", "01000", "11111"),
        -- Character '3'
        3 => ("01110", "10001", "00001", "00110", "00001", "10001", "01110"),
        -- Character '4'
        4 => ("00010", "00110", "01010", "10010", "11111", "00010", "00010"),
        -- Character '5'
        5 => ("11111", "10000", "11110", "00001", "00001", "10001", "01110"),
        -- Character '6'
        6 => ("00110", "01000", "10000", "11110", "10001", "10001", "01110"),
        -- Character '7'
        7 => ("11111", "00001", "00010", "00100", "01000", "01000", "01000"),
        -- Character '8'
        8 => ("01110", "10001", "10001", "01110", "10001", "10001", "01110"),
        -- Character '9'
        9 => ("01110", "10001", "10001", "01111", "00001", "00010", "01100"),
        -- Character 'A'
        10 => ("01110", "10001", "10001", "10001", "11111", "10001", "10001"),
        -- Character 'b'
        11 => ("11110", "10001", "10001", "11110", "10001", "10001", "11110"),
        -- Character 'C'
        12 => ("01110", "10001", "10000", "10000", "10000", "10001", "01110"),
        -- Character 'd'
        13 => ("11100", "10010", "10001", "10001", "10001", "10010", "11100"),
        -- Character 'E'
        14 => ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
        -- Character 'F'
        15 => ("11111", "10000", "10000", "11110", "10000", "10000", "10000")
    );

    -- State machine
    type state_type is (IDLE, SHIFT_DATA, LATCH_DATA, DISPLAY_DELAY);
    signal current_state : state_type := IDLE;

    -- Shift timing: 16 clocks per bit -> ~3 MHz shift clock.
    -- Data is put out while CLK is low; CLK is high for the second half.
    signal phase       : unsigned(3 downto 0) := (others => '0');
    signal bit_counter : unsigned(3 downto 0) := (others => '0');

    -- EN latch pulse timing (50 MHz cycles)
    constant EN_SETUP : integer := 4;  -- EN held low before the pulse
    constant EN_PULSE : integer := 7;  -- EN high; the rising edge latches

    -- Display time per pixel: 5000 cycles = 100 us
    constant DISPLAY_TIME : integer := 5000;
    signal display_counter : unsigned(15 downto 0) := (others => '0');

    -- Data shift register and pixel position
    signal shift_data_package : std_logic_vector(15 downto 0) := (others => '0');
    signal row_counter    : unsigned(2 downto 0) := (others => '0');  -- 0-6
    signal column_counter : unsigned(2 downto 0) := (others => '0');  -- 0-4

    signal row_data      : std_logic_vector(4 downto 0);  -- Current row pattern, masked to one column
    signal row_select    : std_logic_vector(6 downto 0);  -- One-hot row selection
    signal column_select : std_logic_vector(4 downto 0);  -- One-hot column mask

    -- Output registers
    signal matrix_clk_internal  : std_logic := '0';
    signal matrix_en_internal   : std_logic := '0';
    signal matrix_data_internal : std_logic := '0';

begin

    -- Status LED shows enable state
    status_led <= enable;

    -- Current pixel: the selected character's row, masked to one column
    row_data <= column_select and char_rom(to_integer(unsigned(char_select)), to_integer(row_counter));

    -- Generate row selection pattern (skip pin 1 of 74HC595)
    -- 74HC595 pins: [QH(Pin8) QG(Pin7) QF(Pin6) QE(Pin5) QD(Pin4) QC(Pin3) QB(Pin2) QA(Pin1-unused)]
    process(row_counter)
    begin
        case row_counter is
            when "000" => row_select <= "1000000";  -- Row 0
            when "001" => row_select <= "0100000";  -- Row 1
            when "010" => row_select <= "0010000";  -- Row 2
            when "011" => row_select <= "0001000";  -- Row 3
            when "100" => row_select <= "0000100";  -- Row 4
            when "101" => row_select <= "0000010";  -- Row 5
            when "110" => row_select <= "0000001";  -- Row 6
            when others => row_select <= "0000000";
        end case;
    end process;

    -- Generate column selection pattern
    process(column_counter)
    begin
        case column_counter is
            when "000" => column_select <= "00001";  -- Column 0
            when "001" => column_select <= "00010";  -- Column 1
            when "010" => column_select <= "00100";  -- Column 2
            when "011" => column_select <= "01000";  -- Column 3
            when "100" => column_select <= "10000";  -- Column 4
            when others => column_select <= "00000";
        end case;
    end process;

    -- Main state machine
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            if enable = '0' then
                current_state <= IDLE;
                phase <= (others => '0');
                bit_counter <= (others => '0');
                row_counter <= (others => '0');
                column_counter <= (others => '0');
                display_counter <= (others => '0');
                matrix_clk_internal <= '0';
                matrix_en_internal <= '0';
                matrix_data_internal <= '0';
            else
                case current_state is
                    when IDLE =>
                        -- Prepare the frame for the current pixel
                        phase <= (others => '0');
                        bit_counter <= (others => '0');
                        display_counter <= (others => '0');
                        matrix_en_internal <= '0';
                        -- 16-bit frame: [3 unused][5 column bits][1 unused][7 row bits],
                        -- column and row bits LSB first; the MSB half ends up in the
                        -- 74HC595, the LSB half in the STP08DP05
                        shift_data_package <= "000" &
                                     row_data(0) & row_data(1) & row_data(2) & row_data(3) & row_data(4) &
                                     "0" &
                                     row_select(0) & row_select(1) & row_select(2) & row_select(3) & row_select(4) & row_select(5) & row_select(6);
                        current_state <= SHIFT_DATA;

                    when SHIFT_DATA =>
                        -- One bit per 16 cycles: present data with CLK low,
                        -- raise CLK halfway (chips clock on the rising edge),
                        -- shift and advance at the end of the bit period
                        phase <= phase + 1;
                        if phase = 0 then
                            matrix_clk_internal <= '0';
                            matrix_data_internal <= shift_data_package(15);
                        elsif phase = 8 then
                            matrix_clk_internal <= '1';
                        elsif phase = 15 then
                            shift_data_package <= shift_data_package(14 downto 0) & '0';
                            if bit_counter = 15 then
                                bit_counter <= (others => '0');
                                matrix_clk_internal <= '0';
                                current_state <= LATCH_DATA;
                            else
                                bit_counter <= bit_counter + 1;
                            end if;
                        end if;

                    when LATCH_DATA =>
                        -- Rising edge on EN transfers the shift registers to the outputs
                        if display_counter < EN_SETUP then
                            matrix_en_internal <= '0';
                            display_counter <= display_counter + 1;
                        elsif display_counter < EN_SETUP + EN_PULSE then
                            matrix_en_internal <= '1';
                            display_counter <= display_counter + 1;
                        else
                            matrix_en_internal <= '0';
                            display_counter <= (others => '0');
                            current_state <= DISPLAY_DELAY;
                        end if;

                    when DISPLAY_DELAY =>
                        -- Hold the pixel, then advance column-first through the matrix
                        matrix_en_internal <= '0';
                        display_counter <= display_counter + 1;

                        if display_counter >= DISPLAY_TIME then
                            if column_counter = 4 then
                                column_counter <= (others => '0');
                                if row_counter = 6 then
                                    row_counter <= (others => '0');
                                else
                                    row_counter <= row_counter + 1;
                                end if;
                            else
                                column_counter <= column_counter + 1;
                            end if;
                            current_state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- Output assignments
    LedMatrix_CLK <= matrix_clk_internal when enable = '1' else '0';
    LedMatrix_EN <= matrix_en_internal when enable = '1' else '0';
    LedMatrix_Data <= matrix_data_internal when enable = '1' else '0';

end Behavioral;
