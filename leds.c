#include <stdio.h>
#include <stdlib.h>

#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "ws2812.pio.h"

#define IS_RGBW true        // Will use RGBW format
#define NUM_PIXELS 1        // There is 1 WS2812 device in the chain
#define WS2812_PIN 28       // The GPIO pin that the WS2812 connected to

static inline void put_pixel(uint32_t pixel_grb) {
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}

static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b) {
    return  ((uint32_t) (r) << 8)  |
            ((uint32_t) (g) << 16) |
            (uint32_t) (b);
}

void red_LED() {
    put_pixel(urgb_u32(0x7F, 0x00, 0x00));
}

void yellow_LED() {
    put_pixel(urgb_u32(0x0F, 0x0F, 0x0F));
}

void orange_LED() {
    put_pixel(urgb_u32(0xFF, 0xA5, 0x00));
}

void green_LED() {
    put_pixel(urgb_u32(0x00 0x7F, 0x00));
}

void blue_LED() {
    put_pixel(urgb_u32(0x00, 0x00, 0x7F));
}

void off_LED() {
    put_pixel(urgb_u32(0x00, 0x00, 0x00));
}

void change_led() {
    if(game_start) {
        if(lives == 3) {
            green_LED();
        }
        if(lives == 2) {
            yellow_LED();
        }
        if(lives == 1) {
            orange_LED();
        }
        else {
            red_LED();
        }
    }
    else {
        blue_LED();
    }
}