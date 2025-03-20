# 打印当前的包库路径
print(.libPaths())

# 显式设置 R 包库路径
.libPaths("/home/runner/work/_temp/Library")

# 再次打印当前的包库路径
print(.libPaths())

# 列出已安装的包
print(installed.packages()[, "Package"])

# 加载 googlesheets4 包
library(googlesheets4)

# 从环境变量中获取服务账号 JSON 和 Google Sheet ID
json_key <- Sys.getenv("SHEET_KEY")
sheet_id <- Sys.getenv("SHEET_ID")

# 将 JSON 密钥写入文件
writeLines(json_key, "credentials.json")

# 设置 Google Sheets API 的认证
gs4_auth(path = "credentials.json")

# 读取 Google Sheet 的数据
data <- read_sheet(sheet_id, sheet = "Sheet1")

# 打印读取的数据
print(data)

# 清理：删除临时 JSON 文件
file.remove("credentials.json")
