LIST            P=PIC16F627
#INCLUDE        "p16f627.inc"

        __CONFIG        _BODEN_ON & _CP_OFF & _DATA_CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_OFF & _INTRC_OSC_NOCLKOUT
bank0		macro
		bcf	STATUS,RP0
		endm
bank1		macro
		bsf	STATUS,RP0
		endm


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


		goto MAIN


CONVERT:	bank1            ; Main program loop
		bcf TRISA,1      ; Set RA1 as output
		bank0
;ifdef debug
		bcf PORTB,4	; debug, reset conversion indicator
;endif
		bcf PORTA,1      ; Discharge capacitor
		bcf PIR1,CMIF    ; Clear comp Int flag
		bank1
		bsf TRISA,1      ; Reset RA1 as input,
				 ; cap starts charging
		bsf PIE1,CMIE    ; Unmask Comp Int  
		bank0
		clrf TMR1L       ; Clear Timer 1 L
		clrf TMR1H       ; Clear Timer 1 H
		bsf T1CON,TMR1ON ; Start Timer 1
		movf CMCON,f     ; Read to sync output
		bank1
WAIT:		btfsc PIE1,CMIE  ; Wait for comp Int
				; ie wait until Int
		goto WAIT        ; Enable bit has been
				; cleared
GETDATA:			; Timer 1 contains
				; DATA (TMR1L TMR1H)

		bank0
;ifdef debug
		bsf  PORTB,4    ;debug, indicate successfull conversion
;endif 
		return




;           Comparator Interrupt Service routine

COMP:		bank0
		bcf T1CON,TMR1ON ; Stop Timer 1
		bcf PIR1,CMIF    ; Clear Interrupt flag
		bank1
		bcf PIE1,CMIE    ; Mask Comparator Int
		retfie 
END
