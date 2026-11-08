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
  Execute Command  machine LoadPlatformDescription @${CURDIR}/STM32F446RETx.repl
  Execute Command  sysbus LoadELF @${CURDIR}/../build/PWM_Test
  Execute Command  connector Connect sysbus.can1 can_network
  Execute Command  sysbus WriteDoubleWord 0x40006404 0x00000001
  Execute Command  sysbus WriteDoubleWord 0x40006400 0x0000000
  Execute Command  python "self.Machine['sysbus.can1'].WriteDoubleWord(0x14, 0x2)"
  Execute Command  python "self.Machine['sysbus.can1'].UpdateFifo0InterruptLine()"
  Create Terminal Tester  ${UART_PERIPHERAL}  timeout=10  defaultPauseEmulation=False
  ${safe_name}=      Evaluate    "${TEST_NAME}".replace(" ", "_")
  # Execute Command    sysbus.cpu CreateExecutionTracing "test_tracer" @${CURDIR}/../traces/${safe_name}.bin.gz PC true true  
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
    
Verify Motor Function Ind Motor
    [Arguments]    ${motor1_in}    ${motor2_in}     ${motor3_in}    ${motor4_in}
    Verify Motor Function     ${motor1_in}    ${motor2_in}     ${motor3_in}    ${motor4_in}    272
    
Verify Motor Function
    [Arguments]    ${motor1_in}    ${motor2_in}     ${motor3_in}    ${motor4_in}    ${frame_id}
        
    # Caclulate Expected Values
    ${motor1_speed}=       Evaluate       abs(${motor1_in} * ${MAX_RPM} * 4096.0 )
    ${motor2_speed}=       Evaluate       abs(${motor2_in} * ${MAX_RPM} * 4096.0 )
    ${motor3_speed}=       Evaluate       abs(${motor3_in} * ${MAX_RPM} * 4096.0 )
    ${motor4_speed}=       Evaluate       abs(${motor4_in} * ${MAX_RPM} * 4096.0 )
    
    ${motor1_speed}=       Evaluate       32767 if (${motor1_speed} > 32767) else ${motor1_speed}
    ${motor2_speed}=       Evaluate       32767 if (${motor2_speed} > 32767) else ${motor2_speed}
    ${motor3_speed}=       Evaluate       32767 if (${motor3_speed} > 32767) else ${motor3_speed}
    ${motor4_speed}=       Evaluate       32767 if (${motor4_speed} > 32767) else ${motor4_speed}
    
    ${exp_ccr1_raw}=       Evaluate       0 if (abs(float(${motor1_speed})) < 204.75) else int(float(${motor1_speed}))
    ${exp_ccr2_raw}=       Evaluate       0 if (abs(float(${motor2_speed})) < 204.75) else int(float(${motor2_speed}))
    ${exp_ccr3_raw}=       Evaluate       0 if (abs(float(${motor3_speed})) < 204.75) else int(float(${motor3_speed}))
    ${exp_ccr4_raw}=       Evaluate       0 if (abs(float(${motor4_speed})) < 204.75) else int(float(${motor4_speed}))
    
    # Set Exp Output Direction
    ${motor1_dir}=         Evaluate       0 if(${motor1_in} < 0.0) else 1
    ${motor2_dir}=         Evaluate       1 if(${motor2_in} < 0.0) else 0
    ${motor3_dir}=         Evaluate       0 if(${motor3_in} < 0.0) else 1
    ${motor4_dir}=         Evaluate       1 if(${motor4_in} < 0.0) else 0
    
    ${motor1_dir}=         Evaluate       0 if(float(${motor1_speed}) < 204.75) else ${motor1_dir}
    ${motor2_dir}=         Evaluate       0 if(float(${motor2_speed}) < 204.75) else ${motor2_dir}
    ${motor3_dir}=         Evaluate       0 if(float(${motor3_speed}) < 204.75) else ${motor3_dir}
    ${motor4_dir}=         Evaluate       0 if(float(${motor4_speed}) < 204.75) else ${motor4_dir}
    
    # Get Original Values
    ${org_m1}=             Execute Command        sysbus ReadDoubleWord 0x40000034
    ${org_m2}=             Execute Command        sysbus ReadDoubleWord 0x40000038
    ${org_m3}=             Execute Command        sysbus ReadDoubleWord 0x4000003C
    ${org_m4}=             Execute Command        sysbus ReadDoubleWord 0x40000040
    
    # Determine if value changes
    IF    (${motor1_in} > 0 and ${motor3_in} < 0) or (${motor1_in} < 0 and ${motor3_in} > 0) or (${motor2_in} > 0 and ${motor4_in} < 0) or (${motor2_in} < 0 and ${motor4_in} > 0)
    	${exp_ccr1_raw}=       Set Variable       ${org_m1}
    	${exp_ccr3_raw}=       Set Variable       ${org_m3}
    	${motor1_dir}=         Execute Command    gpioPortA.led_m1p1 State
    	${motor3_dir}=         Execute Command    gpioPortB.led_m3p1 State
    	${motor1_dir}=         Evaluate            int(${motor1_dir})
    	${motor3_dir}=         Evaluate            int(${motor3_dir})
    	
    	${exp_ccr2_raw}=       Set Variable       ${org_m2}
    	${exp_ccr4_raw}=       Set Variable       ${org_m4}
    	${motor2_dir}=         Execute Command    gpioPortB.led_m2p1 State
    	${motor4_dir}=         Execute Command    gpioPortB.led_m4p1 State
    	${motor2_dir}=         Evaluate            int(${motor2_dir})
    	${motor4_dir}=         Evaluate            int(${motor4_dir})
    END
    
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
    ${m1_int}=             Evaluate       int(float(${motor1_in})) & 0xFFFF
    ${m2_int}=             Evaluate       int(float(${motor2_in})) & 0xFFFF
    ${m3_int}=             Evaluate       int(float(${motor3_in})) & 0xFFFF
    ${m4_int}=             Evaluate       int(float(${motor4_in})) & 0xFFFF

    ${msb_1}=              Evaluate       (${m1_int} >> 8) & 0xFF
    ${lsb_1}=              Evaluate       ${m1_int} & 0xFF
    
    ${msb_2}=              Evaluate       (${m2_int} >> 8) & 0xFF
    ${lsb_2}=              Evaluate       ${m2_int} & 0xFF

    ${msb_3}=              Evaluate       (${m3_int} >> 8) & 0xFF
    ${lsb_3}=              Evaluate       ${m3_int} & 0xFF

    ${msb_4}=              Evaluate       (${m4_int} >> 8) & 0xFF
    ${lsb_4}=              Evaluate       ${m4_int} & 0xFF
  
    ${msb_1_hex}=          Evaluate       f"0x{${msb_1}:02X}"
    ${lsb_1_hex}=          Evaluate       f"0x{${lsb_1}:02X}"
    ${msb_2_hex}=          Evaluate       f"0x{${msb_2}:02X}"
    ${lsb_2_hex}=          Evaluate       f"0x{${lsb_2}:02X}"
    ${msb_3_hex}=          Evaluate       f"0x{${msb_3}:02X}"
    ${lsb_3_hex}=          Evaluate       f"0x{${lsb_3}:02X}"
    ${msb_4_hex}=          Evaluate       f"0x{${msb_4}:02X}"
    ${lsb_4_hex}=          Evaluate       f"0x{${lsb_4}:02X}"
    
     # Send CAN Message To STM Board
    Execute Command        python "import System; bytes_data = System.Array[System.Byte]([${lsb_1_hex}, ${msb_1_hex}, ${lsb_2_hex}, ${msb_2_hex}, ${lsb_3_hex}, ${msb_3_hex}, ${lsb_4_hex}, ${msb_4_hex}]); frame = Antmicro.Renode.Core.CAN.CANMessageFrame(${frame_id}, bytes_data, True); msg = Antmicro.Renode.Peripherals.CAN.STMCAN.CANMessage(frame); self.Machine['sysbus.can1'].ReceiveCANMessage(msg)"
    
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

Scenario 1.1: All the Same Value
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    
Scenario 1.2: Random Values
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  500  1500  900    

Scenario 1.3: Random Values v2
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  400  1500  900
    
Scenario 1.4: Random Values v3
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  300  1500  900
    
Scenario 1.5: Random Values v4
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  250  1500  900   

Scenario 1.6: Random Values v5
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  499  1500  900
    
Scenario 1.7: Random Values v6
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  450  1500  900
    
Scenario 1.8: Random Values v7
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  425  1500  900
    
Scenario 1.9: Below 204
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  200  1500  900
    
Scenario 1.10: Value Edge Below Deadband
    [Documentation]    Verifies motor inputs work down to register boundaries (Expected 0)
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  204  1500  900

Scenario 1.11: Value Edge Above Deadband
    [Documentation]    Verifies motor inputs work down to register boundaries (Expected > 0)
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  205  1500  900

Scenario 1.12: Value Mix Ultra Low
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1  1  1  1

Scenario 1.13: Value Mix 10_50_80_120
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  10  50  80  120

Scenario 1.14: Value Mix 600_700_800_1000
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  600  700  800  1000

Scenario 1.15: Value Mix 1200_1300_1400_1100
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1200  1300  1400  1100

Scenario 1.16: Value Mix 100_204_300_400
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  100  204  300  400

Scenario 1.17: Value Mix 205_206_207_208
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  205  206  207  208

Scenario 1.18: Value Mix 2000_2000_2000_2000
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  2000  2000  2000  2000

Scenario 1.19: Value Mix 50_950_150_850
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  50  950  150  850

Scenario 1.20: Value Mix 123_456_789_1011
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  123  456  789  1011

Scenario 1.21: Value Mix 4000_4000_4000_4000
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  4000  4000  4000  4000

Scenario 1.22: Random Gen 1603_327_523_1922
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1603  327  523  1922

Scenario 1.23: Random Gen 433_2441_2210_134
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  433  2441  2210  134

Scenario 1.24: Random Gen 2253_2120_1752_2415
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  2253  2120  1752  2415

Scenario 1.25: Random Gen 1403_2370_1950_399
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1403  2370  1950  399

Scenario 1.26: Random Gen 1761_1660_247_153
    [Documentation]    Verifies motor inputs work down to register boundaries
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1761  1660  247  153

Scenario 1.27: Max Int16 Value Clip
    [Documentation]    Verifies motor inputs at maximum signed 16-bit limits
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  32767  32767  32767  32767

Scenario 1.28: ARR Hard Over-Saturation Edge
    [Documentation]    Verifies inputs that calculate exactly to or just above your ARR limit of 4094
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  9481  9482  9500  10000

Scenario 1.29: Mid-Scale Over-Saturation
    [Documentation]    Verifies the board clips mid-tier saturation safely without register overflow
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  12000  15000  18000  20000

Scenario 1.30: All the Same Value (neg)
    [Documentation]    Verifies inputs Works
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500
    
Scenario 1.31: All Negative One
    [Documentation]    Verifies FF FF two's complement handling
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -1  -1  -1  -1

Scenario 1.32: All Negative Two
    [Documentation]    Verifies negative values near zero
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -2  -2  -2  -2

Scenario 1.33: Minimum Int16 Value
    [Documentation]    Verifies minimum signed 16-bit value
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -32768  -32768  -32768  -32768

Scenario 1.34: Negative Boundary Above Minimum
    [Documentation]    Verifies value adjacent to minimum signed 16-bit limit
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -32767  -32767  -32767  -32767

Scenario 1.35: Mixed Min Max Int16
    [Documentation]    Verifies signed extremes in same message
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -32768  32767  -32768  32767

Scenario 1.36: Mixed Sign Alternating
    [Documentation]    Verifies alternating positive and negative values
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  -1500  1500  -1500

Scenario 1.37: Mixed Sign Alternating v2
    [Documentation]    Verifies alternating positive and negative values
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -1500  1500  -1500  1500

Scenario 1.38: All Zero
    [Documentation]    Verifies zero crossing
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  0  0

Scenario 1.39: Negative Deadband Edge Below
    [Documentation]    Verifies negative deadband boundary (Expected 0)
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -204  -204  -204  -204

Scenario 1.40: Negative Deadband Edge Above
    [Documentation]    Verifies negative deadband boundary (Expected < 0)
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -205  -205  -205  -205

Scenario 1.41: Small Negative Values
    [Documentation]    Verifies small negative value handling
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -1  -10  -50  -100

Scenario 1.42: Random Negative Values
    [Documentation]    Verifies arbitrary negative values
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -123  -456  -789  -1011

Scenario 1.43: Positive Negative Zero Mix
    [Documentation]    Verifies sign transitions around zero
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -1  0  1  -1

Scenario 1.44: Int16 Edge Sweep
    [Documentation]    Verifies all important signed boundaries in one frame
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -32768  -1  0  32767

Scenario 2.1: Two Step Ramp
    [Documentation]    Verifies output transitions from zero to nominal command
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  500ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500

Scenario 2.2: Two Step Sign Change
    [Documentation]    Verifies positive to negative transition
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  500ms
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500

Scenario 2.3: Three Step Deadband Crossing
    [Documentation]    Verifies crossing through deadband threshold
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  200  200  200  200
    Sleep  500ms
    Verify Motor Function Ind Motor  204  204  204  204
    Sleep  500ms
    Verify Motor Function Ind Motor  205  205  205  205

Scenario 2.4: Five Step Positive Ramp
    [Documentation]    Verifies smooth positive ramp
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  250ms
    Verify Motor Function Ind Motor  500  500  500  500
    Sleep  250ms
    Verify Motor Function Ind Motor  1000  1000  1000  1000
    Sleep  250ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  250ms
    Verify Motor Function Ind Motor  2000  2000  2000  2000

Scenario 2.5: Five Step Negative Ramp
    [Documentation]    Verifies smooth negative ramp
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  250ms
    Verify Motor Function Ind Motor  -500  -500  -500  -500
    Sleep  250ms
    Verify Motor Function Ind Motor  -1000  -1000  -1000  -1000
    Sleep  250ms
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500
    Sleep  250ms
    Verify Motor Function Ind Motor  -2000  -2000  -2000  -2000

Scenario 2.6: Eight Step Direction Reversal
    [Documentation]    Verifies repeated sign transitions
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  200ms
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  200ms
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  200ms
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  200ms
    Verify Motor Function Ind Motor  0  0  0  0

Scenario 2.7: Ten Step Full Scale Ramp
    [Documentation]    Verifies large range ramp without instability
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -2000  -2000  -2000  -2000
    Sleep  250ms
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500
    Sleep  250ms
    Verify Motor Function Ind Motor  -1000  -1000  -1000  -1000
    Sleep  250ms
    Verify Motor Function Ind Motor  -500  -500  -500  -500
    Sleep  250ms
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  250ms
    Verify Motor Function Ind Motor  500  500  500  500
    Sleep  250ms
    Verify Motor Function Ind Motor  1000  1000  1000  1000
    Sleep  250ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  250ms
    Verify Motor Function Ind Motor  2000  2000  2000  2000
    Sleep  250ms
    Verify Motor Function Ind Motor  2500  2500  2500  2500

Scenario 2.8: Twenty Step Stress Ramp
    [Documentation]    Verifies sustained command changes over maximum step count
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  100ms
    Verify Motor Function Ind Motor  100  100  100  100
    Sleep  100ms
    Verify Motor Function Ind Motor  200  200  200  200
    Sleep  100ms
    Verify Motor Function Ind Motor  300  300  300  300
    Sleep  100ms
    Verify Motor Function Ind Motor  400  400  400  400
    Sleep  100ms
    Verify Motor Function Ind Motor  500  500  500  500
    Sleep  100ms
    Verify Motor Function Ind Motor  600  600  600  600
    Sleep  100ms
    Verify Motor Function Ind Motor  700  700  700  700
    Sleep  100ms
    Verify Motor Function Ind Motor  800  800  800  800
    Sleep  100ms
    Verify Motor Function Ind Motor  900  900  900  900
    Sleep  100ms
    Verify Motor Function Ind Motor  1000  1000  1000  1000
    Sleep  100ms
    Verify Motor Function Ind Motor  1100  1100  1100  1100
    Sleep  100ms
    Verify Motor Function Ind Motor  1200  1200  1200  1200
    Sleep  100ms
    Verify Motor Function Ind Motor  1300  1300  1300  1300
    Sleep  100ms
    Verify Motor Function Ind Motor  1400  1400  1400  1400
    Sleep  100ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  100ms
    Verify Motor Function Ind Motor  1600  1600  1600  1600
    Sleep  100ms
    Verify Motor Function Ind Motor  1700  1700  1700  1700
    Sleep  100ms
    Verify Motor Function Ind Motor  1800  1800  1800  1800
    Sleep  100ms
    Verify Motor Function Ind Motor  1900  1900  1900  1900
    
Scenario 2.9: Independent Channel Sweep
    [Documentation]    Verifies channels operate independently
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  200ms
    Verify Motor Function Ind Motor  500  0  0  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1000  0  0  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  0  0  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  500  0  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  1000  0  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  1500  0  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  1500  500  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  1500  1000  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500

Scenario 2.10: Clockwise Rotation Pattern
    [Documentation]    Verifies rotational motor command changes
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1000  0  0  0
    Sleep  250ms
    Verify Motor Function Ind Motor  0  1000  0  0
    Sleep  250ms
    Verify Motor Function Ind Motor  0  0  1000  0
    Sleep  250ms
    Verify Motor Function Ind Motor  0  0  0  1000
    Sleep  250ms
    Verify Motor Function Ind Motor  1000  1000  1000  1000

Scenario 2.11: Cross Channel Alternation
    [Documentation]    Verifies alternating motor patterns
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  0  1500  0
    Sleep  200ms
    Verify Motor Function Ind Motor  0  1500  0  1500
    Sleep  200ms
    Verify Motor Function Ind Motor  1500  0  1500  0
    Sleep  200ms
    Verify Motor Function Ind Motor  0  1500  0  1500

Scenario 2.12: Deadband Transition Stress
    [Documentation]    Verifies repeated deadband crossings
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  203  203  203  203
    Sleep  150ms
    Verify Motor Function Ind Motor  204  204  204  204
    Sleep  150ms
    Verify Motor Function Ind Motor  205  205  205  205
    Sleep  150ms
    Verify Motor Function Ind Motor  204  204  204  204
    Sleep  150ms
    Verify Motor Function Ind Motor  203  203  203  203
    Sleep  150ms
    Verify Motor Function Ind Motor  205  205  205  205

Scenario 2.13: Mixed Positive Negative Ramp
    [Documentation]    Verifies opposing motor directions
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -500  500  -500  500
    Sleep  250ms
    Verify Motor Function Ind Motor  -1000  1000  -1000  1000
    Sleep  250ms
    Verify Motor Function Ind Motor  -1500  1500  -1500  1500
    Sleep  250ms
    Verify Motor Function Ind Motor  -2000  2000  -2000  2000

Scenario 2.14: Sign Reversal With Zero Crossing
    [Documentation]    Verifies transition through zero
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -2000  -2000  -2000  -2000
    Sleep  250ms
    Verify Motor Function Ind Motor  -1000  -1000  -1000  -1000
    Sleep  250ms
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  250ms
    Verify Motor Function Ind Motor  1000  1000  1000  1000
    Sleep  250ms
    Verify Motor Function Ind Motor  2000  2000  2000  2000

Scenario 2.15: Random Motion Sequence A
    [Documentation]    Verifies handling of unpredictable commands
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1200  300  850  1600
    Sleep  150ms
    Verify Motor Function Ind Motor  400  1700  100  900
    Sleep  150ms
    Verify Motor Function Ind Motor  2000  250  1400  600
    Sleep  150ms
    Verify Motor Function Ind Motor  50  1850  320  1500
    Sleep  150ms
    Verify Motor Function Ind Motor  1000  1000  1000  1000

Scenario 2.16: Random Motion Sequence B
    [Documentation]    Verifies command changes on every channel
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  321  456  789  1023
    Sleep  125ms
    Verify Motor Function Ind Motor  987  654  321  123
    Sleep  125ms
    Verify Motor Function Ind Motor  1500  700  400  1900
    Sleep  125ms
    Verify Motor Function Ind Motor  2222  444  1777  888
    Sleep  125ms
    Verify Motor Function Ind Motor  1  204  205  4094

Scenario 2.17: Saturation Entry Exit
    [Documentation]    Verifies entering and exiting clipping regions
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  4000  4000  4000  4000
    Sleep  250ms
    Verify Motor Function Ind Motor  8000  8000  8000  8000
    Sleep  250ms
    Verify Motor Function Ind Motor  12000  12000  12000  12000
    Sleep  250ms
    Verify Motor Function Ind Motor  4000  4000  4000  4000
    Sleep  250ms
    Verify Motor Function Ind Motor  1000  1000  1000  1000

Scenario 2.18: Int16 Boundary Walk
    [Documentation]    Verifies signed int16 edge transitions
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -32768  -32768  -32768  -32768
    Sleep  200ms
    Verify Motor Function Ind Motor  -32767  -32767  -32767  -32767
    Sleep  200ms
    Verify Motor Function Ind Motor  -1  -1  -1  -1
    Sleep  200ms
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  200ms
    Verify Motor Function Ind Motor  1  1  1  1
    Sleep  200ms
    Verify Motor Function Ind Motor  32767  32767  32767  32767

Scenario 2.19: Twenty Step Mixed Stress
    [Documentation]    Verifies continuous mixed command operation
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  100ms
    Verify Motor Function Ind Motor  100  500  900  1300
    Sleep  100ms
    Verify Motor Function Ind Motor  200  600  1000  1400
    Sleep  100ms
    Verify Motor Function Ind Motor  300  700  1100  1500
    Sleep  100ms
    Verify Motor Function Ind Motor  400  800  1200  1600
    Sleep  100ms
    Verify Motor Function Ind Motor  500  900  1300  1700
    Sleep  100ms
    Verify Motor Function Ind Motor  600  1000  1400  1800
    Sleep  100ms
    Verify Motor Function Ind Motor  700  1100  1500  1900
    Sleep  100ms
    Verify Motor Function Ind Motor  800  1200  1600  2000
    Sleep  100ms
    Verify Motor Function Ind Motor  900  1300  1700  2100
    Sleep  100ms
    Verify Motor Function Ind Motor  1000  1400  1800  2200
    Sleep  100ms
    Verify Motor Function Ind Motor  900  1300  1700  2100
    Sleep  100ms
    Verify Motor Function Ind Motor  800  1200  1600  2000
    Sleep  100ms
    Verify Motor Function Ind Motor  700  1100  1500  1900
    Sleep  100ms
    Verify Motor Function Ind Motor  600  1000  1400  1800
    Sleep  100ms
    Verify Motor Function Ind Motor  500  900  1300  1700
    Sleep  100ms
    Verify Motor Function Ind Motor  400  800  1200  1600
    Sleep  100ms
    Verify Motor Function Ind Motor  300  700  1100  1500
    Sleep  100ms
    Verify Motor Function Ind Motor  200  600  1000  1400
    Sleep  100ms
    Verify Motor Function Ind Motor  0  0  0  0

Scenario 2.20: Emergency Stop Recovery
    [Documentation]    Verifies abrupt stop and restart behavior
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  2000  2000  2000  2000
    Sleep  500ms
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  500ms
    Verify Motor Function Ind Motor  2000  2000  2000  2000
    Sleep  500ms
    Verify Motor Function Ind Motor  0  0  0  0

Scenario 2.21: Mixed Deadband Boundary
    [Documentation]    Verifies positive and negative deadband decisions in same frame
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  204  205  -204  -205

Scenario 2.22: Single Channel Positive Deadband Edge
    [Documentation]    Verifies deadband threshold on channel 1 only
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  204  1500  1500  1500
    Sleep  250ms
    Verify Motor Function Ind Motor  205  1500  1500  1500

Scenario 2.23: Single Channel Negative Deadband Edge
    [Documentation]    Verifies negative deadband threshold on channel 1 only
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -204  1500  1500  1500
    Sleep  250ms
    Verify Motor Function Ind Motor  -205  1500  1500  1500

Scenario 2.24: Int16 Min Channel 1 Isolation
    [Documentation]    Verifies INT16_MIN handling on motor 1 only
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -32768  0  0  0

Scenario 2.25: Int16 Min Channel 2 Isolation
    [Documentation]    Verifies INT16_MIN handling on motor 2 only
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  -32768  0  0

Scenario 2.26: Int16 Min Channel 3 Isolation
    [Documentation]    Verifies INT16_MIN handling on motor 3 only
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  -32768  0

Scenario 2.27: Int16 Min Channel 4 Isolation
    [Documentation]    Verifies INT16_MIN handling on motor 4 only
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  0  0  0  -32768

Scenario 2.28: Saturation Boundary Sweep
    [Documentation]    Verifies clipping behavior around ARR boundary
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  9479  9479  9479  9479
    Sleep  200ms
    Verify Motor Function Ind Motor  9480  9480  9480  9480
    Sleep  200ms
    Verify Motor Function Ind Motor  9481  9481  9481  9481
    Sleep  200ms
    Verify Motor Function Ind Motor  9482  9482  9482  9482

Scenario 2.29: Saturation Exit Recovery
    [Documentation]    Verifies controller recovers correctly from clipping
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  12000  12000  12000  12000
    Sleep  200ms
    Verify Motor Function Ind Motor  9400  9400  9400  9400
    Sleep  200ms
    Verify Motor Function Ind Motor  500  500  500  500

Scenario 2.30: Sign Flip Across Deadband Active
    [Documentation]    Verifies direction reversal outside deadband
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -206  -206  -206  -206
    Sleep  150ms
    Verify Motor Function Ind Motor  206  206  206  206

Scenario 2.31: Sign Flip Across Deadband Inactive
    [Documentation]    Verifies commands remain suppressed inside deadband
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -204  -204  -204  -204
    Sleep  150ms
    Verify Motor Function Ind Motor  204  204  204  204

Scenario 2.32: Rapid Command Reversal Stress
    [Documentation]    Verifies PWM update path during rapid polarity changes
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  10ms
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500
    Sleep  10ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500
    Sleep  10ms
    Verify Motor Function Ind Motor  -1500  -1500  -1500  -1500
    Sleep  10ms
    Verify Motor Function Ind Motor  1500  1500  1500  1500

Scenario 2.33: One LSB Zero Crossing
    [Documentation]    Verifies arithmetic around signed zero boundary
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -1  -1  -1  -1
    Sleep  100ms
    Verify Motor Function Ind Motor  0  0  0  0
    Sleep  100ms
    Verify Motor Function Ind Motor  1  1  1  1

Scenario 2.34: Channel 1 Saturation Isolation
    [Documentation]    Verifies channel 1 clipping does not affect other channels
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  32767  1000  1000  1000

Scenario 2.35: Channel 2 Saturation Isolation
    [Documentation]    Verifies channel 2 clipping does not affect other channels
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1000  32767  1000  1000

Scenario 2.36: Channel 3 Saturation Isolation
    [Documentation]    Verifies channel 3 clipping does not affect other channels
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1000  1000  32767  1000

Scenario 2.37: Channel 4 Saturation Isolation
    [Documentation]    Verifies channel 4 clipping does not affect other channels
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  1000  1000  1000  32767

Scenario 2.38: Saturated Channel Walk
    [Documentation]    Verifies saturation moves between channels correctly
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  32767  1000  1000  1000
    Sleep  200ms
    Verify Motor Function Ind Motor  1000  32767  1000  1000
    Sleep  200ms
    Verify Motor Function Ind Motor  1000  1000  32767  1000
    Sleep  200ms
    Verify Motor Function Ind Motor  1000  1000  1000  32767

Scenario 2.39: Deadband Channel Isolation Mix
    [Documentation]    Verifies mixed active and deadband channels
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  205  204  -205  -204

Scenario 2.40: Extreme Mixed Boundary Stress
    [Documentation]    Verifies all critical arithmetic boundaries simultaneously
    Wait For Line On Uart  System Ready
    Verify Motor Function Ind Motor  -32768  -205  205  32767
    

