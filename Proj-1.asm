;********************************************************************************
; AssemblerProj1: Togglar lysdioder anslutna till pin 8 - 9 (PORTB0 - PORTB1)
;                 via var sin timerkrets eller vid nedtryckning av en tryckknapp:
;
;                 - Timer 0 används för att stänga av PCI-avbrott på I/O-port B.
;                 - Timer 1 togglar LED1 ansluten till PORTB1 var 100:e ms.
;                 - Timer 2 togglas LED2 ansluten till PORTB2 var 200:e ms.
;
;                 - BUTTON1 togglar LED1 mellan att blinka och vara släckt.  ansluten till PORTB4. 
;                 - BUTTON2 togglar LED2 mellan att blinka och vara släckt.  ansluten till PORTB5. 
;                 - BUTTON3 används som en reset signal, som stänger av båda lysdioderna.  ansluten till PORTB3. 
;
;                 Vi använder en prescaler på 1024 för respektive timerkrets,
;                 vilket medför timeravbrott var 16.384:e ms. För att räkna
;                 ut antalet avbrott N som krävs för en viss fördröjning T
;                 kan följande formel användas:
;
;                                       N = T / 16.384,
;
;                 där T är fördröjningstiden i ms.
;
;                 Därmed krävs ca 100 / 16.384 = 6 avbrott för 100 ms, 
;                              ca 200 / 16.384 = 12 avbrott för 200 ms och 
;                              ca 300 / 16.384 = 18 avbrott för 300 ms.               
;********************************************************************************
.EQU LED1 = PORTB0            ; LED1 ansluten till pin 8 (PORTB0).
.EQU LED2 = PORTB1            ; LED2 ansluten till pin 9 (PORTB1).

.EQU BUTTON1 = PORTB4 ; Tryckknapp 1 ansluten till pin 12 (PORTB4).
.EQU BUTTON2 = PORTB5 ; Tryckknapp 2 ansluten till pin 13 (PORTB5).
.EQU BUTTON3 = PORTB3 ; Tryckknapp 3 ansluten till pin 11 (PORTB3).

.EQU TIMER0_MAX_COUNT   = 18  ; Motsvarar ca 300 ms fördröjning.
.EQU TIMER1_MAX_COUNT   = 6   ; Motsvarar ca 100 ms fördröjning.
.EQU TIMER2_MAX_COUNT   = 12  ; Motsvarar ca 200 ms fördröjning.

.EQU RESET_vect        = 0x00 ; Reset-vektor, programmets startpunkt.
.EQU PCINT0_vect       = 0x06 ; Avbrottsvektor för PCI-avbrott på I/O-port B.
.EQU TIMER2_OVF_vect   = 0x12 ; Avbrottsvektor för Timer 2 i Normal Mode.
.EQU TIMER1_COMPA_vect = 0x16 ; Avbrottsvektor för Timer 1 i CTC Mode.
.EQU TIMER0_OVF_vect   = 0x20 ; Avbrottsvektor för Timer 0 i Normal Mode.


;********************************************************************************
; .DSEG: Dataminnet, här lagras statiska variabler. För att allokera minne för
;        en variabel används följande syntax:
;
;        variabelnamn: .datatyp antal_byte
;********************************************************************************
.DSEG
.ORG SRAM_START
counter0: .byte 1 ; static uint8_t counter0 = 0;
counter1: .byte 1 ; static uint8_t counter1 = 0;
counter2: .byte 1 ; static uint8_t counter2 = 0;


;********************************************************************************
; .CSEG: Programminnet - Här lagrar programkoden.
;********************************************************************************
.CSEG

;********************************************************************************
; RESET_vect: Programmets startpunkt. Programhopp sker till subrutinen main
;             för att starta programmet.
;********************************************************************************
.ORG RESET_vect
   RJMP main

 ;/********************************************************************************
;* PCINT0_vect: Avbrottsvektor för PCI-avbrott på I/O-port B, som äger rum vid
;*              nedtryckning eller uppsläppning av någon av tryckknapparna.
;*              Hopp sker till motsvarande avbrottsrutin ISR_PCINT0 för att
;*              hantera avbrottet.
;********************************************************************************/

.ORG PCINT0_vect
   RJMP ISR_PCINT0

;********************************************************************************
; TIMER2_OVF_vect: Avbrottsvektor för overflow-avbrott på Timer 2, vilket sker
;                  var 16.384:e ms. Programhopp sker till motsvarande 
;                  avbrottsrutin ISR_TIMER2_OVF för att hantera avbrottet.
;********************************************************************************
.ORG TIMER2_OVF_vect
   RJMP ISR_TIMER2_OVF

;********************************************************************************
; TIMER1_COMPA_vect: Avbrottsvektor för CTC-avbrott på Timer 1, vilket sker
;                    var 16.384:e ms. Programhopp sker till motsvarande 
;                    avbrottsrutin ISR_TIMER1_COMPA för att hantera avbrottet.
;********************************************************************************
.ORG TIMER1_COMPA_vect
   RJMP ISR_TIMER1_COMPA

;********************************************************************************
; TIMER0_OVF_vect: Avbrottsvektor för overflow-avbrott på Timer 0, vilket sker
;                  var 16.384:e ms. Programhopp sker till motsvarande 
;                  avbrottsrutin ISR_TIMER0_OVF för att hantera avbrottet.
;********************************************************************************
.ORG TIMER0_OVF_vect
   RJMP ISR_TIMER0_OVF

;/********************************************************************************
;* ISR_PCINT0: Avbrottsrutin för PCI-avbrott på I/O-port, som anropas vid
;             nedtryckning och uppsläppning av tryckknapparna. Vid nedtryckning
;             togglas Timer 1 eller timer 2. Om Timer 1 eller 2 stängs av släcks 
;             respektive lysdiod.
;********************************************************************************/
ISR_PCINT0:
   CLR R24
   STS PCICR, R24
   STS TIMSK0, R16
   ISR_PCINT_1:
   IN R24, PINB
   ANDI R24, (1 << BUTTON1)
   BREQ ISR_PCINT0_2
   CALL timer1_toggle
   RETI
   ISR_PCINT0_2:
   IN R24, PINB
   ANDI R24, (1 << BUTTON2)
   BREQ ISR_PCINT0_3
   CALL timer2_toggle
   RETI 
   ISR_PCINT0_3:
   IN R24, PINB
   ANDI R24, (1 << BUTTON3)
   BREQ ISR_PCINT0_end
   CALL system_reset
ISR_PCINT0_end:
   RETI

;********************************************************************************
; ISR_TIMER2_OVF: Avbrottsrutin för overflow-avbrott på Timer 2, vilket sker
;                 var 16.384:e ms. Var 12:e avbrott (var 200:e ms) togglas LED2
;
;                 Den statiska variabeln counter2 läses in från dataminnet,
;                 inkrementeras och jämförs sedan med TIMER2_MAX_COUNT.
;
;                 Om counter2 är större eller lika med TIMER2_MAX_COUNT togglas 
;                 LED2 följt av att counter2 nollställs. Innan avbrottsrutinen
;                 avslutas skrivs det uppdaterade värdet på counter2 tillbaka
;                 till dataminnet.
;********************************************************************************
ISR_TIMER2_OVF:
   LDS R24, counter2        
   INC R24                  
   CPI R24, TIMER2_MAX_COUNT 
   BRLO ISR_TIMER2_OVF_end   
   OUT PINB, R17           
   CLR R24                   
ISR_TIMER2_OVF_end:
   STS counter2, R24       
   RETI                 

;********************************************************************************
; ISR_TIMER1_COMPA: Avbrottsrutin för CTC-avbrott på Timer 1, vilket sker var
;                   16.384:e ms. Var 6:e avbrott (var 100:e ms) togglas LED1.
;
;                   Den statiska variabeln counter1 läses in från dataminnet,
;                   inkrementeras och jämförs sedan med TIMER1_MAX_COUNT.
;
;                   Om counter1 är större eller lika med TIMER1_MAX_COUNT togglas 
;                   LED1 följt av att counter1 nollställs. Innan avbrottsrutinen
;                   avslutas skrivs det uppdaterade värdet på counter1 tillbaka
;                   till dataminnet.
;********************************************************************************
ISR_TIMER1_COMPA:
   LDS R24, counter1         
   INC R24                   
   CPI R24, TIMER1_MAX_COUNT
   BRLO ISR_TIMER1_COMPA_end 
   OUT PINB, R16           
   CLR R24                  
ISR_TIMER1_COMPA_end:
   STS counter1, R24        
   RETI                     

;********************************************************************************
; ISR_TIMER0_OVF: Avbrottsrutin för overflow-avbrott på Timer 0, vilket sker
;                 var 16.384:e ms. Var 18:e avbrott (var 100:e ms).
;
;                 Den statiska variabeln counter0 läses in från dataminnet,
;                 inkrementeras och jämförs sedan med TIMER0_MAX_COUNT.
;
;********************************************************************************
ISR_TIMER0_OVF:
   LDS R24, counter0         
   INC R24                   
   CPI R24, TIMER0_MAX_COUNT 
   BRLO ISR_TIMER0_OVF_end   
   LDI R24, (1 << PCIE0)
   STS PCICR, R24
   CLR R24
   STS TIMSK0, R24   
ISR_TIMER0_OVF_end:
   STS counter0, R24         
   RETI                      


;********************************************************************************
; main: Initierar systemet vid start. Programmet hålls sedan igång så länge
;       matningsspänning tillförs.
;********************************************************************************b
main:
   RCALL setup
main_loop:
   RJMP main_loop

;********************************************************************************
; setup: Initierar I/O-portar samt aktiverar timerkretsar Timer 0 - Timer 2 så
;        att timeravbrott sker var 16.384:e ms per timer.
;
;        Först sätts lysdiodernas pinnar PORTB0 - PORTB1 till utportar. 
;        Därefter sparas värden i CPU-register R16 & R17 för att enkelt toggla
;        de enskilda lysdioderna. Tryckknapparna sparas i CPU - registret R18
;
;        Sedan aktiveras avbrott globalt, följt av att 8-bitars timerkretsar 
;        Timer 0 och Timer 2 aktiveras i Normal Mode med en prescaler på 1024, 
;        vilket medför avbrott var 16.384:e ms vid overflow (uppräkning till 256). 
;
;        För att den 16-bitars timerkretsen Timer 1 ska fungera likartat ställs 
;        denna in i CTC Mode, där maxvärdet sätts till 256 genom att skriva 
;        detta värde till det 16-bitars registret OCR1A. Prescalern sätts till
;        1024 även för denna timerkrets, så att CTC-avbrott sker var 16.384:e ms 
;        efter uppräkning till 256.
;********************************************************************************
setup:
   LDI R16, (1 << LED1) | (1 << LED2)
   OUT DDRB, R16 

   LDI R16, (1 << LED1) 
   LDI R17, (1 << LED2) 

   LDI R18, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)
   OUT PORTB, R18

   SEI
   STS PCICR, R16
   STS PCMSK0, R18

   ;**********************************
   ;Timerbaserat avbrott via timer0
   ;**********************************
   LDI R25, (1 << CS02) | (1 << CS00)
   OUT TCCR0B, R25

   ;**********************************
   ;Timerbaserat avbrott via timer1
   ;**********************************
   LDI R25, (1 << WGM12) | (1 << CS12) | (1 << CS10)
   STS TCCR1B, R25
   LDI R25, high (256)
   STS OCR1AH, R25
   LDI R25, low (256)
   STS OCR1AL, R25

   ;**********************************
   ;Timerbaserat avbrott via timer2
   ;**********************************

   LDI R27, (1 << CS22) | (1 << CS21) |(1 << CS20)
   STS TCCR2B, R27
   RET


;**********************************
;
; Subrutiner för lättläsligare kod
;
;**********************************


;********************************************************************
;
; system_reset: Anropar funktionerna timer1_off och timer2_off för 
;               att återställa programmet.
;
;********************************************************************

system_reset:
    CALL timer1_off
	CALL timer2_off
	RET 

;********************
;  Togglar timer1
;********************
timer1_toggle:
   LDS R24, TIMSK1       
   ANDI R24, (1 << OCIE1A)  
   BRNE timer1_off  
          
		  
;********************
;  Sätter på Timer1
;********************		     
timer1_on:      
   STS TIMSK1, R17  ; Motsvarar C - koden TIMSK1 = (1 << OCIE1A);        
   RET 
 
;********************
;  Stänger av timer1
;********************                  
timer1_off:
   CLR R24                  
   STS TIMSK1, R24         
   IN R24, PORTB            
   ANDI R24, ~(1 << LED1) 
   OUT PORTB, R24   
   RET

   
;********************
;  Togglar timer2
;********************
timer2_toggle: 
   LDS R24, TIMSK2        
   ANDI R24, (1 << TOIE2)  
   BRNE timer2_off    

;********************
;  Sätter på Timer2
;********************        
timer2_on:     
   STS TIMSK2, R16  ; Motsvarar C - koden TIMSK2 = (1 << TOIE2);        
   RET               

;********************
;  Stänger av timer2
;********************
timer2_off:    
   CLR R24                  
   STS TIMSK2, R24         
   IN R24, PORTB            
   ANDI R24, ~(1 << LED2) 
   OUT PORTB, R24
   RET 
