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
RECV_CMD_DEBUG:		JNB	RI, $				;Проверка дали е получена правилна команда
			PUSH	B				;запазваме стойността на B в стека
			MOV	B, #2				;колко още байта имаме от тази команда
			MOV	A, SBUF
			CLR	RI
			;проверка за ping команда 'PIN'
			CJNE	A, #'P', DBG_NOT_PING
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B				;прочели сме още един байт
			CJNE	A, #'I', DBG_UNKNOWN
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B				;прочели сме още един байт
			CJNE	A, #'N', DBG_UNKNOWN
			;значи сме получили PING команда. Отговаряме и излизаме
			CALL	DEBUG_SEND_PONG
			SJMP	DBG_CMD_CHECK_END

			;проверка за dump команда 'DMP'
DBG_NOT_PING:		CJNE	A, #'D', DBG_UNKNOWN
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B				;прочели сме още един байт
			CJNE	A, #'M', DBG_UNKNOWN
			JNB	RI, $
			MOV	A, SBUF
			CLR	RI
			DEC	B				;прочели сме още един байт
			CJNE	A, #'P', DBG_UNKNOWN
			;значи сме получили DUMP команда. Отговаряме и излизаме
			CALL	SEND_CMD_RECORD
			SJMP	DBG_CMD_CHECK_END

DBG_UNKNOWN:		MOV	A, B
			CALL	UTIL_CLEAR_INPUT
DBG_UNKNOWN_END:	CALL	SEND_CMD_UNKNOWN		;изпращаме сигнал за непозната команда

DBG_CMD_CHECK_END:	POP B					;въсзстановяваме стойността на B
			RET					;излизаме от подпрограмата

DEBUG_SEND_PONG:	MOV	SBUF, #'P'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'O'
			JNB	TI, $
			CLR	TI
			MOV	SBUF, #'N'
			CALL	COMM_WAIT_END
			RET
			