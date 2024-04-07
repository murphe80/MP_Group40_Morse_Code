#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "hardware/watchdog.h"
#include "assign02.pio.h"
#include "hardware/pwm.h"
#include <time.h>

#define IS_RGBW true  // Using RGBW format
#define NUM_PIXELS 1  // 1 WS2812 device in the chain
#define WS2812_PIN 28 // GPIO pin that the WS2812 connected to
#define ARRAY_SIZE 173

// Declaring constants
#define MORSE_SPACE "_"
#define MAX_ENCODING_LENGTH 6
#define ALPHABET_START 'A'
#define NUM_START '0'
#define TABLE_LENGTH 36
#define ALPHABET_LENGTH 26

absolute_time_t start_time; // for alarm timer

int currIndex; // variables to store values and index of current input
char curr_input[200];
int lives_remaining = 5; // lives remaining for user
int game_start = 0;

// Defining all morse encodings for each letter
char morse_a[] = ".-";
char morse_b[] = "-...";
char morse_c[] = "-.-";
char morse_d[] = "-..";
char morse_e[] = ".";
char morse_f[] = "..-.";
char morse_g[] = "--.";
char morse_h[] = "....";
char morse_i[] = "..";
char morse_j[] = ".---";
char morse_k[] = "-.-";
char morse_l[] = ".-..";
char morse_m[] = "--";
char morse_n[] = "-.";
char morse_o[] = "---";
char morse_p[] = ".--.";
char morse_q[] = "--.-";
char morse_r[] = ".-.";
char morse_s[] = "...";
char morse_t[] = "-";
char morse_u[] = "..-";
char morse_v[] = "...-";
char morse_w[] = ".--";
char morse_x[] = "-..-";
char morse_y[] = "-.--";
char morse_z[] = "--..";

char level_0[] = "-----";
char level_1[] = ".----";
char level_2[] = "..---";
char level_3[] = "...--";
char level_4[] = "....-";
char level_5[] = ".....";
char level_6[] = "-....";
char level_7[] = "--...";
char level_8[] = "---..";
char level_9[] = "----.";

// Array of morse encodings for each letter
char *morse_table[] = {morse_a, morse_b, morse_c, morse_d,
                       morse_e, morse_f, morse_g, morse_h, morse_i, morse_j, morse_k,
                       morse_l, morse_m, morse_n, morse_o, morse_p, morse_q, morse_r,
                       morse_s, morse_t, morse_u, morse_v, morse_w, morse_x, morse_y,
                       morse_z, level_0, level_1, level_2, level_3, level_4, level_5,
                       level_6, level_7, level_8, level_9};

//function declaration 
void main_asm();
int decodeMorse(char input[], char output[]); 


// timer functions
void timer_begin()
{
    start_time = get_absolute_time();
}

// returns times elapsed of alarm interrupt when button pressed
int timer_end()
{
    int endTime = (int)absolute_time_diff_us(start_time, get_absolute_time());
    return endTime / 100000;
}

// led configurations
static inline void pixel_add(uint32_t pixel_grb)
{
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}

static inline uint32_t rgb_gen(uint8_t r, uint8_t g, uint8_t b)
{
    return ((uint32_t)(r) << 8) |
           ((uint32_t)(g) << 16) |
           (uint32_t)(b);
}

void red_LED()
{
    pixel_add(rgb_gen(0x7F, 0x00, 0x00));
}

void yellow_LED()
{
    pixel_add(rgb_gen(0x0F, 0x0F, 0x0F));
}

void orange_LED()
{
    pixel_add(rgb_gen(0xFF, 0xA5, 0x00));
}

void green_LED()
{
    pixel_add(rgb_gen(0x00, 0x7F, 0x00));
}


void blue_LED()
{
    pixel_add(rgb_gen(0x00, 0x00, 0x7F));
}

void off_LED()
{
    pixel_add(rgb_gen(0x00, 0x00, 0x00));
}

void change_led()
{
    if (game_start)
    {
        if (lives_remaining == 3)
        {
            green_LED();
        }
        if (lives_remaining == 2)
        {
            yellow_LED();
        }
        if (lives_remaining == 1)
        {
            orange_LED();
        }
        else
        {
            red_LED();
        }
    }
    else
    {
        blue_LED();
    }
}

int welcomeMessage()
{
    // Print welcome message
    printf("\n\n");
    printf("**********************************************************\n\n");
    printf("Welcome to Group 40's Morse Code Educator!\n\n");
    printf("How to play: \n");
    printf("Start the game by inputting the morse code for level 1 or level 2\n\n");
    printf("Level 1 = Character and Morse code provided\n");
    printf("Level 2 = Character but no Morse code provided\n\n");
    printf("Next, you will be presented with an alphaneumeric character\n");
    printf("Your task is to correctly input the morse code for that character using the middle button.\n\n");
    printf("If your input is correct, the LED will flash green\n");
    printf("If your input is incorrect, the LED will flash yellow\n");
    printf("You start with 3 lives, and when your lives reach 0, the LED will flash red\n");
    printf("To progress to the next level, you need to input 5 fully correct sequences\n");
    printf("Once all levels are complete, you have won the game!\n\n");

    printf("To input your answer, press the button quickly for * and hold for one second for -\n");
    printf("To Start the game on level 1, enter .----\n");
    printf("To start the game on level 2, enter ..---\n\n");
    printf("**********************************************************\n");
    printf("Enter level: \n");
    return 0;
}

int GameOverMessage()
{
    printf("**********************************************************\n\n");
    printf("GAME OVER!\n");
    printf("**********************************************************\n");
    return 0;
}

int YouWinMessage()
{
    printf("**********************************************************\n\n");
    printf("YOU WIN!\n");
    printf("**********************************************************\n");
    return 0;
}

//returns 1 for a correct result and 0 for an incorrect input
int level1_game()
{
    // Display character at random
    int random_index = rand() % TABLE_LENGTH;
    char *rand_character = morse_table[random_index];
    char decoded[4096] = "";
    // decode string
    if (decodeMorse(rand_character, decoded) == 0)
    {
        printf("Write the equivalent morse code for the character '%s'\n", decoded);
        printf("The morse code for the above character is %s\n\n", rand_character);
    }

    // wait for entire input
    currIndex = -1; // resetting index
    main_asm();
    char decode_input[200] = "";
    // check if input is correct
    if (decodeMorse(curr_input, decode_input) == 0)
    {
        if (strcmp(decode_input, decoded) == 0)
        {
            printf("Well done, that is correct!\n");
            return 1;
        }
    }
    else
    {
        printf("Incorrect, the answer was %s\n", decoded);
        return 0;
    }
    return 0;
}

//returns 1 for a correct result and 0 for an incorrect input 
int level2_game()
{
    // Display character at random
    int random_index = rand() % TABLE_LENGTH;
    char *rand_character = morse_table[random_index];
    char decoded[4096] = "";
    // decode string
    if (decodeMorse(rand_character, decoded) == 0)
    {
        printf("Write the equivalent morse code for the character '%s'\n", decoded);
    }

    // await input from buttons
    currIndex = -1; // resetting index
    main_asm();

    char decode_input[4096] = "";
    // check if input is correct
    if (decodeMorse(curr_input, decode_input) == 0 && strcmp(decoded, decode_input))
    {
        if (strcmp(decode_input, decoded) == 0)
        {
            printf("Well done, that is correct!\n");
            return 1;
        }
    }
    else
    {
        printf("Incorrect, the answer was %s\n", decoded);
        return 0;
    }
    return 0;
}

// decodes the inputted morse code, if valid return 1, else return 0
int decodeMorse(char input[], char output[])
{
    int inputIndex = 0;

    // iterate through string
    while (input[inputIndex] != '\0')
    {
        // store current encoding in variable
        char currEncoding[MAX_ENCODING_LENGTH] = "";
        // Storing encoding in variable
        while (input[inputIndex] != ' ' && input[inputIndex] != '\0')
        {
            // appending character of input to current encoding string
            currEncoding[strlen(currEncoding)] = input[inputIndex];
            inputIndex++;
        }
        // Increment inputIndex if not the end of the encoding
        if (input[inputIndex] == ' ')
            inputIndex++;
        currEncoding[strlen(currEncoding)] = '\0';

        // checking if a space
        if (strcmp(currEncoding, MORSE_SPACE) == 0)
        {
            output[strlen(output)] = ' ';
        }
        else
        {
            // find corresponding array index using encoded string
            int encodingIndex = 0;
            while (strcmp(morse_table[encodingIndex], currEncoding) != 0)
            {
                encodingIndex++;
                // error checking inputted encoding
                if (encodingIndex >= TABLE_LENGTH)
                {
                    printf("No such morse code exists\n");
                    return -1;
                }
            }
            // translate to ASCII equivalent
            if (encodingIndex < ALPHABET_LENGTH)
            {
                int decodedChar = encodingIndex + ALPHABET_START;
                output[strlen(output)] = decodedChar;
            }
            // else it must a number
            else
            {
                int decodedLevel = encodingIndex - ALPHABET_LENGTH + NUM_START;
                output[strlen(output)] = decodedLevel;
            }
        }
    }
    // null terminate the string
    output[strlen(output)] = '\0';
    return 0;
}

// adds a morse character to the current user's input
// 0 is for a dot, 1 is for a dash and 3 is for null character

void add_to_input(int character, int index)
{
    currIndex = currIndex - index;
    if (currIndex < 200)
    {
        if (character == 0)
        {
            curr_input[currIndex] = '.';
        }
        else if (character == 1)
        {
            curr_input[currIndex] = '-';
        }
        else if (character == 2)
        {
            curr_input[currIndex] = ' ';
        }

        else if (character == 3)
        {
            curr_input[currIndex] = '\0';
        }
        
    }
    currIndex++;
    if (index)
    {
        printf("\b%c", curr_input[currIndex - 1]);
    }
    else
        printf("%c", curr_input[currIndex - 1]);
}



void time_start(){
    start_time = get_absolute_time();
}


// Initialise a GPIO pin

void asm_gpio_init(uint pin)
{
    gpio_init(pin);
}

// Set direction of a GPIO pin

void asm_gpio_set_dir(uint pin, bool out)
{
    gpio_set_dir(pin, out);
}

// Get the value of a GPIO pin

bool asm_gpio_get(uint pin)
{
    return gpio_get(pin);
}

// Set the value of a GPIO pin

void asm_gpio_put(uint pin, bool value)
{
    gpio_put(pin, value);
}
// Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
void asm_gpio_set_irq(uint pin) {
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL, true);
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_RISE, true);
}



void play_morse()
{
    game_start = 1;
    change_led();
    // resetting input array and index
    currIndex = -1;
    main_asm(); // calling assembly program
    char decoded_level[200];
    // call decode function on input given by user
    int valid_level = decodeMorse(curr_input, decoded_level);

    if (valid_level == 0)
    {

        if ((int)'1' == (int)decoded_level[0])
        {

            printf("\nYou have selected level 1!\n\n");
            printf("At this level, characters with their equivalent morse code is provided. \n");
            // while lives left, repeat
            int game_number = 0;
            while (lives_remaining > 0 && game_number < 5)
            {
                int correct_answer = level1_game();
                if (!correct_answer)
                    lives_remaining--;
                game_number++;
                change_led();
            }
            if (lives_remaining > 0)
            {
                printf("**********************************************************\n");
                printf("Congratulations, you have progressed to level 2!\n\n");

                game_number = 0;
                while (lives_remaining > 0 && game_number < 5)
                {
                    int correct_answer = level2_game();
                    if (!correct_answer)
                        lives_remaining--;
                    game_number++;
                    change_led();
                }
            }
            if (lives_remaining > 0)
                YouWinMessage();
            else
                GameOverMessage();
        }

        else if ((int)'2' == (int)decoded_level[0])
        {
            change_led();
            printf("\nYou have selected level 2!\n\n");
            printf("At this level, characters without their equivalent morse code is provided. \n");
            // while lives left, repeat
            int game_number = 0;
            while (lives_remaining > 0 && game_number < 5)
            {
                int correct_answer = level2_game();
                if (!correct_answer)
                    lives_remaining--;
                game_number++;
                change_led();
            }
            if (lives_remaining > 0)
                YouWinMessage();
            else
                game_start = 0;
            GameOverMessage();
        }
    }
    else
    {
        printf("Error: Invalid level selected! Program Exiting\n");
        game_start = 0;
        change_led();
    }
}

// Main entry point of the application
int main()
{
    stdio_init_all(); // Initialise all basic IO

    PIO pio = pio0;
    uint offset = pio_add_program(pio, &ws2812_program);
    ws2812_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);
    watchdog_enable(0x7fffff, 1);
    // Print welcome message
    welcomeMessage();

    // call learn morse program
    play_morse();
}


