output "scheduler_arn" {
  description = "SchedulerのARN"
  value       = aws_scheduler_schedule.cost_watcher.arn
}