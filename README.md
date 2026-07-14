# Display Calibration Saver

[![Windows](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4)](https://github.com/CRYS74L/Display-Calibration-Saver)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)](https://learn.microsoft.com/powershell/)
[![Validation](https://github.com/CRYS74L/Display-Calibration-Saver/actions/workflows/powershell-check.yml/badge.svg)](https://github.com/CRYS74L/Display-Calibration-Saver/actions/workflows/powershell-check.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**简体中文** · [English](README.en.md)

把 Windows 当前正在生效的显示校色预览保存为可重复使用的 ICC/ICM 配置文件。

Display Calibration Saver 专门解决这一类问题：校色软件能够正确预览需要的色温、色调、亮度或阶调调整，但无法把调整后的状态保存下来。工具会读取指定显示器当前真正生效的校准曲线，并把它写入一个基础配置文件的副本。

> 颜色如何计算仍由原校色软件负责。Display Calibration Saver 只保存最终结果，不猜测滑杆数值，也不模仿厂商算法。

## 快速使用

1. 下载并解压最新发布包。
2. 双击 `Run.cmd`。
3. 选择一个已经含有 `vcgt` 标签的基础 ICC/ICM 文件。
4. 设置输出文件名、目标显示器和倒计时时间。
5. 开始倒计时后切换到校色软件。
6. 开启并保持需要保存的预览效果。
7. 倒计时结束后，安装并应用生成的新配置文件。

除非你主动选择已存在的输出文件并确认覆盖，否则工具不会修改原始配置文件。

## 为什么需要这个工具

不少校色软件会先把预览调整临时写入 Windows 对应显示器的 Gamma Ramp，再执行保存操作。即使保存失败，想要的显示状态仍可能已经存在于显卡当前的校准表中。这个工具会把这种临时状态固定成可以重复加载的配置文件。

```text
兼容软件的校色预览
        ↓
当前显示器实际生效的校准曲线
        ↓
所选 ICC/ICM 的副本
        ↓
写入捕获曲线的新 vcgt 标签
```

## 功能

- 捕获指定 Windows 显示器当前生效的校准曲线
- 保留基础配置文件并单独生成输出文件
- 每个 RGB 通道保存 256 个节点，精度为 16-bit
- 支持自定义输出文件名和倒计时时间
- 检查 ICC 签名、标签表、偏移、对齐和文件边界
- 正确处理 ICC v2 保留字段，并为 ICC v4 重新计算 Profile ID
- 只依赖 Windows 自带的 PowerShell 5.1
- 不需要安装、不需要管理员权限、不联网、不收集数据

## 使用条件

- Windows 10 或 Windows 11
- Windows PowerShell 5.1 或更高版本
- 基础 ICC/ICM 文件中已经存在 `vcgt` 标签
- 校色软件会通过 Windows 对应显示器的 Gamma Ramp 应用预览效果

## 兼容性

项目不限定任何校色品牌。只要软件通过 Windows 标准显示 Gamma Ramp 路径应用预览，就有可能被捕获。

已确认的适用场景包括 Datacolor SpyderTune：当预览效果正确、但调整后的配置文件无法保存时，可以用本工具保留当前结果。

其他校色工具和配置加载器也可能适用。一个直观的判断方法是：调整后，目标显示器上的整个桌面是否同步变化，而不是只有软件自己的预览窗口变化。

## 无法捕获的效果

它不能保存所有肉眼可见的色彩变化，例如：

- 只存在于某个应用窗口、着色器或渲染管线中的调整
- 游戏内部滤镜或后期处理
- 显示器菜单直接修改的硬件参数或内部 LUT
- 独立的 3D LUT 管线
- 部分 HDR 与高级色彩管理路径
- 绕过标准 Windows Gamma Ramp 的驱动叠加效果

## 工作原理

兼容软件进行预览时，会把三条“每通道 256 个节点、16-bit 精度”的曲线写入目标显示器的 Video LUT。工具通过 Windows GDI 的 `GetDeviceGammaRamp` 接口读取当前数值，再把完整表格写入基础配置文件的 `vcgt` 标签。

生成文件会保留基础配置文件原有的显示器特性描述，只替换显示校准表。文件结构和校验规则见[技术说明](docs/TECHNICAL.md)。

## 重要限制

- 基础配置文件必须已经含有 `vcgt` 标签。
- 1.0 版本要求 `vcgt` 是配置文件中的最后一个数据块，才能在不移动其他标签的情况下安全扩展。
- 捕获校准曲线不会重新测量或重新描述显示器的色域、原生白点等特性。
- 生成文件只适用于基础配置文件创建时对应的显示器状态和硬件设置。
- 没有测量仪器时，工具无法验证最终画面的客观准确性。

## 故障排查

常见报错、多显示器问题、HDR 限制以及配置文件格式问题见[故障排查](docs/TROUBLESHOOTING.md)。

## 隐私与安全

工具完全在本地运行，不联网、不上传配置文件、不收集遥测数据，也不申请管理员权限。每个发布包都包含完整 PowerShell 源代码。


## 声明

Display Calibration Saver 是独立开发的非官方工具，与 Datacolor、Microsoft 或其他校色软硬件厂商没有隶属、授权或合作关系。

## 许可证

项目使用 [MIT License](LICENSE)。
