; experimental VGA/MCGA mode 13h emulation TSR driver for Tandy Video II
; will use 640x200x16 mode
; assemble with yasm/nasm

[bits 16]
[org 0x100]

	jmp	main

tsr10:
	cmp	ax,0013h
	je	intercept
	push	word [cs:int10seg]
	push	word [cs:int10ofs]
	retf
intercept:
	call	set_mode_640x200x16
	mov	al,20h
	iret

int10seg dw 0000h
int10ofs dw 0000h

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
	mov	ax,3510h
	int	21h

	mov	cx,8
	mov	di,signature
	mov	si,signature
	repe	cmpsb
	jne	install_tsr

	mov	dx,error_msg
	mov	ah,9
	int	21h

	mov	ah,0
	int	21h

install_tsr:
	mov	word [int10seg],es
	mov	word [int10ofs],bx

	mov	ax,2510h
	mov	dx,tsr10
	int	21h

	mov	dx,success_msg
	mov	ah,9
	int	21h

	mov	ax,3100h
	mov	dx,(behind_tsr_end+15)>>4
	int	21h

error_msg db "Error: TSR already loaded$"
success_msg db "TSR successfully loaded$"
