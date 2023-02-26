;********************************************************************************
; AssemblerProj1-Final: Togglar lysdioder anslutna till pin 8 - 9 (PORTB0 - PORTB1)
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

.EQU LED1 = PORTB0 ; Lysdiod 1 ansluten till pin 8 (PORTB0).
.EQU LED2 = PORTB1 ; Lysdiod 2 ansluten till pin 9 (PORTB1).

.EQU BUTTON1 = PORTB4 ; Tryckknapp 1 ansluten till pin 12 (PORTB4).
.EQU BUTTON2 = PORTB5 ; Tryckknapp 2 ansluten till pin 13 (PORTB5).
.EQU BUTTON3 = PORTB3 ; Tryckknapp 3 ansluten till pin 11 (PORTB3).

;.EQU TIMER0_MAX_COUNT = ?    ; Motsvarar ca ??? ms fördröjning.
.EQU TIMER1_MAX_COUNT = 6    ; Motsvarar ca 100 ms fördröjning.
.EQU TIMER2_MAX_COUNT = 12   ; Motsvarar ca 200 ms fördröjning.


.EQU RESET_vect  = 0x00 ; Reset-vektor, utgör programmets startpunkt.
.EQU PCINT0_vect = 0x06 ; Avbrottsvektor för PCI-avbrott på I/O-port B.
.EQU TIMER0_OVF_vect   = 0x20 ; Avbrottsvektor för Timer 0 i Normal Mode.
.EQU TIMER1_COMPA_vect = 0x16 ; Avbrottsvektor för Timer 1 i CTC Mode.
.EQU TIMER2_OVF_vect   = 0x12 ; Avbrottsvektor för Timer 2 i Normal Mode.


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
;* .CSEG - Programminnet, här lagras programkoden.
;********************************************************************************
.CSEG



;********************************************************************************
;* RESET_vect: Hoppar till subrutinen main för att starta programmet.
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

;/********************************************************************************
;* ISR_PCINT0: Avbrottsrutin för hantering av PCI-avbrott på I/O-port B, som
;*             äger rum vid nedtryckning eller uppsläppning av någon av 
;*             tryckknapparna. Om nedtryckning av en tryckknapp orsakade 
;*             avbrottet togglas motsvarande lysdiod, annars görs ingenting.
;********************************************************************************/
ISR_PCINT0:
   IN R24, PINB
   ANDI R24, (1 << BUTTON1)
   BREQ ISR_PCINT0_2
   OUT PINB, R16 
   RETI
ISR_PCINT0_2:
   IN R24, PINB
   ANDI R24, (1 << BUTTON2)
   BREQ ISR_PCINT0_3
   OUT PINB, R17 
   RETI 
ISR_PCINT0_3:
   IN R24, PINB
   ANDI R24, (1 << BUTTON3)
   BREQ ISR_PCINT0_end
   OUT PINB, R18 
ISR_PCINT0_end:
   RETI

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

;********************************************************************************
;  Kopierad kommentar för tidsspar, ska göra något annat sedan.
;ISR_TIMER0_OVF: Avbrottsrutin för overflow-avbrott på Timer 0, vilket sker
;                 var 16.384:e ms. Var 6:e avbrott (var 100:e ms) togglas LED1.
;
;                 Den statiska variabeln counter0 läses in från dataminnet,
;                 inkrementeras och jämförs sedan med TIMER0_MAX_COUNT.
;
;                 Om counter0 är större eller lika med TIMER0_MAX_COUNT togglas 
;                 LED1 följt av att counter0 nollställs. Innan avbrottsrutinen
;                 avslutas skrivs det uppdaterade värdet på counter0 tillbaka
;                 till dataminnet.
;********************************************************************************
ISR_TIMER0_OVF:
   LDS R24, counter0         
   INC R24                   
   CPI R24, TIMER0_MAX_COUNT 
   BRLO ISR_TIMER0_OVF_end   
   OUT PINB, R16             
   CLR R24                   
ISR_TIMER0_OVF_end:
   STS counter0, R24         
   RETI                      

;********************************************************************************
;  Kopierad kommentar för tidsspar, ska göra något annat sedan.
;ISR_TIMER1_COMPA: Avbrottsrutin för CTC-avbrott på Timer 1, vilket sker var
;                   16.384:e ms. Var 12:e avbrott (var 200:e ms) togglas LED2.
;
;                   Den statiska variabeln counter1 läses in från dataminnet,
;                   inkrementeras och jämförs sedan med TIMER1_MAX_COUNT.
;
;                   Om counter1 är större eller lika med TIMER1_MAX_COUNT togglas 
;                   LED2 följt av att counter1 nollställs. Innan avbrottsrutinen
;                   avslutas skrivs det uppdaterade värdet på counter1 tillbaka
;                   till dataminnet.
;********************************************************************************
ISR_TIMER1_COMPA:
   LDS R24, counter1         
   INC R24                   
   CPI R24, TIMER1_MAX_COUNT
   BRLO ISR_TIMER1_COMPA_end 
   OUT PINB, R17             
   CLR R24                  
ISR_TIMER1_COMPA_end:
   STS counter1, R24        
   RETI                     

;********************************************************************************
; Kopierad kommentar för tidsspar, ska göra något annat sedan.
;ISR_TIMER2_OVF: Avbrottsrutin för overflow-avbrott på Timer 2, vilket sker
;                 var 16.384:e ms. Var 18:e avbrott (var 300:e ms) togglas LED3.
;
;                 Den statiska variabeln counter2 läses in från dataminnet,
;                 inkrementeras och jämförs sedan med TIMER2_MAX_COUNT.
;
;                 Om counter2 är större eller lika med TIMER2_MAX_COUNT togglas 
;                 LED1 följt av att counter2 nollställs. Innan avbrottsrutinen
;                 avslutas skrivs det uppdaterade värdet på counter2 tillbaka
;                 till dataminnet.
;********************************************************************************
ISR_TIMER2_OVF:
   LDS R24, counter2         
   INC R24                  
   CPI R24, TIMER2_MAX_COUNT 
   BRLO ISR_TIMER2_OVF_end   
   OUT PINB, R18             
   CLR R24                   
ISR_TIMER2_OVF_end:
   STS counter2, R24       
   RETI   

;********************************************************************************
; main: Initierar systemet vid start. Programmet hålls sedan igång så länge
;       matningsspänning tillförs.
;********************************************************************************
main:
   CALL setup
main_loop:
   RJMP main_loop


;********************************************************************************
; setup: 
;********************************************************************************
setup:

RET
