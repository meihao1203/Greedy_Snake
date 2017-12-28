assume cs:code , ds:data , ss:stack

data segment
	SCREEN_COLOR dw 0700h
	BOUNDARY_COLOR dw 1131h		; 31h=49=数字1 , 11h=00010001b=蓝色

	NEXT_ROW dw 160

	SNAKE_HEAD dw 0
	SNAKE_STERN dw 12
	SNAKE dw 200 dup (0 , 0 , 0)

	SNAKE_COLOR dw 2201h

	UP db 48h
	DOWN db 50h
	LEFT db 4Bh
	RIGHT db 4Dh

	
	FOOD_LOCATION dw 160*3 + 20*2	
	FOOD_COLOR dw 4439h	
	NEW_NODE dw 18		

	GAME_OVER db 'Game Over!' 


	DIRECTION dw 3
	DIRECTION_FUNCTION dw offset isMoveUp    - offset greedy_snake + 7e00h
			   dw offset isMoveDown  - offset greedy_snake + 7e00h
			   dw offset isMoveLeft  - offset greedy_snake + 7e00h
			   dw offset isMoveRight - offset greedy_snake + 7e00h

	REPLAY_DIRECTION_STACK db 200 dup (0ffh) ; 记录游戏每走一步的方向
	REPLAY_DIRECTION_TOP dw 0	; 指向下一个可用位置，存放下一步方向

data ends

stack segment
	db 128 dup (0)
stack ends

code segment
start:	
	mov ax , stack
	mov ss , ax
	mov sp , 128

	call cpy_greedy_snake
	call save_old_int9
	call set_new_int9
	
	mov bx , 0
	push bx
	mov bx , 7e00h
	push bx
	retf


	mov ax , 4c00h
	int 21h


;------------------------------------------------------
greedy_snake:

	call init_reg
	call clear_screen
	call init_screen
	call init_snake
	call init_food
	call init_direction


;doAgain:
;	call delay
;	cli
;	call isMoveDirection
;	sti
;	jmp doAgain

infinite:
	mov ax , 1000h
	jmp infinite

	mov ax , 4c00h
	int 21h


;------------------------------------------------------
init_food:
	mov di , FOOD_LOCATION
	push FOOD_COLOR
	pop es:[di]
	ret 


;------------------------------------------------------
replayGame:
	call init_reg		; 重新回放录像就要重新初始化到刚开始运行的状态
	call clear_screen
	call init_screen

	mov SNAKE_HEAD , 0	; 蛇头和蛇尾变成了运行后的状态，这两个数据就只能在这里手动来修改回最初状态
	mov SNAKE_STERN , 12
	mov REPLAY_DIRECTION_TOP , 0	; 重新把top设置成开始状态0,开始执行

	call init_snake
	call init_direction

nextDelay:
	call delay
	cli
	call moveDirection
	sti
	jmp nextDelay

replayGameOver:
	call clear_screen
	call end_game
	call recover_int9Ret
	call return_dos


;------------------------------------------------------
moveDirection:
	mov bx , REPLAY_DIRECTION_TOP
	mov bl , ds:REPLAY_DIRECTION_STACK[bx]

	cmp bl , 0ffh
	je replayGameOver
	mov bh , 0
	add bx , bx
	call word ptr ds:DIRECTION_FUNCTION[bx]

	inc REPLAY_DIRECTION_TOP

	ret


;------------------------------------------------------
isMoveDirection:
	mov bx , DIRECTION
	add bx , bx
	call word ptr ds:DIRECTION_FUNCTION[bx]
	ret


;------------------------------------------------------
delay:
	push ax
	push dx

	mov dx , 3h
	sub ax , ax
delaying:
	sub ax , 1
	sbb dx , 0
	cmp ax , 0
	jne delaying
	cmp dx , 0
	jne delaying
	pop dx
	pop ax
	ret


;------------------------------------------------------
init_direction:
	mov DIRECTION , 3
	ret

;------------------------------------------------------
init_snake:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD
	mov dx , SNAKE_COLOR
	mov si , 160*10+40*2

	mov word ptr ds:[bx+0] , 0	; SNAKE_HEAD =0 , SNAKE_STERN =12
	mov word ptr ds:[bx+2] , si
	mov word ptr es:[si] , dx
	mov word ptr ds:[bx+4] , 6

	sub si , 2
	add bx , 6

	mov word ptr ds:[bx+0] , 0
	mov word ptr ds:[bx+2] , si
	mov word ptr es:[si] , dx
	mov word ptr ds:[bx+4] , 12

	sub si , 2
	add bx , 6

	mov word ptr ds:[bx+0] , 6
	mov word ptr ds:[bx+2] , si
	mov word ptr es:[si] , dx
	mov word ptr ds:[bx+4] , 18

	ret


;------------------------------------------------------
init_screen:
	mov dx , BOUNDARY_COLOR
	call show_up_down_line
	call show_left_right_line
	ret


;------------------------------------------------------
show_left_right_line:
	mov bx , 0
	mov cx , 23
showLeftRightLine:
	mov es:[bx] , dx
	mov es:[bx+79*2] , dx
	add bx , NEXT_ROW
	loop showLeftRightLine
	ret


;------------------------------------------------------
show_up_down_line:
	mov bx , 0
	mov cx , 80
showUpDownLine:
	mov es:[bx] , dx
	mov es:[bx+160*23] , dx
	add bx , 2
	loop showUpDownLine
	ret
	
;------------------------------------------------------
clear_screen:
	mov bx , 0
	mov dx , SCREEN_COLOR
	mov cx , 2000

clearScreen:
	mov word ptr es:[bx] , dx
	add bx , 2
	loop clearScreen
	ret


;------------------------------------------------------
init_reg:
	mov bx , 0b800h
	mov es , bx
	mov bx , data
	mov ds , bx

	ret


;------------------------------------------------------
new_int9:
	push ax
	call clear_buff

	in al , 60h

	pushf 
	call dword ptr cs:[200h]	; 等到代码运行的时候,这里的代码已经放到了0:200,当前的cs=0

	cmp al , UP
	je isUp
	cmp al , DOWN
	je isDown
	cmp al , LEFT
	je isLeft
	cmp al , RIGHT
	je isRight

	cmp al , 01h	; ESC 的扫描码
	je isEsc

	cmp al , 3bh
	jne int9Ret

	call change_screen_color

	
int9Ret:
	pop ax
	iret
	

;------------------------------------------------------
isEsc:
	pop ax
	add sp , 4
	popf		
; 这几句代码是模仿int9Ret执行的操作，因为iret的出栈顺序是 pop ip,pop cs,popf
; 这里还不能返回中断处接着执行，还要做下面其他的操作，所以只能sp+4偏移到栈中存放
; 标志寄存器的位置,恢复psw,丢掉中断处的下一句要执行的代码，接着做我们期待执行的事
	jmp replayGame
	;jmp int9Ret


;------------------------------------------------------
isUp:
	mov di , 160*24+40*2
	mov byte ptr es:[di] , 'U'
	call isMoveUp
	mov dl , 0	; 向上走的函数地址在DIRECTION_FUNCTION中的偏移是0
	call replay_direction_save
	jmp int9Ret


isDown:
	mov di , 160*24+40*2
	mov byte ptr es:[di] , 'D'
	call isMoveDown
	mov dl , 1
	call replay_direction_save
	jmp int9Ret


isLeft:
	mov di , 160*24+40*2
	mov byte ptr es:[di] , 'L'
	call isMoveLeft
	mov dl , 2
	call replay_direction_save

	jmp int9Ret


isRight:
	mov di , 160 * 24 + 40 * 2
	mov byte ptr es:[di] , 'R'
	call isMoveRight
	mov dl , 2
	call replay_direction_save

	jmp int9Ret


;------------------------------------------------------
replay_direction_save:
	mov bx , REPLAY_DIRECTION_TOP
	mov ds:REPLAY_DIRECTION_STACK[bx] , dl ; 把走过的方向放到方向栈中存放
	inc REPLAY_DIRECTION_TOP

	ret


;------------------------------------------------------
isMoveUp:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD

	mov si , ds:[bx+2]
	sub si , NEXT_ROW
	
	cmp byte ptr es:[si] , 0
	jne noMoveUp
	mov DIRECTION , 0

	call new_snake
	ret
noMoveUp:
	call isFood
	ret


isMoveDown:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD

	mov si , ds:[bx+2]
	add si , NEXT_ROW
	
	cmp byte ptr es:[si] , 0
	jne noMoveDown
	mov DIRECTION , 1

	call new_snake
	ret
noMoveDown:
	call isFood
	ret


isMoveLeft:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD

	mov si , ds:[bx+2]
	sub si , 2
	
	cmp byte ptr es:[si] , 0
	jne noMoveLeft
	mov DIRECTION , 2

	call new_snake
	ret
noMoveLeft:
	call isFood
	ret


isMoveRight:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD

	mov si , ds:[bx+2]
	add si , 2
	                             
	cmp byte ptr es:[si] , 0
	jne noMoveRight
	mov DIRECTION , 3

	call new_snake
	ret
noMoveRight:
	call isFood
	ret


;------------------------------------------------------
isFood:
	cmp byte ptr es:[si] , '9'	; 我们前面设置了食物的字符是9,前景背景都是红色
	jne noFood

	call eat_food
	call set_new_food	; 吃掉一个要在生成一个
	ret
		
noFood:
	call clear_screen
	call end_game
	;call recover_int9Ret
	;call return_dos
	ret


;------------------------------------------------------
set_new_food:
	mov al , 0
	out 70h , al
	in al , 71h

	mov dl , al
	and dl , 00001111b	; dl中是个位数的数字
	push cx
	mov cl , 4
	mov ch , 0
	shr al , cl		; al中是十位数的数字
	pop cx		
	mov bl , 10
	mul bl		; ax=al*bl
	add al , dl	; 得到秒数

	mul al		; 如果al是奇数，得到的肯定也是一个奇数,24*80=1920种显示位置，60*60=3600种位置
	shr al , 1	; 二进制，右移一位去掉产生奇数的1
	shl al , 1	; 控制误差，再左移一位，这样误差就为1

	mov bx , ax	; 得到下一个食物出现的位置
	cmp byte ptr es:[bx] , 0	; 如果得到的位置不是空闲的
	jne set_new_food	; 这里有一个问题，如果生成的食物位置不行，到这里要跳转，又要进行下次执行，但是又要发生键盘中断
	
	push FOOD_COLOR
	pop es:[bx]

	ret


;------------------------------------------------------
eat_food:
	push NEW_NODE			; 记录新节点的位置
	pop ds:[bx+0]

	mov bx , offset SNAKE
	add bx , NEW_NODE

	mov word ptr ds:[bx+0] , 0	;食物节点变成头结点，蛇变长一截
	mov ds:[bx+2] , si
	push SNAKE_COLOR
	pop es:[si]

	push SNAKE_HEAD
	pop ds:[bx+4]

	push NEW_NODE
	pop SNAKE_HEAD		

	add NEW_NODE , 6
	ret


;------------------------------------------------------
return_dos:
	mov ax , 4c00h
	int 21h


;------------------------------------------------------
recover_int9Ret:
	push bx
	mov bx , 0
	mov es , bx
	push es:[200h]
	pop es:[9*4]
	push es:[202h]
	pop es:[9*4+2]
	pop bx
	ret
;------------------------------------------------------
end_game:
	call clear_screen
	mov si , offset GAME_OVER
	mov di , 160*12+35*2
	mov cx , 10
s:
	mov al , [si]
	mov byte ptr es:[di] , al
	mov byte ptr es:[di+1] , 00000100b
	inc si
	add di , 2
	loop s
	ret


;------------------------------------------------------
new_snake:
	push SNAKE_STERN
	pop ds:[bx+0]

	mov bx , offset SNAKE
	add bx , SNAKE_STERN

	push ds:[bx+0]

	mov word ptr ds:[bx+0] , 0

	mov di , ds:[bx+2] 
	push SCREEN_COLOR
	pop es:[di]

	mov ds:[bx+2] , si
	push SNAKE_COLOR
	pop es:[si]

	push SNAKE_HEAD
	pop ds:[bx+4]

	push SNAKE_STERN	;曾经的尾巴变成头
	pop SNAKE_HEAD

	pop SNAKE_STERN

	ret


;------------------------------------------------------
clear_buff:
	mov ah , 1
	int 16h
	jz clearBuffRet ; ZF=1,键盘无输入
	mov ah , 0
	int 16h
	jmp clear_buff
clearBuffRet:
	ret


;------------------------------------------------------
change_screen_color:
	push bx 
	push cx
	push es

	mov bx , 0b800h
	mov es , bx
	mov bx , 1
	mov cx , 2000
changeScreenColor:
	inc byte ptr es:[bx]
	add bx , 2
	loop changeScreenColor

	pop es
	pop cx
	pop bx

	ret

snake_end:
	nop


;------------------------------------------------------
cpy_greedy_snake:
	mov bx , cs
	mov ds , bx
	mov si , offset greedy_snake
	
	mov bx , 0
	mov es , bx
	mov di , 7e00h

	mov cx , offset snake_end - offset greedy_snake
	rep movsb

	ret


;------------------------------------------------------
save_old_int9:
	mov bx , 0
	mov es , bx

	push es:[9*4]
	pop es:[200h]
	push es:[9*4+2]
	pop es:[202h]

	ret


;------------------------------------------------------
set_new_int9:
	mov bx , 0
	mov es , bx
	cli
	mov word ptr es:[9*4] , offset new_int9 - offset greedy_snake + 7e00h
	mov word ptr es:[9*4+2] , 0
	sti
	ret



code ends

end start