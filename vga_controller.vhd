-- VGA timing core (800x600 @ 72 Hz counters and sync generation) based on
-- example code by my thesis mentor A. Trost (Faculty of Electrical
-- Engineering, University of Ljubljana). Enable logic, test patterns and
-- RGB outputs added by Tomaz Perme.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_controller is
    Port (
        CLOCK_50 : in  std_logic;
        enable   : in  std_logic;  -- When '0', VGA logic is stopped and outputs are inactive
        mode     : in  std_logic_vector(1 downto 0);  -- "00"=diagonal, "01"=window, "10"=rotary bar

        -- Rotary encoder value for debug display (0..15)
        rotary_value : in unsigned(3 downto 0);

        VGA_R    : out std_logic_vector(3 downto 0);
        VGA_G    : out std_logic_vector(3 downto 0);
        VGA_B    : out std_logic_vector(3 downto 0);
        VGA_HS   : out std_logic;
        VGA_VS   : out std_logic
    );
end vga_controller;

architecture Behavioral of vga_controller is

    -- Horizontal/vertical counters
    signal hst, vst : unsigned(11 downto 0) := (others => '0');

    -- VGA timing constants for 800x600 @ 72 Hz (from original VGA.vhd)
    constant H  : integer := 1040; -- total horizontal
    constant Hf : integer := 856;  -- start of horiz sync
    constant Hs : integer := 120;  -- horiz sync width

    constant V  : integer := 666;  -- total vertical
    constant Vf : integer := 637;  -- start of vert sync
    constant Vs : integer := 6;    -- vert sync width

    signal hsync_int, vsync_int : std_logic := '0';

    -- Internal color
    signal r_int, g_int, b_int : std_logic_vector(3 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------
    -- VGA timing: horizontal / vertical counters
    -- When enable = '0', counters are held/reset to zero (logic "stopped")
    --------------------------------------------------------------------
    process (CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            if enable = '1' then
                if hst = H - 1 then
                    hst <= (others => '0');
                    if vst = V - 1 then
                        vst <= (others => '0');
                    else
                        vst <= vst + 1;
                    end if;
                else
                    hst <= hst + 1;
                end if;
            else
                -- Disabled: hold counters at zero
                hst <= (others => '0');
                vst <= (others => '0');
            end if;
        end if;
    end process;

    -- Sync pulses (only meaningful when enabled)
    hsync_int <= '1' when (hst >= Hf and hst < Hf + Hs) else '0';
    vsync_int <= '1' when (vst >= Vf and vst < Vf + Vs) else '0';

    VGA_HS <= hsync_int when enable = '1' else '0';
    VGA_VS <= vsync_int when enable = '1' else '0';

    --------------------------------------------------------------------
    -- Pattern color generation (on 800x600 active area)
    -- mode = "00" : diagonal split
    -- mode = "01" : 400x400 window in top-left
    -- mode = "10" : rotary bar graph (width proportional to rotary_value)
    -- When enable = '0', RGB outputs are forced to black
    --------------------------------------------------------------------
    process (hst, vst, enable, mode, rotary_value)
        variable x : unsigned(11 downto 0);
        variable y : unsigned(11 downto 0);
        variable bar_limit : unsigned(11 downto 0);
    begin
        -- default black
        r_int <= (others => '0');
        g_int <= (others => '0');
        b_int <= (others => '0');

        if enable = '1' then
            x := hst;
            y := vst;

            -- Only inside visible 800x600
            if (x < 800) and (y < 600) then
                case mode is
                    when "00" =>
                        -- Diagonal: y * 4 < x * 3  (~ y < 0.75 * x)
                        if (y * 4) < (x * 3) then
                            -- Color A (green-ish)
                            r_int <= "0000";
                            g_int <= "1111";
                            b_int <= "0000";
                        else
                            -- Color B (magenta-ish)
                            r_int <= "1111";
                            g_int <= "0000";
                            b_int <= "1111";
                        end if;

                    when "01" =>
                        -- Window pattern: 400x400 in top-left uses blue; rest yellow
                        if (x < 400) and (y < 400) then
                            r_int <= "0000";
                            g_int <= "0000";
                            b_int <= "1111";  -- blue
                        else
                            r_int <= "1111";
                            g_int <= "1111";
                            b_int <= "0000";  -- yellow
                        end if;

                    when "10" =>
                        -- Rotary bar mode: blue bar on purple background.
                        -- Width = rotary_value * 50 + 25 px (25..775): one
                        -- 50 px segment per step, still visible at zero.
                        bar_limit := to_unsigned(((to_integer(rotary_value) * 50) + 25), bar_limit'length);

                        -- Background color (purple)
                        r_int <= "1111";    
                        g_int <= "0000";
                        b_int <= "1111";

                        -- Bar area in blue
                        if x < bar_limit then
                            r_int <= "0000";
                            g_int <= "0000";
                            b_int <= "1111";
                        end if;

                    when others =>
                        -- Default: keep black inside active area
                        null;
                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Drive outputs
    --------------------------------------------------------------------
    VGA_R <= r_int;
    VGA_G <= g_int;
    VGA_B <= b_int;

end Behavioral;


