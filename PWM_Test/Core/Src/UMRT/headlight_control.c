#include "UMRT/headlight_control.h"

static Headlight_State_t s_currentState = HEADLIGHT_STATE_OFF;

static void Headlight_SetPin(uint8_t on)
{
    GPIO_PinState pinState;
#if HEADLIGHT_ACTIVE_HIGH
    pinState = on ? GPIO_PIN_SET : GPIO_PIN_RESET;
#else
    pinState = on ? GPIO_PIN_RESET : GPIO_PIN_SET;
#endif
    HAL_GPIO_WritePin(HEADLIGHT_GPIO_Port, HEADLIGHT_GPIO_Pin, pinState);
}

void Headlight_Init(void)
{
    /* GPIO mode/speed/pull-up are set by CubeMX's MX_GPIO_Init(); this just
     * forces a known-safe state (off) regardless of pin reset default. */
    s_currentState = HEADLIGHT_STATE_OFF;
    Headlight_SetPin(0);
}

void Headlight_HandleCanFrame(const CAN_RxHeaderTypeDef *rxHeader, const uint8_t *rxData)
{
    /* Must be an extended-ID frame -- ExtId is meaningless otherwise. */
    if (rxHeader->IDE != CAN_ID_EXT) {
        return;
    }

    /* Match on PGN only; SA is masked out because it varies by sender. */
    if ((rxHeader->ExtId & FRONT_HEADLIGHT_COMMAND_MASK) != FRONT_HEADLIGHT_COMMAND_ID) {
        return;
    }

    if (rxHeader->DLC < 1) {
        return; /* malformed frame -- nothing to decode */
    }

    uint8_t stateByte = rxData[0];

    switch (stateByte) {
        case HEADLIGHT_STATE_OFF:
            s_currentState = HEADLIGHT_STATE_OFF;
            Headlight_SetPin(0);
            break;

        case HEADLIGHT_STATE_ON:
            s_currentState = HEADLIGHT_STATE_ON;
            Headlight_SetPin(1);
            break;

        case HEADLIGHT_STATE_NOT_AVAILABLE:
            /* Sender has nothing to say this cycle. Hold whatever was last
             * commanded -- don't touch the pin. */
            break;

        case HEADLIGHT_STATE_ERROR:
            /* Reserved value. Fail safe (lights off) rather than guess at
             * what an "error" state should mean electrically. */
            s_currentState = HEADLIGHT_STATE_ERROR;
            Headlight_SetPin(0);
            break;

        default:
            /* Out-of-spec byte (0x02-0xFD). Ignore it and hold the last
             * valid state instead of acting on garbage. */
            break;
    }
}

Headlight_State_t Headlight_GetCurrentState(void)
{
    return s_currentState;
}
