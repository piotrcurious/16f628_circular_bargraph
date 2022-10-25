; this is somewhat slower implementation of 16bit ADC + LED bar display. 
; instead of turning all LEDs at once, it pulses each LED for a predefined period of time.
; this allows to use just one resistor , and as current flows via max one LED at a time, this allows aswell to get rid of 
; external transistor. only required elements are two resistors, which are not really nessesary if one assumes that 
; pulse current will be so short that no damage will happen to either LEDs or PIC transistors. 

; TODO : make RA5 useable as intensity delay , and branch to versions allowing also RA5 controlling switchoff and powerdown,
; implement WDT to powerdown mode etc.

; TODO : implement RA4 driven module. 7 segment display? another LED bar? whatever you wish !

LIST            P=PIC16F627
#INCLUDE        "p16f627.inc"

;        __CONFIG        _BODEN_ON & _CP_OFF & _DATA_CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_OFF & _INTRC_OSC_NOCLKOUT
        __CONFIG        _BODEN_ON & _CP_OFF & _DATA_CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_OFF & _HS_OSC

bank0		macro
		bcf	STATUS,RP0
		endm
bank1		macro
		bsf	STATUS,RP0
		endm

DISPLAY_TEMP1	equ   0x50
DISPLAY_RESULT_1	equ   0x51
DISPLAY_RESULT_2	equ   0x52
DISPLAY_RESULT_3	equ   0x53
RA0		equ 0x00
RA1		equ 0x01
RA2		equ 0x02
RA3		equ 0x03
RA4		equ 0x04
RA5		equ 0x05
RA6		equ 0x06
RA7		equ 0x07

RB0		equ 0x00
RB1		equ 0x01
RB2		equ 0x02
RB3		equ 0x03
RB4		equ 0x04
RB5		equ 0x05
RB6		equ 0x06
RB7		equ 0x07

		org 0            ; Reset Vector
		goto INIT

		org 4            ; Interrupt Vector
		goto COMP
		org 5

INIT:		bank0
;		movlw b'00001101'      ; zwei komparatoren
		movlw b'00000101'	; one comparator 
		movwf CMCON
;		movlw H'14'      ; 
		movlw b'00000100'      ; Timer 1:
					; 0 - TMR1ON - 0(off)
					; 1 - TMR1CS - 0(off) 
					; 2 - /T1SYNC - 1(off)
					; 3 - T1OSCEN - 0(off)

					; 4 - T1CKPS0 - 0 
					; 5 - T1CKPS1 - 0 ; 1:1 prescaler
					; 6 - - 0 
					; 7 - - 0 

		movwf T1CON      ; A 1 MHz clock is used
		clrf PORTA
		clrf PORTB
		bank1
		clrf TRISB
;		movlw H'CF'      ; Enable Vref = 3.6v
;		movwf VRCON
		bsf INTCON,GIE   ; Enable Global Int
		bsf INTCON,PEIE  ; Unmask Peripheral Int


MAIN:

		call CONVERT
		call BARGRAF_DISPLAY

		goto MAIN

;-------------------------16bit ADC subroutine

CONVERT:	
		bank0
		clrf TMR1L       ; Clear Timer 1 L
		clrf TMR1H       ; Clear Timer 1 H

		bank1
		bcf PIR1,TMR1IF
		bsf	TRISA,2  ; set RA2 as input

DISCHARGE_COMPARATOR_CAP:
		bank1            ; Main program loop
		bcf TRISA,1      ; Set RA1 as output
		bank0
		bcf PORTA,1      ; Discharge capacitor
		nop		; wait 200ns
		bank1		; another 200ns. switch bank to 1
		bsf	TRISA,1  ; make RA1 input, 600ns
		bank0		; switch back to bank0 . 
		btfsc	PORTA,1  ;  make sure capacitor got discharged
		goto 	DISCHARGE_COMPARATOR_CAP ; if not, go back discharging it. 
				; else 
		bcf PIR1,CMIF    ; Clear comp Int flag
		bank1

				;		bsf TRISA,1      ; Reset RA1 as input,
				 ; cap starts charging 
				
		bank0
		bsf T1CON,TMR1ON ; Start Timer 1
		movf CMCON,f     ; Read to sync output
		bank1
		bsf PIE1,TMR1IE  ;unmask TMR1 interrupt 
		nop
		bsf PIE1,CMIE    ; Unmask Comp Int

WAIT:		nop
		btfsc PIE1,CMIE  ; Wait for comp Int
				; ie wait until Int
		goto WAIT        ; Enable bit has been
				; cleared
GETDATA:			; Timer 1 contains
				; DATA (TMR1L TMR1H)

		bank0

		return

;-------------------------simple bargraf display subroutine

BARGRAF_DISPLAY:
		bank0
		movfw	TMR1L		;we get only most significiant byte
		andlw	b'11111000'	;and most significiant nibble
		movwf   DISPLAY_TEMP1	;bit testing cannot operate on W

		
		clrf 	DISPLAY_RESULT_1   ;we clear last display result
		clrf    DISPLAY_RESULT_2  
		clrf 	DISPLAY_RESULT_3		

		btfss	DISPLAY_TEMP1,7 ; if the '8' bit is set
		goto    BIT_7_NOT
		
		movlw	b'11111111'
		movwf 	DISPLAY_RESULT_1
		movwf	DISPLAY_RESULT_2
		goto 	BIT_3_NOT ;if 7bit is set, it means '16'. 

BIT_7_NOT
		btfss   DISPLAY_TEMP1,6 ;if the '8' bit is set
		goto    BIT_6_NOT
		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		
BIT_6_NOT:
		btfss   DISPLAY_TEMP1,5 ;if the '4' bit is set
		goto    BIT_5_NOT
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
BIT_5_NOT:

		btfss   DISPLAY_TEMP1,4 ;if the '2' bit is set
		goto    BIT_4_NOT
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
BIT_4_NOT:

		btfss   DISPLAY_TEMP1,3 ;if the '1' bit is set
		goto    BIT_3_NOT
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
BIT_3_NOT:
		
		;now 4 most significant bits can be displayed on a LED bar . 
		bank1
		clrf 	TRISB ; we use PORTB configured as output for that
		nop
		bcf  	TRISA,RA4 ; as PORTB is 8 bit, RA3 will select 3rd significant LED strip
		nop
		bcf     TRISA,RA3 ; as PORTB is 8 BIT, RA0 will select 2nd significant LED strip
		nop
		bcf 	TRISA,RA0 ; as PORTB is 8 bit, RA3 will select 1st significant LED strip. 
		bank0 
		clrf 	PORTB ; switch off all LEDS .
				;1 used as output 'on' state is used because this way device 
				;can be extended to drive bipolar transistors. 
;		bsf	PORTA,RA4 ; 3rd significant bar is off (LED cathodes connect to RA4 via resistor) 
		bcf	PORTA,RA4 ; prototype has intensity delay RA4 based so far, so let's test it
		nop
		bsf	PORTA,RA3 ; 2nd significant bar is off (LED cathodes connect to RA3 via resistor) 
		nop
		bsf 	PORTA,RA0 ; 1st significant bar is off (LED cathodes connect to RA0 via resistor). 
		nop 

				
		bcf	PORTA,RA0 ; les significant byte first 

					;simple magic - check bit in display result, and switch on same bit of PORTB
					;calling intensity delay, then clear, and so on
		btfsc	DISPLAY_RESULT_1,0
		bsf	PORTB,0
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_1,1
		bsf	PORTB,1
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_1,2
		bsf	PORTB,2
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_1,3
		bsf	PORTB,3
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_1,4
		bsf	PORTB,4
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_1,5
		bsf	PORTB,5
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_1,6
		bsf	PORTB,6
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_1,7
		bsf	PORTB,7
		call 	INTENSITY_DELAY
		clrf	PORTB

		bsf	PORTA,RA0 	; less significant byte off
		bcf	PORTA,RA3	; more significant byte on

					; same simple magic - check bit in display result, and switch on same bit of PORTB
					;calling intensity delay, then clear, and so on
		btfsc	DISPLAY_RESULT_2,0
		bsf	PORTB,0
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_2,1
		bsf	PORTB,1
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_2,2
		bsf	PORTB,2
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_2,3
		bsf	PORTB,3
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_2,4
		bsf	PORTB,4
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_2,5
		bsf	PORTB,5
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_2,6
		bsf	PORTB,6
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_2,7
		bsf	PORTB,7
		call 	INTENSITY_DELAY
		clrf	PORTB

		return 


INTENSITY_DELAY:

		nop
		nop

		return

; ------------------thiiiis is theory

;INTENSITY_DELAY
		bank1
		bsf	TRISA,RA4		; tristate RA4 pin - capacitor starts charging
		bsf 	TRISA,RA5		; tristate RA5 pin. it is tristate anyway, but let's make it input 
		bank0 				; switch back to bank0 
INTENSITY_DELAY1:
		btfss	PORTA,RA4		; check if delay capacitor got charged, skip if yes
 		goto 	INTENSITY_DELAY1	; if no, just wait for it to happen. 

		bank1				; when done switch back to bank1
		bcf	TRISA,RA4		; set RA4 as output again, this will discharge capacitor
		bank0
		return






;           Comparator Interrupt Service routine

COMP:		bank0
		bcf T1CON,TMR1ON ; Stop Timer 1
		bcf PIR1,CMIF    ; Clear Interrupt flag
		nop
		bcf PIR1,TMR1IF
		bank1
		bcf PIE1,CMIE    ; Mask Comparator Int
		nop
		bcf PIE1,TMR1IE
		retfie 
END
