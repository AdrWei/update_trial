import os
import pandas as pd
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import rpy2.robjects as ro
from rpy2.robjects import pandas2ri

# 激活 R 到 Pandas 的转换
pandas2ri.activate()

# 运行 R 脚本
ro.r('source("GetFile.R")')

# 获取 R 数据
orderWeb = ro.r('orderWeb')
orderSocial = ro.r('orderSocial')

# 将 R 数据转换为 Pandas DataFrame
df_web = pandas2ri.ri2py(orderWeb)
df_social = pandas2ri.ri2py(orderSocial)

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
    # 获取 Google Sheet
    spreadsheet = client.open_by_key(sheet_id)

    # 处理 orderWeb 工作表
    try:
        sheet = spreadsheet.worksheet("orderWeb")
    except gspread.exceptions.WorksheetNotFound:
        sheet = spreadsheet.add_worksheet(title="orderWeb", rows=100, cols=20)
    sheet.clear()
    sheet.update([df_web.columns.values.tolist()] + df_web.values.tolist())

    # 处理 orderSocial 工作表
    try:
        sheet = spreadsheet.worksheet("orderSocial")
    except gspread.exceptions.WorksheetNotFound:
        sheet = spreadsheet.add_worksheet(title="orderSocial", rows=100, cols=20)
    sheet.clear()
    sheet.update([df_social.columns.values.tolist()] + df_social.values.tolist())

    print("数据成功写入 Google Sheet！")
except gspread.exceptions.SpreadsheetNotFound as e:
    print(f"Error: Google Sheet not found. Please check the SHEET_ID.")
    raise
except Exception as e:
    print(f"Error: {e}")
    raise
