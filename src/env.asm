;Copyright (C) 2000 Edward Popkov <evpopkov@carry.neonet.lv>
;
;$Id: env.asm,v 1.2 2000/04/07 18:36:01 konst Exp $
;
;hackers' env
;
;0.01: 27-Feb-2000	initial release
;
;syntax: env


%include "system.inc"

CODESEG

START:
	pop	ebp
.env:
	inc	ebp
	mov	esi,[esp + ebp * 4]
	test	esi,esi
	jz	_exit
	mov	ecx,esi
	xor	edx,edx
	dec	edx
.slen:
	inc	edx
	lodsb
	test	al,al
	jnz	.slen
	mov	[esi-1],byte 0xa
	inc	edx
	sys_write STDOUT
	jmps	.env

_exit:
	sys_exit_true

END
