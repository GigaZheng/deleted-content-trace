---
name: deleted-content-trace
description: Traces deleted or hidden creator content across platforms. This skill should be used when a video, post, image set, or account was reportedly deleted, taken down, or abandoned, and the user wants to know what survives and where. It covers Bilibili av/BV/mid status probing, distinguishing deleted from private, pulling metadata out of third-party snapshot sites, sweeping YouTube iQiyi Youku AcFun Dailymotion and Niconico, querying Wayback CDX through a local proxy, triaging same-name collisions, and reporting honestly which channels are exhausted versus which require private access.
---

# Deleted Content Trace

## Purpose

Determine, with evidence, whether a specific piece of creator content still exists anywhere reachable after being deleted, hidden, or abandoned. The output is never "probably gone" — it is a per-channel verdict table plus a ranked list of channels that remain physically possible.

This skill exists because the honest answer is usually "public web is exhausted, only private caches remain", and reaching that conclusion defensibly requires checking a specific set of sources in a specific order.

## When to Use

- User reports a video or post was deleted and wants it recovered.
- User supplies an av/BV number, a title fragment, a creator name, or a store link from a third-party download site.
- User asks whether a creator "deleted their account and left the internet".
- User needs to know what residue remains after a Weibo ban or Bilibili account removal.

## Workflow

### Phase 1 — Pin down identity before searching

A creator name alone is almost always ambiguous. Resolve the identity first, or the entire sweep returns noise.

1. Search the platform user index: `https://search.bilibili.com/upuser?keyword=NAME`, regex out `space.bilibili.com/(\d+)`, then confirm each candidate via `x/web-interface/card?mid=`.
2. Check aliases and earlier names. Fans often address a creator by a shortened form found only in danmaku — read a local `danmaku.xml` if one exists.
3. Treat a candidate as invalid when the card returns follower 0, empty signature, `noface.jpg` avatar and no uploads. That is a squatted placeholder, not the creator.

Run `scripts/probe-bili.ps1 -Name NAME` to automate this step.

### Phase 2 — Establish the exact status of the original item

Never assume "deleted". Query and read the error code, because the recovery paths differ completely.

| Code | Message | Meaning | Recoverable? |
|---|---|---|---|
| `0` | ok | still online | just watch it |
| `-404` | 啥都木有 | gone, or never existed | only from caches |
| `62002` | 稿件不可见 | exists but not visible: private, locked, or under review | uploader only |
| `62012` | 仅UP主自己可见 | owner-only | uploader only |
| `12002` | 当前页面评论功能已关闭 | page torn down | gone |

`62002` is the important one. It means the object still exists server-side, so no amount of scraping will retrieve it — but the creator can flip it back with one click. Report that distinction explicitly; it changes what advice is useful.

Run `scripts/probe-bili.ps1 -Aid N` or `-Bvid BVxxx` to get the code plus a pagelist and comment probe.

### Phase 3 — Recover metadata from third-party snapshots

Even when the item is gone, download sites that parsed it while it was alive often still hold a full metadata record. `jijidown.com/video/av<aid>` is the most reliable example and exposes a JSON blob containing:

- `btime` (publish timestamp), `ltime` (last update), `atime`
- `play`, `coins`, `favos` (view/coin/favourite counts)
- `img` (cover URL — frequently still downloadable from the CDN even after deletion)
- `author`, `upid`, `subsort`

Fetch the page, regex out every `"key":value` pair, and rebuild the record. The cover URL alone is worth having: it can be re-searched visually, which is the only remaining lever when text search is exhausted.

### Phase 4 — Sweep platforms, knowing which are automatable

Run `scripts/probe-platforms.ps1 -Keyword TERM`. It covers the channels that actually respond to scripted requests. Do not claim a platform was checked if the script reports it as blocked — say "not verifiable from here".

### Phase 5 — Report and route

Produce a table with one row per channel and an explicit verdict. Then rank the remaining possibilities by realism. Typical ranking:

1. The user's own favourites, watch history, or local cache.
2. The uploader directly (only when `62002`; respect that many creators left deliberately).
3. Paid recovery services on second-hand marketplaces, given a complete identifier block.
4. Creator resource aggregators, when the content was commercial.
5. Visual reverse search on a surviving cover image.

For community archival posts, hand the user a ready-made identifier block: av/BV, cid, exact title, duration, quality, upload date, uploader, and any distinguishing content details.

## Critical Techniques

- **Bypass the 412 on the space API.** `x/space/arc/search` and `x/space/wbi/arc/search` both fail with `412` / `-352` without full fingerprint cookies. `x/series/recArchivesByKeywords?mid=X&keywords=K` returns `code:0` with an empty cookie and accepts any keyword, so loop over several keywords and de-duplicate by bvid. An empty keyword string is blocked, so always pass something.
- **Read `ytInitialData` instead of rendering YouTube.** `https://www.youtube.com/results?search_query=Q` returns HTML containing `"videoRenderer":{"videoId":...` followed by `"title":{"runs":[{"text":...`. Regex the pair; no JS needed.
- **Use the platform JSON endpoints rather than their search pages.** iQiyi: `mesh.if.iqiyi.com/portal/lw/search/homePageV3?key=Q`. Youku: `search.youku.com/api/search?keyword=Q`. Both return parsable JSON; the HTML pages are JS shells.
- **Wayback requires a proxy.** `web.archive.org` is unreachable directly from mainland networks. Probe a local proxy first, then query `http://web.archive.org/cdx/search/cdx?url=...&output=text`. An empty result is meaningful evidence that the URL was never archived.
- **Disambiguate names aggressively.** Japanese and Chinese entertainment names collide constantly. Confirm the entity from context (competition footage, venue, co-performers) before reporting anything, and state which homonyms were excluded.
- **Weibo images outlive the account.** `wxN.sinaimg.cn/{large|mw690|orj1080}/PICID.jpg` does not check account state. Legacy `pic_id` values still resolve years after a ban, so a surviving `pic_id` is a permanent asset while the post body is not.

## Bundled Resources

- `scripts/check-proxy.ps1` — probe common local proxy ports and verify the exit country.
- `scripts/probe-bili.ps1` — resolve a creator by name, or probe an aid/bvid, and print status codes, uploader info, and the upload list.
- `scripts/probe-archive.ps1` — Wayback CDX lookups across URL variants, through a proxy.
- `scripts/probe-platforms.ps1` — keyword sweep across the automatable video platforms.
- `references/platform-matrix.md` — which platform is automatable, which needs login, and why.
- `references/bili-api-cookbook.md` — exact endpoints, parameters, error codes, and the working keyword-bypass trick.
