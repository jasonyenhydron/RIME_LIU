# 功能差異清單

本清單以目前這份 `liur` 小狼毫專案，相對於 LikeIME / 既有需求整理。

## 已完成

- `custom_user(code, word)` 匯入：已匯出到 [openxiami_CustomWord.dict.yaml](/D:/APP/rime-liur-lua-master/openxiami_CustomWord.dict.yaml)，可做加字加詞與自定詞補全。
- `related` 靜態匯入：已匯出到 [likeime_related.tsv](/D:/APP/rime-liur-lua-master/likeime_related.tsv)，供下一詞候選排序使用。
- `related` 即時學習：已在 [lua/liu_related_filter.lua](/D:/APP/rime-liur-lua-master/lua/liu_related_filter.lua) 補上上屏後學習，執行期會寫到 `likeime_related.user.tsv`。
- `emoji.db` 查詢：已透過 [scripts/import_likeime_db.py](/D:/APP/rime-liur-lua-master/scripts/import_likeime_db.py) 匯出 [likeime_emoji.tsv](/D:/APP/rime-liur-lua-master/likeime_emoji.tsv)，並由 [lua/liu_emoji_translator.lua](/D:/APP/rime-liur-lua-master/lua/liu_emoji_translator.lua) 提供 `,,e` 查詢。
- 小狼毫同步流程：已補 [scripts/sync_to_weasel_user.ps1](/D:/APP/rime-liur-lua-master/scripts/sync_to_weasel_user.ps1)，會把 YAML、TSV、DB、Lua、OpenCC 一起同步到 `AppData\Rime`。
- 預測輸入：已開啟 `predictor` / `predict_translator`，並同步 `predict.db`。
- 候選排序修正：候選分組後仍依原始 quality 排序，避免冷門字被 Lua 分組順序頂到前面。

## 可補

- `emoji.db` 中文標籤查詢：目前 `,,e` 先走英文 tag 查詢；若要支援中文關鍵字，需再設計可輸入中文查詢字串的模式。
- `related` 學習衰退與整理：目前即時學習是累加寫入 user TSV，後續可再補定期壓縮、去重、衰退策略。
- `related` 多字詞學習：目前會學完整上屏詞與最後一字 fallback；若要更像手機輸入法，可再補詞組切分與多粒度學習。
- `emoji` 候選註解優化：目前以英文 tag 顯示 comment，可再補繁中標籤摘要或分類。
- 匯入統計報表：可在匯入後自動把 custom/related/emoji 筆數寫進 Markdown 報告。

## 不建議補

- 直接在 librime-lua 內開 SQLite 查 `lime.db` / `emoji.db`：部署、權限與相依性都更脆弱，改成預先匯出 TSV 比較穩。
- 把 `related` 即時學習直接回寫原始 [likeime_related.tsv](/D:/APP/rime-liur-lua-master/likeime_related.tsv)：會混淆靜態匯入資料與執行期學習資料，不利版本控管。
- 讓所有候選都顯示聯想標記：會污染正常選字介面，且已被證實容易造成誤判與混淆。
