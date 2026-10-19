/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <stdio.h>
#include <stdbool.h>
#include <math.h>
#include "UMRT/CAN.h"
#include "UMRT/messages.h"
#include "UMRT/headlight_control.h"

#include "../../ECUAL/DC_MOTOR/DC_MOTOR.h"

#include "assert.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define DC_MOTOR1    0
#define DC_MOTOR2    1
#define DC_MOTOR3    2
#define DC_MOTOR4    3

#define PI_VALUE 3.14159265358979323846

typedef struct {
	int16_t motor1;
	int16_t motor2;
	int16_t motor3;
	int16_t motor4;
} MotorMessage;

#define SOIL_SENSOR_FRAME_ID  (0x18FFEB00u)

typedef struct {
    int16_t temperature; // raw, 0.1 degC/bit
    int16_t humidity;    // raw, 0.1 %RH/bit
    int16_t ec;          // raw, unscaled (see note below)
    int16_t ph;          // raw, 0.1 pH/bit
} SoilSensorMessage;

void PrintSoilSensor(SoilSensorMessage msg) {
    printf("Soil: T=%.1f C  H=%.1f %%RH  EC=%d  pH=%.1f\r\n",
           msg.temperature * 0.1f,
           msg.humidity * 0.1f,
           msg.ec * 0.1f,
           msg.ph * 0.1f);
}

int16_t PWM_RES[] = {0, 0, 0, 0};
int16_t N_PWM_RES[] = {0, 0, 0, 0};
float motor_speed[] = {0, 0, 0, 0};

float MAX_RPM = 1.0f/155.0f;
float WHEEL_DIA = 1.0f/(PI_VALUE * 200.0f);
float SPEED_SCALE = 0.085f;

volatile float   rpm[4]        = {0.0f, 0.0f, 0.0f, 0.0f};
volatile int32_t prev_count[4] = {0, 0, 0, 0};
volatile float wheel_rpm[4] = {0.0f, 0.0f, 0.0f, 0.0f};  /* post-gear-ratio RPM, one per encoder_timers[] entry */

volatile int32_t last_delta[4] = {0, 0, 0, 0};  /* counts moved last sample    */

#define FEEDBACK_TX_PERIOD_MS 100u   /* 10 Hz — tune this alone, independent of RPM sampling */
static uint32_t last_feedback_tx_ms = 0;


void PID_UpdateTargetSpeed(MotorMessage targetSpeed) {
//	motor_speed[0] = targetSpeed.motor1 * MAX_RPM * 60.0f * WHEEL_DIA * 4096.0f * SPEED_SCALE;
//	motor_speed[1] = targetSpeed.motor2 * MAX_RPM * 60.0f * WHEEL_DIA * 4096.0f * SPEED_SCALE;
//	motor_speed[2] = targetSpeed.motor3 * MAX_RPM * 60.0f * WHEEL_DIA * 4096.0f * SPEED_SCALE;
//	motor_speed[3] = targetSpeed.motor4 * MAX_RPM * 60.0f * WHEEL_DIA * 4096.0f * SPEED_SCALE;

	motor_speed[0] = targetSpeed.motor1 * MAX_RPM * 4096.0f;
	motor_speed[1] = targetSpeed.motor2 * MAX_RPM * 4096.0f;
	motor_speed[2] = targetSpeed.motor3 * MAX_RPM * 4096.0f;
	motor_speed[3] = targetSpeed.motor4 * MAX_RPM * 4096.0f;

	PWM_RES[0] = (int16_t) motor_speed[0];
	PWM_RES[1] = (int16_t) motor_speed[1];
	PWM_RES[2] = (int16_t) motor_speed[2];
	PWM_RES[3] = (int16_t) motor_speed[3];

//	PWM_RES[0] = (int16_t) (motor_speed[0] * MAX_RPM * 60.0f * WHEEL_DIA) * 4096.0f;
//	PWM_RES[1] = (int16_t) (motor_speed[1] * MAX_RPM * 60.0f * WHEEL_DIA) * 4096.0f;
//	PWM_RES[2] = (int16_t) (motor_speed[2] * MAX_RPM * 60.0f * WHEEL_DIA) * 4096.0f;
//	PWM_RES[3] = (int16_t) (motor_speed[3] * MAX_RPM * 60.0f * WHEEL_DIA) * 4096.0f;
}

void CAN_MsgReceived(CAN_HandleTypeDef *hcan, CAN_RxHeaderTypeDef *rxheader, uint8_t *rxdata)
{


    uint32_t id = (rxheader->IDE == CAN_ID_STD) ? rxheader->StdId : rxheader->ExtId;
    switch (id)
    {
    //Legacy
    //Jetson
    case 0xFF10:
    case 0x110:
        if (rxheader->DLC != 8) return;

        MotorMessage targetSpeed;
        targetSpeed.motor1 = ((int16_t*)rxdata)[0];
        targetSpeed.motor2 = ((int16_t*)rxdata)[1];
        targetSpeed.motor3 = ((int16_t*)rxdata)[2];
        targetSpeed.motor4 = ((int16_t*)rxdata)[3];

        PID_UpdateTargetSpeed(targetSpeed);
        break;

    case MESSAGES_ROVER_SPEED_CONTROL_FRAME_ID:
        {

            struct messages_rover_speed_control_t cmd;
            if (messages_rover_speed_control_unpack(&cmd, rxdata, rxheader->DLC) != 0) {
                printf("Rover_Speed_Control: unpack failed (DLC=%u)\r\n", rxheader->DLC);
                return;
            }

            double left_rpm  = messages_rover_speed_control_left_angular_velocity_decode(cmd.left_angular_velocity);
            double right_rpm = messages_rover_speed_control_right_angular_velocity_decode(cmd.right_angular_velocity);

            //printf("left rpm: %.2f, right rpm: %.2f\r\n", left_rpm, right_rpm);

            MotorMessage targetSpeed;
            targetSpeed.motor1 = left_rpm;   // left, front
            targetSpeed.motor3 = left_rpm;   // left, rear
            targetSpeed.motor2 = right_rpm;  // right, front
            targetSpeed.motor4 = right_rpm;  // right, rear

            PID_UpdateTargetSpeed(targetSpeed);
            break;
        }

    case SOIL_SENSOR_FRAME_ID:
    {
        if (rxheader->DLC != 8) return;

        SoilSensorMessage soil;
        soil.temperature = ((int16_t*)rxdata)[0];
        soil.humidity    = ((int16_t*)rxdata)[1];
        soil.ec          = ((int16_t*)rxdata)[2];
        soil.ph          = ((int16_t*)rxdata)[3];

        //PrintSoilSensor(soil);
        break;
    }

    //Headlights
    case MESSAGES_FRONT_HEADLIGHT_COMMAND_FRAME_ID:
    {
    	 Headlight_HandleCanFrame(rxheader, rxdata);

    	 break;
    }

    }
}

//void CAN_MsgReceived(CAN_HandleTypeDef *hcan, CAN_RxHeaderTypeDef *rxheader, uint8_t *rxdata) {
//	// For CAN IDs, try to stay in the range: 0xFF00-0xFFFF or 0x1FF00-0x1FFFF.
//	// This fits better in J1939 if we decide to move to that system.
//	printf("CAN_MsgReceived\r\n");
//	switch (rxheader->ExtId) {
//	case 0xFF10: // Motor control
//		assert(rxheader->DLC == 8);
//		printf("Motor Message received!\r\n");
//
//		MotorMessage targetSpeed = {0};
//		targetSpeed.motor1 = ((int16_t*)rxdata)[0];
//		targetSpeed.motor2 = ((int16_t*)rxdata)[1];
//		targetSpeed.motor3 = ((int16_t*)rxdata)[2];
//		targetSpeed.motor4 = ((int16_t*)rxdata)[3];
//
////		printf("  --> targetSpeed.motor1 == %i (%04x)\r\n", targetSpeed.motor1, targetSpeed.motor1);
////		printf("  --> targetSpeed.motor2 == %i (%04x)\r\n", targetSpeed.motor2, targetSpeed.motor2);
////		printf("  --> targetSpeed.motor3 == %i (%04x)\r\n", targetSpeed.motor3, targetSpeed.motor3);
////		printf("  --> targetSpeed.motor4 == %i (%04x)\r\n", targetSpeed.motor4, targetSpeed.motor4);
//
//		PID_UpdateTargetSpeed(targetSpeed);
//
//		break;
//	case 0xFF40: // Headlights
//		printf("Headlights Message received!\r\n");
//	}
//}
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
CAN_HandleTypeDef hcan1;

TIM_HandleTypeDef htim1;
TIM_HandleTypeDef htim2;
TIM_HandleTypeDef htim3;
TIM_HandleTypeDef htim4;
TIM_HandleTypeDef htim12;

UART_HandleTypeDef huart2;

/* USER CODE BEGIN PV */
// ADC_ChannelConfTypeDef sConfig = {0};

//TIM_HandleTypeDef *encoder_timers[4] = {&htim1, &htim3, &htim4, &htim5};

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_TIM3_Init(void);
static void MX_CAN1_Init(void);
static void MX_TIM2_Init(void);
static void MX_TIM1_Init(void);
static void MX_TIM12_Init(void);
static void MX_TIM4_Init(void);
/* USER CODE BEGIN PFP */

uint8_t crc8_j1850(const uint8_t *data, size_t len);
static HAL_StatusTypeDef Send_Rover_Speed_Feedback(float rpm_front_left, float rpm_front_right,
                                                     float rpm_rear_left, float rpm_rear_right);

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
int __io_putchar(int ch) {
  HAL_StatusTypeDef result = HAL_UART_Transmit(&huart2, (uint8_t *)&ch, 1, 10);
  if (result != HAL_OK) {
	  // Backup to indicate printing isn't working.
	  HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
  }
  return ch;
}
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */


  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_USART2_UART_Init();
  MX_TIM3_Init();
  MX_CAN1_Init();
  MX_TIM2_Init();
  MX_TIM1_Init();
  MX_TIM12_Init();
  MX_TIM4_Init();
  /* USER CODE BEGIN 2 */
  CAN_Setup(&hcan1);
  Headlight_Init();

  printf("starting...");
  HAL_StatusTypeDef status = HAL_CAN_Start(&hcan1);
  if (status == HAL_OK) printf("success!\r\n");
  	  else
  	  {
  		  printf("failed! :( status == %u\r\n", status);
		  if (status == HAL_ERROR) HAL_CAN_ErrorCallback(&hcan1);
  	  }

  //HAL_ADCEx_Calibration_Start(&hadc1);
  DC_MOTOR_Init(DC_MOTOR1);
  DC_MOTOR_Init(DC_MOTOR2);
  DC_MOTOR_Init(DC_MOTOR3);
  DC_MOTOR_Init(DC_MOTOR4);
  DC_MOTOR_Start(DC_MOTOR1, DIR_CW, 0);
  DC_MOTOR_Start(DC_MOTOR2, DIR_CW, 0);
  DC_MOTOR_Start(DC_MOTOR3, DIR_CW, 0);
  DC_MOTOR_Start(DC_MOTOR4, DIR_CW, 0);

  HAL_TIM_Encoder_Start(&htim1, TIM_CHANNEL_ALL);
  HAL_TIM_Encoder_Start(&htim3, TIM_CHANNEL_ALL);
  HAL_TIM_Encoder_Start(&htim4, TIM_CHANNEL_ALL);
  //HAL_TIM_Encoder_Start(&htim5, TIM_CHANNEL_ALL);

  HAL_TIM_Base_Start(&htim12);

//  for (int i = 0; i < 4; i++) {
//      prev_count[i] = (int32_t)__HAL_TIM_GET_COUNTER(encoder_timers[i]);
//  }


  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
	//Read Pot. ADC CH4 & Set Motor 1 Speed
//	sConfig.Channel = ADC_CHANNEL_4;
//	HAL_ADC_ConfigChannel(&hadc1, &sConfig);
//	HAL_ADC_Start(&hadc1);
//	HAL_ADC_PollForConversion(&hadc1, 1);
//	AD1_RES = HAL_ADC_GetValue(&hadc1);
//	AD1_RES = 0.5 * AD1_RES;
//	if (AD1_RES < 0.05*4095)
//	{
//		DC_MOTOR_Stop(DC_MOTOR1);
//	}
//	else
//	{
//		DC_MOTOR_Set_Speed(DC_MOTOR1, AD1_RES);
//	}
//
//	//Motor 2
//	sConfig.Channel = ADC_CHANNEL_7;
//	HAL_ADC_ConfigChannel(&hadc1, &sConfig);
//	HAL_ADC_Start(&hadc1);
//	HAL_ADC_PollForConversion(&hadc1, 1);
//	AD2_RES = HAL_ADC_GetValue(&hadc1);
//	if (AD2_RES < 0.05*4095)
//	{
//		DC_MOTOR_Stop(DC_MOTOR2);
//	}
//	else
//	{
//		DC_MOTOR_Set_Speed(DC_MOTOR2, AD2_RES);
//	}

	//Motor L
	if (PWM_RES[0] < 0)
	{
		DC_MOTOR_Set_Dir(DC_MOTOR1, DIR_CCW);
		DC_MOTOR_Set_Dir(DC_MOTOR3, DIR_CCW);
		N_PWM_RES[0] = -1 * PWM_RES[0];
		N_PWM_RES[2] = -1 * PWM_RES[2];

		if (N_PWM_RES[0] < 0.05*4095)
		{
			DC_MOTOR_Stop(DC_MOTOR1);
			DC_MOTOR_Stop(DC_MOTOR3);
		}
		else
		{
			DC_MOTOR_Set_Speed(DC_MOTOR1, N_PWM_RES[0]);
			DC_MOTOR_Set_Speed(DC_MOTOR3, N_PWM_RES[2]);
		}
	}
	else
	{
		DC_MOTOR_Set_Dir(DC_MOTOR1, DIR_CW);
		DC_MOTOR_Set_Dir(DC_MOTOR3, DIR_CW);

		if (PWM_RES[0] < 0.05*4095)
		{
			DC_MOTOR_Stop(DC_MOTOR1);
			DC_MOTOR_Stop(DC_MOTOR3);
		}
		else
		{
			DC_MOTOR_Set_Speed(DC_MOTOR1, PWM_RES[0]);
			DC_MOTOR_Set_Speed(DC_MOTOR3, PWM_RES[2]);
		}
	}


	//Motor R
	if (PWM_RES[1] < 0)
	{
		DC_MOTOR_Set_Dir(DC_MOTOR2, DIR_CW);
		DC_MOTOR_Set_Dir(DC_MOTOR4, DIR_CW);
		N_PWM_RES[1] = -1 * PWM_RES[1];
		N_PWM_RES[3] = -1 * PWM_RES[3];

		if (N_PWM_RES[1] < 0.05*4095)
		{
			DC_MOTOR_Stop(DC_MOTOR2);
			DC_MOTOR_Stop(DC_MOTOR4);
		}
		else
		{
			DC_MOTOR_Set_Speed(DC_MOTOR2, N_PWM_RES[1]);
			DC_MOTOR_Set_Speed(DC_MOTOR4, N_PWM_RES[3]);
		}
	}
	else
	{
		DC_MOTOR_Set_Dir(DC_MOTOR2, DIR_CCW);
		DC_MOTOR_Set_Dir(DC_MOTOR4, DIR_CCW);

		if (PWM_RES[1] < 0.05*4095)
		{
			DC_MOTOR_Stop(DC_MOTOR2);
			DC_MOTOR_Stop(DC_MOTOR4);
		}
		else
		{
			DC_MOTOR_Set_Speed(DC_MOTOR2, PWM_RES[1]);
			DC_MOTOR_Set_Speed(DC_MOTOR4, PWM_RES[3]);
		}
	}

	static uint16_t prev_tick = 0;
	uint16_t now      = (uint16_t)__HAL_TIM_GET_COUNTER(&htim12);
	uint16_t dt_ticks = now - prev_tick;

//	if (dt_ticks >= 200)
//	{
//	    prev_tick = now;
//	    float dt_sec = dt_ticks * 0.0001f;
//
//	    for (int i = 0; i < 4; i++)
//	    {
//	        uint16_t count16 = (uint16_t)__HAL_TIM_GET_COUNTER(encoder_timers[i]);
//	        uint16_t diff16   = (uint16_t)(count16 - (uint16_t)prev_count[i]);
//	        int32_t  delta    = (int32_t)(int16_t)diff16;
//	        prev_count[i]     = (int32_t)count16;
//	        last_delta[i]     = delta;
//
//	        float rev     = (float)delta / 1024.0f;
//	        float raw_rpm = (rev / dt_sec) * 60.0f;
//	        rpm[i]        = rpm[i] * 0.8f + raw_rpm * 0.2f;
//	        wheel_rpm[i]  = rpm[i] / 77.0f;
//
//	        //printf("wheel %d: %.2f rpm\r\n", i, wheel_rpm[i]);
//	    }
//
//	    uint32_t now_ms = HAL_GetTick();
//	    if ((now_ms - last_feedback_tx_ms) >= FEEDBACK_TX_PERIOD_MS)
//	    {
//	        last_feedback_tx_ms = now_ms;
//	        //Send_Rover_Speed_Feedback(wheel_rpm[0], wheel_rpm[1], wheel_rpm[2], wheel_rpm[3]);
//	    }
//	}
  }

  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE3);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLM = 16;
  RCC_OscInitStruct.PLL.PLLN = 336;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV4;
  RCC_OscInitStruct.PLL.PLLQ = 2;
  RCC_OscInitStruct.PLL.PLLR = 2;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_2) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief CAN1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_CAN1_Init(void)
{

  /* USER CODE BEGIN CAN1_Init 0 */

  /* USER CODE END CAN1_Init 0 */

  /* USER CODE BEGIN CAN1_Init 1 */

  /* USER CODE END CAN1_Init 1 */
  hcan1.Instance = CAN1;
  hcan1.Init.Prescaler = 21;
  hcan1.Init.Mode = CAN_MODE_NORMAL;
  hcan1.Init.SyncJumpWidth = CAN_SJW_1TQ;
  hcan1.Init.TimeSeg1 = CAN_BS1_2TQ;
  hcan1.Init.TimeSeg2 = CAN_BS2_1TQ;
  hcan1.Init.TimeTriggeredMode = DISABLE;
  hcan1.Init.AutoBusOff = DISABLE;
  hcan1.Init.AutoWakeUp = DISABLE;
  hcan1.Init.AutoRetransmission = DISABLE;
  hcan1.Init.ReceiveFifoLocked = DISABLE;
  hcan1.Init.TransmitFifoPriority = DISABLE;
  if (HAL_CAN_Init(&hcan1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN CAN1_Init 2 */

  /* USER CODE END CAN1_Init 2 */

}

/**
  * @brief TIM1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM1_Init(void)
{

  /* USER CODE BEGIN TIM1_Init 0 */

  /* USER CODE END TIM1_Init 0 */

  TIM_Encoder_InitTypeDef sConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM1_Init 1 */

  /* USER CODE END TIM1_Init 1 */
  htim1.Instance = TIM1;
  htim1.Init.Prescaler = 0;
  htim1.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim1.Init.Period = 65535;
  htim1.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim1.Init.RepetitionCounter = 0;
  htim1.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  sConfig.EncoderMode = TIM_ENCODERMODE_TI12;
  sConfig.IC1Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC1Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC1Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC1Filter = 4;
  sConfig.IC2Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC2Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC2Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC2Filter = 4;
  if (HAL_TIM_Encoder_Init(&htim1, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim1, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM1_Init 2 */

  /* USER CODE END TIM1_Init 2 */

}

/**
  * @brief TIM2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM2_Init(void)
{

  /* USER CODE BEGIN TIM2_Init 0 */

  /* USER CODE END TIM2_Init 0 */

  TIM_ClockConfigTypeDef sClockSourceConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};
  TIM_OC_InitTypeDef sConfigOC = {0};

  /* USER CODE BEGIN TIM2_Init 1 */

  /* USER CODE END TIM2_Init 1 */
  htim2.Instance = TIM2;
  htim2.Init.Prescaler = 0;
  htim2.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim2.Init.Period = 4294967295;
  htim2.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim2.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  if (HAL_TIM_Base_Init(&htim2) != HAL_OK)
  {
    Error_Handler();
  }
  sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;
  if (HAL_TIM_ConfigClockSource(&htim2, &sClockSourceConfig) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_TIM_PWM_Init(&htim2) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim2, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sConfigOC.OCMode = TIM_OCMODE_PWM1;
  sConfigOC.Pulse = 0;
  sConfigOC.OCPolarity = TIM_OCPOLARITY_HIGH;
  sConfigOC.OCFastMode = TIM_OCFAST_DISABLE;
  if (HAL_TIM_PWM_ConfigChannel(&htim2, &sConfigOC, TIM_CHANNEL_1) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_TIM_PWM_ConfigChannel(&htim2, &sConfigOC, TIM_CHANNEL_2) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_TIM_PWM_ConfigChannel(&htim2, &sConfigOC, TIM_CHANNEL_3) != HAL_OK)
  {
    Error_Handler();
  }
  if (HAL_TIM_PWM_ConfigChannel(&htim2, &sConfigOC, TIM_CHANNEL_4) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM2_Init 2 */

  /* USER CODE END TIM2_Init 2 */
  HAL_TIM_MspPostInit(&htim2);

}

/**
  * @brief TIM3 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM3_Init(void)
{

  /* USER CODE BEGIN TIM3_Init 0 */

  /* USER CODE END TIM3_Init 0 */

  TIM_Encoder_InitTypeDef sConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM3_Init 1 */

  /* USER CODE END TIM3_Init 1 */
  htim3.Instance = TIM3;
  htim3.Init.Prescaler = 0;
  htim3.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim3.Init.Period = 65535;
  htim3.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim3.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  sConfig.EncoderMode = TIM_ENCODERMODE_TI12;
  sConfig.IC1Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC1Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC1Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC1Filter = 4;
  sConfig.IC2Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC2Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC2Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC2Filter = 4;
  if (HAL_TIM_Encoder_Init(&htim3, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim3, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM3_Init 2 */

  /* USER CODE END TIM3_Init 2 */

}

/**
  * @brief TIM4 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM4_Init(void)
{

  /* USER CODE BEGIN TIM4_Init 0 */

  /* USER CODE END TIM4_Init 0 */

  TIM_Encoder_InitTypeDef sConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM4_Init 1 */

  /* USER CODE END TIM4_Init 1 */
  htim4.Instance = TIM4;
  htim4.Init.Prescaler = 0;
  htim4.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim4.Init.Period = 65535;
  htim4.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim4.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  sConfig.EncoderMode = TIM_ENCODERMODE_TI12;
  sConfig.IC1Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC1Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC1Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC1Filter = 4;
  sConfig.IC2Polarity = TIM_ICPOLARITY_RISING;
  sConfig.IC2Selection = TIM_ICSELECTION_DIRECTTI;
  sConfig.IC2Prescaler = TIM_ICPSC_DIV1;
  sConfig.IC2Filter = 4;
  if (HAL_TIM_Encoder_Init(&htim4, &sConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim4, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM4_Init 2 */

  /* USER CODE END TIM4_Init 2 */

}

/**
  * @brief TIM12 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM12_Init(void)
{

  /* USER CODE BEGIN TIM12_Init 0 */

  /* USER CODE END TIM12_Init 0 */

  TIM_ClockConfigTypeDef sClockSourceConfig = {0};

  /* USER CODE BEGIN TIM12_Init 1 */

  /* USER CODE END TIM12_Init 1 */
  htim12.Instance = TIM12;
  htim12.Init.Prescaler = 8399;
  htim12.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim12.Init.Period = 65535;
  htim12.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim12.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  if (HAL_TIM_Base_Init(&htim12) != HAL_OK)
  {
    Error_Handler();
  }
  sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;
  if (HAL_TIM_ConfigClockSource(&htim12, &sClockSourceConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM12_Init 2 */

  /* USER CODE END TIM12_Init 2 */

}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{

  /* USER CODE BEGIN USART2_Init 0 */

  /* USER CODE END USART2_Init 0 */

  /* USER CODE BEGIN USART2_Init 1 */

  /* USER CODE END USART2_Init 1 */
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 115200;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART2_Init 2 */

  /* USER CODE END USART2_Init 2 */

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOC, GPIO_PIN_0, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOA, GPIO_PIN_4|LD2_Pin|GPIO_PIN_7, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOB, GPIO_PIN_0|GPIO_PIN_4|GPIO_PIN_5, GPIO_PIN_RESET);

  /*Configure GPIO pin : B1_Pin */
  GPIO_InitStruct.Pin = B1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_FALLING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(B1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : PC0 */
  GPIO_InitStruct.Pin = GPIO_PIN_0;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  /*Configure GPIO pins : PA4 LD2_Pin PA7 */
  GPIO_InitStruct.Pin = GPIO_PIN_4|LD2_Pin|GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pin : PA6 */
  GPIO_InitStruct.Pin = GPIO_PIN_6;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_RISING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  /*Configure GPIO pins : PB0 PB4 PB5 */
  GPIO_InitStruct.Pin = GPIO_PIN_0|GPIO_PIN_4|GPIO_PIN_5;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */

uint8_t crc8_j1850(const uint8_t *data, size_t len)
{
    uint8_t crc = 0xFF;
    for (size_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (int bit = 0; bit < 8; bit++) {
            crc = (crc & 0x80) ? (uint8_t)((crc << 1) ^ 0x1D)
                                : (uint8_t)(crc << 1);
        }
    }
    return crc ^ 0xFF;
}

static uint8_t feedback_msg_counter = 0;

static HAL_StatusTypeDef Send_Rover_Speed_Feedback(float rpm_front_left, float rpm_front_right,
                                                     float rpm_rear_left, float rpm_rear_right)
{
    CAN_TxHeaderTypeDef txHeader = {0};
    uint8_t  txData[8];
    uint32_t txMailbox;
    struct messages_rover_speed_feedback_t fb = {0};

    /* Clamp to the encodable physical range before handing off to the generated
       encoders - the encode functions do the scale/offset math, not the clamping. */
    float vel_fl = rpm_front_left  < 0.0f ? 0.0f : (rpm_front_left  > 4015.875f ? 4015.875f : rpm_front_left);
    float vel_fr = rpm_front_right < 0.0f ? 0.0f : (rpm_front_right > 4015.875f ? 4015.875f : rpm_front_right);
    float dis_l  = fabsf(rpm_front_left  - rpm_rear_left);
    float dis_r  = fabsf(rpm_front_right - rpm_rear_right);
    if (dis_l > 31.25f) dis_l = 31.25f;
    if (dis_r > 31.25f) dis_r = 31.25f;

    fb.left_angular_velocity  = messages_rover_speed_feedback_left_angular_velocity_encode(vel_fl);
    fb.right_angular_velocity = messages_rover_speed_feedback_right_angular_velocity_encode(vel_fr);
    fb.left_disagreement      = messages_rover_speed_feedback_left_disagreement_encode(dis_l);
    fb.right_disagreement     = messages_rover_speed_feedback_right_disagreement_encode(dis_r);

    feedback_msg_counter = (feedback_msg_counter + 1) % 251;  /* Message_Counter: /max:250 */
    fb.message_counter = feedback_msg_counter;                /* factor 1 / offset 0 - no encode needed */
    fb.crc = 0;                                                /* placeholder; real CRC written below */

    if (messages_rover_speed_feedback_pack(txData, &fb, sizeof(txData)) < 0) {
        return HAL_ERROR;   /* buffer too small - shouldn't happen with a fixed 8-byte array */
    }

    txData[7] = crc8_j1850(txData, 7);   /* <-- your existing CRC function, overwrites the placeholder */

    txHeader.ExtId = MESSAGES_ROVER_SPEED_FEEDBACK_FRAME_ID;
    txHeader.IDE   = CAN_ID_EXT;
    txHeader.RTR   = CAN_RTR_DATA;
    txHeader.DLC   = 8;
    txHeader.TransmitGlobalTime = DISABLE;

    return HAL_CAN_AddTxMessage(&hcan1, &txHeader, txData, &txMailbox);
}

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
