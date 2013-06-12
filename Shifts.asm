;    AFakeProgrammer - firmware for AT89C4051 microcontroller, turning it into programmer for the devices of the same type
;
;    Copyright (C) 2013  Stanislav Hadjiiski, Martin Yordanov
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;
;
; Файлът съдържа подпрограми, зареждащи съдържанието на 8 битовия shift регистър. Използване:
; контрол над индикатора за комуникация, контрол над програмното напрежение, контрол над битовете,
; кодиращи текущото действие. Конвенция за битовете на регистъра:
; |       0     |      1      |      2      |      3      |   4    |       5      |      6      |      7      |
; |  Control 1  |  Control 2  |  Control 3  |  Control 4  |  LED   |  PROG_PULSE  |  Voltage 1  |  Voltage 2  |
;=================================================
; PROG_PULSE е свързан с пин P3.2 на устройството, което се програмира. При подаване на пулсове върху него се запрограмира
; подадения на P1 байт в паметта. За подаване на пулсове се използва подпрограмата SHIFT_REGISTER_PULSE_PROG
;=================================================
; Контрол на напрежението чрез Voltage битовете:
; Voltage 1  |  Voltage 2  | Напрежение [V]
;     0      |      0      |      0
;     0      |      1      |      5
;     1      |      0      |      12	(но се използва комбинация 1 1)
;     1      |      1      |      12
;
; Реализация - чрез 2 NPN транзистора за ключове, един инвертор, два диода против обратен ток и захранващи напрежения 0, 5, 12 V
;===============================================================================================================

;========= Инициализира shift register-a: напрежение на RST 0V, ниско положение на всички контролни битове (READ SIGNATURE режим)
;		Не засяга LED индикатора за комуникация и PROG бита. (Трябва да бъдат променени ръчно)
SHIFT_REGISTER_INIT:		CLR	SHIFT_CLOCK
				CLR	SHIFT_DATA
				CLR	SHIFT_STROBE
				ANL	SHIFT_REGISTER, #00001100B ;сваля всички битове освен тези за LED и PROG
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя програмното напрежение на 0 V (0 0)=====
SHIFT_REGISTER_VOLTAGE_0V:	ANL	SHIFT_REGISTER, #11111100B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя програмното напрежение на 5 V (0 1)=====
SHIFT_REGISTER_VOLTAGE_5V:	ANL	SHIFT_REGISTER, #11111101B
				ORL	SHIFT_REGISTER, #00000001B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя програмното напрежение на 12 V (1 1)=====
SHIFT_REGISTER_VOLTAGE_12V:	ORL	SHIFT_REGISTER, #00000011B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя 4 бита в shift register-a - на регистъра режим на записване =======
;=========			0 1 1 1			===========
SHIFT_LOAD_CONTROL_WRITE:	ANL	SHIFT_REGISTER, #01111111B
				ORL	SHIFT_REGISTER, #01110000B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя 4 бита в shift register-a - кодират режим на четене         =======
;=========			0 0 1 1			===========
SHIFT_LOAD_CONTROL_READ:	ANL	SHIFT_REGISTER, #00111111B
				ORL	SHIFT_REGISTER, #00110000B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя 4 бита в shift register-a - кодират LOCK BIT 1 режим (неизползвано)=
;=========			1 1 1 1			============
SHIFT_LOAD_CONTROL_LOCK1:	ORL	SHIFT_REGISTER, #11110000B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя 4 бита в shift register-a - кодират LOCK BIT 1 режим (неизползвано)=
;=========			1 1 0 0			============
SHIFT_LOAD_CONTROL_LOCK2:	ANL	SHIFT_REGISTER, #11001111B
				ORL	SHIFT_REGISTER, #11000000B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя 4 бита в shift register-a - кодират ERASE режим              =======
;=========			1 0 0 0			============
SHIFT_LOAD_CONTROL_ERASE:	ANL	SHIFT_REGISTER, #10001111B
				ORL	SHIFT_REGISTER, #10000000B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя 4 бита в shift register-a - кодират READ SIGNATURE режим (неизползвано)
;				0 0 0 0			===============
SHIFT_LOAD_CONTROL_READ_SIG:	ANL	SHIFT_REGISTER, #00001111B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя 1 бит в шифт регистъра - светва индикацията за комуникация ============
;=========	светнато = 0 в регистъра
SHIFT_LED_ON:			ANL	SHIFT_REGISTER, #11110111B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Променя 1 бит в шифт регистъра - гаси индикацията за комуникация ============
;=========	загасено = 1 в регистъра
SHIFT_LED_OFF:			ORL	SHIFT_REGISTER, #00001000B
				CALL	APPLY_SHIFT_REGISTER
				RET

;========= Подава логическа единица на PROG пина на устройството за програмиране. Може да се използва при
; Изтриване на паметта на устройството, запис в него и т.н. Ако се използва за запис, преди извикване трябва да се
; избере желания адрес за запрограмиране, чрез подаване на пулсове на PROG_CLOCK и да се запише желания
; байт в PROG_BYTE.
SHIFT_REGISTER_SET_PROG:	ORL	SHIFT_REGISTER, #00000100B
				CALL	APPLY_SHIFT_REGISTER
				RET

;======== Подава логическа нула на PROG пина. В комбинация с SHIFT_REGISTER_SET_PROG служи за подаване на пулсове на PROG
SHIFT_REGISTER_CLR_PROG:	ANL	SHIFT_REGISTER, #11111011B
				CALL	APPLY_SHIFT_REGISTER
				RET

; При извикване записва в действителния shift register стойността на SHIFT_REGISTER променливата
APPLY_SHIFT_REGISTER:		PUSH	ACC
				MOV	A, R0
				PUSH	ACC

				CLR	SHIFT_CLOCK
				CLR	SHIFT_STROBE
				CLR	SHIFT_DATA
				MOV	A, SHIFT_REGISTER
				MOV	R0, #8
SEND_SHIFT_NEXT:		RRC	A	; Измества битовете надясно. Мести най-десния бит в carry флага.
				MOV	SHIFT_DATA, C
				; пулс за "shift"-ване на битовете в регистъра и зареждане на новия
				SETB	SHIFT_CLOCK
				CLR	SHIFT_CLOCK
				;докато не бъдат заредени и 8те бита
				DJNZ	R0, SEND_SHIFT_NEXT

				SETB	SHIFT_STROBE ;паралелно преместване на битовете след серийното им зареждане

				POP	ACC
				MOV	R0, A
				POP	ACC
				RET