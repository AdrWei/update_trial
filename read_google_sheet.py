import gspread
from oauth2client.service_account import ServiceAccountCredentials

# 设置 Google Sheets API 的权限范围
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]

# 从环境变量中获取服务账号 JSON 和 Google Sheet ID
json_key = "credentials.json"  # 将 JSON 密钥文件写入本地文件
sheet_id = "your-google-sheet-id"  # 替换为你的 Google Sheet ID

# 加载服务账号的 JSON 密钥文件
creds = ServiceAccountCredentials.from_json_keyfile_name(json_key, scope)
client = gspread.authorize(creds)

# 打开 Google Sheet
sheet = client.open_by_key(sheet_id).sheet1

# 读取数据
data = sheet.get_all_records()

# 打印数据
print(data)
