/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2023 STMicroelectronics.
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
#include "adc.h"
#include "usart.h"
#include "gpio.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define LEDport GPIOC
#define LEDpin GPIO_PIN_3
#define countof(a) sizeof(a)/sizeof(*(a))
#define Ctr_RT GPIOC
#define Ctr_RT_pin GPIO_PIN_0
#define input1_port GPIOD
#define input1_pin GPIO_PIN_9
#define input2_port GPIOD
#define input2_pin GPIO_PIN_10
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */
char USART1_ReadBuffer;
char USART1_TransmitBuffer[20];
char cmd1='Y';
char cmd2='N';
unsigned char readbuffer[8]="";


int init_ok=0;
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
/* USER CODE BEGIN PFP */

void GetModbusCRC16_Cal(uint8_t *data, uint32_t len) // Modbus-CRC Calculation Method
{
	uint8_t temp;
	uint16_t wcrc = 0xFFFF; // 16-bit crc register pre-set
	uint16_t t1 = 0;
	uint32_t i = 0, j = 0; // counters
	for (i = 0; i < len; i++) // Loop to calculate each data byte
	{
		temp = data[i] & 0X00FF; // Isolate lower 8 bits of data and XOR with crc register
		wcrc ^= temp;            // Store data in crc register
		for (j = 0; j < 8; j++)  // Loop to calculate data
		{
			if (wcrc & 0X0001) // Check if the least significant bit (rightmost) is 1, perform XOR with polynomial if true.
			{
				wcrc >>= 1;   // Shift data right by one bit
				wcrc ^= 0XA001; // Perform XOR with the polynomial
			}
			else // If not 1, shift directly
			{
				wcrc >>= 1; // Shift data right by one bit
			}
		}
	}
	data[6] = wcrc & 0xff;
	data[7] = (wcrc & 0xFF00) >> 8;
    return;
}


void init(unsigned char calibration) // If calibration is 0, do not perform calibration; if it is 1, perform calibration.
{
	unsigned char rs485_init[]={0x01,0x06,0x01,0x00,0x00,0x00,0x00,0x00};
	if(calibration==0)
	{
		rs485_init[5]=0x01;
		GetModbusCRC16_Cal(rs485_init,6);
	}
	else 
	{
		rs485_init[5]=0xA5;
		GetModbusCRC16_Cal(rs485_init,6);
	}
	HAL_GPIO_WritePin(Ctr_RT,Ctr_RT_pin,GPIO_PIN_SET);
	HAL_Delay(2);
	HAL_UART_Transmit(&huart2,rs485_init,8,10);
	HAL_Delay(2);
	HAL_GPIO_WritePin(Ctr_RT,Ctr_RT_pin,GPIO_PIN_RESET);
	return;
}

void Set_speed(uint8_t speed)
{
	unsigned char rs485_speed[]={0x01,0x06,0x01,0x04,0x00,0x00,0x00,0x00};
	rs485_speed[5]=speed;
	GetModbusCRC16_Cal(rs485_speed,6);
	HAL_GPIO_WritePin(Ctr_RT,Ctr_RT_pin,GPIO_PIN_SET);
	HAL_Delay(2);
	HAL_UART_Transmit(&huart2,rs485_speed,8,10);
	HAL_Delay(2);
	HAL_GPIO_WritePin(Ctr_RT,Ctr_RT_pin,GPIO_PIN_RESET);
	return;
}

void Set_force(uint8_t force) // The range of the force parameter is 0x14 to 0x64.
{
	unsigned char rs485_force[]={0x01,0x06,0x01,0x01,0x00,0x00,0x00,0x00};
	rs485_force[5]=force;
	GetModbusCRC16_Cal(rs485_force,6);
	HAL_GPIO_WritePin(Ctr_RT,Ctr_RT_pin,GPIO_PIN_SET);
	HAL_Delay(2);
	HAL_UART_Transmit(&huart2,rs485_force,8,10);
	HAL_Delay(2);
	HAL_GPIO_WritePin(Ctr_RT,Ctr_RT_pin,GPIO_PIN_RESET);
	return;
}
void Set_position(int pos)
{
	uint8_t higher_byte=(pos&0xff00)>>8;
	uint8_t lower_byte=pos&0xff;
	unsigned char rs485_pos[]={0x01,0x06,0x01,0x03,0x00,0x00,0x00,0x00};
	rs485_pos[4]=higher_byte;
	rs485_pos[5]=lower_byte;
	GetModbusCRC16_Cal(rs485_pos,6);
	HAL_GPIO_WritePin(Ctr_RT,Ctr_RT_pin,GPIO_PIN_SET);
	HAL_Delay(2);
	HAL_UART_Transmit(&huart2,rs485_pos,8,10);
	HAL_Delay(2);
	HAL_GPIO_WritePin(Ctr_RT,Ctr_RT_pin,GPIO_PIN_RESET);
	return;
}

//char is_in_position(void)
//{
//	unsigned char rs485_read_position[]={0x01,0x03,0x02,0x01,0x00,0x01,0xd4,0x72};
//	uint8_t buffer;
//	while (buffer!=1)
//	{
//		HAL_UART_Transmit(&huart2,rs485_read_position,8,10);
//		HAL_UART_Receive(&huart2,buffer,1,5);
//	}
//	return 1;
//}

//void HAL_USART_RxCpltCallback(UART_HandleTypeDef *huart)
//{ 
//		if(cmd1==USART1_ReadBuffer)
//		{
//			HAL_GPIO_WritePin(LEDport,LEDpin,GPIO_PIN_RESET);
//			sprintf(USART1_TransmitBuffer,"The LED is on\n");
//			HAL_UART_Transmit(&huart1,(unsigned char *)&USART1_TransmitBuffer,strlen(USART1_TransmitBuffer), 100);
//			USART1_ReadBuffer=0;
//		}
//		else if (cmd2==USART1_ReadBuffer)
//		{
//			sprintf(USART1_TransmitBuffer,"The LED is off\n");
//			HAL_UART_Transmit(&huart1,(unsigned char *)&USART1_TransmitBuffer,strlen(USART1_TransmitBuffer), 100);
//			HAL_GPIO_WritePin(LEDport,LEDpin,GPIO_PIN_SET);
//			USART1_ReadBuffer=0;
//		}
//		while(HAL_UART_Receive_IT(&huart1,(unsigned char *)&USART1_ReadBuffer,1)!=HAL_OK);	
//}


/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
	
// example code for controlling the robot hand
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
  MX_USART1_UART_Init();
  MX_USART2_UART_Init();
  MX_ADC2_Init();
  /* USER CODE BEGIN 2 */
		init(0);
//		Set_speed(100);
//		Set_force(20);
		
		unsigned char position[4]="";
		char Txbuffer[20]="";
		int value=0;
		int pos=1000;
		int last_pos=1000;
		GPIO_PinState input1;
		GPIO_PinState input2;
		char last_cmd;
		char new_cmd;
		
//	HAL_UART_Receive_IT(&huart1,(unsigned char *)&USART1_ReadBuffer,1);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1)
  {
//		HAL_ADC_Start(&hadc2);
//		HAL_ADC_PollForConversion(&hadc2,1000);
//		value=HAL_ADC_GetValue(&hadc2);
//		value=value*1000/4096;
//		value=(value-3)/10*10;
//		sprintf(Txbuffer,"Value=%d\n",value);
//		HAL_UART_Transmit(&huart1,(uint8_t *)Txbuffer,sizeof(Txbuffer),500);
//		pos=value;
//		if(pos==last_pos)
//		{
//			HAL_UART_Transmit(&huart1,position,sizeof(position),100);
//			continue;
//		}
//		else
//		{
//			HAL_UART_Transmit(&huart1,position,sizeof(position),100);
//			Set_position(pos);
//			last_pos=pos;
//		}
		input1=HAL_GPIO_ReadPin(input1_port,input1_pin);
		input2=HAL_GPIO_ReadPin(input2_port,input2_pin);
		
//		if((input1==GPIO_PIN_RESET)&&(input2==GPIO_PIN_RESET))
//		{
//			new_cmd=0;
//		}
//		else
		if((input1==GPIO_PIN_SET)&&(input2==GPIO_PIN_RESET))
		{
			new_cmd=1;
		}
		else if((input1==GPIO_PIN_SET&&input2==GPIO_PIN_SET))
		{
			new_cmd=3;
		}
		
		if(new_cmd==last_cmd)
		{
			continue;
		}
		else
		{
			last_cmd=new_cmd;
			
			if(last_cmd==0)
			{
				Set_speed(100);
				Set_force(50);
				Set_position(1000);
			}
			else if(last_cmd==1)
			{
				Set_speed(100);
				Set_force(50);
				Set_position(1000);
			}
			else if(last_cmd==3)
			{
				Set_speed(100);
				Set_force(50);
				Set_position(0);
			}
			//is_in_position();
			HAL_Delay(1000);
		}
    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
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
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLM = 25;
  RCC_OscInitStruct.PLL.PLLN = 336;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
  RCC_OscInitStruct.PLL.PLLQ = 4;
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
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV4;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV2;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_5) != HAL_OK)
  {
    Error_Handler();
  }
}

/* USER CODE BEGIN 4 */

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

#ifdef  USE_FULL_ASSERT
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
