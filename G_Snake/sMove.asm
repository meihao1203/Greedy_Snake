assume cs:code , ds:data , ss:stack
data segment
	;db 256 dup(0)  ; 代码一点一点写，每个调用都测试一下，现在要写真正程序用到的，就注释掉这里
	BOUNDARY_COLOR dw 4431h   ; 直接定址法，颜色=0100100b,字符31h=数字1
	NEXT_ROL dw 0A0h   ; a0=160
	SNAKE_HEAD dw 0
	SNAKE_BODY dw 6
	SNAKE_STERN dw 12
	SNAKE dw 200 dup (0,0,0)  ; 三个数是来记录前一个节点，中间点的位置，记录下一个点在内存中的相对偏移
	;00 00 00 00 00 00 
	SNAKE_COLOR dw 2201h   ; 颜色00100010b,字符01h='☺'

	UP db 48h
	DOWN db 50h
	LEFT db 4Bh
	RIGHT db 4Dh
	
	SCREEN_COLOR dw 0700h

	NEXT_ROW dw 160


data ends
stack segment
	db 128 dup(0)
stack ends
code segment
start:	
	mov ax , stack
	mov ss , ax
	mov sp , 128

	call cpy_greedy_snake
	call sav_old_int9
	call set_new_int9
	
	
	mov bx , 0
	push bx
	mov bx , 7e00h
	push bx
	retf	   ; pop ip , pop cs  ; CS:IP=0:7e00

	mov ax , 4c00h
	int 21h

greedy_snake:
	call init_reg
	call clear_screen
	call init_screen
	call init_snake	           ; 画出蛇的图形



testA:	; 无限循环,测试
	mov ax , 1000h
	jmp testA

	mov ax , 4c00h
	int 21h




; 双向链表数据结构
;-----------------------------------------
init_snake:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD
	mov si , 160*10+40*2   ; 屏幕上的位置(0690h)
	mov dx , SNAKE_COLOR   ; 2201h

	mov word ptr ds:[bx+0] , 0   ; ds:[bx+0] = 0
	mov ds:[bx+2] , si  
	mov es:[si] , dx             ; 设置蛇的颜色
	mov word ptr ds:[bx+4] , 6

	sub si , 2
	add bx , 6

	mov word ptr ds:[bx+0] , 0   ; ds:[bx+0] = 0
	mov ds:[bx+2] , si
	mov es:[si] , dx             ; 设置蛇的颜色
	mov word ptr ds:[bx+4] , 12

	sub si , 2
	add bx , 6

	mov word ptr ds:[bx+0] , 6   ; ds:[bx+0] = 0
	mov ds:[bx+2] , si
	mov es:[si] , dx             ; 设置蛇的颜色
	mov word ptr ds:[bx+4] , 18


	ret


;-----------------------------------------
init_screen:
	mov dx , BOUNDARY_COLOR    ; 设置游戏界面边框的颜色
	call show_up_down_line     ; 画出游戏上下边界的边框
	call show_left_right_line  ; 画出游戏左右边界的边框
	
	ret


;-----------------------------------------
show_up_down_line:
	mov bx , 0
	mov cx , 80
showUpDownLine:
	mov es:[bx] , dx   ; dx=4431h,字符31h=数字1，颜色=01000100b
	mov es:[bx+160*23] , dx
	add bx , 2
	loop showUpDownLine
	ret


;-----------------------------------------
show_left_right_line:
	mov bx , 0
	mov cx , 23
showLeftRightLine:
	mov es:[bx] , dx
	mov es:[bx+79*2] , dx
	;add bx , 160
	add bx , NEXT_ROL  ; 优化写法
	loop showLeftRightLine
	ret


;-----------------------------------------
init_reg:
	mov bx , 0b800h
	mov es , bx

	mov bx , data
	mov ds , bx
	ret


;-----------------------------------------
clear_screen:
	mov bx , 0
	mov dx , SCREEN_COLOR
	mov cx , 2000

clearScreen:
	mov es:[bx] , dx  ; (dx)=0700,es:[0]~es:[1]=00,es:[2]~es:[3]=07,颜色属性是07，RGB=白色
	add bx , 2
	loop clearScreen
	ret


;-------------------------------------------
new_int9:
	push ax
	
	call clear_buff  ; 清空键盘缓冲区

	in al , 60h   ; 60h号端口读取的是键盘扫描码
	pushf
	call dword ptr cs:[200h]

	cmp al , UP  ; 记录方向键扫描码
	je isUp
	cmp al , LEFT
	je isLeft
	cmp al , RIGHT
	je isRight
	cmp al , DOWN
	je isDown

	cmp al , 3bh  ; 字符 ‘F1’ 的扫描码
	jne int9Ret
	call change_screen_color ;写来测试看，我写的9号中断处理键盘缓冲区能不能正常工作


int9Ret:
	pop ax
	iret


;-------------------------------------------
isUp:
	mov di , 160*24 + 0*2  ;  每行最下面显示出按下的按键
	mov byte ptr es:[di] , 'U'
	call isMoveUp
	jmp int9Ret

isDown:
	mov di , 160*24 + 0*2  ;  每行最下面显示出按下的按键
	mov byte ptr es:[di] , 'D'
	call isMoveDown
	jmp int9Ret

isLeft:
	mov di , 160*24 + 0*2  ;  每行最下面显示出按下的按键
	mov byte ptr es:[di] , 'L'
	call isMoveLeft
	jmp int9Ret

isRight:
	mov di , 160*24 + 0*2       ; 每行最下面显示出按下的按键
	mov byte ptr es:[di] , 'R'  
	call isMoveRight
	jmp int9Ret


;-------------------------------------------
isMoveUp:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD
	mov si , ds:[bx+2]      ; bx+2 获得节点中间的值，这个值记录的是该节点的位置
	sub si , NEXT_ROW	; 向上走了一步，所以中间节点的位置也要偏移160，刚好是一行

	cmp byte ptr es:[si] , 0	; 向上走一步如果es:[si]=1,表示到显示区的边界了，不能移动
	jne noMoveUp			
	call draw_new_snake		; 移动，重新绘制蛇


noMoveUp:
	ret


;-------------------------------------------
isMoveDown:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD
	mov si , ds:[bx+2]
	add si , NEXT_ROW

	cmp byte ptr es:[si] , 0
	jne noMoveDown
	call draw_new_snake

noMoveDown:
	ret


;-------------------------------------------
isMoveLeft:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD
	mov si , ds:[bx+2]
	sub si , 2

	cmp byte ptr es:[si] , 0
	jne noMoveDown
	call draw_new_snake
noMoveLeft:
	ret


;-------------------------------------------
isMoveRight:
	mov bx , offset SNAKE
	add bx , SNAKE_HEAD
	mov si , ds:[bx+2]
	add si , 2

	cmp byte ptr es:[si] , 0
	jne noMoveDown
	call draw_new_snake
noMoveRight:
	ret


;-------------------------------------------
draw_new_snake:
	push SNAKE_STERN  ; 蛇尾巴进栈保存，SNAKE_STERN=12
	pop ds:[bx+0]     ; bx接上面是指向蛇头的,向上走一步，蛇头节点的第一个存储区就要修改，指向前一个节点
; 我们的做法就是我蛇尾的那个节点放到蛇头前面，这要中间的就可以不用修改，只修改第一个和最后一个

	mov bx , offset snake
	add bx , SNAKE_STERN	; 找到记录最后一个节点的内存(蛇尾)

	push ds:[bx+0]			; 先保存最后一个节点中的pre,06

	mov word ptr ds:[bx+0] , 0	; 升级成蛇头了，节点中的pre变成0
	mov di , ds:[bx+2]		; 中间节点保存的是位置信息，现在要改变颜色
	push SCREEN_COLOR
	pop es:[di]

	mov ds:[bx+2] , si		; 修改完颜色，现在最后蛇尾节点变蛇头，要重新修改位置
; si 上面是拿到了最开始蛇头的si-160

	push SNAKE_COLOR
	pop es:[si]			; 在对应位置画出来

	push SNAKE_HEAD			; SNAKE_HEAD=0
	pop ds:[bx+4]			; 最后修改节点中最后一个信息，就是下一个节点的位置(这时候应该指向原来的头结点)

	push SNAKE_STERN		; 曾经的头部现在已经变成尾巴了，SNAKE_STERN=12
	pop SNAKE_HEAD			; SNAKE_HEAD=12
; 因为这些点是记录在内存的，所以要保存他们的位置，才能够正确访问到
; 现在SNAKE_HEAD变成12，下次访问+SNAKE_HEAD就找到真正的头结点在内存中的位置，
; 初始SNAKE_HEAD=0，应该最开始我们在SNAKE中第一个节点存放头，所以只要偏移0就找到真正的头结点了


	pop SNAKE_STERN			; 先保存最后一个节点中的pre，现在修改了蛇尾放到头部前面，pre就是新的尾部
	ret


;                               00   02   04       06   08   10       12   14   16  
;最开始小蛇相关信息在内存中存放(00   si'  06   |   00   si   12   |   06   si   18) ; 这里每个数字都是dw，我写成对应10进制表示的数了
;                               ↑    ↑    ↑        ↑    ↑    ↑        ↑    ↑    ↑
;				pre  pos  next     pre  pos  next     pre  pos  next
;所以SNAKE_HEAD=0,SNAKE_STERN=12 , 所以要找到对应

;第一个头节点前面什么东西也没有，所有pre=0

;head body  STERN	;最开始小蛇
;▅    ▅     ▅

;向上一步，原来的尾巴变成头，在修改对应信息就好了，比如原来最后尾巴节点颜色改成背景色
;                               00   02   04       06   08   10       12   14    16  
;向上一步后相关信息在内存中存放(12   si'  06   |   00   si   12   |   00   si'-1 00)
;                               ↑    ↑    ↑        ↑    ↑    ↑        ↑    ↑     ↑
;				pre  pos  next     pre  pos  next     pre  pos   next(偏移00就可以找到第二个节点在内存中的位置，取出相关信息)
;所以SNAKE_HEAD=12,SNAKE_STERN=06 , 原来的头结点变成第二个节点，尾巴节点变成头，第二个节点变成尾巴

;STERN head body  STERN		;向上一步走
;▅     ▅    ▅    ▅✘(修改颜色为背景色)  


;-------------------------------------------
clear_buff:
	mov ah , 1
	int 16h
	jz clearBuffRet  ; ZF=1,键盘无输入
	mov ah , 0
	int 16h
	jmp clear_buff

clearBuffRet:
	ret


;-------------------------------------------
change_screen_color:
	push bx
	push cx
	push es

	mov bx , 0b800h
	mov es , bx
	mov bx , 1

	mov cx , 2000

changeScreen:
	inc byte ptr es:[bx]
	add bx , 2
	loop changeScreen

	pop es
	pop cx
	pop bx
	ret



greedy_snake_end:	nop







;-------------------------------------------
set_new_int9:
	mov bx , 0
	mov es , bx

	cli
	mov word ptr es:[9*4] , offset new_int9 - offset greedy_snake + 7e00h
	mov word ptr es:[9*4+2] , 0
	sti

	ret


;-------------------------------------------
sav_old_int9:        ; 保存原来的9h号处理键盘中断
	mov bx , 0
	mov es , bx
	
	cli    ; IF=0，不允许其它外中断
	push es:[9*4]
	pop es:[200h]
	push es:[9*4+2]
	pop es:[202h]
	sti
	ret


;-------------------------------------------
cpy_greedy_snake:
	mov bx , cs
	mov ds , bx
	mov si , offset greedy_snake

	mov bx , 0
	mov es , bx 
	mov di , 7e00h  ; ?

	mov cx , offset greedy_snake_end - offset greedy_snake
	cld
	rep movsb

	ret

code ends
end start