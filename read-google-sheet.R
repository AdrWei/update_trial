library(googlesheets4)
library(jsonlite)

# 从环境变量中读取 JSON 密钥和 Google Sheet ID
sheet_key <- Sys.getenv("SHEET_KEY")
sheet_id <- Sys.getenv("SHEET_ID")

# 将 JSON 密钥写入临时文件
json_path <- tempfile(fileext = ".json")
write(sheet_key, json_path)

# 使用 Service Account 进行认证
gs4_auth(path = json_path, cache = FALSE)

# 读取 Google Sheet 的内容
data <- read_sheet(sheet_id, sheet = "Sheet1")  # 读取数据

# 打印数据
print(data)
