*** Settings ***
Suite Setup			Setup
Suite Teardown			Teardown
Test Setup			Reset And Boot Target Chip
Test Teardown			Stop Code Coverage and Pause
Resource			${RENODEKEYWORDS}

*** Variables ***
${UART_PERIPHERAL}        sysbus.usart2
${DEFAULT_UART_TIMEOUT}   10.0
${PI_VALUE}               3.141592653589793
${MAX_RPM}                ${{1.0 / 155.0}}
${WHEEL_DIA}              1
${SPEED_SCALE}            0.085
${ARR_VALUE}              4094

*** Keywords ***
Reset And Boot Target Chip
  [Documentation]  Wipes the state. Loads a new Board.
  Reset Emulation
  Execute Command  emulation CreateCANHub "can_network"
  Execute Command  mach create "STM32F446"
  Execute Command  machine LoadPlatformDescription @/data/Simulation/STM32F446RETx.repl
  Execute Command  sysbus LoadELF @/data/build/PWM_Test
  Execute Command  connector Connect sysbus.can1 can_network
  Execute Command  sysbus WriteDoubleWord 0x40006404 0x00000001
  Execute Command  sysbus WriteDoubleWord 0x40006400 0x0000000
  Execute Command  python "self.Machine['sysbus.can1'].WriteDoubleWord(0x14, 0x2)"
  Execute Command  python "self.Machine['sysbus.can1'].UpdateFifo0InterruptLine()"
  Create Terminal Tester  ${UART_PERIPHERAL}  timeout=10  defaultPauseEmulation=False
  ${safe_name}=      Evaluate    "${TEST_NAME}".replace(" ", "_")
  # Execute Command    sysbus.cpu CreateExecutionTracing "test_tracer" @/data/traces/${safe_name}.bin.gz PC true true  
  Execute Command    emulation SetAdvanceImmediately false

Stop Code Coverage and Pause
  [Documentation]  Stop the Code Coverage and Pauses the Board
  Execute Command    sysbus.cpu Pause
  # Execute Command    sysbus.cpu DisableExecutionTracing
  Execute Command    Clear
  
Motor Has Updated
    [Arguments]     ${addr}     ${timer}     ${exp_ccr}      ${exp_duty}
    
    ${limit}=      Execute Command     ${timer} Limit
    ${raw_val}=    Execute Command     sysbus ReadDoubleWord ${addr}
    
    ${int_val}=    Evaluate            int("""${raw_val}""".strip(), 16)
    Should Be Equal As Integers    ${int_val}     ${exp_ccr}  
    
Led Has Updated
    [Arguments]     ${led}     ${exp_val}
    
    ${raw_val}=    Execute Command     ${led} State
    ${int_val}=    Evaluate            int(${raw_val})
    
    Should Be Equal As Integers    ${int_val}     ${exp_val}
    
Verify Motor Function Angular Velocity
    [Arguments]    ${left_velo}    ${right_velo}     ${reserved}    ${message_cout}     ${crc}
    
    # Caclulate Expected Values
    ${m1}=    Evaluate    (((int(${left_velo}) & 0xFFFF) * 0.125) - 4016.0)
    ${m3}=    Evaluate    (((int(${left_velo}) & 0xFFFF) * 0.125) - 4016.0)
    ${m2}=    Evaluate    (((int(${right_velo}) & 0xFFFF) * 0.125) - 4016.0)
    ${m4}=    Evaluate    (((int(${right_velo}) & 0xFFFF) * 0.125) - 4016.0)
    
    # Caclulate Expected Values
    ${motor1_speed}=       Evaluate       abs(${m1} * ${MAX_RPM} * 4096.0 )
    ${motor2_speed}=       Evaluate       abs(${m2} * ${MAX_RPM} * 4096.0 )
    ${motor3_speed}=       Evaluate       abs(${m3} * ${MAX_RPM} * 4096.0 )
    ${motor4_speed}=       Evaluate       abs(${m4} * ${MAX_RPM} * 4096.0 )
    
    ${motor1_speed}=       Evaluate       32767 if (${motor1_speed} > 32767) else ${motor1_speed}
    ${motor2_speed}=       Evaluate       32767 if (${motor2_speed} > 32767) else ${motor2_speed}
    ${motor3_speed}=       Evaluate       32767 if (${motor3_speed} > 32767) else ${motor3_speed}
    ${motor4_speed}=       Evaluate       32767 if (${motor4_speed} > 32767) else ${motor4_speed}
    
    ${exp_ccr1_raw}=       Evaluate       0 if (abs(float(${motor1_speed})) < 204.75) else int(float(${motor1_speed}))
    ${exp_ccr2_raw}=       Evaluate       0 if (abs(float(${motor2_speed})) < 204.75) else int(float(${motor2_speed}))
    ${exp_ccr3_raw}=       Evaluate       0 if (abs(float(${motor3_speed})) < 204.75) else int(float(${motor3_speed}))
    ${exp_ccr4_raw}=       Evaluate       0 if (abs(float(${motor4_speed})) < 204.75) else int(float(${motor4_speed}))
    
    # Set Exp Output Direction
    ${motor1_dir}=         Evaluate       0 if(${m1} < 0.0) else 1
    ${motor2_dir}=         Evaluate       1 if(${m2} < 0.0) else 0
    ${motor3_dir}=         Evaluate       0 if(${m3} < 0.0) else 1
    ${motor4_dir}=         Evaluate       1 if(${m4} < 0.0) else 0
    
    ${motor1_dir}=         Evaluate       0 if(float(${motor1_speed}) < 204.75) else ${motor1_dir}
    ${motor2_dir}=         Evaluate       0 if(float(${motor2_speed}) < 204.75) else ${motor2_dir}
    ${motor3_dir}=         Evaluate       0 if(float(${motor3_speed}) < 204.75) else ${motor3_dir}
    ${motor4_dir}=         Evaluate       0 if(float(${motor4_speed}) < 204.75) else ${motor4_dir}
    
    # Set Exp Output CCR and Duty
    ${exp_ccr1}=            Evaluate       abs(${exp_ccr1_raw})
    ${exp_ccr2}=            Evaluate       abs(${exp_ccr2_raw})
    ${exp_ccr3}=            Evaluate       abs(${exp_ccr3_raw})
    ${exp_ccr4}=            Evaluate       abs(${exp_ccr4_raw})
    
    ${exp_duty1}=           Evaluate       (float(${exp_ccr1}) / float(${ARR_VALUE}) * 100)
    ${exp_duty2}=           Evaluate       (float(${exp_ccr2}) / float(${ARR_VALUE}) * 100)
    ${exp_duty3}=           Evaluate       (float(${exp_ccr3}) / float(${ARR_VALUE}) * 100)
    ${exp_duty4}=           Evaluate       (float(${exp_ccr4}) / float(${ARR_VALUE}) * 100)
    
    # Get Bytes Splits For CAN Msg
    ${lef_int}=             Evaluate       int(float(${left_velo})) & 0xFFFF
    ${rig_int}=             Evaluate       int(float(${right_velo})) & 0xFFFF
    ${rev_int}=             Evaluate       int(float(${reserved})) & 0xFFFF
    ${count_int}=           Evaluate       int(float(${message_cout})) & 0xFF
    ${crc_int}=             Evaluate       int(float(${crc})) & 0xFF

    ${msb_1}=              Evaluate       (${lef_int} >> 8) & 0xFF
    ${lsb_1}=              Evaluate       ${lef_int} & 0xFF
    
    ${msb_2}=              Evaluate       (${rig_int} >> 8) & 0xFF
    ${lsb_2}=              Evaluate       ${rig_int} & 0xFF

    ${msb_3}=              Evaluate       (${rev_int} >> 8) & 0xFF
    ${lsb_3}=              Evaluate       ${rev_int} & 0xFF

    ${msb_4}=              Evaluate       ${crc_int} & 0xFF
    ${lsb_4}=              Evaluate       ${count_int} & 0xFF
  
    ${msb_1_hex}=          Evaluate       f"0x{${msb_1}:02X}"
    ${lsb_1_hex}=          Evaluate       f"0x{${lsb_1}:02X}"
    ${msb_2_hex}=          Evaluate       f"0x{${msb_2}:02X}"
    ${lsb_2_hex}=          Evaluate       f"0x{${lsb_2}:02X}"
    ${msb_3_hex}=          Evaluate       f"0x{${msb_3}:02X}"
    ${lsb_3_hex}=          Evaluate       f"0x{${lsb_3}:02X}"
    ${msb_4_hex}=          Evaluate       f"0x{${msb_4}:02X}"
    ${lsb_4_hex}=          Evaluate       f"0x{${lsb_4}:02X}"
    
    # Send CAN Message To STM Board
    Execute Command        python "import System; bytes_data = System.Array[System.Byte]([${lsb_1_hex}, ${msb_1_hex}, ${lsb_2_hex}, ${msb_2_hex}, ${lsb_3_hex}, ${msb_3_hex}, ${lsb_4_hex}, ${msb_4_hex}]); print(bytes_data); frame = Antmicro.Renode.Core.CAN.CANMessageFrame(16771456, bytes_data, True); msg = Antmicro.Renode.Peripherals.CAN.STMCAN.CANMessage(frame); self.Machine['sysbus.can1'].ReceiveCANMessage(msg)"
    
    # Wait for registry to update before checking values with a max of 1 second of waiting
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Motor Has Updated    0x40000034     sysbus.timer2    ${exp_ccr1}     ${exp_duty1}
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Motor Has Updated    0x40000038     sysbus.timer2    ${exp_ccr2}     ${exp_duty2}
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Motor Has Updated    0x4000003C     sysbus.timer2    ${exp_ccr3}     ${exp_duty3}
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Motor Has Updated    0x40000040     sysbus.timer2    ${exp_ccr4}     ${exp_duty4}
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Led Has Updated      gpioPortA.led_m1p1     ${motor1_dir}
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Led Has Updated      gpioPortB.led_m2p1     ${motor2_dir}
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Led Has Updated      gpioPortB.led_m3p1     ${motor3_dir}
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Led Has Updated      gpioPortB.led_m4p1     ${motor4_dir}
    
*** Test Cases ***

Scenario 0.0: Engineering Zero
    [Documentation]    Verifies angular velocity decodes to exactly zero.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    
Scenario 0.1: Both Zero
    [Documentation]    Verifies both angular velocity channels decode and process zero correctly.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  0  0  0  0

Scenario 0.2: Both Positive Nominal
    [Documentation]    Verifies nominal positive angular velocity values on both channels.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  1500  1500  0  0  0

Scenario 0.3: Both Negative Nominal
    [Documentation]    Verifies nominal negative angular velocity values on both channels.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -1500  -1500  0  0  0

Scenario 0.4: Left Positive Right Negative
    [Documentation]    Verifies mixed-sign operation with left positive and right negative.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  1500  -1500  0  0  0

Scenario 0.5: Left Negative Right Positive
    [Documentation]    Verifies mixed-sign operation with left negative and right positive.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -1500  1500  0  0  0

Scenario 0.6: Positive One
    [Documentation]    Verifies handling of minimum positive non-zero values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  1  1  0  0  0

Scenario 0.7: Negative One
    [Documentation]    Verifies handling of minimum negative non-zero values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -1  -1  0  0  0

Scenario 0.8: Positive Two
    [Documentation]    Verifies small positive values above the minimum non-zero boundary.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  2  2  0  0  0

Scenario 0.9: Negative Two
    [Documentation]    Verifies small negative values above the minimum non-zero boundary.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -2  -2  0  0  0

Scenario 0.10: Int16 Maximum
    [Documentation]    Verifies processing of maximum signed 16-bit value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32767  32767  0  0  0

Scenario 0.11: Int16 Minimum
    [Documentation]    Verifies processing of minimum signed 16-bit value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -32768  -32768  0  0  0

Scenario 0.12: Mixed Int16 Extremes
    [Documentation]    Verifies minimum and maximum signed 16-bit values in a single frame.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -32768  32767  0  0  0

Scenario 0.13: Mixed Int16 Extremes Reversed
    [Documentation]    Verifies maximum and minimum signed 16-bit values in reversed order.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32767  -32768  0  0  0

Scenario 0.14: Random Values A
    [Documentation]    Verifies decoding of arbitrary positive values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  123  456  0  0  0

Scenario 0.15: Random Values B
    [Documentation]    Verifies decoding of arbitrary negative values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -123  -456  0  0  0

Scenario 0.16: Random Values C
    [Documentation]    Verifies mixed positive and negative arbitrary values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  123  -456  0  0  0

Scenario 0.17: Random Values D
    [Documentation]    Verifies mixed negative and positive arbitrary values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -456  123  0  0  0

Scenario 0.18: Mid Scale
    [Documentation]    Verifies operation near mid-scale positive values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  16384  16384  0  0  0

Scenario 0.19: Mid Scale Negative
    [Documentation]    Verifies operation near mid-scale negative values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -16384  -16384  0  0  0

Scenario 0.20: Adjacent Zero Crossing
    [Documentation]    Verifies behavior immediately across the signed zero boundary.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -1  1  0  0  0

Scenario 0.21: Large Positive Difference
    [Documentation]    Verifies handling of large positive magnitude differences between channels.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32767  1  0  0  0

Scenario 0.22: Large Negative Difference
    [Documentation]    Verifies handling of large negative magnitude differences between channels.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -32768  -1  0  0  0

Scenario 0.23: One Side Zero
    [Documentation]    Verifies left channel idle while right channel is active.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  1500  0  0  0

Scenario 0.24: Other Side Zero
    [Documentation]    Verifies right channel idle while left channel is active.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  1500  0  0  0  0

Scenario 0.25: Extreme Mixed
    [Documentation]    Verifies maximum positive and negative values simultaneously.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  -32768  32767  0  0  0

Scenario 0.26: Random Extremes
    [Documentation]    Verifies scaling and decoding across a broad operating range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  24576  -8192  0  0  0

Scenario 0.27: Invalid Below Valid Range
    [Documentation]    Verifies handling of angular velocity values immediately below valid protocol range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32127  32127  0  0  0

Scenario 0.28: Invalid Above Valid Range
    [Documentation]    Verifies handling of angular velocity values immediately above valid protocol range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64256  64256  0  0  0

Scenario 0.29: Maximum Uint16
    [Documentation]    Verifies handling of maximum possible encoded value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  65535  65535  0  0  0

Scenario 0.30: Minimum Uint16
    [Documentation]    Verifies handling of minimum possible encoded value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  0  0  0  0

Scenario 0.31: Mixed Valid Invalid High
    [Documentation]    Verifies one valid channel and one invalid maximum channel.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  65535  0  0  0

Scenario 0.32: Mixed Valid Invalid Low
    [Documentation]    Verifies one valid channel and one invalid minimum channel.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  0  0  0  0

Scenario 0.33: Engineering Zero Left Maximum Right
    [Documentation]    Verifies extreme legal operating range across channels.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  64255  0  0  0

Scenario 0.34: Engineering Maximum Left Zero Right
    [Documentation]    Verifies extreme legal operating range across channels reversed.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  32128  0  0  0

Scenario 0.35: Reserved Field All Ones
    [Documentation]    Verifies reserved field does not affect motor command processing.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  65535  0  0

Scenario 0.36: Message Counter Maximum
    [Documentation]    Verifies maximum message counter value does not affect decoding.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0  255  0

Scenario 0.37: CRC Maximum
    [Documentation]    Verifies maximum CRC byte does not affect decoding.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0  0  255

Scenario 0.38: All Auxiliary Fields Maximum
    [Documentation]    Verifies all auxiliary fields set to their maximum values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  65535  255  255

Scenario 0.39: Lower Valid Boundary Pair
    [Documentation]    Verifies operation exactly at the minimum valid encoded value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  32128  65535  255  255

Scenario 0.40: Upper Valid Boundary Pair
    [Documentation]    Verifies operation exactly at the maximum valid encoded value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  64255  65535  255  255

Scenario 0.41: Lower Plus One Boundary
    [Documentation]    Verifies operation one count above minimum valid encoded value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32129  32129  0  0  0

Scenario 0.42: Upper Minus One Boundary
    [Documentation]    Verifies operation one count below maximum valid encoded value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64254  64254  0  0  0

Scenario 0.43: Mid Scale Pair
    [Documentation]    Verifies operation near the middle of the valid encoded range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  48191  48191  0  0  0

Scenario 0.44: Random Valid Pair A
    [Documentation]    Verifies arbitrary values within protocol limits.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  43890  52712  0  0  0

Scenario 0.45: Random Valid Pair B
    [Documentation]    Verifies arbitrary values within protocol limits.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  35100  61000  0  0  0

Scenario 0.46: Random Valid Pair C
    [Documentation]    Verifies arbitrary values within protocol limits.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40001  50001  0  0  0

Scenario 0.47: Random Valid Pair D
    [Documentation]    Verifies arbitrary values within protocol limits.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  50000  32128  0  0  0

Scenario 0.48: Alternating Min Max
    [Documentation]    Verifies rapid transition between protocol boundaries.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  64255  0  0  0
    Verify Motor Function Angular Velocity  64255  32128  0  0  0

Scenario 0.49: Repeated Engineering Zero
    [Documentation]    Verifies repeated zero-speed command processing.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    Verify Motor Function Angular Velocity  32128  32128  0  0  0

Scenario 0.50: Repeated Maximum Velocity
    [Documentation]    Verifies repeated maximum-speed command processing.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  64255  0  0  0
    Verify Motor Function Angular Velocity  64255  64255  0  0  0
    Verify Motor Function Angular Velocity  64255  64255  0  0  0

Scenario 0.51: Lower Boundary Walk
    [Documentation]    Verifies transition into the valid protocol range and catches off-by-one validation errors.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32127  32127  0  0  0
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    Verify Motor Function Angular Velocity  32129  32129  0  0  0

Scenario 0.52: Upper Boundary Walk
    [Documentation]    Verifies transition out of the valid protocol range and catches off-by-one validation errors.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64254  64254  0  0  0
    Verify Motor Function Angular Velocity  64255  64255  0  0  0
    Verify Motor Function Angular Velocity  64256  64256  0  0  0

Scenario 0.53: Invalid Then Valid Recovery
    [Documentation]    Verifies the controller recovers correctly after receiving an invalid command.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  65535  65535  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  0

Scenario 0.54: Valid Invalid Valid Sequence
    [Documentation]    Verifies invalid packets do not corrupt subsequent valid commands.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Verify Motor Function Angular Velocity  0  0  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  0

Scenario 0.55: Left Invalid Right Valid
    [Documentation]    Verifies handling when only the left channel contains an invalid value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  40128  0  0  0

Scenario 0.56: Left Valid Right Invalid
    [Documentation]    Verifies handling when only the right channel contains an invalid value.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  65535  0  0  0

Scenario 0.57: Message Counter Rollover Boundary
    [Documentation]    Verifies operation near message counter rollover.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0  254  0
    Verify Motor Function Angular Velocity  40128  40128  0  255  0
    Verify Motor Function Angular Velocity  40128  40128  0  0    0

Scenario 0.58: Reserved Field Pattern Test
    [Documentation]    Verifies reserved field contents do not affect angular velocity decoding.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  43690  0  0
    Verify Motor Function Angular Velocity  40128  40128  21845  0  0

Scenario 0.59: Repeated Packet Stress
    [Documentation]    Verifies identical command packets do not accumulate error or stale state.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  0

Scenario 0.60: Full Protocol Extremes
    [Documentation]    Verifies all message fields at their maximum legal values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  64255  65535  255  255

Scenario 0.61: Full Protocol Minimums
    [Documentation]    Verifies all message fields at their minimum values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  32128  0  0  0

Scenario 0.62: Maximum Differential Velocity
    [Documentation]    Verifies one side commanded at minimum legal velocity and the other at maximum.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  64255  0  0  0

Scenario 0.63: Maximum Differential Velocity Reversed
    [Documentation]    Verifies one side commanded at maximum legal velocity and the other at minimum.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  32128  0  0  0

Scenario 0.64: CRC Sweep
    [Documentation]    Verifies CRC field changes do not affect payload decoding when CRC is ignored.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  85
    Verify Motor Function Angular Velocity  40128  40128  0  0  170
    Verify Motor Function Angular Velocity  40128  40128  0  0  255

Scenario 0.65: Message Counter Sweep
    [Documentation]    Verifies message counter values do not affect payload decoding.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0  0    0
    Verify Motor Function Angular Velocity  40128  40128  0  1    0
    Verify Motor Function Angular Velocity  40128  40128  0  127  0
    Verify Motor Function Angular Velocity  40128  40128  0  255  0

Scenario 0.66: Illegal Raw Minimum Left
    [Documentation]    Verifies handling of the absolute minimum uint16 value on the left channel.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  32128  0  0  0

Scenario 0.67: Illegal Raw Minimum Right
    [Documentation]    Verifies handling of the absolute minimum uint16 value on the right channel.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  0  0  0  0

Scenario 0.68: Illegal Raw Maximum Left
    [Documentation]    Verifies handling of the absolute maximum uint16 value on the left channel.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  65535  32128  0  0  0

Scenario 0.69: Illegal Raw Maximum Right
    [Documentation]    Verifies handling of the absolute maximum uint16 value on the right channel.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  65535  0  0  0

Scenario 0.70: Fully Illegal Angular Velocities
    [Documentation]    Verifies handling when both angular velocity fields violate protocol limits.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  65535  65535  255  255

Scenario 0.81: Maximum Legal Values With Reserved Zero
    [Documentation]    Verifies legal maximum angular velocity with minimal auxiliary fields.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  64255  0  0  0

Scenario 0.82: Minimum Legal Values With Reserved Maximum
    [Documentation]    Verifies legal minimum angular velocity with maximum auxiliary fields.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  32128  65535  255  255

Scenario 0.83: One Channel Lower Boundary Walk
    [Documentation]    Verifies lower-boundary transitions on the left channel while the right remains constant.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32127  40128  0  0  0
    Verify Motor Function Angular Velocity  32128  40128  0  0  0
    Verify Motor Function Angular Velocity  32129  40128  0  0  0

Scenario 0.84: One Channel Upper Boundary Walk
    [Documentation]    Verifies upper-boundary transitions on the right channel while the left remains constant.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  64254  0  0  0
    Verify Motor Function Angular Velocity  40128  64255  0  0  0
    Verify Motor Function Angular Velocity  40128  64256  0  0  0

Scenario 0.85: Simultaneous Lower Invalid High Invalid
    [Documentation]    Verifies handling of both channels outside opposite ends of the legal range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  65535  0  0  0

Scenario 0.86: Simultaneous High Invalid Low Invalid
    [Documentation]    Verifies handling of both channels outside opposite ends of the legal range reversed.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  65535  0  0  0  0

Scenario 0.87: Legal Recovery After Mixed Invalid
    [Documentation]    Verifies controller returns to normal operation after mixed invalid values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  65535  0  65535  255  255
    Verify Motor Function Angular Velocity  40128  40128  0  0  0

Scenario 0.88: Auxiliary Fields Cycling
    [Documentation]    Verifies velocity decoding remains stable while all auxiliary fields change.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0      0    0
    Verify Motor Function Angular Velocity  40128  40128  65535  1    85
    Verify Motor Function Angular Velocity  40128  40128  43690  127  170
    Verify Motor Function Angular Velocity  40128  40128  21845  255  255

Scenario 0.89: Alternating Extreme Auxiliary Patterns
    [Documentation]    Verifies reserved, counter, and CRC values do not leak into velocity calculations.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  48128  48128  43690  85   170
    Verify Motor Function Angular Velocity  48128  48128  21845  170  85

Scenario 0.90: Valid Packet Flood Stability
    [Documentation]    Verifies repeated valid packets remain stable over many updates.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0

Scenario 0.91: Full Legal Range Sweep
    [Documentation]    Verifies operation through representative values spanning the entire legal range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    Verify Motor Function Angular Velocity  36128  36128  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  56128  56128  0  0  0
    Verify Motor Function Angular Velocity  64255  64255  0  0  0

Scenario 0.92: Full Legal Range Sweep Reverse
    [Documentation]    Verifies descending operation throughout the legal encoded range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  64255  0  0  0
    Verify Motor Function Angular Velocity  56128  56128  0  0  0
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Verify Motor Function Angular Velocity  36128  36128  0  0  0
    Verify Motor Function Angular Velocity  32128  32128  0  0  0

Scenario 0.93: Lower Bound Left Upper Bound Right With Aux Max
    [Documentation]    Verifies maximum differential velocity with maximum auxiliary values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  64255  65535  255  255

Scenario 0.94: Upper Bound Left Lower Bound Right With Aux Max
    [Documentation]    Verifies maximum differential velocity reversed with maximum auxiliary values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  32128  65535  255  255

Scenario 0.95: Edge Valid Values Mixed
    [Documentation]    Verifies legal values immediately inside both protocol limits.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32129  64254  0  0  0

Scenario 0.96: Illegal Values Mixed
    [Documentation]    Verifies legal-adjacent invalid values on both sides of the range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32127  64256  0  0  0

Scenario 0.97: All Fields Zero
    [Documentation]    Verifies behavior with an entirely zero message.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  0  0  0  0

Scenario 0.98: All Fields Maximum
    [Documentation]    Verifies behavior with an entirely saturated message.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  65535  65535  65535  255  255

Scenario 0.99: Random Stress Pattern A
    [Documentation]    Verifies decoding with arbitrary legal velocities and auxiliary values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  43890  61234  21845  73  182

Scenario 0.100: Random Stress Pattern B
    [Documentation]    Verifies decoding with arbitrary legal velocities and auxiliary values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  57999  33444  43690  201  19

Scenario 0.101: Sequential Velocity Ramp Up
    [Documentation]    Verifies increasing angular velocity commands are processed correctly.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  36128  36128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  56128  56128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  64255  64255  0  0  0

Scenario 0.102: Sequential Velocity Ramp Down
    [Documentation]    Verifies decreasing angular velocity commands are processed correctly.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  64255  64255  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  56128  56128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  48128  48128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  36128  36128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  32128  32128  0  0  0

Scenario 0.103: Rapid Min Max Toggle
    [Documentation]    Verifies repeated transitions between minimum and maximum valid values.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  64255  64255  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  64255  64255  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  32128  32128  0  0  0

Scenario 0.104: Left Right Alternating Extremes
    [Documentation]    Verifies independent channel operation through extreme transitions.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  64255  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  64255  32128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  32128  64255  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  64255  32128  0  0  0

Scenario 0.105: Invalid Low Then Valid Then Invalid High
    [Documentation]    Verifies proper recovery when alternating between invalid and valid commands.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0  0  0  0  0
    Sleep  100ms
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Sleep  100ms
    Verify Motor Function Angular Velocity  65535  65535  0  0  0

Scenario 0.106: Mixed Validity Sweep
    [Documentation]    Verifies handling of alternating valid and invalid channel combinations.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0      40128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  40128  40128  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  40128  65535  0  0  0
    Sleep  50ms
    Verify Motor Function Angular Velocity  40128  40128  0  0  0

Scenario 0.107: Full Range Stress Sequence
    [Documentation]    Verifies decoder stability across representative values spanning the entire legal range.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32128  64255  65535  255  255
    Sleep  25ms
    Verify Motor Function Angular Velocity  36128  56128  43690  85   170
    Sleep  25ms
    Verify Motor Function Angular Velocity  40128  48128  21845  127  85
    Sleep  25ms
    Verify Motor Function Angular Velocity  48128  40128  65535  170  255
    Sleep  25ms
    Verify Motor Function Angular Velocity  56128  36128  0      255  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  64255  32128  65535  255  255

Scenario 0.108: Counter And CRC Activity Sequence
    [Documentation]    Verifies payload decoding remains stable while counter and CRC continuously change.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  40128  40128  0      0    0
    Sleep  25ms
    Verify Motor Function Angular Velocity  40128  40128  0      1    85
    Sleep  25ms
    Verify Motor Function Angular Velocity  40128  40128  0      2    170
    Sleep  25ms
    Verify Motor Function Angular Velocity  40128  40128  0      3    255
    Sleep  25ms
    Verify Motor Function Angular Velocity  40128  40128  0      4    0

Scenario 0.109: Boundary Crossing Stress
    [Documentation]    Verifies behavior around both legal boundaries under repeated transitions.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  32127  32127  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  32128  32128  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  32129  32129  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  64254  64254  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  64255  64255  0  0  0
    Sleep  25ms
    Verify Motor Function Angular Velocity  64256  64256  0  0  0

Scenario 0.110: Recovery Stress Sequence
    [Documentation]    Verifies repeated recovery from alternating invalid and valid packets.
    Wait For Line On Uart  System Ready
    Verify Motor Function Angular Velocity  0      0      0      0    0
    Sleep  50ms
    Verify Motor Function Angular Velocity  40128  40128  0      0    0
    Sleep  50ms
    Verify Motor Function Angular Velocity  65535  65535  65535  255  255
    Sleep  50ms
    Verify Motor Function Angular Velocity  40128  40128  0      0    0
    
