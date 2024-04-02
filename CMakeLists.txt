# Specify the name of the executable.
add_executable(MP_Group40_Morse_Code)

# Specify the source files to be compiled.
target_sources(MP_Group40_Morse_Code PRIVATE morse.c morse.S morse.pio)

# Generating the PIO header file from the PIO source file.
pico_generate_pio_header(MP_Group40_Morse_Code ${CMAKE_CURRENT_LIST_DIR}/morse.pio)

# Pull in commonly used features.
target_link_libraries(MP_Group40_Morse_Code PRIVATE pico_stdlib hardware_pio hardware_pwm)

# Create map/bin/hex file etc.
pico_add_extra_outputs(MP_Group40_Morse_Code)

# Add the URL via pico_set_program_url.
apps_auto_set_url(MP_Group40_Morse_Code)
