import os
import json
from datetime import datetime, timedelta
import boto3
from botocore.exceptions import ClientError

def get_cost_and_usage(client, start_date, end_date):
    """Cost Explorerからコストと使用量を取得する"""
    try:
        response = client.get_cost_and_usage(
            TimePeriod={'Start': start_date, 'End': end_date},
            Granularity='MONTHLY',
            Metrics=['UnblendedCost'],
            GroupBy=[{'Type': 'DIMENSION', 'Key': 'SERVICE'}]
        )
        return response
    except ClientError as e:
        print(f"Error getting cost and usage: {e}")
        raise

def format_message(cost_data):
    """送信するためのメッセージを整形する"""
    total_cost = 0
    service_costs = []

    for result in cost_data.get('ResultsByTime', []):
        for group in result.get('Groups', []):
            service_name = group['Keys'][0]
            amount = float(group['Metrics']['UnblendedCost']['Amount'])
            total_cost += amount
            service_costs.append({'Service': service_name, 'Amount': amount})

    # コストで降順にソート
    service_costs.sort(key=lambda x: x['Amount'], reverse=True)
    
    # 過去7日間のコストから月間コストを予測
    estimated_monthly_cost = (total_cost / 7) * 30
    
    total_cost_str = f"{total_cost:,.6f}"
    estimated_monthly_cost_str = f"{estimated_monthly_cost:,.6f}"
    
    subject = "Daily AWS Cost Report"
    
    message_lines = [
        f"Total estimated cost for the last 7 days is {total_cost_str} USD.",
        f"Estimated monthly cost based on the last 7 days is {estimated_monthly_cost_str} USD.",
        "\nTop 5 services by cost:"
    ]
    
    for i, item in enumerate(service_costs[:5]):
        message_lines.append(f"{i+1}. {item['Service']}: {item['Amount']:,.6f} USD")
        
    message = "\n".join(message_lines)
    
    return subject, message

def publish_to_sns(client, topic_arn, subject, message):
    """SNSトピックにメッセージを発行する"""
    try:
        client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        print("Message published to SNS successfully.")
    except ClientError as e:
        print(f"Error publishing to SNS: {e}")
        raise

def handler(event, context):
    """Lambdaハンドラ関数"""
    SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

    if not SNS_TOPIC_ARN:
        raise ValueError("Environment variable SNS_TOPIC_ARN must be set.")

    ce_client = boto3.client('ce', region_name='us-east-1')
    sns_client = boto3.client('sns', region_name='us-east-1')

    # 日付範囲（過去7日間）
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    
    start_str = start_date.strftime('%Y-%m-%d')
    end_str = end_date.strftime('%Y-%m-%d')

    cost_data = get_cost_and_usage(ce_client, start_str, end_str)
    subject, message_body = format_message(cost_data)

    publish_to_sns(sns_client, SNS_TOPIC_ARN, subject, message_body)
    
    return {
        'statusCode': 200,
        'body': json.dumps('Daily cost report sent successfully.')
    }