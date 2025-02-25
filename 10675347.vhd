library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.ALL;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;--segnale di CLOCK in ingresso generato dal TestBench
        i_rst : in std_logic;--segnale di RESET che inizializza la macchina pronta per ricevere il primo segnale di START
        i_start : in std_logic;--segnale di START generato dal Test Bench
        i_data : in std_logic_vector(7 downto 0);--segnale (vettore) che arriva dalla memoria in seguito ad una richiesta di lettura
        o_address : out std_logic_vector(15 downto 0);--segnale (vettore) di uscita che manda l'indirizzo alla memoria;
        o_done : out std_logic;--segnale di uscita che comunica la fine dell'elaborazione e il dato di uscita scritto in memoria
        o_en : out std_logic;--segnale di ENABLE da dover mandare alla memoria per poter comunicare (sia in lettura che in scrittura)
        o_we : out std_logic;--segnale di WRITE ENABLE da dover mandare alla memoria (=1) per poter scriverci. Per leggere da memoria esso deve essere 0
        o_data : out std_logic_vector (7 downto 0) --segnale (vettore) di uscita dal componente verso la memoria
    );
end project_reti_logiche;

architecture architettura of project_reti_logiche is

    type status_type is (WAIT_CLOCK, PRE_READ_0, READ_0, READ_1, MIN_MAX_SHIFT, PRE_SHIFTING, SHIFTING, DONE);
    signal status : status_type;

begin
    process(i_clk, i_rst)
        variable nxt: status_type;
        variable totalPixel: integer range 0 to 16384;

        variable minimum: std_logic_vector(7 downto 0);
        variable maximum: std_logic_vector(7 downto 0);
        variable delta: integer range 0 to 255;
        
        variable shift: integer range 0 to 8;
        variable i: integer range 0 to 8;
        variable exceed: boolean;

        variable address: std_logic_vector(15 downto 0);
        variable addressShifted: std_logic_vector(15 downto 0);
        
        variable temp: std_logic_vector(8 downto 0);

    begin
        if (i_rst = '1') then 
            status <= PRE_READ_0;
        end if;

        if(i_clk'event and i_clk = '1') then
            case status is
                
                when WAIT_CLOCK => 
                status <= nxt;

                when PRE_READ_0 =>
                    --prepare READ_0
                    o_done <= '0';
                    if(i_start = '1') then
                        o_we <= '0';
                        o_en <= '1';
                        o_address <= "0000000000000000";
                        nxt := READ_0;
                        status <= WAIT_CLOCK;
                    end if;
                
                when READ_0 =>
                    --READ_0
                    totalPixel := conv_integer(i_data);
                    --prepare Read_1
                    o_address <= "0000000000000001";
                    nxt := READ_1;
                    status <= WAIT_CLOCK;

                when READ_1 =>
                    --READ_1
                    totalPixel := totalPixel * conv_integer(i_data);
                    --prepare MIN_MAX_SHIFT
                    minimum := "11111111";
                    maximum := "00000000";
                    address := "0000000000000010";
                    o_address <= address;
                    nxt := MIN_MAX_SHIFT;
                    status <= WAIT_CLOCK;

                when MIN_MAX_SHIFT =>
                    --MIN_MAX
                    if(CONV_INTEGER(address) /= totalPixel+2) then
                        if(i_data > maximum) then 
                            maximum := i_data;
                        end if;
                        if(i_data < minimum) then 
                            minimum := i_data;
                        end if;
                        address := address +1;
                        o_address <= address;
                        --MIN_MAX (next pixel)
                        status <= WAIT_CLOCK;
                    else
                        --SHIFT
                        delta:= conv_integer(maximum-minimum);
                        if(delta = 0) then shift:= 8;-- 0
                        elsif(delta < 3) then shift:= 7;-- 1-2
                        elsif(delta < 7) then shift:= 6;-- 3-6
                        elsif(delta < 15) then shift:= 5;-- 7-14
                        elsif(delta < 31) then shift:= 4;-- 15-30
                        elsif(delta < 64) then shift:= 3;-- 31-62
                        elsif(delta < 127) then shift:= 2;-- 63-126
                        elsif(delta < 255) then shift:= 1;-- 127-254
                        else shift:= 0;--255
                        end if;
                        --setup PRE_SHIFTING
                        addressShifted := address -1;
                        address := "0000000000000001";
                        o_address <= address;
                        status <= PRE_SHIFTING;
                    end if;

                when PRE_SHIFTING =>
                    --PRE_SHIFTING
                    o_we <= '0';
                    address := address + 1;
                    addressShifted := addressShifted + 1;
                    o_address <= address;
                    nxt := SHIFTING;
                    status <= WAIT_CLOCK;
                
                when SHIFTING =>
                    if(CONV_INTEGER(address) /= totalPixel+2) then
                        -- SHIFTING
                        temp:= "0" & (i_data - minimum);
                        exceed := false;

                        i := 0;
                        while(i < shift) loop
                            if(temp(7 downto 7) = "1")then
                                exceed:=true;
                                exit;
                            else
                                temp := temp(7 downto 0) & '0';
                            end if;
                            i := i + 1;
                        end loop;
                        
                        if(exceed) then
                            o_data <= "11111111";
                        else
                            o_data <= temp(7 downto 0);
                        end if;
                        
                        o_we <= '1';
                        o_address <= addressShifted;
                        status <= PRE_SHIFTING;
                    else
                        --DONE
                        status <= DONE;
                    end if;

                when DONE =>
                    --DONE
                    o_done <= '1';
                    --WAIT FOR RESTART
                    if(i_start = '0') then status <= PRE_READ_0;
                    end if;

            end case;
        end if;
    end process;
end architettura;
