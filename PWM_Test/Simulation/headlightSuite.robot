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
  Execute Command  machine LoadPlatformDescription @PWM_Test/Simulation/STM32F446RETx.repl
  Execute Command  sysbus LoadELF @PWM_Test/build/PWM_Test
  Execute Command  connector Connect sysbus.can1 can_network
  Execute Command  sysbus WriteDoubleWord 0x40006404 0x00000001
  Execute Command  sysbus WriteDoubleWord 0x40006400 0x0000000
  Execute Command  python "self.Machine['sysbus.can1'].WriteDoubleWord(0x14, 0x2)"
  Execute Command  python "self.Machine['sysbus.can1'].UpdateFifo0InterruptLine()"
  Create Terminal Tester  ${UART_PERIPHERAL}  timeout=10  defaultPauseEmulation=False
  ${safe_name}=      Evaluate    "${TEST_NAME}".replace(" ", "_")
  # Execute Command    sysbus.cpu CreateExecutionTracing "test_tracer" @PWM_Test/traces/${safe_name}.bin.gz PC true true  
  Execute Command    emulation SetAdvanceImmediately false

Stop Code Coverage and Pause
  [Documentation]  Stop the Code Coverage and Pauses the Board
  Execute Command    sysbus.cpu Pause
  # Execute Command    sysbus.cpu DisableExecutionTracing
  Execute Command    Clear
  
Led Has Updated
    [Arguments]     ${led}     ${exp_val}
    
    ${raw_val}=    Execute Command     ${led} State
    ${int_val}=    Evaluate            int(${raw_val})
    
    Should Be Equal As Integers    ${int_val}     ${exp_val}
    
Verify Toggle Headlights
    [Arguments]    ${state}
    ${raw_org_state}=      Execute Command   gpioPortC.led_hl State
    ${int_org_state}=      Evaluate          int(${raw_org_state})
    
    Execute Command        python "import System; bytes_data = System.Array[System.Byte]([${state}]); frame = Antmicro.Renode.Core.CAN.CANMessageFrame(16772096, bytes_data, True); msg = Antmicro.Renode.Peripherals.CAN.STMCAN.CANMessage(frame); self.Machine['sysbus.can1'].ReceiveCANMessage(msg)"
    
    ${int_exp_led1}=       Evaluate          0 if(int("""${state}""".strip(), 16) == 254) else int(${state})
    ${int_exp_led1}=       Evaluate          ${int_org_state} if(int(${int_exp_led1}) > 1) else int(${int_exp_led1})
    
    Run Keyword   Wait Until Keyword Succeeds    1s     10ms     Led Has Updated    gpioPortC.led_hl   ${int_exp_led1}
    
*** Test Cases ****
Scenario 3.1: Headlights Off
    [Documentation]    Verifies Headlights Work Off
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00

Scenario 3.2: Headlights On
    [Documentation]    Verifies Headlights Work On
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01

Scenario 3.3: Headlights Off On
    [Documentation]    Verifies Headlights Transition Off To On
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01

Scenario 3.4: Headlights On Off
    [Documentation]    Verifies Headlights Transition On To Off
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x00

Scenario 3.5: Headlights Force Off
    [Documentation]    Verifies Headlights Force Off
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFE

Scenario 3.6: Headlights On Force Off
    [Documentation]    Verifies Force Off Overrides On State
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0xFE

Scenario 3.7: Headlights Off Force Off
    [Documentation]    Verifies Force Off While Already Off
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0xFE

Scenario 3.8: Headlights Repeated On
    [Documentation]    Verifies Repeated On Commands
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x01

Scenario 3.9: Headlights Repeated Off
    [Documentation]    Verifies Repeated Off Commands
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x00

Scenario 3.10: Headlights Repeated Force Off
    [Documentation]    Verifies Repeated Force Off Commands
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0xFE

Scenario 3.11: Headlights Toggle Cycle
    [Documentation]    Verifies Off On Off Transition
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x00

Scenario 3.12: Headlights Reverse Toggle Cycle
    [Documentation]    Verifies On Off On Transition
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01

Scenario 3.13: Headlights Rapid Toggle
    [Documentation]    Verifies Multiple State Transitions
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x00

Scenario 3.14: Headlights On Force Off On
    [Documentation]    Verifies Recovery From Force Off
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x01

Scenario 3.15: Headlights Off Force Off On
    [Documentation]    Verifies On Command After Force Off
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x01

Scenario 3.16: Headlights Stress Test
    [Documentation]    Verifies Repeated State Changes Up To Ten Actions
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x00

Scenario 3.17: Headlights Full Transition Coverage
    [Documentation]    Verifies All Supported State Transitions
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0xFE
    
Scenario 3.18: CAN Value 0x02
    [Documentation]    Verify handling of CAN value 0x02
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x02

Scenario 3.19: CAN Value 0x03
    [Documentation]    Verify handling of CAN value 0x03
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x03

Scenario 3.20: CAN Value 0x04
    [Documentation]    Verify handling of CAN value 0x04
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x04

Scenario 3.21: CAN Value 0x05
    [Documentation]    Verify handling of CAN value 0x05
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x05

Scenario 3.22: CAN Value 0x06
    [Documentation]    Verify handling of CAN value 0x06
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x06

Scenario 3.23: CAN Value 0x07
    [Documentation]    Verify handling of CAN value 0x07
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x07

Scenario 3.24: CAN Value 0x08
    [Documentation]    Verify handling of CAN value 0x08
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x08

Scenario 3.25: CAN Value 0x09
    [Documentation]    Verify handling of CAN value 0x09
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x09

Scenario 3.26: CAN Value 0x0A
    [Documentation]    Verify handling of CAN value 0x0A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x0A

Scenario 3.27: CAN Value 0x0B
    [Documentation]    Verify handling of CAN value 0x0B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x0B

Scenario 3.28: CAN Value 0x0C
    [Documentation]    Verify handling of CAN value 0x0C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x0C

Scenario 3.29: CAN Value 0x0D
    [Documentation]    Verify handling of CAN value 0x0D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x0D

Scenario 3.30: CAN Value 0x0E
    [Documentation]    Verify handling of CAN value 0x0E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x0E

Scenario 3.31: CAN Value 0x0F
    [Documentation]    Verify handling of CAN value 0x0F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x0F

Scenario 3.32: CAN Value 0x10
    [Documentation]    Verify handling of CAN value 0x10
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x10

Scenario 3.33: CAN Value 0x11
    [Documentation]    Verify handling of CAN value 0x11
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x11

Scenario 3.34: CAN Value 0x12
    [Documentation]    Verify handling of CAN value 0x12
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x12

Scenario 3.35: CAN Value 0x13
    [Documentation]    Verify handling of CAN value 0x13
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x13

Scenario 3.36: CAN Value 0x14
    [Documentation]    Verify handling of CAN value 0x14
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x14

Scenario 3.37: CAN Value 0x15
    [Documentation]    Verify handling of CAN value 0x15
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x15

Scenario 3.38: CAN Value 0x16
    [Documentation]    Verify handling of CAN value 0x16
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x16

Scenario 3.39: CAN Value 0x17
    [Documentation]    Verify handling of CAN value 0x17
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x17

Scenario 3.40: CAN Value 0x18
    [Documentation]    Verify handling of CAN value 0x18
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x18

Scenario 3.41: CAN Value 0x19
    [Documentation]    Verify handling of CAN value 0x19
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x19

Scenario 3.42: CAN Value 0x1A
    [Documentation]    Verify handling of CAN value 0x1A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x1A

Scenario 3.43: CAN Value 0x1B
    [Documentation]    Verify handling of CAN value 0x1B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x1B

Scenario 3.44: CAN Value 0x1C
    [Documentation]    Verify handling of CAN value 0x1C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x1C

Scenario 3.45: CAN Value 0x1D
    [Documentation]    Verify handling of CAN value 0x1D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x1D

Scenario 3.46: CAN Value 0x1E
    [Documentation]    Verify handling of CAN value 0x1E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x1E

Scenario 3.47: CAN Value 0x1F
    [Documentation]    Verify handling of CAN value 0x1F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x1F

Scenario 3.48: CAN Value 0x20
    [Documentation]    Verify handling of CAN value 0x20
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x20

Scenario 3.49: CAN Value 0x21
    [Documentation]    Verify handling of CAN value 0x21
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x21

Scenario 3.50: CAN Value 0x22
    [Documentation]    Verify handling of CAN value 0x22
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x22

Scenario 3.51: CAN Value 0x23
    [Documentation]    Verify handling of CAN value 0x23
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x23

Scenario 3.52: CAN Value 0x24
    [Documentation]    Verify handling of CAN value 0x24
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x24

Scenario 3.53: CAN Value 0x25
    [Documentation]    Verify handling of CAN value 0x25
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x25

Scenario 3.54: CAN Value 0x26
    [Documentation]    Verify handling of CAN value 0x26
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x26

Scenario 3.55: CAN Value 0x27
    [Documentation]    Verify handling of CAN value 0x27
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x27

Scenario 3.56: CAN Value 0x28
    [Documentation]    Verify handling of CAN value 0x28
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x28

Scenario 3.57: CAN Value 0x29
    [Documentation]    Verify handling of CAN value 0x29
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x29

Scenario 3.58: CAN Value 0x2A
    [Documentation]    Verify handling of CAN value 0x2A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x2A

Scenario 3.59: CAN Value 0x2B
    [Documentation]    Verify handling of CAN value 0x2B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x2B

Scenario 3.60: CAN Value 0x2C
    [Documentation]    Verify handling of CAN value 0x2C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x2C

Scenario 3.61: CAN Value 0x2D
    [Documentation]    Verify handling of CAN value 0x2D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x2D

Scenario 3.62: CAN Value 0x2E
    [Documentation]    Verify handling of CAN value 0x2E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x2E

Scenario 3.63: CAN Value 0x2F
    [Documentation]    Verify handling of CAN value 0x2F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x2F

Scenario 3.64: CAN Value 0x30
    [Documentation]    Verify handling of CAN value 0x30
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x30

Scenario 3.65: CAN Value 0x31
    [Documentation]    Verify handling of CAN value 0x31
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x31

Scenario 3.66: CAN Value 0x32
    [Documentation]    Verify handling of CAN value 0x32
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x32

Scenario 3.67: CAN Value 0x33
    [Documentation]    Verify handling of CAN value 0x33
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x33

Scenario 3.68: CAN Value 0x34
    [Documentation]    Verify handling of CAN value 0x34
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x34

Scenario 3.69: CAN Value 0x35
    [Documentation]    Verify handling of CAN value 0x35
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x35

Scenario 3.70: CAN Value 0x36
    [Documentation]    Verify handling of CAN value 0x36
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x36
    
Scenario 3.71: CAN Value 0x37
    [Documentation]    Verify handling of CAN value 0x37
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x37

Scenario 3.72: CAN Value 0x38
    [Documentation]    Verify handling of CAN value 0x38
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x38

Scenario 3.73: CAN Value 0x39
    [Documentation]    Verify handling of CAN value 0x39
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x39

Scenario 3.74: CAN Value 0x3A
    [Documentation]    Verify handling of CAN value 0x3A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x3A

Scenario 3.75: CAN Value 0x3B
    [Documentation]    Verify handling of CAN value 0x3B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x3B

Scenario 3.76: CAN Value 0x3C
    [Documentation]    Verify handling of CAN value 0x3C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x3C

Scenario 3.77: CAN Value 0x3D
    [Documentation]    Verify handling of CAN value 0x3D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x3D

Scenario 3.78: CAN Value 0x3E
    [Documentation]    Verify handling of CAN value 0x3E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x3E

Scenario 3.79: CAN Value 0x3F
    [Documentation]    Verify handling of CAN value 0x3F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x3F

Scenario 3.80: CAN Value 0x40
    [Documentation]    Verify handling of CAN value 0x40
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x40

Scenario 3.81: CAN Value 0x41
    [Documentation]    Verify handling of CAN value 0x41
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x41

Scenario 3.82: CAN Value 0x42
    [Documentation]    Verify handling of CAN value 0x42
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x42

Scenario 3.83: CAN Value 0x43
    [Documentation]    Verify handling of CAN value 0x43
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x43

Scenario 3.84: CAN Value 0x44
    [Documentation]    Verify handling of CAN value 0x44
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x44

Scenario 3.85: CAN Value 0x45
    [Documentation]    Verify handling of CAN value 0x45
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x45

Scenario 3.86: CAN Value 0x46
    [Documentation]    Verify handling of CAN value 0x46
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x46

Scenario 3.87: CAN Value 0x47
    [Documentation]    Verify handling of CAN value 0x47
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x47

Scenario 3.88: CAN Value 0x48
    [Documentation]    Verify handling of CAN value 0x48
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x48

Scenario 3.89: CAN Value 0x49
    [Documentation]    Verify handling of CAN value 0x49
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x49

Scenario 3.90: CAN Value 0x4A
    [Documentation]    Verify handling of CAN value 0x4A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x4A

Scenario 3.91: CAN Value 0x4B
    [Documentation]    Verify handling of CAN value 0x4B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x4B

Scenario 3.92: CAN Value 0x4C
    [Documentation]    Verify handling of CAN value 0x4C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x4C

Scenario 3.93: CAN Value 0x4D
    [Documentation]    Verify handling of CAN value 0x4D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x4D

Scenario 3.94: CAN Value 0x4E
    [Documentation]    Verify handling of CAN value 0x4E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x4E

Scenario 3.95: CAN Value 0x4F
    [Documentation]    Verify handling of CAN value 0x4F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x4F

Scenario 3.96: CAN Value 0x50
    [Documentation]    Verify handling of CAN value 0x50
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x50

Scenario 3.97: CAN Value 0x51
    [Documentation]    Verify handling of CAN value 0x51
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x51

Scenario 3.98: CAN Value 0x52
    [Documentation]    Verify handling of CAN value 0x52
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x52

Scenario 3.99: CAN Value 0x53
    [Documentation]    Verify handling of CAN value 0x53
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x53

Scenario 3.100: CAN Value 0x54
    [Documentation]    Verify handling of CAN value 0x54
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x54

Scenario 3.101: CAN Value 0x55
    [Documentation]    Verify handling of CAN value 0x55
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x55

Scenario 3.102: CAN Value 0x56
    [Documentation]    Verify handling of CAN value 0x56
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x56

Scenario 3.103: CAN Value 0x57
    [Documentation]    Verify handling of CAN value 0x57
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x57

Scenario 3.104: CAN Value 0x58
    [Documentation]    Verify handling of CAN value 0x58
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x58

Scenario 3.105: CAN Value 0x59
    [Documentation]    Verify handling of CAN value 0x59
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x59

Scenario 3.106: CAN Value 0x5A
    [Documentation]    Verify handling of CAN value 0x5A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x5A

Scenario 3.107: CAN Value 0x5B
    [Documentation]    Verify handling of CAN value 0x5B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x5B

Scenario 3.108: CAN Value 0x5C
    [Documentation]    Verify handling of CAN value 0x5C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x5C

Scenario 3.109: CAN Value 0x5D
    [Documentation]    Verify handling of CAN value 0x5D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x5D

Scenario 3.110: CAN Value 0x5E
    [Documentation]    Verify handling of CAN value 0x5E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x5E

Scenario 3.111: CAN Value 0x5F
    [Documentation]    Verify handling of CAN value 0x5F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x5F

Scenario 3.112: CAN Value 0x60
    [Documentation]    Verify handling of CAN value 0x60
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x60

Scenario 3.113: CAN Value 0x61
    [Documentation]    Verify handling of CAN value 0x61
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x61

Scenario 3.114: CAN Value 0x62
    [Documentation]    Verify handling of CAN value 0x62
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x62

Scenario 3.115: CAN Value 0x63
    [Documentation]    Verify handling of CAN value 0x63
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x63

Scenario 3.116: CAN Value 0x64
    [Documentation]    Verify handling of CAN value 0x64
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x64

Scenario 3.117: CAN Value 0x65
    [Documentation]    Verify handling of CAN value 0x65
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x65

Scenario 3.118: CAN Value 0x66
    [Documentation]    Verify handling of CAN value 0x66
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x66

Scenario 3.119: CAN Value 0x67
    [Documentation]    Verify handling of CAN value 0x67
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x67

Scenario 3.120: CAN Value 0x68
    [Documentation]    Verify handling of CAN value 0x68
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x68
    
Scenario 3.121: CAN Value 0x69
    [Documentation]    Verify handling of CAN value 0x69
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x69

Scenario 3.122: CAN Value 0x6A
    [Documentation]    Verify handling of CAN value 0x6A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x6A

Scenario 3.123: CAN Value 0x6B
    [Documentation]    Verify handling of CAN value 0x6B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x6B

Scenario 3.124: CAN Value 0x6C
    [Documentation]    Verify handling of CAN value 0x6C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x6C

Scenario 3.125: CAN Value 0x6D
    [Documentation]    Verify handling of CAN value 0x6D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x6D

Scenario 3.126: CAN Value 0x6E
    [Documentation]    Verify handling of CAN value 0x6E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x6E

Scenario 3.127: CAN Value 0x6F
    [Documentation]    Verify handling of CAN value 0x6F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x6F

Scenario 3.128: CAN Value 0x70
    [Documentation]    Verify handling of CAN value 0x70
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x70

Scenario 3.129: CAN Value 0x71
    [Documentation]    Verify handling of CAN value 0x71
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x71

Scenario 3.130: CAN Value 0x72
    [Documentation]    Verify handling of CAN value 0x72
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x72

Scenario 3.131: CAN Value 0x73
    [Documentation]    Verify handling of CAN value 0x73
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x73

Scenario 3.132: CAN Value 0x74
    [Documentation]    Verify handling of CAN value 0x74
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x74

Scenario 3.133: CAN Value 0x75
    [Documentation]    Verify handling of CAN value 0x75
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x75

Scenario 3.134: CAN Value 0x76
    [Documentation]    Verify handling of CAN value 0x76
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x76

Scenario 3.135: CAN Value 0x77
    [Documentation]    Verify handling of CAN value 0x77
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x77

Scenario 3.136: CAN Value 0x78
    [Documentation]    Verify handling of CAN value 0x78
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x78

Scenario 3.137: CAN Value 0x79
    [Documentation]    Verify handling of CAN value 0x79
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x79

Scenario 3.138: CAN Value 0x7A
    [Documentation]    Verify handling of CAN value 0x7A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x7A

Scenario 3.139: CAN Value 0x7B
    [Documentation]    Verify handling of CAN value 0x7B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x7B

Scenario 3.140: CAN Value 0x7C
    [Documentation]    Verify handling of CAN value 0x7C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x7C

Scenario 3.141: CAN Value 0x7D
    [Documentation]    Verify handling of CAN value 0x7D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x7D

Scenario 3.142: CAN Value 0x7E
    [Documentation]    Verify handling of CAN value 0x7E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x7E

Scenario 3.143: CAN Value 0x7F
    [Documentation]    Verify handling of CAN value 0x7F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x7F

Scenario 3.144: CAN Value 0x80
    [Documentation]    Verify handling of CAN value 0x80
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x80

Scenario 3.145: CAN Value 0x81
    [Documentation]    Verify handling of CAN value 0x81
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x81

Scenario 3.146: CAN Value 0x82
    [Documentation]    Verify handling of CAN value 0x82
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x82

Scenario 3.147: CAN Value 0x83
    [Documentation]    Verify handling of CAN value 0x83
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x83

Scenario 3.148: CAN Value 0x84
    [Documentation]    Verify handling of CAN value 0x84
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x84

Scenario 3.149: CAN Value 0x85
    [Documentation]    Verify handling of CAN value 0x85
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x85

Scenario 3.150: CAN Value 0x86
    [Documentation]    Verify handling of CAN value 0x86
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x86

Scenario 3.151: CAN Value 0x87
    [Documentation]    Verify handling of CAN value 0x87
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x87

Scenario 3.152: CAN Value 0x88
    [Documentation]    Verify handling of CAN value 0x88
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x88

Scenario 3.153: CAN Value 0x89
    [Documentation]    Verify handling of CAN value 0x89
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x89

Scenario 3.154: CAN Value 0x8A
    [Documentation]    Verify handling of CAN value 0x8A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x8A

Scenario 3.155: CAN Value 0x8B
    [Documentation]    Verify handling of CAN value 0x8B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x8B

Scenario 3.156: CAN Value 0x8C
    [Documentation]    Verify handling of CAN value 0x8C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x8C

Scenario 3.157: CAN Value 0x8D
    [Documentation]    Verify handling of CAN value 0x8D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x8D

Scenario 3.158: CAN Value 0x8E
    [Documentation]    Verify handling of CAN value 0x8E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x8E

Scenario 3.159: CAN Value 0x8F
    [Documentation]    Verify handling of CAN value 0x8F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x8F

Scenario 3.160: CAN Value 0x90
    [Documentation]    Verify handling of CAN value 0x90
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x90

Scenario 3.161: CAN Value 0x91
    [Documentation]    Verify handling of CAN value 0x91
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x91

Scenario 3.162: CAN Value 0x92
    [Documentation]    Verify handling of CAN value 0x92
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x92

Scenario 3.163: CAN Value 0x93
    [Documentation]    Verify handling of CAN value 0x93
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x93

Scenario 3.164: CAN Value 0x94
    [Documentation]    Verify handling of CAN value 0x94
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x94

Scenario 3.165: CAN Value 0x95
    [Documentation]    Verify handling of CAN value 0x95
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x95

Scenario 3.166: CAN Value 0x96
    [Documentation]    Verify handling of CAN value 0x96
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x96

Scenario 3.167: CAN Value 0x97
    [Documentation]    Verify handling of CAN value 0x97
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x97

Scenario 3.168: CAN Value 0x98
    [Documentation]    Verify handling of CAN value 0x98
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x98

Scenario 3.169: CAN Value 0x99
    [Documentation]    Verify handling of CAN value 0x99
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x99

Scenario 3.170: CAN Value 0x9A
    [Documentation]    Verify handling of CAN value 0x9A
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x9A
    
Scenario 3.171: CAN Value 0x9B
    [Documentation]    Verify handling of CAN value 0x9B
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x9B

Scenario 3.172: CAN Value 0x9C
    [Documentation]    Verify handling of CAN value 0x9C
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x9C

Scenario 3.173: CAN Value 0x9D
    [Documentation]    Verify handling of CAN value 0x9D
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x9D

Scenario 3.174: CAN Value 0x9E
    [Documentation]    Verify handling of CAN value 0x9E
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x9E

Scenario 3.175: CAN Value 0x9F
    [Documentation]    Verify handling of CAN value 0x9F
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x9F

Scenario 3.176: CAN Value 0xA0
    [Documentation]    Verify handling of CAN value 0xA0
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA0

Scenario 3.177: CAN Value 0xA1
    [Documentation]    Verify handling of CAN value 0xA1
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA1

Scenario 3.178: CAN Value 0xA2
    [Documentation]    Verify handling of CAN value 0xA2
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA2

Scenario 3.179: CAN Value 0xA3
    [Documentation]    Verify handling of CAN value 0xA3
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA3

Scenario 3.180: CAN Value 0xA4
    [Documentation]    Verify handling of CAN value 0xA4
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA4

Scenario 3.181: CAN Value 0xA5
    [Documentation]    Verify handling of CAN value 0xA5
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA5

Scenario 3.182: CAN Value 0xA6
    [Documentation]    Verify handling of CAN value 0xA6
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA6

Scenario 3.183: CAN Value 0xA7
    [Documentation]    Verify handling of CAN value 0xA7
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA7

Scenario 3.184: CAN Value 0xA8
    [Documentation]    Verify handling of CAN value 0xA8
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA8

Scenario 3.185: CAN Value 0xA9
    [Documentation]    Verify handling of CAN value 0xA9
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xA9

Scenario 3.186: CAN Value 0xAA
    [Documentation]    Verify handling of CAN value 0xAA
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xAA

Scenario 3.187: CAN Value 0xAB
    [Documentation]    Verify handling of CAN value 0xAB
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xAB

Scenario 3.188: CAN Value 0xAC
    [Documentation]    Verify handling of CAN value 0xAC
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xAC

Scenario 3.189: CAN Value 0xAD
    [Documentation]    Verify handling of CAN value 0xAD
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xAD

Scenario 3.190: CAN Value 0xAE
    [Documentation]    Verify handling of CAN value 0xAE
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xAE

Scenario 3.191: CAN Value 0xAF
    [Documentation]    Verify handling of CAN value 0xAF
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xAF

Scenario 3.192: CAN Value 0xB0
    [Documentation]    Verify handling of CAN value 0xB0
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB0

Scenario 3.193: CAN Value 0xB1
    [Documentation]    Verify handling of CAN value 0xB1
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB1

Scenario 3.194: CAN Value 0xB2
    [Documentation]    Verify handling of CAN value 0xB2
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB2

Scenario 3.195: CAN Value 0xB3
    [Documentation]    Verify handling of CAN value 0xB3
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB3

Scenario 3.196: CAN Value 0xB4
    [Documentation]    Verify handling of CAN value 0xB4
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB4

Scenario 3.197: CAN Value 0xB5
    [Documentation]    Verify handling of CAN value 0xB5
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB5

Scenario 3.198: CAN Value 0xB6
    [Documentation]    Verify handling of CAN value 0xB6
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB6

Scenario 3.199: CAN Value 0xB7
    [Documentation]    Verify handling of CAN value 0xB7
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB7

Scenario 3.200: CAN Value 0xB8
    [Documentation]    Verify handling of CAN value 0xB8
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB8

Scenario 3.201: CAN Value 0xB9
    [Documentation]    Verify handling of CAN value 0xB9
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xB9

Scenario 3.202: CAN Value 0xBA
    [Documentation]    Verify handling of CAN value 0xBA
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xBA

Scenario 3.203: CAN Value 0xBB
    [Documentation]    Verify handling of CAN value 0xBB
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xBB

Scenario 3.204: CAN Value 0xBC
    [Documentation]    Verify handling of CAN value 0xBC
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xBC

Scenario 3.205: CAN Value 0xBD
    [Documentation]    Verify handling of CAN value 0xBD
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xBD

Scenario 3.206: CAN Value 0xBE
    [Documentation]    Verify handling of CAN value 0xBE
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xBE

Scenario 3.207: CAN Value 0xBF
    [Documentation]    Verify handling of CAN value 0xBF
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xBF

Scenario 3.208: CAN Value 0xC0
    [Documentation]    Verify handling of CAN value 0xC0
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC0

Scenario 3.209: CAN Value 0xC1
    [Documentation]    Verify handling of CAN value 0xC1
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC1

Scenario 3.210: CAN Value 0xC2
    [Documentation]    Verify handling of CAN value 0xC2
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC2

Scenario 3.211: CAN Value 0xC3
    [Documentation]    Verify handling of CAN value 0xC3
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC3

Scenario 3.212: CAN Value 0xC4
    [Documentation]    Verify handling of CAN value 0xC4
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC4

Scenario 3.213: CAN Value 0xC5
    [Documentation]    Verify handling of CAN value 0xC5
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC5

Scenario 3.214: CAN Value 0xC6
    [Documentation]    Verify handling of CAN value 0xC6
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC6

Scenario 3.215: CAN Value 0xC7
    [Documentation]    Verify handling of CAN value 0xC7
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC7

Scenario 3.216: CAN Value 0xC8
    [Documentation]    Verify handling of CAN value 0xC8
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC8

Scenario 3.217: CAN Value 0xC9
    [Documentation]    Verify handling of CAN value 0xC9
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xC9

Scenario 3.218: CAN Value 0xCA
    [Documentation]    Verify handling of CAN value 0xCA
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xCA

Scenario 3.219: CAN Value 0xCB
    [Documentation]    Verify handling of CAN value 0xCB
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xCB

Scenario 3.220: CAN Value 0xCC
    [Documentation]    Verify handling of CAN value 0xCC
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xCC
    
Scenario 3.221: CAN Value 0xCD
    [Documentation]    Verify handling of CAN value 0xCD
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xCD

Scenario 3.222: CAN Value 0xCE
    [Documentation]    Verify handling of CAN value 0xCE
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xCE

Scenario 3.223: CAN Value 0xCF
    [Documentation]    Verify handling of CAN value 0xCF
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xCF

Scenario 3.224: CAN Value 0xD0
    [Documentation]    Verify handling of CAN value 0xD0
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD0

Scenario 3.225: CAN Value 0xD1
    [Documentation]    Verify handling of CAN value 0xD1
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD1

Scenario 3.226: CAN Value 0xD2
    [Documentation]    Verify handling of CAN value 0xD2
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD2

Scenario 3.227: CAN Value 0xD3
    [Documentation]    Verify handling of CAN value 0xD3
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD3

Scenario 3.228: CAN Value 0xD4
    [Documentation]    Verify handling of CAN value 0xD4
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD4

Scenario 3.229: CAN Value 0xD5
    [Documentation]    Verify handling of CAN value 0xD5
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD5

Scenario 3.230: CAN Value 0xD6
    [Documentation]    Verify handling of CAN value 0xD6
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD6

Scenario 3.231: CAN Value 0xD7
    [Documentation]    Verify handling of CAN value 0xD7
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD7

Scenario 3.232: CAN Value 0xD8
    [Documentation]    Verify handling of CAN value 0xD8
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD8

Scenario 3.233: CAN Value 0xD9
    [Documentation]    Verify handling of CAN value 0xD9
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xD9

Scenario 3.234: CAN Value 0xDA
    [Documentation]    Verify handling of CAN value 0xDA
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xDA

Scenario 3.235: CAN Value 0xDB
    [Documentation]    Verify handling of CAN value 0xDB
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xDB

Scenario 3.236: CAN Value 0xDC
    [Documentation]    Verify handling of CAN value 0xDC
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xDC

Scenario 3.237: CAN Value 0xDD
    [Documentation]    Verify handling of CAN value 0xDD
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xDD

Scenario 3.238: CAN Value 0xDE
    [Documentation]    Verify handling of CAN value 0xDE
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xDE

Scenario 3.239: CAN Value 0xDF
    [Documentation]    Verify handling of CAN value 0xDF
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xDF

Scenario 3.240: CAN Value 0xE0
    [Documentation]    Verify handling of CAN value 0xE0
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE0

Scenario 3.241: CAN Value 0xE1
    [Documentation]    Verify handling of CAN value 0xE1
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE1

Scenario 3.242: CAN Value 0xE2
    [Documentation]    Verify handling of CAN value 0xE2
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE2

Scenario 3.243: CAN Value 0xE3
    [Documentation]    Verify handling of CAN value 0xE3
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE3

Scenario 3.244: CAN Value 0xE4
    [Documentation]    Verify handling of CAN value 0xE4
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE4

Scenario 3.245: CAN Value 0xE5
    [Documentation]    Verify handling of CAN value 0xE5
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE5

Scenario 3.246: CAN Value 0xE6
    [Documentation]    Verify handling of CAN value 0xE6
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE6

Scenario 3.247: CAN Value 0xE7
    [Documentation]    Verify handling of CAN value 0xE7
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE7

Scenario 3.248: CAN Value 0xE8
    [Documentation]    Verify handling of CAN value 0xE8
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE8

Scenario 3.249: CAN Value 0xE9
    [Documentation]    Verify handling of CAN value 0xE9
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xE9

Scenario 3.250: CAN Value 0xEA
    [Documentation]    Verify handling of CAN value 0xEA
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xEA

Scenario 3.251: CAN Value 0xEB
    [Documentation]    Verify handling of CAN value 0xEB
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xEB

Scenario 3.252: CAN Value 0xEC
    [Documentation]    Verify handling of CAN value 0xEC
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xEC

Scenario 3.253: CAN Value 0xED
    [Documentation]    Verify handling of CAN value 0xED
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xED

Scenario 3.254: CAN Value 0xEE
    [Documentation]    Verify handling of CAN value 0xEE
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xEE

Scenario 3.255: CAN Value 0xEF
    [Documentation]    Verify handling of CAN value 0xEF
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xEF

Scenario 3.256: CAN Value 0xF0
    [Documentation]    Verify handling of CAN value 0xF0
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF0

Scenario 3.257: CAN Value 0xF1
    [Documentation]    Verify handling of CAN value 0xF1
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF1

Scenario 3.258: CAN Value 0xF2
    [Documentation]    Verify handling of CAN value 0xF2
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF2

Scenario 3.259: CAN Value 0xF3
    [Documentation]    Verify handling of CAN value 0xF3
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF3

Scenario 3.260: CAN Value 0xF4
    [Documentation]    Verify handling of CAN value 0xF4
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF4

Scenario 3.261: CAN Value 0xF5
    [Documentation]    Verify handling of CAN value 0xF5
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF5

Scenario 3.262: CAN Value 0xF6
    [Documentation]    Verify handling of CAN value 0xF6
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF6

Scenario 3.263: CAN Value 0xF7
    [Documentation]    Verify handling of CAN value 0xF7
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF7

Scenario 3.264: CAN Value 0xF8
    [Documentation]    Verify handling of CAN value 0xF8
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF8

Scenario 3.265: CAN Value 0xF9
    [Documentation]    Verify handling of CAN value 0xF9
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xF9

Scenario 3.266: CAN Value 0xFA
    [Documentation]    Verify handling of CAN value 0xFA
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFA

Scenario 3.267: CAN Value 0xFB
    [Documentation]    Verify handling of CAN value 0xFB
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFB

Scenario 3.268: CAN Value 0xFC
    [Documentation]    Verify handling of CAN value 0xFC
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFC

Scenario 3.269: CAN Value 0xFD
    [Documentation]    Verify handling of CAN value 0xFD
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFD

Scenario 3.270: CAN Value 0xFE
    [Documentation]    Verify handling of CAN value 0xFE
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFE

Scenario 3.271: CAN Value 0xFF
    [Documentation]    Verify handling of CAN value 0xFF
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFF

Scenario 3.272: Repeated ON Command x100
    [Documentation]    Verify state remains ON after 100 ON commands
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0x01
    END

Scenario 3.273: Repeated OFF Command x100
    [Documentation]    Verify state remains OFF after 100 OFF commands
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0x00
    END

Scenario 3.274: Repeated FORCE OFF Command x100
    [Documentation]    Verify state remains FORCE OFF after 100 FORCE OFF commands
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0xFE
    END

Scenario 3.275: Rapid OFF ON Toggle x100
    [Documentation]    Verify rapid toggling stability
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0x00
        Verify Toggle Headlights    0x01
    END

Scenario 3.276: Rapid ON FORCE OFF Toggle x100
    [Documentation]    Verify force off always overrides
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0x01
        Verify Toggle Headlights    0xFE
    END

Scenario 3.277: Rapid OFF FORCE OFF Toggle x100
    [Documentation]    Verify off and force off transition stability
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0x00
        Verify Toggle Headlights    0xFE
    END

Scenario 3.278: Alternating Valid Commands
    [Documentation]    Verify all valid command transitions
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0xFE

Scenario 3.279: Invalid Then ON
    [Documentation]    Verify recovery from invalid command
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x55
    Verify Toggle Headlights    0x01

Scenario 3.280: Invalid Then OFF
    [Documentation]    Verify OFF accepted after invalid command
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xAA
    Verify Toggle Headlights    0x00

Scenario 3.281: Invalid Then FORCE OFF
    [Documentation]    Verify FORCE OFF accepted after invalid command
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xCC
    Verify Toggle Headlights    0xFE

Scenario 3.282: Lowest Valid To Lowest Invalid
    [Documentation]    Transition from OFF to invalid value
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x02

Scenario 3.283: Highest Invalid To ON
    [Documentation]    Verify 0xFF does not affect ON command
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFF
    Verify Toggle Headlights    0x01

Scenario 3.284: Pattern Test 0x55 Repeated
    [Documentation]    Verify repeated alternating bit pattern
    Wait For Line On Uart    System Ready
    Repeat Keyword    20 times    Verify Toggle Headlights    0x55

Scenario 3.285: Pattern Test 0xAA Repeated
    [Documentation]    Verify repeated alternating bit pattern
    Wait For Line On Uart    System Ready
    Repeat Keyword    20 times    Verify Toggle Headlights    0xAA

Scenario 3.286: Pattern Test 0xFF Repeated
    [Documentation]    Verify repeated max value
    Wait For Line On Uart    System Ready
    Repeat Keyword    20 times    Verify Toggle Headlights    0xFF

Scenario 3.287: Pattern Test 0x02 Repeated
    [Documentation]    Verify repeated minimum invalid value
    Wait For Line On Uart    System Ready
    Repeat Keyword    20 times    Verify Toggle Headlights    0x02

Scenario 3.288: Valid Invalid Valid
    [Documentation]    Verify invalid command does not break sequence
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x55
    Verify Toggle Headlights    0x00

Scenario 3.289: ON Invalid FORCE OFF
    [Documentation]    Verify sequence handling
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x7F
    Verify Toggle Headlights    0xFE

Scenario 3.290: FORCE OFF Invalid ON
    [Documentation]    Verify recovery from invalid command
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x88
    Verify Toggle Headlights    0x01

Scenario 3.291: Sequential Boundary Values
    [Documentation]    Verify critical edge values
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x02
    Verify Toggle Headlights    0xFD
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0xFF

Scenario 3.292: Ascending Boundary Sweep
    [Documentation]    Verify edge values in ascending order
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x02
    Verify Toggle Headlights    0x03
    Verify Toggle Headlights    0x04

Scenario 3.293: Descending Boundary Sweep
    [Documentation]    Verify edge values in descending order
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFF
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0xFD
    Verify Toggle Headlights    0xFC

Scenario 3.294: Full Nibble Pattern Test
    [Documentation]    Verify nibble-based patterns
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x0F
    Verify Toggle Headlights    0xF0
    Verify Toggle Headlights    0x33
    Verify Toggle Headlights    0xCC

Scenario 3.295: Walking Bit Up
    [Documentation]    Verify walking 1 pattern
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x02
    Verify Toggle Headlights    0x04
    Verify Toggle Headlights    0x08
    Verify Toggle Headlights    0x10
    Verify Toggle Headlights    0x20
    Verify Toggle Headlights    0x40
    Verify Toggle Headlights    0x80

Scenario 3.296: Walking Bit Down
    [Documentation]    Verify reverse walking bit pattern
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x80
    Verify Toggle Headlights    0x40
    Verify Toggle Headlights    0x20
    Verify Toggle Headlights    0x10
    Verify Toggle Headlights    0x08
    Verify Toggle Headlights    0x04
    Verify Toggle Headlights    0x02
    Verify Toggle Headlights    0x01

Scenario 3.297: Random Pattern Sequence 1
    [Documentation]    Verify random sequence handling
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x13
    Verify Toggle Headlights    0xA7
    Verify Toggle Headlights    0x42
    Verify Toggle Headlights    0xFE

Scenario 3.298: Random Pattern Sequence 2
    [Documentation]    Verify random sequence handling
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x7C
    Verify Toggle Headlights    0x29
    Verify Toggle Headlights    0x01

Scenario 3.299: All Valid Commands Repeated
    [Documentation]    Verify continuous valid operation
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    50
        Verify Toggle Headlights    0x00
        Verify Toggle Headlights    0x01
        Verify Toggle Headlights    0xFE
    END

Scenario 3.300: Invalid Flood x500
    [Documentation]    Verify stability under invalid message flood
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    500
        Verify Toggle Headlights    0x55
    END

Scenario 3.301: Alternate Invalid Flood
    [Documentation]    Flood of alternating invalid commands
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    250
        Verify Toggle Headlights    0x55
        Verify Toggle Headlights    0xAA
    END

Scenario 3.302: Invalid Sweep Near Zero
    [Documentation]    Verify low-byte invalid range
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x02
    Verify Toggle Headlights    0x03
    Verify Toggle Headlights    0x04
    Verify Toggle Headlights    0x05
    Verify Toggle Headlights    0x06

Scenario 3.303: Invalid Sweep Near Force Off
    [Documentation]    Verify high-byte invalid range
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFA
    Verify Toggle Headlights    0xFB
    Verify Toggle Headlights    0xFC
    Verify Toggle Headlights    0xFD

Scenario 3.304: ON OFF FORCE OFF Loop x25
    [Documentation]    State machine endurance
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    25
        Verify Toggle Headlights    0x01
        Verify Toggle Headlights    0x00
        Verify Toggle Headlights    0xFE
    END

Scenario 3.305: ON Recovery After Flood
    [Documentation]    Verify ON after invalid traffic
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0x55
    END
    Verify Toggle Headlights    0x01

Scenario 3.306: OFF Recovery After Flood
    [Documentation]    Verify OFF after invalid traffic
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0xAA
    END
    Verify Toggle Headlights    0x00

Scenario 3.307: FORCE OFF Recovery After Flood
    [Documentation]    Verify FORCE OFF after invalid traffic
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    100
        Verify Toggle Headlights    0xCC
    END
    Verify Toggle Headlights    0xFE

Scenario 3.308: Startup With ON Command
    [Documentation]    Verify first command ON after startup
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01

Scenario 3.309: Startup With OFF Command
    [Documentation]    Verify first command OFF after startup
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00

Scenario 3.310: Startup With FORCE OFF Command
    [Documentation]    Verify first command FORCE OFF after startup
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFE

Scenario 3.311: Startup With Invalid Command
    [Documentation]    Verify invalid first command
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x99

Scenario 3.312: Alternating Valid Invalid Commands
    [Documentation]    Verify alternating traffic
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x55
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0xAA
    Verify Toggle Headlights    0xFE

Scenario 3.313: Boundary Transition 0xFD To 0xFE
    [Documentation]    Verify invalid to valid boundary
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFD
    Verify Toggle Headlights    0xFE

Scenario 3.314: Boundary Transition 0x01 To 0x02
    [Documentation]    Verify valid to invalid boundary
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x02

Scenario 3.315: Maximum Value Before Valid Command
    [Documentation]    Verify handling of 0xFF before ON
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0xFF
    Verify Toggle Headlights    0x01

Scenario 3.316: Minimum Invalid Before OFF
    [Documentation]    Verify handling of 0x02 before OFF
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x02
    Verify Toggle Headlights    0x00

Scenario 3.317: Stress Sequence Length 50
    [Documentation]    Long mixed sequence
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    50
        Verify Toggle Headlights    0x00
        Verify Toggle Headlights    0x55
        Verify Toggle Headlights    0x01
        Verify Toggle Headlights    0xAA
        Verify Toggle Headlights    0xFE
    END

Scenario 3.318: Alternate Force Off Recovery
    [Documentation]    Verify repeated recovery from force off
    Wait For Line On Uart    System Ready
    FOR    ${i}    IN RANGE    25
        Verify Toggle Headlights    0xFE
        Verify Toggle Headlights    0x01
    END

Scenario 3.319: Extended Mixed Traffic
    [Documentation]    Simulate realistic CAN activity
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x22
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0x88
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0xFF

Scenario 3.320: Headlight Command Qualification
    [Documentation]    Final qualification edge-case test
    Wait For Line On Uart    System Ready
    Verify Toggle Headlights    0x00
    Verify Toggle Headlights    0x01
    Verify Toggle Headlights    0xFE
    Verify Toggle Headlights    0x02
    Verify Toggle Headlights    0xFD
    Verify Toggle Headlights    0xFF
    Verify Toggle Headlights    0x55
    Verify Toggle Headlights    0xAA
