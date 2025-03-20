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

# 询盘分类
gsaData = df[df['source'] == '4']
orgData = df[df['source'] == '7']
fbTrans = df[df['source'] == '20']
NonFB = pd.concat([gsaData, orgData, fbTrans])
fbData = df[df['source'] == '12']

# 非FB表单处理
gtitle = NonFB['custom_config'].apply(lambda x: x['title'] if x else None)
all_titles = gtitle.dropna().unique()
result_list = all_titles.tolist()

# 动态获取所有标题
all_titles = list(set(result_list + [col for col in df.columns if col not in result_list]))
all_titles = sorted([title for title in all_titles if title])

# 转换为宽格式
final_df = NonFB.explode('custom_config').pivot(index='inquiry_id', columns='custom_config', values='content')

# 清理合并内容
cleaned_df = final_df.assign(
    company_name=final_df[['Company Name', 'company', 'Azienda', 'Bedrijf', 'Empresa', 'Firma', 'Nom de la compagnie', 'Nome dell\'azienda', 'Şirket Adı', 'اسم الشركة', '公司名称', '회사', '회사 이름']].bfill(axis=1).iloc[:, 0],
    country=final_df[['country', 'Land', 'Paese', 'País', 'Kraj', '국가']].bfill(axis=1).iloc[:, 0],
    phone=final_df[['phone', 'telefon', 'Telefono', 'Teléfono', 'telefoon', 'Phone/WhatsApp/Skype', 'Telefono/WhatsApp/Skype', 'Telefon/WhatsApp/Skype', 'الهاتف/الواتساب/سكايب', '电话/WhatsApp/Skype', '전화', '전화/WhatsApp/Skype', 'WhatsApp', 'Whatsapp', '왓츠앱']].bfill(axis=1).iloc[:, 0],
    skype=final_df[['skype', 'Skype', 'Skype\'a', 'Skypen', '스카이프']].bfill(axis=1).iloc[:, 0]
).reset_index()

# 整理新的NonFB数据表格
WebInquiry = pd.DataFrame({
    '询盘时间': NonFB['create_time'],
    '国家': NonFB['ip_country'],
    '公司名称': cleaned_df['company_name'],
    '联系人': NonFB['contacts'],
    '联系方式': cleaned_df['phone'],
    '邮箱': NonFB['email'],
    '询盘内容': NonFB['content'],
    '跟进人': NonFB['account_name']
})

# 整理新的FB数据表格
info = fbData['content']
email = info.str.extract(r'email: ([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})')[0]
phone_number = info.str.extract(r'phone number: (\+?[0-9]+)')[0]
content = info.str.extract(r'content: ([^\n]+)')[0]
full_name = info.str.extract(r'full name: ([^\n]+)')[0]
company_name = info.str.extract(r'company name: ([^\n]+)')[0]

SocialInquiry = pd.DataFrame({
    '询盘时间': fbData['create_time'],
    '国家': fbData['ip_country'],
    '公司名称': company_name,
    '联系人': full_name,
    '联系方式': phone_number,
    '邮箱': email,
    '询盘内容': content,
    '跟进人': fbData['account_name']
})

# 按时间顺序排列
WebInquiry['询盘时间'] = pd.to_datetime(WebInquiry['询盘时间'])
SocialInquiry['询盘时间'] = pd.to_datetime(SocialInquiry['询盘时间'])
orderWeb = WebInquiry.sort_values(by='询盘时间')
orderSocial = SocialInquiry.sort_values(by='询盘时间')

# 将数据写入 Google Sheets
sheet.update([orderWeb.columns.values.tolist()] + orderWeb.values.tolist(), 'A1')
sheet.update([orderSocial.columns.values.tolist()] + orderSocial.values.tolist(), 'A' + str(len(orderWeb) + 2))

# 清理：删除临时 JSON 文件
os.remove("credentials.json")
