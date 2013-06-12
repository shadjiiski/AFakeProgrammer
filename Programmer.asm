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
;===============Константни==================================================================
PROG_BYTE	EQU	P1

SHIFT_STROBE	EQU	P3.3			;Strobe за shift register-a
SHIFT_DATA	EQU	P3.4			;Data пин за shift register-a
SHIFT_CLOCK	EQU	P3.5			;Clock пин за shift register-a. На rising edge се записва data бита в регистъра

PROG_CLOCK	EQU	P3.2			;pin, чрез който сменяме текущия адрес в target устройството
PROG_READY	EQU	P3.7			;pin, чрез който може да следим дали процеса на запрограмирване е приключил
						;След подаване на пулс за запрограмирване този бит ще бъде 0, докато процеса
						;на запрограмиране не приключи

;===============Променливи в паметта========================================================
;===============битови променливи===============
		BSEG	AT	020H
FLG_ACT_ERR:	DBIT	1			;Ако флагът е вдигнат, значи е имало грешка при предното действие
TARGET_BLANK:	DBIT	1			;Стойност 1 ако target устройството е изтрито, стойност 0 в противния случай
TARGET_4KB:	DBIT	1			;1 = AT89C4051 = 4 KB ROM
						;0 = AT89C2051 = 2 KB ROM
PROGRAMMING:	DBIT	1			;булева променлива, показваща дали сме в режим на програмиране

;===============байтови променливи==============
		DSEG	AT	030H
RCVD_CMD_MARK:	DS	1			;Записваме тук първия байт от полученото, за да разберем коя е командата

;	Променливи, използвани при получаване и изпращане на записи по серийния канал
REC_LEN:	DS	1			;Броя data байтове (при получаване на data record)
CUR_WRITE_ADDR:	DS	2			;На кой адрес от паметта да се записва байта при получаване на data record
						;разцепено на HIGH и LOW байт (|HIGH|LOW|)
LAST_PROG_ADDR:	DS	2			;В режим на програмиране тук записваме кой е последно достигнатия(незапрограмиран) адрес
						;в паметта на програмираното устройство (|HIGH|LOW|)
WRITE_BUFFER:	DS	8			;8 байта буфер, в които да се запише data record-a, за да се изпрати до
						;target устройството

TMP:		DS	8			;разделително пространство от 8 байта (неизползвано, цел: намаляване на вредите от memory leak)

SHIFT_REGISTER:	DS	1			; 1 байт, съдържащ данни за предаване на действителния shift register
;=============== Протокол ======================
;	Всички debug команди са реализирани в CMD_utils_debug.asm. Всички останали са реализирани в CMD_utils.asm
;
;	Командите, получавани от микроконтролера започват с един байт-маркер, показващ типа на командата
;	Маркери:
;	1) ':' - с него започват всички data records, които трябва да се запрограмират (вкл. End of file записа)
;	2) '-' - команди за изтриване на памет
;	3) '+' - команди за прочитане на запрограмирано устройство
;	4) '?' - debug команди
;	5) '=' - general marker. С него започват команди за настройка на режима на програматора както и DISCOVER командата
;
;	Всички команди, които могат да бъдат получени, освен командата за запрограмирване са с фиксирана дължина от
;	 3 байта.Списък на възможните за получаване команди:
;	1) команда за запрограмирване. По същество представлява един ред от IHEX8 файл, като е наложено
;		ограничечние да има не повече от 8 байта в запис. Задължително започва с маркер за data record ':'.
;		След получаване на записа микроконтролера проверява чексумата му. При съответствие се изпраща
;		aknowledge команда. При несъответствие се изпраща resend команда.
;	2) 'DEL' - команда за изтриване на паметта на програмираното устройство. Задължително започва с маркер за
;		команда за триене '-'.
;		Неимплементирано - при получаване се изпраща aknowledge команда. При изпълнение се изпраща success
;		или error команда в зависимост от изхода на операцията.
;	3) 'VER' - команда за прочитане на цялата памет на запрограмирано устройство. Задължително започва с маркер
;		за прочитане на памет '+'.
;		Неимплементирано - при получаване се отговаря с aknowledge команда. След това се започва изпращане
;		на последователни IHEX8 записи по серийния канал. Завършват с end of file запис
;	4) 'PIN' - ping debug команда. Задължително е да се изпрати с маркер за debug '?'.
;		Отговора е неизменно pong командата 'PON'
;	5) 'DMP' - dump debug команда. Изпраща се задължително с debug маркера '?'. Отговора на микроконтролера ще
;		представлява IHEX8 форматиран ред, показващ текущия запис за запрограмирване, намиращ се в паметта
;		на микроконтролера. Изпратения ред съдържа не повече от 8 data байта.
;	6) 'DSC' - discover команда. Изпраща се, за да се определи дали устройството е закачено на даден порт. При
;		получаване е задължително да се отговори с командата JFP (вж. по-долу). Трябва да започва с general маркер
;	7) 'LRG' - large команда. За смяна на режим на работа на програмтора за таргет устройство AT89C4051 (т.е 4 KB памет)
;		Трябва да започва с general маркер. Отговора е задължително aknowledge команда.
;	8) 'SML' - small команда. Сменя режима за програмиране на устройство AT89C2051 (т.е. с 2 KB памет). Трябва да
;		започва с general marker команда. Отговора е задължително aknowledge команда.
;
;	Командите, които може да изпрати микроконтролера имат фиксирана големина от 3 байта и не започват с маркер.
;	Протокола се реализира така, че да не се случват големи грешки, ако командата бъде приета грешно от компютъра,
;	като най-големия възможен проблем трябва да е нужда от повторно изтриване и запрограмирване. Списък на командите
;	които може да изпрати микроконтролера:
;	1) 'AKN' - acknowledge команда. Изпраща се като отговор ако е нямало проблеми при получаване на предходната команда.
;	2) 'RES' - resend команда. Изпраща се в отговор на команда за запрограмирване, ако чексумата не е била вярна
;	3) 'UNK' - unkown команда. Изпраща се в отговор на всяка неразпозната команда.
;	4) 'NXT' - next команда. Изпраща се след успешно запрограмирване на запис, за да се поиска следващия от компютъра.
;		Изключение се прави, ако последния получен запис е бил end of file - тогава нищо не се запрограмирва, а се
;		прекратява дейността.
;	5) 'JFP' - команда, изпращана в отговор на discover командата. Означава JFakeProgrammer
;	Неимплементирани команди, които могат да бъдат изпращани:
;	1) 'ERR' - error команда. Ще се изпраща при неуспешно изтриване на ROM паметаа.
;	2) 'SCS' - success команда. Ще се изпраща при успешно изтриване на ROM паметта.
;======= Край на протокола =====================
		CSEG
		ORG 0000H
		;Настройка на серийния интерфейс
		MOV	SCON, #01010000B		;Serial Mode 1, REN = 1
		MOV	TMOD, #00100000B		;Timer 1, Mode 2 (8-bit, autoreload)
		MOV	TH1, #253			;Избираме 9600 Baudrate
		MOV	TL1, #253			;----------------------
		SETB	TR1				;Стартира таймер 1

;===============Първоначално инициализиране=======================
		;първоначално изчистване на контролиращите pin-ове
		CLR	FLG_ACT_ERR			;първоначално изчистване на флага за грешка
		SETB	TARGET_4KB			;по подразбиране устройството е AT89C4051
		CLR	TARGET_BLANK			;преди да проверим няма основание да смятаме, че Target устройството е изтрито
		CLR	PROG_CLOCK			;смяната е с възходящи импулси, затова го изчистваме
		CLR	PROGRAMMING			;в началото разбира се не сме в режим на програмиране
		MOV	SHIFT_REGISTER, #00001000B	;загасен индикатор за комуникация, нулеви контролни битове, свален PROG, 0 V на RST
		CALL	SHIFT_REGISTER_INIT		;инициализиране на регистъра
;===============край на инициализирането==========================

;===============Основен цикъл=====================================
MAIN_LOOP:	JB	RI, SERIAL_RCV		;чакаме серийна комуникация
		JNB	TI, MAIN_LOOP		;Изчистване на флага за изпращане, ако е бил вдигнат
		CLR	TI			;...
		CALL	SHIFT_LED_OFF		;гасим LED индикатора
		SJMP	MAIN_LOOP		;и връщаме в основния цикъл
;===============Край на основния цикъл============================

;===============Обработка на получения сигнал=====================
SERIAL_RCV:	MOV	RCVD_CMD_MARK, SBUF		;първия прочетен байт е маркер за типа команда (тъй като идваме от основния цикъл)
		CLR	RI				;Изчистваме флага за получаване
		CALL	SHIFT_LED_ON			;светваме LED индикатора
		CALL	RECV_CMD_CHECK			;проверка на типа команда и реакция
		SJMP	MAIN_LOOP			;връщане в основния цикъл
;===============край на обработката на сигнала====================

;===============Вмъкване на всички файлове от проекта=============
		INCLUDE "CMD_utils.asm"		;включва подпрограми за изпращане на команди
		INCLUDE	"CMD_utils_debug.asm"	;добавя debug подпрограми към горното
		INCLUDE	"Actions.asm"		;включва подпрограми, извършващи триене на ROM, запис и четене
		INCLUDE	"Shifts.asm"		;включва подпрограми за управление на shift register-a
;===============край на вмъкването на файлове======================
;===============Край на всичкия програмен код======================
		END