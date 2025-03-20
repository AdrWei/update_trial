import os
import pandas as pd
import gspread
from oauth2client.service_account import ServiceAccountCredentials

# 设置 Google Sheets API 的权限范围
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]

# 从环境变量中获取服务账号 JSON 和 Google Sheet ID
json_key = "credentials.json"  # 将 JSON 密钥文件写入本地文件
sheet_id = os.getenv("SHEET_ID")  # 从环境变量中获取 Google Sheet ID

# 加载服务账号的 JSON 密钥文件
creds = ServiceAccountCredentials.from_json_keyfile_name(json_key, scope)
client = gspread.authorize(creds)

# 读取 R 生成的表
orderWeb = pd.read_csv("orderWeb.csv")  # 假设 R 程序将表保存为 CSV 文件
orderSocial = pd.read_csv("orderSocial.csv")

# 打开 Google Sheet
try:
    # 获取 Google Sheet
    spreadsheet = client.open_by_key(sheet_id)

    # 写入 orderWeb 到第一个工作表
    try:
        sheet = spreadsheet.worksheet("orderWeb")  # 尝试获取名为 "orderWeb" 的工作表
    except gspread.exceptions.WorksheetNotFound:
        sheet = spreadsheet.add_worksheet(title="orderWeb", rows=100, cols=20)  # 如果不存在，创建新工作表
    sheet.clear()  # 清空现有数据
    sheet.update([orderWeb.columns.values.tolist()] + orderWeb.values.tolist())  # 写入表头和数据

    # 写入 orderSocial 到第二个工作表
    try:
        sheet = spreadsheet.worksheet("orderSocial")  # 尝试获取名为 "orderSocial" 的工作表
    except gspread.exceptions.WorksheetNotFound:
        sheet = spreadsheet.add_worksheet(title="orderSocial", rows=100, cols=20)  # 如果不存在，创建新工作表
    sheet.clear()  # 清空现有数据
    sheet.update([orderSocial.columns.values.tolist()] + orderSocial.values.tolist())  # 写入表头和数据

    print("数据成功写入 Google Sheet！")
except gspread.exceptions.SpreadsheetNotFound as e:
    print(f"Error: Google Sheet not found. Please check the SHEET_ID.")
    raise
except Exception as e:
    print(f"Error: {e}")
    raise
