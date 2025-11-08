variable "project" {
  description = "プロジェクト名"
  type        = string
  default     = "aws-cost-watcher"
}

variable "recipient_email" {
  description = "通知の送信先メールアドレス"
  type        = string
}


variable "batch_schedule" {
  description = "コスト確認のスケジュール（cron形式）"
  type        = string
}

variable "batch_timezone" {
  description = "スケジュールのタイムゾーン"
  type        = string
  default     = "Asia/Tokyo"
}
 