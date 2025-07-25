#include "DC_MOTOR.h"

const DC_MOTOR_CfgType DC_MOTOR_CfgParam[DC_MOTOR_UNITS] =
{
    // DC MOTOR 1 Configurations
    {
    GPIOA,
    GPIOB,
    GPIO_PIN_7,
    GPIO_PIN_13,
    TIM3,
    TIM_CHANNEL_1,
    84,
    DC_MOTOR_F_PWM,
    DC_MOTOR_PWM_RES
    },
	// DC MOTOR 2 Configurations
	{
	GPIOA,
	GPIOB,
	GPIO_PIN_8,
	GPIO_PIN_13,
	TIM3,
	TIM_CHANNEL_2,
	84,
	DC_MOTOR_F_PWM,
	DC_MOTOR_PWM_RES
	},
	// DC MOTOR 3 Configurations
	{
	GPIOA,
	GPIOB,
	GPIO_PIN_9,
	GPIO_PIN_13,
	TIM3,
	TIM_CHANNEL_3,
	84,
	DC_MOTOR_F_PWM,
	DC_MOTOR_PWM_RES
	},
	// DC MOTOR 4 Configurations
	{
	GPIOA,
	GPIOB,
	GPIO_PIN_10,
	GPIO_PIN_13,
	TIM3,
	TIM_CHANNEL_4,
	84,
	DC_MOTOR_F_PWM,
	DC_MOTOR_PWM_RES
	}
};
