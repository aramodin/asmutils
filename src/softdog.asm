;Copyright (C) 1999-2001 Konstantin Boldyshev <konst@linuxassembly.org>
;
;$Id: softdog.asm,v 1.4 2001/02/23 12:39:29 konst Exp $
;
;hackers' softdog (software watchdog)
;
;syntax: softdog [PERIOD]
;
;PERIOD (in seconds) - kick period, if missing use default of 10
;
;example:	softdog
;		softdog 15
;
;0.01: 04-Jul-1999	initial release
;0.02: 29-Jul-1999	fixed bug with sys_open
;0.03: 18-Sep-1999	elf macros support
;0.04: 22-Jan-2001	minor size improvement

%include "system.inc"

%assign	DEFPERIOD	10	;default period
%assign	MAXPERIOD	60	;maximum kernel margin

CODESEG

;ebp - period

START:
	_mov	ebp,DEFPERIOD
	pop	esi
	dec	esi
	jz	.start
	pop	esi
	pop	esi

	xor	eax,eax
	xor	ebx,ebx
.next_digit:
	lodsb
	sub	al,'0'
	jb	.done
	cmp	al,9
	ja	.done
	imul	ebx,byte 10
	add	ebx,eax
	_jmp	.next_digit
.done:
	or	ebx,ebx		;zero?
	jz	.start
	_mov	eax,MAXPERIOD
	cmp	ebx,eax			;if more than max - set max
	jb	.start0
	mov	ebx,eax
.start0:
	mov	ebp,ebx
.start:
	mov	[t.tv_sec],ebp

	sys_open softdog,O_WRONLY
	mov	ebp,eax
	test	eax,eax
	js	.exit

	sys_fork
	or	eax,eax
	jz	.child
.exit:
	sys_exit

.child:
	sys_write ebp,softdog,1
	sys_nanosleep t,NULL
	_jmp	.child

softdog	db	'/dev/watchdog',EOL

UDATASEG

t I_STRUC timespec
.tv_sec		ULONG	1
.tv_nsec	ULONG	1
I_END

END
