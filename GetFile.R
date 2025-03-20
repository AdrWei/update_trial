library(httr)
library(jsonlite)
library(openxlsx)
library(tidyverse)
library(janitor)

# 常量定义 ----
# 1. 登录信息
LOGIN_URL <- "https://admin.lifisher.com/api/login"
USERNAME <- "15077219088"
PASSWORD <- "15077219088"

# 2. 数据导出路径
OUTPUT_FILE <- "广告统计.xlsx"

# 3. API 请求信息
BASE_URL <- "https://api-qqt.weyescloud.com/jmc/inquiry/export"
SITE_ID <- 5735
PAGE_SIZE <- 200
MAX_PAGES <- 100  # 安全阈值，防止无限循环

# 4. 请求头配置
HEADERS <- add_headers(
  `User-Agent` = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  `appkey` = "man2oqlx6oqnf2wzhhrbarih2zlmoe7ckb00aec53knzelpw8ogc4g8ws880o00b",
  `token` = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJjb2QiOiI0MDYzLTg4NDc1Ni05Mzk3ODUtMTAzNjczOS0yMzY3NTciLCJ1c3IiOiIxNTA3NzIxOTA4OCIsImV4cCI6MTc0MzY2ODAzNSwiaWF0IjoxNzQyNDU4NDM1LCJqdGkiOiIwOWRmNGMycGx0OG44MDFxNHZzN2lnc2VrdSJ9.FcBKm5wDBL5ZP6_R15U9t2wxZBvj4gyNa48zXTk77Ig",
  `domain` = "statistics.lifisher.com",
  `Referer` = "https://statistics.lifisher.com/",
  `timestamp` = as.character(as.numeric(Sys.time()) * 1000)
)

# 爬取数据 ----
# 1. 发送登录请求（GET 方法）
response <- GET(
  LOGIN_URL, config(ssl_verifypeer = FALSE),
  query = list(
    username = USERNAME,
    password = PASSWORD
  ),
  user_agent("Mozilla/5.0")
)

# 2. 提取 Cookies 并转换为字符向量
cookies_df <- cookies(response)  # 返回数据框
cookies_vec <- paste(cookies_df$name, cookies_df$value, sep = "=")

# 3. 验证 Cookies 格式
cat("Cookies 字符向量：", cookies_vec, "\n")

# 4. 使用正确格式的 Cookies 访问受保护页面
protected_page <- GET(
  "https://admin.lifisher.com/home/index",
  config(ssl_verifypeer = FALSE),
  set_cookies(cookies_vec),  # 传递字符向量而非数据框
  user_agent("Mozilla/5.0")
)

# 5. 检查结果
if (status_code(protected_page) == 200) {
  print("访问受保护页面成功！")
} else {
  print(content(protected_page, "text"))
}

# 分页获取所有数据
all_data <- data.frame()
page <- 1
has_more <- TRUE

while (has_more && page <= MAX_PAGES) {
  # 构造查询参数
  query <- list(
    is_junk = 0,
    site_id = SITE_ID,
    page_number = page,
    page_size = PAGE_SIZE
  )
  
  # 发送请求
  response <- GET(BASE_URL, query = query, config = HEADERS)
  
  # 处理响应
  if (status_code(response) == 200) {
    res_data <- fromJSON(content(response, "text"))
    
    # 检查是否有数据
    if (length(res_data$data) > 0) {
      current_page_data <- res_data$data
      all_data <- rbind(all_data, current_page_data)
      cat("成功获取第", page, "页，累计", nrow(all_data), "条记录\n")
      page <- page + 1
    } else {
      has_more <- FALSE
      cat("第", page, "页无数据，终止分页\n")
    }
  } else {
    stop("请求失败，状态码:", status_code(response))
  }
  
  Sys.sleep(0.5)  # 控制请求频率
}

# 询盘分类 ----
gsaData <- subset(all_data, source == "4")
orgData <- subset(all_data, source == "7")
fbTrans <- subset(all_data, source == "20")
NonFB <- rbind(gsaData, orgData, fbTrans)
fbData <- subset(all_data, source == "12")

gtitle <- NonFB$custom_config
fbtitle <- fbData$content

# 非FB表单处理(cleaned_df) ----
# 1. 取custom.config中的列名
title_list <- lapply(gtitle, function(x) x$title)  # 提取所有title列
all_titles <- unlist(title_list)                     # 展开为字符向量
unique_titles <- unique(all_titles)                  # 去重
result_list <- as.list(unique_titles)                # 转换为列表

# 查看结果（按字母排序）
result_list[order(unlist(result_list))]
alist <- result_list

# 2. 将content提取作新的列表
processed_list <- lapply(seq_along(gtitle), function(i) {
  df <- gtitle[[i]]
  
  # 处理完全空白data.frame（0x0）
  if (identical(dim(df), c(0L, 0L))) {
    return(tibble(
      source_index = i,  # 记录原始位置
      inquiry_id = NA_character_,
      title = NA_character_,
      content = NA_character_
    ))
  }
  
  # 处理非空白data.frame
  df %>%
    mutate(
      source_index = i,  # 记录原始位置
      across(any_of(c("inquiry_id", "title", "content")), as.character),
      content = na_if(trimws(content), "")
    ) %>%
    select(source_index, inquiry_id, title, content)
})

# 步骤2：合并并创建完整记录
combined_df <- bind_rows(processed_list) %>%
  group_by(source_index) %>%
  mutate(row_in_group = row_number()) %>%
  ungroup()

# 步骤3：动态获取所有标题（包含空白data.frame的潜在标题）
all_titles <- union(
  unlist(alist),
  unique(combined_df$title[!is.na(combined_df$title)])
) %>%
  sort() %>%
  .[. != "" & !is.na(.)]

# 步骤4：转换为宽格式（保持原始记录数量）
final_df <- combined_df %>%
  pivot_wider(
    id_cols = c(source_index, inquiry_id),
    names_from = title,
    values_from = content,
    values_fn = ~ paste(na.omit(.), collapse = "|"),  # 处理多值
    values_fill = NA
  ) %>%
  arrange(source_index) %>%
  select(source_index, inquiry_id, all_of(all_titles)) %>%
  select(-source_index)

# 3. 清理合并内容
cleaned_df <- final_df %>%
  mutate(company_name = coalesce(`Company Name`, company, Azienda, Bedrijf, Empresa, Firma,
                                 `Nom de la compagnie`, `Nome dell'azienda`, `Şirket Adı`,
                                 `اسم الشركة`, 公司名称, 회사, `회사 이름`)) %>%
  mutate(country = coalesce(country, Land, Paese, País, Kraj, 국가)) %>%
  mutate(phone = coalesce(
    phone, telefon, Telefono, Teléfono, telefoon,
    `Phone/WhatsApp/Skype`, `Telefono/WhatsApp/Skype`,
    `Telefon/WhatsApp/Skype`, `الهاتف/الواتساب/سكايب`,
    `电话/WhatsApp/Skype`, 전화, `전화/WhatsApp/Skype`,
    WhatsApp, Whatsapp, 왓츠앱
  )) %>%
  mutate(skype = coalesce(skype, Skype, `Skype'a`, Skypen, 스카이프)) %>%
  select(inquiry_id, company_name, country, phone, skype, file, everything()) %>%
  remove_empty("cols") %>%
  mutate(across(where(is.character), ~ na_if(., "")))

# 整理新的NonFB数据表格（WebInquiry） ----
WebInquiry <- as.data.frame(cbind(NonFB$create_time, NonFB$ip_country, cleaned_df$company_name, NonFB$contacts, cleaned_df$phone, NonFB$email, NonFB$content, NonFB$account_name))

# 整理新的FB数据表格 (SocialInquiry) ----
info <- fbData$content
email <- regmatches(info, regexpr("email: [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", info))
phone_number <- regmatches(info, regexpr("phone number: \\+?[0-9]+", info))
content <- regmatches(info, regexpr("content: [^\n]+", info))
full_name <- regmatches(info, regexpr("full name: [^\n]+", info))
company_name <- regmatches(info, regexpr("company name: [^\n]+", info))

# 去除前缀
email <- sub("email: ", "", email)
phone_number <- sub("phone number: ", "", phone_number)
content <- sub("content: ", "", content)
full_name <- sub("full name: ", "", full_name)
company_name <- sub("company name: ", "", company_name)

# 写入Facebook询盘文件
SocialInquiry <- as.data.frame(cbind(fbData$create_time, fbData$ip_country, company_name, full_name, phone_number, email, content, fbData$account_name))

# 按时间顺序排列 ----
WebInquiry$V1 <- as.POSIXct(WebInquiry$V1, format = "%Y-%m-%d %H:%M:%S")
SocialInquiry$V1 <- as.POSIXct(SocialInquiry$V1, format = "%Y-%m-%d %H:%M:%S")
orderWeb <- WebInquiry[order(WebInquiry$V1), ]
orderSocial <- SocialInquiry[order(SocialInquiry$V1), ]

# 重命名标题栏
colnames(orderWeb) <- c('询盘时间', '国家', '公司名称', '联系人', '联系方式', '邮箱', '询盘内容', '跟进人')
colnames(orderSocial) <- c('询盘时间', '国家', '公司名称', '联系人', '联系方式', '邮箱', '询盘内容', '跟进人')
