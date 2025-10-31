"""
AWS Lambda Function: Scan Processor
Processes ECR and Inspector v2 scan events and stores results in DynamoDB
"""

import json
import os
import logging
from datetime import datetime
from decimal import Decimal
import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
ecr_client = boto3.client('ecr')
inspector_client = boto3.client('inspector2')
dynamodb = boto3.resource('dynamodb')
sns_client = boto3.client('sns')

# Environment variables
SCAN_RESULTS_TABLE = os.environ.get('SCAN_RESULTS_TABLE')
VULNERABILITY_INVENTORY_TABLE = os.environ.get('VULNERABILITY_INVENTORY_TABLE')
CRITICAL_SNS_TOPIC = os.environ.get('CRITICAL_SNS_TOPIC')
HIGH_SNS_TOPIC = os.environ.get('HIGH_SNS_TOPIC')
VULNERABILITY_THRESHOLD = os.environ.get('VULNERABILITY_THRESHOLD', 'HIGH')


def lambda_handler(event, context):
    """
    Main Lambda handler
    Processes EventBridge events from ECR and Inspector v2
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Determine event source
        source = event.get('source', '')
        detail_type = event.get('detail-type', '')
        
        if source == 'aws.ecr' and 'Image Scan' in detail_type:
            return process_ecr_scan(event)
        elif source == 'aws.inspector2' and 'Finding' in detail_type:
            return process_inspector_finding(event)
        else:
            logger.warning(f"Unknown event source: {source}, detail-type: {detail_type}")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Event ignored - unknown source'})
            }
    
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def process_ecr_scan(event):
    """
    Process ECR image scan completion event
    """
    detail = event.get('detail', {})
    
    repository_name = detail.get('repository-name')
    image_digest = detail.get('image-digest')
    image_tags = detail.get('image-tags', [])
    scan_status = detail.get('scan-status')
    
    logger.info(f"Processing ECR scan for {repository_name}:{image_tags}")
    
    if scan_status != 'COMPLETE':
        logger.warning(f"Scan status is {scan_status}, skipping processing")
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Scan not complete'})
        }
    
    try:
        # Get detailed scan findings from ECR
        scan_findings = ecr_client.describe_image_scan_findings(
            repositoryName=repository_name,
            imageId={'imageDigest': image_digest}
        )
        
        findings = scan_findings.get('imageScanFindings', {})
        finding_severity_counts = findings.get('findingSeverityCounts', {})
        
        # Extract vulnerability details
        vulnerabilities = findings.get('findings', [])
        
        # Store in DynamoDB
        scan_result = {
            'image_digest': image_digest,
            'scan_timestamp': int(datetime.utcnow().timestamp()),
            'repository_name': repository_name,
            'image_tags': image_tags,
            'scan_type': 'ECR_BASIC',
            'scan_status': scan_status,
            'vulnerability_counts': {
                'CRITICAL': finding_severity_counts.get('CRITICAL', 0),
                'HIGH': finding_severity_counts.get('HIGH', 0),
                'MEDIUM': finding_severity_counts.get('MEDIUM', 0),
                'LOW': finding_severity_counts.get('LOW', 0),
                'INFORMATIONAL': finding_severity_counts.get('INFORMATIONAL', 0),
                'UNDEFINED': finding_severity_counts.get('UNDEFINED', 0)
            },
            'total_vulnerabilities': len(vulnerabilities),
            'vulnerabilities': convert_to_dynamodb_format(vulnerabilities[:100]),  # Limit to avoid item size issues
            'scan_completed_at': datetime.utcnow().isoformat(),
            'ttl': int(datetime.utcnow().timestamp()) + (365 * 24 * 60 * 60)  # 1 year retention
        }
        
        # Store in DynamoDB
        table = dynamodb.Table(SCAN_RESULTS_TABLE)
        table.put_item(Item=scan_result)
        
        logger.info(f"Stored scan results for {repository_name}:{image_tags}")
        
        # Update vulnerability inventory
        update_vulnerability_inventory(vulnerabilities)
        
        # Check if alert needed
        critical_count = finding_severity_counts.get('CRITICAL', 0)
        high_count = finding_severity_counts.get('HIGH', 0)
        
        if critical_count > 0:
            send_alert('CRITICAL', repository_name, image_tags, critical_count, high_count)
        elif high_count > 0:
            send_alert('HIGH', repository_name, image_tags, critical_count, high_count)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'ECR scan processed successfully',
                'repository': repository_name,
                'vulnerabilities': finding_severity_counts
            })
        }
    
    except ClientError as e:
        logger.error(f"AWS API error: {str(e)}", exc_info=True)
        raise
    except Exception as e:
        logger.error(f"Error processing ECR scan: {str(e)}", exc_info=True)
        raise


def process_inspector_finding(event):
    """
    Process Inspector v2 finding event
    """
    detail = event.get('detail', {})
    
    finding_arn = detail.get('findingArn')
    severity = detail.get('severity')
    title = detail.get('title', '')
    description = detail.get('description', '')
    
    logger.info(f"Processing Inspector finding: {title} [{severity}]")
    
    # Extract resource information
    resources = detail.get('resources', [])
    
    for resource in resources:
        resource_type = resource.get('type')
        
        if resource_type == 'AWS_ECR_CONTAINER_IMAGE':
            repository_name = resource.get('details', {}).get('awsEcrContainerImage', {}).get('repositoryName')
            image_digest = resource.get('details', {}).get('awsEcrContainerImage', {}).get('imageHash')
            image_tags = resource.get('details', {}).get('awsEcrContainerImage', {}).get('imageTags', [])
            
            # Store Inspector finding
            scan_result = {
                'image_digest': image_digest,
                'scan_timestamp': int(datetime.utcnow().timestamp()),
                'repository_name': repository_name,
                'image_tags': image_tags,
                'scan_type': 'INSPECTOR_V2',
                'finding_arn': finding_arn,
                'severity': severity,
                'title': title,
                'description': description,
                'finding_details': convert_to_dynamodb_format(detail),
                'scan_completed_at': datetime.utcnow().isoformat(),
                'ttl': int(datetime.utcnow().timestamp()) + (365 * 24 * 60 * 60)
            }
            
            table = dynamodb.Table(SCAN_RESULTS_TABLE)
            table.put_item(Item=scan_result)
            
            logger.info(f"Stored Inspector finding for {repository_name}")
            
            # Send alert for high severity findings
            if severity in ['CRITICAL', 'HIGH']:
                send_alert(severity, repository_name, image_tags, 1 if severity == 'CRITICAL' else 0, 1 if severity == 'HIGH' else 0, title)
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Inspector finding processed successfully',
            'severity': severity
        })
    }


def update_vulnerability_inventory(vulnerabilities):
    """
    Update the vulnerability inventory table with unique CVEs
    """
    if not vulnerabilities:
        return
    
    table = dynamodb.Table(VULNERABILITY_INVENTORY_TABLE)
    
    for vuln in vulnerabilities[:50]:  # Limit batch size
        try:
            cve_id = vuln.get('name', 'UNKNOWN')
            package_name = vuln.get('attributes', [{}])[0].get('value', 'UNKNOWN') if vuln.get('attributes') else 'UNKNOWN'
            severity = vuln.get('severity', 'UNKNOWN')
            
            # Check if this is a CVE (starts with CVE-)
            if not cve_id.startswith('CVE-'):
                continue
            
            item = {
                'cve_id': cve_id,
                'package_name': package_name,
                'severity': severity,
                'description': vuln.get('description', ''),
                'uri': vuln.get('uri', ''),
                'last_detected': datetime.utcnow().isoformat(),
                'ttl': int(datetime.utcnow().timestamp()) + (365 * 24 * 60 * 60)
            }
            
            # Use update to merge with existing data
            table.put_item(Item=item)
            
        except Exception as e:
            logger.error(f"Error updating vulnerability inventory: {str(e)}")
            continue


def send_alert(severity, repository_name, image_tags, critical_count, high_count, title=''):
    """
    Send SNS alert based on severity
    """
    try:
        topic_arn = CRITICAL_SNS_TOPIC if severity == 'CRITICAL' else HIGH_SNS_TOPIC
        
        if not topic_arn:
            logger.warning(f"No SNS topic configured for {severity}")
            return
        
        message = {
            'severity': severity,
            'repository': repository_name,
            'image_tags': image_tags,
            'critical_vulnerabilities': critical_count,
            'high_vulnerabilities': high_count,
            'title': title,
            'timestamp': datetime.utcnow().isoformat(),
            'message': f"🚨 {severity} vulnerability detected in {repository_name}:{','.join(image_tags)}"
        }
        
        subject = f"[{severity}] Container Vulnerability Alert - {repository_name}"
        
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=json.dumps(message, indent=2)
        )
        
        logger.info(f"Sent {severity} alert to SNS")
    
    except Exception as e:
        logger.error(f"Error sending SNS alert: {str(e)}", exc_info=True)


def convert_to_dynamodb_format(data):
    """
    Convert floats to Decimal for DynamoDB compatibility
    """
    if isinstance(data, list):
        return [convert_to_dynamodb_format(item) for item in data]
    elif isinstance(data, dict):
        return {key: convert_to_dynamodb_format(value) for key, value in data.items()}
    elif isinstance(data, float):
        return Decimal(str(data))
    else:
        return data
