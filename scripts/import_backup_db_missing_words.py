#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""從指定的 lime.db 匯入主字典沒有的多字詞到 openxiami_CustomWord.dict.yaml。"""

from __future__ import annotations

import argparse
import re
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
# 下方內容由 scripts/import_backup_db_missing_words.py 自動產生
"""

BASE_DICTIONARY_FILES = (
    "openxiami_TCJP.dict.yaml",
    "openxiami_TradExt.dict.yaml",
)

DIGIT_TRANSLATION = str.maketrans("0123456789", "versfwlcbk")


def normalize_word(text: str) -> str:
    """把換行、Tab、重複空白整理成單一空白，保留特殊符號本身。"""
    normalized = str(text).replace("\ufeff", "").replace("\x00", "")
    normalized = normalized.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    normalized = re.sub(r"\s+", " ", normalized)
    return normalized.strip()


def normalize_code(code: str) -> str:
    """整理編碼並把數字碼轉成目前 liur 可用字母碼。"""
    normalized = str(code).replace("\ufeff", "").replace("\x00", "")
    normalized = normalized.replace("\r", "").replace("\n", "").replace("\t", "").strip().lower()
    return normalized.translate(DIGIT_TRANSLATION)


def load_base_words(dictionary_paths: tuple[Path, ...]) -> set[str]:
    """載入主字典所有既有詞條，用來排除原本嘸蝦米已經有的詞。"""
    words: set[str] = set()

    for path in dictionary_paths:
        if not path.exists():
            continue

        in_data = False
        for line in path.read_text(encoding="utf-8").splitlines():
            if line == "...":
                in_data = True
                continue
            if not in_data or not line or line.startswith("#") or "\t" not in line:
                continue

            word = line.split("\t", 1)[0].strip()
            if word:
                words.add(word)

    return words


def collect_missing_multi_words(
    conn: sqlite3.Connection,
    base_words: set[str],
    tables: tuple[str, ...],
) -> list[tuple[str, str, str]]:
    """蒐集主字典沒有的多字詞，回傳 (table, word, code) 清單。"""
    collected: list[tuple[str, str, str]] = []
    seen_pairs: set[tuple[str, str]] = set()

    for table in tables:
        rows = conn.execute(
            f"""
            SELECT code, word, MAX(COALESCE(score, 0) + COALESCE(basescore, 0)) AS final_score
            FROM {table}
            WHERE COALESCE(code, '') <> ''
              AND COALESCE(word, '') <> ''
            GROUP BY code, word
            ORDER BY code COLLATE NOCASE ASC, final_score DESC, word ASC
            """
        )

        for code, word, _score in rows:
            normalized_word = normalize_word(word)
            normalized_code = normalize_code(code)

            if not normalized_word or not normalized_code:
                continue
            if len(normalized_word) <= 1:
                continue
            if normalized_word in base_words:
                continue

            pair = (normalized_word, normalized_code)
            if pair in seen_pairs:
                continue

            seen_pairs.add(pair)
            collected.append((table, normalized_word, normalized_code))

    collected.sort(key=lambda item: (item[2], item[1], item[0]))
    return collected


def write_custom_word_dict(output_path: Path, entries: list[tuple[str, str, str]]) -> None:
    """輸出成 Rime 可直接載入的加字加詞檔。"""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(CUSTOM_WORD_HEADER)
        for _table, word, code in entries:
            fh.write(f"{word}\t{code}\n")


def main() -> int:
    """將指定備份資料庫中主字典沒有的多字詞匯入加字加詞檔。"""
    parser = argparse.ArgumentParser(
        description="Import multi-word items missing from base dictionaries into openxiami_CustomWord.dict.yaml."
    )
    parser.add_argument(
        "--db",
        default=r"D:\jason.yen\Downloads\backup (7)\databases\lime.db",
        help="來源 lime.db 路徑。",
    )
    parser.add_argument(
        "--out",
        default="openxiami_CustomWord.dict.yaml",
        help="輸出的加字加詞檔路徑。",
    )
    parser.add_argument(
        "--tables",
        default="custom,custom_user",
        help="要匯入的資料表，逗號分隔。",
    )
    args = parser.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"Database not found: {db_path}")

    tables = tuple(item.strip() for item in args.tables.split(",") if item.strip())
    if not tables:
        raise SystemExit("No tables specified.")

    base_words = load_base_words(tuple(Path(name) for name in BASE_DICTIONARY_FILES))

    conn = sqlite3.connect(str(db_path))
    try:
        entries = collect_missing_multi_words(conn, base_words, tables)
    finally:
        conn.close()

    write_custom_word_dict(Path(args.out), entries)

    custom_count = sum(1 for table, _, _ in entries if table == "custom")
    custom_user_count = sum(1 for table, _, _ in entries if table == "custom_user")

    print(f"Exported {len(entries)} multi-word entries to {args.out}")
    print(f"custom={custom_count}")
    print(f"custom_user={custom_user_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
