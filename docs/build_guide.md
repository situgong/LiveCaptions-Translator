# LiveCaptions Translator 编译打包指南

本文档提供了如何在本地环境中编译和打包LiveCaptions Translator项目的详细说明。

## 前置要求

在开始编译之前，请确保您的系统满足以下要求：

1. **操作系统**：Windows 11 (22H2或更高版本)
2. **.NET开发环境**：
   - .NET SDK 8.0或更高版本
   - Visual Studio 2022或更高版本（推荐）或Visual Studio Code

## 获取源代码

```bash
# 克隆仓库
git clone https://github.com/SakiRinn/LiveCaptions-Translator.git
# 进入项目目录
cd LiveCaptions-Translator
```

## 使用Visual Studio编译

1. 使用Visual Studio打开解决方案文件 `LiveCaptionsTranslator.sln`
2. 选择配置为 `Release` 和平台为 `Any CPU`（或根据需要选择`ARM64`）
3. 构建解决方案（快捷键`Ctrl+Shift+B`或使用菜单`构建->构建解决方案`）
4. 编译后的文件将位于项目的 `bin/Release/net8.0-windows` 目录下

## 使用命令行编译

您也可以使用.NET CLI（命令行接口）来编译项目：

### 基本编译

```bash
# 恢复包依赖
dotnet restore

# 编译项目（Debug模式）
dotnet build

# 编译项目（Release模式）
dotnet build -c Release
```

### 发布应用程序

#### 发布框架依赖版本（较小文件体积，需要目标机器安装.NET运行时）

```bash
# x64架构
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o ./publish/x64

# ARM64架构
dotnet publish -c Release -r win-arm64 --self-contained false -p:PublishSingleFile=true -o ./publish/arm64
```

#### 发布自包含版本（较大文件体积，不需要目标机器安装.NET运行时）

```bash
# x64架构
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -o ./publish/x64-selfcontained

# ARM64架构
dotnet publish -c Release -r win-arm64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true -o ./publish/arm64-selfcontained
```

发布后的可执行文件将会在对应的输出目录中。

## 自动化构建和发布

本项目使用GitHub Actions进行自动化构建和发布。当推送带有`v`前缀的标签时（如`v1.0.0`），将会自动触发构建和发布流程。

CI/CD流程将会：
1. 构建x64和ARM64架构的框架依赖和自包含版本
2. 创建GitHub Release并上传构建产物

若需手动触发构建流程，可以在GitHub仓库中进入Actions标签页，然后选择`CI/CD Pipeline`并点击`Run workflow`。

## 发布文件说明

构建完成后，将会生成以下几种文件：

1. `LiveCaptionsTranslator-win-x64.exe` - x64架构的框架依赖版本（需要安装.NET 8运行时）
2. `LiveCaptionsTranslator-win-x64-withruntime.exe` - x64架构的自包含版本（无需安装额外运行时）
3. `LiveCaptionsTranslator-win-arm64.exe` - ARM64架构的框架依赖版本（需要安装.NET 8运行时）
4. `LiveCaptionsTranslator-win-arm64-withruntime.exe` - ARM64架构的自包含版本（无需安装额外运行时）

## 注意事项

1. 自包含版本文件体积较大（约60-80MB），但可以在未安装.NET运行时的机器上运行
2. 框架依赖版本文件体积较小（约2-3MB），但需要目标机器已安装.NET 8.0运行时
3. 确保使用的.NET SDK版本与项目要求兼容
4. 若需要在ARM64设备上运行，请选择对应的ARM64版本 