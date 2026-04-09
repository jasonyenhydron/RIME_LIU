#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""將 LikeIME 的 custom / custom_user / related / emoji 匯入目前 Rime liur 專案。"""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path


CUSTOM_WORD_HEADER = """# Rime schema 中州輸入法的字碼檔
# encoding: utf-8
#
# 自定詞字典（由 lua_translator@liu_custom_word_translator 載入）
# 格式：詞條<Tab>編碼
#
---
name: openxiami_CustomWord
version: "1"
sort: original
...
# 人工編碼詞，適合超長句子，或包含數字的詞
# 自定詞會排在完整匹配漢字後面、補字候選前面
#
# 下方內容由 scripts/import_likeime_db.py 自動產生
"""

ROOT_WORD_HEADER = """# Rime schema 中州輸入法的字碼檔
# encoding: utf-8
#
# LikeIME custom 字根字典
# 格式：詞條<Tab>編碼
#
---
name: likeime_custom
version: "1"
sort: original
...
# 下方內容由 scripts/import_likeime_db.py 自動產生
"""

CUSTOM_USER_DIGIT_TRANSLATION = str.maketrans("0123456789", "versfwlcbk")
BASE_DICTIONARY_FILES = (
    "openxiami_TCJP.dict.yaml",
    "openxiami_TradExt.dict.yaml",
)


def escape_related_field(text: str) -> str:
    """將 related 匯出時可能破壞 TSV 的特殊字元轉義。"""
    return (
        text.replace("\\", "\\\\")
        .replace("\t", "\\t")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )


def normalize_custom_user_code(code: str) -> str:
    """將 custom_user 的數字字根轉成 liur 可用字母，避免輸出數字碼。"""
    normalized = code.replace("\r", "").replace("\n", "").replace("\t", "")
    return normalized.translate(CUSTOM_USER_DIGIT_TRANSLATION)


def load_existing_entries(dictionary_paths: tuple[Path, ...]) -> set[tuple[str, str]]:
    """載入主字典既有的 詞/碼 配對，避免重複寫入自定詞檔。"""
    entries: set[tuple[str, str]] = set()

    for path in dictionary_paths:
        if not path.exists():
            continue

        in_data = False
        for line in path.read_text(encoding="utf-8").splitlines():
            if line == "...":
                in_data = True
                continue
            if not in_data or not line or line.startswith("#"):
                continue

            parts = line.split("\t")
            if len(parts) < 2:
                continue

            word = parts[0].strip()
            code = parts[1].strip()
            if word and code:
                entries.add((word, code))

    return entries


def load_existing_single_char_codes(dictionary_paths: tuple[Path, ...]) -> set[str]:
    """載入主字典既有的單字碼，避免單字異體/簡繁條目重複寫入自定詞檔。"""
    codes: set[str] = set()

    for path in dictionary_paths:
        if not path.exists():
            continue

        in_data = False
        for line in path.read_text(encoding="utf-8").splitlines():
            if line == "...":
                in_data = True
                continue
            if not in_data or not line or line.startswith("#"):
                continue

            parts = line.split("\t")
            if len(parts) < 2:
                continue

            word = parts[0].strip()
            code = parts[1].strip()
            if len(word) == 1 and code:
                codes.add(code)

    return codes


def export_custom_user(conn: sqlite3.Connection, output_path: Path) -> int:
    """將 custom_user 的 code / word 匯出到 Rime 自定詞詞典。"""
    cur = conn.cursor()
    rows = cur.execute(
        """
        SELECT code, word, MAX(COALESCE(score, 0) + COALESCE(basescore, 0)) AS final_score
        FROM custom_user
        WHERE COALESCE(code, '') <> ''
          AND COALESCE(word, '') <> ''
        GROUP BY code, word
        ORDER BY code COLLATE NOCASE ASC, final_score DESC, word ASC
        """
    )

    existing_entries = load_existing_entries(
        tuple(Path(name) for name in BASE_DICTIONARY_FILES)
    )
    existing_single_char_codes = load_existing_single_char_codes(
        tuple(Path(name) for name in BASE_DICTIONARY_FILES)
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    count = 0

    with output_path.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(CUSTOM_WORD_HEADER)
        for code, word, _score in rows:
            normalized_word = str(word).replace("\r", " ").replace("\n", " ").replace("\t", " ")
            normalized_code = normalize_custom_user_code(str(code))
            if not normalized_word or not normalized_code or len(normalized_code) == 1:
                continue
            # 加詞檔只保留 5 碼內條目，避免過長自訂碼拖慢候選與污染主流程。
            if len(normalized_code) > 5:
                continue
            if len(normalized_word) <= 1:
                continue
            if (normalized_word, normalized_code) in existing_entries:
                continue
            if len(normalized_word) == 1 and normalized_code in existing_single_char_codes:
                continue
            fh.write(f"{normalized_word}\t{normalized_code}\n")
            count += 1

    return count


def export_custom(conn: sqlite3.Connection, output_path: Path) -> int:
    """將 custom 的 code / word 匯出到 Rime 字根詞典。"""
    cur = conn.cursor()
    rows = cur.execute(
        """
        SELECT code, word, MAX(COALESCE(score, 0) + COALESCE(basescore, 0)) AS final_score
        FROM custom
        WHERE COALESCE(code, '') <> ''
          AND COALESCE(word, '') <> ''
        GROUP BY code, word
        ORDER BY code COLLATE NOCASE ASC, final_score DESC, word ASC
        """
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    count = 0

    with output_path.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(ROOT_WORD_HEADER)
        for code, word, _score in rows:
            normalized_word = str(word).replace("\r", " ").replace("\n", " ").replace("\t", " ")
            normalized_code = str(code).replace("\r", "").replace("\n", "").replace("\t", "")
            if not normalized_word or not normalized_code:
                continue
            fh.write(f"{normalized_word}\t{normalized_code}\n")
            count += 1

    return count


def export_related(conn: sqlite3.Connection, output_path: Path) -> tuple[int, int]:
    """將 related 表匯出成 Lua filter 可讀取的 TSV。"""
    cur = conn.cursor()
    rows = cur.execute(
        """
        SELECT pword, cword, score, basescore
        FROM related
        WHERE COALESCE(pword, '') <> ''
          AND COALESCE(cword, '') <> ''
        ORDER BY pword ASC, score DESC, basescore DESC, cword ASC
        """
    )

    distinct_pwords = set()
    count = 0

    with output_path.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write("# LikeIME related export for Rime liur\n")
        fh.write("# pword\\tcword\\tscore\n")
        for pword, cword, score, basescore in rows:
            final_score = int(score or 0) + int(basescore or 0)
            fh.write(
                f"{escape_related_field(str(pword))}\t"
                f"{escape_related_field(str(cword))}\t"
                f"{final_score}\n"
            )
            distinct_pwords.add(str(pword))
            count += 1

    return count, len(distinct_pwords)


def export_emoji(emoji_db_path: Path, output_path: Path) -> tuple[int, int]:
    """將 emoji.db 匯出成 Lua translator 可讀取的 TSV。"""
    if not emoji_db_path.exists():
        return 0, 0

    conn = sqlite3.connect(str(emoji_db_path))
    try:
        cur = conn.cursor()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        row_count = 0
        value_count: set[str] = set()

        with output_path.open("w", encoding="utf-8", newline="\n") as fh:
            fh.write("# LikeIME emoji export for Rime liur\n")
            fh.write("# locale\\ttag\\tvalue\n")
            for locale in ("tw", "cn", "en"):
                rows = cur.execute(
                    f"""
                    SELECT tag, value
                    FROM {locale}
                    WHERE COALESCE(tag, '') <> ''
                      AND COALESCE(value, '') <> ''
                    ORDER BY tag ASC, value ASC
                    """
                )
                for tag, value in rows:
                    fh.write(
                        f"{locale}\t"
                        f"{escape_related_field(str(tag))}\t"
                        f"{escape_related_field(str(value))}\n"
                    )
                    row_count += 1
                    value_count.add(str(value))
    finally:
        conn.close()

    return row_count, len(value_count)


def main() -> int:
    """匯入 LikeIME 資料庫到目前工作區。"""
    parser = argparse.ArgumentParser(
        description="Import LikeIME custom_user and related tables into this Rime liur workspace."
    )
    parser.add_argument(
        "--db",
        default=r"D:\CODE\LIKEIME\DATA\lime.db",
        help="LikeIME SQLite database path.",
    )
    parser.add_argument(
        "--custom-out",
        default="openxiami_CustomWord.dict.yaml",
        help="Output path for the custom word dictionary.",
    )
    parser.add_argument(
        "--root-out",
        default="likeime_custom.dict.yaml",
        help="Output path for the LikeIME custom root dictionary.",
    )
    parser.add_argument(
        "--related-out",
        default="likeime_related.tsv",
        help="Output path for the related-word TSV.",
    )
    parser.add_argument(
        "--emoji-db",
        default=r"D:\CODE\LIKEIME\DATA\emoji.db",
        help="LikeIME emoji SQLite database path.",
    )
    parser.add_argument(
        "--emoji-out",
        default="likeime_emoji.tsv",
        help="Output path for the emoji TSV.",
    )
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"Database not found: {db_path}")

    conn = sqlite3.connect(str(db_path))
    try:
        root_count = export_custom(conn, Path(args.root_out))
        custom_count = export_custom_user(conn, Path(args.custom_out))
        related_count, pword_count = export_related(conn, Path(args.related_out))
    finally:
        conn.close()

    emoji_count, emoji_value_count = export_emoji(Path(args.emoji_db), Path(args.emoji_out))

    print(f"Exported {root_count} custom entries to {args.root_out}")
    print(f"Exported {custom_count} custom_user entries to {args.custom_out}")
    print(
        f"Exported {related_count} related rows across {pword_count} pwords to {args.related_out}"
    )
    print(
        f"Exported {emoji_count} emoji rows across {emoji_value_count} emojis to {args.emoji_out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
