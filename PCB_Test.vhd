library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity PCB_Test is
    Port ( CLOCK_50 : in  std_logic;
           led_pcb : out  std_logic_vector (7 downto 0);
			  LED : out std_logic_vector (1 downto 0);
			  RotaryEncoder_SW : in std_logic;
			  RotaryEncoder : in std_logic_vector (1 downto 0);-- (0)->A ; (1)->B
			  SWITCH : in std_logic_vector (3 downto 0);
			  BUTTON : in std_logic_vector (3 downto 0);
			  AUDIO_OUT : out std_logic; -- PWM signal
			  LedMatrix_CLK : out std_logic;
			  LedMatrix_EN : out std_logic;
			  LedMatrix_Data : out std_logic;
           VGA_R : out std_logic_vector(3 downto 0);
           VGA_G : out std_logic_vector(3 downto 0);
           VGA_B : out std_logic_vector(3 downto 0);
           VGA_HS : out std_logic;
           VGA_VS : out std_logic);
end PCB_Test;

architecture Behavioral of PCB_Test is
    signal counter : unsigned (24 downto 0) := (others => '0');
    signal led_blink : std_logic := '0';  -- Heartbeat blink for LED(1)
    
    -- Debounced input signals from input_handler module
    signal BUTTON_deb : std_logic_vector (3 downto 0) := (others => '0');
    signal SWITCH_deb : std_logic_vector (3 downto 0) := (others => '0');
    
    -- Rotary encoder signals from dedicated controller
    signal RotaryEncoder_SW_deb : std_logic := '0';
    signal rotary_value        : unsigned(3 downto 0) := (others => '0');
    signal rotary_step_pulse   : std_logic := '0';
    
    -- LED Matrix control signals
    signal led_matrix_char : std_logic_vector(3 downto 0) := "0000";  -- Display character (0-F)

    -- VGA mode control:
    -- "00" = diagonal, "01" = window, "10" = rotary bar
    signal vga_mode : std_logic_vector(1 downto 0) := "00";
    signal button0_prev : std_logic := '0';
    
begin
    -- Button and switch debouncing
    input_handler_inst: entity work.input_handler
    port map (
        CLOCK_50 => CLOCK_50,
        BUTTON => BUTTON,
        SWITCH => SWITCH,
        BUTTON_deb => BUTTON_deb,
        SWITCH_deb => SWITCH_deb
    );
    
    -- Sine generator with PWM output; the rotary encoder selects the
    -- note (natural notes G3 to A5)
    audio_inst: entity work.audio_controller
    port map (
        clk => CLOCK_50,
        enable => SWITCH_deb(3),
        rotary_value => rotary_value,
        audio_out => AUDIO_OUT
    );
    
    -- 5x7 LED matrix scan driver
    led_matrix_inst: entity work.led_matrix_controller
    port map (
        CLOCK_50 => CLOCK_50,
        enable => SWITCH_deb(2),
        char_select => led_matrix_char,
        LedMatrix_CLK => LedMatrix_CLK,
        LedMatrix_EN => LedMatrix_EN,
        LedMatrix_Data => LedMatrix_Data,
        status_led => open
    );

    -- VGA test patterns; when disabled the outputs are held inactive
    vga_inst: entity work.vga_controller
    port map (
        CLOCK_50 => CLOCK_50,
        enable   => SWITCH_deb(1),
        mode     => vga_mode,
        rotary_value => rotary_value,
        VGA_R    => VGA_R,
        VGA_G    => VGA_G,
        VGA_B    => VGA_B,
        VGA_HS   => VGA_HS,
        VGA_VS   => VGA_VS
    );

    -- Rotary encoder decoding and encoder button debounce
    rotary_enc_inst: entity work.rotary_encoder_controller
    port map (
        CLOCK_50  => CLOCK_50,
        A         => RotaryEncoder(0),
        B         => RotaryEncoder(1),
        SW_raw    => RotaryEncoder_SW,
        SW_deb    => RotaryEncoder_SW_deb,
        value     => rotary_value,
        step_pulse=> rotary_step_pulse
    );
    
    -- Process for LED toggling and VGA mode control
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            -- Heartbeat: toggle once per counter wrap (2^25 / 50 MHz = ~0.67 s)
            counter <= counter + 1;
            if counter = 0 then
                led_blink <= not led_blink;
            end if;
            
            -- VGA mode toggle on BUTTON_deb(0) rising edge (debounced input)
            -- Cycle through: "00" -> "01" -> "10" -> "00" ...
            if BUTTON_deb(0) = '1' and button0_prev = '0' then
                case vga_mode is
                    when "00" =>
                        vga_mode <= "01";
                    when "01" =>
                        vga_mode <= "10";
                    when others =>
                        vga_mode <= "00";
                end case;
            end if;
            button0_prev <= BUTTON_deb(0);
        end if;
    end process;

    
    -- Connect debounced inputs to LEDs for testing
    LED(0) <= led_blink;             -- Heartbeat blink on LED[0]
    LED(1) <= RotaryEncoder_SW_deb;  -- Rotary encoder switch to LED[1]
        -- Connect rotary encoder A/B directly to LEDs for debugging
    --LED(0) <= RotaryEncoder(0);  -- Show encoder A on LED[0]
    --LED(1) <= RotaryEncoder(1);  -- Show encoder B on LED[1]

    led_pcb(3 downto 0) <= BUTTON_deb;        -- Buttons to first 4 PCB LEDs
    led_pcb(5 downto 4) <= SWITCH_deb(1 downto 0);  -- Switches 0-1 to PCB LEDs 4-5
    led_pcb(6) <= SWITCH_deb(2);              -- LED matrix enable status on led_pcb(6)
    led_pcb(7) <= SWITCH_deb(3);              -- Audio enable status on led_pcb(7)
    
    -- Set character to display on LED matrix (for now, use buttons to select 0-F)
    led_matrix_char <= BUTTON_deb;
end Behavioral;