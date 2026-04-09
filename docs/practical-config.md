# 嘸蝦米實用版 第一版

這一版的目標是：

- 保留嘸蝦米主輸入習慣
- 補常用短語
- 在正常候選中補精簡字根提示
- 啟用較完整的標點處理
- 補常用快捷切換

## 已加入

1. 常用短語詞庫
- 檔案：[liur_phrases.dict.yaml](/D:/APP/rime-liur-lua-master/liur_phrases.dict.yaml)
- 以低權重詞庫方式掛入，不覆蓋原生主字典

2. 精簡字根提示
- 檔案：[lua/liu_code_hint_filter.lua](/D:/APP/rime-liur-lua-master/lua/liu_code_hint_filter.lua)
- 正常輸入時，前段候選會補主碼提示
- 特殊模式如 `;;`、`;`、`,,`、`` ` `` 會自動略過
- 目前預設停用，原因是這層會增加每次候選產生的計算量，先以輸入流暢度優先

3. 標點強化
- 啟用 `punct_segmentor`、`punct_translator`、`punctuator`
- 使用小狼毫預設標點表，優先輸出中文標點與成對引號

4. 常用快捷切換
- `,,en`：切到英文
- `,,zh`：切回中文
- `,,wc`：切換查碼
- `,,ec`：切換擴充字集

## 目前為了效能暫停

- `related` 聯想排序
- `related` 即時學習 processor
- 內建 `predictor` / `predict_translator`
- `table_translator@phrases`
- 自定詞補全（僅保留自定詞精確命中）

原因：
- 這些模組都會參與每次按鍵後的候選重排
- 在目前這份方案與資料量下，優先保住主輸入與選字流暢度

## 原則

- 原生嘸蝦米字根仍是主體
- 自訂詞與短語只補缺，不搶主候選
- 字根提示只做精簡顯示，不等同完整反查模式
