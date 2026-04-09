# LikeIME 匯入說明

## 匯入內容

- `custom(code, word)` 會匯入到 `likeime_custom.dict.yaml`
- `custom_user(code, word)` 會匯入到 `openxiami_CustomWord.dict.yaml`
- `custom_user` 只匯入大於 1 個字的詞，單字不寫入加詞檔
- `custom_user` 的數字字根會在匯入時轉成 `0123456789 -> versfwlcbk`
- `custom_user` 若轉換後只剩 1 碼，會直接略過，不匯入 `openxiami_CustomWord.dict.yaml`
- `custom_user` 若轉換後超過 5 碼，也會直接略過，不匯入 `openxiami_CustomWord.dict.yaml`
- `custom_user` 若詞/碼已存在於 `openxiami_TCJP.dict.yaml` 或 `openxiami_TradExt.dict.yaml`，也會直接略過
- `custom_user` 若是單字，且字碼在主字典已存在，也會略過，避免單字異體或簡繁條目重複匯入
- `related(pword, cword)` 會匯出到 `likeime_related.tsv`
- `emoji.db` 會匯出到 `likeime_emoji.tsv`

## 執行方式

在專案根目錄執行：

```powershell
python .\scripts\import_likeime_db.py
```

預設資料來源：

```text
D:\CODE\LIKEIME\DATA\lime.db
D:\CODE\LIKEIME\DATA\emoji.db
```

## 生效方式

1. 匯入完成後重新部署小狼毫
2. `custom` 會成為 LikeIME 補充字根候選
3. `custom_user` 會成為 liur 自定詞候選
4. `related` 會依上一個上屏詞提升相關候選排序，並將即時學習寫入 `likeime_related.user.tsv`
5. `emoji.db` 會提供 `,,e` 英文標籤查詢，例如 `,,esmile`

## 補充

- `likeime_custom.dict.yaml` 是由 `custom` 匯出的字根檔
- `likeime_related.tsv` 是靜態匯入資料
- `likeime_related.user.tsv` 是小狼毫執行時逐步學到的關聯資料
- `likeime_emoji.tsv` 是由 `emoji.db` 匯出的查詢資料

## 一鍵部署

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_likeime_data.ps1
```

## 備份資料庫補匯入

若要從其他備份 `lime.db` 只補「主字典沒有的多字詞」到加字加詞檔，可執行：

```powershell
python .\scripts\import_backup_db_missing_words.py --db "D:\jason.yen\Downloads\backup (7)\databases\lime.db"
```

這支腳本會：

- 同時讀 `custom` 與 `custom_user`
- 排除主字典已存在的詞
- 排除單字
- 保留超長句
- 自動整理折行、Tab、重複空白
- 把數字碼轉成 `0123456789 -> versfwlcbk`
