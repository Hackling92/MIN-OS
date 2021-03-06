;MIN-OS-Serial -  VER 1.2A
;
;
;EEPROM located at 0000h - 2000h
;Ram located at 8000h - C000h !!!!!!!!!! CHECK ME !!!!!!!!!!!!!!!
;Input Buffer located at 8000h - 8080h
;Stack Pointer at 0C000h
;
;If this code is used in any way give credit to hackling92.  Nothing special just use my name. Thanks




	; start the program at memory region 1 for programing simplicity
	.ORG 0001h

lf	EQU 0Ah		; declair Line Feed
STACK	EQU 0C000h	; stack pointer

	LD SP,STACK	; set the stack pointer


inituart:
	LD A,10000000b  ; set div latch enable 1
	OUT (03h),A	; write lcr
	LD A,0Ch		; set Divisor
	OUT (00h),A	; dll 0x07 (#7)
	LD A,00h
	OUT (01h),A	; dlm 0x00
	LD A,00000011b	; set dle to 0, break to 0, no parity, 1 stop bit, 8 bytes
	OUT (03h),A	; write new configured lcr
	JP startloop	; program start
		

;-----------------------
putc:			;Put Charactor Loop
	CALL tx_ready
	OUT (00h), A
	RET

puts:			;Put String Loop
	PUSH AF
	PUSH HL
puts_loop:
	LD A, (HL)
	CP 0
	JR Z, puts_end
	CALL putc
	INC HL
	JR puts_loop
puts_end:
	POP HL
	POP AF
	RET
;-----------------------


tx_ready:		;Check For Charactor In UART
	PUSH AF
tx_ready_loop:
	IN A, (05h)
	BIT 5, A
	JR Z, tx_ready_loop
	POP AF
	RET


;-----------------------

uin:			;Get Charactor
	IN A, (05h)
	BIT 0,A
	JP Z,uin
	IN A,(00h)
	RET


;-----------------------

make_hex:		; convert ascii from uart to hex
	LD B,0
	CALL h1
	RLCA
	RLCA
	RLCA
	RLCA
	LD B,A
h1:
	CALL uin
	LD C,A
	CALL putc
	AND 070h
	CP 040h
	JP C,h2
	LD A,C
	AND 00Fh
	ADD A,9
	JP h3
h2:
	LD A,C
	AND 00Fh
h3:
	OR B
	RET

;-----------------------	
	
startloop:		; starting point for program	
	LD HL, starttext	;Load Start Message Location
	CALL puts	; print start message

;----------------------------------------------
command_loop:
	CALL uin
	CALL putc
	CP 4Ah
	JP Z,j_loop
	CP 50h
	JP Z,p_loop
	CP 52h
	JP Z,r_loop


j_loop:
	CALL uin
	CALL putc
	CP 4Dh		;JM COMMAND
	JP Z,8100h

p_loop:
	CALL uin
	CALL putc
	CP 45h		;PE COMMAND
	JP Z,pe_com
	CP 4Fh		;PO COMMAND
	JP Z,po_com

r_loop:
	CALL uin
	CALL putc
	CP 53h		;RS COMMAND
	JP Z,0000h
	CP 50h		;RP COMMAND "REMOTE PROGRAM"
	JP Z,serial_program


start_add:		; PE/PO Start Address
	DEFB "Start Add: ",0
end_add:		; PE End Address
	DEFB "End Add: ",0
new_dat:		; New Data For PO Command
	DEFB "New Data: ",0
address:		; Address Text
	DEFB "Address: ",0

;---------------------------------------------------
pe_com:
	LD HL, start_add
	CALL puts
	CALL make_hex
	LD D,A
	CALL make_hex
	LD E,A
	LD HL, end_add
	CALL puts
	LD BC,0000h
	CALL make_hex
	LD D,A
	CALL make_hex
	LD E,A

po_com:
	LD HL, address
	CALL puts
	;add func here from above
	LD HL, new_dat
	CALL puts
	;add func here

;---------------------------------------------------

serial_program:
	LD HL,8100h	; set location to store program sent from serial terminal
secloop:
	CALL uin
	CALL putc
	CP 7Fh		; Check for delete to know when to execute program in ram
	JP Z,8100h	; If delete jump to ram location
	LD (HL),A	; used to store above hex into memory
	INC HL		; incriment hl for next byte
	JP secloop	; loop until makehex finds 'del', then execute jump to 8100h
	
	HALT		; stop cpu in the event that the program misbehaves 


starttext:		; start message
	DEFB "Ready: ", lf,0
	
	

	;.ORG 00F0H
start:	
	LD A, 1H

loop:
	CALL putc
	LD B, A
	LD A, 99h
	CP B
	JP Z, start
	LD A, B
	INC A
	JP loop

	.ORG 8100H

	;LD HL,8110H
	;LD DE,00F0H
	;LD BC,32
	;LDIR
	JP 00FFH