# Bilibili Probe Cookbook

All endpoints below are GET, need no login, and work with a desktop Chrome user agent
plus `Referer: https://www.bilibili.com/`.

## Status of one submission

```
https://api.bilibili.com/x/web-interface/view?aid=68600774
https://api.bilibili.com/x/web-interface/view?bvid=BV1xx411c7mD
https://api.bilibili.com/x/player/pagelist?aid=68600774
https://api.bilibili.com/x/v2/reply?oid=68600774&type=1&pn=1&ps=5
```

Read `code` before anything else:

| code | message | meaning | can it come back |
|---|---|---|---|
| `0` | ok | online | n/a |
| `-404` | 啥都木有 | deleted, or the id never existed | only from caches/mirrors |
| `62002` | 稿件不可见 | exists but hidden: private, locked, or under review | **yes — the uploader can restore it** |
| `62012` | 仅UP主自己可见 | owner-only | uploader only |
| `12002` | 当前页面评论功能已关闭 | page torn down | no |
| `-352` | 风控校验失败 | needs a fully fingerprinted session | retry with a different endpoint |

`62002` versus `-404` is the single most useful distinction in this whole workflow.
`62002` means scraping is pointless but a one-line action by the creator fixes it.

## Locating a creator

```
https://search.bilibili.com/upuser?keyword=NAME
```
HTML is server-rendered enough that `space\.bilibili\.com/(\d+)` yields candidate mids.
Then confirm each one:

```
https://api.bilibili.com/x/web-interface/card?mid=325849670
https://api.bilibili.com/x/relation/stat?vmid=325849670
```

An empty or squatted id shows up as: `follower: 0`, `following: 1`, empty `sign`,
`face` ending in `noface.jpg`, and no uploads. Do not mistake it for the creator.
The space page title still renders the nickname, so page existence alone proves nothing —
only the card data does.

## Listing uploads when the space API is blocked

Both of these fail without a full cookie set:

```
x/space/arc/search?mid=...          -> HTTP 412
x/space/wbi/arc/search?mid=...      -> code -352 (even with a valid w_rid signature)
```

The wbi signature (`wts` + sorted params + mixin key from `x/web-interface/nav`) is not
sufficient on its own; buvid3, dm_img_list and the other fingerprint params are also
checked, and those rotate. Do not sink time into it.

Use the keyword endpoint instead:

```
https://api.bilibili.com/x/series/recArchivesByKeywords?mid=102570416&keywords=%E5%9C%88&ps=30&pn=1&orderby=pubdate
```

- Empty `keywords` is rejected (412). Always pass something.
- Returns `data.archives[]` with `bvid`, `title`, `pubdate`, `duration`.
- It matches on **title text only**, so a single keyword cannot enumerate everything.
  Loop over several likely words (`舞`, `cos`, `漫展`, `2020`, `2021`) and de-duplicate by bvid.
- Rate limiting starts around one request per second; sleep 600–800 ms between calls.

## Third-party snapshot sites

Sites that used to parse Bilibili while the video was alive keep a metadata record.
`https://jijidown.com/video/av68600774` embeds a JSON blob with:

| key | meaning |
|---|---|
| `btime` | publish timestamp (unix seconds) |
| `ltime` | last modification |
| `atime` | last access by the crawler |
| `upid` | uploader mid |
| `author` | uploader nickname at crawl time |
| `play` / `coins` / `favos` | view / coin / favourite counts |
| `img` | cover URL — **often still downloadable after deletion** |
| `subsort` | category |

Fetch the page and regex every `"key":value` pair. The metrics are what let you say
"nobody mirrored this, it was only ever worth 52 views" versus "297 favourites, someone
probably saved it".

The cover URL is worth keeping: `i0.hdslb.com/bfs/archive/<hash>.jpg` continues to serve
even for deleted submissions, and a visual reverse search on it is the last remaining lever.

## Deleted Weibo residue

A banned Weibo account keeps its images on the CDN. The URL form is:

```
https://wx1.sinaimg.cn/large/PICID.jpg
https://wx2.sinaimg.cn/mw690/PICID.jpg
https://wx3.sinaimg.cn/orj1080/PICID.jpg
```

`wx1`–`wx4` are interchangeable; the size segment is not. A random non-existent pic_id
returns 403, which confirms the CDN is checking id existence rather than account state.

`pic_id` is derivable from a Weibo `mid` via the documented base62 transform, so a single
surviving link to one post is enough to reconstruct every image in it. The post body and
comments are not recoverable once the account is gone — only the media.
