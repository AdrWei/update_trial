# 加载库
library(httr)
library(jsonlite)
library(dplyr)
library(tidyr)

  tryCatch({
  ## 环境变量
  lifisher_codes <- Sys.getenv("LIFISHER_CODES")
  lifisher_token <- Sys.getenv("LIFISHER_TOKEN")
  lifisher_variables <- Sys.getenv("LIFISHER_VARIABLES")
  
  # 解析 JSON
  codes <- fromJSON(lifisher_codes)
  token_parts <- fromJSON(lifisher_token)
  constants <- fromJSON(lifisher_variables)
  
  # 提取 JSON 中的值
  USERNAME <- codes$USERNAME
  PASSWORD <- codes$PASSWORD
  APPKEY <- codes$APPKEY
  
  ## 重组 TOKEN
  TOKEN <- paste0(token_parts$Token_1, token_parts$Token_2, token_parts$Token_3, token_parts$Token_4)
  
  # 常量定义
  LOGIN_URL <- constants$LOGIN_URL
  DOMAIN <- constants$DOMAIN
  REFERER <- constants$REFERER
  SITE_ID <- constants$SITE_ID
  BASE_URL <- constants$BASE_URL   
}, error = function(e) {
  print(paste("Error:", e$message))
})

# 2. API 请求信息
PAGE_SIZE <- 200
MAX_PAGES <- 100  # 安全阈值，防止无限循环

# 3. 请求头配置
HEADERS <- add_headers(
  `User-Agent` = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  `appkey` = APPKEY,
  `token` = TOKEN,
  `domain` = DOMAIN,
  `Referer` = REFERER,
  `timestamp` = as.character(as.numeric(Sys.time()) * 1000)
)

# 4. 标题栏信息
WEB_INQUIRY_COLUMNS <- c('询盘时间', '国家', '公司名称', '联系人', '联系方式', '邮箱', '询盘内容', '跟进人')
SOCIAL_INQUIRY_COLUMNS <- c('询盘时间', '国家', '公司名称', '联系人', '联系方式', '邮箱', '询盘内容', '跟进人')

# 5. 正则表达式
EMAIL_REGEX <- "email: [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
PHONE_REGEX <- "phone number: \\+?[0-9]+"
CONTENT_REGEX <- "content: [^\n]+"
FULL_NAME_REGEX <- "full name: [^\n]+"
COMPANY_NAME_REGEX <- "company name: [^\n]+"

# 替换 janitor::remove_empty 函数
remove_empty <- function(df, which = "cols") {
  if (which == "cols") {
    df <- df[, colSums(!is.na(df) & df != "") > 0]
  } else if (which == "rows") {
    df <- df[rowSums(!is.na(df) & df != "") > 0, ]
  }
  return(df)
}

# 爬取数据 ----
# 1. 发送登录请求（GET 方法）
response <- GET(
  LOGIN_URL, config(ssl_verifypeer = FALSE),
  query = list(username = USERNAME, password = PASSWORD),
  user_agent("Mozilla/5.0")
)

# 2. 提取 Cookies 并转换为字符向量
cookies_vec <- cookies(response) |>
  paste(.$name, .$value, sep = "=")

# 3. 使用 Cookies 访问受保护页面
protected_page <- GET(
  "https://admin.lifisher.com/home/index",
  config(ssl_verifypeer = FALSE),
  set_cookies(cookies_vec),
  user_agent("Mozilla/5.0")
)

if (status_code(protected_page) != 200) {
  stop("访问受保护页面失败：", content(protected_page, "text"))
}

# 4. 分页获取所有数据
all_data <- data.frame()
for (page in 1:MAX_PAGES) {
  response <- GET(
    BASE_URL,
    query = list(is_junk = 0, site_id = SITE_ID, page_number = page, page_size = PAGE_SIZE),
    config = HEADERS
  )
  
  if (status_code(response) != 200) {
    stop("请求失败，状态码:", status_code(response))
  }
  
  res_data <- fromJSON(content(response, "text"))
  if (length(res_data$data) == 0) break
  
  all_data <- bind_rows(all_data, res_data$data)
  cat("成功获取第", page, "页，累计", nrow(all_data), "条记录\n")
  Sys.sleep(0.5)
}

# 询盘分类 ----
gsaData <- filter(all_data, source == "4")
orgData <- filter(all_data, source == "7")
fbTrans <- filter(all_data, source == "20")
NonFB <- bind_rows(gsaData, orgData, fbTrans)
fbData <- filter(all_data, source == "12")

# 非FB表单处理 ----
cleaned_df <- NonFB$custom_config |>
  map_df(~ {
    if (identical(dim(.x), c(0L, 0L))) {
      tibble(inquiry_id = NA_character_, title = NA_character_, content = NA_character_)
    } else {
      .x |>
        mutate(across(everything(), as.character)) |>
        select(inquiry_id, title, content)
    }
  }) |>
  pivot_wider(
    id_cols = inquiry_id,
    names_from = title,
    values_from = content,
    values_fn = ~ paste(na.omit(.), collapse = "|"),
    values_fill = NA
  ) |>
  mutate(
    company_name = coalesce(`Company Name`, company, Azienda, Bedrijf, Empresa, Firma, `Nom de la compagnie`, `Nome dell'azienda`, `Şirket Adı`, `اسم الشركة`, 公司名称, 회사, `회사 이름`),
    country = coalesce(country, Land, Paese, País, Kraj, 국가),
    phone = coalesce(phone, telefon, Telefono, Teléfono, telefoon, `Phone/WhatsApp/Skype`, `Telefono/WhatsApp/Skype`, `Telefon/WhatsApp/Skype`, `الهاتف/الواتساب/سكايب`, `电话/WhatsApp/Skype`, 전화, `전화/WhatsApp/Skype`, WhatsApp, Whatsapp, 왓츠앱),
    skype = coalesce(skype, Skype, `Skype'a`, Skypen, 스카이프)
  ) |>
  select(inquiry_id, company_name, country, phone, skype, everything()) |>
  remove_empty("cols") |>
  mutate(across(where(is.character), ~ na_if(., "")))

# 整理 NonFB 数据表格
WebInquiry <- NonFB |>
  select(create_time, ip_country, contacts, email, content, account_name) |>
  bind_cols(cleaned_df |> select(company_name, phone)) |>
  setNames(WEB_INQUIRY_COLUMNS) |>
  mutate(across(1, ~ as.POSIXct(.x, format = "%Y-%m-%d %H:%M:%S"))) |>
  arrange(1)

# 整理 FB 数据表格
SocialInquiry <- fbData |>
  mutate(
    email = str_extract(content, EMAIL_REGEX) |> str_remove("email: "),
    phone_number = str_extract(content, PHONE_REGEX) |> str_remove("phone number: "),
    content = str_extract(content, CONTENT_REGEX) |> str_remove("content: "),
    full_name = str_extract(content, FULL_NAME_REGEX) |> str_remove("full name: "),
    company_name = str_extract(content, COMPANY_NAME_REGEX) |> str_remove("company name: ")
  ) |>
  select(create_time, ip_country, company_name, full_name, phone_number, email, content, account_name) |>
  setNames(SOCIAL_INQUIRY_COLUMNS) |>
  mutate(across(1, ~ as.POSIXct(.x, format = "%Y-%m-%d %H:%M:%S"))) |>
  arrange(1)

# 保存数据
save(WebInquiry, SocialInquiry, file = "data.RData")
cat("\nWebInquiry 表格前 5 行：\n")
print(head(WebInquiry, 5))
