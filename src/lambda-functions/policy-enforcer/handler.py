"""
AWS Lambda Function: Policy Enforcer
Enforces security policies on scanned container images
Determines if images should be approved or rejected for deployment
"""

import json
import os
import logging
from datetime import datetime, timedelta
import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
ecr_client = boto3.client('ecr')
dynamodb = boto3.resource('dynamodb')

# Environment variables
BLOCK_ON_CRITICAL = os.environ.get('BLOCK_ON_CRITICAL', 'true').lower() == 'true'
BLOCK_ON_HIGH = os.environ.get('BLOCK_ON_HIGH', 'false').lower() == 'true'
MAX_CRITICAL_AGE_DAYS = int(os.environ.get('MAX_CRITICAL_AGE_DAYS', '0'))
MAX_HIGH_AGE_DAYS = int(os.environ.get('MAX_HIGH_AGE_DAYS', '30'))
MAX_MEDIUM_AGE_DAYS = int(os.environ.get('MAX_MEDIUM_AGE_DAYS', '90'))


def lambda_handler(event, context):
    """
    Main Lambda handler
    Evaluates scan results against security policies
    """
    logger.info(f"Evaluating policy for event: {json.dumps(event)}")
    
    try:
        # Extract scan results from event
        if 'scan_results' in event:
            scan_results = event['scan_results']
        elif 'detail' in event:
            # Extract from EventBridge event
            scan_results = extract_scan_results_from_event(event)
        else:
            raise ValueError("No scan results found in event")
        
        # Evaluate policies
        policy_result = evaluate_policies(scan_results)
        
        # Tag image based on policy result
        if 'repository_name' in scan_results and 'image_digest' in scan_results:
            tag_image(
                scan_results['repository_name'],
                scan_results['image_digest'],
                policy_result['status']
            )
        
        logger.info(f"Policy evaluation result: {policy_result['status']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'policy_result': policy_result,
                'scan_results': scan_results
            }, default=str)
        }
    
    except Exception as e:
        logger.error(f"Error evaluating policy: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def extract_scan_results_from_event(event):
    """
    Extract scan results from EventBridge event
    """
    detail = event.get('detail', {})
    
    return {
        'repository_name': detail.get('repository-name'),
        'image_digest': detail.get('image-digest'),
        'image_tags': detail.get('image-tags', []),
        'vulnerability_counts': detail.get('finding-severity-counts', {})
    }


def evaluate_policies(scan_results):
    """
    Evaluate all security policies against scan results
    Returns policy decision (APPROVED or REJECTED) with reasons
    """
    vuln_counts = scan_results.get('vulnerability_counts', {})
    
    violations = []
    warnings = []
    
    # Policy 1: Block on CRITICAL vulnerabilities
    critical_count = vuln_counts.get('CRITICAL', 0)
    if critical_count > 0:
        if BLOCK_ON_CRITICAL:
            violations.append(f"CRITICAL vulnerabilities found: {critical_count}")
        else:
            warnings.append(f"CRITICAL vulnerabilities found: {critical_count} (not blocking)")
    
    # Policy 2: Block on HIGH vulnerabilities (if configured)
    high_count = vuln_counts.get('HIGH', 0)
    if high_count > 0 and BLOCK_ON_HIGH:
        violations.append(f"HIGH vulnerabilities found: {high_count}")
    elif high_count > 0:
        warnings.append(f"HIGH vulnerabilities found: {high_count} (not blocking)")
    
    # Policy 3: Check total vulnerability threshold
    total_vulns = sum([
        vuln_counts.get('CRITICAL', 0),
        vuln_counts.get('HIGH', 0),
        vuln_counts.get('MEDIUM', 0),
        vuln_counts.get('LOW', 0)
    ])
    
    if total_vulns > 100:
        violations.append(f"Total vulnerabilities ({total_vulns}) exceeds threshold (100)")
    elif total_vulns > 50:
        warnings.append(f"Total vulnerabilities ({total_vulns}) approaching threshold")
    
    # Policy 4: Check MEDIUM vulnerability count
    medium_count = vuln_counts.get('MEDIUM', 0)
    if medium_count > 50:
        warnings.append(f"High number of MEDIUM vulnerabilities: {medium_count}")
    
    # Determine final status
    if violations:
        status = 'REJECTED'
        message = f"Image rejected due to {len(violations)} policy violation(s)"
    else:
        status = 'APPROVED'
        message = "Image approved - no policy violations"
    
    result = {
        'status': status,
        'message': message,
        'violations': violations,
        'warnings': warnings,
        'vulnerability_summary': vuln_counts,
        'total_vulnerabilities': total_vulns,
        'evaluated_at': datetime.utcnow().isoformat(),
        'policies_evaluated': [
            {
                'name': 'block_critical',
                'enabled': BLOCK_ON_CRITICAL,
                'passed': critical_count == 0 or not BLOCK_ON_CRITICAL
            },
            {
                'name': 'block_high',
                'enabled': BLOCK_ON_HIGH,
                'passed': high_count == 0 or not BLOCK_ON_HIGH
            },
            {
                'name': 'total_threshold',
                'enabled': True,
                'passed': total_vulns <= 100
            }
        ]
    }
    
    return result


def tag_image(repository_name, image_digest, status):
    """
    Tag ECR image with policy status
    """
    try:
        # Add custom tag to image
        ecr_client.put_image_tag_mutability(
            repositoryName=repository_name,
            imageTagMutability='MUTABLE'
        )
        
        # Tag format: policy-status-APPROVED or policy-status-REJECTED
        tag = f"policy-{status.lower()}-{datetime.utcnow().strftime('%Y%m%d')}"
        
        # Note: ECR doesn't support adding tags to existing images directly
        # This would typically be done during image push in CI/CD
        # We'll log the intended tag instead
        logger.info(f"Would tag image {image_digest} with: {tag}")
        
        # Store policy decision in image metadata (if needed)
        # This could be done via DynamoDB or Parameter Store
        
    except ClientError as e:
        logger.error(f"Error tagging image: {str(e)}")
        # Don't fail the function if tagging fails


def check_vulnerability_age(cve_id, max_age_days):
    """
    Check if a CVE is older than the maximum allowed age
    This would query a CVE database or NVD API
    """
    # Placeholder - would implement actual CVE age checking
    # For now, return False (not too old)
    return False


def get_policy_recommendations(scan_results):
    """
    Generate recommendations for fixing policy violations
    """
    vuln_counts = scan_results.get('vulnerability_counts', {})
    recommendations = []
    
    if vuln_counts.get('CRITICAL', 0) > 0:
        recommendations.append({
            'priority': 'CRITICAL',
            'action': 'Update base image and vulnerable packages immediately',
            'details': 'Run: docker build --no-cache to rebuild with latest base image'
        })
    
    if vuln_counts.get('HIGH', 0) > 0:
        recommendations.append({
            'priority': 'HIGH',
            'action': 'Review and update vulnerable packages',
            'details': 'Check package manager for available security updates'
        })
    
    if vuln_counts.get('MEDIUM', 0) > 10:
        recommendations.append({
            'priority': 'MEDIUM',
            'action': 'Schedule maintenance window for updates',
            'details': 'Plan to update non-critical dependencies'
        })
    
    return recommendations
