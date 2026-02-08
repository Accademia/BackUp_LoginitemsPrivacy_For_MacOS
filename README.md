



# 概要：

<br>

+ 用于备份、还原 ：登录项 (含后台项清单) 与 TCC (隐私)

 
<br>
<br>

-------


# 使用建议：
<br>

+ 可以将备份命令加到自动任务当中，从而每日自动备份。

<br>
<br>

---------


# 用途：

<br>

+ 对于MacOS来说，最大的用处就是在系统迁移的时候、或系统还原的时候，首次启动时会卡在登录界面无法前进。此时建议，先用另一个空白的Admin账户进入系统，清理掉 无法启动用户的 全部启动项，然后就能避免 首次启动时 被卡住了。

+ 当进入系统后，在使用还原功能，将登录项 (含后台项清单) 与 TCC (隐私) 还原。

<br>
<br>

---------


# 程序下载

<br>

#  [usercmd_backup_LoginitemsPrivacy](https://cdn.jsdelivr.net/gh/Accademia/BackUp_LoginitemsPrivacy_For_MacOS/usercmd_backup_LoginitemsPrivacy)  

> ### https://cdn.jsdelivr.net/gh/Accademia/BackUp_LoginitemsPrivacy_For_MacOS/usercmd_backup_LoginitemsPrivacy

<br>

#  [usercmd_restore_LoginitemsPrivacy](https://cdn.jsdelivr.net/gh/Accademia/BackUp_LoginitemsPrivacy_For_MacOS/usercmd_restore_LoginitemsPrivacy)   

> ### https://cdn.jsdelivr.net/gh/Accademia/BackUp_LoginitemsPrivacy_For_MacOS/usercmd_restore_LoginitemsPrivacy

<br>
<br>

---------

# 命令说明：

<br>

	# 1) 赋予可执行权限
	chmod +x usercmd_backup_LoginitemsPrivacy
	chmod +x usercmd_restore_LoginitemsPrivacy

	# 2) 执行备份（LoginItems & Extensions + Privacy & Security）
	sudo ./usercmd_backup_LoginitemsPrivacy

	# 3) 执行还原（LoginItems & Extensions + Privacy & Security）
	sudo ./usercmd_restore_LoginitemsPrivacy

	
<br>
<br>

---------


#  保存路径：(备份数据保存在哪里)

<br>

	/iCloud/BACKUP/设备标识/用户名/LoginItemsExtensions/日期/
	/iCloud/BACKUP/设备标识/用户名/PrivacySecurity/日期/


<br>
<br>

---------


#  ⚠️⚠️⚠️ SIP 提示（隐私权限完整还原说明）：

<br>


	# 重要：隐私相关的“系统级 TCC 目录”还原，必须关闭 SIP 才能完整执行
	# 日常使用请保持 SIP 开启（不要长期关闭）

	# 关闭 SIP（仅用于临时还原）
	1) 重启进入恢复模式（Apple Silicon：长按电源键，出现“选项”后进入；Intel：开机按住 Command + R）
	2) 打开“终端”
	3) 执行：csrutil disable
	4) 重启

	# 还原完成后，务必恢复 SIP
	1) 再次进入恢复模式
	2) 打开“终端”
	3) 执行：csrutil enable
	4) 重启

<br>
<br>

---------


#  免密执行（sudoers）：

<br>

	# 重要：请把 <你的用户名> 替换成你自己的用户名
	# 如果脚本不在 /usr/local/bin/，请替换为实际路径

	# 1) 使用 visudo 创建 sudoers.d 文件
	sudo visudo -f /etc/sudoers.d/loginitems-privacy

	# 2) 写入以下内容（将 <你的用户名> 替换成你自己的用户名）
	<你的用户名> ALL=(root) NOPASSWD: SETENV: /usr/local/bin/usercmd_backup_LoginitemsPrivacy
	<你的用户名> ALL=(root) NOPASSWD: SETENV: /usr/local/bin/usercmd_restore_LoginitemsPrivacy

	# 3) 设置权限（必须为 0440，否则 sudo 会忽略）
	sudo chmod 0440 /etc/sudoers.d/loginitems-privacy



<br>
<br>

---------

   
#  本项目相关的系列工具

<br>

 - ## [UpdateFull_For_MacOS](https://github.com/Accademia/UpdateFull_For_MacOS)  🔥🔥🔥🔥🔥 
   
   > 聚合更新脚本，聚合了市面上所有主流的MacOS APP更新程序，包括 Homebrew 、 Mas 、 Sparkle 、 MacPorts 、 TopGreade 、MacUpdater 等 第三方更新软件。实现 一站式 + 后台静默执行 + 无人值守式 更新 。

 - ## [Migrate_MacApp_To_Homebrew](https://github.com/Accademia/Migrate_MacApp_To_Homebrew)  🔥🔥🔥🔥🔥 
   
   > 扫描本机 App，生成可迁移到 Homebrew 的安装清单。

 - ## [Generate_Sudoers_For_Homebrew](https://github.com/Accademia/Generate_Sudoers_For_Homebrew)  🔥🔥🔥 
   
   > 生成 ，执行Homebrew升级时，所需的 sudoers 免密规则，便于当前脚本时，全自动更新（无人值守式更新）。

 - ## [BackUp_LoginitemsPrivacy_For_MacOS](https://github.com/Accademia/BackUp_LoginitemsPrivacy_For_MacOS)  🔥 
   
   > 备份/还原 登录项与扩展、隐私与安全（TCC）配置。

 - ## [BackUp_LaunchPad_For_MacOS](https://github.com/Accademia/BackUp_LaunchPad_For_MacOS)  🔥 
   
   > 备份/还原 LaunchPad（启动台）布局。

 - ## [Generate_ClashRuleset_For_Homebrew](https://github.com/Accademia/Generate_ClashRuleset_For_Homebrew)  
   
   > 生成用于 Homebrew 下载更新时，所需的 Clash 规则集，提升访问稳定性。



<br>
<br>



版权：
-------
	
+ 遵从MIT协议

+ 所有代码全部来自于 OpenAI ChatGPT 5 Pro + Agent 编写
