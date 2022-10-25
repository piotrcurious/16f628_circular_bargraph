LIST            P=PIC16F627
#INCLUDE        "p16f627.inc"

        __CONFIG        _BODEN_ON & _CP_OFF & _DATA_CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_OFF & _INTRC_OSC_NOCLKOUT

;---------macros

bank0		macro
		bcf	STATUS,RP0
		endm
bank1		macro
		bsf	STATUS,RP0
		endm

;---------RAM registers

SAVE_W          EQU             0X50    ; TEMP FOR ISR
SAVE_S          EQU             0X51    ; TEMP FOR ISR
SAVE_P          EQU             0X52
recogn_counter	EQU		0x53	; recognitions counter
interrupt_counter EQU 		0x54    ; counter of interrupts
		org 0            ; Reset Vector
		goto INIT

		org 4            ; Interrupt Vector
		goto COMP
		org 5

INIT:		bank0
		movlw H'05'      ; Comp config mode 5
		movwf CMCON
		movlw H'14'      ; Timer 1 prescale by 2
		movwf T1CON      ; A 1 MHz clock is used
		clrf PORTA
		clrf PORTB
		bank1
		clrf	TRISB	; all RB are outputs 
		movlw H'CF'      ; Enable Vref = 3.6v
		movwf VRCON
		bsf INTCON,GIE   ; Enable Global Int
		bsf INTCON,PEIE  ; Unmask Peripheral Int

CONVERT:
		bank1
WAIT:		btfsc PIE1,CMIE  ; Wait for comp Int
				; ie wait until Int
		goto WAIT        ; Enable bit has been
				; cleared
GETDATA:			; Timer 1 contains
		
				; light level value

		bank0 

		btfss   interrupt_counter,0
		bcf	PORTB,4
		btfsc   interrupt_counter,0
		bsf	PORTB,4
		

		goto CONVERT     ; Loop for new data

;           Comparator Interrupt Service routine

COMP:		
	        MOVWF   SAVE_W                  ; SAVE W REGISTER
        	SWAPF   STATUS,W                ; SWAP STATUS TO BE SAVED INTO W
        	MOVWF   SAVE_S                  ; SAVE STATUS REGISTER
        	SWAPF   PCLATH,W
        	MOVWF   SAVE_P                  ; SAVE PCLATH

		bank0 
; DEBUG

		decf  interrupt_counter
		bcf T1CON,TMR1ON ; Stop Timer 1
		bcf PIR1,CMIF    ; Clear Interrupt flag
		bank1
		bcf PIE1,CMIE    ; Mask Comparator Int

		bank1            ; 
		bcf TRISA,1      ; Set RA1 as output
		bank0
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


	        SWAPF   SAVE_P,W
       		MOVWF   PCLATH                  ; RESTORE PCLATH
        	SWAPF   SAVE_S,W
        	MOVWF   STATUS                  ; RESTORE STATUS REGISTER - RESTORES BANK
        	SWAPF   SAVE_W,F
        	SWAPF   SAVE_W,W                ; RESTORE W REGISTER

		retfie 
END
