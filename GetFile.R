library(httr)
library(jsonlite)
library(dplyr)
library(tidyr)

# 替换 janitor::remove_empty 函数
remove_empty <- function(df, which = "cols") {
  if (which == "cols") {
    df <- df[, colSums(!is.na(df) & df != "") > 0]
  } else if (which == "rows") {
    df <- df[rowSums(!is.na(df) & df != "") > 0, ]
  }
  return(df)
}

# 常量定义 ----
# 1. 登录信息
LOGIN_URL <- "https://admin.lifisher.com/api/login"
USERNAME <- "15077219088"
PASSWORD <- "15077219088"

# 3. API 请求信息
BASE_URL <- "https://api-qqt.weyescloud.com/jmc/inquiry/export"
SITE_ID <- 5735
PAGE_SIZE <- 200
MAX_PAGES <- 100  # 安全阈值，防止无限循环

# 4. 请求头配置
HEADERS <- add_headers(
  `User-Agent` = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  `appkey` = "man2oqlx6oqnf2wzhhrbarih2zlmoe7ckb00aec53knzelpw8ogc4g8ws880o00b",
  `token` = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJjb2QiOiI0MDYzLTg4NDc1Ni05Mzk3ODUtMTAzNjczOS0yMzY3NTciLCJ1c3IiOiIxNTA3NzIxOTA4OCIsImV4cCI6MTc0MzY2ODAzNSwiaWF0IjoxNzQyNDU4NDM1LCJqdGkiOiIwOWRmNGMycGx0OG44MDFxNHZzN2lnc2VrdSJ9.FcBKm5wDBL5ZP6_R15U9t2
