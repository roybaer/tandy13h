; experimental VGA/MCGA mode 13h emulation TSR driver for Tandy Video II
; will use 640x200x16 mode
; assemble with yasm/nasm

[bits 16]
[org 0x100]

	jmp	main

tsr10:
	cmp	ah,00h
	je	intercept_00h
	cmp	ah,0fh
	je	intercept_0fh
	cmp	ax,1a00h
	je	intercept_1a00h
normal_int_10h:
	push	word [cs:int10seg]
	push	word [cs:int10ofs]
	retf

intercept_00h:
	mov	[cs:display_mode],al
	cmp	al,13h
	je	mode_13h_requested
	cmp	al,93h
	je	mode_13h_requested
	jmp	normal_int_10h

intercept_0fh:
	cmp	byte [cs:display_mode],13h
	je	is_13h
	cmp	byte [cs:display_mode],93h
	jne	normal_int_10h
is_13h:
	mov	ah,40	; number of character columns
	mov	al,[cs:display_mode]
	mov	bl,0	; active page
	iret

intercept_1a00h:
	mov	al,ah
	mov	bx,0a0ah	; MCGA with digital color display
	iret

mode_13h_requested:
	call	set_mode_640x200x16
	mov	al,20h
	iret

int10seg dw 0000h
int10ofs dw 0000h
display_mode db 0

; data for CRTC registers 0-18, index port 3d4h, data port 3d4h
crtc_tab db 71h,50h,5ah,0efh,0ffh,6,0c8h,0e2h,1ch,0,0,0,0,0,0,0,18h,0,46h

; data for control registers, index in low byte
ctrl_tab dw 0f01h,2,1003h,105h,208h

; keep a signature somewhere to prevent double loading
signature db "TANDY13H"

; switch to 640x200x16 Tandy mode -- this is not EGA mode 0eh
set_mode_640x200x16:
	push	ax
	push	dx

	; switch to mode 3
	mov	ax,3
	int	10h

	; select 640 dot graphics mode with hi-res clock, disable video
	mov	dx,3d8h
	mov	al,13h
	out	dx,al

	; set CRTC registers

	push	ds
	push	si

	push	cs
	pop	ds
	mov	si,crtc_tab

	xor	ax,ax
	cld		; will be restored by iret

crtc_loop:
	mov	dl,0d4h	; dx=3d4h
	out	dx,al
	inc	ax
	push	ax
	lodsb
	inc	dx
	out	dx,al
	pop	ax
	cmp	al,19
	jb	crtc_loop

	; set control registers
	mov	si,ctrl_tab
ctrl_loop:
	mov	dl,0dah	; dx=3dah
	lodsw
	out	dx,al
	mov	dl,0deh	; dx=3deh
	xchg	al,ah
	out	dx,al
	cmp	ah,8
	jne	ctrl_loop

	pop	si
	pop	ds

	; clear color select register
	mov	dl,0d9h	; dx=3d9h
	mov	al,0
	out	dx,al

	; disable extended RAM paging
	mov	dl,0ddh	; dx=3ddh
	mov	al,0
	out	dx,al

	; select page 2 for CRT & CPU
	mov	dl,0dfh	; dx=3dfh
	mov	al,24h
	out	dx,al	

	cmp	byte [cs:display_mode],93h
	je	skip_clear_screen
	; clear screen
	push	es	; save es
	push	0a000h
	pop	es	; es=0a000h
	push	di	; save di
	xor	di,di	; di=0
	xor	ax,ax	; ax=0
	push	cx	; save cx
	mov	cx,32000
	rep	stosw	; write 64000 black pixels (technically 128000)
	pop	cx	; restore cx
	pop	di	; restore di
	pop	es	; restore es
skip_clear_screen:

	; select 640 dot graphics mode with hi-res clock, enable video
	mov	dl,0d8h	; dx = 3d8h
	mov	al,1bh
	out	dx,al

	pop	dx	; restore dx
	pop	ax	; restore ax

	ret

; calculate number of paragraphs to be kept resident from this label
behind_tsr_end:

main:
	; print title
	mov	dx,msg_title
	mov	ah,9
	int	21h

	; get interrupt vector for 10h (stores result in es:bx)
	mov	ax,3510h
	int	21h

	; try to figure out whether the TSR is already installed
	mov	cx,8
	mov	di,signature
	mov	si,signature
	repe	cmpsb
	; store old interrupt vector
	mov	word [int10seg],es
	mov	word [int10ofs],bx
        ; install TSR if signature check failed
	jne	install_tsr

	; TSR removal requested? (case insensitive /u)
	cmp	word [81h]," /"
	jne	already_loaded
	mov	ax,[83h]
	or	al,20h
	cmp	ax,'u'+(13<<8)
	jne	already_loaded
	; restore original interrupt vector
	mov	ax,2510h
	push	ds	; save ds
	push	word [es:int10seg]
	pop	ds
	mov	dx,[es:int10ofs]
	int	21h
	; free TSR memory; TSR segment already in es
	mov	ah,49h
	int	21h
	pop	ds	; restore ds
	mov	dx,msg_success_rem
	jmp	output_msg_and_exit
already_loaded:
	mov	dx,msg_error_already_loaded
	jmp	output_msg_and_exit

install_tsr:
	; find out whether the active graphics adapter is Tandy Video II

	; check whether it supports VGA's "read combination code"
	mov	ax,1a00h
	int	10h
	; if this is a VGA it cannot be a Tandy Video II
	cmp	al,1ah
	je	incompat_vid
	; if this is an EGA it cannot be a Tandy Video II
	mov	ah,12h
	mov	bl,10h
	int	10h
	cmp	bl,10h
	jne	incompat_vid
	; if it is neither VGA nor EGA and runs in mode 7, it cannot be a Tandy Video II with color screen
	mov	ax,0f00h
	int	10h
	cmp	al,7
	je	incompat_vid
	; check magic numbers in BIOS area to rule out PCjr and older Tandy 1000
	push	0fc00h
	pop	es
	mov	ah,[es:3ffeh]
	mov	al,[es:0]
	cmp	ax,0ff21h
	jne	incompat_vid
	; newer Tandy 1000 detected; check whether it supports "get configuration"
	mov	ah,0c0h
	int	15h
	jc	incompat_vid
	; it does => Tandy Video II detected (RL, SL and TL series)
	; go on and install the TSR
	mov	ax,2510h
	mov	dx,tsr10
	int	21h

	; print success message
	mov	dx,msg_success
	mov	ah,9
	int	21h

	; terminate and stay resident
	mov	ax,3100h
	mov	dx,(behind_tsr_end+15)>>4
	int	21h

; incompatible graphics adapter detected
incompat_vid:
	mov	dx,msg_error_incompat_vid
output_msg_and_exit:
	mov	ah,9
	int	21h
	mov	ah,0
	int	21h


msg_title db "MCGA 13h emulator for Tandy Video II - TSR $"
msg_error_already_loaded db "already loaded",10,13,"$"
msg_success db "loaded",10,13,"$"
msg_success_rem db "removed",10,13,"$"
msg_error_incompat_vid db "error: Wrong graphics adapter",10,13,"$"
