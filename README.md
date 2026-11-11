# umrt-stm32
Main Project of STM32


# Testing with Renode
Renode is a software that allows for us to test these STM project before we test on a physical board.

## CI/CD Pipeline Requirements
For the automated CI/CD pipeline, any `CMakeLists.txt` will be run as long as it within 2 levels from the top, within all of these folder containing `CMakeLists.txt` the pipeline will look for the `Simulation` folder and any `*.robot` file will be ran. If there is code coverage reports they are expected to be in the `traces` folder and should be saved as `.gz` files.

## Setup Testing
1) Clone this repository
2) Cd into the `PWM_Test` directory
3) Run the following command to be able to test the submitted code locally `docker  run -it --rm -v .:/data <<renode_image>> renode-tester <<path_to_test_file_inside_container>>`

## Setup Simulate Board
1) Clone this repository
2) Cd into the `PWM_Test` directory
3) Run the following command to be able to run your own test `docker  run -it --rm -v .:/data <<renode_image>>`
4) When the container terminal starts run these command to setup the board

```
emulation CreateCANHub "can_network"
mach create "PWM_Test_Simulation1"
machine LoadPlatformDescription @/data/Simulation/STM32F446RETx.repl #This line loads the board
sysbus LoadELF @/data/build/PWM_Test #This line load the software

# Create a window to see UART message output
showAnalyzer sysbus.usart2

# Connect Can Network to Machine
connector Connect sysbus.can1 can_network

# Fixes to allow the program to run on the simulated board
sysbus WriteDoubleWord 0x40006404 0x00000001
sysbus WriteDoubleWord 0x40006400 0x0000000
python "self.Machine['sysbus.can1'].WriteDoubleWord(0x14, 0x2)"
python "self.Machine['sysbus.can1'].UpdateFifo0InterruptLine()"
start
```

5) You can now run your own commands inside this container, below are a few different sample messages

```
# Sample Can Message
python "import System; bytes_data = System.Array[System.Byte]([0x80, 0x7D, 0x80, 0x7D, 0x00, 0x00, 0x00, 0x00]); frame = Antmicro.Renode.Core.CAN.CANMessageFrame(16771456, bytes_data, True); msg = Antmicro.Renode.Peripherals.CAN.STMCAN.CANMessage(frame); self.Machine['sysbus.can1'].ReceiveCANMessage(msg)"

# Sample Inspect Registry
sysbus ReadDoubleWord 0x40000800
```
