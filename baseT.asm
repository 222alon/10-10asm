; -------------------------------------------------------------------------------------------------------------
; 1010 By Alon Levi, God bless our souls
; -------------------------------------------------------------------------------------------------------------
IDEAL
MODEL small
STACK 100h
DATASEG

game_grid db 100 dup (0) ; The actual game grid, shows the status of each square. 

screen_status db 0 ; Stores the current screen which is being presented, 0 for main menu, 1 for credits, 2 for game screen, 3 for game over screen.
menu_ptr db 1 ; Which button in the menu is currently "focused", for kb use.

shape_hold_status db 2 dup (0) ; The status of if the user is currently holding a shape , and which shape the user holds (block_hold_status +0 for shape hold status, +1 for which shape)
held_shape_source db 0 ; Where the help shape came from

cur_shapes db 3 ; Stores the current shapes which are in the shape storage. 0 is no shape

cur_score dw ?  ; The current score of the user.
high_score dw ?; The highest score achieved in the game, To be read/written in a text file, max score is 65,536. 

check_grid db 25 dup (0) ; Used to convert the shape ID to a shape, and put the shape in the grid

seed dw ? ; The current seed , Used in the random number generator

mouse_x dw 0 ; The X position of the mouse
mouse_y dw 0 ; The Y position of the mouse

mouse_grid_x db 0 ; The X position of the mouse on the grid
mouse_grid_y db 0 ; The Y position of the mouse on the grid

mouse_left_click dw 0 ; The status of the mouse's left click key, 0 = not pressed , 1 = pressed
mouse_right_click dw 0 ; The status of the mouse's right click key, 0 = not pressed , 1 = pressed

clear_clicked_shape db '    ' , 13 , '$' ; Clears the clicked shaped (used for testing)

checked_game_grid db 100 dup (0) ; The game grid of the "next turn", used to apply the clearing of multiple lines at once

check_fill db 0 ; Used by the clearing checks to check if a Row/Columm is filled

; IMAGE LOADING
menu_image db 'images\screens\menu3.bmp' , 0 ; Menu image, 320x200
game_image db 'images\screens\game3.bmp' , 0 ; Game screen image, 320x200
ptr_image db 'images\screens\ptr.bmp' , 0 ; Pointer image, 27x17
cred_image db 'images\screens\cred.bmp' , 0 ; Image of the credit screen, size 320x200
lose_image db 'images\screens\lose.bmp' , 0 ; Image of the lose screen , size 320x200
colors_image db 'images\colors.bmp' , 0 ;An image with many colors, only used as a pallet (unused)
square_image_black db 'images\square.bmp' , 0 ; A black 10x10 square
square_image_red db 'images\squareR.bmp' , 0 ; A red 10x10 square
square_image_blue db 'images\squareB.bmp' , 0 ; A blue 10x10 square

filehandle dw ?
Header db 54 dup (0)
Palette db 256*4 dup (0)
ScrLine db 320 dup (0)
ErrorMsg db 'Error!', 13 , '$' 

CODESEG




; IMAGE FILE DRAWING AND SQUARE PAINTING SEGMENT

	proc OpenFile
		; Open file / using file handling
		push bp
		mov bp,sp
		filename equ [bp + 4]
		mov dx,filename
		mov ah, 3Dh
		xor al, al
		int 21h
		pop bp
		jc openerror
		mov [filehandle], ax

		ret 2
		openerror :
			mov dx, offset ErrorMsg
			mov ah, 9h
			int 21h
			ret 2
		
		endp OpenFile
	
	proc ReadHeader
		; Read BMP file header, 54 bytes
		mov ah,3fh
		mov bx, [filehandle]
		mov cx,54
		mov dx,offset Header
		int 21h
		ret
		endp ReadHeader

	proc ReadPalette
		; Read BMP file color palette, 256 colors * 4 bytes (400h)
		mov ah,3fh
		mov cx,400h
		mov dx,offset Palette
		int 21h
		ret
		endp ReadPalette

	proc CopyPal
		; Copy the colors palette to the video memory
		; The number of the first color should be sent to port 3C8h
		; The palette is sent to port 3C9h
		mov si,offset Palette
		mov cx,256
		mov dx,3C8h
		mov al,0
		; Copy starting color to port 3C8h
		out dx,al
		; Copy palette itself to port 3C9h
		inc dx
		PalLoop1:
			; Note: Colors in a BMP file are saved as BGR values rather than RGB .
			mov al,[si+2] ; Get red value .
			shr al,1
			shr al,1; Max. is 255, but video palette maximal
			; value is 63. Therefore dividing by 4.
			out dx,al ; Send it .
			mov al,[si+1] ; Get green value .
			shr al,1
			shr al,1
			out dx,al ; Send it .
			mov al,[si] ; Get blue value .
			shr al,1
			shr al,1
			out dx,al ; Send it .
			add si,4 ; Point to next color .
			; (There is a null chr. after every color.)

			loop PalLoop1
		ret
		endp CopyPal
	
	proc CopyBitmap
		; recieves 4 parameters  - > x pos , y pos, width,height
		; BMP graphics are saved upside-down .
		; Read the graphic line by line (200 lines in VGA format),
		; displaying the lines from bottom to top.
		mov ax, 0A000h
		mov es, ax
		push bp
		mov bp,sp
		yVal equ [bp + 4]
		xVal equ [bp + 6]
		yPos equ [bp + 8]
		xPos equ [bp + 10]

		mov cx,yVal
		PrintBMPLoop1:
			;combine result of mul with ax and cx to get the correct position on the screen
			
			push cx
			mov ax,320
			mul cx

			mov di,ax

			;Calculation of X position:
			add di,xPos

			; Calculation of Y position:
			mov ax,320
			
			mul yPos
			add di,ax

			; Read one line
			mov ah,3fh
			mov cx,xVal ;The amount of width of the image in the file handling
			mov dx,offset ScrLine
			int 21h
			; Copy one line into video memory
			cld ; Clear direction flag, for movsb
			mov cx,xVal
			mov si,offset ScrLine

			rep movsb ; Copy line to the screen
			 ;rep movsb is same as the following code :
			 ;mov es:di, ds:si
			 ;inc si
			 ;inc di
			 ;dec cx
			 ;loop until cx=0
			pop cx
			loop PrintBMPLoop1
			pop bp
			ret 8

		endp CopyBitmap
	
	proc CloseFile
		mov ah,3Eh
		mov bx, [filehandle]
		int 21h
		ret
		endp CloseFile

; Grid drawing chunk

	proc Draw_Shapes
		; Draws the grid based on the values in game_grid
		
		

		mov cx, 100

		
			draw_squares_loop:
			mov bx, cx
			dec bx
			xor dh, dh
			mov dl, [game_grid + bx] 
			cmp dl , 1
			jne end_squares_loop

			call Memory_To_Grid
			
			
			push ax
			push bx


			call PaintSquare_Grid

			

			end_squares_loop:
			loop draw_squares_loop

		
		ret
		endp Draw_Shapes

	proc PaintSquare_Grid
		; paints a square at given x , y coords, bp + 6 = x, bp + 4 = y
		push bp
		mov bp, sp
		xPos equ [bp+6]
		yPos equ [bp+4]

		push cx

		mov al , 11
		mul xPos
		mov xPos , al

		mov al , 11
		mul yPos
		mov yPos , al

		add xPos , 107
		add yPos , 47

		push offset square_image_red
		call OpenFile
		call ReadHeader
		call ReadPalette
		call CopyPal

		push xPos
		push yPos
		push 10
		push 10
		call CopyBitmap
		call CloseFile

		; mov al , 2
		; mov bl , 0
		; mov cx, 10
		; mov si , 0 ; which Line it paints
		; mov di , 0 ; which pixel it paints in each line
		; linesLoop:
		; 	push cx
		; 	mov cx , 10
		; 	lineLoop:
		; 		push cx
		; 		mov cx, xPos
		; 		add cx, si
		; 		mov dx , yPos
		; 		add dx, di
		; 		; paint the pixel
		; 		mov ah,0ch
		; 		int 10h
		; 		; increase the Y value
		; 		inc di

		; 		pop cx
		; 		loop lineLoop

		; 	inc si ;incease X value
		; 	mov di, 0
		; 	pop cx
		; 	loop linesLoop

		pop cx
		pop bp
		ret 4
		endp PaintSquare_Grid

; Memory-Grid Functions chunk

	proc Memory_To_Grid
		; Recieves a position in memory over BX, translates it and returns the X pos over ax, Y pos over bx

		xor ah , ah
		mov al , bl
		mov bl , 10
		div bl ; ah contains the X val, al contains the Y val
		xor bh , bh
		mov bl , al
		mov al , ah 
		xor ah , ah

		ret
		endp Memory_To_Grid

	proc Grid_To_Memory
		; Recieves a position on the grid , returns a position in the memory over ax
		push bp
		mov bp, sp
		push bx
		xPos equ [bp+6]
		yPos equ [bp+4]

		cmp xPos, 10
		jb legal_range
		mov ax , 100
		jmp end_grid_to_memory_conv

		legal_range:
		mov al , yPos
		mov bl , 10
		mul bl
		add ax , xPos
		
		end_grid_to_memory_conv:
		pop bx
		pop bp
		ret 4
		endp Grid_To_Memory

	proc Check_Memory_To_Grid
		; Recieves a position in check_grid memory over AX, translates it and returns the X pos over ax, Y pos over bx

		mov bl , 5
		div bl ; ah contains the Y value, al contains the X value
		mov bl , ah
		xor bh , bh
		xor ah , ah

		ret
		endp Check_Memory_To_Grid

proc Check_requirement
	; Recieves a position on the grid and a shape ID (specified in a seperate document), checks if given shape can fit at given coords 
	; returns 0 over ax if the shape can be placed, 1 if it can't
	push bp
	mov bp, sp


	xPos equ [bp + 8]
	yPos equ [bp + 6]

	shape_ID equ [bp + 4]

	push shape_ID
	call ID_to_shape

	
	final_check:

	mov cx , 25

	final_check_loop:

		mov bx, cx
		dec bx

		cmp [check_grid + bx] , 1
			jne final_check_loop_end

		mov ax , bx
		call Check_Memory_To_Grid

		add ax , xPos
		add bx , yPos
		push ax
		push bx
		call Grid_To_Memory
		mov di , ax ; di contains correct address


		

		
		mov dx , di
		
		final_check_1:
			cmp dx , 99
				jna final_check_2
				mov ax , 1
				jmp end_check
		final_check_2:
			cmp [game_grid + di] , 1
				jne final_check_loop_end
				mov ax , 1
				jmp end_check
			
			final_check_loop_end:
		loop final_check_loop

	mov ax , 0

	end_check:
	

	pop bp
	ret 6 
	endp Check_requirement

; Set drawing chunk

	proc Draw_Current_Shapes
		; Draws the shapes in cur_shapes on the set
		push ax
		
		xor ah , ah
		mov al , [cur_shapes]
		push ax
		call ID_to_shape
		push 1
		call PaintShape_Set

		xor ah , ah
		mov al , [cur_shapes + 1]
		push ax
		call ID_to_shape
		push 2
		call PaintShape_Set

		xor ah , ah
		mov al , [cur_shapes + 2]
		push ax
		call ID_to_shape
		push 3
		call PaintShape_Set

		pop ax

		ret
		endp Draw_Current_Shapes

	proc PaintShape_Set
		; paints a shape (check_grid) at given index inside the set area
		push bp
		mov bp, sp
		indx equ [bp+4]
		sub sp , 4
		xPos equ [bp-2]
		yPos equ [bp-4]
		push cx 

		indx_1_check:
			cmp indx , 1
			jne indx_2_check ; Jump to next check
			mov xPos , 252
			mov yPos , 16
			jmp start_shape_set_loop

		indx_2_check:
			cmp indx , 2
			jne indx_3_check ; Jump to next check
			mov xPos , 263
			mov yPos , 73
			jmp start_shape_set_loop

		indx_3_check:
			mov xPos , 252
			mov yPos , 130
			jmp start_shape_set_loop

		start_shape_set_loop:
		mov cx , 25


		paint_shape_set_loop:

			mov bx, cx
			dec bx

			cmp [check_grid + bx] , 1
				jne paint_shape_set_loop_end

			mov ax , bx

			call Check_Memory_To_Grid

			mov dx, bx

			mov bl , 11
			mul bl

			add ax , xPos ; The X value to paint the square on
			push ax

			mov ax , dx
			mov bl , 11
			mul bl

			add ax , yPos ; The Y value to paint the square on
			push ax

			call PaintSquare


			paint_shape_set_loop_end:
			loop paint_shape_set_loop

			pop cx
			add sp , 4
			pop bp
			ret 2
		endp PaintShape_Set

	proc PaintSquare
		; paints a square at given x , y coords, bp + 6 = x, bp + 4 = y
		push bp
		mov bp, sp
		xPos equ [bp+6]
		yPos equ [bp+4]

		push cx

		push offset square_image_black
		call OpenFile
		call ReadHeader
		call ReadPalette
		call CopyPal

		push xPos
		push yPos
		push 10
		push 10
		call CopyBitmap
		call CloseFile

		pop cx
		pop bp
		ret 4
		endp PaintSquare

proc ID_to_shape
	; The function recieves an ID and translates it into data on check_grid, recieves shape ID

	push bp
	mov bp , sp
	shape_ID equ [bp + 4]

	push ax
	push bx
	push cx
	push dx

	mov cx , 25
	check_grid_reset: ; resets the checking grid
		mov bx , cx
		dec bx
		mov [check_grid + bx] , 0
		loop check_grid_reset

	mov al , shape_ID

	; big V segment

		check_specific_19:
	        cmp al , 19 ; ID nm 19 , the big V "facing" bottom left
	        jne check_specific_18

	        mov [check_grid + 2] , 1
	        mov [check_grid + 7] , 1
	        mov [check_grid + 12] , 1
			mov [check_grid + 11] , 1
			mov [check_grid + 10] , 1

	        jmp end_convert

        check_specific_18:
	        cmp al , 18 ; ID nm 18 , the big V "facing" bottom right
	        jne check_specific_17

	        mov [check_grid + 0] , 1
	        mov [check_grid + 5] , 1
	        mov [check_grid + 10] , 1
			mov [check_grid + 11] , 1
			mov [check_grid + 12] , 1

	        jmp end_convert

		check_specific_17:
        	cmp al , 17 ; ID nm 17 , the big V "facing" top left
			jne check_specific_16


			mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1
			mov [check_grid + 2] , 1
			mov [check_grid + 5] , 1
			mov [check_grid + 10] , 1

        	jmp end_convert

		check_specific_16:
	        cmp al , 16 ; ID nm 16 , the big V "facing" top right
			jne check_specific_15

			mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1
			mov [check_grid + 2] , 1
			mov [check_grid + 7] , 1
			mov [check_grid + 12] , 1

			jmp end_convert

	; small V segment

        check_specific_15:
	        cmp al , 15 ; ID nm 15 , small V "facing" bottom left
	        jne check_specific_14

	        mov [check_grid + 0] , 1
			mov [check_grid + 5] , 1
			mov [check_grid + 6] , 1

	        jmp end_convert

        check_specific_14:
	        cmp al , 14 ; ID nm 14 , small V "facing" bottom right
	        jne check_specific_13

	        mov [check_grid + 1] , 1
			mov [check_grid + 5] , 1
			mov [check_grid + 6] , 1

	        jmp end_convert

        check_specific_13:
	        cmp al , 13 ; ID nm 13 , the small V "facing" top left
			jne check_specific_12

			mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1
			mov [check_grid + 5] , 1

			jmp end_convert

        check_specific_12:
	        cmp al , 12 ; ID nm 12 , small V "facing" top right
	        jne check_specific_11

	        mov [check_grid + 0] , 1
	        mov [check_grid + 1] , 1
	        mov [check_grid + 6] , 1

	        jmp end_convert

	; horizontal lines segment

        check_specific_11:
	        cmp al , 11 ; ID nm 11 , the 5 block horizontal line
	        jne check_specific_10

	        mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1
			mov [check_grid + 2] , 1
			mov [check_grid + 3] , 1
	        mov [check_grid + 4] , 1

	        jmp end_convert

		check_specific_10:
			cmp al , 10 ; ID nm 10 , the 4 block horizontal line
			jne check_specific_9

			mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1
			mov [check_grid + 2] , 1
			mov [check_grid + 3] , 1

			jmp end_convert

		check_specific_9:
			cmp al , 9 ; ID nm 9 , the 3 block horizontal line
			jne check_specific_8
			mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1
			mov [check_grid + 2] , 1

			jmp end_convert

		check_specific_8:
			cmp al , 8 ; ID nm 8 , the 2 block horizontal line
			jne check_specific_7

			mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1

			jmp end_convert

	; vertical lines segment

		check_specific_7:
			cmp al , 7 ; ID nm 7 , the 5 block vartical line
			jne check_specific_6

			mov [check_grid + 0] , 1
			mov [check_grid + 5] , 1
			mov [check_grid + 10] , 1
			mov [check_grid + 15] , 1
			mov [check_grid + 20] , 1

			jmp end_convert

		check_specific_6:
			cmp al , 6 ; ID nm 6 , the 4 block vartical line
			jne check_specific_5

			mov [check_grid + 0] , 1
			mov [check_grid + 5] , 1
			mov [check_grid + 10] , 1
			mov [check_grid + 15] , 1

			jmp end_convert

		check_specific_5:
			cmp al , 5 ; ID nm 5 , the 3 block vartical line
			jne check_specific_4

			mov [check_grid + 0] , 1
			mov [check_grid + 5] , 1
			mov [check_grid + 10] , 1

			jmp end_convert

		check_specific_4:
			cmp al , 4 ; ID nm 5 , the 2 block vartical line
			jne check_specific_3

			mov [check_grid + 0] , 1
			mov [check_grid + 5] , 1


			jmp end_convert
			
	; The square segment

		check_specific_3:
			cmp al , 3 ; ID nm 3 , the 3x3 block
			jne check_specific_2

			mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1
			mov [check_grid + 2] , 1

			mov [check_grid + 5] , 1
			mov [check_grid + 6] , 1
			mov [check_grid + 7] , 1

			mov [check_grid + 10] , 1
			mov [check_grid + 11] , 1
			mov [check_grid + 12] , 1

			jmp end_convert
	
		check_specific_2: 
			cmp al , 2 ; ID nm 2 , the 2x2 block
			jne check_specific_1

			mov [check_grid + 0] , 1
			mov [check_grid + 1] , 1
			mov [check_grid + 5] , 1
			mov [check_grid + 6] , 1
			
			jmp end_convert

		check_specific_1:

			cmp al , 1 ; ID nm 1 , the 1x1 block
			jne check_specific_0

			mov [check_grid + 0] , 1
			
			jmp end_convert

		check_specific_0: ; ID nm 0 , no shape
			
			jmp end_convert


	end_convert:

	pop dx
	pop cx
	pop bx
	pop ax

	pop bp
	ret 2
	endp ID_to_shape

proc Put_Shape_In_Grid
	; Recieves a position on the grid , enters the shape from check_grid into game_grid
	push bp
	mov bp, sp
	xPos equ [bp+6]
	yPos equ [bp+4]
	push cx
	push bx
	push ax
	push di
	mov cx , 25
		put_shape_in_grid_loop:

		mov bx, cx
		dec bx

		cmp [check_grid + bx] , 1
			jne put_shape_in_grid_loop_end

		mov ax , bx
		call Check_Memory_To_Grid

		add ax , xPos
		add bx , yPos
		push ax
		push bx
		call Grid_To_Memory
		mov di , ax ; di contains correct address


		mov [game_grid+di] , 1
		
		
			
			put_shape_in_grid_loop_end:
		loop put_shape_in_grid_loop

	pop di
	pop ax
	pop bx
	pop cx
	pop bp
	ret 4
	endp Put_Shape_In_Grid

; Random segment 

	proc Generate_Seed
		push ax
		push bx
		push cx
		push dx
		mov ah , 2Ch
		int 21h

		hours equ ch
		minutes equ cl
		seconds equ dh

		xor ax , ax
		mov [seed] , ax

		mov al , seconds
		xor ah , ah
		add [seed] , ax

		mov al , minutes
		mov bl , 60
		mul bl
		add [seed] , ax

		mov al , hours
		xor ah , ah
		mov bx , 3600
		mul bx
		mov dh , dl
		add [seed] , ax
		add [seed] , dx


		pop dx
		pop cx
		pop bx
		pop ax
		ret
		endp Generate_Seed

	proc Random_Shape
		; When called, generates a "random" number between 1 and 19, and returns it over ax
		
		push dx

		mov ax, 25173 ; LCG Multiplier
		mov dx , [seed]
	    mul dx ; DX:AX = LCG multiplier * seed
	    add ax, 13849 ; Add LCG increment value
	    ; Modulo 65536, AX = (multiplier*seed+increment) mod 65536
	    mov [seed], ax ; Update seed = return value

	 	xor ah , ah
	 	xor dx , dx
		mov bl , 19
		div bl
		mov al , ah
		xor ah , ah
		inc al

	    pop dx

	    ret
	    endp Random_Shape

; Number printing segment (debug)
	proc Print_Number_P
	; The private function of Print_Number (not to be accessed directly, messes up directioneries!)
		xor	dx , dx
		xor	bx , bx			
		div	cx	;Divide DX:AX by CX
		and	ax,ax ;Is quotient zero?
		jz	print ;Yes print remainder
		push dx
		call Print_Number ;and do again.
		pop dx ;Restore previous reminder
	
	print:
		mov	bx,dx ;Print remainder in AH
		mov	ah,2
		mov dl , bl
		add dl , '0' ;Convert Binary to ASCII
		int	21h	;Print
		ret


	endp Print_Number_P

	proc Print_Number
	; Recieves a number over ax, prints number to the screen (uses recursion!)
	push bx
	push cx
	push dx
	mov cx , 10
	call Print_Number_P
	pop dx
	pop cx
	pop bx
	ret
	endp Print_Number

; Check Fill chunk

	proc Check_Row
		; Recieves a Row number (0-9) via stack, returns 0 over check_fill if it isn't full, returns 1 if it is. 
		push bp
		mov bp, sp
		Row equ [bp+4]
		mov [check_fill] , 0
		
		push cx
		push bx
		push ax
		push di

		mov bx , Row

		xor ah , ah
		mov al , 10

		mul bl

		mov di , ax

		mov cx , 10
		check_row_loop:
			cmp [game_grid+di] , 0
			je end_check_row
			inc di
			loop check_row_loop

		mov [check_fill] , 1



		end_check_row:

		pop di
		pop ax
		pop bx
		pop cx

		pop bp
		ret 2
		endp Check_Row

	proc Check_Columm
		; Recieves a Columm number (0-9), returns 0 over check_fill if it isn't full, returns 1 if it is. 
		push bp
		mov bp, sp
		Columm equ [bp+4]
		mov [check_fill] , 0
		
		push cx
		push bx
		push ax
		push di

		mov di , Columm

		mov cx , 10
		check_columm_loop:
			mov ax , cx
			dec ax

			push di
			push ax
			call Grid_To_Memory
			mov bx , ax
			cmp [game_grid+bx] , 0
			je end_check_columm
			loop check_columm_loop

		mov [check_fill] , 1



		end_check_columm:

		pop di
		pop ax
		pop bx
		pop cx

		pop bp
		ret 2
		endp Check_Columm

	proc Check_Filled
		; The function checks the data from game_grid to see if any rows/columms are filled, clears any filled columms and rows.
		push ax
		push bx
		push cx
		push di

		; Copies data from game_grid to checked_game_grid
		cld

		mov cx , 100
		mov ax , ds
		mov es , ax

		mov si , offset game_grid
		mov di , offset checked_game_grid
		rep movsb


		mov cx , 10
		check_filled_rows_loop:
			mov ax , cx
			dec ax
			push ax
			call Check_Row
			cmp [check_fill] , 1
			jne end_check_filled_rows_loop
			
			push cx
			mov di , ax
			mov cx , 10
				row_filled_loop:
					mov ax , cx
					dec ax

					push ax
					push di
					call Grid_To_Memory

					mov bx , ax
					mov [checked_game_grid+bx] , 0

					loop row_filled_loop

			pop cx
			end_check_filled_rows_loop:
			loop check_filled_rows_loop

		mov cx , 10
		check_filled_columms_loop:
			mov ax , cx
			dec ax
			push ax
			call Check_Columm
			cmp [check_fill] , 1
			jne end_check_filled_columms_loop
			
			push cx
			mov di , ax
			mov cx , 10
				columm_filled_loop:
					mov ax , cx
					dec ax

					push di
					push ax
					call Grid_To_Memory

					mov bx , ax
					mov [checked_game_grid+bx] , 0

					loop columm_filled_loop
				
			pop cx
			end_check_filled_columms_loop:
			loop check_filled_columms_loop

		; Copies data from checked_game_grid to game_grid
		cld

		mov cx , 100
		mov ax , ds
		mov es , ax

		mov si , offset checked_game_grid
		mov di , offset game_grid
		rep movsb

		pop di
		pop cx
		pop bx
		pop cx

		ret 
		endp Check_Filled

; Mouse functions chunk
	
	proc Get_Mouse_Info
		; Returns the mouse state over some varieables 
		push ax
		push bx
		push cx
		push dx

		mov ax , 3h
		int 33h

		shr cx , 1

		mov [mouse_x] , cx
		mov [mouse_y] , dx
		
		cmp bx , 01b
		jne right_click_check
		mov [mouse_right_click] , 0
		mov [mouse_left_click] , 1
		jmp end_mouse_check

		right_click_check:
		cmp bx , 10b
		jne both_click_check
		mov [mouse_right_click] , 1
		mov [mouse_left_click] , 0
		jmp end_mouse_check

		both_click_check:
		cmp bx , 11b
		jne no_click
		mov [mouse_right_click] , 1
		mov [mouse_left_click] , 1
		jmp end_mouse_check

		no_click:
		mov [mouse_right_click] , 0
		mov [mouse_left_click] , 0

		end_mouse_check:
		pop dx
		pop cx
		pop bx
		pop ax
		ret
		endp Get_Mouse_Info

	proc PaintShape_On_Mouse
		; paints a shape on the mouse
		push bp
		mov bp, sp
		sub sp , 4
		xPos equ [bp-2]
		yPos equ [bp-4]
		push cx 

		call Get_Mouse_Info

		mov cx , [mouse_x]
		mov xPos , cx
		mov cx , [mouse_y]
		mov yPos , cx

		mov cx , 25

		paint_shape_mouse_loop:

			mov bx, cx
			dec bx

			cmp [check_grid + bx] , 1
				jne paint_shape_mouse_loop_end

			mov ax , bx

			call Check_Memory_To_Grid

			mov dx, bx

			mov bl , 11
			mul bl

			add ax , xPos ; The X value to paint the square on
			push ax

			mov ax , dx
			mov bl , 11
			mul bl

			add ax , yPos ; The Y value to paint the square on
			push ax

			call PaintSquare_Blue


			paint_shape_mouse_loop_end:
			loop paint_shape_mouse_loop

			pop cx
			add sp , 4
			pop bp
			ret 2
		endp PaintShape_On_Mouse

	proc PaintSquare_Blue
		; paints a blue square at given x , y coords, bp + 6 = x, bp + 4 = y
		push bp
		mov bp, sp
		xPos equ [bp+6]
		yPos equ [bp+4]

		push cx

		push offset square_image_blue
		call OpenFile
		call ReadHeader
		call ReadPalette
		call CopyPal

		push xPos
		push yPos
		push 10
		push 10
		call CopyBitmap
		call CloseFile

		pop cx
		pop bp
		ret 4
		endp PaintSquare_Blue

	proc Mouse_To_Grid
		; Translates the mouse position to a position on the grid
		call Get_Mouse_Info
		
		push di
		push cx

		mov di , 216
		
		mov cx , 9
		mouse_to_grid_x_loop:
			sub di , 11
			cmp [mouse_x] , di
			ja end_mouse_to_grid_x
			loop mouse_to_grid_x_loop

		end_mouse_to_grid_x:
		mov [mouse_grid_x] , cl

		mov di , 156
		
		mov cx , 9
		mouse_to_grid_y_loop:
			sub di , 11
			cmp [mouse_y] , di
			ja end_mouse_to_grid_y
			loop mouse_to_grid_y_loop

		end_mouse_to_grid_y:
		mov [mouse_grid_y] , cl

		pop cx
		pop di
		ret 
		endp Mouse_To_Grid

; Set segment
	proc Check_Set_Empty
	; Checks if the set is empty, if it is, returns 1 over ax, returns 0 if not
	mov ax , 0

	cmp [cur_shapes] , 0
	jne end_set_empty_check

	cmp [cur_shapes+1] , 0
	jne end_set_empty_check

	cmp [cur_shapes+2] , 0
	jne end_set_empty_check

	mov ax , 1

	end_set_empty_check:
	ret 
	endp Check_Set_Empty

	proc Restock_Shapes
	; When called, randomizes each shape in the set
	push ax
	
	call Random_Shape
	mov [cur_shapes] , al

	call Random_Shape
	mov [cur_shapes+1] , al

	call Random_Shape
	mov [cur_shapes+2] , al

	pop ax

	ret 
	endp Restock_Shapes

proc Check_Lose
	;Checks if the game is lost, returns result over ax, returns 0 if not, 1 if it is.
	
	push bx
	push cx
	push di

	shape_one_check:
	cmp [cur_shapes] , 0
	je shape_two_check

	xor bh, bh
	mov bl , [cur_shapes]

	xor ch , ch
	mov cl , 9

	shape_one_check_outer_loop:
		push cx
		mov di , cx
		xor ch, ch 
		mov cl , 9
		shape_one_check_inner_loop:
			push di
			push cx
			push bx
			call Check_requirement
			cmp ax , 0
			je free_slot_found

			loop shape_one_check_inner_loop

		pop cx
		loop shape_one_check_outer_loop

	shape_two_check:
	cmp [cur_shapes+1] , 0
	je shape_three_check


	xor bh, bh
	mov bl , [cur_shapes+1]

	xor ch , ch
	mov cl , 9

	shape_two_check_outer_loop:
		push cx
		mov di , cx
		xor ch, ch 
		mov cl , 9
		shape_two_check_inner_loop:
			push di
			push cx
			push bx
			call Check_requirement
			cmp ax , 0
			je free_slot_found

			loop shape_two_check_inner_loop

		pop cx
		loop shape_two_check_outer_loop

	shape_three_check:
	mov ax , 1
	cmp [cur_shapes+2] , 0
	je end_lose_check

	xor bh, bh
	mov bl , [cur_shapes+2]

	xor ch , ch
	mov cl , 9

	shape_three_check_outer_loop:
		push cx
		mov di , cx
		xor ch, ch 
		mov cl , 9
		shape_three_check_inner_loop:
			push di
			push cx
			push bx
			call Check_requirement
			cmp ax , 0
			je free_slot_found

			loop shape_three_check_inner_loop

		pop cx
		loop shape_three_check_outer_loop

	mov ax , 1
	jmp end_lose_check


	free_slot_found:
	pop cx
	
	
	end_lose_check:
	
	pop di
	pop cx
	pop bx
	ret
	endp Check_Lose

start :
mov ax, @data
mov ds, ax


; Graphic mode
mov ax, 13h
int 10h


; Process BMP file
; call OpenFile
; call ReadHeader
; call ReadPalette
; call CopyPal
; call CopyBitmap
; push 200
; push 50

; mov [game_grid] , 0

; mov [game_grid + 41] , 0 

call Generate_Seed

mov ax , 0h
int 33h
; Reset mouse

; mov ax , 1h 
; int 33h
; ; Show mouse on screen

call Restock_Shapes


; A segment that handles all of the screens and calls relevent functions
	loop_draw:

		; Screen checks 
			menu_check:
				cmp [screen_status] , 0
				jne cred_check ; Jump to next check

				mov ax , 0h
				int 33h
				; Reset mouse

				jmp draw_menu

			cred_check:
				cmp [screen_status] , 1
				jne game_check ; Jump to next check
				jmp draw_cred

			game_check:
				cmp [screen_status] , 2
				jne lose_check ; Jump to next check

				mov ax , 0h
				int 33h
				; Reset mouse

				jmp draw_game

			lose_check:
				cmp [screen_status] , 3
				jne draw_menu

				mov ax , 0h
				int 33h
				; Reset mouse

				jmp draw_lose

		draw_menu:

			mov [screen_status] , 0 ; Failsafe for if the screen status gets out of range

			; Menu drawing segment
			push offset menu_image
			call OpenFile

			call ReadHeader
			call ReadPalette
			call CopyPal
			push 0
			push 0
			push 320
			push 200
			call CopyBitmap
			call CloseFile

			; ptr drawing segment
			push offset ptr_image
			call OpenFile

			call ReadHeader
			call ReadPalette
			call CopyPal

			cmp [menu_ptr] , 1 ; button one pos
			jne button_two_pos
				push 56
				push 102
				jmp menu_ptr_draw

			button_two_pos:
				cmp [menu_ptr] , 2 ; button two pos
				push 70
				push 146
				jmp menu_ptr_draw

			menu_ptr_draw:
			push 28
			push 17
			call CopyBitmap

			call CloseFile



			WaitForData_menu: ; Menu logic and handling segment
				mov ah, 1
				Int 16h
				jz WaitForData_menu
				mov ah, 0
				int 16h
				cmp ah , 10h ; Is it the Q key?
				jne up_arrow_handler ;Quit if it is
				mov [screen_status] , 3
				jmp loop_draw

				up_arrow_handler:
					cmp ah , 48h ; Is it the up arrow?
					jne down_arrow_handler ;Move to next segment if not.
					dec [menu_ptr] ; Decrease the pointer
					cmp [menu_ptr] , 0
					jne jump_to_draw
					mov [menu_ptr], 2 ; If the pointer is out of range, move it to the max value
					jmp jump_to_draw

				down_arrow_handler:
					cmp ah, 50h ; Is it the down arrow?
					jne enter_key_handler ;Move to next segment if not.
					inc [menu_ptr] ; Increase the pointer
					cmp [menu_ptr] , 3
					jne jump_to_draw 
					mov [menu_ptr], 1 ; If the pointer is out of range, move it to the min value
					jmp jump_to_draw

				jump_to_draw:
					jmp draw_menu

				enter_key_handler:
					cmp ah, 1Ch ; Is it the Enter key?
					jne WaitForData_menu
					cmp [menu_ptr] , 1
					jne button_two_pressed
					mov [screen_status] , 2 ; Change screen status to game screen
					jmp loop_draw
					button_two_pressed:
					mov [screen_status] , 1
					jmp loop_draw

		draw_cred:
			push offset cred_image
			call OpenFile

			call ReadHeader
			call ReadPalette
			call CopyPal

			push 0
			push 0
			push 320
			push 200
			call CopyBitmap
			call CloseFile

			WaitForData_cred:
				mov ah, 1
				Int 16h
				jz WaitForData_cred
				mov ah, 0
				int 16h
				cmp ah, 1Ch ; Check if it's the Enter key
				jne WaitForData_cred
				mov [screen_status] , 0
				jmp loop_draw 

		draw_game:
			push offset game_image
			call OpenFile

			call ReadHeader
			call ReadPalette
			call CopyPal
			push 0
			push 0
			push 320
			push 200
			call CopyBitmap
			call CloseFile

			call Check_Set_Empty
			cmp ax , 1
			jne set_not_empty
			cmp [shape_hold_status] , 0
			jne set_not_empty
			
			call Restock_Shapes

			set_not_empty:
			call Draw_Current_Shapes

			call Check_Filled

			call Draw_Shapes

			mov ax , 1h 
			int 33h
			; Show mouse on screen

			cmp [shape_hold_status] , 0
			jne WaitForData_game

			call Check_Lose
			cmp ax , 1
			jne WaitForData_game

			mov [screen_status] , 3
			jmp loop_draw

			; mov dx , offset clear_clicked_shape
			; mov	ah, 9h
			; int	21h	; Clear the coords

			; call Mouse_To_Grid

			; xor ah , ah
			; mov al , [mouse_grid_x]
			; call Print_Number

			; mov	ah,2
			; mov dl , ','
			; int	21h	;Print

			; xor ah , ah
			; mov al, [mouse_grid_y]
			; call Print_Number


			

			
			WaitForData_game:

				call Mouse_To_Grid

				cmp [byte ptr shape_hold_status] , 1
				jne mouse_checks
				xor ah , ah
				mov al , [shape_hold_status + 1]
				push ax
				call ID_to_shape
				call PaintShape_On_Mouse

				mouse_checks:
					; Right click checks , if user presses right click with a shape, returns the shape
					cmp [mouse_right_click] , 1
					jne mouse_left_click_checks

					cmp [byte ptr shape_hold_status] , 1	; Is the user holding a shape?
					jne mouse_left_click_checks	; If not , move to the left click checks
					
					xor bh , bh
					mov bl , [held_shape_source]
					dec bx

					xor ah , ah
					mov al , [shape_hold_status+1]

					mov [cur_shapes+bx] , al

					mov [held_shape_source] , 0
					mov [shape_hold_status] , 0
					mov [shape_hold_status+1] , 0



					mouse_left_click_checks:
						; Left click checks, If the user presses left click when at the "set" area of the game, it will pick up a shape
						; Unless the user is already holding a shape

						; If the user presses left click at the game grid, if they are holding a shape, check if they can insert the shape into the grid
						; And if so, insert the shape.

						cmp [mouse_left_click] , 1
						je check_where_click
						jmp check_kb_game

						check_where_click:
						cmp [mouse_x] , 252
						ja check_set_segment
						jmp check_grid_segment

						check_set_segment:

							cmp [byte ptr shape_hold_status] , 0
							je check_set_number
							jmp check_kb_game

							check_set_number:

							cmp [mouse_y] , 73
							ja check_shape_2


							mov al , [cur_shapes]
							cmp al , 0
							je jump_to_kb_check_checkpoint
							mov [shape_hold_status] , 1
							mov [shape_hold_status+1] , al

							mov [cur_shapes] , 0
							mov [held_shape_source] , 1
							jmp check_kb_game

							check_shape_2:
							cmp [mouse_y] , 130
							ja check_shape_3

							mov al , [cur_shapes+1]
							cmp al , 0
							je jump_to_kb_check_checkpoint
							mov [shape_hold_status] , 1
							mov [shape_hold_status+1] , al

							mov [cur_shapes+1] , 0
							mov [held_shape_source] , 2
							jmp check_kb_game

							check_shape_3:

							mov al , [cur_shapes+2]
							cmp al , 0
							je jump_to_kb_check_checkpoint
							mov [shape_hold_status] , 1
							mov [shape_hold_status+1] , al

							mov [cur_shapes+2] , 0
							mov [held_shape_source] , 3
							jmp check_kb_game

							jump_to_kb_check_checkpoint:
								jmp check_kb_game

						check_grid_segment:

							
							cmp [byte ptr shape_hold_status] , 0
							je check_kb_game

							mov dx , offset clear_clicked_shape
							mov	ah, 9h
							int	21h	; Clear the coords

							xor ah , ah
							mov al , [shape_hold_status+1]

							xor bh , bh
							mov bl , [mouse_grid_x]
							push bx

							mov bl , [mouse_grid_y]
							push bx

							push ax
							call Check_requirement

							cmp ax , 0
							jne check_kb_game

							xor bh , bh
							mov bl , [mouse_grid_x]
							push bx

							mov bl , [mouse_grid_y]
							push bx

							call Put_Shape_In_Grid

							mov [shape_hold_status] , 0
							mov [shape_hold_status+1] , 0

							

				check_kb_game:
				mov ah, 1
				Int 16h
				jz WaitForData_game_checkpoint
				mov ah, 0
				int 16h
				cmp ah , 10h ; Is it the Q key?
				jne esc_handler ;Quit if it is
				mov [screen_status] , 3
				jmp loop_draw

				esc_handler:
				cmp ah, 1h ; Is it the ESC key?
				jne WaitForData_game_checkpoint
				mov [screen_status] , 0 ; Change screen status back to menu
				jmp loop_draw

				WaitForData_game_checkpoint:
				jmp draw_game

		draw_lose:

			push offset lose_image
			call OpenFile

			call ReadHeader
			call ReadPalette
			call CopyPal

			push 0
			push 0
			push 320
			push 200
			call CopyBitmap
			call CloseFile

			mov ah, 0
			int 16h ; Wait for any button press


	end_draw:

; Back to text mode
mov ah, 0
mov al, 2
int 10h
exit :
mov ax, 4c00h
int 21h
END start
