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

	DIRECTION dw 3		; 设置自动移动
	DIRECTION_FUN dw offset isMoveUp     - offset greedy_snake + 7e00h ; [0]
		      dw offset isMoveDown   - offset greedy_snake + 7e00h ; [2]
		      dw offset isMoveLeft   - offset greedy_snake + 7e00h ; [4]
		      dw offset isMoveRight  - offset greedy_snake + 7e00h ; [6]
		
	FOOD_LOCATION dw 160*3 + 20*2	; 先人为的设定一个位置
	FOOD_COLOR dw 4439h	; 39h=字符'9' , 44h=01000100b 红色
	NEW_NODE dw 18		; 后面吃到食物那要用到，18就是我们初始化小蛇后蛇尾的下一个位置

	GAME_OVER db 'Game Over!' 
	GAME_DIR db 'direction: '
	SCORE_STR db 'Score='
	SCORE_CHAR db '0123456789ABCDEF'
	SCORE dw 0h
	SCORE_POSITION dw 160*24+60*2


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
	call init_food
	call init_snake	           ; 画出蛇的图形

	

nextMove:
	call delay    
	cli
	call isMoveDirection
	sti
	jmp nextMove



testA:	; 无限循环,测试
	mov ax , 1000h
	jmp testA

	mov ax , 4c00h
	int 21h



;-----------------------------------------
init_food:
	mov di , FOOD_LOCATION
	push FOOD_COLOR
	pop es:[di]
	ret


;-----------------------------------------
isMoveDirection:
	mov bx , DIRECTION
	add bx , bx
	call word ptr ds:DIRECTION_FUN[bx]
	ret



;-----------------------------------------
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
	call show_score		   ; 初始化界面下面输出字符串score=
	call output_score	   ; 输出成绩，初始为 0 
	call show_direction        ; 显示dierction
	
	ret


;-----------------------------------------
show_direction:
	mov si , offset GAME_DIR
	mov di , 160*24+0*2
	mov cx , 11
showDirection:
	mov al , ds:[si]
	mov es:[di] , al
	mov byte ptr es:[di+1] , 00000010b
	inc si
	add di , 2
	loop showDirection
	ret


;-----------------------------------------
show_score:
	mov si , offset SCORE_STR
	mov di , 160*24+50*2
	
	mov cx , 6
showScore:
	mov al , ds:[si]
	mov es:[di] , al
	mov byte ptr es:[di+1] , 00000010b
	inc si
	add di , 2
	loop showScore
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
output_score:
	mov si , offset SCORE
	mov ax , ds:[si]

	mov si , SCORE_POSITION	
	mov dx , ax

	mov al , ah
	mov ah , 0
	mov cx , 4
	shr al , cl	; 得到最高位
	mov bx , ax
	mov al , ds:SCORE_CHAR[bx]
	mov byte ptr es:[si] , al
	mov byte ptr es:[si+1] , 00001010b
	add si , 2

	mov ax , dx
	mov al , ah
	mov ah , 0
	mov cx , 4
	shl al , cl   
	shr al , cl	; 次高位
	mov bx , ax
	mov al , ds:SCORE_CHAR[bx]
	mov byte ptr es:[si] , al
	mov byte ptr es:[si+1] , 00001010b
	add si , 2

	mov ax , dx
	mov ah , 0
	mov cx , 4
	shr al , cl	; 次次高位
	mov bx , ax
	mov al , ds:SCORE_CHAR[bx]	
	mov byte ptr es:[si] , al
	mov byte ptr es:[si+1] , 00001010b
	add si , 2

	mov ax , dx
	mov ah , 0
	mov cx , 4
	shl al , cl	
	shr al , cl	; 最低位
	mov bx , ax
	mov al , ds:SCORE_CHAR[bx]
	mov byte ptr es:[si] , al
	mov byte ptr es:[si+1] , 00001010b
	add si , 2

	mov byte ptr es:[si] , 'H'
	mov byte ptr es:[si+1] , 00001010b


	ret


;-----------------------------------------
show_left_right_line:
	mov bx , 0
	mov cx , 23
showLeftRightLine:
	mov es:[bx] , dx
	mov es:[bx+79*2] , dx
	;add bx , 160
	add bx , NEXT_ROW  ; 优化写法
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
	mov di , 160*24 + 12*2  ;  每行最下面显示出按下的按键
	mov byte ptr es:[di] , 'U'
	mov byte ptr es:[di+1] , 00001010b
	cmp DIRECTION , 1	; 自动移动加入的时候，按下按键要进行判断，如果水平方向相反，就不用移动了
; 下面写的移动函数，在移动前会判断将要移动到的位置的字符信息是不是背景(也就是没显示其他的东西)，如果是
; 就直接返回了，这么写是代码风格更好。效率也高
	je int9Ret

	call isMoveUp
	jmp int9Ret

isDown:
	mov di , 160*24 + 12*2  ;  每行最下面显示出按下的按键
	mov byte ptr es:[di] , 'D'
	mov byte ptr es:[di+1] , 00001010b
	cmp DIRECTION , 0
	je int9Ret

	call isMoveDown
	jmp int9Ret

isLeft:
	mov di , 160*24 + 12*2  ;  每行最下面显示出按下的按键
	mov byte ptr es:[di] , 'L'
	mov byte ptr es:[di+1] , 00001010b
	cmp DIRECTION , 3
	je int9Ret

	call isMoveLeft
	jmp int9Ret

isRight:
	mov di , 160*24 + 12*2       ; 每行最下面显示出按下的按键
	mov byte ptr es:[di] , 'R'  
	mov byte ptr es:[di+1] , 00001010b
	cmp DIRECTION , 2
	je int9Ret

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

	mov DIRECTION , 0		; 在按下相应按键，蛇能动了之后，就要设置自动移动了
	ret

noMoveUp:
	call isFood
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

	mov DIRECTION , 1
	ret
noMoveDown:
	call isFood	;下一步不能走，加入食物后也要判断下是不是食物
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
	mov DIRECTION , 2
	ret
noMoveLeft:
	call isFood
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
	mov DIRECTION , 3
	ret
noMoveRight:
	call isFood
	ret


;-------------------------------------------
isFood:
	cmp byte ptr es:[si] , '9'	; 我们前面设置了食物的字符是9,前景背景都是红色
	jne noFood

	call eat_food
	call set_new_food	; 吃掉一个要再生成一个
	ret
noFood:
	call clear_screen
	call recover_int9Ret
	call end_game
	call return_dos
	
	ret


;-------------------------------------------
return_dos:
	mov ax , 4c00h
	int 21h


;-------------------------------------------
recover_int9Ret:
	push es
	mov bx , 0
	mov es , bx
	push es:[200h]
	pop es:[9*4]
	push es:[202h]
	pop es:[9*4+2]
	pop es
	ret
;-------------------------------------------
end_game:
	mov si , offset GAME_OVER
	mov di , 160*12+35*2
	mov cx , 10
endGame:
	mov al , ds:[si]
	mov byte ptr es:[di] , al
	mov byte ptr es:[di+1] , 00001100b
	inc si
	add di , 2
	loop endGame

	ret


;-------------------------------------------
set_new_food:
	mov al , 0
	out 70h , al
	in al , 71h

	mov dl , al 
	and dl , 00001111b	; dl中是个位数的数字
	push cx
	mov cl , 4
	mov ch , 0
	shr al , cl	; al中是十位数的数字
	pop cx		; 之前这里没有pop,导致出错，调试半天
	mov bl , 10
	mul bl		; ax=al*bl
	add al , dl	; 得到秒数

	mul al		; 如果al是奇数,得到的肯定也是一个奇数;25*80*2=4000种显示位置,最后一行是3840~4000
; 按小时算，60*60=3600种位置，所以食物不可能随机到最后一行，导致蛇吃不到食物
	shr al , 1	; 二进制，右移一位去掉产生奇数的1
	shl al , 1	; 控制误差，再左移一位，这样误差就为1
	mov bx , ax	; 得到下一个食物出现的位置
	cmp byte ptr es:[bx] , 0	; 如果得到的位置不是空闲的
	jne set_new_food	; 这里有一个问题，如果生成的食物位置不行，到这里要跳转，又要进行下次执行，但是又要发生键盘中断
	
	push FOOD_COLOR		
	pop es:[bx]	; 这种办法可能得到的食物在蛇身上或者边界上

	ret


;-------------------------------------------
eat_food:
	push NEW_NODE		; 记录新节点的位置
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
	pop SNAKE_HEAD		; 设置新的头
;                               00   02   04       06   08   10       12   14   16       18   20   22  
;最开始小蛇相关信息在内存中存放(18   si   06   |   00   si   12   |   06   si   18   |   00   si   00) 
;                               ↑    ↑    ↑        ↑    ↑    ↑        ↑    ↑    ↑        ↑    ↑    ↑
;				pre  pos  next     pre  pos  next     pre  pos  next     pre  pos  next  
;这个图是初始小蛇走了一步，然后吃了食物后在内存中的存储状态，第四个节点就变成新的蛇头节点,后面一次是第一个节点第二个节点和第三个节点
;尾节点没变，还是在内存偏移12的位置
	add NEW_NODE , 6

	inc SCORE
	call output_score

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
	jz clearBuffRet		; ZF=1,键盘无输入
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