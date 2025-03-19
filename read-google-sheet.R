library(googledrive)
library(googlesheets4)

# 使用 JSON 文件进行身份验证
gs4_auth(path = "service-account.json", cache = FALSE)

# 替换为你的 Google Sheet URL
sheet_url <- "15fvhsXjQY72CgVJ6DIT-IXEw6vjSIEhfHnuTSppocW0"

# 读取 Google Sheet
sheet_data <- read_sheet(sheet_url)

# 将数据保存为 CSV 文件
write.csv(sheet_data, "output.csv", row.names = FALSE)
