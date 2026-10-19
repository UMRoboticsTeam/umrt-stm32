#ifndef HEADLIGHT_CONTROL_H
#define HEADLIGHT_CONTROL_H

#include "stm32f4xx_hal.h"
#include <stdint.h>

/* --- CAN identity: Front_Headlight_Command -----------------------------
 * PGN 0xFFEC, Priority 6, PDU2 (proprietary broadcast, no destination
 * address). SA is masked out of the match below because it varies by
 * sender and isn't part of the PGN -- don't compare against it.
 *
 * TODO: confirm 0xFFEC is still the group extension actually merged into
 * umrt-can-definitions before relying on this. It was free as of our last
 * check but that repo is shared -- verify against the live Messages.sym.
 * ------------------------------------------------------------------- */
#define FRONT_HEADLIGHT_COMMAND_ID    0x18FFEC00UL   /* SA bits zeroed, placeholder */
#define FRONT_HEADLIGHT_COMMAND_MASK  0x1FFFFF00UL   /* match everything except SA */

/* --- Wiring ------------------------------------------------------------
 * TODO: replace with your actual CubeMX pin. If you label the pin
 * "HEADLIGHT" in the Pinout view, CubeMX will generate HEADLIGHT_GPIO_Port
 * / HEADLIGHT_Pin in main.h and you can drop these two lines entirely.
 * ------------------------------------------------------------------- */
#define HEADLIGHT_GPIO_Port   GPIOC
#define HEADLIGHT_GPIO_Pin    GPIO_PIN_0

/* Set to 0 if your driver stage is active-low (e.g. the GPIO sinks current
 * through an NPN/MOSFET gate to pull the load's control line low, rather
 * than sourcing it high). Check this on the bench before trusting it --
 * getting this backwards means "off" commands turn the lights on. */
#define HEADLIGHT_ACTIVE_HIGH  1

/* Front_Headlight_State byte values, per Messages.sym. */
typedef enum {
    HEADLIGHT_STATE_OFF           = 0x00,
    HEADLIGHT_STATE_ON            = 0x01,
    HEADLIGHT_STATE_ERROR         = 0xFE,
    HEADLIGHT_STATE_NOT_AVAILABLE = 0xFF,
} Headlight_State_t;

/* Call once at startup, after MX_GPIO_Init(). */
void Headlight_Init(void);

/* Call from your CAN receive path (e.g. HAL_CAN_RxFifo0MsgPendingCallback,
 * or wherever you currently dispatch on RxHeader.ExtId) for every received
 * frame. It's a no-op if the frame isn't this PGN. */
void Headlight_HandleCanFrame(const CAN_RxHeaderTypeDef *rxHeader, const uint8_t *rxData);

/* Last commanded state, for logging/telemetry if you want it. */
Headlight_State_t Headlight_GetCurrentState(void);

#endif /* HEADLIGHT_CONTROL_H */
