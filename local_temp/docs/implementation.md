# LiveCaptions Translator 实现方案

## 项目概述

LiveCaptions Translator 是一个集成了翻译API与Windows实时字幕(Live Captions)功能的工具，它能够实现实时语音翻译，即使在非Copilot+ PC上也可使用。项目使用C#和.NET框架开发，采用Fluent UI设计风格。

## 系统架构

### 核心组件

1. **Windows Live Captions 集成** - 自动调用Windows系统的实时字幕功能
2. **文本处理引擎** - 处理和优化Live Captions生成的文本
3. **翻译引擎** - 连接多种翻译API服务
4. **用户界面** - 简洁美观的Fluent UI风格界面

### 关键类与模块

```
src/
├── models/ - 数据模型
│   ├── Caption.cs - 字幕数据模型
│   ├── Setting.cs - 用户设置
│   ├── TranslateAPIConfig.cs - 翻译API配置
│   └── TranslationTaskQueue.cs - 翻译任务队列
├── utils/ - 工具类
│   ├── LiveCaptionsHandler.cs - Windows Live Captions交互
│   ├── TextUtil.cs - 文本处理工具
│   └── TranslateAPI.cs - 翻译API集成
└── windows/ - 用户界面
    └── [界面相关文件]
```

## 核心实现细节

### 1. Windows Live Captions 集成

LiveCaptions Translator通过`Windows.Automation`命名空间与Windows Live Captions进行交互，实现了对Live Captions窗口的控制和内容获取。

关键代码（源自`LiveCaptionsHandler.cs`）：

```csharp
public static AutomationElement LaunchLiveCaptions()
{
    // 初始化
    KillAllProcessesByPName(PROCESS_NAME);
    var process = Process.Start(PROCESS_NAME);

    // 查找窗口
    AutomationElement? window = null;
    for (int attemptCount = 0;
         window == null || window.Current.ClassName.CompareTo("LiveCaptionsDesktopWindow") != 0;
         attemptCount++)
    {
        window = FindWindowByPId(process.Id);
        if (attemptCount > 10000)
            throw new Exception("Failed to launch!");
    }

    return window;
}

public static string GetCaptions(AutomationElement window)
{
    if (captionsTextBlock == null)
        captionsTextBlock = FindElementByAId(window, "CaptionsTextBlock");
    try
    {
        return captionsTextBlock?.Current.Name ?? string.Empty;
    }
    catch (ElementNotAvailableException)
    {
        captionsTextBlock = null;
        throw;
    }
}
```

### 2. 文本处理与同步

系统通过两个核心循环处理字幕流：`SyncLoop`和`TranslateLoop`。`SyncLoop`负责从Live Captions获取文本并进行预处理，而`TranslateLoop`负责翻译处理。

关键代码（源自`Translator.cs`）：

```csharp
public static void SyncLoop()
{
    int idleCount = 0;
    int syncCount = 0;

    while (true)
    {
        if (Window == null)
        {
            Thread.Sleep(2000);
            continue;
        }

        string fullText = string.Empty;
        try
        {
            // 检查LiveCaptions.exe是否仍在运行
            var info = Window.Current;
            var name = info.Name;
            // 获取LiveCaptions识别的文本 (10-20ms)
            fullText = LiveCaptionsHandler.GetCaptions(Window);     
        }
        catch (ElementNotAvailableException)
        {
            Window = null;
            continue;
        }
        
        // 文本预处理
        fullText = RegexPatterns.Acronym().Replace(fullText, "$1$2");
        fullText = RegexPatterns.AcronymWithWords().Replace(fullText, "$1 $2");
        fullText = RegexPatterns.PunctuationSpace().Replace(fullText, "$1 ");
        fullText = RegexPatterns.CJPunctuationSpace().Replace(fullText, "$1");
        fullText = TextUtil.ReplaceNewlines(fullText, TextUtil.MEDIUM_THRESHOLD);
        
        // 获取最后一个句子并处理
        // ...
        
        Thread.Sleep(25);
    }
}
```

### 3. 多种翻译API集成

系统支持多种翻译API，包括Google、OpenAI、Ollama、DeepL等，使用统一的接口进行调用。

关键代码（源自`TranslateAPI.cs`）：

```csharp
public static readonly Dictionary<string, Func<string, CancellationToken, Task<string>>>
    TRANSLATE_FUNCTIONS = new()
{
    { "Google", Google },
    { "Google2", Google2 },
    { "Ollama", Ollama },
    { "OpenAI", OpenAI },
    { "DeepL", DeepL },
    { "OpenRouter", OpenRouter },
    { "Youdao", Youdao },
    { "MTranServer", MTranServer },
};

public static async Task<string> OpenAI(string text, CancellationToken token = default)
{
    var config = Translator.Setting.CurrentAPIConfig as OpenAIConfig;
    string language = config.SupportedLanguages.TryGetValue(Translator.Setting.TargetLanguage, out var langValue)
        ? langValue
        : Translator.Setting.TargetLanguage;
    var requestData = new
    {
        model = config?.ModelName,
        messages = new BaseLLMConfig.Message[]
        {
            new BaseLLMConfig.Message { role = "system", content = string.Format(Prompt, language)},
            new BaseLLMConfig.Message { role = "user", content = $"🔤 {text} 🔤" }
        },
        temperature = config?.Temperature,
        max_tokens = 64,
        stream = false
    };

    // HTTP请求处理...
}
```

### 4. 数据模型设计

系统使用`Caption`类存储和管理字幕数据，实现`INotifyPropertyChanged`接口以支持界面实时更新。

关键代码（源自`Caption.cs`）：

```csharp
public class Caption : INotifyPropertyChanged
{
    private static Caption? instance = null;
    public event PropertyChangedEventHandler? PropertyChanged;

    private string displayOriginalCaption = "";
    private string displayTranslatedCaption = "";
    private string overlayOriginalCaption = "";
    private string overlayTranslatedCaption = "";

    public string OriginalCaption { get; set; } = "";
    public string TranslatedCaption { get; set; } = "";
    
    // 属性实现...
    
    public Queue<TranslationHistoryEntry> LogCards { get; } = new(6);
    public IEnumerable<TranslationHistoryEntry> DisplayLogCards => LogCards.Reverse();
    
    // 单例模式实现
    public static Caption GetInstance()
    {
        if (instance != null)
            return instance;
        instance = new Caption();
        return instance;
    }
}
```

## 关键技术难点与解决方案

### 1. Windows Live Captions的集成

**难点**：Windows Live Captions没有提供公开API进行集成。

**解决方案**：使用Windows Automation API捕获Live Captions窗口，并通过AutomationElement获取字幕内容。通过以下步骤实现：
- 启动Live Captions进程
- 查找并固定Live Captions窗口
- 通过AutomationId识别字幕文本块
- 实时获取字幕内容

### 2. 文本处理与分段

**难点**：Live Captions生成的文本可能包含多个句子，需要合理分段才能进行翻译。

**解决方案**：
- 使用正则表达式处理各种文本格式问题
- 根据标点符号识别句子边界
- 对不同语言的句子结构进行特殊处理
- 使用队列管理待翻译文本片段

### 3. 翻译任务队列管理

**难点**：需要处理翻译API的延迟和可能的失败情况。

**解决方案**：实现`TranslationTaskQueue`类，具有以下特点：
- 任务优先级管理
- 取消旧任务支持
- 错误处理和重试机制
- 结果缓存

## 扩展性设计

系统设计考虑了良好的扩展性：

1. **翻译API扩展**：通过抽象接口设计，只需添加新的API实现到`TRANSLATE_FUNCTIONS`字典即可支持新的翻译服务。

2. **UI主题支持**：支持明暗主题自动切换，跟随系统主题。

3. **设置持久化**：用户设置通过`Setting`类管理，支持配置的保存和加载。

## 性能优化

1. **轻量级设计**：程序设计保持轻量级，避免占用过多系统资源。

2. **翻译请求限流**：通过`MaxSyncInterval`和`MaxIdleInterval`参数控制翻译请求频率。

3. **UI响应性优化**：使用属性通知机制确保UI的实时更新不影响核心处理逻辑。

## 结论

LiveCaptions Translator通过巧妙地集成Windows Live Captions和多种翻译API，创建了一个实用的实时语音翻译工具。系统的设计考虑了扩展性、性能和用户体验，使得非Copilot+ PC用户也能享受实时语音翻译功能。 