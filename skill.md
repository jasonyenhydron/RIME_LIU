# skill.md

本檔作為這個專案的維護規範與操作提示，後續修改前先讀這份。

## 專案定位

- 這是 Windows 小狼毫的 Rime `liur` 嘸蝦米設定專案
- 主要維護目標是穩定輸入、可持續匯入 LikeIME 資料、避免把個人執行期檔案誤提交

## 修改原則

- 先看現況檔案引用關係，再改設定或刪檔
- 需求不明確時先釐清，再下手改
- 不隨意刪除 `build` 以外仍被 schema 引用的詞典或 Lua
- 不覆蓋使用者自己的 `user.yaml`、`*.userdb`、同步資料

## 程式與設定修改流程

1. 先確認需求影響的檔案
2. 修改 schema、Lua、詞典或匯入腳本
3. 在沙盒內先做語法或指令層級檢查
4. 若影響輸入法行為，執行小狼毫重新佈署
5. 更新相關 Markdown 說明
6. 用中文 commit 訊息提交

## 常用檔案

- 主方案：[liur.schema.yaml](/D:/APP/rime-liur-lua-master/liur.schema.yaml)
- 編譯後方案：[build/liur.schema.yaml](/D:/APP/rime-liur-lua-master/build/liur.schema.yaml)
- Lua 入口：[rime.lua](/D:/APP/rime-liur-lua-master/rime.lua)
- 自定詞詞典：[openxiami_CustomWord.dict.yaml](/D:/APP/rime-liur-lua-master/openxiami_CustomWord.dict.yaml)
- LikeIME 聯想：[likeime_related.tsv](/D:/APP/rime-liur-lua-master/likeime_related.tsv)
- 匯入腳本：[scripts/import_likeime_db.py](/D:/APP/rime-liur-lua-master/scripts/import_likeime_db.py)

## LikeIME 匯入規則

- DB 路徑預設：`D:\CODE\LIKEIME\DATA\lime.db`
- `custom_user(code, word)` 匯入到自定詞詞典
- `related(pword, cword)` 匯出為 TSV，供 Lua filter 排序候選
- 匯入完成後要重新佈署，否則小狼毫不會吃到新資料

## 提交規則

- commit 訊息使用臺灣繁體中文
- 只提交這次需求實際相關檔案
- 避免把 `user.yaml`、多餘 `build/*.yaml` 時間戳變更、暫存檔一起提交

## 可再加強的規範

- 可補一份 `docs/maintenance.md` 記錄清理策略
- 可補一份 `docs/release-checklist.md` 記錄每次修改後的檢查項目
- 可把匯入後的筆數統計自動寫進 Markdown

## 文件更新後固定流程

- 更新 `*.md` 後，若需交付，先 `git commit`、再 `git push`
- push 完成後執行 [scripts/build_release_package.ps1](/D:/APP/rime-liur-lua-master/scripts/build_release_package.ps1) 產生安裝包
- 再執行 [scripts/deploy_weasel.ps1](/D:/APP/rime-liur-lua-master/scripts/deploy_weasel.ps1) 重新安裝到 `AppData\Rime`
- `deploy_weasel.ps1` 會自動停止並重新啟動 `WeaselServer`

