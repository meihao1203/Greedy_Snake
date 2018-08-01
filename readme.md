> 注：GREEDY_SNAKE 是基于8086 汇编语言开发的，汇编语言风格是采用《汇编语言》第二版 王爽著；

### Greedy_Snake 要在Intel实模式下运行，所有运行项目前要安装DOSBOX 虚拟出一个8086实模式环境 ###
1. 安装DOSBOX：运行DOSBox0.74-win32-installer.exe即可安装；
2. 将Greedy_Snake clone到本地任意盘，eg:d:\Greedy_Snake
	- mount d:\Greedy_Snake 到一个指定虚拟盘符：
	- `mount k d:\Greedy_Snake`   (why is k？ because i like this charactor)
3. 运行G_Snake
	- 在DOSBOX的DOS提示符下键入：
	- `Z:\>K:`(回车)
	- `K:\>cd G_Snake`(回车)
	- 使用masm 5.0工具编译、链接、运行.asm源程序
	- MASM.EXE、LINK.EXE、debug.exe、edit.com都是开发工具，用来编译、链接、调试和编辑代码
4. G_Snake.asm 是最终代码；
	- `masm G_Snake.asm`  (编译游戏)
	- `link G_Snake.obj` (链接游戏)
	- `G_Snake`   (运行游戏)
5. G_Snake.asm分了4个步骤：
	 - map.asm 是绘制游戏界面的
	 - sMove.asm 是让小蛇响应对应的键盘中断自动移动
	 - sMA.asm  是让小蛇响应方向后自动移动
	 - G_Snake.asm 是最终程序

----------

### G_Snake.asm 实现了随机出现食物，统计分数，显示小蛇运动方向，响应键盘中断后指定方向自动移动和游戏结束恢复9h键盘中断正常退出  ###

----------
#### 游戏开始界面 ####
![游戏开始界面](https://github.com/meihao1203/Greedy_Snake/blob/master/G_Snake/1.png)
#### 运行吃到6个食物 ####
![游戏运行界面](https://github.com/meihao1203/Greedy_Snake/blob/master/G_Snake/2.png)
#### 游戏结束界面 ####
![游戏结束界面](https://github.com/meihao1203/Greedy_Snake/blob/master/G_Snake/3.png)


----------
注：游戏运行中有可能会卡住不出现食物，这时候是程序通过获取cmos芯片中的秒数来计算得出的食物位置不合理，正在重新获取新的秒数计算新的食物位置；很快就会恢复。
