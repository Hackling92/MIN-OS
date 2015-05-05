;MIN-OS-Serial -  VER 1.0A
;
;
;Ram located at 8000h
;Stack Pointer at 88FFh
;Change as needed
;If this code is used give credit to hackling92.  Nothing special just use my name. Thank You




	; start the program at memory region 1 for programing simplicity
	.ORG 0001h

lf	EQU 0Ah		; declair Line Feed

	LD SP,88FFh	; set the stack pointer


inituart:
	LD A,10000000b  ; set div latch enable 1
	OUT (03h),A	; write lcr
	LD A,01h	; set Divisor to 1 for 115200 baud
	OUT (00h),A	; dll 0x07 (#7)
	LD A,00h
	OUT (01h),A	; dlm 0x00
	LD A,00001011b	; set dle to 0, break to 0, odd parity, 1 stop bit, 8 bytes
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
	CALL make_uppercase
	CP 58h		;X
	JP Z,command_loop_aborted
	RET


;-----------------------

new_line:			;Print Line Feed
	CALL tx_ready
	LD A, lf
	OUT (00h), A
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



Num2Hex:
	LD A,H
	CALL Num1
	LD D,A
	LD A,H
	CALL Num2
	LD E,A

Num1:
	RRA
	RRA
	RRA
	RRA
Num2:
	OR 240
	DAA
	ADD A,160
	ADC A,40h
	LD C,A
	
	RET


;-----------------------

make_uppercase:			;Makes lowercase Hex uppercase Hex

	CP 60h
	JP c,make_uppercase_end	;This in conjuntion with the line below check to see of A was less then 60h
	JP z,make_uppercase_end

	LD B,20h		;Subtract 20h to convert lowercase to uppercase
	SUB B
	RET
make_uppercase_end:
	RET

;-----------------------

get_string:
	LD HL,8000h
get_string_2:
	CALL uin
	CP 0Dh			;ENTER
	JP Z,get_string_1
	CP 08h			;BACKSPACE
	JP Z,get_string_3
	CALL putc
	LD (HL),A
	INC HL
	JP get_string_2
get_string_1:
	LD (HL),00h
	RET
get_string_3:
	LD D,H
	LD E,L
	DEC DE
	LD A,(DE)
	CP 0h
	JP Z,get_string_2
	DEC HL
	LD A,08h
	CALL putc
	JP get_string_2

;-----------------------

string_cmp:
	LD DE,8000h
string_cmp_2:
	LD A,(DE)
	CP (HL)
	JP Z,string_cmp_1
	JP string_cmp_fail
string_cmp_1:
	LD A,(HL)
	CP 0h
	JP Z,string_cmp_pass
	INC HL
	INC DE
	JP string_cmp_2
string_cmp_fail:
	OR A
	RET
string_cmp_pass:
	SCF
	RET

;-----------------------
	
startloop:			; starting point for program	
	LD HL, starttext	; Load Start Message Location
	CALL puts		; print start message
	JP command_loop

;----------------------------------------------
command_loop_aborted:
	LD HL, abort_msg
	CALL puts
command_loop:
	CALL new_line
	LD HL,command_msg
	CALL puts
	CALL get_string

	LD HL,peek_command	;PEEK COMMAND
	CALL string_cmp
	JP C,pe_com

	LD HL,poke_command	;POKE COMMAND
	CALL string_cmp
	JP C,po_com

	LD HL,poke+_command	;POKE+ COMMAND
	CALL string_cmp
	JP C,p_plus_com

	LD HL,reset_command	;RESET COMMAND
	CALL string_cmp
	JP C,rs_com

	LD HL,jump_command	;JUMP COMMAND
	CALL string_cmp
	JP C,jm_com

	LD HL,program_command	;PROGRAM COMMAND
	CALL string_cmp
	JP C,rp_com

	LD HL,invalid_msg
	CALL puts
	JP command_loop



jm_com:
	JP Z,8101h
	JP command_loop



rs_com:
	JP Z,0000h
	CALL command_loop

rp_com:
	JP Z,serial_program
	JP command_loop


;---------------------------------------------------
pe_com:			;Peek Command
	CALL new_line
	LD HL, address
	CALL puts
	CALL make_hex
	LD D,A
	CALL make_hex
	LD E,A
	CALL new_line
	LD A,(DE)
	LD H,A
	CALL Num2Hex
	LD A,D
	CALL putc
	LD A,E
	CALL putc
	CALL new_line
	JP command_loop


po_com:			;Poke Command
	CALL new_line
	LD HL, address
	CALL puts
	CALL make_hex
	LD D,A
	CALL make_hex
	LD E,A
	CALL new_line
	LD HL,data_msg
	CALL puts
	CALL make_hex
	LD (DE),A
	CALL new_line
	JP command_loop


p_plus_com:		;Poke Command With Auto Inc
	CALL new_line
	LD HL,start_add
	CALL puts
	CALL make_hex
	LD D,A
	CALL make_hex
	LD E,A
	CALL new_line
p_plus_com_loop_1:
	LD HL,data_msg
	CALL puts
	CALL make_hex
	LD (DE),A
	CALL new_line
	INC DE
	JP p_plus_com_loop_1

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

	



;Strings
;--------------------------------------------------
start_add:		; PE/PO Start Address
	DEFB "Start Add: ",0
end_add:		; PE End Address
	DEFB "End Add: ",0
new_dat:		; New Data For PO Command
	DEFB "New Data: ",0
address:		; Address Text
	DEFB "Address: ",0
starttext:		; start message
	DEFB "READY", lf,0
command_msg:		; Enter Command message
	DEFB "Command: ",0
data_msg:		; Data Message
	DEFB "Data: ",0
abort_msg:		; Abort Message
	DEFB "Aborted", lf,0
invalid_msg:		; Abort Message
	DEFB "Invalid Com", lf,0
;--------------------------------------------------



;Command Strings
;--------------------------------------------------

peek_command:
	DEFB "PEEK",0
poke_command:
	DEFB "POKE",0
poke+_command:
	DEFB "POKE+",0
reset_command:
	DEFB "RESET",0
jump_command:
	DEFB "JUMP",0
program_command:
	DEFB "PROGRAM",0

;--------------------------------------------------
	


	.ORG 8101h
	CALL get_string
	LD HL,starttext
	CALL string_cmp
	JP startloop
