;Copyright (C) 2000 Dmitry Bakhvalov <dl@gazeta.ru>
;
;$Id: rm.asm,v 1.2 2001/02/23 12:39:29 konst Exp $
;
;hackers' rm
;
;syntax: rm [-r] file...
;
;If someone really feels like he needs more of the original GNU rm's
;options - just ask me or better yet add 'em yourself :)
;
;Send me any feedback,suggestions,additional code, etc.

		%include "system.inc"
		CODESEG
START:
		pop	ecx			; get argc
		cmp	ecx,byte 2		; must have at least 2 args
		jl	near invalid_args

		pop	eax			; skip argv[0]
		dec	ecx			; dont count argv[0]
		
		xor	ebp,ebp			; -r flag
						
		pop	ebx			; let's test for "-r" option
		cmp	word [ebx],"-r"
		jnz	not_recursive
		inc	ebp			; set recursive flag
		jmp	args_loop
not_recursive:		
		push	ebx			; put the arg back

args_loop:
		pop	edi
		test	edi,edi
		jz	no_more_args
		
		call	is_dir
		jnz	rm_file
		
		test	ebp,ebp			; it's a dir and no -r flag
		jz	args_loop		; set. so we skip this arg
		
		push	edi			; dir to rm
		call	rm			; rm files
		pop	ebx			; 
		sys_rmdir			; rm the dir itself
		jmp	args_loop
rm_file:
		sys_unlink edi			; rm the file
		
		jmp	args_loop
		
no_more_args:
invalid_args:
		sys_exit_true			; exit


;
;
		%define	CALL_FRAME	8
		%define SRC_DIR		(CALL_FRAME+0)
		%define HANDLE_SIZE	4
		%define HANDLE_OFFS	(HANDLE_SIZE+0)
		%define DENTS_BUF_SIZE	266
		%define DENTS_BUF_OFFS	(DENTS_BUF_SIZE+HANDLE_OFFS)
		%define BUF_SIZE	4096
		%define BUF_OFFS	(DENTS_BUF_OFFS+BUF_SIZE)
		%define LOCAL_BUFSIZE	(HANDLE_SIZE+DENTS_BUF_SIZE+BUF_SIZE)
rm:
		push	ebp
		mov	ebp,esp
		sub	esp,LOCAL_BUFSIZE

		mov	edi,[ebp+SRC_DIR]		; src must be a dir
		call	is_dir
		jnz	near .error

		sys_open [ebp+SRC_DIR],O_RDONLY		; opendir(src)
		test	eax,eax
		js	near .error
		
		mov	[ebp-HANDLE_OFFS],eax

.next_dentry:		
		lea	ecx,[ebp-DENTS_BUF_OFFS]
		sys_getdents [ebp-HANDLE_OFFS],EMPTY,DENTS_BUF_SIZE
		test	eax,eax
		js	near .error
		jz	near .done
		
		mov	edi,ecx				; edi = buf
		mov	ecx,eax				; ecx = rc
		
.main_loop:
		lea	edx,[edi+10]			; edx = filename
		mov	ax,0x002E
		cmp	byte [edx],al			; starts with "." ?
		jnz	.without_dots			; nope
		cmp	byte [edx+1],ah			; null?
		jz	.skip				; skip "." dir
		cmp	word [edx+1],ax			; ".." dir
		jz	.skip				; skip it
	    
.without_dots:
		push	edi				; save buf ptr

		lea	edi,[ebp-BUF_OFFS]		; tmp buffer
		mov	esi,[ebp+SRC_DIR]		; dst dir
							; edx hold filename
		call	full_name			; create fullname
		
							; edi holds tmp buffer
		call	is_dir
		jnz	.its_a_file
		
		
		pushad					; call ourself
		push	edi				; fullname
		call	rm
		pop	ebx				; remove the dir itself
		sys_rmdir
		popad
		jmp	.next

.its_a_file:
		; rm the damn file
		sys_unlink edi
.next:
		pop	edi				; restore buf ptr
.skip:
		xor	eax,eax
		mov	ax,[edi+8]			; eax=rec_len
		
		add	edi,eax
		sub	ecx,eax
		
		jnz	.main_loop
		jmp	.next_dentry
		
.done:
		mov	ebx,[ebp-HANDLE_OFFS]
		sys_close

.error:		
		add	esp,LOCAL_BUFSIZE
		pop	ebp
		ret		

		

;
; ----------------------------- procedures ------------------------------------
;

; edi - tmp buf, esi - dir, edx - file
;
full_name:
		pushad
		call	strcpy
		call	fix_slash
		mov	esi,edx
		call	strcat
		popad
		ret

; edi=file name
; -
fix_slash:
		push	edx
		push	esi
		
		mov	esi,edi
		call	strlen
		dec	edx
		
		mov	ax,0x002F
		cmp	byte [edi+edx],al
		jz	.ok
		
		inc	edx
		mov	word [edi+edx],ax
.ok:
		pop	esi
		pop	edx
		ret
		

; edi = file name
; zero flag = 1 if dir; carry flag=1 if file doesnt exists
is_dir:
		pushad
		
		sys_stat edi,stat_buf
		test	eax,eax
		js	.error
		
		movzx	eax,word [stat_buf.st_mode]
		mov	ebx,40000q
		and	eax,ebx
		cmp	eax,ebx
		clc				; file exists
		jmp	.popit
.error:
		stc				; if file doesnt exist set
						; carry flag
.popit:						
		popad
		ret		


; esi=string
; edx=strlen
strlen:
		push	eax
		push	esi
		
		xor	eax,eax
		mov	edx,eax
		dec	edx
.do_strlen:
		inc	edx
		lodsb
		test	al,al
		jnz	.do_strlen
		
		pop	esi
		pop	eax
		ret


; esi=source  edi=dest
; -
strcpy:
		pushad
				
		call	strlen
		inc	edx		; copy NULL too
		mov	ecx,edx
		rep	movsb
		
		popad
		ret


; esi=source  edi=dest
; -
strcat:
		pushad
				
		xchg	esi,edi
		call	strlen
		
		xchg	esi,edi
		add	edi,edx
		
		call	strlen
		inc	edx		; copy NULL byte too
		mov	ecx,edx
		rep 	movsb		; copy
		
		popad
		ret


		UDATASEG
buf:		resb	4096
buf_size	equ 	$-buf

stat_buf I_STRUC stat
.st_dev		USHORT	1
.__pad1		USHORT	1
.st_ino		ULONG	1
.st_mode	USHORT	1
.st_nlink	USHORT	1
.st_uid		USHORT	1
.st_gid		USHORT	1
.st_rdev	USHORT	1
.__pad2		USHORT	1
%ifdef __BSD__
.st_atime	ULONG	1
.st_atimensec	ULONG	1
.st_mtime	ULONG	1
.st_mtimensec	ULONG	1
.st_ctime	ULONG	1
.st_ctimensec	ULONG	1
.st_size	ULONG	1
.st_blocks	ULONG	1
.__pad3		ULONG	1
.st_blksize	ULONG	1
.st_flags	ULONG	1
.st_gen		ULONG	1
.st_lspare	ULONG	3
%else
.st_size	ULONG	1
.st_blksize	ULONG	1
.st_blocks	ULONG	1
.st_atime	ULONG	1
.__unused1	ULONG	1
.st_mtime	ULONG	1
.__unused2	ULONG	1
.st_ctime	ULONG	1
.__unused3	ULONG	1
%endif
.__unused4	ULONG	1
.__unused5	ULONG	1
I_END

		END
