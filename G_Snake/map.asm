assume cs:code , ds:data , ss:stack
data segment
	;db 256 dup(0)  ; 代码一点一点写，每个调用都测试一下，现在要写真正程序用到的，就注释掉这里
	BOUNDARY_COLOR dw 4431h   ; 直接定址法，颜色=0100100b,字符31h=数字1
	NEXT_ROL dw 0A0h   ; a0=160
	SNAKE_HEAD dw 0
	SNAKE_BODY dw 6	     ; 这个后面没用到，可以注释掉
	SNAKE_STERN dw 12    ; 尾巴在下面SNAKE分配的内存中的偏移
	SNAKE dw 200 dup (0,0,0)  ; 三个数是来记录前一个节点，中间点的位置，记录下一个点在内存中的相对偏移
	;00 00 00 00 00 00 
	SNAKE_COLOR dw 2201h   ; 颜色00100010b,字符01h='☺'
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
	mov bx , 0208h
	push bx
	retf	; pop ip , pop cs  ; CS:IP=0:03e8h

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

	mov word ptr ds:[bx+0] , 0   ; ds:[bx+0] = 0,蛇头节点是第一个节点，pre只能为0
	mov ds:[bx+2] , si  
	mov es:[si] , dx             ; 设置蛇的颜色
	mov word ptr ds:[bx+4] , 6

	sub si , 2	; 初始小蛇水平方向，蛇头后一个点的位置就是si-2
	add bx , 6

	mov word ptr ds:[bx+0] , 0   ; ds:[bx+0] = 0,第二个节点前面是蛇头节点，pre=0
	mov ds:[bx+2] , si
	mov es:[si] , dx             ; 设置蛇的颜色
	mov word ptr ds:[bx+4] , 12

	sub si , 2
	add bx , 6

	mov word ptr ds:[bx+0] , 6   ; ds:[bx+0] = 6
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
	mov es:[bx] , dx  ;dx=4831h,字符31h=数字1，颜色=0100100b
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
	mov dx , 0700h
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

	cmp al , 3bh  ; 字符 ‘F1’ 的扫描码
	jne int9Ret
	call change_screen_color ;写来测试看，我写的9号中断处理键盘缓冲区能不能正常工作


int9Ret:
	pop ax
	iret


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



greedy_snake_end:	
	nop







;-------------------------------------------
set_new_int9:
	mov bx , 0
	mov es , bx

	cli
	mov word ptr es:[9*4] , offset new_int9 - offset greedy_snake + 0208h
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
	mov bx , cs	; 要拷贝的代码是在当前代码段CS
	mov ds , bx
	mov si , offset greedy_snake

	mov bx , 0
	mov es , bx 
	mov di , 0208h  ; 自己指定一个位置

	mov cx , offset greedy_snake_end - offset greedy_snake
	cld
	rep movsb

	ret

code ends
end start