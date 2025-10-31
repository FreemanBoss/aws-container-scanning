"""
AWS Lambda Function: Slack Notifier
Sends formatted notifications to Slack when vulnerabilities are detected
"""

import json
import os
import logging
from datetime import datetime
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL', '')


def lambda_handler(event, context):
    """
    Main Lambda handler
    Processes SNS messages and sends to Slack
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract message from SNS
        if 'Records' in event:
            # SNS event
            for record in event['Records']:
                if record.get('EventSource') == 'aws:sns':
                    message = json.loads(record['Sns']['Message'])
                    send_slack_notification(message)
        else:
            # Direct invocation
            send_slack_notification(event)
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Notification sent successfully'})
        }
    
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def send_slack_notification(message):
    """
    Send formatted notification to Slack
    """
    if not SLACK_WEBHOOK_URL:
        logger.warning("Slack webhook URL not configured, skipping notification")
        return
    
    # Extract details from message
    severity = message.get('severity', 'UNKNOWN')
    repository = message.get('repository', 'unknown')
    image_tags = message.get('image_tags', [])
    critical_count = message.get('critical_vulnerabilities', 0)
    high_count = message.get('high_vulnerabilities', 0)
    title = message.get('title', '')
    timestamp = message.get('timestamp', datetime.utcnow().isoformat())
    
    # Build Slack message
    slack_message = build_slack_message(
        severity, repository, image_tags, critical_count, high_count, title, timestamp
    )
    
    # Send to Slack
    try:
        req = Request(SLACK_WEBHOOK_URL, json.dumps(slack_message).encode('utf-8'))
        req.add_header('Content-Type', 'application/json')
        
        response = urlopen(req)
        response.read()
        
        logger.info(f"Sent Slack notification for {repository}")
    
    except HTTPError as e:
        logger.error(f"HTTP error sending to Slack: {e.code} - {e.reason}")
        raise
    except URLError as e:
        logger.error(f"URL error sending to Slack: {e.reason}")
        raise


def build_slack_message(severity, repository, image_tags, critical_count, high_count, title, timestamp):
    """
    Build formatted Slack message with blocks
    """
    # Color coding by severity
    color_map = {
        'CRITICAL': '#FF0000',  # Red
        'HIGH': '#FF6600',      # Orange
        'MEDIUM': '#FFCC00',    # Yellow
        'LOW': '#00CC00',       # Green
        'INFORMATIONAL': '#0099FF'  # Blue
    }
    
    color = color_map.get(severity, '#808080')
    
    # Emoji by severity
    emoji_map = {
        'CRITICAL': ':rotating_light:',
        'HIGH': ':warning:',
        'MEDIUM': ':large_orange_diamond:',
        'LOW': ':information_source:',
        'INFORMATIONAL': ':bulb:'
    }
    
    emoji = emoji_map.get(severity, ':bell:')
    
    # Build message blocks
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"{emoji} Container Vulnerability Alert",
                "emoji": True
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*Severity:*\n{severity}"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Repository:*\n`{repository}`"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Image Tags:*\n{', '.join([f'`{tag}`' for tag in image_tags]) if image_tags else 'None'}"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Timestamp:*\n{timestamp}"
                }
            ]
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*Critical:*\n{critical_count}"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*High:*\n{high_count}"
                }
            ]
        }
    ]
    
    # Add title if present
    if title:
        blocks.insert(1, {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*Finding:* {title}"
            }
        })
    
    # Add action recommendations
    if critical_count > 0 or high_count > 0:
        blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Recommended Actions:*\n• Review scan findings in AWS Console\n• Update base image to latest version\n• Check for package updates\n• Do not deploy to production"
            }
        })
    
    # Add divider
    blocks.append({"type": "divider"})
    
    # Add context
    blocks.append({
        "type": "context",
        "elements": [
            {
                "type": "mrkdwn",
                "text": f"Container Image Scanning System | {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC"
            }
        ]
    })
    
    # Build final message
    message = {
        "username": "Container Security Bot",
        "icon_emoji": ":shield:",
        "attachments": [
            {
                "color": color,
                "blocks": blocks,
                "fallback": f"{severity} vulnerability detected in {repository}"
            }
        ]
    }
    
    return message


def send_teams_notification(message):
    """
    Send notification to Microsoft Teams (alternative to Slack)
    """
    # Placeholder for Microsoft Teams integration
    # Would use similar webhook approach with Teams message format
    pass


def send_email_notification(message):
    """
    Send formatted email notification using SES
    """
    # Placeholder for email integration
    # Would use boto3 SES client
    pass
