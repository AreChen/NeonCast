# Development and releases

日常开发直接在 `main` 进行。开发代码、测试、文档和工具保留在仓库，玩家从 GitHub Releases 下载版本化的安装包。

## 发布步骤

1. 在 `main` 修改代码，执行 `python -m pytest tests -q`。
2. 更新 `NeonCast.toc` 的 `## Version`，并在 `CHANGELOG.md` 添加同版本的非空记录。
3. 运行 `python tools/package.py --tag v<版本>` 检查包。可使用 `--notes-output <路径>` 检查该版本的发布说明。
4. 提交并推送 `main`，然后创建并推送匹配的标签：

   ```sh
   git tag -a v0.3.0-beta.3 -m 'NeonCast 0.3.0-beta.3'
   git push origin v0.3.0-beta.3
   ```

   示例版本仅供本次发布使用；后续必须换成新版本。

`Release` 工作流确认标签提交属于 `main`，运行测试，核对版本与发布说明，然后构建 ZIP 和 SHA-256 校验文件。上传完成前保持 Draft，成功后发布。若上次仅创建了 Draft，重新运行可恢复上传；已公开的版本不能覆盖。

版本格式：`X.Y.Z` 为正式版；`X.Y.Z-alpha.N`、`X.Y.Z-beta.N`、`X.Y.Z-rc.N` 自动标记为预发布，不替换最新正式版。标签必须以 `v` 开头且与 TOC 完全一致。

## 玩家安装包

发布附件是 `NeonCast-<版本>.zip`，解压即得到 `NeonCast/`，直接放进 `Interface/AddOns/`。ZIP 使用固定路径、权限、排序和时间戳，相同输入产生相同字节。

内容仅限：

- `NeonCast.toc` 及其 Lua/XML 依赖，包括未来 UI XML 引用的脚本。
- 自动加载的根 `Bindings.xml`。
- `tools/package.py` 中明确列出的运行材质与图标。
- MIT `LICENSE`。

新增资源必须同时更新打包资源清单。README、多语言开发文档、测试、Python 依赖、工具、工作流、Git 信息及模拟预览不会进入 ZIP。SHA-256 校验文件作为独立发布附件提供。

GitHub 自动附带的 Source code ZIP/TAR 是开发源码快照，不是玩家安装包；请下载以 `NeonCast-` 开头的 ZIP 附件。
