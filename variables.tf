variable "recipient_email" {
  description = "通知の送信先メールアドレス"
  type        = string
}


variable "batch_schedule" {
  description = "コスト確認のスケジュール（cron形式）"
  type        = string
  # デフォルトは毎日午前9時(JST)
  default = "cron(0 9 * * ? *)"
}

variable "batch_timezone" {
  description = "スケジュールのタイムゾーン"
  type        = string
  default     = "Asia/Tokyo"
}
