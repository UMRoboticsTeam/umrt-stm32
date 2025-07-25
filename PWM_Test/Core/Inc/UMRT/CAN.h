/*
 * CAN.h
 *
 *  Created on: Mar 22, 2025
 *      Author: quinndt
 */

#ifndef INC_UMRT_CAN_H_
#define INC_UMRT_CAN_H_

#include "stm32f4xx_hal.h"
#include "stm32f4xx_hal_can.h"

void CAN_Setup(CAN_HandleTypeDef* hcan);

/**
 * This function must be defined elsewhere.
 * It will only be called in the case that there is no error.
 *
 * References are NOT guaranteed to exist after the call the CAN_Msg_Received ends.
 */
void CAN_MsgReceived(CAN_HandleTypeDef *hcan, CAN_RxHeaderTypeDef *rxheader, uint8_t *rxdata);

#endif /* INC_UMRT_CAN_H_ */
