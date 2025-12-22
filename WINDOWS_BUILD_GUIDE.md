# Windows 打包详细指南 (从零开始)

如果您从未接触过 Flutter，且您的机器上没有安装开发环境，请按照以下步骤操作。

> [!IMPORTANT]
> **限制条件**：您必须在 **Windows 电脑** 上执行以下操作。Mac 电脑无法直接生成 Windows 的 `.exe` 程序。

---

## 方案一：自动化打包 (推荐)

如果您将代码推送到 **GitHub**，我为您准备了自动构建脚本。

1. 将本项目推送至 GitHub 仓库。
2. 点击仓库顶部的 **Actions** 选项卡。
3. 在左侧选择 **Build Windows EXE** 流程。
4. 点击 **Run workflow** 手动触发构建。
5. 构建完成后，您可以在对应的任务中下载 `iot-devkit-windows-x64.zip`，解压即用。

---

## 方案二：本地手动打包 (在 Windows 电脑上)

如果您想在本地打包，请按以下步骤配置环境：

### 第一步：安装必要软件

1. **安装 Git**:
   从 [git-scm.com](https://git-scm.com/download/win) 下载并安装。安装时一路点击“下一步”即可。
2. **安装 Visual Studio 2022**:
   - 下载 [Visual Studio 社区版](https://visualstudio.microsoft.com/zh-hans/downloads/)。
   - **关键步骤**：在安装程序中勾选 **“使用 C++ 的桌面开发” (Desktop development with C++)**。否则打包会报错。

### 第二步：配置 Flutter SDK

1. **下载 SDK**: [点击下载 Flutter Stable SDK](https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.0-stable.zip)。
2. **解压**: 将压缩包解压到 `C:\development\flutter` (不要放在 C:\Program Files 等需要权限的文件夹)。
3. **配置环境变量**:
   - 在 Windows 搜索框搜索“环境变量”。
   - 编辑“系统变量”中的 `Path`。
   - 新建一项，输入 `C:\development\flutter\bin`。
4. **验证**: 打开 PowerShell，输入 `flutter doctor`。

### 第三步：获取代码并执行打包

1. **打开控制台**（在您的项目文件夹内）：

   ```powershell
   flutter pub get
   ```

2. **执行编译**:

   ```powershell
   flutter build windows --release
   ```

---

## 如何分发程序

打包完成后，您的程序位于：
`build\windows\x64\runner\Release\`

**注意**：您不能只拷贝 `iot_devkit.exe`。您必须把 **整个 Release 文件夹** 发送给目标用户，或者将其压缩成 ZIP 发送。

### 获取单文件安装包

如果您希望生成一个像 QQ、微信那样的单个安装包，建议使用 **Inno Setup**:

1. 下载安装 [Inno Setup](https://jrsoftware.org/isdl.php)。
2. 将 `Release` 文件夹内的所有文件作为源文件打包。
