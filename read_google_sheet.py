import os
import requests
import pandas as pd
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import re
from datetime import datetime
import json

# 设置 Google Sheets API 的权限范围
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]

# 从环境变量中获取服务账号 JSON 和 Google Sheet ID
json_key = "credentials.json"  # 将 JSON 密钥文件写入本地文件
sheet_id = os.getenv("SHEET_ID")  # 从环境变量中获取 Google Sheet ID

# 加载服务账号的 JSON 密钥文件
creds = ServiceAccountCredentials.from_json_keyfile_name(json_key, scope)
client = gspread.authorize(creds)

# 打开 Google Sheet
try:
    sheet = client.open_by_key(sheet_id).sheet1
except gspread.exceptions.SpreadsheetNotFound as e:
    print(f"Error: Google Sheet not found. Please check the SHEET_ID.")
    raise
except Exception as e:
    print(f"Error: {e}")
    raise

TOKEN = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJjb2QiOiI0MDYzLTg4NDc1Ni05Mzk3ODUtMTAzNjczOS0yMzY3NTciLCJ1c3IiOiIxNTA3NzIxOTA4OCIsImV4cCI6MTc0MzY2ODAzNSwiaWF0IjoxNzQyNDU4NDM1LCJqdGkiOiIwOWRmNGMycGx0OG44MDFxNHZzN2lnc2VrdSJ9.FcBKm5wDBL5ZP6_R15U9t2wxZBvj4gyNa48zXTk77Ig"

# 常量定义
LOGIN_URL = "https://admin.lifisher.com/api/login"
USERNAME = "15077219088"
PASSWORD = "15077219088"
BASE_URL = "https://api-qqt.weyescloud.com/jmc/inquiry/export"
SITE_ID = 5735
PAGE_SIZE = 200
MAX_PAGES = 100
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "appkey": "man2oqlx6oqnf2wzhhrbarih2zlmoe7ckb00aec53knzelpw8ogc4g8ws880o00b",
    "token": TOKEN,
    "domain": "statistics.lifisher.com",
    "Referer": "https://statistics.lifisher.com/",
    "timestamp": str(int(datetime.now().timestamp() * 1000))
}

# 登录并获取 cookies
response = requests.get(LOGIN_URL, params={"username": USERNAME, "password": PASSWORD}, headers=HEADERS, verify=False)
cookies = response.cookies.get_dict()

# 分页获取所有数据
all_data = []
page = 1
has_more = True

while has_more and page <= MAX_PAGES:
    query = {
        "is_junk": 0,
        "site_id": SITE_ID,
        "page_number": page,
        "page_size": PAGE_SIZE
    }
    response = requests.get(BASE_URL, params=query, headers=HEADERS, cookies=cookies, verify=False)
    if response.status_code == 200:
        res_data = response.json()
        if res_data.get("data"):
            all_data.extend(res_data["data"])
            print(f"成功获取第 {page} 页，累计 {len(all_data)} 条记录")
            page += 1
        else:
            has_more = False
            print(f"第 {page} 页无数据，终止分页")
    else:
        raise Exception(f"请求失败，状态码: {response.status_code}")

# 将数据转换为 DataFrame
df = pd.DataFrame(all_data)

# 将 DataFrame 写入 Google Sheet
try:
    # 清空现有数据（可选）
    sheet.clear()

    # 写入表头
    sheet.update([df.columns.values.tolist()], 'A1')

    # 写入数据
    sheet.update(df.values.tolist(), 'A2')

    print("数据成功写入 Google Sheet！")
except Exception as e:
    print(f"写入 Google Sheet 时出错: {e}")
    raise

# 清理：删除临时 JSON 文件
os.remove("credentials.json")
