/*
 * CAN.c
 *
 * Functions to deal with the Controller Area Network (CAN) protocol.
 *
 *  Created on: Mar 22, 2025
 *      Author: quinndt
 */

#include "stm32f4xx_hal.h"
#include "stm32f4xx_hal_can.h"
#include "UMRT/CAN.h"
#include <stdio.h>


// Define all CAN callbacks for interrupts:
void HAL_CAN_ErrorCallback(CAN_HandleTypeDef* hcan) {
	printf("\r\n==== CAN ERROR INTERRUPT %08lX\r\n", hcan->ErrorCode);
	if ((hcan->ErrorCode&HAL_CAN_ERROR_EWG)==HAL_CAN_ERROR_EWG) printf("  -> has bit: Protocol Error Warning (HAL_CAN_ERROR_EWG)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_EPV)==HAL_CAN_ERROR_EPV) printf("  -> has bit: Error Passive (HAL_CAN_ERROR_EPV)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_BOF)==HAL_CAN_ERROR_BOF) printf("  -> has bit: Bus-off error (HAL_CAN_ERROR_BOF)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_STF)==HAL_CAN_ERROR_STF) printf("  -> has bit: Stuff error (HAL_CAN_ERROR_STF)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_FOR)==HAL_CAN_ERROR_FOR) printf("  -> has bit: Form error (HAL_CAN_ERROR_FOR)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_ACK)==HAL_CAN_ERROR_ACK) printf("  -> has bit: Acknowledgment error (HAL_CAN_ERROR_ACK)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_BR)==HAL_CAN_ERROR_BR) printf("  -> has bit: Bit recessive error (HAL_CAN_ERROR_BR)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_BD)==HAL_CAN_ERROR_BD) printf("  -> has bit: Bit dominant error (HAL_CAN_ERROR_BD)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_CRC)==HAL_CAN_ERROR_CRC) printf("  -> has bit: CRC error (HAL_CAN_ERROR_CRC)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_RX_FOV0)==HAL_CAN_ERROR_RX_FOV0) printf("  -> has bit: Rx FIFO0 overrun error (HAL_CAN_ERROR_RX_FOV0)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_RX_FOV1)==HAL_CAN_ERROR_RX_FOV1) printf("  -> has bit: Rx FIFO1 overrun error (HAL_CAN_ERROR_RX_FOV1)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_TX_ALST0)==HAL_CAN_ERROR_TX_ALST0) printf("  -> has bit: TxMailbox 0 transmit failure due to arbitration lost (HAL_CAN_ERROR_TX_ALST0)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_TX_TERR0)==HAL_CAN_ERROR_TX_TERR0) printf("  -> has bit: TxMailbox 0 transmit failure due to transmit error (HAL_CAN_ERROR_TX_TERR0)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_TX_ALST1)==HAL_CAN_ERROR_TX_ALST1) printf("  -> has bit: TxMailbox 1 transmit failure due to arbitration lost (HAL_CAN_ERROR_TX_ALST1)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_TX_TERR1)==HAL_CAN_ERROR_TX_TERR1) printf("  -> has bit: TxMailbox 1 transmit failure due to transmit error (HAL_CAN_ERROR_TX_TERR1)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_TX_ALST2)==HAL_CAN_ERROR_TX_ALST2) printf("  -> has bit: TxMailbox 2 transmit failure due to arbitration lost (HAL_CAN_ERROR_TX_ALST2)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_TX_TERR2)==HAL_CAN_ERROR_TX_TERR2) printf("  -> has bit: TxMailbox 2 transmit failure due to transmit error (HAL_CAN_ERROR_TX_TERR2)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_TIMEOUT)==HAL_CAN_ERROR_TIMEOUT) printf("  -> has bit: Timeout error (HAL_CAN_ERROR_TIMEOUT)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_NOT_INITIALIZED)==HAL_CAN_ERROR_NOT_INITIALIZED) printf("  -> has bit: Peripheral not initialized (HAL_CAN_ERROR_NOT_INITIALIZED)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_NOT_READY)==HAL_CAN_ERROR_NOT_READY) printf("  -> has bit: Peripheral not ready (HAL_CAN_ERROR_NOT_READY)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_NOT_STARTED)==HAL_CAN_ERROR_NOT_STARTED) printf("  -> has bit: Peripheral not started (HAL_CAN_ERROR_NOT_STARTED)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_PARAM)==HAL_CAN_ERROR_PARAM) printf("  -> has bit: Parameter error (HAL_CAN_ERROR_PARAM)\r\n");
	if ((hcan->ErrorCode&HAL_CAN_ERROR_INTERNAL)==HAL_CAN_ERROR_INTERNAL) printf("  -> has bit: Internal error (HAL_CAN_ERROR_INTERNAL)\r\n");
	printf("====\r\n");
}


// receive headers and data: array in case we have 2 FIFO (first in; first out) queues.
CAN_RxHeaderTypeDef rxheader[1];
uint8_t rxdata[1][8];

HAL_StatusTypeDef CAN_Transmit(const CAN_HandleTypeDef *hcan, const CAN_TxHeaderTypeDef *pHeader, const uint8_t aData[], uint32_t *pTxMailbox);

void HAL_CAN_RxFifo0MsgPendingCallback(CAN_HandleTypeDef* hcan) {
	printf("HAL_CAN_RxFifo0MsgPendingCallback\r\n");
	HAL_StatusTypeDef result = HAL_CAN_GetRxMessage(hcan, 0, &rxheader[0], rxdata[0]);
	if (result != HAL_OK) {
		printf("HAL_CAN_RxFifo0MsgPendingCallback function HAL_CAN_GetRxMessage failed with result 0x%02X\r\n", result);
		return;
	}

	if (rxheader[0].IDE == CAN_ID_EXT) {
		printf("  -> ID (ext) %lu (%08x)\r\n", rxheader[0].ExtId, rxheader[0].ExtId);
	} else {
		printf("  -> ID (std) %lu (%03x)\r\n", rxheader[0].StdId, rxheader[0].StdId);
	}
	printf("  -> LENGTH %lu\r\n", rxheader[0].DLC);
	printf("     DATA == (%02x%02x %02x%02x %02x%02x %02x%02x)\r\n",
			rxdata[0][0], rxdata[0][1], rxdata[0][2], rxdata[0][3], rxdata[0][4], rxdata[0][5], rxdata[0][6], rxdata[0][7], rxdata[0][8]);
	printf("  -> DATA[0] % 3u (%02x)\r\n", rxdata[0][0], rxdata[0][0]);
	printf("  -> DATA[1] % 3u (%02x)\r\n", rxdata[0][1], rxdata[0][1]);
	printf("  -> DATA[2] % 3u (%02x)\r\n", rxdata[0][2], rxdata[0][2]);
	printf("  -> DATA[3] % 3u (%02x)\r\n", rxdata[0][3], rxdata[0][3]);
	printf("  -> DATA[4] % 3u (%02x)\r\n", rxdata[0][4], rxdata[0][4]);
	printf("  -> DATA[5] % 3u (%02x)\r\n", rxdata[0][5], rxdata[0][5]);
	printf("  -> DATA[6] % 3u (%02x)\r\n", rxdata[0][6], rxdata[0][6]);
	printf("  -> DATA[7] % 3u (%02x)\r\n", rxdata[0][7], rxdata[0][7]);

	CAN_MsgReceived(hcan, &rxheader[0], rxdata[0]);
}

void HAL_CAN_RxFifo0FullCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_RxFifo0FullCallback\r\n"); }
void HAL_CAN_RxFifo1MsgPendingCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_RxFifo1MsgPendingCallback\r\n"); }
void HAL_CAN_RxFifo1FullCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_RxFifo1FullCallback\r\n"); }
void HAL_CAN_SleepCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_SleepCallback\r\n"); }
void HAL_CAN_WakeUpFromRxMsgCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_WakeUpFromRxMsgCallback\r\n"); }
void HAL_CAN_TxMailbox0CompleteCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_TxMailbox0CompleteCallback\r\n"); }
void HAL_CAN_TxMailbox1CompleteCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_TxMailbox1CompleteCallback\r\n"); }
void HAL_CAN_TxMailbox2CompleteCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_TxMailbox2CompleteCallback\r\n"); }
void HAL_CAN_TxMailbox0AbortCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_TxMailbox0AbortCallback\r\n"); }
void HAL_CAN_TxMailbox1AbortCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_TxMailbox1AbortCallback\r\n"); }
void HAL_CAN_TxMailbox2AbortCallback(CAN_HandleTypeDef* hcan) { printf("HAL_CAN_TxMailbox2AbortCallback\r\n"); }


void CAN_ActivateNotification(CAN_HandleTypeDef* hcan, uint32_t id, const char* name) {
	HAL_StatusTypeDef result = HAL_CAN_ActivateNotification(hcan, id);
	if (result == HAL_OK) {
		printf("Activated notification for '%s'!\r\n", name);
	} else {
		printf("ERROR: Could not register CAN callback '%s' (result: %i; error: %08lX)\r\n", name, result, hcan->ErrorCode);
	}
}

void CAN_Setup(CAN_HandleTypeDef* hcan) {
	// Activate all notifications
	CAN_ActivateNotification(hcan, CAN_IT_ERROR, "ERROR");
	CAN_ActivateNotification(hcan, CAN_IT_LAST_ERROR_CODE, "LAST_ERROR_CODE");
	CAN_ActivateNotification(hcan, CAN_IT_TX_MAILBOX_EMPTY, "TX_MAILBOX_EMPTY");
	CAN_ActivateNotification(hcan, CAN_IT_RX_FIFO0_MSG_PENDING, "RX_FIFO0_MSG_PENDING");
	CAN_ActivateNotification(hcan, CAN_IT_RX_FIFO0_FULL, "RX_FIFO0_FULL");
	CAN_ActivateNotification(hcan, CAN_IT_RX_FIFO0_OVERRUN, "RX_FIFO0_OVERRUN");
	CAN_ActivateNotification(hcan, CAN_IT_RX_FIFO1_MSG_PENDING, "RX_FIFO1_MSG_PENDING");
	CAN_ActivateNotification(hcan, CAN_IT_RX_FIFO1_FULL, "RX_FIFO1_FULL");
	CAN_ActivateNotification(hcan, CAN_IT_RX_FIFO1_OVERRUN, "RX_FIFO1_OVERRUN");
	CAN_ActivateNotification(hcan, CAN_IT_WAKEUP, "WAKEUP");
	CAN_ActivateNotification(hcan, CAN_IT_SLEEP_ACK, "SLEEP_ACK");
	CAN_ActivateNotification(hcan, CAN_IT_ERROR_WARNING, "ERROR_WARNING");
	CAN_ActivateNotification(hcan, CAN_IT_ERROR_PASSIVE, "ERROR_PASSIVE");
	CAN_ActivateNotification(hcan, CAN_IT_BUSOFF, "BUSOFF");


	// Setup packet filtering

	CAN_FilterTypeDef canfilterconfig;

	canfilterconfig.FilterActivation = CAN_FILTER_ENABLE;
	canfilterconfig.FilterBank = 0;  // which filter bank to use from the assigned ones
	canfilterconfig.FilterFIFOAssignment = CAN_FILTER_FIFO0;
	canfilterconfig.FilterIdHigh = 0;
	canfilterconfig.FilterIdLow = 0;
	// since the mask = 0, all packets are received
	canfilterconfig.FilterMaskIdHigh = 0;
	canfilterconfig.FilterMaskIdLow = 0;
	canfilterconfig.FilterMode = CAN_FILTERMODE_IDMASK;
	canfilterconfig.FilterScale = CAN_FILTERSCALE_32BIT;
	canfilterconfig.SlaveStartFilterBank = 27;  // how many filters to assign to the CAN1 (master can)

	HAL_CAN_ConfigFilter(hcan, &canfilterconfig);
}

