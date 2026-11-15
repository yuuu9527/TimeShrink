# 时间收缩 · TimeShrink

打开锁屏音乐界面（点开封面）时，把锁屏上的大时间**收缩到状态栏下方**，不再压在封面上；收起音乐后自动恢复。

适配 iOS 16+（SpringBoard / CoverSheet），**隐根（RootHide / roothide）** 打包，架构 `iphoneos-arm64e`，文件直接安装到 `/Library`（无 `/var/jb`）。

## 安装

从 [Releases](../../releases) 下载 `com.yu.timeshrink_*.deb`，用 Sileo / Filza 安装，或者在终端：

```sh
dpkg -i com.yu.timeshrink_*.deb
killall -9 SpringBoard
```

> 本包只适用于 RootHide（隐根）环境；无根/多巴胺环境请用 rootless 变体重新构建。

## 使用

设置 → 时间收缩：

| 选项 | 说明 |
|---|---|
| 启用插件 | 总开关（默认关闭） |
| 收缩比例 | 收缩后的大小，0.15–0.60，默认 0.30 |
| 同时淡出日期 | 时间缩到顶部时把日期一起淡出，避免重叠 |

## 实现

- Hook `CSCoverSheetViewController` / `CSMainPageContentViewController` 的布局回调；
- 在锁屏视图树里找字号最大的「时间」视图（同时支持 UILabel 和只暴露无障碍文本的自绘视图）；
- 找到宽过屏宽 45% 的封面视图（类名含 artwork/albumArt/nowPlaying，或接近正方形的大图）来判定「音乐已展开」；
- 用 `UIView` 弹簧动画把时间缩放到顶部，0.4s 轮询兜底。

## 局限

- 依赖运行时查找视图，不做私有类硬编码；不同系统版本表现可能不同，属于实验性插件。
- 只在 SpringBoard 内生效，不修改任何系统文件。

by 鱼教兽
