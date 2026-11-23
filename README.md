# deleted-content-trace

**博主已删内容溯源工具箱** — 当一期视频、一条动态、一套图被删掉之后，用可复现的流程判断：它还存在于哪里，哪些渠道已经查死，哪些还物理上可能。

*A systematic tracer for deleted creator content: Bilibili status probing, third-party snapshot mining, Wayback CDX, and a platform sweep that distinguishes "searched, empty" from "cannot be searched".*

---

## 它解决什么问题

用户说「这个视频被删了，能找到吗」。直接开搜索引擎爬一遍，得到的是噪声和幻觉。正确顺序是：

1. 先把**人**认准，否则后面全是同名歧义
2. 再查**这一条**的确切状态，因为「已删除」和「仅自己可见」的救援路径完全不同
3. 然后去**快照站**捞元数据，因为页没了但解析记录常常还在
4. 再**扫平台**，但只扫真能扫的，其余如实标注「无法验证」
5. 最后给出一张**逐渠道判定表** + 按现实性排序的剩余路径

这个 skill 就是把这五步固化下来。

## 核心判断：`62002` 不是 `-404`

这是整个流程里最值钱的一条经验：

| 返回码 | 含义 | 还能回来吗 |
|---|---|---|
| `0` | 在线 | — |
| `-404 啥都木有` | 真没了，或者这 ID 从来不存在 | 只能靠缓存/搬运 |
| **`62002 稿件不可见`** | **稿件还在，只是不可见**（私密/锁定/审核中） | **能，UP 主一键就能恢复** |
| `62012 仅UP主自己可见` | 仅本人可见 | 只有 UP 主能改 |
| `12002 当前页面评论功能已关闭` | 页面已拆 | 不能 |

`62002` 意味着爬虫再怎么爬都是白费，因为文件还在服务器上、只是没人有权读——这种情况该建议的是「联系 UP 主」，而不是「继续挖」。

## 脚本

| 脚本 | 作用 |
|---|---|
| `scripts/check-proxy.ps1` | 探测本机可用代理端口，验证出口国家。Wayback / YouTube / Dailymotion 必须走代理 |
| `scripts/probe-bili.ps1` | 按昵称反查 mid、按 aid/bvid 查状态码、按 mid 拉稿件列表 |
| `scripts/probe-archive.ps1` | Wayback CDX 多 URL 变体查询，空结果本身就是证据 |
| `scripts/probe-platforms.ps1` | 关键词横扫 YouTube / 爱奇艺 / 优酷 / Dailymotion，其余平台标注为不可自动验证 |

```powershell
# 1. 确认代理
.\scripts\check-proxy.ps1

# 2. 认人 + 查状态
.\scripts\probe-bili.ps1 -Name "某个coser"
.\scripts\probe-bili.ps1 -Aid 68600774
.\scripts\probe-bili.ps1 -Mid 102570416

# 3. 查存档
.\scripts\probe-archive.ps1 -Aid 68600774 -Proxy http://127.0.0.1:7890

# 4. 扫平台
.\scripts\probe-platforms.ps1 -Keyword "某个名字" -Proxy http://127.0.0.1:7890
```

## 关键技术点

**绕开空间接口 412**：`x/space/arc/search` 返回 412、`x/space/wbi/arc/search` 返回 -352（连 wbi 签名都救不了，还要 buvid3 和一堆指纹参数）。改用：

```
x/series/recArchivesByKeywords?mid=MID&keywords=关键词
```

空关键词会被拦，必须带词；它只匹配**标题**，所以要循环多个词（`舞`、`cos`、`漫展`、`2020`）再按 bvid 去重。

**快照站捞元数据**：`jijidown.com/video/av<aid>` 这类站当年解析过，页面里嵌着一坨 JSON，能捞到 `btime`（发布时间）、`ltime`、`play/favos/coins`、`author`、`img`（封面）。封面 URL 在视频删除后常常仍然可下载，而封面是**图片反搜**的唯一入口——文本搜索全灭时的最后一张牌。

**YouTube 不用渲染**：直接请求 `results?search_query=`，HTML 里有 `ytInitialData`，正则摘 `videoRenderer` 即可。

**同名歧义必须排除**：中文/日文名字碰撞极严重。实践中同一个短名字同时指向过：在播动画的角色、日本 AV 女优、手办产品线、网文角色。每一个都能刷出几十条「看起来很像」的结果。

**微博号没了图还在**：`wxN.sinaimg.cn/{large|mw690|orj1080}/PICID.jpg` 不校验账号状态，随机 pic_id 返回 403 说明 CDN 只校验 ID 存在性。`pic_id` 可由 mid 经 base62 反算，所以**留有一条微博链接就够还原全部图片**；正文和评论不可恢复。

## 实测记录

在真实案例上跑通的路径：

- 一个 2019 年的 B 站视频：`-404`，快照站仍保留完整元数据（发布时间、播放 3980、收藏 297、封面可下载），B 站全站无搬运，Wayback 零存档 → 结论「公开渠道归零」
- 一位已退圈 coser：B 站只剩一个 0 粉 0 投的占位号，靠优酷聚合站的摘要片段翻出她另一支舞的标题和上传者 ID
- 一期被删视频：`62002 稿件不可见`，与「彻底删除」区分开后，建议路径从「挖缓存」改成「找 UP 主」

## 使用边界

- 只用于**定位和判断**，不提供破解、绕过鉴权、批量爬取受保护内容的能力
- 报告里「查过没有」和「查不了」必须分开写，这是这个工具存在的前提
- 涉及他人已退网的私人内容时，建议优先走公开存档，不建议私信打扰

## License

MIT
