#include "DC_MOTOR.h"

const DC_MOTOR_CfgType DC_MOTOR_CfgParam[DC_MOTOR_UNITS] =
{
    // DC MOTOR 1 Configurations
    {
    GPIOA,
    GPIOB,
    GPIO_PIN_4,
    GPIO_PIN_13,
    TIM2,
    TIM_CHANNEL_1,
    84,
    DC_MOTOR_F_PWM,
    DC_MOTOR_PWM_RES
    },
	// DC MOTOR 2 Configurations
	{
	GPIOB,
	GPIOB,
	GPIO_PIN_4,
	GPIO_PIN_13,
	TIM2,
	TIM_CHANNEL_2,
	84,
	DC_MOTOR_F_PWM,
	DC_MOTOR_PWM_RES
	},
	// DC MOTOR 3 Configurations
	{
	GPIOB,
	GPIOB,
	GPIO_PIN_0,
	GPIO_PIN_13,
	TIM2,
	TIM_CHANNEL_3,
	84,
	DC_MOTOR_F_PWM,
	DC_MOTOR_PWM_RES
	},
	// DC MOTOR 4 Configurations
	{
	GPIOB,
	GPIOB,
	GPIO_PIN_5,
	GPIO_PIN_13,
	TIM2,
	TIM_CHANNEL_4,
	84,
	DC_MOTOR_F_PWM,
	DC_MOTOR_PWM_RES
	}
};
