;    AFakeProgrammer - frimware for AT89C4051 microcontroller, turning it into programmer for the devices of the same type
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
;Различни възможни начала на записа
MARK_RECORD	EQU	3AH			;':' Маркира начало на data record
MARK_VERIFY	EQU	2BH			;'+' Маркира начало на команда за четене на памет
MARK_ERASE	EQU	2DH			;'-' Маркира начало на команда за триене на памет
MARK_DEBUG	EQU	3FH			;'?' Маркира начало на DEBUG команда
MARK_GENERAL	EQU	3DH			;'=' Маркира команда за настройка или discover команда

;=======================Проверка на типа команда по първия байт (RCVD_CMD_MARK) и ===========
;=======================подходяща реакция в зависимост от командата==========================
RECV_CMD_CHECK:		PUSH	ACC	;запазване на акумулатора
			MOV	A, RCVD_CMD_MARK
			CJNE	A, #MARK_DEBUG, NOT_DEBUG
			;получаваме DEBUG команда? проверката е в CMD_utils_debug.asm
			CALL	RECV_CMD_DEBUG
			SJMP	CHK_CMD_END

NOT_DEBUG:		CJNE	A, #MARK_RECORD, NOT_RECORD
			;получаваме команда за запис?
			CALL	RECV_CMD_WRITE
			SJMP	CHK_CMD_END

NOT_RECORD:		CJNE	A, #MARK_VERIFY, NOT_VERIFY
			;получаваме команда за прочитане на ROM?
			CALL RECV_CMD_VERIFY
			SJMP	CHK_CMD_END

NOT_VERIFY:		CJNE	A, #MARK_ERASE, NOT_ERASE
			;получаваме команда за изтриване на ROM?
			CALL	RECV_CMD_ERASE
			SJMP	CHK_CMD_END

NOT_ERASE:		CJNE	A, #MARK_GENERAL, NOT_GENERAL
			;получаваме general команда?
			CALL	RECV_CMD_GENERAL
			SJMP	CHK_CMD_END

			;Получаваме непозната или грешна команда
			;Изчакваме да се получат и следващите 3 байта, дефиниращи командата:
NOT_GENERAL:		MOV	A, #3
			CALL	UTIL_CLEAR_INPUT
			;Изпращаме сигнал за непозната команда
			CALL SEND_CMD_UNKNOWN
CHK_CMD_END:		POP	ACC
			RET

;=======================Проверява дали получаваме General команда и реагира спрямо нея=======
;=======================	DSC	LRG	SML	=====================================
RECV_CMD_GENERAL:	PUSH	ACC
			PUSH	B
			JNB	RI, $
			MOV	A, SBUF
			MOV	B, #2
			CLR	RI
			CJNE	A, #'D', GENERAL_NOT_DSC
			;продължаваме проверка за DSC команда
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'S', GENERAL_UNKNOWN
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'C', GENERAL_UNKNOWN
			;получили сме discover команда. Отговаряме и излизаме
			CALL	SEND_DISCOVER_ANS
			SJMP	GENERAL_CMD_END

GENERAL_NOT_DSC:	CJNE	A, #'L', GENERAL_NOT_LRG
			;продължаваме проверка за LRG команда
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'R', GENERAL_UNKNOWN
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'G', GENERAL_UNKNOWN
			;получили сме large команда (4KB). Записваме в TARGET_4KB, отговаряме и излизаме
			SETB	TARGET_4KB
			CALL	SEND_CMD_AKNOWLEDGE
			SJMP	GENERAL_CMD_END

GENERAL_NOT_LRG:	CJNE	A, #'S', GENERAL_UNKNOWN
			;продължаваме проверка за SML команда
			;продължаваме проверка за LRG команда
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'M', GENERAL_UNKNOWN
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'L', GENERAL_UNKNOWN
			;получили сме small (2KB) команда. Записваме в TARGET_4KB, отговаряме и излизаме
			CLR	TARGET_4KB
			CALL	SEND_CMD_AKNOWLEDGE
			SJMP	GENERAL_CMD_END

GENERAL_UNKNOWN:	MOV	A, B
			CALL	UTIL_CLEAR_INPUT
GENERAL_INPUT_CLEARED:	CALL	SEND_CMD_UNKNOWN
			SJMP	GENERAL_CMD_END
GENERAL_CMD_AKN:	CALL	SEND_CMD_AKNOWLEDGE
GENERAL_CMD_END:	POP	B
			POP	ACC
			RET

;=======================Проверка и изпълнение на команда за прочитане на ROM=================
;=======================		RED			=============================
RECV_CMD_VERIFY:	PUSH	ACC
			PUSH	B
			JNB	RI, $				;Проверка дали е получена правилна команда
			MOV	A, SBUF
			CLR	RI
			MOV	B, #2
			CJNE	A, #'V', ERR_RECV_CMD_VERIFY
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'E', ERR_RECV_CMD_VERIFY
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'R', ERR_RECV_CMD_VERIFY
			;Командата е правилна - изпращане на AKNOWLEDGE и изпълнение на командата
			CALL	SEND_CMD_AKNOWLEDGE
			CALL	ACTION_VERIFY
			SJMP	VERIFY_END
			;На серийния порт не е получено точно '+VER' - изпращане на съобщение за
			;неизвестна команда
ERR_RECV_CMD_VERIFY:	MOV	A, B
			CALL	UTIL_CLEAR_INPUT
			CALL	SEND_CMD_UNKNOWN
VERIFY_END:		POP	B
			POP	ACC
			RET

;=======================Проверка и изпълнение на команда за писане в ROM=====================
			;Запазване на регистри R0, R1, R2
RECV_CMD_WRITE:		MOV	A, R0
			PUSH	ACC
			MOV	A, R1
			PUSH	ACC
			MOV	A, R2
			PUSH	ACC
			;1) запис на изпратеното. Паралелно 2) проверка на чексума
			;получаване на REC_LEN
			JNB	RI, $
			CLR	RI
			MOV	REC_LEN, SBUF
			MOV	A, REC_LEN	;за проверка на чексумата

			;получаване на адреса на записа. Първо старшия байт
			JNB	RI, $
			CLR	RI
			MOV	CUR_WRITE_ADDR, SBUF
			ADD	A, CUR_WRITE_ADDR
			;а сега и младшия
			JNB	RI, $
			CLR	RI
			MOV	CUR_WRITE_ADDR+1, SBUF
			ADD	A, CUR_WRITE_ADDR+1

			;получаване типа на записа в R0
			JNB	RI, $
			CLR	RI
			MOV	R0, SBUF
			ADD	A, R0
			;проверка за End of file запис
			CJNE	R0, #01H, NOT_EOF_REC
			SJMP	WRITE_RECV_CHKSM
			;проверка за нулев брой data байтове
NOT_EOF_REC:		MOV	R1, REC_LEN
			CJNE	R1, #0, NOT_ZERO_SIZE
			SJMP	WRITE_RECV_CHKSM
			;получаване на data байтовете
NOT_ZERO_SIZE:		MOV	R1, #WRITE_BUFFER
			MOV	R2, REC_LEN
REC_RCV_CYCLE:		JNB	RI, $
			CLR	RI
			MOV	@R1, SBUF
			ADD	A, @R1	;за чексумата
			INC	R1
			DJNZ	R2, REC_RCV_CYCLE
			;получаване на чексума и проверка
WRITE_RECV_CHKSM:	JNB	RI, $
			CLR	RI
			MOV	R1, SBUF;получаване на чексума в R1
			CPL	A	;финално изчисляване на локалната чексума
			INC	A
			;сравняване на двете чексуми
			CLR	C	; bugfix изчистване на евентуално вдигнатия кери флаг
			SUBB	A, R1
			CJNE	A, #0, CHKSUM_ERR
			;ако чекусмите съвпадат
			CALL	SEND_CMD_AKNOWLEDGE	;потвърждение
			CJNE	R0, #0, WRITE_RECV_EOF	;ако записа е data record записваме и искаме следващия запис
			CALL	ACTION_WRITE		;самото записване в target устройството
			CALL	SHIFT_LED_ON
			CALL	SEND_CMD_NEXT
			SJMP	WRITE_CMD_END

WRITE_RECV_EOF:		CALL	WRITE_FINALIZE
			SJMP	WRITE_CMD_END

CHKSUM_ERR:		CALL	SEND_CMD_RESEND
			;възстановяване на регистри R2, R1, R0
WRITE_CMD_END:		POP	ACC
			MOV	R2, A
			POP	ACC
			MOV	R1, A
			POP	ACC
			MOV	R0, A
			RET

;=======================Проверка и изпълнение на команда за триене на ROM====================
;=======================		DEL			=============================
RECV_CMD_ERASE:		PUSH	ACC
			PUSH	B
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			MOV	B, #2
			CJNE	A, #'D', ERR_RECV_CMD_ERASE
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'E', ERR_RECV_CMD_ERASE
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B
			CJNE	A, #'L', ERR_RECV_CMD_ERASE
			;Получили сме erase команда
			CALL	SEND_CMD_AKNOWLEDGE
			CALL	ACTION_ERASE
			CALL	ACTION_CHECK_BLANK
			JB	TARGET_BLANK, ERASED_SUCCESS
			CALL	SEND_CMD_ERR
			SJMP	ERASE_END
ERASED_SUCCESS:		CALL	SEND_CMD_SUCCESS
			SJMP	ERASE_END

ERR_RECV_CMD_ERASE:	MOV	A, B
			CALL	UTIL_CLEAR_INPUT
			CALL	SEND_CMD_UNKNOWN
ERASE_END:		POP	B
			POP	ACC
			RET

;================Преди извикване трябва да се зареди в акумулатора колко байта трябва да се изчакат===
;================Изчаква получаването на толкова байта и след това връща управлението
UTIL_CLEAR_INPUT:	CJNE	A, #0, HAS_TO_CLEAR
			RET
HAS_TO_CLEAR:		JNB	RI, $
			CLR	RI
			DJNZ	ACC, HAS_TO_CLEAR
			RET
;=======================Изпраща сигнал, че получената команда е била приета=================
;=======================		AKN			============================
SEND_CMD_AKNOWLEDGE:	MOV	SBUF, #'A'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'K'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'N'
			CALL	COMM_WAIT_END
			RET
;=======================Изпраща сигнал, че предната команда е успешно изпълнена=============
;=======================		SCS			============================
SEND_CMD_SUCCESS:	MOV	SBUF, #'S'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'C'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'S'
			CALL	COMM_WAIT_END
			RET
;=======================Изпраща сигнал, че последната команда се е провалила================
;=======================		ERR			============================
SEND_CMD_ERR:		MOV	SBUF, #'E'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'R'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'R'
			CALL	COMM_WAIT_END
			RET

;=======================Изпраща сигнал, че получената команда е била непозната==============
;=======================		UNK			============================
SEND_CMD_UNKNOWN:	MOV	SBUF, #'U'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'N'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'K'
			CALL	COMM_WAIT_END
			RET

;=======================Изпраща молба за повторно изпращане на данни (след грешна чексума)==
;=======================		RES			============================
SEND_CMD_RESEND:	MOV	SBUF, #'R'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'E'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'S'
			CALL	COMM_WAIT_END
			RET

;=======================Изпраща молба за следващия запис (data record)=======================
;=======================		NXT			=============================
SEND_CMD_NEXT:		MOV	SBUF, #'N'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'X'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'T'
			CALL	COMM_WAIT_END
			RET

;=======================Отговаря на discovery команда с JFakeProgrammer======================
;=======================		JFP			=============================
SEND_DISCOVER_ANS:	MOV	SBUF, #'J'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'F'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'P'
			CALL	COMM_WAIT_END
			RET

;=======================Изпращане на текущо записания в паметта data record (от target устройство)=
SEND_CMD_RECORD:	MOV	A, R0
			PUSH	ACC
			MOV	A, R1
			PUSH	ACC
			CALL	SHIFT_LED_ON
REC_SEND_THE_FUNC:	MOV	R0, #WRITE_BUFFER	;началния адрес на буфера -> R0
			MOV	A, #0			;в акумулатора натрупваме чек сумата
			;изпращане на MARK_RECORD ':'
			MOV	SBUF, #MARK_RECORD
			JNB	TI, $
			CLR	TI
;			изпращане на REC_LEN
			MOV	SBUF, REC_LEN
			ADD	A, REC_LEN		;отчитане в чек сумата
			JNB	TI, $
			CLR	TI
			;изпращане на LOAD_OFFSET
			MOV	SBUF, CUR_WRITE_ADDR	;старшия байт
			ADD	A, CUR_WRITE_ADDR	;отчитане в чексумата
			JNB	TI, $
			CLR	TI
			MOV	SBUF, CUR_WRITE_ADDR+1	;младшия байт
			ADD	A, CUR_WRITE_ADDR+1	;отчитане в чексумата
			JNB	TI, $
			CLR	TI
			;изпращане на REC_TYPE 00H
			MOV	SBUF, #00H
			JNB	TI, $
			CLR	TI
			;REC_TYPE = 0, затова не го добавяме към чексумата
			;изпращане на байтовете данни
			MOV	R1, REC_LEN
			CJNE	R1, #0, REC_DATA_SEND
			SJMP	REC_CHKSUM_SEND
REC_DATA_SEND:		ADD	A, @R0		;добавяме към чексумата
			MOV	SBUF, @R0	;изпращаме текущия байт
			JNB	TI, $
			CLR	TI
			INC	R0		;следващия адрес със записан байт
			DJNZ	R1, REC_DATA_SEND ;повтаряне, докато не свършат байтовете за пращане
			;изпращане на чек сумата
REC_CHKSUM_SEND:	CPL	A
			INC	A
			MOV	SBUF, A
			JNB	TI, $		;изчакваме края на операцията
			CLR	TI

			;изчакваме отговор. Желаем да получим 'AKN' последвано от 'NXT', но е възможно да получим 'RES'
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'R', REC_SEND_NOT_R
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'E', REC_SEND_NOT_E
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'S', REC_SEND_NOT_S
			;получена е resend команда 'RES'
			SJMP	REC_SEND_THE_FUNC
REC_SEND_NOT_R:		JNB	RI, $
			CLR	RI
REC_SEND_NOT_E:		JNB	RI, $
			CLR	RI
REC_SEND_NOT_S:		;получили сме команда, различна от 'RES'. Приемаме, че е 'AKN'. Очакваме 'NXT'
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'N', REC_SEND_NOT_N
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'X', REC_SEND_NOT_X
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'T', REC_SEND_NOT_T
			;получена е 'NXT' команда. Излизаме от подпрограмата
			SJMP	REC_SEND_END
REC_SEND_NOT_N:		JNB	RI, $
			CLR	RI
REC_SEND_NOT_X:		JNB	RI, $
			CLR	RI
REC_SEND_NOT_T:		CALL	SEND_CMD_UNKNOWN
			SETB	FLG_ACT_ERR
REC_SEND_END:
			CALL	SHIFT_LED_OFF
			POP	ACC
			MOV	R1, ACC
			POP	ACC
			MOV	R0, A
			RET

;===============Изпраща End of file record по серийния канал===================
;===============	: 00 0000 01 FF
			;изпращане на record mark
SEND_CMD_EOF:		PUSH	ACC
			CALL	SHIFT_LED_ON
EOF_SEND_THE_FUNC:	MOV	SBUF, #MARK_RECORD
			JNB	TI, $
			CLR	TI

			;изпращане на RecLen и offset (00 0000)
			MOV	A, #3
SEND_EOF_CYCLE:		MOV	SBUF, #0
			JNB	TI, $
			CLR	TI
			DJNZ	ACC, SEND_EOF_CYCLE

			;изпращане на тип запис
			MOV	SBUF, #01H
			JNB	TI, $
			CLR	TI

			;изпращане на чек сума
			MOV	SBUF, #0FFH
			;изчакваме края на действието
			JNB	TI, $
			CLR	TI
			;чакаме потвърждение 'AKN' или resend 'RES'
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'R', EOF_SEND_NOT_R
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'E', EOF_SEND_NOT_E
			JNB	RI, $
			CLR	RI
			MOV	A, SBUF
			CJNE	A, #'S', EOF_SEND_NOT_S
			;получен е 'RES' resend сигнал
			SJMP	EOF_SEND_THE_FUNC
EOF_SEND_NOT_R:		JNB	RI, $
			CLR	RI
EOF_SEND_NOT_E:		JNB	RI, $
			CLR	RI
EOF_SEND_NOT_S:		CALL	SHIFT_LED_OFF
			POP	ACC
			RET

;=============		Подпрограма, изчакваща изпращането на висящия байт и изгасянето на индикатора за комуникация
COMM_WAIT_END:		JNB	TI, $		;изчаква края на изпращането
			CLR	TI		;изчиства флага за изпращане
			CALL	SHIFT_LED_OFF	;гаси датчика за комуникация
			RET