# Platform Capability Matrix

Measured November 2026 from a Windows host with a local HTTP proxy available at `127.0.0.1:7890`.
"Automatable" means a plain `curl`/`Invoke-RestMethod` call returns usable data with no login.

| Platform | Automatable | Endpoint | Needs proxy | Notes |
|---|---|---|---|---|
| Bilibili | yes | `api.bilibili.com/x/...` | no | Error-code semantics are the core signal, see the cookbook |
| Wayback (CDX) | yes | `web.archive.org/cdx/search/cdx` | **yes** | Stores HTML only; media files are almost never captured |
| YouTube | yes | `www.youtube.com/results?search_query=` | **yes** | Parse `ytInitialData`; no JS rendering needed |
| iQiyi | yes | `mesh.if.iqiyi.com/portal/lw/search/homePageV3?key=` | no | Clean JSON, returns short-video results too |
| Youku | partial | `search.youku.com/api/search?keyword=` | no | Returns JSON but the result schema is unstable; payload under 800 bytes means no hits |
| Dailymotion | yes | `api.dailymotion.com/videos?search=` | **yes** | Public REST, no key |
| AcFun | no | `rest/pc-direct/search` returns 404 unsigned | no | JS-rendered site; search by hand |
| Niconico | no | `api.search.nicovideo.jp` behind CloudFront | **yes** | Blocks datacenter IPs with 403 |
| Douyin / Kuaishou / Xiaohongshu / Weibo | no | requires signed-in session + request signing | — | Manual only |
| TikTok / Instagram / X | no | requires signed-in session | **yes** | Manual only |

## Reporting rule

Never write "checked platform X, nothing found" for a platform in the *no* rows.
Write "not verifiable from here, try the keyword manually". The difference between
"searched and empty" and "could not search" is the whole value of the report.

## Same-name collision triage

Chinese and Japanese entertainment names collide heavily. Before reporting a candidate,
confirm at least one independent anchor: a competition listing, a venue, a co-performer,
a distinctive subtitle string, or a physical description that matches the source.

Documented collisions encountered in practice for a single two-character surname plus given name:

- an anime character (same surname, given name from a currently airing show)
- a JAV actress with an identical romanised name
- a figurine product line using the same name
- a martial-arts novel character with the same two characters

Each produced dozens of confident-looking search hits that had to be discarded.
