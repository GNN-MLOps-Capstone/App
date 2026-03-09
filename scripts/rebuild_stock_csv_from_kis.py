#!/usr/bin/env python3
"""
KIS 마스터(kospi/kosdaq/konex) 기준으로 App CSV를 재생성한다.

생성 파일:
- App/lib/screens/name.csv
- App/lib/screens/stock_list.csv
"""

from __future__ import annotations

import csv
import re
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path


SHORT_CODE_RE = re.compile(r"^[0-9A-Z]{6}$")
ISIN_RE = re.compile(r"^KR[0-9A-Z]{10}$")

MASTER_SOURCES = [
    ("KOSPI", "https://new.real.download.dws.co.kr/common/master/kospi_code.mst.zip", "kospi_code.mst", 228),
    ("KOSDAQ", "https://new.real.download.dws.co.kr/common/master/kosdaq_code.mst.zip", "kosdaq_code.mst", 222),
    ("KONEX", "https://new.real.download.dws.co.kr/common/master/konex_code.mst.zip", "konex_code.mst", 184),
]


def _download_and_extract(url: str, expected_mst: str, dst_dir: Path) -> Path:
    zip_path = dst_dir / f"{expected_mst}.zip"
    urllib.request.urlretrieve(url, zip_path)
    with zipfile.ZipFile(zip_path, "r") as zf:
        names = zf.namelist()
        target = expected_mst if expected_mst in names else None
        if target is None:
            target = next((n for n in names if n.lower().endswith(".mst")), None)
        if target is None:
            raise RuntimeError(f"mst file not found in {url}")
        zf.extract(target, dst_dir)
        return dst_dir / target


def _iter_master_rows(path: Path, market: str, tail_len: int):
    with path.open("r", encoding="cp949", errors="ignore") as f:
        for raw in f:
            line = raw.rstrip("\r\n")
            if not line:
                continue

            if market == "KONEX":
                if len(line) <= 21 + tail_len:
                    continue
                short_code = line[0:9].strip()
                isin = line[9:21].strip()
                name = line[21:-tail_len].strip()
            else:
                if len(line) <= 21 + tail_len:
                    continue
                front = line[:-tail_len]
                short_code = front[0:9].strip()
                isin = front[9:21].strip()
                name = front[21:].strip()

            if not SHORT_CODE_RE.fullmatch(short_code):
                continue
            if not ISIN_RE.fullmatch(isin):
                continue
            if not name:
                continue

            yield {
                "name": name,
                "market": market,
                "isu_cd": isin,
                "short_code": short_code,
            }


def _load_alias_by_isin(stock_list_path: Path) -> dict[str, str]:
    alias_by_isin: dict[str, str] = {}
    if not stock_list_path.exists():
        return alias_by_isin

    with stock_list_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) < 2:
                continue
            if row[0].strip() == "한글명":
                continue
            alias = row[1].strip()
            isin = next(
                (cell.strip().upper() for cell in row if ISIN_RE.fullmatch(cell.strip().upper())),
                "",
            )
            if ISIN_RE.fullmatch(isin) and alias and isin not in alias_by_isin:
                alias_by_isin[isin] = alias.replace(",", "/")
    return alias_by_isin


def rebuild(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    name_csv_path = out_dir / "name.csv"
    stock_list_csv_path = out_dir / "stock_list.csv"

    alias_by_isin = _load_alias_by_isin(stock_list_csv_path)
    records_by_code: dict[str, dict[str, str]] = {}

    with tempfile.TemporaryDirectory(prefix="kis-master-") as td:
        work = Path(td)
        for market, url, mst_name, tail_len in MASTER_SOURCES:
            mst_path = _download_and_extract(url, mst_name, work)
            for rec in _iter_master_rows(mst_path, market, tail_len):
                # 단축코드 충돌 시 먼저 들어온 시장(KOSPI->KOSDAQ->KONEX) 우선.
                records_by_code.setdefault(rec["short_code"], rec)

    records = sorted(records_by_code.values(), key=lambda x: (x["market"], x["short_code"]))

    tmp_name = name_csv_path.with_suffix(".tmp")
    with tmp_name.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Name", "Market", "ISU_CD", "SHORT_CODE"])
        for r in records:
            writer.writerow([r["name"], r["market"], r["isu_cd"], r["short_code"]])
    shutil.move(tmp_name, name_csv_path)

    tmp_stock = stock_list_csv_path.with_suffix(".tmp")
    with tmp_stock.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["한글명", "추가명", "종목코드", "표준코드", "시장"])
        for r in sorted(records, key=lambda x: x["name"]):
            alias = alias_by_isin.get(r["isu_cd"], "")
            writer.writerow([r["name"], alias, r["short_code"], r["isu_cd"], r["market"]])
    shutil.move(tmp_stock, stock_list_csv_path)

    print(f"Done: {len(records)} symbols")
    print(f"- {name_csv_path}")
    print(f"- {stock_list_csv_path}")


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[1]
    rebuild(repo_root / "lib" / "screens")
