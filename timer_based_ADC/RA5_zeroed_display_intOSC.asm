; this is somewhat slower implementation of 16bit ADC + LED bar display. 
; instead of turning all LEDs at once, it pulses each LED for a predefined period of time.
; this allows to use just one resistor , and as current flows via max one LED at a time, this allows aswell to get rid of 
; external transistor. only required elements are two resistors, which are not really nessesary if one assumes that 
; pulse current will be so short that no damage will happen to either LEDs or PIC transistors. 

; TODO : implement WDT to powerdown mode etc.
; RA4 is OC type, and the code measures how long it takes for it to return to 1 after 0'ing. 
; connecting _small_ capacitor and large potentiometer is recommended if you want intensity knob.
; if you want to save parts - just put a pullup resistor of i.e. 1mohm , 100kohm, etc can be used. 
; as meter will wait to infinity if there is no 1 on the pin, it can be also used for powerdown mode. 
;
; RA5 should be pulled up by weak resistor , and equipped with switch to 0 . 
; i made this using intensity delay pot - on 1.3v of PCB it is connected via 4.7K resistor to 5V, 
; so RA5 got connected to the resistor. when pot is turned to 0 , RA5 gets to 0 aswell, as long as 
; RA4 is still down.
; RA5 is now used to set '0'  
;

LIST            P=PIC16F627
#INCLUDE        "p16f627.inc"
ERRORLEVEL 	-302
        __CONFIG        _BODEN_ON & _CP_OFF & _DATA_CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_OFF & _INTRC_OSC_NOCLKOUT
;        __CONFIG        _BODEN_ON & _CP_OFF & _DATA_CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_OFF & _HS_OSC

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
DISPLAY_RESULT_4	equ   0x54
INTENSITY_KNOB		equ	0x55
DELAY			equ	0x56
DELAY2			equ	0x57
COMPARATOR_DISCHARGE_TIME	equ 0x58
COMPARATOR_DISCHARGE_TIME2	equ 0x59
INTERRUPT_STATUS	equ	0x60
SUBTRACTION_REGISTER1 equ 0x61
SUBTRACTION_REGISTER2 equ 0x62
ZERO_2			equ	0x63
ZERO_1			equ	0x64
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
		call DISCHARGE_COMPARATOR_CAPACITOR
		call CONVERT
		call COMPENSATE_RESULT
		
		movlw	0x00
		subwf	TMR1H,W
		btfsc	STATUS,Z
		goto	DISPLAY_LOW

		movfw	TMR1H
		call	BARGRAF_DISPLAY_W
DISPLAY_LOW:
		movlw	0x00
		subwf	TMR1H,W
		btfss	STATUS,Z
		goto	DISPLAY_HIGH

		movfw	TMR1L
		call	BARGRAF_DISPLAY_W
DISPLAY_HIGH:


		call ASK_USER_IF_ZERO

		goto	MAIN

ASK_USER_IF_ZERO
		bank1
		bsf 	TRISA,RA5		; tristate RA5 pin. it is tristate anyway, but let's make it input 
		bank0 		
		btfsc	PORTA,RA5
		return 			;user did not press button - return
			;RA5 pressed , zero calibration
		call	DISCHARGE_COMPARATOR_CAPACITOR
		call	CONVERT

		bank1
		bcf	INTCON,GIE

		movlw	0x00
		movwf	EEADR ; write ZERO_2 to 0x00 @ eeprom
		bank0 
		movfw	TMR1H
		bank1
		movwf	EEDATA
		bsf	EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xaa
		movwf	EECON2
		bsf	EECON1,WR
		
ZERO_2_WRITE:
		btfsc	EECON1,WR
		goto	ZERO_2_WRITE
		bank0
		bcf	PIR1,EEIF

		bank1
		movlw	0x01
		movwf	EEADR ; write ZERO_1 to 0x01 @ eeprom
		bank0 
		movfw	TMR1L
		bank1
		movwf	EEDATA
		bsf	EECON1,WREN
		movlw	0x55
		movwf	EECON2
		movlw	0xAA
		movwf	EECON2
		bsf	EECON1,WR
		
	
ZERO_1_WRITE:
		btfsc	EECON1,WR
		goto	ZERO_1_WRITE

		bank1
		bcf	PIR1,EEIF
		
		
		bank1
		bcf	EECON1,WREN
		bsf	INTCON,GIE

		bank0
		bsf	PORTB,RB1

USER_HOLDS_KEY:
		bsf	PORTA,RA3
		rrf	PORTB
		movfw	PORTB
		call 	INTENSITY_DELAY
		btfsc	PORTA,RA5
		goto	USER_HOLDS_KEY
		bcf	PORTA,RA3
		clrf	PORTB		
		return


COMPENSATE_RESULT:
		; compensation for 20mhz clock :

		bank1		
		movlw   0x00
		movwf	EEADR  ; read 0x00 byte from EEPROM = ZERO_2		
		bsf	EECON1,RD
		movfw	EEDATA
		bank0
		movwf	SUBTRACTION_REGISTER2		

		bank1
		movlw   0x01
		movwf	EEADR  ; read 0x01 byte from EEPROM = ZERO_1		
		bsf	EECON1,RD
		movfw	EEDATA
		bank0
		movwf	SUBTRACTION_REGISTER1

		movf	SUBTRACTION_REGISTER1,W
		subwf	TMR1L
		movf	SUBTRACTION_REGISTER2,W
		btfss	STATUS,C
		incfsz	SUBTRACTION_REGISTER2,W
		subwf	TMR1H
;		btfsc	STATUS,C
		return
		clrf	TMR1H
		clrf 	TMR1L
		return

DISCHARGE_COMPARATOR_CAP:
		bank1            ; 
		bcf TRISA,1      ; Set RA1 as output
		bank0
		bcf PORTA,1      ; Discharge capacitor
		nop		; wait 

		bank1		
		bsf	TRISA,1  ; make RA1 input
		bank0		; switch back to bank0 . 
		btfsc	PORTA,1  ;  make sure capacitor got discharged 
		goto 	DISCHARGE_COMPARATOR_CAP ; if not, go back discharging it. 
		return 

DISCHARGE_COMPARATOR_CAPACITOR:
		call 	DISCHARGE_COMPARATOR_CAP
		bank1 
		bcf	TRISA,RA1 
		nop
;		bcf	TRISA,RA2
		bank0 
		bcf 	PORTA,RA1
		nop
;		bcf	PORTA,RA2
		
;		clrf	COMPARATOR_DISCHARGE_TIME2
		movlw	0x10
		movwf	COMPARATOR_DISCHARGE_TIME2
	
DISCHARGE_COMPARATOR2

		clrf	COMPARATOR_DISCHARGE_TIME

DISCHARGE_COMPARATOR
		decfsz	COMPARATOR_DISCHARGE_TIME
		goto	DISCHARGE_COMPARATOR
		decfsz	COMPARATOR_DISCHARGE_TIME2
		goto	DISCHARGE_COMPARATOR2

		return

;-------------------------16bit ADC subroutine

CONVERT:	
	
		bank0
		clrf	INTERRUPT_STATUS 
		clrf TMR1L       ; Clear Timer 1 L
		bcf PIR1,TMR1IF  ; clear tmr1 int flag
		clrf TMR1H       ; Clear Timer 1 H
		bcf PIR1,CMIF    ; Clear comp Int flag

		bank1
		bsf PIE1,CMIE    ; Unmask Comp Int
		bsf	TRISA,RA2  ; set RA2 as input
		bsf PIE1,TMR1IE  ;unmask TMR1 interrupt 
		bank0

		bsf T1CON,TMR1ON ; Start Timer 1 
		movf CMCON,f     ; Read to sync output
		bank1		; 4 cycles
		bsf	TRISA,RA1 ; start charging cap - 8 cycles
		 
WAIT:		
		btfsc PIE1,CMIE  ; Wait for int to clean PIE1 (bank1)
;		btfss PIR1,CMIF				
;		btfss	INTERRUPT_STATUS,0	; bank0 
		goto WAIT        
				; 
GETDATA:			; Timer 1 contains
				; DATA (TMR1L TMR1H)
		bank1            ; 
		bcf TRISA,1      ; Set RA1 as output
		bank0
		bcf PORTA,1      ; Discharge capacitor
		return

;-------------------------simple bargraf display subroutine


		

BARGRAF_DISPLAY_W:
		bank0
;		movfw	TMR1H		;we get only most significiant byte
;		movfw	TMR1L		;we get only least significiant byte (for quick testing)
;		movfw	COMPARATOR_DISCHARGE_TIME ; display how long it took to discharge comparator capacitor					
;		andlw	b'11111000'	;and most significiant nibble - this filtering is obsolete

					
		movwf   DISPLAY_TEMP1	;bit testing cannot operate on W

;		bcf	STATUS,C
;		rlf	DISPLAY_TEMP1
;		bcf	STATUS,C
;		rlf	DISPLAY_TEMP1
;		bcf	STATUS,C
;		rlf	DISPLAY_TEMP1 ; debug - show three bits which would usually contain just 
					;error - 0-15 , 8 cycles for TMR1 to start counting 
					; + 8 for interrupts to stop timer

		; RA4 has significant capacitance. let's initalise line select pins first then. 
		bank1
		clrf 	TRISB ; we use PORTB configured as output for that
		bcf  	TRISA,RA4 ; as PORTB is 8 bit, RA4 will select 3rd significant LED strip
					; IT REQUIRES PULL-UP POTENTIOMETER
		nop
		bcf     TRISA,RA3 ; as PORTB is 8 BIT, RA3 will select 2nd significant LED strip
		nop
		bcf 	TRISA,RA0 ; as PORTB is 8 bit, RA0 will select 1st significant LED strip. 
		bank0 
		clrf 	PORTB ; switch off all LEDS .
				;1 used as output 'on' state
		bcf	PORTA,RA4 ; RA4 is used for intensity delay routine. resetting . 
				; IT REQUIRES PULL UP AND CAPACITOR!
		nop
		bsf	PORTA,RA3 ; 2nd significant bar is off (LED cathodes connect to RA3 via resistor) 
		nop
		bsf 	PORTA,RA0 ; 1st significant bar is off (LED cathodes connect to RA0 via resistor). 
		nop 


		
		clrf 	DISPLAY_RESULT_1   ;we clear last display results
		clrf    DISPLAY_RESULT_2  
		clrf 	DISPLAY_RESULT_3		
		clrf 	DISPLAY_RESULT_4		



		btfss	DISPLAY_TEMP1,7 ; if the '16' bit is set
		goto    BIT_7_NOT
		
		bsf     STATUS,C		; insert 1 16 times. 
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		


BIT_7_NOT
		btfss   DISPLAY_TEMP1,6 ;if the '8' bit is set
		goto    BIT_6_NOT
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		
		
BIT_6_NOT:
		btfss   DISPLAY_TEMP1,5 ;if the '4' bit is set
		goto    BIT_5_NOT
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
BIT_5_NOT:

		btfss   DISPLAY_TEMP1,4 ;if the '2' bit is set
		goto    BIT_4_NOT
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
BIT_4_NOT:

		btfss   DISPLAY_TEMP1,3 ;if the '1' bit is set
		goto    BIT_3_NOT
		bsf     STATUS,C
		rlf     DISPLAY_RESULT_1
		rlf	DISPLAY_RESULT_2
		rlf	DISPLAY_RESULT_3
		rlf 	DISPLAY_RESULT_4		
BIT_3_NOT:
		
;-----------------debug-RA4 capacitance , quick hax
		clrf	INTENSITY_KNOB

		bank0   
		bsf	PORTA,RA4
		bank1 
		bsf	TRISA,RA4
		bank0 	

SET_RA4_HIGH	
		decf	INTENSITY_KNOB
		btfss	PORTA,RA4
		goto 	SET_RA4_HIGH ; go back decreasing INTENSITY_KNOB
				 	;INTENSITY_KNOB gets decreased, so shortest time of re-charge
					; will mean longest delay (intensity) 
					; if longest time of discharge happens, intensity time is shorter.
					; this way simple logarhytmic pwm is achieved 
		bank1	
		bcf	TRISA,RA4 ; make RA4 out again
		bank0

		bcf	PORTA,RA0 ; least significant byte first 

					;simple magic - check bit in display result, and switch on same bit of PORTB
					;calling intensity delay, then clear, and so on
		movfw	INTENSITY_KNOB ; load INTENSITY_KNOB value to w. it's used by INTENSITY DELAY 
					;not a very ellegant way, but it helps saving one cycle per each delay 
					;thus reducing shortest possible delay 


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
		nop			;cannot operate on same register due to pipelining, so wait
		bcf	PORTA,RA3	; more significant byte on

					; simple magic again - check bit in display result, and switch on same bit of PORTB
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

		bsf	PORTA,RA3 	; more significant byte off
		nop 			;cannot operate on same register due to pipelinging, so wait
		bcf	PORTA,RA4	; most significant byte on

					; same simple magic - check bit in display result, and switch on same bit of PORTB
					;calling intensity delay, then clear, and so on
		btfsc	DISPLAY_RESULT_3,0
		bsf	PORTB,0
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_3,1
		bsf	PORTB,1
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_3,2
		bsf	PORTB,2
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_3,3
		bsf	PORTB,3
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_3,4
		bsf	PORTB,4
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_3,5
		bsf	PORTB,5
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_3,6
		bsf	PORTB,6
		call 	INTENSITY_DELAY
		clrf	PORTB
		btfsc	DISPLAY_RESULT_3,7
		bsf	PORTB,7
		call 	INTENSITY_DELAY
		clrf	PORTB
		
		bsf	PORTA,RA4	;most significant byte off
		return 


;INTENSITY_DELAY:

		nop
;		nop	;lenght defines intensity by amount of energy pumped into each led. 

		return

INTENSITY_DELAY:
		movwf	DELAY	
INTENSITY_DELAY_LOOP1:
		decfsz	DELAY
		goto	INTENSITY_DELAY_LOOP1 
		return


; ------------------thiiiis is theory

;INTENSITY_DELAY
		bank1
		bcf	TRISA,RA1		; set RA1 pin as output - it should allow RA5 cap discharge by circuit 
		bsf 	TRISA,RA5		; tristate RA5 pin. it is tristate anyway, but let's make it input 
		bank0 				; switch back to bank0 
		bcf	PORTA,RA1		; set RA1 to 0 . it should discharge RA5 cap by circuit trickery (diode :)
INTENSITY_DELAY1:
		btfss	PORTA,RA5		; check if delay capacitor got charged, skip if yes
 		goto 	INTENSITY_DELAY1	; if no, just wait for it to happen. 

		bank1				; when done switch back to bank1
		bsf	TRISA,RA1		; set RA1 as input back 
		bank0
		return






;           Comparator Interrupt Service routine

COMP:	
		bank0
		bcf T1CON,TMR1ON ; Stop Timer 1
		bcf PIR1,CMIF    ; Clear comparator Interrupt flag
		nop
		bcf PIR1,TMR1IF  ; mask tmr1 interrupt flag
		bank1
		bcf PIE1,CMIE    ; Mask Comparator Int
		nop
		bcf PIE1,TMR1IE  ; mask tmr1 interrupt
		;PIR1 should contain reason why interrupt occured. 
		retfie 
END
