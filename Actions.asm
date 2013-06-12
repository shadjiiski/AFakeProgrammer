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
;===============Изтриване на ROM паметта на target устройството==============
;Изтриването се извършва чрез избиране на подходящи контролни битове (SHIFTS_LOAD_CONTROL_ERASE подпрограма от Shifts.asm),
;избиране на програмно напрежение VPP (12 V) върху RST на микроконтролера и подаване на поне 10 ms низходящ PROG импулс
; @see SHIFT_LOAD_CONTROL_ERASE		(Shifts.asm)
; @see SHIFT_REGISTER_VOLTAGE_12V	(Shifts.asm)
; @see SHIFT_REGISTER_SET_PROG		(Shifts.asm)
; @see SHIFT_REGISTER_CLR_PROG		(Shifts.asm)
ACTION_ERASE:		PUSH	ACC				;запазване в стека на досегашните стойности
			MOV	A, R0				;на регистрите, използвани в подпрограмата
			PUSH	ACC				;...
			MOV	A, R1				;...
			PUSH	ACC				;...

			CALL	SHIFT_REGISTER_VOLTAGE_0V	;предварителна процедура по документация
			CLR	PROG_CLOCK			;...
			CALL	SHIFT_REGISTER_CLR_PROG		;...
			CALL	SHIFT_REGISTER_VOLTAGE_5V	;...
			CALL	SHIFT_REGISTER_SET_PROG		;...
			CALL	SHIFT_REGISTER_VOLTAGE_12V	;избираме напрежение VPP(12 V)
			CALL	SHIFT_LOAD_CONTROL_ERASE	;избираме контролни битове за операция изтриване
			CALL	SHIFT_REGISTER_CLR_PROG		;подаваме низходящ импулс
			CALL	DELAY_10MS			;изчакване около 10 милисекунди
			CALL	SHIFT_REGISTER_SET_PROG		;край на импулса
			CALL	SHIFT_REGISTER_INIT		;връщане в начално положение

			POP	ACC				;Възстановяване на запазените в стека стойности
			MOV	R1, A				;...
			POP	ACC				;...
			MOV	R0, A				;...
			POP	ACC				;...
			RET					;край на подпрограмата

;===============Прочитане на цялата ROM на target устройството и=============
;===============изпращане по серийния порт на прочетеното====================
;Подпрограмата може да се извика и за verify и за прочит на паметта на незащитено устройство. Дали четем
;4KB устройство или 2KB устройство можем да разберем от променливата TARGET_4KB
;Действието се осъществява по следния начин:
;1) нулира се адреса на устройството за прочит чрез възходяща промяна на RST напрежението
;2) избиране на напрежение за четене (High), контролни битове за четене и висок потенциал на PROG
;3) последователно изпращане на записи от по 8 байта (SEND_CMD_RECORD подпрограма от CMD_utils.asm)
;4) изпращане на End Of File запис
; @see SEND_CMD_RECORD			(CMD_utils.asm)
; @see SHIFT_REGISTER_VOLTAGE_0V	(Shifts.asm)
; @see SHIFT_REGISTER_VOLTAGE_5V	(Shifts.asm)
; @see SHIFT_LOAD_CONTROL_READ		(Shifts.asm)
; @see CUR_WRITE_ADDR			(Programmer.asm)
; @see REC_LEN				(Programmer.asm)
; @see PROG_BYTE			(Programmer.asm)
; @see TARGET_4KB			(Programmer.asm)
; @see FLG_ACT_ERR			(Programmer.asm)
ACTION_VERIFY:		PUSH	ACC				;запазване в стека на досегашните стойности
			MOV	A, R0				;на регистрите, използвани в подпрограмата
			PUSH	ACC				;...
			MOV	A, R2				;...
			PUSH	ACC				;...

			CALL	SHIFT_REGISTER_VOLTAGE_0V	;предварителна процедура по документация
			CLR	PROG_CLOCK			;...
			CALL	SHIFT_REGISTER_CLR_PROG		;...
			CALL	SHIFT_REGISTER_VOLTAGE_5V	;нулиране на program counter за устройството чрез възходяща промяна на напрежението
								;същевременно избор на подходящо напрежение
			CALL	SHIFT_REGISTER_SET_PROG		;подсигуряване високо ниво на PROG
			CALL	SHIFT_LOAD_CONTROL_READ		;избиране на контролни битове за четене

			MOV	CUR_WRITE_ADDR,#0		;нулиране на адреса на записите (глобална променлива)
			MOV	CUR_WRITE_ADDR+1,#0		;... и младшия байт
			MOV	REC_LEN, #8			;изпращаме по 8 байта в запис

WR0:			MOV	R0,#WRITE_BUFFER		;запазваме адреса на масива (елемент 1/8) в R0
			MOV	R2, #8				;ще записваме 8 байта в масива
WR1:			MOV	@R0, PROG_BYTE			;...всеки елемент се прочита от PROG_BYTE (отговаря на P1 на другия контролер)
			INC	R0				;...следващ елемент
			SETB	PROG_CLOCK			;инкрементираме адреса в паметта на програмирания контролер чрез положителен пулс
			CLR	PROG_CLOCK			;...
			DJNZ	R2,WR1				;...
			CALL	SEND_CMD_RECORD			;изпращане на записа
			JB	FLG_ACT_ERR, R			;ако е измало грешка, прекратяваме изпращането

			CLR	C				;изчисляваме адреса на първия байт от следващия запис и го записваме в
			MOV	A,#8				;локалната променлива CUR_WRITE_ADDR (старши и +1 младши байт)
			ADD	A,CUR_WRITE_ADDR+1		;...
			MOV	CUR_WRITE_ADDR+1,A		;...
			MOV	A,#0				;...
			ADDC	A,CUR_WRITE_ADDR		;...
			MOV	CUR_WRITE_ADDR,A		;...

			JB	TARGET_4KB,M4KB			;максималния адрес е различен за 2KB и 4КБ
			;2KB памет = 2048 байта. Т.е. ако изчисления адрес е >= 0800H трябва да прекратим (не изпращаме повече)
			CJNE	A,#08,WR0		;ако старшия байт е различен от 08H продължаваме изпращането
			SJMP	R

			;4KB памет = 4096 байта. Т.е. ако изчисления адрес е >= 1000H трябва да прекратим (не изпращаме повече)
M4KB:			CJNE	A,#10H,WR0		;ако старшия байт е различен от 10H продължаваме изпращането

R:			CALL	SEND_CMD_EOF			;изпращане End Of File запис за край
			CALL	SHIFT_REGISTER_INIT		;връщане в начално положение
			CALL	SHIFT_REGISTER_CLR_PROG		;...
			CALL	SHIFT_LED_OFF			;гасим индикатора за комуникация
			CLR	FLG_ACT_ERR			;изчистваме флага за грешка, ако е бил качен по време на изпращането
			POP	ACC				;Възстановяване на запазените в стека стойности
			MOV	R2, A				;...
			POP	ACC				;...
			MOV	R0, A				;...
			POP	ACC				;...
			RET					;край на подпрограмата

;===============Четене на данни от серийния порт и запис в target устройството=
;Преди извикването на тази подпрограма в паметта на програматора се зарежда запис. В него са посочени броя байтове (REC_LEN), адреса,
;на който да бъде записан първия от тях байт (старши и младши байт на CUR_WRITE_ADDR) както и самите байтове в масива WRITE_BUFFER
; 1) подсигуряване на ниско ниво на CLOCK и всико ниво на PROG. Зареждане на контролни битове. Нулиране на адреса в паметта чрез
;	възходяща промяна на напрежението към програмно VPP (12 V)
; 2) инкрементиране на адреса в паметта до достигане на желания адрес (CUR_WRITE_ADDR)
; 3) записване на REC_LEN последователни записа от WRITE_BUFFER в PROG_BYTE, инкрементиране на адреса в паметта между всеки два
; 4) възстановяване на стандартен режим на програматора преди изход от подпрограмата
; @see SHIFT_REGISTER_CLR_PROG			(Shifts.asm)
; @see SHIFT_REGISTER_SET_PROG			(Shifts.asm)
; @see SHIFT_LOAD_CONTROL_WRITE			(Shifts.asm)
; @see SHIFT_REGISTER_VOLTAGE_0V		(Shifts.asm)
; @see SHIFT_REGISTER_VOLTAGE_12V		(Shifts.asm)
; @see PROG_CLOCK				(Programmer.asm)
; @see REC_LEN					(Programmer.asm)
; @see CUR_WRITE_ADDR				(Programmer.asm)
; @see WRITE_BUFFER				(Programmer.asm)
ACTION_WRITE:		PUSH	ACC				;запазване в стека на досегашните стойности
			MOV	A, R0				;на регистрите, използвани в подпрограмата
			PUSH	ACC				;...
			MOV	A, R1				;...
			PUSH	ACC				;...
			MOV	A, R2				;...
			PUSH	ACC				;...
			;проверка дали това е първия запис
			JB	PROGRAMMING, WRITE_INITED	;ако е първия запис преминаваме в режим на записване
			SETB	PROGRAMMING			;маркираме, че сме в режим на програмиране
			MOV	LAST_PROG_ADDR, #0		;нулираме достигнатия адрес в локални променливи
			MOV	LAST_PROG_ADDR+1, #0		;...
			CALL	SHIFT_REGISTER_VOLTAGE_0V	;0V -> 5V нулира вътрешния адрес на паметта на програмируемото устройство
			CLR	PROG_CLOCK			;необходими са ни положителни импулси за XTAL
			CALL	SHIFT_REGISTER_SET_PROG		;и отрицателни за PROG
			CALL	SHIFT_REGISTER_VOLTAGE_5V	;за нулиране на адреса
			CALL	SHIFT_LOAD_CONTROL_WRITE	;Зареждане на подходящата комбинация на контролните битове
			CALL	SHIFT_REGISTER_VOLTAGE_12V	;избира програмно напрежение
			CALL	DELAY_10US			;изчакваме установяване на напрежение (по документация)
			;записване на REC_LEN байта, започващи от избрания адрес
WRITE_INITED:		MOV	R1,REC_LEN			;запомняме броя байтове за запис в R1
			CALL	ADVANCE_TO_ADDR			;Избира подходящия адрес за байта
			MOV	R0,#WRITE_BUFFER		;адреса на елемент 1/8 на масива за запис отива в R0
			;цикъл за записване на байтовете от масива
WRITE_BYTE:		MOV	PROG_BYTE,@R0			;подаваме за запис текущия елемент на масива
			CALL	SHIFT_REGISTER_CLR_PROG		;Подаване на низходящ импулс за запрограмиране (min време е 1 us, т.е. влизаме)
			CALL	SHIFT_REGISTER_SET_PROG		;...
			;TODO може да се направи verify на записания байт преди преминаване към следващия. Записаното може да се прочете от PROG_BYTE
			;при подходящо напрежение и контролни битове
			JNB	PROG_READY, $			;Изчакваме края на записването
			INC	R0				;премества ни на следващия елемент масива
			;Инкрементираме адреса, до който сме стигнали
			SETB	PROG_CLOCK
			CLR	PROG_CLOCK
			;Завъртаме цикъла
			DJNZ	R1, WRITE_BYTE
			;след записването променяме адреса, до който сме стигнали в локални променливи (LAST_PROG_ADDR)
			CLR	C
			MOV	A, CUR_WRITE_ADDR+1
			ADD	A, REC_LEN
			MOV	LAST_PROG_ADDR+1, A
			MOV	A, #0
			ADDC	A, CUR_WRITE_ADDR
			MOV	LAST_PROG_ADDR, A
			;Записът е изцяло обработен. Възстановяване на променливите от стека
			POP	ACC
			MOV	R2, A
			POP	ACC
			MOV	R1, A
			POP	ACC
			MOV	R0, A
			POP	ACC
			RET

;==============	Подпрограма, която трябва да бъде извикана след получаване на End Of File запис (или евентуално възникнала грешка)
WRITE_FINALIZE:		CALL	SHIFT_REGISTER_INIT		;Връща основно състояние на контролните битове и напрежението
			CALL	SHIFT_REGISTER_CLR_PROG		;сваля PROG
			CLR	PROG_CLOCK			;сваля XTAL
			CLR	PROGRAMMING			;маркира режима за програмиране като завършен
			RET

;===============Проверка дали target устройството е с изтрита памет=============
;TODO нулиране на брояча за паметта, задаване на подходящи напрежение и контролни битове (за четене) чрез Shifts.asm
;	Последователна проверка на байтовете на устройството (FF = изтрит). При достигане на неизтрит трябва да се отбележи
;	стойност 0 в TARGET_BLANK променливата (битова) и изход. При достигане на максималния адрес и само изтрити байтове -
;	да се запише стойност 1 в TARGET_BLANK и изход. Максималния адрес може да се определи от TARGET_4KB променливата
ACTION_CHECK_BLANK:	PUSH	ACC				;запазване в стека на досегашните стойности
			MOV	A, R0				;на регистрите, използвани в подпрограмата
			PUSH	ACC				;...
			MOV	A, R2				;...
			PUSH	ACC				;...
			SETB	TARGET_BLANK			;предварително маркираме като изтрит. Ако не е ще коригираме
			;следва четене, но без изпращане на прочетеното
			CALL	SHIFT_REGISTER_VOLTAGE_0V	;предварителна процедура по документация
			CLR	PROG_CLOCK			;...
			CALL	SHIFT_REGISTER_CLR_PROG		;...
			CALL	SHIFT_REGISTER_VOLTAGE_5V	;нулиране на program counter за устройството чрез възходяща промяна на напрежението
								;същевременно избор на подходящо напрежение
			CALL	SHIFT_REGISTER_SET_PROG		;подсигуряване високо ниво на PROG
			CALL	SHIFT_LOAD_CONTROL_READ		;избиране на контролни битове за четене

			MOV	R0, #0				;тук пазим старшия байт на текущия адрес
			MOV	R2, #0				;а тук младшия
BLANK_CHK:		MOV	A, PROG_BYTE			;прочитаме байта, записан на този адрес
			CJNE	A, #0FFH, CHK_BLANK_ERR		;изтритите байтове са FF
			SETB	PROG_CLOCK			;преминаваме на следващия адрес от паметта чрез възходящ импулс на XTAL
			CLR	PROG_CLOCK			;...
			CLR	C				;както и в локалните променливи
			MOV	A, R2				;...
			ADD	A, #1				;...
			MOV	R2, A				;...
			MOV	A, #0				;...
			ADDC	A, R0				;...
			MOV	R0, A				;...
			;различни проверки в зависимост от размера на паметта
			JB	TARGET_4KB, BLANK_CHK_4KB
			;2KB памет. Ако сме достигнали адрес 0800H трябва да прекратим
			CJNE	A, #08H, BLANK_CHK
			SJMP	CHK_BLANK_END
			;4KB памет. Ако сме достигнали адрес 1000H трябва да прекратим
BLANK_CHK_4KB:		CJNE	A, #10H, BLANK_CHK
			SJMP	CHK_BLANK_END
CHK_BLANK_ERR:		CLR	TARGET_BLANK			;неизтрит байт. Значи паметта не е изтрита
			SJMP	CHK_BLANK_END			;излизаме от подпрограмата
			;връщаме шифт-регистъра в основно състояние и излизаме от подпрограмата
CHK_BLANK_END:		CALL	SHIFT_REGISTER_INIT
			CALL	SHIFT_REGISTER_CLR_PROG
			POP	ACC
			MOV	R2, A
			POP	ACC
			MOV	R0, A
			POP	ACC
			RET

;==============Проста подпрограма за 10 милисекунди забавяне===========================================
DELAY_10MS:		PUSH	ACC
			MOV	A, R0
			PUSH	ACC
			MOV	A, R1
			PUSH	ACC

			MOV	R0, #19				; delay 19 * 255 * 2 * 1,085us = 10,5 ms
DLY_10MS_INNER:		MOV	R1, #255			;...
			DJNZ	R1, $				;...
			DJNZ	R0, DLY_10MS_INNER		;end delay

			POP	ACC
			MOV	R1, A
			POP	ACC
			MOV	R0, A
			POP	ACC
			RET

;==============Проста подпрограма за около 10 микросекунди забавяне===========================================
DELAY_10US:		NOP
			NOP
			NOP
			NOP
			NOP
			NOP
			NOP
			NOP
			NOP
			NOP
			RET

;===============Подпрограма, избираща даден адрес от паметта на устройството за програмиране. Преди извикване е необходимо да се
;попълни желания адрес в старшия и младшия байт на променливата CUR_WRITE_ADDR. Приема се, че преди извикването на подпрограмата
;вътрешния брояч на паметта на устройството, което се програмира, е доведена до адресът, записан в старшия и младшия байтове на
;LAST_PROG_ADDR
ADVANCE_TO_ADDR:	PUSH	ACC				;Запазване на променливи в стека
			MOV	A, R1				;...
			PUSH	ACC				;...
			MOV	A, R2				;...
			PUSH	ACC				;...

			MOV	R1,LAST_PROG_ADDR		;старшия байт на последно достигнатия адрес (незапрограмиран)
			MOV	R2,LAST_PROG_ADDR+1		;младшия байт

			;проверка за достигане на желания адрес
ADV_CHECK_ADDR:		MOV	A, R1
			CJNE	A, CUR_WRITE_ADDR, ADV_SET_ADDR
			MOV	A, R2
			CJNE	A, CUR_WRITE_ADDR+1, ADV_SET_ADDR
			SJMP	ADV_END
			;инкрементиране на адреса чрез възходящ импулс на XTAL
ADV_SET_ADDR:		SETB	PROG_CLOCK			;...
			CLR	PROG_CLOCK			;...
			;инкрементиране на адреса и в локални променливи
			CLR	C				;...
			MOV	A, R2				;...
			ADD	A, #1				;...
			MOV	R2, A				;...
			MOV	A, #0				;...
			ADDC	A, R1				;...
			MOV	R1, A				;...
			;обратно към проверката за достигнат желан адрес
			SJMP	ADV_CHECK_ADDR
			;край на подпрограмата за избор на адрес
ADV_END:		POP	ACC				;Възстановяване от стека
			MOV	R2, A				;...
			POP	ACC				;...
			MOV	R1, A				;...
			POP	ACC				;...
			RET
