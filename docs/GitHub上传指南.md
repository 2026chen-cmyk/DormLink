# 创建仓库和提交
GitHub 用户名是 https://github.com/ 后面的账号名，不是登录邮箱。
1. 登录 https://github.com ，点击右上角头像 → Your profile，复制地址最后的账号名。
2. 点击右上角 + → New repository。名称填写 dorm-link-harmonyos，Description 填“智能宿舍自动化规则编排课程项目”。
3. 为方便老师访问可选 Public；如果涉及隐私可用 Private 并邀请老师。不勾选自动创建 README（本项目已有）。点击 Create repository。
4. 将仓库地址发回当前聊天，格式 https://github.com/用户名/dorm-link-harmonyos 。不要提供密码或 token。

## 使用 GitHub Desktop（适合初次使用）
安装 https://desktop.github.com/ 并登录本人账号。使用 File → Add local repository 选择本 DormLink 文件夹；若提示不是 Git 仓库，点击 create a repository here。确认 Local path 为 DormLink 的父目录，Name 为 DormLink，避免建成嵌套目录。也可先 Create new repository 到一个新目录，再复制本项目所有内容（含 .gitignore，不含 tests/.runtime）进去。
完成审阅后填写真实 Summary，例如“实现环境模型、规则优先级执行与冲突记录”，Commit to main；Publish repository，仓库名称可设 dorm-link-harmonyos。
后续真实修改分别提交，例如修复 ArkTS 编译问题、完善 UI、验证恢复、补运行证据。不要为看起来像开发过程拆造无内容的提交或修改日期。
若先在网页建了空仓库，可 Desktop → Clone repository → URL，克隆后复制项目内容，Commit，再 Push。
在 GitHub 网页核查源码已出现，且未上传签名文件、密钥、local.properties 或 oh_modules。

## 仅网页上传（备选）
进入新仓库，Add file → Upload files，拖入项目内容，保持文件夹层级。网页可能跳过隐藏 .gitignore，须单独核查。测试和后续修改仍需在本人账号提交。

提交作业答案必须包括：GitHub 仓库完整 URL + 本人 GitHub 用户名。登录邮箱不替代用户名。
