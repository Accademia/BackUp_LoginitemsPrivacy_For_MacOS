备份\还原：登录项 (含后台项清单) 与 TCC (隐私)



概要：
-------
	+ 用于备份、还原 ：登录项 (含后台项清单) 与 TCC (隐私)
		- 登录时打开
 
.

命令说明：
-------

	# 1) 赋予可执行权限
	chmod +x mac-loginitems-privacy.sh

	# 2) 先干跑验证（仅打印步骤与目标路径，不写入）
	sudo zsh ./mac-loginitems-privacy.sh backup --dry-run

	# 3) 备份（会在 iCloud Drive 目标目录内创建时间戳子目录）
	sudo zsh ./mac-loginitems-privacy.sh backup

	# 4) 查看状态摘要（前 200 行 sfltool 输出 + 当前“登录时打开”列表 + TCC 前 20 条）
	sudo zsh ./mac-loginitems-privacy.sh status

	# 5) 还原（重建“登录时打开”；尝试安装 .mobileconfig；打开“登录项”设置页）
	sudo zsh ./mac-loginitems-privacy.sh restore

	# 6) 重置（清空登录项/后台项数据库 + 重置所有 TCC；谨慎！）
	sudo zsh ./mac-loginitems-privacy.sh reset

	
.

保存路径：(备份数据保存在哪里)
-------

	/iCloud/BACKUP/计算机名称/用户名称/Loginitems-Privacy/

	# 注意：执行保存还原时，路径上的用户名中不要有空格（如果有空格，会被自动删除）


使用建议：
-------

	+ 可以将备份命令加到自动任务当中，从而每日自动备份。


用途：
-------

	+ 对于MacOS来说，最大的用处就是在系统迁移的时候、或系统还原的时候，首次启动时会卡在登录界面无法前进。此时建议，先用另一个空白的Admin账户进入系统，清理掉 无法启动用户的 全部启动项，然后就能避免 首次启动时 被卡住了。

	++ 当进入系统后，在使用还原功能，将登录项 (含后台项清单) 与 TCC (隐私) 还原。



版权：
-------
	+ 遵从MIT协议
	+ 所有代码全部来自于 OpenAI ChatGPT 5 Pro + Agent 编写

